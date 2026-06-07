# Pliki

Rozdział opisuje pięć plików tworzących kompletny zestaw artefaktu lub substratu: deskryptor schematu (`.desc`), główny plik danych binarnych, indeks metadanych (`.meta`), plik cienia danych (`.shadow`) i plik cienia indeksu (`.meta.shadow`). Dla każdego pliku przedstawiono format binarny, semantykę pól oraz reguły zapisu i odczytu. Rozdział obejmuje też klasę `metaDataStream` — mechanizm kompresji RLE, obsługę przerw w transmisji, interfejs aktualizacji i persystencję po restarcie. Sekcja końcowa pokazuje relacje między wszystkimi plikami na poziomie operacji `append`, `update` i `read`.

Zakres rozdziału **nie obejmuje** mechanizmu rotacji plików między sesjami (→ [Rotacja](rotacja.md)) ani narzędzia inspekcji `xtrdb -s` (→ [Narzędzie inspekcji](narzedzie-inspekcji.md)).

---

## Plik deskryptora (.desc)

Plik `.desc` opisuje strukturę rekordu. Jest parsowany przez gramatykę ANTLR4 (`DESC.g4`) i może zawierać pola danych, metainformację o typie składowania oraz politykę retencji.

### Składnia

```
{ <polecenie>* }
```

Każde polecenie to jedno z poniższych:

```
BYTE     nazwa [N]          # tablica N bajtów (domyślnie N=1)
INTEGER  nazwa [N]          # 32-bitowe liczby całkowite ze znakiem
UINT     nazwa [N]          # 32-bitowe bez znaku
FLOAT    nazwa [N]          # 32-bitowe zmiennoprzecinkowe (IEEE 754)
DOUBLE   nazwa [N]          # 64-bitowe zmiennoprzecinkowe
RATIONAL nazwa [N]          # para int64: licznik i mianownik
STRING   nazwa [rozmiar]    # ciąg znaków o stałej długości
REF      "ścieżka/plik"     # referencja do zewnętrznego pliku deskryptora
TYPE     identyfikator      # typ składowania (DEFAULT, MEMORY, POSIXSHD, …)
RETENTION pojemność segment # retencja cykliczna na dysku
RETMEMORY pojemność         # retencja cykliczna w pamięci
```

### Przykłady plików `.desc`

**Artefakt domyślny** — dwa pola numeryczne, składowanie `DEFAULT` (plik danych + plik cienia):

```
{
  INTEGER  ts
  FLOAT    value
  TYPE     DEFAULT
}
```

**Efemeryd** — strumień ulotny wyłącznie w RAM:

```
{
  DOUBLE   x
  DOUBLE   y
  TYPE     MEMORY
}
```

**Substrat z retencją** — cykliczny bufor ostatnich 1000 rekordów na dysku (10 segmentów po 100):

```
{
  INTEGER  ts
  FLOAT    a
  FLOAT    b
  TYPE     DEFAULT
  RETENTION 1000 100
}
```

**Deklaracja źródła binarnego** (`DECLARE` w RQL generuje ten schemat):

```
{
  INTEGER  a
  FLOAT    b
  TYPE     DEVICE
  REF      "sensor/data.bin"
}
```

### Rozmiary typów pól

| Typ        | Rozmiar pojedynczej wartości |
| ---------- | ---------------------------- |
| `BYTE`     | 1 B                          |
| `INTEGER`  | 4 B                          |
| `UINT`     | 4 B                          |
| `FLOAT`    | 4 B                          |
| `DOUBLE`   | 8 B                          |
| `RATIONAL` | 16 B (dwa int64)             |
| `STRING`   | N B (deklarowany rozmiar)    |

Dla pól tablicowych `nazwa[N]` całkowity rozmiar = rozmiar_typu × N. Pola `TYPE`, `REF`, `RETENTION` i `RETMEMORY` nie zajmują miejsca w rekordzie — są metadanymi deskryptora.

Rozmiar rekordu `R` = suma rozmiarów wszystkich pól danych.

### Pole TYPE a strategia składowania

Pole `TYPE` w deskryptorze bezpośrednio wyznacza, który akcesor (`FileInterface`) zostanie użyty przez `storage::initializeAccessor()`. Brak pola `TYPE` jest równoznaczny z `DEFAULT`. Wartość jest nieczuła na wielkość liter (`MEMORY` = `memory`).

---

## Plik danych binarnych

Plik danych to sekwencja rekordów o stałej długości, zapisywanych jeden po drugim bez żadnego nagłówka. Rozmiar pojedynczego rekordu `R` wyznaczany jest przez deskryptor jako suma bajtów wszystkich pól.

| Offset w pliku | Zawartość  | Rozmiar  |
| -------------- | ---------- | -------- |
| 0              | Rekord 0   | R bajtów |
| R              | Rekord 1   | R bajtów |
| 2R             | Rekord 2   | R bajtów |
| ...            | ...        | ...      |
| (N-1) × R      | Rekord N-1 | R bajtów |

