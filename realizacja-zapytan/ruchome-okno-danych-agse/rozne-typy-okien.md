# Różne typy okien

Operator `@(k, w)` przez dobór dwóch parametrów pozwala zbudować każdy z klasycznych typów okien stosowanych w przetwarzaniu strumieni. Poniżej zestawienie wzorców na jednym wspólnym strumieniu źródłowym.

## Strumień źródłowy

Plik `data.txt` — 12 kolejnych liczb całkowitych:

```
$ seq 1 12 > data.txt
```

Deklaracja źródła — jeden rekord co sekundę, jedno pole:

```
DECLARE val INTEGER
STREAM src, 1
FILE 'data.txt'
```

## Tumbling window — okna bez nakładania

Skok równy rozmiarowi okna: `k = w`. Każdy element wejściowy należy dokładnie do jednego okna wyjściowego.

```
SELECT *
STREAM tumbling
FROM src@(4,4)
```

Interwał wyjściowy: `1s × 4 / 1 = 4s`. Rekordy wyjściowe:

```
$ xqry -s tumbling
1  2  3  4
5  6  7  8
9 10 11 12
```

Zastosowania: agregacja próbek w stałych przedziałach czasu (np. minutowe, godzinowe).

## Sliding window — okna z nakładaniem

Skok mniejszy od rozmiaru okna: `k < w`. Każdy element wejściowy pojawia się w kilku kolejnych oknach.

```
SELECT *
STREAM sliding
FROM src@(1,4)
```

Interwał wyjściowy: `1s × 1 / 1 = 1s`. Rekordy wyjściowe:

```
$ xqry -s sliding
1  2  3  4
2  3  4  5
3  4  5  6
4  5  6  7
...
```

Zastosowania: średnia ruchoma, detekcja trendów, filtry FIR (jak w [implementacji filtru sygnałowego](../../przyklady-zastosowan/implementacja-filtru-sygnalowego.md)).

## Próbkowanie — okna z przerwami

Skok większy od rozmiaru okna: `k > w`. Część elementów wejściowych jest pomijana.

```
SELECT *
STREAM sampled
FROM src@(3,1)
```

Interwał wyjściowy: `1s × 3 / 1 = 3s`. Rekordy wyjściowe:

```
$ xqry -s sampled
1
4
7
10
```

Zastosowania: decimacja sygnału, redukcja częstotliwości próbkowania, diagnostyka co N-ty pomiar.

## Okno lustrzane — odwrócona kolejność pól

Ujemna wartość `w` odwraca kolejność pól w rekordzie wyjściowym przy zachowaniu tego samego rozmiaru okna.

```
SELECT *
STREAM mirrored
FROM src@(2,-2)
```

Interwał wyjściowy: `1s × 2 / 1 = 2s`. Rekordy wyjściowe (kolejność pól odwrócona):

```
$ xqry -s mirrored
2  1
4  3
6  5
8  7
...
```

Porównaj z `src@(2,2)`, które dałoby `1 2`, `3 4`, `5 6`… — kolejność zgodna z napływem. Agregacja lustrzana jest niezbędna przy odwracaniu serializacji (deserializacja), jak opisano w [przykładzie serializacji](przyklad-serializacji.md).

## Zestawienie wzorców

| Zapytanie      | Typ okna   | Interwał | Rozmiar rekordu | Nakładanie |
| -------------- | ---------- | -------- | --------------- | ---------- |
| `src@(4,4)`    | tumbling   | 4 s      | 4 pola          | brak       |
| `src@(1,4)`    | sliding    | 1 s      | 4 pola          | pełne      |
| `src@(2,4)`    | hop window | 2 s      | 4 pola          | częściowe  |
| `src@(3,1)`    | próbkowanie| 3 s      | 1 pole          | brak       |
| `src@(2,-2)`   | lustrzane  | 2 s      | 2 pola          | brak       |

## Plan realizacji zapytań

Wszystkie cztery warianty można uruchomić jednocześnie umieszczając je w jednym pliku `.rql`:

```
DECLARE val INTEGER STREAM src, 1 FILE 'data.txt'

SELECT * STREAM tumbling FROM src@(4,4)
SELECT * STREAM sliding  FROM src@(1,4)
SELECT * STREAM sampled  FROM src@(3,1)
SELECT * STREAM mirrored FROM src@(2,-2)
```

```
$ xretractor -c windows.rql -f -p -d > out.dot && dot -Tsvg out.dot -o out.svg
```

Plan zapytania pokaże cztery niezależne gałęzie wywodzące się ze wspólnego węzła `src`. Każda gałąź realizuje inny typ okna bez wzajemnych zależności.

> **_NOTE:_** Opisana funkcjonalność ma pokrycie w testach: `agse1`, `agse2`, `agse3`, `Pattern6` opisanych w załączniku pt. [Testy Integracyjne](../../zalaczniki/testy-integracyjne.md).
