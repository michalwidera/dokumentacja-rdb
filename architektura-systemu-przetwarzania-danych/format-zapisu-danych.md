---
description: >-
  Format zapisu danych wymaga uwzględnienia zależności czasowych w opracowanym
  systemie. Zależności te powinny oprócz zarejestrowanych danych odtworzyć
  kolejność ich zarejestrowania oraz przerwy w przepływie.
icon: line-height
---

# Format zapisu danych

W systemie przetwarzane są serie czasowe w trzech postaciach: **artefaktów**, **efemerydów** i **substratów**. Każdy typ ma inne przeznaczenie i inną strategię przechowywania.

Substraty i Artefakty - formalnie niczym nie różnią się w systemie. Jedyna różnica to fakt, że substraty zostały wygenerowane w oparciu o równiania algebry strumieni danych i nie zostały zapisane bezpośrednio w ciągu poleceń dla kompilatora. Jeśli zadeklarujemy strumień Artefaktu, który pokryje postać substratu - substrat zostanie zredukowany. Efemerydy to strumienie, które powstały za pomocą polecenia Declare - zawierają wartości które istnieją tylko przez chwilkę.

### Typy akcesorów składowania

Pole `TYPE` w deskryptorze (lub dyrektywa `STORAGE` w RQL) wybiera implementację `FileInterface`:

| Typ (`TYPE_PROFILE`) | Klasa implementacji | Zastosowanie |
| -------------------- | ------------------- | ------------ |
| `DEFAULT`            | `groupFile<posixBinaryFileWithShadow>` | Artefakty domyślne — plik danych + plik cienia, z retencją |
| `DIRECT`             | `groupFile<posixBinaryFile>` | Zapis bezpośredni bez cienia, z retencją |
| `POSIX`              | `posixBinaryFile`   | Surowy zapis POSIX bez cienia |
| `POSIXSHD`           | `posixBinaryFileWithShadow` | POSIX z plikiem cienia |
| `MEMORY`             | `memoryFile`        | Składowanie wyłącznie w RAM (efemerydy) |
| `GENERIC`            | `genericBinaryFile` | Ogólny akcesor binarny |
| `DEVICE`             | `binaryDeviceRO`    | Zewnętrzne urządzenie binarnych danych wejściowych (tylko odczyt) |
| `TEXTSOURCE`         | `textSourceRO`      | Tekstowe źródło danych wejściowych (tylko odczyt) |

---

## Zestaw plików artefaktu i substratu

Artefakty i substraty zapisywane na dysk mogą być skojarzone z maksymalnie czterema plikami:

| Plik                  | Rozszerzenie         | Cel                                                       |
| --------------------- | -------------------- | --------------------------------------------------------- |
| Plik danych binarnych | _(nazwa strumienia)_ | Główny strumień rekordów — append-only                    |
| Plik deskryptora      | `.desc`              | Schemat rekordu (pola, typy, rozmiary, typ składowania)   |
| Plik metadanych       | `.meta`              | Indeks wartości null i przerw w transmisji (RLE)          |
| Plik cienia           | `.shadow`            | Modyfikacje rekordów bez nadpisywania danych oryginalnych |

```mermaid
graph TD
    D[".desc\nDeskryptor\nschemat rekordu"]
    B["Plik danych\n binarny\nrekordy N×R bajtów"]
    M[".meta\nMetadane\nindeks null + przerwy"]
    S[".shadow\nPlik cienia\nmodyfikacje rekordów"]

    D -->|"opisuje strukturę"| B
    B -->|"towarzyszący indeks"| M
    B -->|"opcjonalne nadpisania"| S

    style S fill:#f9c,color:#000
    style M fill:#cdf,color:#000
```

_Rys. 11. Zestaw plików artefaktu i ich powiązania_

Plik cienia i plik metadanych są opcjonalne. Przy ciągłym napływie danych bez przerw i bez modyfikacji wystarczy sam plik danych binarnych i deskryptor.

Efemerydy **nie posiadają żadnych plików na dysku** — istnieją wyłącznie w pamięci operacyjnej procesu i znikają po jego zakończeniu.

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

```mermaid
stateDiagram-v2
    [*] --> Budowa : konstruktor
    Budowa --> Aktywny : loadIndex()
    Aktywny --> Aktywny : onRecordAppended()
    Aktywny --> Aktywny : onRecordModified()
    Aktywny --> Aktywny : onTransmissionGap()
    Aktywny --> Aktywny : flushCurrentEntry()
    Aktywny --> [*] : destruktor (auto flush)
```

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

Wywoływany przez `storage` przy aktualizacji istniejącego rekordu. Lokalizuje rekord w segmentach RLE i rozbija segment na maksymalnie trzy części: przed modyfikowanym rekordem, sam rekord, za nim.

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

#### `onTransmissionGap(duration)`

Rejestruje przerwę w transmisji o podanej długości (w jednostkach interwału strumienia). Najpierw zatwierdza bieżący segment (`flushCurrentEntry()`), następnie dołącza do pliku wpis z `isGap=true`.

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

Diagram sekwencji dla typowego wzorca `storage` (append + flush po każdym rekordzie):

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

