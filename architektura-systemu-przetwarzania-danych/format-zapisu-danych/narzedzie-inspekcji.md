# Narzędzie inspekcji: `xtrdb -s`

Polecenie `xtrdb -s <ścieżka>` wyświetla kompletny obraz stanu składowania artefaktu — bez otwierania procesu `xretractor`, bez wchodzenia w tryb interaktywny. Wystarczy wskazać ścieżkę bazową (bez rozszerzenia), a narzędzie samo znajdzie powiązane pliki: `.desc`, dane binarne, `.meta`, `.shadow`, segmenty cykliczne i pliki rotowane.

> **_NOTE:_** Opisana funkcjonalność ma pokrycie w teście: `issue153_storagemap_meta_cases` opisanym w załączniku pt. [Testy Integracyjne](../../zalaczniki/testy-integracyjne.md).

## Cel i zastosowanie

| Sytuacja | Co daje `xtrdb -s` |
| -------- | ------------------- |
| Diagnoza po awarii | Widać od razu, czy plik danych jest spójny z metadanymi — różne liczby rekordów sygnalizują problem |
| Weryfikacja retencji | Sekcja DATA TOTAL pokazuje podział na segmenty i aktualny stopień wypełnienia bufora cyklicznego |
| Kontrola modyfikacji | Sekcja SHADOW ujawnia liczbę niezatwierdzonych zmian — `Updates: N` oznacza, że `merge()` nie był wykonany |
| Analiza jakości danych | Pasek META z symbolami `=`, `-`, `~`, `X` pokazuje wzorzec null i przerwy bez parsowania pliku binarnego |
| Audyt historii rotacji | Sekcja ROTATED FILES wymienia stare wersje pliku po kolejnych rotacjach |

Polecenie jest **tylko do odczytu** — nie modyfikuje żadnego pliku. Można je uruchamiać również gdy `xretractor` nie działa.

## Co pokazuje mapa

Górna część raportu to trzyelementowa mapa poglądowa:

```
│ [shadow]   │ [binary data] │ [meta index]                    │
```

Każdy wiersz mapy odpowiada jednemu segmentowi RLE lub segmentowi danych:

| Kolumna | Zawartość |
| ------- | --------- |
| `[shadow]` | Dla artefaktu bez retencji: liczba niezapisanych modyfikacji (`N updates`). Dla retencji segmentowej: etykieta segmentu `sN` z liczbą modyfikacji. |
| `[binary data]` | Zakres indeksów rekordów w pliku binarnym (`begin-end`) lub etykieta segmentu `sN begin-end`. Wiersze z przerwą w transmisji (gap) mają puste pole. |
| `[meta index]` | Opis segmentu RLE z pliku `.meta`: liczba rekordów i wzorzec null w formie `[====]`. |

Poniżej mapy następują kolejne sekcje:

| Sekcja | Opis |
| ------ | ---- |
| `DESCRIPTOR` | Ścieżka i rozmiar pliku `.desc`, lista pól z typami i rozmiarami, rozmiar rekordu w bajtach. |
| `DATA` | Liczba rekordów, ścieżka do pliku danych. Przy retencji (`RETENTION`): podział na segmenty, polityka (liczba segmentów i pojemność), maksymalny dopuszczalny rozmiar bufora, lista plików `_segment_*`. |
| `META` | Liczba segmentów RLE i rekordów w indeksie, graficzny pasek obrazujący wzorzec null w czasie. |
| `SHADOW` | Ścieżka i rozmiar pliku cienia oraz liczba niezatwierdzonych modyfikacji. |
| `ROTATED FILES` | Pliki z poprzednich rotacji (`.old1`, `.old2`, …) wraz z rozmiarami. |

### Legenda paska META

```
[====] — dane bez wartości null
[----] — częściowe null (przynajmniej jedno pole ma wartość null)
[~~~~] — wszystkie pola mają wartość null (nullfill)
[XXXX] — przerwa w transmisji (gap)
```

---

## Przykład 1 — artefakt prosty

Strumień `pomiar` z dwoma polami, 100 rekordów, bez modyfikacji, bez przerw:

```
{
  INTEGER  ts
  FLOAT    value
  TYPE     DEFAULT
}
```

```
$ xtrdb -s pomiar
```

