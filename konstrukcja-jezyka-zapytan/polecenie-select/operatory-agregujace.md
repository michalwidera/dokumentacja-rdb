# Operatory agregujące

## Dwie osie agregacji (MIN, MAX, AVG, SUMC)

Te same cztery słowa kluczowe opisują dwie różne konstrukcje. Po stronie `FROM` reduktor
zwija pola jednego bieżącego rekordu. W liście `SELECT` agregat okna rekordowego zwija jedną
wartość wyrażenia obliczoną dla każdego z kolejnych rekordów historii. Położenie konstrukcji
rozstrzyga zatem, czy redukcja biegnie poziomo po polach, czy pionowo po czasie.

## Reduktory bieżącego rekordu w FROM

Reduktory strumieniowe działają na strumieniu posiadającym wiele pól — typowo na wyniku
operatora `@(k,w)` albo na rekordzie zawierającym tablicę liczbową. Redukują wszystkie
płaskie sloty jednego rekordu do jednej wartości.

### Składnia

```
FROM AGREGATOR(wyrażenie_strumieniowe)
```

gdzie `AGREGATOR` to jedno z:

| Słowo kluczowe | Działanie |
|----------------|-----------|
| `min`  / `MIN` | minimum ze wszystkich pól rekordu |
| `max`  / `MAX` | maksimum ze wszystkich pól rekordu |
| `avg`  / `AVG` | średnia arytmetyczna pól rekordu |
| `sumc` / `SUMC`| suma wszystkich pól rekordu |

Słowa kluczowe akceptowane są zarówno małymi, jak i wielkimi literami. Są zastrzeżone, dlatego strumień nie może nazywać się `min`, `MAX`, `avg` ani `SUMC`.

Argumentem może być całe wyrażenie strumieniowe, nie tylko pojedyncza nazwa. Dzięki temu okno i redukcję można zapisać bez pomocniczego zapytania:

```rql
SELECT * STREAM total FROM SUMC(src@(1,5))
```

Postać przyrostkowa `strumień.min`, `.max`, `.avg` i `.sumc` pozostaje zgodna wstecz, ale jest wygaszana. Parser emituje ostrzeżenie i zaleca postać funkcyjną. Dotychczasowy zapis `src@(1,5).sumc` jest poprawny, lecz nowe zapytania powinny używać `SUMC(src@(1,5))`.

### Pola tablicowe i wartości NULL

Liczbowa deklaracja `T[N]` jest jednym wpisem deskryptora, ale zajmuje `N` płaskich slotów
rekordu. Reduktor odwiedza wszystkie te sloty. Dlatego poniższe zapytanie liczy minimum ze
wszystkich 24 ogniw bieżącego rekordu, a nie tylko z `cells[0]`:

```rql
DECLARE cells INTEGER[24] STREAM battery, 1 FILE 'cells.txt'
SELECT * STREAM cell_min FROM MIN(battery)
```

Schematy strumieni pochodnych rozwijają tablice liczbowe do pól skalarnych, zachowując
kolejność slotów i układ bajtów. `STRING[N]` jest natomiast jednym polem tekstowym o
szerokości N bajtów, nie tablicą N liczb.

Wartości `NULL` są pomijane. Jeżeli wszystkie sloty rekordu mają wartość `NULL`, wynikiem
redukcji jest `NULL`, a nie zero.

### Interwał wyjściowy

Agregaty nie zmieniają częstotliwości strumienia — interwał wyniku jest taki sam jak źródła:

\\[\Delta_{wynik} = \Delta_{strumień}\\]

### Typ wyniku

Typ wyniku zależy od typu wartości wejściowych:

| Typ wejściowy | Typ wyniku `MIN`/`MAX`/`AVG`/`SUMC` |
| ------------- | ------------------------------------ |
| `BYTE`, `INTEGER`, `UINT`, `RATIONAL` | `RATIONAL` |
| `FLOAT` | `FLOAT` |
| `DOUBLE` | `DOUBLE` |

Dla typów całkowitych i wymiernych rachunek idzie po liczbach wymiernych, więc `AVG` nie
traci reszty z dzielenia. Dotyczy to także `MIN` i `MAX`: minimum trzech siódemek ma typ
`RATIONAL` i wartość `7/1`, a nie typ `INTEGER`. `FLOAT` i `DOUBLE` zachowują swój typ;
artefakt z takim wejściem nie zmienia się w pole `RATIONAL`.