Każdy rekord zawiera upakowane wartości pól w kolejności zdefiniowanej przez deskryptor:

| Offset w rekordzie             | Pole    | Rozmiar       |
| ------------------------------ | ------- | ------------- |
| 0                              | pole\_0 | len\_0 bajtów |
| len\_0                         | pole\_1 | len\_1 bajtów |
| len\_0 + len\_1                | ...     | ...           |
| len\_0 + len\_1 + ... + len\_n | pole\_n | len\_n bajtów |

Operacja **append** (dodanie nowego rekordu) dopisuje dane na koniec pliku. Operacja **update** (modyfikacja istniejącego rekordu) — jeśli istnieje plik cienia — trafia do pliku cienia, a nie do pliku głównego.

### Przykład

```
DECLARE a INTEGER, b FLOAT STREAM str1, 0.1 FILE 'data.dat'
```

Rozmiar rekordu: INTEGER (4 B) + FLOAT (4 B) = **8 bajtów**. Po 5 sekundach napływu danych (10 Hz) plik `data.dat` ma rozmiar 5 × 10 × 8 = **400 bajtów**.

---

## Plik metadanych (.meta)

Plik `.meta` to indeks wartości null i przerw w transmisji. Przechowuje informację o tym, które pola rekordów mają wartość null i gdzie wystąpiły przerwy — bez duplikowania samych danych.

### Format pliku

| Pozycja    | Zawartość                                  | Rozmiar  |
| ---------- | ------------------------------------------ | -------- |
| Nagłówek   | `creationTimeNs` (int64)                   | 8 bajtów |
| Wpis RLE 0 | `gapFlag \| count \| bitsetSize \| bitset` | zmienny  |
| Wpis RLE 1 | `gapFlag \| count \| bitsetSize \| bitset` | zmienny  |
| ...        | ...                                        | ...      |
| Wpis RLE k | wpis bieżący (w pamięci)                   | zmienny  |

### Format wpisu RLE

Każdy wpis opisuje ciąg kolejnych rekordów z identycznym wzorcem null:

| Pole          | Rozmiar       | Opis                             |
| ------------- | ------------- | -------------------------------- |
| `gapFlag`     | 1 B           | 0 = normalny rekord, 1 = przerwa |
| `recordCount` | 8 B (size\_t) | liczba rekordów w ciągu          |
| `bitsetSize`  | 8 B (size\_t) | liczba pól (N)                   |
| `bitset`      | ⌈N/8⌉ B       | bit i = pole i ma wartość null   |

### Kompresja RLE

Kolejne rekordy z tym samym wzorcem null są scalane w jeden wpis przez zwiększenie `recordCount`. Nowy wpis tworzony jest dopiero gdy wzorzec się zmienia.

**10 rekordów, 2 pola, bez null:**

| Wpis   | isGap | count | bitset |
| ------ | ----- | ----- | ------ |
| wpis 0 | F     | 10    | \[F,F] |

**Null w polu 1 od rekordu 5:**

| Wpis   | isGap | count | bitset |
| ------ | ----- | ----- | ------ |
| wpis 0 | F     | 5     | \[F,F] |
| wpis 1 | F     | 5     | \[F,T] |

**Przerwa w transmisji po rekordzie 3:**

| Wpis   | isGap | count | bitset |
| ------ | ----- | ----- | ------ |
| wpis 0 | F     | 3     | \[F,F] |
| wpis 1 | T     | 7     | \[T,T] |
| wpis 2 | F     | ...   | \[F,F] |

### Marker przerwy w transmisji (gap)

Przerwa w transmisji (np. wyłączenie systemu, zanik sygnału) rejestrowana jest jako wpis z `isGap=true` i wszystkimi bitami null ustawionymi na `true`. Parametr `count` przechowuje długość przerwy w jednostkach interwału strumienia. Sam plik danych binarnych nie zawiera żadnych dodatkowych rekordów dla przerwy — informacja żyje wyłącznie w pliku `.meta`.

> **_NOTE:_** Opisana funkcjonalność ma pokrycie w testach: `issue113_meta_internal`, `issue113_meta_autocreate` opisanych w załączniku pt. [Testy Integracyjne](../../zalaczniki/testy-integracyjne.md).

---

### Klasa metaDataStream

Plikiem `.meta` zarządza klasa `rdb::metaDataStream`. Hermetyzuje ona trzy obszary odpowiedzialności:

1. **Agregację RLE w pamięci** — buforuje bieżący segment (ostatnią serię rekordów z identycznym wzorcem null) w polu `currentEntry_`, nie zapisując go do pliku przy każdym rekordzie.
2. **Trwałość danych** — wyłącznie zakończone segmenty (gdy wzorzec się zmienia lub gdy nastąpi jawne wywołanie `flushCurrentEntry()`) trafiają do pliku jako wpisy zatwierdzone (_committed_).
3. **Indeks zapytań** — udostępnia interfejs do odpytywania wzorca null dla dowolnego rekordu oraz wykrywania przerw w transmisji.

