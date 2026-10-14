# Rozwiązywanie interwałów

Każdy strumień w RetractorDB ma przypisany interwał czasowy - delta (Δ). Interwał określa, jak często produkowane są nowe wartości. Dla strumieni deklarowanych (`DECLARE`) interwał podaje użytkownik. Dla strumieni wynikowych (`SELECT`) interwał wyznacza kompilator z równań algebry strumieni.

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

Każda runda rozwiązuje co najmniej jeden strumień - bo graf jest acykliczny i sortowanie topologiczne gwarantuje, że źródła są przetwarzane przed wynikami. Jeśli liczba nierozwiązanych strumieni nie maleje, oznacza to cykl - patrz [Wykrywanie pętli](wykrywanie-petli.md).

## Równania operatorów

### Suma strumieni (`+`, STREAM\_ADD)

```rql
SELECT ... STREAM c FROM a + b
```

\\[\Delta_c = \min(\Delta_a, \Delta_b)\\]

Strumień wynikowy produkuje wartości tak często, jak szybszy ze strumieni wejściowych.

Przykład: core0(Δ=1/10) + core1(Δ=1/5) → str1(Δ=1/10)

### Synchronizacja strumieni (`#`, STREAM\_HASH)

```rql
SELECT ... STREAM c FROM a # b
```

\\[\Delta_c = \frac{\Delta_a \cdot \Delta_b}{\Delta_a + \Delta_b}\\]

Operator `#` przeplata rekordy wejściowe. Częstość wyniku jest sumą częstości wejść, co daje powyższy interwał. Plan określa kolejność wyboru wejścia; oba źródła nie muszą emitować jednocześnie.

Przykład: core0(Δ=1/10) # core1(Δ=1/5) → str1(Δ=1/15)

### Przesunięcie w czasie (`>n`, STREAM\_TIMEMOVE)

```rql
SELECT ... STREAM c FROM a > n
```

\\[\Delta_c = \Delta_a\\]

Przesunięcie nie zmienia częstotliwości ani ciągu emitowanych rekordów, zmienia natomiast indeks, pod którym ten ciąg się pojawia: rekord `m` niesie treść rekordu `m-n`. Jest przyczynowym opóźnieniem, ale jego nośnikiem jest **początek logiczny**, a nie ogon - rekordy o indeksie mniejszym od `n` nie mają definicji. Własny ogon operatora jest niedodatni: wynosi `max(0, W_src − n)`, bo rekord `m-n` jest starszy od bieżącego i tym bardziej dostępny. Listing planu pokazuje obie wielkości jako `origin=` i `tail=`; sloty milczenia to ich suma i runtime nic w nich nie emituje.

Historia źródła wymaga `n+1` rekordów na sam zakres odczytu, a dla źródła deklarowanego dodatkowo dwóch na wyprzedzenie czoła (rekord uzbrojony przy otwarciu storage i zerowy prefetch), którego adresowanie indeksem logicznym nie skraca.

### Reduktory strumieniowe (`MAX`, `MIN`, `AVG`, `SUMC`)

\\[\Delta_c = \Delta_a\\]

Reduktory działają na całym wyrażeniu strumieniowym, np. `AVG(a@(1,10))`. Redukują wartości w rekordzie lub oknie, ale interwał strumienia wyjściowego pozostaje taki sam jak źródłowego. Postać przyrostkowa `.max`, `.min`, `.avg`, `.sumc` jest zgodna wstecz, lecz wygaszana.

### Algorytm AGSE (`@(step, window)`, STREAM\_AGSE)

```rql
SELECT ... STREAM c FROM a @ (step, window)
```

\\[\Delta_c = \frac{\Delta_a \cdot \text{step}}{F_{a}}\\]

AGSE (Algorytm Generowania Serii Epizodów) generuje okna przesuwne. `F_a` oznacza liczbę płaskich wartości w rekordzie źródła, wyznaczoną przez `descriptorStorage().flatElementCount()`. Krok jest liczony po tych wartościach, więc interwał wynikowy zależy od kroku i szerokości rekordu wejściowego. Rozmiar okna wyjściowego określa liczbę wartości w oknie.

### Operatory de-hash (STREAM\_DEHASH\_DIV, STREAM\_DEHASH\_MOD)

Operacje odwrotne do `#` - wyznaczają, jaki interwał miał jeden ze strumieni wejściowych, znając interwał wyniku i drugiego argumentu:

\\[\Delta_a = \frac{\Delta_c \cdot \Delta_b}{\left|\Delta_c - \Delta_b\right|}\\]

## Walidacja interwałów

Interwał źródła `DECLARE` musi być dodatni. Kompilator sprawdza to także dla planu zbudowanego bez parsera. Argumenty interwałowe `&`, `%` i `-` są sprawdzane podczas kompilacji; dla rozplotu `&` i `%` argument równy interwałowi źródła jest dodatkowo odrzucany przed dzieleniem przez zero w powyższym wzorze. Dotyczy to także interwału źródła wyliczonego z innego wyrażenia. W Pythonie taka odmowa jest `CompileError`, po którym można poprawić plan i ponowić kompilację.

Rachunek operatorów używa szerszych liczb całkowitych i sprawdza, czy wynik mieści się w reprezentacji interwału. Wynik spoza zakresu jest odmową planu. Wewnętrzne zero oznaczające jeszcze nierozwiązany węzeł oraz zerowy interwał dyrektywy nie oznaczają dopuszczenia źródła z zerowym krokiem. Po zakończonej kompilacji interwały strumieni są dodatnie; runtime korzysta z tego niezmiennika zamiast ponawiać te same kontrole w każdym rekordzie. Regresje `ut_compiler` obejmują niedodatnie interwały, rozplot równych interwałów i ponowną kompilację poprawnego planu z dyrektywami.

## Dlaczego iteracja?

W zapytaniu z wieloma strumieniami wynikowymi jeden strumień może zależeć od drugiego:

```rql
DECLARE a INTEGER STREAM core0, 0.1 BINFILE 'data.dat'
SELECT str1[0] STREAM str1 FROM core0
SELECT str2[0] STREAM str2 FROM str1
```

W pierwszej rundzie iteracji kompilator wyznacza Δ\_str1 = 1/10 (bo Δ\_core0 jest znana). W drugiej rundzie - Δ\_str2 = 1/10 (bo Δ\_str1 jest już znana). Gdyby nie iteracja, str2 musiałoby być zadeklarowane przed str1, co ograniczałoby ekspresywność języka.
