# Przykład średniej ruchomej

Średnia ruchoma (ang. *moving average*) to jeden z najprostszych i najczęściej stosowanych filtrów sygnałowych. Każdy punkt wyjściowy jest średnią arytmetyczną `N` ostatnich próbek. Operator `@(1, N)` w RetractorDB tworzy dokładnie takie okno: dla każdego nowego pomiaru dostępne jest `N` ostatnich wartości.

## Dane źródłowe

Przyjmijmy strumień temperatury mierzonej co sekundę. Plik `temp.txt` zawiera kolejne odczyty:

```
$ seq 10 5 60 > temp.txt
```

```
10
15
20
25
30
35
40
45
50
55
60
```

## Zapytanie RQL

Plik `avg.rql`:

```
DECLARE temp INTEGER \
STREAM sensor, 1 \
FILE 'temp.txt'

SELECT * \
STREAM window5 \
FROM sensor@(1,5)

SELECT window5[0]+window5[1]+window5[2]+window5[3]+window5[4] \
STREAM sumRow \
FROM window5

SELECT sumRow[0]/5 \
STREAM avg5 \
FROM sumRow
```

### Co robi każde zapytanie

1. `sensor@(1,5)` — tworzy przesuwne okno 5-elementowe. Każdy rekord `window5` zawiera 5 ostatnich odczytów temperatury. Interwał wyjściowy: `1s / 1 × 1 = 1s` (skok=1, W=1 pole).
2. Suma pięciu pól — klasyczne `SELECT` po polach `window5[0]`..`window5[4]`.
3. Podzielenie sumy przez 5 — wynik to średnia ruchoma.

## Uruchomienie

```
$ xretractor avg.rql &
$ xqry -s avg5
```

Przykładowy wynik (okno wypełnia się po pierwszych 5 próbkach):

```
30
35
40
45
50
```

Wartość `30` odpowiada średniej z pierwszego pełnego okna: `(10+15+20+25+30)/5 = 20`... uwaga — system RetractorDB nie wyświetla niepełnych okien, więc pierwsze pojawienie się wyniku odpowiada chwili gdy okno jest w pełni nasycone danymi.

## Weryfikacja planu zapytania

```
$ xretractor -c avg.rql -f -p -d > out.dot && dot -Tsvg out.dot -o out.svg
```

W wygenerowanym planie widać łańcuch: `sensor → window5 → sumRow → avg5`. Kluczowy jest węzeł `sensor@(1,5)` — z jednoelementowego strumienia wchodzącego co sekundę powstaje strumień pięcioelementowy, ciągle przesuwany.

## Zależność między parametrami okna a opóźnieniem

Średnia ruchoma wprowadza opóźnienie o połowę długości okna. Dla okna N=5 opóźnienie wynosi 2 próbki (2 sekundy). Zwiększenie okna:

* zmniejsza szum (większe wygładzenie),
* zwiększa opóźnienie,
* nie zmienia interwału wyjściowego (przy stałym skoku k=1).

Zmiana skoku przy stałym oknie:

```
sensor@(5,5)   -- tumbling: wynik co 5 sekund, bez nakładania
sensor@(1,5)   -- sliding:  wynik co sekundę, pełne nakładanie
sensor@(3,5)   -- częściowe nakładanie: wynik co 3 sekundy
```

> **_NOTE:_** Opisana funkcjonalność ma pokrycie w testach: `agse1`, `agse2`, `agse3`, `Pattern6` opisanych w załączniku pt. [Testy Integracyjne](../../zalaczniki/testy-integracyjne.md).
