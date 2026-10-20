# Różne typy okien

Operator `@(k, w)` przez dobór dwóch parametrów pozwala zbudować każdy z klasycznych typów okien stosowanych w przetwarzaniu strumieni. Poniżej zestawienie wzorców na jednym wspólnym strumieniu źródłowym.

## Strumień źródłowy

Plik `data.txt` - 12 kolejnych liczb całkowitych:

```
$ seq 1 12 > data.txt
```

Deklaracja źródła - jeden rekord co sekundę, jedno pole:

```rql
DECLARE val INTEGER STREAM src, 1 TEXTFILE 'data.txt'
```

## Tumbling window - okna bez nakładania

Skok równy rozmiarowi okna: `k = w`. Kolejne emitowane okna są rozłączne. Ich faza wynika ze stemplowania końcem okna, więc początkowy fragment wejścia może poprzedzać pierwsze pełne okno.

```rql
SELECT * STREAM tumbling FROM src@(4,4)
```

Interwał wyjściowy: `1s × 4 / 1 = 4s`. Dwa pierwsze rekordy wyjściowe:

```
$ xqry --null -s tumbling
5 4 3 2
9 8 7 6
```

Pierwszy rekord ma indeks logiczny 1 i obejmuje pozycje źródła 1..4, czyli wartości 2..5. Dodatnia szerokość umieszcza najnowszą wartość na początku rekordu. Próbka 1 leży przed pierwszym pełnym oknem tego podziału.

Zastosowania: agregacja próbek w stałych przedziałach czasu (np. minutowe, godzinowe).

## Sliding window - okna z nakładaniem

Skok mniejszy od rozmiaru okna: `k < w`. Każdy element wejściowy pojawia się w kilku kolejnych oknach.

```rql
SELECT * STREAM sliding FROM src@(1,4)
```

Interwał wyjściowy: `1s × 1 / 1 = 1s`. Rekordy wyjściowe:

```
$ xqry --null -s sliding
4 3 2 1
5 4 3 2
6 5 4 3
7 6 5 4
...
```

Zastosowania: średnia ruchoma, detekcja trendów, filtry FIR (jak w [implementacji filtru sygnałowego](../../przyklady-zastosowan/implementacja-filtru-sygnalowego.md)).

## Próbkowanie - okna z przerwami

Skok większy od rozmiaru okna: `k > w`. Część elementów wejściowych jest pomijana.

```rql
SELECT * STREAM sampled FROM src@(3,1)
```

Interwał wyjściowy: `1s × 3 / 1 = 3s`. Rekordy wyjściowe:

```
$ xqry --null -s sampled
1
4
7
10
```

Zastosowania: decimacja sygnału, redukcja częstotliwości próbkowania, diagnostyka co N-ty pomiar.

## Okno lustrzane - odwrócona kolejność pól

Ujemna wartość `w` odwraca kolejność pól w rekordzie wyjściowym przy zachowaniu tego samego rozmiaru okna.

```rql
SELECT * STREAM mirrored FROM src@(2,-2)
```

Interwał wyjściowy: `1s × 2 / 1 = 2s`. Rekordy wyjściowe (kolejność pól odwrócona):

```
$ xqry --null -s mirrored
2 3
4 5
6 7
8 9
...
```

Porównaj z `src@(2,2)`, które dałoby `3 2`, `5 4`, `7 6` - najnowszą wartość jako pierwszą. Ujemna szerokość zachowuje kolejność napływu, ale nie zmienia fazy podziału na pary. Wyrównanie fazy przy odwracaniu serializacji opisano w [przykładzie serializacji](przyklad-serializacji.md).

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

```rql
DECLARE val INTEGER STREAM src, 1 TEXTFILE 'data.txt'

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