Klasa przechowuje dwa stany:

| Stan | Lokalizacja | Opis |
| ---- | ----------- | ---- |
| Zatwierdzone segmenty | plik `.meta` na dysku | wszystkie zakończone przebiegi RLE |
| Segment bieżący (`currentEntry_`) | pamięć operacyjna | aktualnie akumulowany przebieg (jeszcze niezapisany lub do nadpisania) |

### Cykl życia obiektu

Diagram stanów (Rys. 11) przedstawia przejścia między fazami obiektu `metaDataStream`:

```mermaid
%% pdf-width: 30%
stateDiagram-v2
    [*] --> Budowa : konstruktor
    Budowa --> Aktywny : loadIndex()
    Aktywny --> Aktywny : onRecordAppended()
    Aktywny --> Aktywny : onRecordModified()
    Aktywny --> Aktywny : onTransmissionGap()
    Aktywny --> Aktywny : flushCurrentEntry()
    Aktywny --> [*] : destruktor (auto flush)
```

_Rys. 11. Cykl życia obiektu metaDataStream_

**Konstruktor** (`metaDataStream(descriptor, path)`):
- Inicjalizuje pusty `currentEntry_` na podstawie liczby pól deskryptora.
- Wywołuje `loadIndex()` — jeżeli plik istnieje, wczytuje wszystkie zatwierdzone segmenty, wyznacza `committedRecordCount_`, a ostatni niegapowy segment przenosi z powrotem do `currentEntry_` (umożliwia kontynuację serii RLE po restarcie).
- Jeżeli plik nie istnieje, tworzy go i zapisuje nagłówek (znacznik czasu utworzenia strumienia).

**Destruktor** automatycznie wywołuje `flushCurrentEntry()`, gwarantując, że bieżący bufor trafi na dysk nawet gdy program zakończy pracę w normalnym trybie.

### Interfejs aktualizacji

Klasa wyróżnia trzy scenariusze zmiany stanu metadanych:

#### `onRecordAppended(nullBitset)`

Wywoływany przez `storage` po każdym dołączeniu nowego rekordu do pliku danych.

```
wzorzec identyczny z currentEntry_?
├─ TAK → zwiększ currentEntry_.recordCount (akumulacja RLE, brak I/O)
└─ NIE → flushCurrentEntry() (poprzedni segment na dysk)
          ustaw currentEntry_ = {nullBitset, count=1}
```

Operacja I/O następuje **wyłącznie przy zmianie wzorca** — dla serii identycznych rekordów koszt to jedna inkrementacja licznika w pamięci.

#### `onRecordModified(index, nullBitset)`

Wywoływany przez `storage` przy aktualizacji istniejącego rekordu. Zachowanie zależy od trybu pracy:

**Tryb normalny** (brak pliku cienia danych): lokalizuje rekord w segmentach RLE i rozbija segment na maksymalnie trzy części: przed modyfikowanym rekordem, sam rekord, za nim.

```
rekord w currentEntry_ (pamięć)?
├─ TAK → splitSegment() w pamięci, nowe fragmenty dołączone do pliku
└─ NIE → wczytaj plik, splitSegment(), przepisz plik (rewriteFile)
```

Przykład rozbicia segmentu `[allNull × 5]` przy modyfikacji rekordu 2:

```
Przed:  [allNull × 5]
Po:     [allNull × 2] [allPresent × 1] [allNull × 2]
```

**Tryb cienia** (`shadowMode_ = true`, aktywowany przez `setShadowMode(true)`): zamiast modyfikować główny indeks, dopisuje jedno nadpisanie wzorca null do pliku `.meta.shadow`. Główny indeks `.meta` pozostaje nienaruszone i spójne z głównym plikiem danych.

```
shadowMode_?
├─ TAK → appendShadowOverride(index, nullBitset) → wpis w .meta.shadow
└─ NIE → applyModificationToMainIndex(index, nullBitset) → splitSegment()
```

#### `onTransmissionGap(duration)`

Rejestruje przerwę w transmisji o podanej długości (w jednostkach interwału strumienia). Najpierw zatwierdza bieżący segment (`flushCurrentEntry()`), następnie dołącza do pliku wpis z `isGap=true` (Rys. 12).

```mermaid
sequenceDiagram
    participant S as storage
    participant M as metaDataStream
    participant F as plik .meta

    S->>M: onTransmissionGap(5)
    M->>F: flushCurrentEntry() — zapisz [normalny, count=N]
    M->>F: appendEntry(isGap=true, count=5)
    Note over F: plik zawiera teraz marker przerwy
```

_Rys. 12. Sekwencja rejestracji przerwy — onTransmissionGap_

### Mechanizm bezpieczeństwa: `flushCurrentEntry()` i nadpisywanie (tailDirty\_)

