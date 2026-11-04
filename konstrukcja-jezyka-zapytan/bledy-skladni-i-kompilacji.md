# Błędy składni i kompilacji

Błędne zapytanie może zostać odrzucone przy rozpoznawaniu składni, sprawdzaniu wartości liczbowych lub budowie planu. Ten rozdział wyjaśnia komunikaty zgłaszane przez parser i kompilator oraz pokazuje, jak poprawić zapis. Obejmuje także konstrukcje zgodne z gramatyką, których silnik nie potrafi wykonać, np. okno historyczne bez źródła danych.

Mapa testów jednostkowych i integracyjnych oraz sposób wiązania identyfikatorów wymagań są opisane w [załączniku Testy integracyjne](../zalaczniki/testy-integracyjne.md#wymagania-w-kodzie-i-powiązanie-z-testami).

Przejdź do grupy odpowiadającej komunikatowi:

- [Zapis polecenia, komentarze i nawiasy](#zapis-polecenia-komentarze-i-nawiasy)
- [Liczby, interwały i wymiary](#liczby-interwały-i-wymiary)
- [Nazwy strumieni, pola i zależności](#nazwy-strumieni-pola-i-zależności)
- [Operatory strumieniowe i funkcje](#operatory-strumieniowe-i-funkcje)
- [Okna historyczne w liście SELECT](#okna-historyczne-w-liście-select)
- [LET, VAR i DO SET](#let-var-i-do-set)
- [Generatory rodzin strumieni](#generatory-rodzin-strumieni)
- [Reguły RULE](#reguły-rule)
- [Źródła, magazyny i dyrektywy](#źródła-magazyny-i-dyrektywy)

## Jak odczytać komunikat

Najpierw sprawdź plik bez uruchamiania przetwarzania:

```bash
xretractor -c zapytania.rql 2>bledy.txt
echo $?
cat bledy.txt
```

Kod `0` oznacza poprawną kompilację. Odmowa błędnego planu zwraca `EPROTO`, czyli `71` na Linuksie. Inne niepowodzenia, np. brak samego pliku `.rql`, mogą zwracać inny kod; w skrypcie zawsze sprawdzaj, czy wynik jest różny od zera. Tryb `-c` nie uruchamia źródeł ani nie sprawdza dostępności plików danych.

| Element komunikatu | Znaczenie | Co sprawdzić |
| --- | --- | --- |
| `Syntax error @Rql`, `line L:C`, `msg:...` | Lekser lub parser nie rozpoznał zapisu. | Wskazany znak, poprzedzające go słowo, przecinek, apostrof lub nawias. |
| `Parse result:...` | Nie powiodło się parsowanie albo kontrola semantyczna parsera. | Oprócz składni także zakres liczby, opcje `DECLARE`, dyrektywy, deklaracje `LET`/`VAR` i cel `RULE`. |
| `Check result:...` | Parser przyjął zapis, ale kompilator odmówił zbudowania planu. | Nazwy i indeksy pól, zależności, typy, zgodność operatorów oraz zasoby historii. |
| `FATAL: internal compiler error: ...` | Naruszony został wewnętrzny warunek kompilatora. | Zachowaj plan, komunikat i wersję programu do zgłoszenia błędu. Ten komunikat nie wskazuje zwykłej poprawki składni. |

Numer wiersza `L` jest liczony od `1`, a pozycja `C` w wierszu od `0`. W poleceniu kontynuowanym znakiem `\` numer wskazuje początek połączonego polecenia, a pozycja dotyczy połączonego tekstu. `Input file:` wskazuje plik, którego dotyczy odmowa. Poprawiaj pierwszy błąd i ponawiaj kompilację: kolejne kontrole mogą ujawnić następne problemy dopiero po jego usunięciu.

W tabelach poniżej podano charakterystyczne **fragmenty komunikatów**. Pełna treść zawiera również nazwy strumieni, wartości i czasem pozycję w pliku. Lista słów oczekiwanych przez parser zależy od miejsca błędu.

## Wspólne źródła przykładów

Każdą parę z tabel oraz każdy blok oznaczony „Błędnie” lub „Poprawnie” sprawdzaj **osobno**, dopisując go do poniższego nagłówka. Wyjątkiem są bloki oznaczone „pełny plan”, które zawierają już wszystkie potrzebne deklaracje. Pliki źródeł są przykładowe: wystarczą do sprawdzenia przez `-c`, a do wykonania trzeba przygotować dane zgodne ze schematami.

```rql
DECLARE v INTEGER, w INTEGER STREAM src, 1 TEXTFILE 'dane.txt'
DECLARE z INTEGER STREAM aux, 1 TEXTFILE 'pomocnicze.txt'
DECLARE a INTEGER[3] STREAM vec, 1 BINFILE 'wektor.bin'
DECLARE label STRING[8] STREAM words, 1 BINFILE 'napisy.bin'
SELECT * STREAM out FROM src VOLATILE
```

`src` ma dwa pola, `aux` jedno, a `vec` trzy elementy liczbowe. `words` zawiera jeden napis długości ośmiu bajtów. Indeksy elementów zaczynają się od zera. `out` jest wynikiem `SELECT`, do którego można dołączać reguły.

## Zapis polecenia, komentarze i nawiasy

`mismatched input` oznacza token niepasujący w danym miejscu, `missing` brak wymaganego tokenu, `extraneous input` nadmiarowy token, a `token recognition error` znak nierozpoznany przez lekser. Nie każdy błąd daje wszystkie te komunikaty. Sprawdź również zapis przed wskazanym miejscem: parser często zauważa brak przecinka lub nawiasu dopiero przy następnym słowie.

| Fragment komunikatu | Błędnie | Poprawnie |
| --- | --- | --- |
| `missing STREAM` | `SELECT v result FROM src` | `SELECT v STREAM result FROM src` |
| `missing ','` | `DECLARE x INTEGER STREAM sensor 1 TEXTFILE 'x.txt'` | `DECLARE x INTEGER STREAM sensor, 1 TEXTFILE 'x.txt'` |
| `no viable alternative` | `SELECT to_string(v,16) STREAM result FROM src` | `SELECT to_string(v:16) STREAM result FROM src` |
| `expecting ID` | `SELECT v STREAM MIN FROM src` | `SELECT v STREAM minimum FROM src` |
| `extraneous input ';'` | `SELECT v STREAM result FROM src;` | `SELECT v STREAM result FROM src` |
| `token recognition error` | `DECLARE x INTEGER STREAM sensor, 1 TEXTFILE "x.txt"` | `DECLARE x INTEGER STREAM sensor, 1 TEXTFILE 'x.txt'` |
| `which is not defined in the plan` | `SELECT v STREAM result FROM src # komentarz` | `SELECT v STREAM result FROM src // komentarz` |

W funkcji `to_string` dwukropek oddziela szerokość pola wynikowego; przecinki oddzielają pozycje listy `SELECT`. Słowa kluczowe, m.in. `MIN`, `MAX`, `AVG`, `SUMC`, `TIMEOUT` i `RATIONAL`, nie mogą zastępować identyfikatora w pisowni rozpoznawanej przez gramatykę. Średnik nie jest terminatorem polecenia RQL. Napisy zapisuje się w apostrofach. `#` oznacza komentarz tylko jako pierwszy niebiały znak wiersza, natomiast w `FROM` jest operatorem przeplotu. Dlatego pojedyncze słowo po `#` może zostać przyjęte jako nazwa drugiego strumienia i dać błąd kompilacji, a dłuższy komentarz błąd składni.

Każdy fizyczny wiersz jest domyślnie osobnym poleceniem. Przeniesienie `FROM` do kolejnego wiersza wymaga znaku kontynuacji:

**Błędnie:**

```rql
SELECT v STREAM result
FROM src
```

**Poprawnie:**

```rql
SELECT v STREAM result \
FROM src
```

W `RULE WHEN` porównanie ma dwa argumenty. Zapis zakresu wymaga `AND`; `NOT` należy do logiki `WHEN` i nie jest operatorem wyrażenia skalarnego `SELECT`. Nawiasy grupują arytmetykę, ale gramatyka nie dopuszcza w nich całych porównań ani warunków logicznych.

| Fragment komunikatu | Błędnie | Poprawnie |
| --- | --- | --- |
| `mismatched input '<'` | `RULE alarm ON out WHEN 0 < out[0] < 10 DO DUMP -1 TO 1` | `RULE alarm ON out WHEN 0 < out[0] AND out[0] < 10 DO DUMP -1 TO 1` |
| `missing ')'` | `RULE alarm ON out WHEN (out[0] > 0) DO DUMP -1 TO 1` | `RULE alarm ON out WHEN out[0] > 0 DO DUMP -1 TO 1` |
| `'NOT'` | `SELECT NOT v STREAM result FROM src` | `SELECT IsZero(v) STREAM result FROM src` |

Ostatnia poprawka realizuje sprawdzenie zera w polu wynikowym. Jeśli potrzebne jest zanegowanie złożonego warunku, zapisz je w regule, zgodnie z [opisem warunków logicznych](polecenie-rule-warunek-logiczny.md).

**Testy i wymagania:** [Składnia, komentarze i pozycje błędów](../zalaczniki/testy-integracyjne.md#rql-tests-syntax).

## Liczby, interwały i wymiary

### Liczba spoza zakresu lub niedozwolony interwał

Literal musi mieścić się w typie, do którego odczytuje go parser. Późniejsze rzutowanie nie naprawi już odrzuconego literalu. Ułamek interwału nie może mieć zerowego mianownika, a interwał źródła oraz argumenty operatorów `&`, `%` i `-` muszą być dodatnie. W tych miejscach zapis dziesiętny jest przeliczany do reprezentacji wymiernej o ograniczonym zakresie i rozdzielczości.

| Fragment komunikatu | Błędnie | Poprawnie |
| --- | --- | --- |
| `numeric literal 2147483648 is out of range` | `SELECT v+2147483648 STREAM result FROM src` | `SELECT v+2147483647 STREAM result FROM src` |
| `fraction 1/0 has a zero denominator` | `DECLARE x INTEGER STREAM sensor, 1/0 TEXTFILE 'x.txt'` | `DECLARE x INTEGER STREAM sensor, 1/10 TEXTFILE 'x.txt'` |
| `interval 0 must be greater than zero` | `DECLARE x INTEGER STREAM sensor, 0 TEXTFILE 'x.txt'` | `DECLARE x INTEGER STREAM sensor, 1/10 TEXTFILE 'x.txt'` |
| `numeric literal 0.00000001 is out of range` | `DECLARE x INTEGER STREAM sensor, 0.00000001 TEXTFILE 'x.txt'` | `DECLARE x INTEGER STREAM sensor, 1/100000000 TEXTFILE 'x.txt'` |

Pierwsza poprawka zmienia wartość na mieszczącą się w `INTEGER`. Gdy aplikacja potrzebuje większej liczby, zadeklaruj ją jako stałą o odpowiednim typie, np. `LET OFFSET : DOUBLE = 2147483648`, i użyj `?OFFSET`; nie otaczaj niepoprawnego literału samą funkcją `to_double`.

### Zerowy rozmiar lub przekroczony limit

`must be greater than zero`, `must not be negative` i `exceeds the limit` opisują ograniczenie konkretnego argumentu. Długość pola, szerokość `to_string`, krok i bezwzględna szerokość okna muszą być dodatnie. Przesunięcie `>0` jest dozwolone. Ujemna szerokość okna AGSE określa jego kierunek i jest poprawna, o ile jej wartość bezwzględna mieści się w limicie.

| Fragment komunikatu | Błędnie | Poprawnie |
| --- | --- | --- |
| `must be greater than zero` | `DECLARE x INTEGER[0] STREAM sensor, 1 BINFILE 'x.bin'` | `DECLARE x INTEGER[3] STREAM sensor, 1 BINFILE 'x.bin'` |
| `must be greater than zero` | `SELECT * STREAM result FROM src@(0,3)` | `SELECT * STREAM result FROM src@(1,3)` |
| `must be greater than zero` | `SELECT * STREAM result FROM src@(1,0)` | `SELECT * STREAM result FROM src@(1,3)` |
| `must be greater than zero` | `SELECT MIN(src[0]:0) STREAM result FROM src` | `SELECT MIN(src[0]:3) STREAM result FROM src` |
| `must be greater than zero` | `SELECT to_string(v:0) STREAM result FROM src` | `SELECT to_string(v:16) STREAM result FROM src` |
| `exceeds the limit 65536` | `SELECT * STREAM result FROM src>65537` | `SELECT * STREAM result FROM src>10` |

Pełna tabela limitów i wyjaśnienie ograniczeń łącznych są w rozdziale [Granice wymiarów planu](../kompilacja-zapytan/granice-wymiarow-planu.md). Kompilator sprawdza również wielkości wyliczone, np. długość po połączeniu napisów, rozmiar rekordu, sumę elementów planu, początek logiczny i opóźnienie startowe. Wartości argumentów mieszczące się osobno w limitach nie gwarantują, że cały plan się w nich mieści.

Przykładowo dwa pola `to_string` o szerokości `40000` są osobno dopuszczalne, ale ich połączenie daje jeden napis długości `80000`, przekraczający limit pola:

| Fragment komunikatu | Błędnie | Poprawnie |
| --- | --- | --- |
| `has length 80000; the limit is 65536` | `SELECT to_string(v:40000)+to_string(w:40000) STREAM result FROM src` | `SELECT to_string(v:16)+to_string(w:16) STREAM result FROM src` |

Początek logiczny wyliczony dla złożonego planu musi mieścić się w typie `int`. Dwa kolejne okna AGSE `@(1,65536)` nad źródłem jednopolowym przekraczają limit `2147483647` slotów. Komunikat zawiera `has a logical origin of ... slots; the limit is ...`. Poprawka zmniejsza szerokości obu okien:

**Błędnie (pełny plan):**

```rql
DECLARE x INTEGER STREAM sensor, 1 TEXTFILE 'x.txt'
SELECT * STREAM first FROM sensor@(1,65536)
SELECT * STREAM result FROM first@(1,65536)
```

**Poprawnie (pełny plan):**

```rql
DECLARE x INTEGER STREAM sensor, 1 TEXTFILE 'x.txt'
SELECT * STREAM first FROM sensor@(1,32)
SELECT * STREAM result FROM first@(1,32)
```

**Testy i wymagania:** [Liczby, interwały i limity](../zalaczniki/testy-integracyjne.md#rql-tests-numbers).

## Nazwy strumieni, pola i zależności

### Nieznana nazwa lub indeks poza rekordem

Brak strumienia w `FROM`, brak pola w schemacie i indeks poza zakresem to trzy różne przyczyny. Indeks `src[2]` jest niepoprawny, ponieważ `src` ma dwie pozycje: `0` i `1`. Nazwa tablicy `a` sama nie wskazuje jednego elementu. Liczbową tablicę odczytaj przez `a[0]`, `a[1]` itd. albo przez płaski indeks strumienia.

| Fragment komunikatu | Błędnie | Poprawnie |
| --- | --- | --- |
| `which is not defined in the plan` | `SELECT * STREAM result FROM missing` | `SELECT * STREAM result FROM src` |
| `OUT_OF_BUSSINESS is reserved stream name` | `SELECT * STREAM OUT_OF_BUSSINESS FROM src` | `SELECT * STREAM result FROM src` |
| `has no field` | `SELECT src.temperature STREAM result FROM src` | `SELECT src.v STREAM result FROM src` |
| `out of range` | `SELECT src[2] STREAM result FROM src` | `SELECT src[1] STREAM result FROM src` |
| `not a single field` | `SELECT a STREAM result FROM vec` | `SELECT a[0] STREAM result FROM vec` |
| `out of range` | `SELECT a[3] STREAM result FROM vec` | `SELECT a[2] STREAM result FROM vec` |
| `which is not in its FROM clause` | `SELECT aux[0] STREAM result FROM src` | `SELECT aux[0] STREAM result FROM aux` |
| `contributes no contiguous block of fields` | `SELECT aux[_] STREAM result FROM src` | `SELECT aux[_] STREAM result FROM aux` |

Lista pól nie jest sposobem pobierania dowolnego innego strumienia z planu. Odczytuje rekord wejściowy wynikający z `FROM`. Jeżeli chcesz użyć pól z dwóch źródeł jednocześnie, skonstruuj odpowiednie wyrażenie w `FROM`, np. sumę strumieni, i odwołuj się do jego pól.

Zwykły `SELECT` może wskazywać producenta zdefiniowanego niżej w pliku, jeżeli cały plan jest acykliczny. Samo przestawienie deklaracji nie naprawia literówki ani cyklu. Inne zasady kolejności obowiązują dla `LET`, `VAR` oraz dołączania `RULE`: ich deklaracje lub cel muszą być już znane parserowi.

### Odczyt składowej po przeplocie

Komunikat `constituent of an interleave (#)` oznacza próbę odczytu nazwanej składowej przez operator `#`. Przeplot ma jeden wspólny schemat; `src[0]` nie wskazuje w nim wyłącznie rekordów pochodzących z `src`. Dotyczy to także `src.v`, `src[_]`, `src.*` i nazw pól rozpoznanych jako pola składowej.

| Fragment komunikatu | Błędnie | Poprawnie |
| --- | --- | --- |
| `constituent of an interleave (#)` | `SELECT src[0] STREAM result FROM src#out` | `SELECT result[0] STREAM result FROM src#out` |

Poprawny wariant odczytuje pierwszą pozycję wspólnego rekordu wejściowego. Jeśli celem jest odzyskanie konkretnej składowej, użyj rozplotu `&` lub `%` z odpowiednim interwałem, zamiast zastępować nazwę bez zmiany zamiaru obliczenia. Zasady opisują rozdziały o [przeplocie](polecenie-select/sekwencjonowanie-operacji-przeplotu.md) i [aliasowaniu](../kompilacja-zapytan/aliasowanie.md).

### Samoodwołanie i cykl

`a stream cannot be its own producer` oznacza bezpośredni odczyt własnego wyniku w `FROM`. `Circular dependency in stream definitions` oznacza, że zależności nie pozwalają wyznaczyć interwałów. W poprawnie sparsowanym planie trzeba usunąć cykl, a nie tylko zmienić kolejność wierszy.

| Fragment komunikatu | Błędnie | Poprawnie |
| --- | --- | --- |
| `a stream cannot be its own producer` | `SELECT * STREAM result FROM result` | `SELECT * STREAM result FROM src` |

**Błędnie:**

```rql
SELECT * STREAM first FROM second
SELECT * STREAM second FROM first
```

**Poprawnie:**

```rql
SELECT * STREAM first FROM second
SELECT * STREAM second FROM src
```

W poprawionej parze producent `second` nadal występuje po konsumencie, ale zależność kończy się w źródle `src`. Więcej: [Wykrywanie pętli w kompilacji](../kompilacja-zapytan/wykrywanie-petli.md).

**Testy i wymagania:** [Odwołania, indeksy, przeplot i cykle](../zalaczniki/testy-integracyjne.md#rql-tests-references).

## Operatory strumieniowe i funkcje

### Schematy przeplotu i interwał różnicy

`Hash operation needs same schemas on arguments stream` lub `HASH operation constraint failed` dotyczą niezgodnej liczby płaskich elementów argumentów `#`. Liczba pól musi być zgodna; typy i szerokości na odpowiadających sobie pozycjach są uzgadniane przez kompilator. W przykładzie dwupolowy `src` nie może być bezpośrednio przepleciony z jednopolowym `aux`. Najpierw wybierz potrzebną pozycję:

**Błędnie:**

```rql
SELECT * STREAM result FROM src#aux
```

**Poprawnie:**

```rql
SELECT src[0] STREAM scalar FROM src
SELECT * STREAM result FROM scalar#aux
```

`SUBTRACT interval constraint failed` oznacza próbę użycia operatora różnicy z interwałem docelowym krótszym od interwału źródła. Operator `-` w `FROM` służy wybieraniu rekordów z rzadszym lub równym taktem, nie przyspieszaniu strumienia.

| Fragment komunikatu | Błędnie | Poprawnie |
| --- | --- | --- |
| `SUBTRACT interval constraint failed` | `SELECT * STREAM result FROM src-1/2` | `SELECT * STREAM result FROM src-2` |

`src` ma interwał `1`, więc poprawiony cel `2` jest dopuszczalny. Wartość dobierz do wymaganego taktu aplikacji.

### Nieznana funkcja lub zły rodzaj wywołania

Kompilator sprawdza nazwę funkcji również w warunku reguły i w `DO SET`. Szerokość po dwukropku w zwykłym wywołaniu funkcji jest dostępna tylko dla `to_string`. Reduktor strumienia i agregacja okna rekordów mają inne argumenty: `MIN(src)` należy do `FROM`, natomiast `MIN(src[0]:3)` do listy pól.

| Fragment komunikatu | Błędnie | Poprawnie |
| --- | --- | --- |
| `not a known RQL function` | `SELECT Sqrtt(v) STREAM result FROM src` | `SELECT Sqrt(v) STREAM result FROM src` |
| `takes no width argument` | `SELECT Sqrt(v:16) STREAM result FROM src` | `SELECT Sqrt(v) STREAM result FROM src` |
| `expecting ':'` | `SELECT MIN(src) STREAM result FROM src` | `SELECT MIN(src[0]:3) STREAM result FROM src` |

W ostatnim wierszu poprawka wybiera agregację trzech rekordów historii jednego pola. Jeżeli zamiarem jest redukcja pól bieżącego rekordu, zapisz reduktor w `FROM`. Próby użycia samego słowa `MIN` jako pola kompilator odmawia komunikatem `reads the result of stream reducer ... directly`. Najpierw utwórz strumień z wynikiem redukcji:

**Błędnie:**

```rql
SELECT MIN STREAM result FROM MIN(src)
```

**Poprawnie:**

```rql
SELECT * STREAM reduced FROM MIN(src)
SELECT reduced[0] STREAM result FROM reduced
```

### Niedozwolony typ argumentu

Nie każda funkcja lub operacja przyjmuje wszystkie typy. Jednoargumentowy `-` nie przyjmuje `STRING`, a `~` przyjmuje tylko `BYTE` lub `UINT`. Funkcje `Sqrt`, `sin`, `cos`, `exp`, `tan`, `log` i `log2` odmawiają argumentu `RATIONAL`; potrzebna jest jawna konwersja do typu przybliżonego. Dotyczy to również wyników reduktorów strumieniowych, które dla argumentów całkowitych dają `RATIONAL`.

| Fragment komunikatu | Błędnie | Poprawnie |
| --- | --- | --- |
| `unary '-' is not defined for STRING` | `SELECT -label STREAM result FROM words` | `SELECT -to_double(label) STREAM result FROM words` |
| `is defined only for BYTE and UINT` | `SELECT ~v STREAM result FROM src` | `SELECT -v STREAM result FROM src` |

Pierwsza poprawka ma sens, gdy napis reprezentuje liczbę; niepoprawna konwersja wartości da `NULL` podczas wykonania. Druga realizuje arytmetyczną negację liczby całkowitej. Jeśli celem jest dopełnienie bitowe, źródło lub operand musi mieć typ `BYTE` albo `UINT`.

**Błędnie:**

```rql
SELECT * STREAM reduced FROM AVG(src)
SELECT Sqrt(reduced[0]) STREAM result FROM reduced
```

**Poprawnie:**

```rql
SELECT * STREAM reduced FROM AVG(src)
SELECT Sqrt(to_double(reduced[0])) STREAM result FROM reduced
```

W tym przypadku fragment komunikatu to `'Sqrt' over a RATIONAL value is not implemented`. Konwersja jest świadomym przejściem od wartości dokładnej do przybliżonej. Lista funkcji i zasady typów: [Wyrażenia pól i funkcje skalarne](polecenie-select/wyrazenia-pol-i-funkcje-skalarne.md).

**Testy i wymagania:** [Funkcje i typy operandów](../zalaczniki/testy-integracyjne.md#rql-tests-functions).

## Okna historyczne w liście SELECT

Agregacja `MIN/MAX/AVG/SUMC(wyrażenie:N)` odczytuje historię jednego strumienia. `FROM` musi więc być pojedynczym odwołaniem do strumienia, a argument musi odczytywać co najmniej jedno jego pole liczbowe. Nie można agregować samych stałych, napisów ani zagnieżdżać jednej agregacji okna w drugiej.

| Fragment komunikatu | Błędnie | Poprawnie |
| --- | --- | --- |
| `reads no field` | `SELECT AVG(1:3) STREAM result FROM src` | `SELECT AVG(src[0]:3) STREAM result FROM src` |
| `window aggregates are arithmetic` | `SELECT AVG(label:3) STREAM result FROM words` | `SELECT AVG(to_double(src[0]):3) STREAM result FROM src` |

Poprawka drugiego przykładu wybiera liczbowe źródło. Jeśli dane liczbowe są dostarczane jako tekst, utwórz najpierw osobny strumień z konwersją i agreguj jego wynik.

### Okno nad złożonym FROM

Komunikat `its FROM clause must be a single stream reference` wymaga wydzielenia transformacji strumieniowej do osobnego zapytania. Jeśli potrzebne jest okno nad sumą źródeł, najpierw utwórz strumień z tej sumy, a następnie czytaj jego historię.

**Błędnie:**

```rql
SELECT AVG(src[0]:3) STREAM result FROM src+aux
```

**Poprawnie:**

```rql
SELECT * STREAM joined FROM src+aux
SELECT AVG(joined[0]:3) STREAM result FROM joined
```

### Zagnieżdżenie okien

Komunikat `nests one window aggregate inside another` oznacza, że wewnętrzne wyniki nie mają jeszcze własnej historii. Utwórz dla nich osobny strumień:

**Błędnie:**

```rql
SELECT AVG(MIN(src[0]:3):4) STREAM result FROM src
```

**Poprawnie:**

```rql
SELECT MIN(src[0]:3) STREAM minima FROM src
SELECT AVG(minima[0]:4) STREAM result FROM minima
```

### Okno w regule lub DO SET

`uses a window aggregate in a RULE condition` i `uses a window aggregate in DO SET` oznaczają niedozwolone miejsce agregacji. Reguła korzysta z gotowego rekordu strumienia. Najpierw oblicz agregację w `SELECT`, a regule przekaż jej pole wynikowe:

**Błędnie:**

```rql
RULE alarm ON out WHEN AVG(out[0]:3) > 10 DO DUMP -1 TO 1
```

**Poprawnie:**

```rql
SELECT AVG(src[0]:3) STREAM mean FROM src
RULE alarm ON mean WHEN mean[0] > 10 DO DUMP -1 TO 1
```

Ta sama metoda dotyczy wartości przypisywanej przez `DO SET`. Dodatkowo zmienna `VAR` nie może występować wewnątrz argumentu okna: zmienia się w czasie wykonania, a historia przechowuje rekordy źródła, nie dawne wartości zmiennej. Pełne zasady: [Operatory agregujące](polecenie-select/operatory-agregujace.md).

**Testy i wymagania:** [Okna historyczne](../zalaczniki/testy-integracyjne.md#rql-tests-windows).

## LET, VAR i DO SET

### Użycie przed deklaracją, nazwa i typ stałej

Nazwy `LET` i `VAR` mają wspólną przestrzeń nazw i rozróżniają wielkość liter. Odwołanie ma postać `?N`, bez spacji po `?`. Deklaracja musi wystąpić przed pierwszym użyciem i nie może być powtórzona. Nazwa nie może zawierać `$`. Prawa strona deklaracji jest pojedynczym literałem liczbowym, nie wyrażeniem arytmetycznym.

**Błędnie (pełny plan):**

```rql
DECLARE x INTEGER[?N] STREAM sensor, 1 BINFILE 'x.bin'
LET N = 3
```

**Poprawnie (pełny plan):**

```rql
LET N = 3
DECLARE x INTEGER[?N] STREAM sensor, 1 BINFILE 'x.bin'
```

Przyczynę wskazuje `is not declared; LET must precede its first use`. Komunikat `is already declared` wymaga usunięcia drugiej deklaracji lub nadania jej innej nazwy. Samo zadeklarowanie `VAR` o nazwie użytej już przez `LET` również jest powtórzeniem.

**Błędnie:**

```rql
LET N = 3
VAR N = 0
```

**Poprawnie:**

```rql
LET N = 3
VAR COUNT = 0
```

### Stała w niewłaściwym kontekście

Rozmiar tablicy, indeks pola i szerokość okna wymagają wartości całkowitej. Przy adnotacji typu te konteksty przyjmują `INTEGER`. Interwały przyjmują stałe bez adnotacji lub z adnotacją `INTEGER` albo `RATIONAL`. Ułamek `LET` bez adnotacji może określać interwał, ale nie ma bezpośredniej postaci literału w wyrażeniu skalarnym; dla dokładnej wartości w polu użyj `: RATIONAL`.

**Błędnie:**

```rql
LET SCALE = 1/2
SELECT src[0]*?SCALE STREAM result FROM src
```

**Poprawnie:**

```rql
LET SCALE : RATIONAL = 1/2
SELECT src[0]*?SCALE STREAM result FROM src
```

Fragment komunikatu: `is a fraction, which an expression has no literal for`. Inne odmowy tej grupy to `is not an integer`, `cannot be used in ...` i `is out of range for ...`. Typ `INTEGER` nie przyjmie wartości `1.5`; konwersja literału w deklaracji do typu całkowitego musi być dokładna. Typy `BYTE` i `STRING` nie są dozwolonymi adnotacjami `LET` ani `VAR`.

Przykład odmowy `is not an integer` dla szerokości okna:

**Błędnie:**

```rql
LET N = 1.5
SELECT AVG(src[0]:?N) STREAM result FROM src
```

**Poprawnie:**

```rql
LET N : INTEGER = 3
SELECT AVG(src[0]:?N) STREAM result FROM src
```

### Zmienna w miejscu określającym strukturę planu

`variable ?N cannot be used in ...` oznacza użycie zmiennej wykonania jako parametru, który musi być ustalony podczas kompilacji, np. szerokości okna, rozmiaru rodziny lub interwału. Jeżeli wartość ma określać strukturę, zadeklaruj stałą:

**Błędnie:**

```rql
VAR N = 3
SELECT AVG(src[0]:?N) STREAM result FROM src
```

**Poprawnie:**

```rql
LET N = 3
SELECT AVG(src[0]:?N) STREAM result FROM src
```

### Niedozwolony cel lub typ przypisania

Cel `DO SET` musi być zadeklarowaną zmienną `VAR`. Próba zmiany `LET` daje `cannot be the target of DO SET`; nieznana nazwa daje `VAR must precede its first use`.

**Błędnie:**

```rql
LET COUNT = 0
RULE increase ON out WHEN out[0] > 0 DO SET ?COUNT = ?COUNT+1
```

**Poprawnie:**

```rql
VAR COUNT = 0
RULE increase ON out WHEN out[0] > 0 DO SET ?COUNT = ?COUNT+1
```

Złożone wyrażenie po prawej stronie musi mieć typ zmiennej. Komunikat `no implicit conversion` wymaga jawnego rzutowania albo zmiany typu deklaracji. Samodzielny literal lub odwołanie do stałej `LET` może być konwertowane do typu celu, jeśli wartość da się w nim przedstawić; nie oznacza to automatycznej konwersji dowolnego wyrażenia.

**Błędnie:**

```rql
VAR LEVEL = 0
RULE update ON out WHEN out[0] > 0 DO SET ?LEVEL = to_double(out[0])+0.5
```

**Poprawnie:**

```rql
VAR LEVEL : DOUBLE = 0
RULE update ON out WHEN out[0] > 0 DO SET ?LEVEL = to_double(out[0])+0.5
```

Poprawka zachowuje część ułamkową przez zmianę typu zmiennej na `DOUBLE`. Jeśli aplikacja potrzebuje liczby całkowitej, można zamiast tego jawnie użyć `to_integer` dla całego wyrażenia, uwzględniając obcięcie części ułamkowej. Szczegóły: [LET](polecenie-let.md) oraz [VAR i DO SET](polecenie-var.md).

**Testy i wymagania:** [Stałe LET i adnotacje typu](../zalaczniki/testy-integracyjne.md#rql-tests-constants); [Zmienne VAR i przypisania DO SET](../zalaczniki/testy-integracyjne.md#rql-tests-variables).

## Generatory rodzin strumieni

Rodzina `STREAM cell[N]` rozwija się do `N` strumieni. `$` oznacza numer instancji i ma sens wyłącznie w generatorze. Rozmiar musi być dodatni, szablon musi używać `$`, a po rozwinięciu wszystkie indeksy muszą mieścić się w źródle.

| Fragment komunikatu | Błędnie | Poprawnie |
| --- | --- | --- |
| `uses '$' outside a stream generator` | `SELECT $ STREAM result FROM vec` | `SELECT $ STREAM cell[3] FROM vec` |
| `uses no '$'` | `SELECT vec[0] STREAM cell[3] FROM vec` | `SELECT vec[$] STREAM cell[3] FROM vec` |
| `must be greater than zero` | `SELECT vec[$] STREAM cell[0] FROM vec` | `SELECT vec[$] STREAM cell[3] FROM vec` |
| `out of range` | `SELECT vec[$] STREAM cell[4] FROM vec` | `SELECT vec[$] STREAM cell[3] FROM vec` |
| `must not carry a FILE directive` | `SELECT vec[$] STREAM cell[3] FROM vec FILE 'wspolny.bin'` | `SELECT vec[$] STREAM cell[3] FROM vec` |
| `is not a stream generator` | `SELECT * STREAM result FROM src[0]` | `SELECT * STREAM result FROM src` |

`src[0]` w liście pól oznacza pozycję rekordu, ale w `FROM` zapis `cell[0]` wskazuje instancję rodziny. Zwykłego strumienia nie indeksuje się w `FROM`.

**Błędnie:**

```rql
SELECT vec[$] STREAM cell[3] FROM vec
SELECT * STREAM result FROM cell[3]
```

**Poprawnie:**

```rql
SELECT vec[$] STREAM cell[3] FROM vec
SELECT * STREAM result FROM cell[2]
```

Komunikat `outside the range 0..2` dotyczy indeksu rodziny. Instancje są numerowane `0`, `1`, `2`. Odrzucane są też ujemne i niemieszczące się w `int` wyniki wyrażeń indeksu, powtórzone rodziny (`is declared more than once`) oraz kolizje wygenerowanych nazw (`collides with a stream that already exists`). Zmień indeks, rozmiar lub nazwę rodziny zgodnie z zamiarem obliczenia.

Reguła `DO SET` na rodzinie daje komunikat `instances would write one variable in the same slot`. Każda instancja próbowałaby zmienić tę samą zmienną. Dołącz regułę do pojedynczego, nazwanego wyniku `SELECT`, który czyta wybraną instancję, albo do osobnego strumienia zbierającego wyniki rodziny.

**Błędnie:**

```rql
VAR COUNT = 0
SELECT vec[$] STREAM cell[3] FROM vec
RULE increase ON cell WHEN cell[0] > 0 DO SET ?COUNT = ?COUNT+1
```

**Poprawnie:**

```rql
VAR COUNT = 0
SELECT vec[$] STREAM cell[3] FROM vec
SELECT * STREAM chosen FROM cell[0]
RULE increase ON chosen WHEN chosen[0] > 0 DO SET ?COUNT = ?COUNT+1
```

**Testy i wymagania:** [Rodziny strumieni](../zalaczniki/testy-integracyjne.md#rql-tests-generators).

## Reguły RULE

### Cel reguły i dostępne pola

`RULE` dołącza się do istniejącego już wyniku `SELECT`. Nie można dołączyć jej do `DECLARE`. Warunek i `DO SET` czytają rekord wyjściowy strumienia z `ON`, a nie dowolne źródło jego obliczeń. Nazwy i indeksy w regule zapisuj względem tego wyniku.

| Fragment komunikatu | Błędnie | Poprawnie |
| --- | --- | --- |
| `but no such stream is defined` | `RULE alarm ON missing WHEN 1 DO DUMP -1 TO 1` | `RULE alarm ON out WHEN 1 DO DUMP -1 TO 1` |
| `cannot be attached to declaration stream` | `RULE alarm ON src WHEN src[0] > 0 DO DUMP -1 TO 1` | `RULE alarm ON out WHEN out[0] > 0 DO DUMP -1 TO 1` |
| `reads only the record of the stream it is attached to` | `RULE alarm ON out WHEN src[0] > 0 DO DUMP -1 TO 1` | `RULE alarm ON out WHEN out[0] > 0 DO DUMP -1 TO 1` |
| `out of range` | `RULE alarm ON out WHEN out[2] > 0 DO DUMP -1 TO 1` | `RULE alarm ON out WHEN out[1] > 0 DO DUMP -1 TO 1` |

### Powtórzona nazwa i zakres DUMP

Komunikat `is already defined on stream` oznacza powtórzenie nazwy reguły na tym samym strumieniu. Zmień nazwę drugiej reguły albo usuń powtórzenie. Ta sama nazwa może wystąpić na innym strumieniu, o ile nie prowadzi do kolizji nazwy pliku zrzutu.

**Błędnie:**

```rql
RULE alarm ON out WHEN out[0] > 10 DO DUMP -1 TO 1
RULE alarm ON out WHEN out[1] > 20 DO DUMP -1 TO 1
```

**Poprawnie:**

```rql
RULE alarm_v ON out WHEN out[0] > 10 DO DUMP -1 TO 1
RULE alarm_w ON out WHEN out[1] > 20 DO DUMP -1 TO 1
```

Granice `DUMP L TO R` muszą spełniać `L < R`. Zakres jest półotwarty `[L,R)`. Dozwolone są także obie granice ujemne, np. `-5 TO -2`.

| Fragment komunikatu | Błędnie | Poprawnie |
| --- | --- | --- |
| `left bound must be less than right bound` | `RULE alarm ON out WHEN out[0] > 0 DO DUMP 2 TO 2` | `RULE alarm ON out WHEN out[0] > 0 DO DUMP -2 TO 2` |
| `exceeds the limit 256` | `RULE alarm ON out WHEN out[0] > 0 DO DUMP -1 TO 1 RETENTION 257` | `RULE alarm ON out WHEN out[0] > 0 DO DUMP -1 TO 1 RETENTION 8` |

`would write the same dump file as rule` dotyczy kolizji nazw plików. Przykładowo pary: strumień `a`, reguła `b_c` oraz strumień `a_b`, reguła `c` dają wspólny rdzeń `a_b_c`. Porównanie ignoruje wielkość liter. Zmień nazwę reguły lub strumienia tak, aby rdzenie były różne. Szczegóły: [Polecenie RULE](polecenie-rule.md).

**Błędnie:**

```rql
SELECT * STREAM a FROM src
SELECT * STREAM a_b FROM src
RULE b_c ON a WHEN a[0] > 0 DO DUMP -1 TO 1
RULE c ON a_b WHEN a_b[0] > 0 DO DUMP -1 TO 1
```

**Poprawnie:**

```rql
SELECT * STREAM a FROM src
SELECT * STREAM a_b FROM src
RULE b_c ON a WHEN a[0] > 0 DO DUMP -1 TO 1
RULE alarm ON a_b WHEN a_b[0] > 0 DO DUMP -1 TO 1
```

**Testy i wymagania:** [Cele RULE, zakresy DUMP i nazwy zrzutów](../zalaczniki/testy-integracyjne.md#rql-tests-rules).

## Źródła, magazyny i dyrektywy

### Opcje niepasujące do rodzaju źródła

`DEVICE` nie przyjmuje `DISPOSABLE` ani `HOLD`; te opcje dotyczą plików `BINFILE` i `TEXTFILE`. `TIMEOUT` jest dozwolony tylko przy `DEVICE`, w zakresie od `0` do `86400` sekund. Zero jest tu poprawne, chociaż jest zabronione jako interwał strumienia.

| Fragment komunikatu | Błędnie | Poprawnie |
| --- | --- | --- |
| `DEVICE does not take HOLD` | `DECLARE x BYTE STREAM sensor, 1 DEVICE '/dev/zero' HOLD` | `DECLARE x BYTE STREAM sensor, 1 DEVICE '/dev/zero'` |
| `DEVICE does not take DISPOSABLE` | `DECLARE x BYTE STREAM sensor, 1 DEVICE '/dev/zero' DISPOSABLE` | `DECLARE x BYTE STREAM sensor, 1 DEVICE '/dev/zero'` |
| `TIMEOUT applies to DEVICE` | `DECLARE x INTEGER STREAM sensor, 1 TEXTFILE 'x.txt' TIMEOUT 1` | `DECLARE x INTEGER STREAM sensor, 1 TEXTFILE 'x.txt'` |
| `must not be negative` | `DECLARE x BYTE STREAM sensor, 1 DEVICE '/dev/zero' TIMEOUT -1` | `DECLARE x BYTE STREAM sensor, 1 DEVICE '/dev/zero' TIMEOUT 0` |
| `exceeds the limit 86400 s` | `DECLARE x BYTE STREAM sensor, 1 DEVICE '/dev/zero' TIMEOUT 86401` | `DECLARE x BYTE STREAM sensor, 1 DEVICE '/dev/zero' TIMEOUT 1` |
| `requires a non-empty file name` | `DECLARE x INTEGER STREAM sensor, 1 TEXTFILE ''` | `DECLARE x INTEGER STREAM sensor, 1 TEXTFILE 'x.txt'` |

Jeżeli dane pochodzą z urządzenia lub FIFO, wybierz `DEVICE` zgodnie z rodzajem rzeczywistego źródła. Zmiana słowa kluczowego bez zmiany rodzaju źródła może przejść kompilację, a zostać odrzucona podczas uruchamiania. Kolejność opcji określa gramatyka: `TIMEOUT`, `DISPOSABLE`, `ONESHOT`, `HOLD`. Szczegóły: [Opcje odczytu](polecenie-declare-opcje-odczytu.md).

### Niepoprawny profil lub pusta dyrektywa

`STORAGE` przy `SELECT` i dyrektywa `SUBSTRAT` przyjmują profile zapisywalne: `DEFAULT`, `MEMORY`, `DIRECT`, `POSIX`, `POSIXSHD`, `GENERIC`. `DEVICE`, `BINFILE` i `TEXTFILE` określają źródła `DECLARE`; nie są profilami wyniku. Dyrektywy `STORAGE`, `SUBSTRAT` i `ROTATION` wymagają niepustej wartości w apostrofach.

| Fragment komunikatu | Błędnie | Poprawnie |
| --- | --- | --- |
| `is not a storage profile` | `SELECT v STREAM result FROM src STORAGE DEVICE` | `SELECT v STREAM result FROM src STORAGE MEMORY` |
| `is not a storage profile` | `SUBSTRAT 'textsource'` | `SUBSTRAT 'memory'` |
| `requires a non-empty value` | `ROTATION ''` | `ROTATION 'rotation_counter.txt'` |
| `requires a non-empty file name` | `SELECT v STREAM result FROM src FILE ''` | `SELECT v STREAM result FROM src FILE 'wynik.bin'` |

### Konflikt VOLATILE, PERSISTENT i DEFAULT VOLATILE

`PERSISTENT conflicts with STORAGE MEMORY` wskazuje sprzeczne wymagania trwałości. Gramatyka dopuszcza tylko jedną z klauzul `VOLATILE` lub `PERSISTENT`. W zapytaniu klauzule mają kolejność: `FILE`, `RETENTION`, `VOLATILE` albo `PERSISTENT`, `STORAGE`.

| Fragment komunikatu | Błędnie | Poprawnie |
| --- | --- | --- |
| `PERSISTENT conflicts with STORAGE MEMORY` | `SELECT v STREAM result FROM src PERSISTENT STORAGE MEMORY` | `SELECT v STREAM result FROM src PERSISTENT STORAGE DEFAULT` |

`DEFAULT VOLATILE` może wystąpić tylko raz, przed `DECLARE`, `SELECT` i `RULE`. Powtórzenie daje `DEFAULT VOLATILE may occur only once`, a spóźniona dyrektywa `DEFAULT VOLATILE must precede DECLARE, SELECT and RULE`.

**Błędnie (pełny plan):**

```rql
DECLARE x INTEGER STREAM sensor, 1 TEXTFILE 'x.txt'
DEFAULT VOLATILE
SELECT * STREAM result FROM sensor
```

**Poprawnie (pełny plan):**

```rql
DEFAULT VOLATILE
DECLARE x INTEGER STREAM sensor, 1 TEXTFILE 'x.txt'
SELECT * STREAM result FROM sensor
```

### Postać retencji niezgodna z magazynem

`RETENTION N` określa pierścień w pamięci i wymaga `STORAGE MEMORY`, `VOLATILE` albo odziedziczonego `DEFAULT VOLATILE`. Magazyn segmentowy na dysku wymaga dwóch argumentów: `RETENTION pojemność liczba_segmentów`. Drugi argument przy magazynie pamięciowym jest błędem. Wartość `0` jako liczba segmentów oznacza brak ograniczenia ich liczby, nie pusty magazyn.

| Fragment komunikatu | Błędnie | Poprawnie |
| --- | --- | --- |
| `sets only the size of a MEMORY ring` | `SELECT v STREAM result FROM src RETENTION 5` | `SELECT v STREAM result FROM src RETENTION 5 2` |
| `sets segments on disk` | `SELECT v STREAM result FROM src RETENTION 5 2 STORAGE MEMORY` | `SELECT v STREAM result FROM src RETENTION 5 STORAGE MEMORY` |

Pierwsza poprawka wybiera retencję na dysku. Jeśli potrzebny jest RAM, zachowaj jeden argument i dopisz `VOLATILE` lub `STORAGE MEMORY`.

### Retencja za krótka dla odczytów historii

`keeps only ... record(s) on disk ... but the plan reads ... record(s) back from it` oznacza, że plan może sięgnąć do segmentu, który został już usunięty. Zwiększ pojemność lub liczbę segmentów albo zmniejsz wymagany zasięg historii.

**Błędnie:**

```rql
SELECT v STREAM kept FROM src RETENTION 2 2
SELECT * STREAM result FROM kept>6
```

**Poprawnie:**

```rql
SELECT v STREAM kept FROM src RETENTION 10 2
SELECT * STREAM result FROM kept>6
```

Dla `RETENTION C S` z `S > 0` po rozpoczęciu nowego segmentu gwarantowana liczba zachowanych rekordów wynosi `(S-1)*C+1`, a nie `S*C`. Z tego powodu samo pomnożenie obu argumentów może prowadzić do błędnego oszacowania. To samo sprawdzenie obejmuje retencję domyślną z konfiguracji TOML. Szczegóły: [Typy STORAGE](polecenie-select/typy-storage.md).

### Budżet pamięci historii

Komunikat `Plan keeps ... bytes of stream history in memory; the budget [limits] history_memory_mib = ...` dotyczy sumy historii źródeł i magazynów pamięciowych. Zawiera również nazwę strumienia o największym udziale, liczbę rekordów i ich wielkość. Zmniejsz okna, przesunięcia lub szerokość rekordów; dla wyników pośrednich rozważ magazyn dyskowy. Zwiększenie budżetu w TOML ma sens dopiero po sprawdzeniu dostępnej pamięci. Samo przejście na `VOLATILE` nie zmniejsza wymaganej długości historii.

Przykład dla domyślnego budżetu pamięci historii: rekord długości 65536 bajtów i przesunięcie o 65536 rekordów wymagają historii wielokrotnie przekraczającej ten budżet. Oba argumenty osobno mieszczą się w limitach parsera. Poprawka zmniejsza zasięg odczytu historii:

**Błędnie (pełny plan):**

```rql
DECLARE text STRING[65536] STREAM wide, 1 BINFILE 'szerokie.bin'
SELECT * STREAM result FROM wide>65536 VOLATILE
```

**Poprawnie (pełny plan):**

```rql
DECLARE text STRING[65536] STREAM wide, 1 BINFILE 'szerokie.bin'
SELECT * STREAM result FROM wide>10 VOLATILE
```

**Testy i wymagania:** [Źródła, dyrektywy i retencja](../zalaczniki/testy-integracyjne.md#rql-tests-storage).

## Co nie jest błędem składni

Udana kompilacja nie potwierdza dostępności urządzenia, istnienia pliku wejściowego, zgodności zachowanego deskryptora ani prawa zapisu do katalogu. Komunikaty takie jak `source file does not exist`, `descriptor schema mismatch` i `directory ... does not exist` odnoszą się do źródeł lub stanu magazynów, sprawdzanych przy uruchamianiu i innych ścieżkach ładowania planu. Przyczynę usuwa się przez poprawienie ścieżki, danych, uprawnień lub uzgodnienie magazynu z planem. Nie należy w ciemno usuwać artefaktów tylko dlatego, że parser zaakceptował zapytanie.

Również obliczenie `v/0` lub niepoprawna konwersja tekstu na liczbę może przejść kompilację i dać `NULL` przy wykonaniu. Nie jest to to samo co zerowy mianownik **interwału** `1/0`, który parser odrzuca. Ostrzeżenie o nieużywanej stałej, przestarzałej notacji lub nieograniczonym wzroście magazynu również nie oznacza odmowy kompilacji. Rozróżniaj ostrzeżenie, niepoprawny plan i wynik obliczenia.

## Podstawa katalogu i dalsza diagnostyka

Katalog opiera się na kontrolach w bieżącej implementacji, a nie wyłącznie na diagramach gramatyki:

| Źródło | Zakres komunikatów |
| --- | --- |
| [RQL.g4](https://github.com/michalwidera/retractordb/blob/dfcc42d2a5fee2efa0b531d682766e4b7b9b73bb/src/retractor/lib/RQL.g4) | Budowa poleceń, kolejność klauzul, rozróżnienie wyrażeń skalarnych, logicznych i strumieniowych. |
| [RQLParser.cpp](https://github.com/michalwidera/retractordb/blob/dfcc42d2a5fee2efa0b531d682766e4b7b9b73bb/src/retractor/lib/RQLParser.cpp) | Pozycje błędów, liczby i wymiary, opcje źródeł, `LET`/`VAR`, dołączanie reguł, dyrektywy i postać retencji. |
| [compiler.cpp](https://github.com/michalwidera/retractordb/blob/dfcc42d2a5fee2efa0b531d682766e4b7b9b73bb/src/retractor/lib/compiler.cpp) | Odwołania, zależności, operatory, generatory, okna, funkcje, przypisania i zasoby historii. |
| [expressionShape.cpp](https://github.com/michalwidera/retractordb/blob/dfcc42d2a5fee2efa0b531d682766e4b7b9b73bb/src/retractor/lib/expressionShape.cpp) | Odmowy niedozwolonych kombinacji operatora lub funkcji z typem argumentu. |
| [launcher.cpp](https://github.com/michalwidera/retractordb/blob/dfcc42d2a5fee2efa0b531d682766e4b7b9b73bb/src/retractor/launcher.cpp) | Kanały `Parse result:` i `Check result:`, kod odmowy planu oraz zakończenie trybu `-c`. |
| [test_compiler.cpp](https://github.com/michalwidera/retractordb/blob/dfcc42d2a5fee2efa0b531d682766e4b7b9b73bb/test/UnitTest/test_compiler.cpp) | Przypadki odmowy i poprawne warianty kontrolne dla parsera i kompilatora. |

Odnośniki utrwalają rewizję kodu użytą przy opracowaniu rozdziału. Komunikaty o wewnętrznie uszkodzonych tokenach i naruszonych niezmiennikach nie mają pary „błędne/poprawne RQL”: wymagają zgłoszenia defektu. Gdy zapis jest poprawny, ale plan różni się od oczekiwań, użyj [narzędzi debugowania kompilacji](../kompilacja-zapytan/debugowanie-kompilacji.md), a szczegóły kolejności kontroli sprawdź w [Przebiegach kompilacji](../kompilacja-zapytan/przebiegi-kompilacji.md).
