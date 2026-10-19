# Polecenie LET

Polecenie `LET` nadaje nazwę stałej liczbowej. Plan może potem odwoływać się do niej przez `?NAZWA` wszędzie tam, gdzie przyjmuje liczbę: w parametrach okna `@`, indeksach pól, rozmiarach, przesunięciu, interwałach, retencji, granicach `DUMP` i w wyrażeniach. Zapytanie opisuje wtedy rolę parametru (`WINDOW_WIDTH`, `ALARM_LIMIT`) zamiast powtarzać magiczne liczby, a zmiana parametru wymaga edycji jednego wiersza.

Stała nie jest zmienną: jej wartość jest ustalona w chwili wczytania planu i nie zmienia się podczas wykonania. Liczby wpisane wprost w zapytanie (literały) pozostają pełnoprawne, a obie formy mogą występować w jednym planie.

> **_NOTE:_** Opisana funkcjonalność ma pokrycie w testach: `let_constants` i `adhoc_parse_error` opisanych w załączniku pt. [Testy Integracyjne](../zalaczniki/testy-integracyjne.md) oraz w testach jednostkowych kompilatora (`ut_compiler`).

## Składnia

```rql
LET nazwa_stałej = wartość
```

![Diagram składni polecenia LET](../assets/railroad-let.svg)

_Rys. 67. Diagram składni polecenia LET_

Diagram składni (railroad) przedstawiony na Rys. 67 został wygenerowany na podstawie reguły `let_statement` z gramatyki ANTLR4 systemu (`RQL.g4`). Za słowem kluczowym `LET` stoi nazwa stałej, znak `=` i wartość: liczba całkowita lub dziesiętna albo ułamek `licznik/mianownik`, każda z opcjonalnym znakiem minus.

Przykład syntetyczny:

```rql
LET SIGNAL_INDEX = 0
LET STATUS_INDEX = 1
LET WINDOW_STEP = 3
LET WINDOW_WIDTH = 16
LET ALARM_LIMIT = 250

DECLARE signal INTEGER, status INTEGER STREAM sample, 1 TEXTFILE 'sample.txt'
SELECT sample[?SIGNAL_INDEX], sample[?STATUS_INDEX] STREAM channels FROM sample
SELECT * STREAM block FROM channels@(?WINDOW_STEP, ?WINDOW_WIDTH)
RULE high_signal ON channels WHEN channels[?SIGNAL_INDEX] >= ?ALARM_LIMIT DO DUMP -1 TO 1
```

Kompilacja tego planu (`xretractor -c`) daje dokładnie ten sam plan co zapis z literałami `0`, `1`, `@(3, 16)` i `>= 250`.

### Prawa strona

Prawą stroną jest zawsze **jeden literał**:

| Postać | Przykład | Uwagi |
|---|---|---|
| liczba całkowita | `LET N = 16`, `LET OFFSET = -3` | zakres 32-bitowej liczby całkowitej ze znakiem |
| liczba dziesiętna | `LET GAIN = 0.5`, `LET T = 2.` | postać jak literał zmiennoprzecinkowy RQL; zapis z wykładnikiem (`1E3`) nie jest przyjmowany |
| ułamek | `LET SOURCE_INTERVAL = 1/40` | mianownik różny od zera |

Wyrażenie (`LET A = 1 + 2`), odwołanie do innej stałej (`LET B = ?A`) i znak plus (`LET X = +1`) są błędami składni.

### Nazwa i odwołanie

Nazwa stałej zaczyna się od litery i składa się z liter, cyfr i podkreślników. Znak `$` jest niedozwolony, aby odwołania nie myliły się z indeksem generatora strumieni. Wielkość liter ma znaczenie: `?signal` i `?SIGNAL` to różne stałe.

Odwołanie to jeden token: znak `?` i bezpośrednio po nim nazwa, bez spacji (`? NAZWA` jest błędem leksera). Stałe mają **osobną przestrzeń nazw**: `?X` nigdy nie jest polem ani strumieniem, a goły identyfikator `X` nigdy nie jest stałą. Stała może więc nosić tę samą nazwę co pole, strumień lub funkcja bez kolizji, a istniejące zapytania nie zmieniają znaczenia. `?` wewnątrz napisu, ścieżki, komentarza i polecenia `SYSTEM` pozostaje zwykłym tekstem.

Słowo `LET` (także `let`) jest zastrzeżone i nie może być nazwą strumienia, pola ani reguły.

### Zasięg

- Stała obowiązuje od wiersza deklaracji do końca pliku planu. `LET` może stać w dowolnym miejscu pliku, ale przed pierwszym użyciem; odwołanie przed deklaracją jest błędem.
- Ponowna deklaracja tej samej nazwy jest błędem; stałej nie da się nadpisać.
- Stałe należą do jednego planu: nie przechodzą do innego pliku, kolejnego wczytania ani zapytań ad hoc.
- Nieużyta stała nie jest błędem. `xretractor` wypisuje ostrzeżenie na stderr, także z `--quiet`, np. `xretractor: warning: line 2: constant ?UNUSED is declared but never used`. Przy ponownym wczytaniu planu przez kanał reset to samo ostrzeżenie trafia do dziennika serwera.