Klasa `storage` wywołuje `flushCurrentEntry()` po **każdym** wywołaniu `write()`, aby zagwarantować przeżycie awarii procesu. Naiwna implementacja dopisywałaby nowy wpis do pliku przy każdym flushu — powodując wzrost pliku proporcjonalny do liczby rekordów, nawet bez zmian wzorca null.

Rozwiązanie: mechanizm **lazy overwrite** oznaczany flagą `tailDirty_`.

```
flushCurrentEntry() → zapis [wzorzec, count=2] na dysk
onRecordAppended(ten sam wzorzec):
    currentEntry_.count = 2 (przywrócony z dysku)
    tailDirty_ = true        ← następny flush nadpisze, nie doda
    currentEntry_.count++    → count = 3
flushCurrentEntry() → seek na ostatni wpis, overwrite [wzorzec, count=3]
    (rozmiar pliku bez zmian)
```

Diagram sekwencji dla typowego wzorca `storage` (append + flush po każdym rekordzie) ilustruje Rys. 13:

```mermaid
sequenceDiagram
    participant S as storage
    participant M as metaDataStream
    participant F as plik .meta

    S->>M: onRecordAppended([F,F])
    S->>M: flushCurrentEntry()
    M->>F: appendEntry([F,F], count=1)

    S->>M: onRecordAppended([F,F])
    S->>M: flushCurrentEntry()
    Note over M: tailDirty_=true, overwrite last entry
    M->>F: overwrite last entry: [F,F] count=2

    S->>M: onRecordAppended([F,F])
    S->>M: flushCurrentEntry()
    M->>F: overwrite last entry: [F,F] count=3

    S->>M: onRecordAppended([T,F])
    Note over M: inny wzorzec → nowy wpis
    S->>M: flushCurrentEntry()
    M->>F: appendEntry([T,F], count=1)
```

_Rys. 13. Mechanizm lazy overwrite — nadpisywanie ostatniego wpisu .meta_

Dzięki temu plik `.meta` rośnie wyłącznie przy **zmianie wzorca null** — nie przy każdym rekordzie. Przy ciągłym napływie jednorodnych danych plik ma stały rozmiar niezależnie od liczby rekordów.

### Persystencja i odtwarzanie stanu

Po restarcie procesu nowy obiekt `metaDataStream` wczytuje plik przez `loadIndex()` (sekwencja na Rys. 14):

1. Odczytuje nagłówek — znacznik czasu (`creationTimeNs`), przechowywany jako `int64` nanosekund od epoki.
2. Wczytuje wszystkie zatwierdzone wpisy z pliku.
3. Jeżeli ostatni wpis **nie jest gap-em** — przenosi go z powrotem do `currentEntry_` i usuwa z pliku (umożliwia kontynuację RLE po restarcie bez duplikacji).
4. Wyznacza `committedRecordCount_` jako sumę `recordCount` wszystkich niegalowych wpisów pozostałych w pliku.

```mermaid
sequenceDiagram
    participant Proc1 as Pierwsza sesja
    participant F as plik .meta
    participant Proc2 as Druga sesja

    Proc1->>F: zapisuje segmenty [A×500][B×200]
    Note over Proc1: destruktor → flushCurrentEntry()
    Proc1->>F: ostatni segment zatwierdzony

    Proc2->>F: loadIndex()
    F-->>Proc2: odczyt wszystkich segmentów
    Note over Proc2: ostatni segment przeniesiony do currentEntry_
    Note over Proc2: gotowość do kontynuacji RLE
    Proc2->>Proc2: totalRecords() = 700
```

_Rys. 14. Persystencja i odtwarzanie stanu po restarcie_

### Interfejs zapytań

| Metoda | Opis         |
| ----   | ------------ |
| `getNullBitset(i)` | Zwraca wzorzec null dla rekordu `i`. W trybie cienia najpierw sprawdza nadpisania w `shadowOverrides_` (od końca — ostatnie wygrywa), a dopiero przy braku wpisu sięga do głównego indeksu. |
| `isGapBefore(i)` | Zwraca `true`, jeżeli bezpośrednio przed rekordem `i` w indeksie RLE znajduje się wpis `isGap=true`. Rekord 0 nigdy nie ma przerwy przed sobą. |
| `segments()` | Zwraca wszystkie segmenty RLE: zatwierdzone (z dysku) oraz bieżący (z pamięci), jeżeli jest niepusty. Nie obejmuje nadpisań z `.meta.shadow`. Służy do inspekcji i testów. |
| `totalRecords()` | Suma rekordów we wszystkich segmentach (committed + pending). |
| `isEmpty()` | Skrót: `totalRecords() == 0`. |
| `rotate(percounter)` | Rotuje plik indeksu: przemianowuje bieżący plik `.meta` na `.meta.old<N>`, tworzy nowy pusty plik. Wywoływana przez `storage::detectStartupState()` po wykryciu rotacji pliku danych (plik danych pusty, indeks niepusty). Gdy `percounter < 0`, plik nie jest przemianowywany — wykonywany jest tylko reset indeksu. |
| `reset()` | Czyści indeks w miejscu: zeruje liczniki, przepisuje plik z samym nagłówkiem bez zmiany jego nazwy. Wywołuje też `discardShadow()`. Wywoływany przez `storage` przy czyszczeniu bez zachowania historii (np. po `purge()`). |

