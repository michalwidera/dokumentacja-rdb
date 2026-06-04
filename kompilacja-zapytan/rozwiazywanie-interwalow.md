# Rozwiązywanie interwałów

Każdy strumień w RetractorDB ma przypisany interwał czasowy — delta (Δ). Interwał określa, jak często produkowane są nowe wartości. Dla strumieni deklarowanych (`DECLARE`) interwał podaje użytkownik. Dla strumieni wynikowych (`SELECT`) interwał wyznacza kompilator z równań algebry strumieni.

Przykłady w tym rozdziale używają kanonicznych deklaracji z całego rozdziału: `core0` (Δ=1/10), `core1` (Δ=1/5), `core2` (Δ=3/10).

## Algorytm

Etap `resolveStreamIntervals` działa iteracyjnie:

```
prevUnresolved = ∞
pętla:
    unresolvedCount = 0
    posortuj qTree topologicznie
    dla każdego zapytania:
        jeśli delta strumieni źródłowych znana:
            wyznacz deltę wynikową z równania operatora
        w przeciwnym razie:
            unresolvedCount++
    jeśli unresolvedCount == 0: koniec (sukces)
    jeśli unresolvedCount >= prevUnresolved: błąd (pętla w grafie)
    prevUnresolved = unresolvedCount
```

Każda runda rozwiązuje co najmniej jeden strumień — bo graf jest acykliczny i sortowanie topologiczne gwarantuje, że źródła są przetwarzane przed wynikami. Jeśli liczba nierozwiązanych strumieni nie maleje, oznacza to cykl — patrz [Wykrywanie pętli](wykrywanie-petli.md).

## Równania operatorów

### Suma strumieni (`+`, STREAM\_ADD)

```
SELECT ... STREAM c FROM a + b
```

\\[\Delta_c = \min(\Delta_a, \Delta_b)\\]

Strumień wynikowy produkuje wartości tak często, jak szybszy ze strumieni wejściowych.

Przykład: core0(Δ=1/10) + core1(Δ=1/5) → str1(Δ=1/10)

### Synchronizacja strumieni (`#`, STREAM\_HASH)

```
SELECT ... STREAM c FROM a # b
```

\\[\Delta_c = \frac{\Delta_a \cdot \Delta_b}{\Delta_a + \Delta_b}\\]

Wynik odpowiada średniej harmonicznej interwałów — strumień produkuje wartości tylko wtedy, gdy oba wejścia są dostępne jednocześnie.

Przykład: core0(Δ=1/10) # core1(Δ=1/5) → str1(Δ=1/15)

### Przesunięcie w czasie (`>n`, STREAM\_TIMEMOVE)

```
SELECT ... STREAM c FROM a > n
```

\\[\Delta_c = \Delta_a\\]

Przesunięcie nie zmienia częstotliwości strumienia — tylko przesuwa okno odczytu o n próbek.

### Agregaty okienkowe (`.max`, `.min`, `.avg`, `.sum`)

\\[\Delta_c = \Delta_a\\]

Agregaty redukują wartości w oknie, ale interwał strumienia wyjściowego pozostaje taki sam jak źródłowego.

### Algorytm AGSE (`@(step, window)`, STREAM\_AGSE)

```
SELECT ... STREAM c FROM a @ (step, window)
```

\\[\Delta_c = \frac{\Delta_a \cdot \text{step}}{\text{windowSize}}\\]

AGSE (Algorytm Generowania Serii Epizodów) generuje okna przesuwne. Interwał wynikowy zależy od kroku i rozmiaru okna względem źródła.

### Operatory de-hash (STREAM\_DEHASH\_DIV, STREAM\_DEHASH\_MOD)

Operacje odwrotne do `#` — wyznaczają, jaki interwał miał jeden ze strumieni wejściowych, znając interwał wyniku i drugiego argumentu:

\\[\Delta_a = \frac{\Delta_c \cdot \Delta_b}{\left|\Delta_c - \Delta_b\right|}\\]

## Dlaczego iteracja?

W zapytaniu z wieloma strumieniami wynikowymi jeden strumień może zależeć od drugiego:

```
DECLARE a INTEGER STREAM core0, 0.1 FILE 'data.dat'
SELECT str1[0] STREAM str1 FROM core0
SELECT str2[0] STREAM str2 FROM str1
```

W pierwszej rundzie iteracji kompilator wyznacza Δ\_str1 = 1/10 (bo Δ\_core0 jest znana). W drugiej rundzie — Δ\_str2 = 1/10 (bo Δ\_str1 jest już znana). Gdyby nie iteracja, str2 musiałoby być zadeklarowane przed str1, co ograniczałoby ekspresywność języka.