# Wykres świecowy (OHLC)

Wykres świecowy (ang. *candlestick chart*) jest podstawową formą prezentacji notowań w analizie technicznej. Każdy przedział czasu opisują cztery wartości: otwarcie (*open*), maksimum (*high*), minimum (*low*) i zamknięcie (*close*). Prostokąt świecy rozciąga się od otwarcia do zamknięcia, a knoty sięgają maksimum i minimum przedziału.

Przykład pokazuje, jak zbudować świece z regularnego strumienia wyłącznie zapytaniami RQL i jak `xqry --gnuplot-ohlc` rysuje je na wspólnej osi razem z próbkami, z których powstały. Źródłem danych są bajty losowe, wygładzone średnią kroczącą do przebiegu przypominającego kurs. Nie są to dane rynkowe - przykład demonstruje mechanizm, a nie analizę notowań.

## Zapytanie RQL

Plik `examples/candlestick/candlestick.rql`:

```rql
STORAGE 'temp'
DEFAULT VOLATILE

DECLARE v BYTE STREAM source, 0.02 FILE '/dev/random'

SELECT int(AVG(source[0] : 25)) STREAM price FROM source
SELECT * STREAM bar FROM price@(10,-10)
SELECT * STREAM hi FROM MAX(bar)
SELECT * STREAM lo FROM MIN(bar)
SELECT bar[0], int(hi[0]), int(lo[0]), bar[9] STREAM ohlc FROM bar + hi + lo
SELECT * STREAM chart FROM ohlc + bar
```

Plan składa się z następujących strumieni:

| Strumień | Interwał       | Pola | Rola                                               |
| -------- | -------------- | ---- | -------------------------------------------------- |
| `source` | 0,02 s (50 Hz) | 1    | bajty odczytywane z `/dev/random`                  |
| `price`  | 0,02 s         | 1    | średnia krocząca z 25 próbek - „kurs”              |
| `bar`    | 0,2 s          | 10   | okno rozłączne: 10 próbek kursu w kolejności napływu |
| `hi`     | 0,2 s          | 1    | maksimum rekordu `bar`                             |
| `lo`     | 0,2 s          | 1    | minimum rekordu `bar`                              |
| `ohlc`   | 0,2 s          | 4    | otwarcie, maksimum, minimum, zamknięcie            |
| `chart`  | 0,2 s          | 14   | świeca i dziesięć próbek, z których powstała       |

Dyrektywa `DEFAULT VOLATILE` utrzymuje wszystkie wyniki i substraty w pamięci, więc przykład niczego nie utrwala na dysku (→ [Klauzula VOLATILE](../konstrukcja-jezyka-zapytan/polecenie-select/klauzula-volatile.md)). Katalog `temp` wskazany przez `STORAGE` musi jednak istnieć przed startem serwera.

Strumień `price` powstaje z agregatu okna rekordowego `AVG(source[0] : 25)`. Agregat w liście `SELECT` redukuje pionowo, po kolejnych rekordach historii, więc zamienia biały szum w wolno zmienny przebieg, a interwał wyniku pozostaje równy interwałowi źródła. Średnia ma typ `RATIONAL`, dlatego zapytanie rzutuje ją funkcją `int(...)` na liczbę całkowitą - z tego samego powodu co w przykładzie [filtru sygnałowego](implementacja-filtru-sygnalowego.md): gnuplot odczytałby z ułamka tylko licznik.

Strumień `bar` jest oknem `price@(10,-10)`. Skok i szerokość są równe, więc jest to okno rozłączne (*tumbling*): każda próbka kursu trafia do dokładnie jednej świecy, a nowy rekord pojawia się co 10 × 0,02 s = 0,2 s. Ujemna szerokość oznacza agregację lustrzaną - pola są ułożone zgodnie z napływem, dlatego `bar[0]` jest najstarszą próbką okna (otwarcie), a `bar[9]` najnowszą (zamknięcie) (→ [Różne typy okien](../realizacja-zapytan/ruchome-okno-danych-agse/rozne-typy-okien.md)).

Strumienie `hi` i `lo` używają reduktorów `MAX(bar)` i `MIN(bar)` w klauzuli `FROM`. Reduktor strumieniowy zwija poziomo pola jednego rekordu, więc daje maksimum i minimum dziesięciu próbek świecy przy niezmienionym interwale 0,2 s (→ [Operatory agregujące](../konstrukcja-jezyka-zapytan/polecenie-select/operatory-agregujace.md)). Wynik reduktora również ma typ `RATIONAL`, stąd `int(hi[0])` i `int(lo[0])` w kolejnym zapytaniu.

Agregat okna rekordowego nie zastąpiłby tu okna `@`. Zapis `MAX(price[0] : 10)` w liście `SELECT` przesuwa się o jeden rekord i emituje wynik co 0,02 s, czyli dałby dziesięć nakładających się świec na każdą właściwą. Dopiero okno rozłączne wyznacza granice świecy i jej interwał.

