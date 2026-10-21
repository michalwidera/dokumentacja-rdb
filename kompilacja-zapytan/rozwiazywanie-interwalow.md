# Rozwiązywanie interwałów

Każdy strumień w RetractorDB ma przypisany interwał czasowy - delta (Δ). Interwał określa, jak często produkowane są nowe wartości. Dla strumieni deklarowanych (`DECLARE`) interwał podaje użytkownik. Dla strumieni wynikowych (`SELECT`) interwał wyznacza kompilator z równań algebry strumieni.

Przykłady w tym rozdziale używają kanonicznych deklaracji z całego rozdziału: `core0` (Δ=1/10), `core1` (Δ=1/5), `core2` (Δ=3/10).

## Algorytm

Etap `resolveStreamIntervals` działa iteracyjnie. Interwały deklarowanych źródeł są już znane i dodatnie, a nierozwiązany interwał strumienia wynikowego ma wewnętrzną wartość zero. Istnienie wszystkich źródeł jest sprawdzane przed tym etapem.

```
pętla:
    unresolvedCount = 0
    resolvedThisPass = 0
    posortuj qTree po rosnącym interwale
    dla każdego zapytania poza deklaracjami i dyrektywami:
        jeśli którykolwiek interwał źródłowy jest nierozwiązany:
            unresolvedCount++
            przejdź do następnego zapytania
        wyznacz deltę wynikową z równania operatora
        jeśli interwał tego zapytania był nierozwiązany:
            resolvedThisPass++
        zapisz wyznaczoną deltę
    jeśli unresolvedCount == 0: koniec (sukces)
    jeśli resolvedThisPass == 0: błąd (cykl w grafie)
```

Wywołanie `qTree::sort()` porządkuje węzły według interwału, a nie topologicznie. Producent nie musi więc poprzedzać konsumenta. Interwał wyznaczony wcześniej w tej samej rundzie jest od razu dostępny dla kolejnych zapytań.

W poprawnym grafie acyklicznym każda runda z nierozwiązanymi węzłami rozwiązuje co najmniej jeden z nich: wśród tych węzłów istnieje taki, którego wszystkie źródła są już rozwiązane. Znane interwały pozostają znane, więc liczba nierozwiązanych węzłów maleje. Jeśli po rundzie nadal istnieją nierozwiązane węzły, ale `resolvedThisPass == 0`, występuje cykl - patrz [Wykrywanie pętli](wykrywanie-petli.md). Niepoprawny argument operatora lub wynik poza zakresem reprezentacji powoduje osobną odmowę kompilacji.

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

### Różnica strumienia (`- r`, STREAM\_SUBTRACT)

```rql
SELECT ... STREAM c FROM a - r
```

\\[\Delta_c = r,\qquad r \geq \Delta_a > 0\\]

Argument `r` jest docelowym interwałem, a nie wielkością odejmowaną od interwału źródła. Operator wybiera rekordy źródła w tym takcie. Równy interwał zachowuje takt źródła, większy daje wolniejszy wynik, a mniejszy jest odrzucany podczas walidacji ograniczeń planu.

### Przesunięcie w czasie (`>n`, STREAM\_TIMEMOVE)

```rql
SELECT ... STREAM c FROM a > n
```

\\[\Delta_c = \Delta_a\\]

Przesunięcie nie zmienia częstotliwości ani ciągu emitowanych rekordów, zmienia natomiast indeks, pod którym ten ciąg się pojawia: rekord `m` niesie treść rekordu `m-n`. Jest przyczynowym opóźnieniem, ale jego nośnikiem jest **początek logiczny**, a nie ogon - rekordy o indeksie mniejszym od `n` nie mają definicji. Własny ogon operatora jest nieujemny: wynosi `max(0, W_src - n)`, bo rekord `m-n` jest starszy od bieżącego i tym bardziej dostępny. Listing planu pokazuje obie wielkości jako `origin=` i `tail=`; sloty milczenia to ich suma i runtime nic w nich nie emituje.

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

Jeśli `c = a # b`, operator `&` wyznacza interwał składowej `a` na podstawie interwału przeplotu `c` i argumentu oznaczającego interwał drugiej składowej `b`. Odwrócenie równania przeplotu daje:

\\[\Delta_a = \frac{\Delta_c \cdot \Delta_b}{\Delta_b - \Delta_c},\qquad 0 < \Delta_c < \Delta_b\\]

Warunek dziedziny wynika z dodatniości interwałów: przeplot ma większą częstość niż każda ze składowych. Dla operatora `%` role `a` i `b` zamieniają się.

Implementacja używa ogólnie wzoru z wartością bezwzględną:

\\[\Delta_a = \frac{\Delta_c \cdot \Delta_b}{\left|\Delta_c - \Delta_b\right|}\\]

Kompilator odrzuca równe interwały oraz wynik szybszy od źródła, czyli `Delta_a < Delta_c`. Może przyjąć również argument spoza dziedziny odwracania przeplotu. Na przykład dla `Delta_c = 3/2` i `Delta_b = 1` wyznacza `Delta_a = 3`, ale przeplot interwałów `3` i `1` ma interwał `3/4`, a nie `3/2`. Wartość bezwzględna nie czyni więc tego wzoru odwrotnością `#` poza podaną dziedziną.

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

Oba strumienie wynikowe mają interwał `1/10`. Jeśli w danej rundzie `str1` zostanie odwiedzony przed `str2`, oba interwały mogą zostać wyznaczone w tej samej rundzie. Jeśli kolejność będzie odwrotna, `str2` poczeka do następnej rundy, ponieważ przy jego odwiedzeniu interwał `str1` nie był jeszcze znany.

Iteracja uniezależnia wynik od kolejności odwiedzania węzłów po sortowaniu według interwału. Kolejność zapisania zapytań w pliku nie narzuca kolejności ich rozwiązywania. Gdyby ten etap przetwarzał graf w rzeczywistym porządku topologicznym, cały poprawny łańcuch zależności można byłoby rozwiązać w jednym przejściu.
