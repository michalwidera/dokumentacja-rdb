# Ruchome okno danych AGSE

Ruchome okno danych to pojęcie powszechnie stosowane w systemach przetwarzających strumienie lub serie czasowe. Idea polega na grupowaniu danych w oknach czasowych, dając możliwość użytkownikowi możliwość przetwarzania w zamrożonych migawkach.

RetractorDB wspiera ten model przetwarzania danych poprzez operator **AgSe** (Agregacja i Serializacja). Operator ten jest dwuargumentowy i działa na strumieniu. Oznaczany znakiem `@`, ma postać:

```
strumień@(k, w)
```

gdzie:

* **k** - skok okna (dodatnia liczba naturalna): o ile elementów spłaszczonego strumienia przesuwa się okno przy każdym kroku,
* **w** - rozmiar okna (liczba całkowita różna od zera): ile elementów zawiera jeden rekord wyjściowy.

Spłaszczenie uwzględnia wszystkie elementy tablic liczbowych. Rekord z `INTEGER[3]` wnosi trzy elementy, a `STRING[N]` jeden element tekstowy. Skok liczony w rekordach i skok liczony w elementach są równe tylko dla źródła jednoelementowego.

Wartość dodatnia `w` zachowuje historyczną konwencję RetractorDB: najnowsze pole okna jest pierwsze. Wartość ujemna oznacza **agregację lustrzaną** - odwraca tę kolejność, więc pola są ułożone zgodnie z napływem.

## Jak zmienia się interwał strumienia wyjściowego

Jeśli strumień źródłowy ma `W` spłaszczonych elementów w rekordzie i interwał `Δ`, to strumień wyjściowy operatora `@(k, w)` ma:

* `|w|` pól w rekordzie wyjściowym,
* interwał wyjściowy `Δ_out = (Δ / W) × k`.

| Parametry          | Efekt                                                          |
| ------------------ | -------------------------------------------------------------- |
| `k = \|w\|`        | okno tumbling - kolejne okna nie zachodzą na siebie            |
| `k < \|w\|`        | okno przesuwne (sliding) - kolejne okna zachodzą na siebie     |
| `k > \|w\|`        | próbkowanie z przerwami - część danych jest pomijana           |
| `k = 1, \|w\| = 1` | serializacja - wielopolowy rekord rozbijany na jednoelementowe |
| `w < 0`            | agregacja lustrzana - kolejność napływu od najstarszego pola   |

## Typowe wzorce użycia

```rql
# serializacja: 2 pola → 1 pole (interwał ÷ 2)
SELECT * STREAM s1 FROM A@(1,1)

# tumbling window: 4 elementy, bez nakladania
SELECT * STREAM s2 FROM A@(4,4)

# sliding window: okno 5-elementowe przesuwane o 1
SELECT * STREAM s3 FROM A@(1,5)

# sampling: every fifth flattened element
SELECT * STREAM s4 FROM A@(5,1)

# deserialization: align pairs and restore arrival order
SELECT * STREAM s5 FROM (s1>1)@(2,-2)
```

## Wizualizacja operatora @

Poniżej schematyczne przedstawienie działania `source@(k, w)` dla strumienia jednoelementowego:

```
Dane wejściowe:   0  1  2  3  4  5  6  7  8  9  ...
                  ↓  ↓  ↓  ↓  ↓  ↓  ↓  ↓  ↓  ↓

@(1, 3) - sliding window, skok=1, okno=3:
  [2,1,0]  [3,2,1]  [4,3,2]  [5,4,3]  ...

@(3, 3) - tumbling window, skok=3, okno=3:
  [3,2,1]           [6,5,4]           ...

@(5, 1) - próbkowanie co 5 elementów:
  [0]               [5]               ...

@(2,-2) - lustrzana, skok=2, okno=2:
  [1,2]    [3,4]    [5,6]    [7,8]    ...
```

Okno jest stemplowane **końcem** przedziału: rekord o indeksie logicznym `n` obejmuje pozycje `n·k−(|w|−1) … n·k`, więc jego najnowsze pole leży dokładnie w pozycji `n·k`. Dzięki temu indeks logiczny okna oznacza tę samą chwilę co indeks logiczny źródła i złączenie okna z jego własnym źródłem (potok FIR) nie wyprzedza sygnału. Ilustracja powyżej pokazuje ciąg emitowanych okien; pierwsze z nich nosi indeks `origin`, nie zero.

Przy `k = |w|` emitowane okna są rozłączne, ale nie muszą zaczynać podziału od pierwszego elementu źródła. Dla `@(3,3)` pierwszy pełny rekord ma indeks 1 i obejmuje pozycje 1..3. Zmiana znaku `w` odwraca kolejność pól bez zmiany fazy; wyrównanie par przy deserializacji pokazuje [przykład serializacji](przyklad-serializacji.md).

AGSE emituje dopiero pełne okno. Początkowe sloty, w których okno sięgałoby przed początek źródła, **nie są rekordami i nie mają definicji** - tworzą raportowany w planie `origin=`. Sloty, w których okno jest zdefiniowane, ale najnowsze pole jeszcze nie powstało, tworzą `tail=`. Prawdziwy `NULL` obecny w danych pozostaje natomiast elementem pełnego okna. Formalna granica ogona i pojemności historii jest opisana w rozdziale [Ogony, początki logiczne i obserwowalność operatorów](../../podstawy-matematyczne/ogony-i-obserwowalnosc-operatorow.md).

## Przykłady

Poniższe podrozdziały prezentują konkretne zastosowania operatora AgSe:

* **Przykład serializacji** - zamiana wielopolowego rekordu na sekwencję jednoelementowych rekordów i powrót przez wyrównanie fazy oraz agregację lustrzaną.
* **Przykład średniej ruchomej** - sliding window jako podstawa filtru uśredniającego sygnał.
* **Różne typy okien** - tumbling, sliding i próbkowanie na jednym strumieniu danych.

Polecenia `xqry --null` w przykładach pomijają wiersze całkowicie `NULL`, w tym powiadomienia IPC sprzed pierwszego pełnego okna. Filtr pomija również prawdziwe wyniki całkowicie `NULL`; aby je obserwować, pomiń tę opcję. Kontrakt odbioru opisują [opcje xqry](../../zalaczniki/opcje-wywolania/xqry.md).

Na początku rozważymy proces serializacji w operatorze Agregacji i Serializacji – AgSe.

> **_NOTE:_** Opisana funkcjonalność ma pokrycie w testach: `agse1`, `agse2`, `agse3`, `Pattern6` opisanych w załączniku pt. [Testy Integracyjne](../../zalaczniki/testy-integracyjne.md).