Suma `bar + hi + lo` łączy trzy strumienie o tym samym interwale w rekord o 12 polach, z których `ohlc` wybiera cztery wartości świecy. Ostatnie zapytanie, `ohlc + bar`, dokleja do świecy jej dziesięć próbek. Rekord `chart` ma zatem 14 pól: otwarcie, maksimum, minimum, zamknięcie i próbki w kolejności napływu. Ponieważ świeca i jej próbki przychodzą w jednym rekordzie, klient nie musi dopasowywać w czasie dwóch osobnych strumieni.

## Tryb `--gnuplot-ohlc`

Opcja `--gnuplot-ohlc` jest modyfikatorem trybu `-p` / `--gnuplot` programu `xqry` (→ [xqry](../zalaczniki/opcje-wywolania/xqry.md)). Oczekuje rekordu o układzie:

```
open, high, low, close, próbka_1, ..., próbka_N
```

Liczba próbek N wynika z długości rekordu (N = liczba pól - 4) i nie wymaga osobnego parametru. Rysowanie przebiega według następujących reguł:

- Każdy rekord daje jedną świecę, ustawioną nad środkiem przedziału zajmowanego przez jej N próbek. Korpus świecy ma szerokość 80% tego przedziału.
- Świeca, której zamknięcie jest nie mniejsze niż otwarcie, jest zielona (wzrostowa); pozostałe są czerwone (spadkowe). Próbki są rysowane niebieską linią.
- Pierwszy parametr `-p` liczy **próbki**, tak jak w zwykłym trybie gnuplot. W oknie mieści się więc tyle świec, ile wynosi szerokość okna podzielona przez N.
- Najnowsza próbka stoi w x = 0. Modyfikator `--gnuplot-rtl` odwraca oś, więc najnowsze świece pojawiają się po prawej stronie.
- Świeca, w której którakolwiek z czterech wartości jest `NULL`, jest pomijana w całości; jej próbki pozostają na wykresie.
- Rekord bez próbek (4 pola lub mniej) nie jest rysowany. `xqry` wypisuje wtedy jednorazowo komunikat na `stderr`, np. `xqry: --gnuplot-ohlc needs open, high, low, close and at least one sample; stream 'ohlc' sends 4`. Standardowe wyjście trafia do gnuplota, więc bez tego komunikatu okno pozostałoby puste bez wyjaśnienia.
- Wywołanie `--gnuplot-ohlc` bez `--gnuplot` kończy się błędem `--gnuplot-ohlc requires --gnuplot/-p mode.`

## Uruchomienie

Do wyświetlenia wykresu służy cel `candlestick` w systemie budowania:

```bash
# z katalogu build/Debug albo build/Release
ninja candlestick
```

CMake uruchamia w katalogu `examples/candlestick` wywołanie:

```bash
scripts/xplot.sh chart candlestick.rql 250,64,192 "--gnuplot-ohlc --gnuplot-rtl"
```

Znaczenie parametrów:

| Parametr                       | Znaczenie                                                         |
| ------------------------------ | ----------------------------------------------------------------- |
| `chart`                        | Nazwa strumienia wynikowego                                       |
| `candlestick.rql`              | Plik zapytań                                                      |
| `250`                          | Szerokość okna w próbkach - 25 świec po 10 próbek                 |
| `64,192`                       | Zakres osi Y; średnia z 25 losowych bajtów skupia się wokół 127,5 |
| `--gnuplot-ohlc --gnuplot-rtl` | Tryb świecowy, najnowsze świece po prawej stronie                 |

Skrypt `scripts/xplot.sh` działa tak samo jak w przykładzie [analizy sygnałów EKG](wizualizacja-ekg-mit-bih.md#wizualizacja-na-ekranie): tworzy od nowa katalog `temp`, uruchamia nazwaną instancję `xretractor` w tle i przepuszcza strumień przez `xqry` do `gnuplot`.

Bez skryptu przykład można uruchomić w dwóch oknach terminala, z katalogu `examples/candlestick`:

```
$ mkdir -p temp && xretractor candlestick.rql
```

```
$ xqry -s chart -p 250,64,192 --gnuplot-ohlc --gnuplot-rtl | gnuplot
```

<figure><img src="../assets/candlestick_ohlc.png" data-pdf-width="75%" alt="Wykres świecowy strumienia chart: zielone i czerwone świece nałożone na niebieską linię próbek"><figcaption><p>Rys. 63. Wykres świecowy strumienia <code>chart</code> - 25 świec po 10 próbek, najnowsze po prawej</p></figcaption></figure>

Rys. 63 przedstawia jedną ramkę danych wysłaną przez `xqry --gnuplot-ohlc --gnuplot-rtl`, wyrenderowaną przez gnuplot. Każda świeca obejmuje dokładnie dziesięć próbek niebieskiej linii: dolna lub górna krawędź korpusu leży na pierwszej próbce przedziału (otwarcie), przeciwna na ostatniej (zamknięcie), a knoty sięgają najwyższej i najniższej próbki przedziału. Otwarcie kolejnej świecy leży blisko zamknięcia poprzedniej, ponieważ `price` jest średnią kroczącą i zmienia się płynnie między przedziałami.

> **_NOTE:_** Tryb `--gnuplot-ohlc` sprawdzają testy jednostkowe `ut_formatter`: położenie świecy nad jej próbkami, szerokość okna liczona w próbkach, pomijanie świecy z wartością `NULL` oraz rekord bez próbek.