Dzięki temu plik `.meta` rośnie wyłącznie przy **zmianie wzorca null** — nie przy każdym rekordzie. Przy ciągłym napływie jednorodnych danych plik ma stały rozmiar niezależnie od liczby rekordów.

### Persystencja i odtwarzanie stanu

Po restarcie procesu nowy obiekt `metaDataStream` wczytuje plik przez `loadIndex()`:

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
    Note over Proc2: ostatni segment przeniesiony\ndo currentEntry_\n(gotowość do kontynuacji RLE)
    Proc2->>Proc2: totalRecords() = 700
```

### Interfejs zapytań

| Metoda | Opis |
| ------ | ---- |
| `getNullBitset(i)` | Zwraca wzorzec null dla rekordu `i`. Działa zarówno dla rekordów w segmentach zatwierdzonych (dysk), jak i w segmencie bieżącym (pamięć). |
| `isGapBefore(i)` | Zwraca `true`, jeżeli bezpośrednio przed rekordem `i` w indeksie RLE znajduje się wpis `isGap=true`. Rekord 0 nigdy nie ma przerwy przed sobą. |
| `segments()` | Zwraca wszystkie segmenty RLE: zatwierdzone (z dysku) oraz bieżący (z pamięci), jeżeli jest niepusty. Służy do inspekcji i testów. |
| `totalRecords()` | Suma rekordów we wszystkich segmentach (committed + pending). |
| `isEmpty()` | Skrót: `totalRecords() == 0`. |
| `reset()` | Czyści indeks: zeruje liczniki, przepisuje plik z samym nagłówkiem. Wywoływany przez `storage` przy rotacji pliku danych. |

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

```mermaid
flowchart TD
    Q["Odczyt rekordu na pozycji P"]
    Q --> SH{"Szukaj P w .shadow\n(od końca)"}
    SH -->|znaleziono| RET1["Zwróć dane z .shadow\n(najnowsza modyfikacja)"]
    SH -->|nie znaleziono| MAIN["Odczyt z pliku głównego\npread(fd, pos=P×R)"]
    MAIN --> RET2["Zwróć dane oryginalne"]
```

_Rys. 12. Priorytety odczytu rekordu z pliku cienia_

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

_Rys. 13. Scalanie pliku cienia z plikiem głównym_

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

## Relacja pomiędzy plikami

```mermaid
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
        U3["→ .meta: onRecordModified(N, nullBitset)"]
        U1 --> U2
        U1 --> U3
    end

    subgraph "Odczyt rekordu"
        R1["storage::read(pos=N)"]
        R2{".shadow\nma wpis N?"}
        R3["dane z .shadow"]
        R4["dane z pliku głównego"]
        R5[".meta: nullBitset dla N"]
        R1 --> R2
        R2 -->|tak| R3
        R2 -->|nie| R4
        R1 --> R5
    end
```

_Rys. 14. Relacja pomiędzy operacjami zapisu, modyfikacji i odczytu artefaktu_

---

## Podsumowanie: uzasadnienie przyjętej struktury

### Punkt wyjścia — plik binarny bez metadanych

Najprostszy możliwy zapis serii czasowej to sekwencja surowych wartości w pliku binarnym: stały rozmiar rekordu, brak nagłówka, brak opisu struktury. Takie podejście ma jedną zaletę — minimalny narzut — i szereg istotnych ograniczeń:

- Interpretacja danych wymaga wiedzy zewnętrznej wobec pliku (nazwy pól, typy, kolejność).
- Brak informacji o przerwach w transmisji — ciągłość danych jest pozorna.
- Każda modyfikacja historycznego rekordu niszczy dane oryginalne nieodwracalnie.
- Zmiana struktury rekordu unieważnia cały plik.

RetractorDB rejestruje dane z czujników działających w czasie rzeczywistym, gdzie przerwy zasilania, zaniki sygnału i konieczność retrospektywnej korekty danych są normalnym zjawiskiem eksploatacyjnym, nie wyjątkiem. Struktura czterech plików odpowiada bezpośrednio na każde z tych ograniczeń.

### Co wnosi każdy plik

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

### Porównanie podejść

| Właściwość | Surowy plik binarny | Struktura RetractorDB |
| ---------- | ------------------- | --------------------- |
| Samoopisywalność | brak — wymaga zewnętrznej dokumentacji | tak — deskryptor `.desc` przy danych |
| Obsługa przerw w transmisji | brak — przerwy niewidoczne lub fikcyjne rekordy | tak — `.meta` rejestruje przerwy bez rozszerzania pliku danych |
| Wartości null per pole | brak — zero = null nierozróżnialne | tak — bitset null w `.meta` |
| Korekta danych historycznych | destruktywna | niedestruktywna — `.shadow` |
| Przywrócenie oryginału po korekcie | niemożliwe | tak — usunięcie `.shadow` |
| Wielokrotność strategii składowania | brak | tak — pole `TYPE` w deskryptorze |
| Koszt przy danych bez przerw i null | — | minimalny: `.meta` ≈ 17 B nagłówek + 1 wpis RLE |
