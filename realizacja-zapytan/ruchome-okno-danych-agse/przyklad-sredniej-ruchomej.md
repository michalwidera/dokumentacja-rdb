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

```rql
DECLARE temp INTEGER STREAM sensor, 1 TEXTFILE 'temp.txt'

SELECT * STREAM avg5 FROM AVG(sensor@(1,5))
```

### Co robi zapytanie

1. `sensor@(1,5)` tworzy przesuwne okno pięciu ostatnich odczytów temperatury. Interwał wyjściowy wynosi `(1s / 1) × 1 = 1s`, ponieważ źródło ma jeden element w rekordzie.
2. `AVG(...)` redukuje pięć pól każdego pełnego okna do średniej. Dla wejścia `INTEGER` wynik ma typ `RATIONAL`, więc zachowuje część ułamkową.

Ręczne zsumowanie pól `INTEGER` i podzielenie przez całkowite `5` obcinałoby wynik: dla `[1,1,1,1,2]` dałoby `1`, a `AVG` daje dokładnie `6/5`. Wartości `NULL` są pomijane; okno bez żadnej obecnej wartości daje `NULL`. Drugim sposobem zapisania tej średniej jest agregat historii `SELECT AVG(temp : 5) STREAM avg5 FROM sensor`, opisany w rozdziale [Operatory agregujące](../../konstrukcja-jezyka-zapytan/polecenie-select/operatory-agregujace.md).

## Uruchomienie

```
$ xretractor avg.rql --xqrywait &
$ xqry --null -s avg5
```

Przykładowy wynik (okno wypełnia się po pierwszych 5 próbkach):

```
20/1
25/1
30/1
35/1
40/1
45/1
50/1
```

Pierwszy zapisany wynik to `(10+15+20+25+30)/5 = 20`, wypisany jako ułamek `20/1`. Rekord artefaktu powstaje dopiero po uzyskaniu pełnego okna. Opcja `--xqrywait` wstrzymuje start do pierwszego polecenia klienta, dzięki czemu subskrypcja obejmuje pierwszy wynik. `--null` pomija w wyjściu klienta początkowe wiersze `NULL` przekazywane przez IPC; pomija też rzeczywiste wyniki całkowicie `NULL`.

## Weryfikacja planu zapytania

```
$ xretractor -c avg.rql -f -p -d > out.dot && dot -Tsvg out.dot -o out.svg
```

W wygenerowanym planie widać źródło `sensor`, substrat okna AGSE i reduktor tworzący `avg5`. Okno ma pięć pól, a wynik średniej jedno pole typu `RATIONAL`. Kompilator wydziela substrat bez potrzeby nadawania mu osobnej nazwy w zapytaniu.

## Zależność między parametrami okna a opóźnieniem

Przy pełnych danych średnia ruchoma o długości N ma opóźnienie grupowe `(N-1)/2` próbek. Dla N=5 są to 2 próbki (2 sekundy). To własność filtru, odrębna od początkowego oczekiwania na pełne okno i od ogona startowego planu. Zwiększenie okna:

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