```
Storage map: pomiar

[shadow]   | [binary data] | [meta index]
           | 0-100         | [====] 100 records, no nulls

DESCRIPTOR  pomiar.desc                               43 B
  INTEGER   ts                                         4 B
  FLOAT     value                                      4 B
  Record size:                                         8 B

DATA        pomiar                                   800 B
  Records: 100

META        pomiar.meta                               26 B
  Segments: 1   Records: 100
  [=========================100==========================]
  Legend: [====] data  [----] partial null
          [~~~~] nullfill  [XXXX] gap

SHADOW      pomiar.shadow (missing)                    0 B
```

Interpretacja: jeden segment RLE, brak przerw, brak null, plik cienia nieobecny. Plik binarny ma dokładnie 100 × 8 = 800 bajtów.

---

## Przykład 2 — artefakt z przerwą w transmisji i modyfikacją

Strumień `czujnik` z trzema polami. Po 50 rekordach nastąpiła przerwa (10 jednostek interwału), następnie napłynęło 30 rekordów z częściowymi brakami w polu `pressure`. Dwa rekordy zostały później zmodyfikowane (plik cienia obecny):

```
{
  INTEGER  ts
  FLOAT    temp
  FLOAT    pressure
  TYPE     DEFAULT
}
```

```
$ xtrdb -s czujnik
```

```
Storage map: czujnik

[shadow]   | [binary data] | [meta index]
           | 0-50          | [====] 50 records, no nulls
           |               | [XXXX] 10 records, gap
2 updates  | 50-80         | [----] 30 records, some nulls

DESCRIPTOR  czujnik.desc                              52 B
  INTEGER   ts                                         4 B
  FLOAT     temp                                       4 B
  FLOAT     pressure                                   4 B
  Record size:                                        12 B

DATA        czujnik                                  960 B
  Records: 80

META        czujnik.meta                              60 B
  Segments: 3   Records: 80
  [========50=========][gap:10][===========30============]
  Legend: [====] data  [----] partial null
          [~~~~] nullfill  [XXXX] gap

SHADOW      czujnik.shadow                            26 B
  Updates: 2
```

Interpretacja: plik binarny zawiera 80 rekordów (gap nie zajmuje miejsca w pliku danych), przerwa jest zakodowana wyłącznie w `.meta`. Kolumna `[binary data]` pokazuje pusty zakres dla segmentu gapowego — dane binarnych nie ma. Pole `pressure` w rekordach 50–79 ma wartości null w niektórych polach (`[----]`). Plik cienia zawiera 2 modyfikacje, które jeszcze nie zostały scalone z plikiem głównym.

---

## Przykład 3 — artefakt z retencją segmentową

Strumień `bufor` z retencją cykliczną: maksymalnie 10 segmentów po 100 rekordów (łącznie 1000 rekordów). Aktualnie zapisano 280 rekordów w trzech segmentach:

```
{
  DOUBLE   value
  TYPE     DEFAULT
  RETENTION 1000 100
}
```

```
$ xtrdb -s bufor
```

```
Storage map: bufor

[shadow]   | [binary data] | [meta index]
s0         | s0 0-100      | [====] 100 records, no nulls
s1         | s1 100-200    | [====] 100 records, no nulls
s2         | s2 200-280    | [====] 80 records, no nulls

DESCRIPTOR  bufor.desc                                48 B
  DOUBLE    value                                      8 B
  Record size:                                         8 B

DATA TOTAL  rec=280 src=0 seg=280                  2240 B
  Records: 280
  Source: bufor   Segments: bufor_segment_*
  Segmented data (RETENTION): 3
  Policy: segments=10 capacity=100
  Retention cap records: 1000
  Retention cap bytes: 8000
  Total records: 280
    current=0  segments=280
  Total bytes: 2240
    current=0  segments=2240
    [0] bufor_segment_0 rec:100 range:0-100
    [1] bufor_segment_1 rec:100 range:100-200
    [2] bufor_segment_2 rec:80 range:200-280

META        bufor.meta                                26 B
  Segments: 1   Records: 280
  [========================280=========================]
  Legend: [====] data  [----] partial null
          [~~~~] nullfill  [XXXX] gap

SHADOW      bufor.shadow (missing)                     0 B
```

Interpretacja: kolumna `[binary data]` pokazuje każdy segment z etykietą `sN` i zakresem indeksów globalnych. Sekcja DATA TOTAL zawiera pełne zestawienie: `src=0` (brak rekordów poza segmentami), `seg=280` (wszystkie rekordy w segmentach). Przy wypełnieniu bufora (10 segmentów × 100 = 1000 rekordów) najstarszy segment zostanie usunięty, a nowy dopisany.
