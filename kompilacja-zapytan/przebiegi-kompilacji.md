# Przebiegi kompilacji

Kompilacja zapytań w RetractorDB przebiega w wielu etapach. Każdy etap transformuje wewnętrzną reprezentację zapytań — drzewo `qTree` — i przekazuje wynik do następnego. Kolejność jest ściśle ustalona: każdy etap zakłada, że poprzedni zakończył się sukcesem.

`qTree` to topologicznie posortowany `std::vector<query>` — centralna struktura danych kompilatora i executora. Każdy element wektora odpowiada jednemu zapytaniu (`SELECT` lub `DECLARE`) i przechowuje jego schemat pól, sekwencję instrukcji stosu, interwał czasowy oraz referencje do strumieni źródłowych. Sortowanie topologiczne gwarantuje, że strumień źródłowy zawsze poprzedza strumień wynikowy — etapy mogą przetwarzać `qTree` liniowo, bez nawrotów.

## Przykład śledzący

Przez cały rozdział śledzimy jedno zapytanie — `query.rql` — przez kolejne etapy:

```
DECLARE a BYTE, b INTEGER 
STREAM core0, 0.1
FILE 'sensor_a.txt'

DECLARE c INTEGER, d FLOAT
STREAM core1, 0.2
FILE 'sensor_b.txt'

DECLARE e INTEGER
STREAM core2, 0.3
FILE 'sensor_c.txt'

SELECT *
STREAM merged
FROM core0 + core1

SELECT merged[0], merged[2], core0[0], core1[0]
STREAM result
FROM merged
```

Po przejściu przez wszystkie etapy `xretractor -c query.rql` drukuje:

```
merged(1/10)
        :- PUSH_STREAM(core0)
        :- PUSH_STREAM(core1)
        :- STREAM_ADD
        core0_0: BYTE
                PUSH_ID(merged[0])
        core0_1: INTEGER
                PUSH_ID(merged[1])
        core1_2: INTEGER
                PUSH_ID(merged[2])
        core1_3: FLOAT
                PUSH_ID(merged[3])
result(1/10)
        :- PUSH_STREAM(merged)
        result_0: BYTE
                PUSH_ID(merged[0])
        result_1: INTEGER
                PUSH_ID(merged[2])
        result_2: BYTE
                PUSH_ID(merged[0])
        result_3: INTEGER
                PUSH_ID(merged[2])
core0(1/10)     sensor_a.txt
        a: BYTE
        b: INTEGER
core1(1/5)      sensor_b.txt
        c: INTEGER
        d: FLOAT
core2(3/10)     sensor_c.txt
        e: INTEGER
```

Podrozdziały o substratach i symbolu `_` używają rozszerzonych wariantów tego samego zestawu deklaracji. Jak interpretować każdy element tego planu — patrz [Debugowanie kompilacji](debugowanie-kompilacji.md).

## Łańcuch etapów

Łańcuch etapów definiuje funkcja `compiler::compile()`:

{% stepper %}
{% step %}
#### extractIntermediateStreams

Sprowadza każde wyrażenie FROM do postaci co najwyżej dwuargumentowej. Złożone wyrażenia jak `(core0#core1)+core2` oraz zapisy łańcuchowe bez nawiasów (`core0+core1+core2`, `core0#core1#core2`) wymagają pośrednich strumieni. Etap tworzy automatycznie substraty — patrz [Substraty](substraty.md).
{% endstep %}

{% step %}
#### expandSchemaWildcards

Rozwija symbol `*` w klauzuli SELECT. Zastępuje go listą pól wynikających z schematu strumienia źródłowego — patrz [Rozwijanie symbolu \*](rozwijanie-symbolu.md).
{% endstep %}

{% step %}
#### resolveStreamIntervals (← tu wykrywane są pętle)

Wyznacza interwał czasowy (delta) każdego strumienia na podstawie operatorów algebraicznych i interwałów strumieni wejściowych. Algorytm iteracyjny — w każdej rundzie rozwiązuje tyle strumieni, ile jest możliwe. Wykrywa cykliczne zależności zatrzymując się, gdy liczba nierozwiązanych strumieni przestaje maleć — patrz [Rozwiązywanie interwałów](rozwiazywanie-interwalow.md) i [Wykrywanie pętli](wykrywanie-petli.md).
{% endstep %}

{% step %}
#### deduplicateSubstrats

Optymalizacja: jeśli dwa zapytania korzystają z tej samej operacji pośredniej (np. `core0#core1`), etap wskazuje drugie zapytanie na substrat utworzony przez pierwsze. Unika powielania obliczeń — patrz przykład w [Substraty](substraty.md).
{% endstep %}

{% step %}
#### resolveFieldReferences

Przekształca odwołania do pól ze schematów źródłowych na indeksy w schemacie wynikowym. Obsługuje aliasowanie — `core0[0]` zamienia na `str1[0]` itp. — patrz [Aliasowanie](aliasowanie.md).
{% endstep %}

{% step %}
#### expandIndexWildcards

Rozwija symbol `_` w indeksach pól. Powielenie formuły dla wszystkich pasujących par pól ze schematów argumentów — patrz [Przetwarzanie symbolu \_](przetwarzanie-symbolu-_.md).
{% endstep %}

{% step %}
#### localizeFieldOffsets

Przelicza referencje do pól (`b[x]`, `c[y]`) na indeksy w spłaszczonym schemacie wynikowym (`merged[z]`). Dla ADD indeks wynika z sumy liczności pól poprzedzających strumieni; dla HASH każde pole otrzymuje indeks 0 (schemat jednoargumentowy). Etap uwzględnia nie tylko źródła bezpośrednie, ale także źródła przechodnie ukryte za automatycznymi substratami.
{% endstep %}

{% step %}
#### computeRequiredCapacities

Oblicza wymagane pojemności buforów dla każdego strumienia na podstawie rozmiarów schematów i wymagań okien czasowych.
{% endstep %}

{% step %}
#### validateConstraints

Weryfikuje poprawność semantyczną skompilowanego planu: zgodność typów, rozmiary okien, dostępność źródeł danych.
{% endstep %}

{% step %}
#### applyCapacitiesToStreams

Aplikuje obliczone pojemności do obiektów strumieni. Po tym etapie plan jest gotowy do wykonania przez `dataModel`.
{% endstep %}
{% endstepper %}

Każdy etap zwraca `"OK"` lub komunikat błędu — wówczas kompilacja się zatrzymuje.