### Interfejs cienia indeksu

Zestaw metod zarządzających plikiem `.meta.shadow`. Wywoływane przez `storage::attachStorage()` i powiązane operacje na pliku cienia danych.

| Metoda | Opis         |
| ----   | ------------ |
| `setShadowMode(enabled)` | Włącza lub wyłącza tryb cienia. Przy `enabled=true` wywołuje `loadShadow()` — wczytuje istniejące nadpisania z pliku `.meta.shadow`. |
| `mergeShadow()` | Scala nadpisania z cienia do głównego indeksu (wywołuje `applyModificationToMainIndex()` dla każdego nadpisania w kolejności zapisu — ostatnie wygrywa), a następnie usuwa plik `.meta.shadow`. Odpowiednik `merge()` dla pliku cienia danych. |
| `discardShadow()` | Czyści listę nadpisań w pamięci i usuwa plik `.meta.shadow`. Wywoływany przy odrzuceniu cienia danych (purge, reset, rotacja). |

### Przykład użycia — typowy scenariusz produkcyjny

```
storage.write(rec0)           → onRecordAppended([F,F,F]) + flushCurrentEntry()
storage.write(rec1)           → onRecordAppended([F,F,F]) + flushCurrentEntry()
storage.write(rec2_val_null)  → onRecordAppended([T,F,F]) + flushCurrentEntry()
storage.write(rec3)           → onRecordAppended([F,F,F]) + flushCurrentEntry()

Plik .meta po powyższych operacjach (4 flushe, 2 segmenty):
  [isGap=F, count=2, bitset=[F,F,F]]   ← wpis 0
  [isGap=F, count=1, bitset=[T,F,F]]   ← wpis 1  (rec2)
  [isGap=F, count=1, bitset=[F,F,F]]   ← wpis 2  (rec3, bieżący w pamięci)

getNullBitset(2) → [T,F,F]   (pole 0 rekordu 2 jest null)
isGapBefore(2)  → false
totalRecords()  → 4
```

---

## Plik cienia (.shadow)

Plik cienia umożliwia modyfikację zarejestrowanych rekordów bez niszczenia danych oryginalnych. Usunięcie pliku `.shadow` przywraca oryginalny stan danych.

### Format wpisu

| Pole       | Rozmiar       | Opis                           |
| ---------- | ------------- | ------------------------------ |
| `position` | 8 B (size\_t) | indeks rekordu w pliku głównym |
| `data`     | R bajtów      | nowe wartości rekordu          |

Każda modyfikacja dopisuje nowy wpis na koniec pliku cienia. Przy wielu modyfikacjach tego samego rekordu plik może zawierać wiele wpisów dla tej samej pozycji — aktualny jest ostatni.

### Priorytety odczytu

Priorytety odczytu to reguła rozstrzygania, z którego źródła system ma zwrócić wartość rekordu, gdy ten sam indeks może występować jednocześnie w pliku głównym i w pliku cienia. W RetractorDB priorytet definiowany jest deterministycznie: najpierw sprawdzany jest `.shadow` (od końca, aby wybrać najnowszą modyfikację), a dopiero przy braku wpisu wykonywany jest odczyt z pliku głównego. Pojęcie to dotyczy aspektu **spójności i wersjonowania odczytu** danych po modyfikacjach, a nie samego fizycznego formatu zapisu rekordu w pliku binarnym.


```mermaid
%% pdf-width: 100%
flowchart LR
    Q["Odczyt rekordu na pozycji P"]
    Q --> SH{"Szukaj P w .shadow\n(od końca)"}
    SH -->|znaleziono| RET1["Zwróć dane z .shadow\n(najnowsza modyfikacja)"]
    SH -->|nie znaleziono| MAIN["Odczyt z pliku głównego\npread(fd, pos=P×R)"]
    MAIN --> RET2["Zwróć dane oryginalne"]
```

_Rys. 15. Priorytety odczytu rekordu z pliku cienia_

Rys. 15 przedstawia logikę odczytu rekordu: system najpierw sprawdza wpis w `.shadow`, a dopiero przy jego braku odczytuje rekord z pliku głównego.

### Scalanie (merge)

Operacja `merge()` scala zmiany z pliku cienia do pliku głównego i zeruje plik cienia. Po scaleniu dane oryginalne są bezpowrotnie nadpisane.

```mermaid
sequenceDiagram
    participant App
    participant Shadow as .shadow
    participant Main as plik główny

    App->>Shadow: odczyt wszystkich wpisów (i, data_i)
    loop dla każdego wpisu
        Shadow-->>App: (position=i, data=data_i)
        App->>Main: pwrite(data_i, offset=i×R)
    end
    App->>Shadow: ftruncate(0) — wyczyść plik cienia
```

