---
icon: window-frame
---

# Ruchome okno danych AGSE

Ruchome okno danych to pojęcie powszechnie stosowane w systemach przetwarzających strumienie lub serie czasowe. Idea polega na grupowaniu danych w oknach czasowych, dając możliwość użytkownikowi możliwość przetwarzania w zamrożonych migawkach.

RetractorDB wspiera ten model przetwarzania danych poprzez operator **AgSe** (Agregacja i Serializacja). Operator ten jest dwuargumentowy i działa na strumieniu. Oznaczany znakiem `@`, ma postać:

```
strumień@(k, w)
```

gdzie:

* **k** — skok okna (liczba naturalna): o ile rekordów źródłowych przesuwa się okno przy każdym kroku,
* **w** — rozmiar okna (liczba całkowita różna od zera): ile pól źródłowych zawiera jeden rekord wyjściowy.

Wartość ujemna `w` oznacza **agregację lustrzaną** — pola w rekordzie wyjściowym ułożone są w odwrotnej kolejności względem napływu.

## Jak zmienia się interwał strumienia wyjściowego

Jeśli strumień źródłowy ma `W` pól w rekordzie i interwał `Δ`, to strumień wyjściowy operatora `@(k, w)` ma:

* `|w|` pól w rekordzie wyjściowym,
* interwał wyjściowy `Δ_out = (Δ / W) × k`.

| Parametry          | Efekt                                                          |
| ------------------ | -------------------------------------------------------------- |
| `k = \|w\|`        | okno tumbling — kolejne okna nie zachodzą na siebie            |
| `k < \|w\|`        | okno przesuwne (sliding) — kolejne okna zachodzą na siebie     |
| `k > \|w\|`        | próbkowanie z przerwami — część danych jest pomijana           |
| `k = 1, \|w\| = 1` | serializacja — wielopolowy rekord rozbijany na jednoelementowe |
| `w < 0`            | agregacja lustrzana — kolejność pól w oknie odwrócona          |

## Typowe wzorce użycia

```
-- serializacja: 2 pola → 1 pole (interwał ÷ 2)
SELECT * STREAM s1 FROM A@(1,1)

-- tumbling window: okna po 4 rekordy, bez nakładania
SELECT * STREAM s2 FROM A@(4,4)

-- sliding window: okno 5-elementowe przesuwane o 1
SELECT * STREAM s3 FROM A@(1,5)

-- próbkowanie: co piąty rekord (skip=5, okno=1)
SELECT * STREAM s4 FROM A@(5,1)

-- deserializacja lustrzana: przywrócenie kolejności pól
SELECT * STREAM s5 FROM s1@(2,-2)
```

## Wizualizacja operatora @

Poniżej schematyczne przedstawienie działania `source@(k, w)` dla strumienia jednoelementowego:

```
Dane wejściowe:   0  1  2  3  4  5  6  7  8  9  ...
                  ↓  ↓  ↓  ↓  ↓  ↓  ↓  ↓  ↓  ↓

@(1, 3) — sliding window, skok=1, okno=3:
  [0,1,2]  [1,2,3]  [2,3,4]  [3,4,5]  ...

@(3, 3) — tumbling window, skok=3, okno=3:
  [0,1,2]           [3,4,5]           ...

@(5, 1) — próbkowanie co 5 elementów:
  [0]               [5]               ...

@(2,-2) — lustrzana, skok=2, okno=2:
  [1,0]    [3,2]    [5,4]    [7,6]    ...
```

## Przykłady

Poniższe podrozdziały prezentują konkretne zastosowania operatora AgSe:

* **Przykład serializacji** — zamiana wielopolowego rekordu na sekwencję jednoelementowych rekordów i powrót przez agregację lustrzaną.
* **Przykład średniej ruchomej** — sliding window jako podstawa filtru uśredniającego sygnał.
* **Różne typy okien** — tumbling, sliding i próbkowanie na jednym strumieniu danych.

Na początku rozważymy proces serializacji w operatorze Agregacji i Serializacji – AgSe.

> **_NOTE:_** Opisana funkcjonalność ma pokrycie w testach: `agse1`, `agse2`, `agse3`, `Pattern6` opisanych w załączniku pt. [Testy Integracyjne](../../zalaczniki/testy-integracyjne.md).
