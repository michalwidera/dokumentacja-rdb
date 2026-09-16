# Przetwarzanie symbolu \_

Indeks `[_]` jest cukrem syntaktycznym powielającym wyrażenie pola. Jedno wyrażenie zapisane w `SELECT` rozwija się podczas kompilacji do wielu pól wynikowych, po jednym dla każdego zgodnego slotu wskazanych strumieni.

Liczba kopii nie wynika wyłącznie z własnego schematu strumienia. `x[_]` oznacza wszystkie sloty, które `x` wnosi do rekordu czytanego przez dane zapytanie z całej klauzuli `FROM`. Ma to znaczenie, gdy operator strumieniowy zmienia szerokość schematu, na przykład tworząc okno.

Przykład używa kanonicznych deklaracji z całego rozdziału — `core0` ma dwa pola (BYTE, INTEGER), `core1` ma dwa pola (INTEGER, FLOAT), schematy są równoliczne:

```rql
DECLARE a BYTE, b INTEGER   STREAM core0, 0.1 FILE ‘sensor_a.txt’
DECLARE c INTEGER, d FLOAT  STREAM core1, 0.2 FILE ‘sensor_b.txt’

SELECT core0[_] * core1[_] \
STREAM scaled \
FROM core0 + core1
```

Po przeprowadzeniu kompilacji:

```
$ xretractor -c query.rql
{{#include ../regen/out/underscore.txt}}
```

Symbol `_` rozwinął się w dwa pola: `scaled[0] * scaled[2]` (czyli `a * c`) i `scaled[1] * scaled[3]` (czyli `b * d`). Odwołania do `core0` i `core1` zostały przetłumaczone przez aliasowanie na absolutne pozycje w schemacie złączonym. Typy wynikowe to INTEGER (`BYTE * INTEGER`) i FLOAT (`INTEGER * FLOAT`) — wynik równania typów w górę, opisanego w osobnym podrozdziale.

## Szerokość liczona w klauzuli `FROM`

Jednopolowy strumień `src` wnosi pięć slotów, gdy w `FROM` znajduje się jego okno `src@(1,5)`. Dzięki temu splot FIR można zapisać bez osobnego, nazwanego strumienia okna:

```rql
DECLARE value INTEGER STREAM src, 1/500 FILE 'data.txt'
DECLARE coef INTEGER[5] STREAM filter, 1 FILE 'coef.txt'

SELECT src[_] * filter[_] STREAM products FROM src@(1,5)+filter
SELECT products[0] STREAM output FROM SUMC(products)
```

Pierwsze zapytanie rozwija się do pięciu iloczynów. Jest równoważne dłuższej postaci:

```rql
SELECT * STREAM window FROM src@(1,5)
SELECT window[_] * filter[_] STREAM products FROM window+filter
SELECT products[0] STREAM output FROM SUMC(products)
```

W krótszej postaci kompilator sam wydziela okno z `FROM` jako substrat. Taki substrat jest przezroczysty podczas ustalania szerokości wkładu `src`. Nazwany przez użytkownika strumień `window` stanowi natomiast granicę schematu, dlatego dłuższa postać odwołuje się do `window[_]`, a nie do `src[_]`.

Operator stojący w `FROM` może także zmniejszyć szerokość. Reduktor zwija okno do jednego slotu, więc poniższe `src[_]` rozwija się tylko raz:

```rql
SELECT src[_] STREAM total FROM SUMC(src@(1,5))
```

Jeżeli jedno wyrażenie zawiera kilka indeksów `[_]`, kompilator tworzy tyle kopii, ile wynosi najmniejsza z ustalonych szerokości ich wkładów. W typowym splocie okno i strumień współczynników mają tę samą szerokość.

Kompilator odrzuca odwołanie, gdy wskazany strumień nie występuje w `FROM` albo jego pola nie tworzą tam spójnego bloku. Przykładem drugiego przypadku jest `src[_]` pod oknem zbudowanym nad konkatenacją `(src+other)@(1,5)`: pola obu źródeł są powtarzane wspólnie i nie da się przypisać `src` jednej szerokości bez zgadywania. Należy wtedy nadać podwyrażeniu własną nazwę i użyć `[_]` na tym nazwanym wyniku.

## Symbol `_` a przeplot

Aliasowanie składowych przez `A[_]` jest poprawne dla sumy `+`, ponieważ suma zachowuje osobne fragmenty schematów obu argumentów. Nie wolno stosować tej postaci do składowej osiąganej przez przeplot `#`:

```rql
SELECT A[_] - B[_] STREAM roznica FROM A#B
```

Po przeplocie pozycje `A[k]` i `B[k]` są tą samą pozycją wspólnego schematu, więc powyższe wyrażenie nie identyfikuje dwóch różnych wartości. Kompilator kończy taki plan błędem zamiast po cichu obliczyć `wynik[k]-wynik[k]`.

Jeżeli `_` ma przetwarzać rekord przeplotu, należy najpierw nadać wynikowi nazwę, a potem odwołać się do tego wyniku:

```rql
SELECT * STREAM przeplot FROM A#B
SELECT przeplot[_] * 2 STREAM przeskalowany FROM przeplot
```

Odzyskanie konkretnej składowej wymaga operatora rozplotu `&` albo `%`.

Ta funkcjonalność ma główne zastosowanie w algorytmach filtrów sygnałowych, w których wykonuje się wiele takich samych operacji na odpowiadających sobie elementach okna i wektora współczynników. Nie jest konieczna do osiągnięcia pełnej funkcjonalności RetractorDB, ale znacząco skraca takie zapytania. Kompletny przykład przedstawia rozdział [Implementacja filtru sygnałowego](../przyklady-zastosowan/implementacja-filtru-sygnalowego.md).