_Rys. 16. Scalanie pliku cienia z plikiem głównym_

Rys. 16 przedstawia przebieg `merge()`: kolejne wpisy `(position, data)` z `.shadow` są zapisywane do pliku głównego, a po zakończeniu plik cienia jest czyszczony.

### Przykład: modyfikacja rekordu

```
# Strumień str1: 2 pola INTEGER (4B każde), recordSize = 8B
# Rekord 2 (oryginał): [100, 200]
# Modyfikacja: pole 0 → 999

# Plik .shadow po modyfikacji:
# offset 0: [position=2 (8B)][999, 200 (8B)]
```

Odczyt rekordu 2 zwróci `[999, 200]`. Odczyt rekordu 0 i 1 zwróci dane z pliku głównego (nie ma ich w shadow).

---

## Plik cienia indeksu (.meta.shadow)

Plik `.meta.shadow` jest odpowiednikiem `.shadow` na poziomie indeksu null. Rejestruje nadpisania wzorców null dla poszczególnych rekordów bez modyfikowania głównego pliku `.meta`, zachowując spójność pary: `plik główny ↔ .meta` oraz `plik cienia ↔ .meta.shadow`.

### Kiedy powstaje

Plik `.meta.shadow` jest tworzony automatycznie przez `metaDataStream`, gdy spełnione są dwa warunki:

1. Magazyn jest typu `DEFAULT` lub `POSIXSHD` — czyli taki, który trzyma modyfikacje rekordów w pliku `.shadow` (nie w pliku głównym).
2. W danej sesji wykonana zostanie przynajmniej jedna modyfikacja istniejącego rekordu (`storage::write()` na indeks inny niż maksymalny).

Warunek 1 sprawdzany jest podczas `storage::attachStorage()` — jeżeli jest spełniony, wywoływane jest `metaDataStream::setShadowMode(true)`.

### Format pliku

Plik `.meta.shadow` nie ma nagłówka. Jest sekwencją wpisów w tym samym formacie binarnym co wpisy w pliku `.meta`, z tą różnicą, że pole `recordCount` przechowuje **bezwzględny indeks rekordu** (nie liczbę rekordów w serii RLE):

| Pole         | Rozmiar       | Znaczenie w `.meta.shadow`            |
| ------------ | ------------- | ------------------------------------- |
| `gapFlag`    | 1 B           | zawsze 0 (nadpisania nie są przerwami) |
| `recordCount`| 8 B (size\_t) | bezwzględny indeks nadpisywanego rekordu |
| `bitsetSize` | 8 B (size\_t) | liczba pól deskryptora (N)            |
| `bitset`     | ⌈N/8⌉ B       | nowy wzorzec null dla tego rekordu    |