Odbiorca pola `RATIONAL` musi znać układ pary licznik-mianownik
(→ [Układ pola RATIONAL](../../architektura-systemu-przetwarzania-danych/format-zapisu-danych/pliki.md#układ-pola-rational))
albo jawnie przepuścić wynik przez `to_string`, `to_double` lub `to_integer`.

### Przykład: średnia z rekordu okna AGSE

```
DECLARE val INTEGER STREAM src, 1 FILE 'data.txt'

-- AGSE buduje rekord z pięciu próbek, AVG redukuje jego pięć pól
SELECT * STREAM ma5 FROM AVG(src@(1,5))
```

Strumień `ma5` zawiera w każdej chwili średnią z pięciu kolejnych próbek `src`. Jest to
kompozycja operatora AGSE z reduktorem rekordu, a nie agregat z listy `SELECT` opisany niżej.

### Przykład: filtr sygnałowy (sumc)

Fragment z przykładu implementacji filtru sygnałowego:

```rql
SELECT source[_] * filter[_] STREAM accRow FROM source@(1,25)+filter
SELECT accRow[0] STREAM output FROM SUMC(accRow)
```

Okno znajduje się bezpośrednio w `FROM`, więc nie wymaga osobnego zapytania. `source[_]` rozwija się zgodnie z 25 slotami, które `source@(1,25)` wnosi do rekordu wejściowego. `SUMC(accRow)` sumuje wszystkie pola rekordu `accRow` — iloczyny próbek sygnału przez współczynniki filtru — produkując wyjście filtru FIR.

### Przykład: MIN i MAX

```
DECLARE v INTEGER STREAM src, 0.1 FILE '/dev/urandom'
SELECT * STREAM min10 FROM MIN(src@(1,10))
SELECT * STREAM max10 FROM MAX(src@(1,10))
```

> **_NOTE:_** Reduktory bieżącego rekordu mają pokrycie w testach `simple_max`,
> `wide_from_names`, `agse_array` i `array_derived`, opisanych w załączniku
> [Testy integracyjne](../../zalaczniki/testy-integracyjne.md).

---

## Agregaty okna rekordowego w SELECT

### Składnia

```rql
SELECT wyrażenie_z_AGREGATOR(wartość_rekordu : szerokość) \
STREAM wynik FROM źródło
```

Sam `AGREGATOR(wartość_rekordu : szerokość)` jest operandem zwykłego wyrażenia pola. Można
go łączyć z literałami, innymi polami, operatorami arytmetycznymi i funkcjami skalarnymi:

```rql
SELECT 2*MIN(a : 5)+1, null2zero(AVG(a+b : 5))-10 \
STREAM transformed FROM src
```

Nie wolno jedynie zagnieżdżać agregatu okna w argumencie innego agregatu okna.
`szerokość` jest dodatnią liczbą rekordów. Dla rekordu wynikowego o indeksie logicznym `n`
agregat oblicza `wartość_rekordu` osobno na rekordach źródła od `n-(szerokość-1)` do `n`, a
następnie redukuje dokładnie te wartości. Okno jest stemplowane końcem i przesuwa się o jeden rekord.
Interwał wyniku pozostaje równy interwałowi źródła, początek logiczny przesuwa się o
`szerokość-1`, a ogon startowy jest dziedziczony ze źródła.

```rql
DECLARE a INTEGER, b INTEGER STREAM src, 1 FILE 'data.txt'

SELECT MIN(a : 5), MAX(a : 5), AVG(a+b : 5), SUMC(a : 5) \
STREAM stats FROM src
```

Kilka agregatów nad tym samym wyrażeniem, źródłem i szerokością współdzieli jedno przejście
po historii. Wartości `NULL` są pomijane; okno bez ani jednej wartości obecnej daje `NULL`.
Typ wyniku podlega tej samej tabeli promocji co reduktor bieżącego rekordu, a ustalony typ
jest zachowywany przez czyste kopie, przesunięcia i pozostałe operatory kopiujące schemat.

### Ograniczenia argumentu

Argument musi być liczbowym wyrażeniem odczytującym co najmniej jedno pole jednego
przechowywanego źródła. Zapytanie z agregatem okna rekordowego musi mieć w `FROM` pojedyncze,
zwykłe odwołanie do strumienia. Kompilator odrzuca:

- szerokość niedodatnią;
- wyrażenie tekstowe albo stałe, które nie odczytuje pola;
- wyrażenie mieszające historię kilku strumieni;
- zagnieżdżony agregat okna i użycie agregatu w warunku `RULE`;
- złożoną klauzulę `FROM`, na przykład `FROM src - 2`;
- gołą nazwę tablicy liczbowej.

Dla `DECLARE a INTEGER[3]` trzeba wskazać jeden kanał, na przykład `MIN(a[0] : 5)`.
`MIN(a : 5)` nie oznacza wszystkich elementów tablicy z każdego rekordu i zostaje odrzucone. Redukcję
wszystkich elementów jednego rekordu zapisuje się osobno jako `FROM MIN(strumień)`.

### Łączenie redukcji po kanałach i po czasie

Obie osie można składać bez serializacji tablicy i bez ręcznego tworzenia osobnego
strumienia dla każdego kanału:

```rql
DECLARE value INTEGER[24] STREAM sensors, 1/10 FILE 'sensors.txt'

SELECT * STREAM row_min FROM MIN(sensors)
SELECT MIN(row_min[0] : 10) STREAM interval_min FROM row_min
```

Pierwszy `MIN` redukuje 24 równoległe wartości jednego rekordu. Drugi redukuje wyniki z
dziesięciu kolejnych rekordów, więc `interval_min` jest minimum z 240 wartości, ale zachowuje
interwał źródła i emituje przesuwne okno po każdym rekordzie. Jeżeli potrzebny jest wynik
rzadszy, należy rozrzedzić gotowy strumień zgodnie z następną sekcją.

### Hopping window

Agregat w `SELECT` nie ma argumentu kroku. Hopping window powstaje przez rozrzedzenie
gotowego strumienia okien operatorem `-` w drugim węźle:

```rql
SELECT MIN(a : 5) STREAM sliding FROM src
SELECT * STREAM hopping FROM sliding - 2
```

Argument operatora `-` jest docelowym interwałem wyniku. Dla skoku H nad źródłem o
interwale \(\Delta\) należy podać \(H\Delta\). Rozdzielenie na dwa węzły zachowuje w każdym
oknie pięć kolejnych rekordów i dopiero potem wybiera co H-ty wynik. Bezpośrednie
`SELECT MIN(a : 5) ... FROM src - 2` nie jest skrótem tej konstrukcji i nie kompiluje się.

> **_NOTE:_** Składnię, typy, brzegi, współdzielenie obliczeń, wyrażenia, wartości `NULL`
> i ograniczenia agregatów okna rekordowego sprawdzają `window_aggregate` oraz testy
> jednostkowe `ut_compiler` i `ut_expeval`.

---

## Dalszy rachunek na wyniku agregatu

Funkcje skalarne należą do składni wyrażeń pól, nie do żadnego rodzaju okna. Pełną listę,
reguły nazw i arności oraz semantykę typów opisuje rozdział
[Wyrażenia pól i funkcje skalarne](wyrazenia-pol-i-funkcje-skalarne.md). Poniżej pozostają
tylko konwersje szczególnie istotne przy odczycie wyniku agregatu.

`isnull(x)` zwraca 1 dla `NULL` i 0 dla wartości obecnej. `null2zero(x)` zamienia `NULL` na
całkowite zero, ale wartość obecną przepuszcza bez zmiany jej typu. Jest to konwersja
stratna, a nie sposób eksportu informacji o braku. Dzielenie przez zero daje `NULL` dla
każdego typu liczbowego i nie zatrzymuje dalszego przetwarzania strumienia.

---

## Przykład konwersji: to_string

Funkcja `to_string` konwertuje wyrażenie liczbowe na ciąg tekstowy o zadanej szerokości. Wynik trafia do pola typu STRING w strumieniu wynikowym.

### Składnia

```
to_string(wyrażenie : szerokość)
to_string(wyrażenie)
```

Parametr `szerokość` (liczba naturalna po dwukropku `:`) określa szerokość pola wyjściowego w bajtach. Pominięcie parametru daje domyślną szerokość 32 bajtów.

> **ℹ Info**
>
> Separator argumentów to dwukropek `:`, nie przecinek `,`. Przecinek jest separatorem listy SELECT — użycie przecinka w `to_string(x, n)` spowoduje błąd parsowania.


### Przykład

```
DECLARE v INTEGER STREAM src, 1 FILE 'data.txt'

SELECT to_string(src[0]:10) STREAM labels FROM src
```

Strumień `labels` zawiera wartości `src` sformatowane jako tekst w polu 10-bajtowym.

### Konkatenacja z literałem

Ciąg wynikowy można łączyć z literałem stringowym operatorem `+`:

```
SELECT to_string(src[0]:8) + '_ok' STREAM tagged FROM src
```

Rozmiar pola wynikowego: 8 (z `to_string`) + 3 (literal `_ok`) = 11 bajtów.

### Zastosowanie

`to_string` przydaje się przy eksporcie do systemów przyjmujących dane tekstowe (Graphite, InfluxDB przez `xqry`) lub przy tworzeniu etykiet zdarzeń łączonych z wyjściem `DO DUMP`.

> **_NOTE:_** Opisana funkcjonalność ma pokrycie w testach: `issue121_isnull`, `issue128_numeric_to_string`, `issue128_string_to_numeric` opisanych w załączniku pt. [Testy Integracyjne](../../zalaczniki/testy-integracyjne.md).

---

## Przykład konwersji: to_integer

Funkcja `to_integer` konwertuje wyrażenie liczbowe na pole typu `INTEGER`. Jest podstawową
drogą odczytu artefaktu z agregatem: pole `RATIONAL` zamienia na liczbę całkowitą, którą
czytelnik odczyta bez znajomości układu pary licznik-mianownik.

### Składnia

```
to_integer(wyrażenie)
```

### Zaokrąglenie

> **⚠️ Ostrzeżenie**
>
> `to_integer` **obcina w stronę zera**, a nie podłoguje. Dla wartości ujemnych wynik różni
> się od podłogi o jeden.

Reguła jest ta sama dla argumentu wymiernego i zmiennoprzecinkowego — w obu przypadkach
część ułamkowa jest odrzucana, a znak zachowany:

| Wartość wejściowa | `to_integer` | podłoga (dla porównania) |
| ----------------- | ------------ | ------------------------ |
| `8/3`             | `2`          | `2`                      |
| `-8/3`            | `-2`         | `-3`                     |
| `-4/3`            | `-1`         | `-2`                     |
| `-2.6666…`        | `-2`         | `-3`                     |

Wartość `NULL` przechodzi przez funkcję bez zmiany — `to_integer(NULL)` daje `NULL`, a nie zero.

### Pułapka przy przenoszeniu na Pythona

Operator `//` w Pythonie **podłoguje**, więc naiwne przepisanie zapytania rozjeżdża się
z silnikiem na każdej wartości ujemnej:

```python
>>> -8 // 3        # Python: podłoga
-3
>>> int(-8 / 3)    # to samo, co robi to_integer
-2
```

Model odtwarzający zachowanie silnika musi liczyć średnią obciętą jawnie:

```python
def truncated_mean(values):
    """Obcięcie w stronę zera, tak jak rzutowanie średniej wymiernej."""
    total = sum(values)
    quotient = abs(total) // len(values)
    return quotient if total >= 0 else -quotient
```

Ten sam problem dotyczy każdego języka, w którym dzielenie całkowite podłoguje.

### Zastosowanie

`to_integer` jest właściwe tam, gdzie odbiorca artefaktu ma przyjąć liczbę całkowitą i część
ułamkowa nie jest potrzebna. Tam, gdzie wartość ma pozostać dokładna, właściwe jest
`to_string`, które zapisuje ułamek jako tekst `licznik/mianownik`, albo odczyt pary wprost
(→ [Układ pola RATIONAL](../../architektura-systemu-przetwarzania-danych/format-zapisu-danych/pliki.md#układ-pola-rational)).

> **_NOTE:_** Opisana funkcjonalność ma pokrycie w testach: `issue128_string_to_numeric` opisanym w załączniku pt. [Testy Integracyjne](../../zalaczniki/testy-integracyjne.md), oraz w testach jednostkowych `ut_payload` i `ut_convertTypes`, przypinających układ pola `RATIONAL` i regułę zaokrąglenia.