## Gdzie można użyć stałej

`?NAZWA` może stanąć wszędzie tam, gdzie gramatyka przyjmuje literał liczbowy. W każdym miejscu podlega tym samym ograniczeniom co literał (zakres, znak, granice planu z rozdziału [Granice wymiarów planu](../kompilacja-zapytan/granice-wymiarow-planu.md)).

| Miejsce | Zapis ze stałą | Wymagana wartość |
|---|---|---|
| parametry okna `@` | `src@(?WINDOW_STEP, ?WINDOW_WIDTH)`, `src@(?STEP, -?WIDTH)` | całkowita; krok > 0, szerokość różna od zera (ujemna jak w literale) |
| indeks pola | `src[?FIELD_INDEX]` | całkowita, ≥ 0 |
| rozmiar pola tablicowego | `INTEGER[?CHANNEL_COUNT]`, `STRING[?TEXT_WIDTH]` | całkowita, > 0 |
| rozmiar rodziny strumieni | `STREAM result[?FAMILY_SIZE]` | całkowita, > 0 |
| indeks generatora | `src[?LAST_INDEX-$]` | całkowita; arytmetyka indeksu jak dla literału |
| przesunięcie | `src > ?SHIFT` | całkowita, ≥ 0 |
| okno rekordowe | `AVG(src[?FIELD_INDEX] : ?HISTORY_WIDTH)` | całkowita, > 0 |
| szerokość tekstu | `to_string(x : ?TEXT_WIDTH)` | całkowita, > 0 |
| retencja | `RETENTION ?CAPACITY ?SEGMENTS` | całkowite; pojemność > 0, segmenty ≥ 0 |
| `DUMP` | `DUMP -?BEFORE TO ?AFTER RETENTION ?KEEP` | całkowite; granice jak w literale, retencja ≥ 0 |
| interwał `DECLARE` | `STREAM src, ?SOURCE_INTERVAL TEXTFILE '...'` | > 0 |
| operatory `&`, `%`, `-` | `src - ?OUTPUT_INTERVAL` | > 0 |
| `TIMEOUT` | `TIMEOUT ?WAIT` | ≥ 0 |
| wyrażenie w `SELECT` i `RULE ... WHEN` | `src[0] * ?GAIN + ?OFFSET`, `x >= ?ALARM_LIMIT` | całkowita lub dziesiętna |

Na diagramach składni poleceń [SELECT](polecenie-select/README.md), [DECLARE](polecenie-declare.md) i [RULE](polecenie-rule.md) gałąź `?stała` stoi obok liczby wszędzie tam, gdzie diagram pokazuje liczbę: przy rozmiarach, interwałach, `TIMEOUT`, retencji i granicach `DUMP`. Pozostałe miejsca z tabeli należą do wyrażeń, których diagramy nie rozpisują.

Przykład obejmujący wszystkie konteksty jednocześnie:

```rql
LET SOURCE_INTERVAL = 1/40
LET TEXT_WIDTH = 8
LET FAMILY_SIZE = 2
LET LAST_INDEX = 1
LET VALUE_INDEX = 0
LET HISTORY_WIDTH = 4
LET SHIFT = 2
LET OUTPUT_INTERVAL = 1/20
LET GAIN = 0.5
LET OFFSET = -3
LET CAPACITY = 1000
LET SEGMENTS = 2

DECLARE value INTEGER, label STRING[?TEXT_WIDTH] STREAM src, ?SOURCE_INTERVAL TEXTFILE 'wide.txt'
SELECT src[?LAST_INDEX-$] STREAM fam[?FAMILY_SIZE] FROM src
SELECT AVG(src[?VALUE_INDEX] : ?HISTORY_WIDTH) STREAM avg_value FROM src
SELECT to_string(src[?VALUE_INDEX] : ?TEXT_WIDTH) STREAM text FROM src > ?SHIFT
SELECT src[?VALUE_INDEX] * ?GAIN + ?OFFSET STREAM scaled FROM src - ?OUTPUT_INTERVAL RETENTION ?CAPACITY ?SEGMENTS
```

## Typ stałej

Stała ma typ swojego literału. W każdym miejscu parser zamienia ją tak samo, jak zamieniłby literał tej postaci wpisany w to miejsce, bez niejawnej konwersji:

| Kontekst | stała całkowita | stała dziesiętna | ułamek |
|---|---|---|---|
| konteksty całkowite (indeksy, rozmiary, `@`, `>`, okna, retencja, `DUMP`) | wartość | odmowa: `is not an integer` | odmowa: `is not an integer` |
| interwał `DECLARE`, `&`, `%`, `-`, `TIMEOUT` | `n` jak literał `n` | jak literał `x.y` (zamiana na ułamek z tą samą kontrolą zakresu) | jak literał `a/b` |
| wyrażenie w `SELECT` i `RULE ... WHEN` | `INTEGER` | `FLOAT` | odmowa: w wyrażeniu `1/40` jest dzieleniem całkowitym, a nie literałem ułamka - zapisz stałą dziesiętnie |

Ułamek złożony ze stałej, np. `?N/40` lub `?A/?B`, nie jest literałem ułamka. W interwale jest błędem składni, a w wyrażeniu - zwykłym dzieleniem wartości stałej przez `40`.

### Znak minus

Tam, gdzie literał przyjmuje znak minus (szerokość okna `@`, granice `DUMP`, `TIMEOUT`, wyrażenia), można napisać `-?X`. Zapis neguje wartość stałej, a wynik podlega tym samym ograniczeniom co literał. Przy `LET W = 3` zapis `src@(1, -?W)` daje to samo co `src@(1, -3)`, a przy `LET W = -3` zapis `src@(1, ?W)` daje ten sam wynik. W wyrażeniu `-?X` jest jednym czynnikiem, jak literał `-2`: `-?X^2` oznacza `(-X)^2`. W `TIMEOUT` ujemny wynik jest odmową: `TIMEOUT -?W` przy `W = 1` daje `DECLARE dev: TIMEOUT ?W = 1 (...) must not be negative`, a `-?Z` przy `Z = 0` jest przyjmowane.

## Stała znika przed wykonaniem

Stałe rozwiązuje wyłącznie parser: do kompilatora trafiają już liczby. Deklaracja `LET` nie tworzy strumienia, pola, węzła planu ani operacji wykonywanej dla każdego rekordu, a nazwy nie są wyszukiwane w trakcie przetwarzania.

Skutki:

- plan z `LET` i ten sam plan z literałami dają identyczny wynik kompilacji: programy, schematy, typy, interwały, wymagania historii i retencji;
- wydruki `xretractor -c` (tekst, CSV i graf DOT) pokazują liczby, nie nazwy stałych - nazwy występują tylko w komunikatach parsera;
- optymalizacje planu działają na liczbach, jak dla literałów.

## Zapytania ad hoc

Zapytanie ad hoc (`xqry`) nie widzi stałych działającego planu. Zapytanie z deklaracją `LET` jest odrzucane (`'LET' is not supported`), a odwołanie `?X` kończy się błędem nieznanej stałej. Odmowa nie zmienia działającego planu i nie zatrzymuje serwera.

## Błędy

Każdy błąd stałej jest odmową kompilacji: `xretractor` kończy pracę z kodem błędu, a serwer odrzuca zapytanie bez zmiany planu. Komunikat podaje nazwę stałej, kontekst i pozycję `wiersz:kolumna` w pliku planu.

| Sytuacja | Przykład komunikatu |
|---|---|
| nieznana stała lub użycie przed deklaracją | `line 2:14: constant ?NOPE in field index is not declared; LET must precede its first use` |
| ponowna deklaracja | `line 3:4: constant ?A is already declared on line 2` |
| `$` w nazwie | `line 2:4: constant name A$B must not contain '$'` |
| zerowy mianownik | `line 2:4: fraction 1/0 of constant ?D has a zero denominator` |
| wartość poza zakresem literału | `line 2:4: value 2147483648 of constant ?X is out of range` |
| wartość niecałkowita w kontekście całkowitym | `line 3:14: constant ?H = 0.5 in field index is not an integer` |
| ułamek w wyrażeniu | `constant ?F = 1/40 (line 3:19) is a fraction, which an expression has no literal for; write it as a decimal` |
| naruszenie ograniczenia miejsca | `AGSE window ?W = 0 (line 3:34) must be greater than zero`, `interval ?N = -1 (line 3:29) must be greater than zero`, `DUMP RETENTION ?B = -2 (line 4:52) must not be negative` |
| wyrażenie lub odwołanie po prawej stronie, spacja po `?` | błąd składni parsera, np. `token recognition error at: '? '` |

Ograniczenia miejsca, których nie da się sprawdzić w chwili podstawienia - np. indeks poza schematem strumienia czy pusty zakres `DUMP` - zgłasza kompilator tym samym komunikatem co dla literału.

## Pomiary i porównania

Narzędzia porównujące różne wersje silnika na tym samym tekście planu wymagają, aby każda porównywana wersja umiała ten plan wczytać. Wersje sprzed wprowadzenia `LET` odrzucają plan ze stałymi, dlatego do takich porównań należy używać planów z literałami, a warianty z `LET` trzymać w osobnych plikach.
