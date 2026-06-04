# Operatory agregujące i funkcje wyrażeń

## Agregaty okna (MIN, MAX, AVG, SUMC)

Operatory agregujące działają na strumieniu posiadającym wiele pól — typowo strumieniu wynikowym operatora `@(k,w)` (okno danych). Redukują wszystkie pola rekordu do jednej wartości.

### Składnia

```
FROM strumień.agregator
```

gdzie `agregator` to jedno z:

| Słowo kluczowe | Działanie |
|----------------|-----------|
| `min`  / `MIN` | minimum ze wszystkich pól rekordu |
| `max`  / `MAX` | maksimum ze wszystkich pól rekordu |
| `avg`  / `AVG` | średnia arytmetyczna pól rekordu |
| `sumc` / `SUMC`| suma wszystkich pól rekordu |

Słowa kluczowe akceptowane są zarówno małymi, jak i wielkimi literami.

### Interwał wyjściowy

Agregaty nie zmieniają częstotliwości strumienia — interwał wyniku jest taki sam jak źródła:

$$\Delta_{wynik} = \Delta_{strumień}$$

### Przykład: średnia ruchoma

```
DECLARE val INTEGER STREAM src, 1 FILE 'data.txt'

-- okno 5-elementowe przesuwane o 1
SELECT * STREAM win5 FROM src@(1,5)

-- średnia z 5 ostatnich wartości
SELECT win5[0] STREAM ma5 FROM win5.avg
```

Strumień `ma5` zawiera w każdej chwili średnią z pięciu kolejnych próbek `src`.

### Przykład: filtr sygnałowy (sumc)

Fragment z przykładu implementacji filtru sygnałowego:

```
SELECT signalRow[_] * filter[_] STREAM accRow FROM signalRow+filter
SELECT accRow[0] STREAM output FROM accRow.sumc
```

`accRow.sumc` sumuje wszystkie pola rekordu `accRow` (iloczyny próbek sygnału przez współczynniki filtru) produkując wyjście filtru FIR.

### Przykład: MIN i MAX

```
DECLARE v INTEGER STREAM src, 0.1 FILE '/dev/urandom'
SELECT * STREAM win10 FROM src@(1,10)

SELECT win10[0] STREAM min10 FROM win10.min
SELECT win10[0] STREAM max10 FROM win10.max
```

> **_NOTE:_** Opisana funkcjonalność ma pokrycie w testach: `simple_max`, `Pattern4` opisanych w załączniku pt. [Testy Integracyjne](../../zalaczniki/testy-integracyjne.md).

---

## Funkcja to_string

Funkcja `to_string` konwertuje wyrażenie liczbowe na ciąg tekstowy o zadanej szerokości. Wynik trafia do pola typu STRING w strumieniu wynikowym.

### Składnia

```
to_string(wyrażenie : szerokość)
to_string(wyrażenie)
```

Parametr `szerokość` (liczba naturalna po dwukropku `:`) określa szerokość pola wyjściowego w bajtach. Pominięcie parametru daje domyślną szerokość 32 bajtów.

> **ℹ️ Info**
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