Każde wywołanie `onRecordModified()` w trybie cienia dopisuje jeden wpis na koniec pliku. Wiele wpisów dla tej samej pozycji jest dozwolone — obowiązuje **ostatni** wpis (semantyka „last-write-wins", zgodna z plikiem `.shadow`).

### Priorytety odczytu

W trybie cienia `getNullBitset(i)` skanuje listę nadpisań od końca. Jeżeli znajdzie wpis dla indeksu `i`, zwraca jego wzorzec null bez sięgania do głównego indeksu (Rys. 17):

```mermaid
flowchart TD
    Q["getNullBitset(i)"]
    Q --> SM{"shadowMode_?"}
    SM -->|tak| SCAN{"shadowOverrides_\n(od końca): wpis dla i?"}
    SCAN -->|znaleziono| RET1["Zwróć nullBitset z nadpisania\n(najnowsze wygrywa)"]
    SCAN -->|nie znaleziono| MAIN["Wyszukaj w głównym indeksie\n(segmenty RLE na dysku)"]
    SM -->|nie| MAIN
    MAIN --> RET2["Zwróć wzorzec z .meta"]
```

_Rys. 17. Priorytety odczytu wzorca null — główny indeks vs. cień indeksu_

### Cykl życia

Plik `.meta.shadow` jest zarządzany równolegle z plikiem cienia danych:

| Zdarzenie na pliku `.shadow` | Akcja na `.meta.shadow` |
| ---------------------------- | ----------------------- |
| Pierwsza modyfikacja rekordu | Tworzenie pliku; dołączenie pierwszego wpisu |
| Kolejne modyfikacje | Dołączanie kolejnych wpisów |
| `merge()` — scalenie cienia z plikiem głównym | `mergeShadow()` — nadpisania aplikowane do `.meta`; plik usuwany |
| `purge()` / `reset()` — odrzucenie cienia | `discardShadow()` — plik usuwany bez scalania |
| Restart procesu | `setShadowMode(true)` → `loadShadow()` — plik odczytywany; nadpisania przywrócone w pamięci |
| Usunięcie tymczasowego magazynu (destruktor) | Plik `.meta.shadow` usuwany razem z `.meta` |

### Persystencja po restarcie

Po restarcie procesu nowy obiekt `metaDataStream` przywraca stan cienia przez `loadShadow()` (Rys. 18):

1. Odczytuje wszystkie wpisy z `.meta.shadow` (brak nagłówka — format bezpośredni).
2. Ładuje je do `shadowOverrides_` w kolejności zapisu.
3. `getNullBitset()` i kolejne `onRecordModified()` działają tak samo jak przed restartem.

```mermaid
%% pdf-width: 100%
sequenceDiagram
    participant Proc1 as Pierwsza sesja
    participant MS as .meta.shadow
    participant Meta as .meta

    Proc1->>Meta: onRecordAppended([F,F,F]) × 5
    Proc1->>MS: onRecordModified(2, [T,T,T]) → dołącz wpis (index=2)
    Note over Meta: .meta bez zmian [allNull×5]
    Note over MS: .meta.shadow: [(index=2, [T,T,T])]

    Note over Proc1: restart

    participant Proc2 as Druga sesja
    Proc2->>MS: setShadowMode(true) → loadShadow()
    MS-->>Proc2: [(index=2, [T,T,T])]
    Note over Proc2: getNullBitset(2) → [T,T,T]
    Proc2->>Meta: mergeShadow() → applyModificationToMainIndex(2, [T,T,T])
    Proc2->>MS: usuń plik .meta.shadow
```

_Rys. 18. Cień indeksu — odtwarzanie wzorców null po restarcie_

### Przykład użycia — korekta rekordu z zachowaniem spójności

```
# 5 rekordów w strumieniu str1, 3 pola FLOAT
# Rekord 2 ma wartość null w polu 0: nullBitset=[T,F,F]
# Operator koryguje pole 0 rekordu 2 → zmiana wzorca na [F,F,F]

# Operacje:
storage.write(rec2_corrected, pos=2)
  → .shadow: dołącz (position=2, data_corrected)
  → metaDataStream.onRecordModified(2, [F,F,F])
    → tryb cienia: .meta.shadow: dołącz (index=2, [F,F,F])

# Stan plików:
# .meta        — bez zmian: [isGap=F, count=2, [F,F,F]], 
# >> [isGap=F, count=1, [T,F,F]], [isGap=F, count=2, [F,F,F]]
# .meta.shadow — nowy wpis: [gapFlag=0, recordCount=2, bitset=[F,F,F]]

# Odczyt:
getNullBitset(2) → [F,F,F]  (z .meta.shadow)
getNullBitset(1) → [F,F,F]  (z .meta)

# Po scaleniu:
storage.merge() → .shadow wchłonięty do pliku głównego
metaDataStream.mergeShadow() → .meta przebudowany, .meta.shadow usunięty
# .meta po merge: [isGap=F, count=5, [F,F,F]]  (wszystkie rekordy pełne)
```

> **_NOTE:_** Mechanizm `.meta.shadow` jest testowany w teście jednostkowym `scenariusz_cien_indeksu` (`test_metaDataStream_usage.cpp`).

---

## Relacja pomiędzy plikami

W tej części relacje między plikami są pokazane na dwóch poziomach. Poziom strukturalny opisuje, że plik danych jest nośnikiem rekordów, deskryptor `.desc` definiuje ich format, plik `.meta` przechowuje informację o wartościach null i przerwach transmisji, `.shadow` gromadzi modyfikacje danych bez niszczenia oryginału, a `.meta.shadow` gromadzi analogicznie nadpisania wzorców null. Poziom operacyjny (Rys. 19) pokazuje przebieg odczytu i zapisu: odczyt najpierw sprawdza `.shadow` i `.meta.shadow`, `merge()` przenosi poprawki do pliku głównego i głównego indeksu, a operacje `append`, `update` i `read` utrzymują spójność danych i metadanych w całym cyklu życia artefaktu.

```mermaid
%% pdf-width: 100%
graph LR
    subgraph "Zapis nowego rekordu (append)"
        A1["storage::write(data, pos=MAX)"]
        A2["→ plik główny: dopisz na koniec"]
        A3["→ .meta: onRecordAppended(nullBitset)"]
        A1 --> A2
        A1 --> A3
    end

    subgraph "Modyfikacja rekordu (update)"
        U1["storage::write(data, pos=N)"]
        U2["→ .shadow: dopisz (N, data)"]
        U3["→ .meta.shadow: dopisz (index=N, nullBitset)"]
        U1 --> U2
        U1 --> U3
    end

    subgraph "Odczyt rekordu"
        R1["storage::read(pos=N)"]
        R2{".shadow\nma wpis N?"}
        R3["dane z .shadow"]
        R4["dane z pliku głównego"]
        R5{".meta.shadow\nma wpis N?"}
        R6["nullBitset z .meta.shadow"]
        R7["nullBitset z .meta"]
        R1 --> R2
        R2 -->|tak| R3
        R2 -->|nie| R4
        R1 --> R5
        R5 -->|tak| R6
        R5 -->|nie| R7
    end
```

_Rys. 19. Relacja pomiędzy operacjami zapisu, modyfikacji i odczytu artefaktu_

Rys. 19 przedstawia przepływ operacji `append`, `update` i `read` przez warstwę `storage` oraz ich bezpośredni wpływ na plik danych, `.meta`, `.shadow` i `.meta.shadow`.

## Punkt wyjścia — plik binarny bez metadanych

Najprostszy możliwy zapis serii czasowej to sekwencja surowych wartości w pliku binarnym: stały rozmiar rekordu, brak nagłówka, brak opisu struktury. Takie podejście ma jedną zaletę — minimalny narzut — i szereg istotnych ograniczeń:

- Interpretacja danych wymaga wiedzy zewnętrznej wobec pliku (nazwy pól, typy, kolejność).
- Brak informacji o przerwach w transmisji — ciągłość danych jest pozorna.
- Każda modyfikacja historycznego rekordu niszczy dane oryginalne nieodwracalnie.
- Zmiana struktury rekordu unieważnia cały plik.

RetractorDB rejestruje dane z czujników działających w czasie rzeczywistym, gdzie przerwy zasilania, zaniki sygnału i konieczność retrospektywnej korekty danych są normalnym zjawiskiem eksploatacyjnym, nie wyjątkiem. Struktura czterech plików odpowiada bezpośrednio na każde z tych ograniczeń.

## Co wnosi każdy plik

**Deskryptor (`.desc`) — samoopisywalność i niezależność od kodu**

Plik danych binarnych jest bezużyteczny bez znajomości struktury rekordu. Deskryptor przechowuje tę wiedzę obok danych, co oznacza:

- Dane można odczytać i zinterpretować bez dostępu do kodu źródłowego ani konfiguracji — wystarczy plik `.desc`.
- Narzędzie `xtrdb` może analizować dowolny artefakt bez dodatkowych parametrów.
- Zmiana struktury strumienia (dodanie pola, zmiana typu) jest jawna i wersjonowalna.
- Pole `TYPE` w deskryptorze decyduje o strategii składowania, co pozwala temu samemu silnikowi obsługiwać trwałe artefakty, ulotne efemerydy i zewnętrzne źródła danych bez zmiany logiki zapytań.

**Plik metadanych (`.meta`) — wiarygodność serii czasowej**

Seria czasowa z dziurami, traktowana jako ciągła, prowadzi do błędnych obliczeń okien czasowych, błędnych agregacji i fałszywych korelacji. Plik `.meta` zapewnia:

- Odróżnienie rekordu z wartością zero od rekordu nieobecnego (null) — semantycznie zupełnie różnych stanów.
- Rejestrację przerw w transmisji bez wstawiania fikcyjnych rekordów do pliku danych — plik binarny pozostaje gęsty i adresowalny pozycyjnie.
- Kompresję RLE — typowe serie czasowe mają długie okresy bez null, więc koszt metadanych jest bliski zeru dla danych dobrej jakości.
- Możliwość odtworzenia dokładnego harmonogramu rejestracji, w tym długości przerw, co jest niezbędne przy obliczaniu interwałów w algebrze strumieni.

**Plik cienia (`.shadow`) — niedestruktywna korekta danych**

W systemach pomiarowych korekta błędnych próbek po fakcie jest standardową procedurą. Nadpisanie pliku binarnego jest nieodwracalne i usuwa dowód oryginalnego pomiaru. Plik cienia:

- Pozwala skorygować dowolny historyczny rekord bez modyfikacji pliku głównego.
- Zachowuje oryginalny pomiar jako domyślny — usunięcie pliku `.shadow` w pełni przywraca stan wyjściowy.
- Umożliwia scalenie (`merge`) korekt do pliku głównego wtedy, gdy jest to świadoma decyzja operatora, nie skutek uboczny zapisu.
- Separuje dane certyfikowane (plik główny) od danych roboczych (plik cienia), co ma znaczenie w zastosowaniach wymagających audytowalności.

**Plik cienia indeksu (`.meta.shadow`) — spójność metadanych przy korekcie**

Korekta rekordu w pliku cienia danych musi znaleźć odzwierciedlenie w indeksie null — inaczej `getNullBitset()` zwróciłoby przestarzały wzorzec z głównego `.meta`. Plik `.meta.shadow`:

- Utrzymuje spójność między parami: `plik główny ↔ .meta` oraz `.shadow ↔ .meta.shadow`.
- Pozwala `getNullBitset()` zwrócić aktualny wzorzec null dla skorygowanego rekordu bez modyfikowania głównego indeksu.
- Śledzi cykl życia pliku cienia danych — scalany i usuwany dokładnie razem z `.shadow`.
- Umożliwia pełne odtworzenie stanu po restarcie: nadpisania załadowane z `.meta.shadow` są natychmiast dostępne bez ponownego skanowania pliku cienia danych.