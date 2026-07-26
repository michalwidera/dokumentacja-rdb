# Przebiegi kompilacji

Kompilacja zapytań w RetractorDB przebiega w wielu etapach. Każdy etap transformuje wewnętrzną reprezentację zapytań — drzewo `qTree` — i przekazuje wynik do następnego. Kolejność jest ściśle ustalona: każdy etap zakłada, że poprzedni zakończył się sukcesem.

`qTree` to `std::vector<query>` — centralna struktura danych kompilatora
i executora. Każdy element wektora odpowiada jednemu zapytaniu (`SELECT` lub
`DECLARE`) i przechowuje jego schemat pól, sekwencję instrukcji stosu,
interwał czasowy, ogon startowy oraz referencje do strumieni źródłowych.
Nie każdy etap utrzymuje kolejność wektora: rozwiązanie interwałów sortuje go
według `rInterval`. Dlatego kompilacja kończy się bezwarunkowym sortowaniem
topologicznym, które gwarantuje, że podczas wykonania producent poprzedza
konsumenta.

## Przykład śledzący

Przez cały rozdział śledzimy jedno zapytanie — `query.rql` — przez kolejne etapy:

```
DECLARE a BYTE, b INTEGER \
STREAM core0, 0.1 \
FILE 'sensor_a.txt'

DECLARE c INTEGER, d FLOAT \
STREAM core1, 0.2 \
FILE 'sensor_b.txt'

DECLARE e INTEGER \
STREAM core2, 0.3 \
FILE 'sensor_c.txt'

SELECT * \
STREAM merged \
FROM core0 + core1

SELECT merged[0], merged[2], core0[0], core1[0] \
STREAM result \
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

#### extractIntermediateStreams

Sprowadza każde wyrażenie FROM do postaci co najwyżej dwuargumentowej. Złożone wyrażenia jak `(core0#core1)+core2` oraz zapisy łańcuchowe bez nawiasów (`core0+core1+core2`, `core0#core1#core2`) wymagają pośrednich strumieni. Każde zapytanie jest redukowane do punktu stałego, więc etap obsługuje również sąsiadujące podwyrażenia jednoargumentowe, np. `(core0>2)#(core1>1)`. Etap tworzy automatycznie substraty — patrz [Substraty](substraty.md).

#### expandSchemaWildcards

Rozwija symbol `*` w klauzuli SELECT. Zastępuje go listą pól wynikających z schematu strumienia źródłowego — patrz [Rozwijanie symbolu \*](rozwijanie-symbolu.md).

#### resolveStreamIntervals (← tu wykrywane są pętle)

Wyznacza interwał czasowy (delta) każdego strumienia na podstawie operatorów algebraicznych i interwałów strumieni wejściowych. Algorytm iteracyjny — w każdej rundzie rozwiązuje tyle strumieni, ile jest możliwe. Wykrywa cykliczne zależności zatrzymując się, gdy liczba nierozwiązanych strumieni przestaje maleć — patrz [Rozwiązywanie interwałów](rozwiazywanie-interwalow.md) i [Wykrywanie pętli](wykrywanie-petli.md).

#### factorMatchedHashTimeMoves

Rozpoznaje dopasowane przesunięcia argumentów przeplotu. Gdy `i·ΔA=k·ΔB`, przepisuje `(A>i)#(B>k)` do `(A#B)>(i+k)`, redukując dwa substraty przesunięcia do jednego substratu przeplotu. Przypadki niedopasowane oraz substraty współdzielone z innymi konsumentami pozostają bez zmian — patrz [Substraty](substraty.md).

Przesunięcie zwiększa ogon startowy, a nie wstawia rekordy prefiksu.
Równość fizycznych przesunięć sprawia, że obie strony reguły mają ten sam
emitowany ciąg oraz ten sam ogon po przeliczeniu na sloty wyniku.

#### deduplicateSubstrats

Optymalizacja: jeśli dwa zapytania korzystają z tej samej operacji pośredniej (np. `core0#core1`), etap wskazuje drugie zapytanie na substrat utworzony przez pierwsze. Unika powielania obliczeń — patrz przykład w [Substraty](substraty.md).

#### resolveFieldReferences

Przekształca odwołania do pól ze schematów źródłowych na indeksy w schemacie wynikowym. Obsługuje aliasowanie — `core0[0]` zamienia na `str1[0]` itp. — patrz [Aliasowanie](aliasowanie.md).

#### expandIndexWildcards

Rozwija symbol `_` w indeksach pól. Powielenie formuły dla wszystkich pasujących par pól ze schematów argumentów — patrz [Przetwarzanie symbolu \_](przetwarzanie-symbolu-_.md).

#### shareEquivalentSelectComputations

Wykrywa jawne zapytania `SELECT` o równoważnych programach pól i drzewach `FROM` zawierających `STREAM_ADD`. Porządkuje tylko dwoje dzieci pojedynczego węzła `STREAM_ADD`, bez zmiany grupowania całego drzewa. Dla każdej klasy równoważności tworzy jeden substrat `STREAM_SELECT_*`, a publiczne zapytania pozostawia jako lekkie projekcje zachowujące własne nazwy, deskryptory, reguły i storage. Przebieg wykonuje się przed lokalizacją offsetów — patrz [Substraty](substraty.md).

#### localizeFieldOffsets

Przelicza referencje do pól (`b[x]`, `c[y]`) na indeksy w spłaszczonym schemacie wynikowym (`merged[z]`). Dla ADD indeks wynika z sumy liczności pól poprzedzających strumieni; dla HASH każde pole otrzymuje indeks 0 (schemat jednoargumentowy). Etap uwzględnia nie tylko źródła bezpośrednie, ale także źródła przechodnie ukryte za automatycznymi substratami.

#### computeRequiredCapacities

Oblicza wymagane pojemności buforów dla każdego strumienia na podstawie
rozmiarów schematów i wymagań okien czasowych. Po zakończeniu ogona
przesunięcie `>N` odczytuje slot historii o indeksie `N`, dlatego wymaga
`N+1` rekordów (slot 0 jest rekordem bieżącym). Pojemność historii jest
wymaganiem wykonawczym, a nie prefiksem wyniku.

#### validateConstraints

Weryfikuje poprawność semantyczną skompilowanego planu: zgodność typów, rozmiary okien, dostępność źródeł danych.

#### applyCapacitiesToStreams

Aplikuje obliczone pojemności do obiektów strumieni.

#### computeStartupLatency

Oblicza `query::startupLatency`, czyli liczbę początkowych slotów własnego
interwału strumienia, w których wynik nie jest jeszcze zdefiniowany.
Źródła mają ogon 0, `>N` dodaje `N`, przeplot uwzględnia ogony obu wejść
i własne wyprzedzenie drugiego argumentu, suma bierze maksimum przeliczonych
ogonów, a lewy rozplot `Theta` dodaje jeden slot. Listing planu pokazuje
wartość jako `tail=`. Runtime nie emituje podczas ogona żadnego rekordu.

#### topologicalSort

Bezwarunkowo przywraca końcowy porządek producent–konsument. Jest to część
poprawności wykonania, nie kosmetyka prezentacji planu: interwał wyniku `#`
jest mniejszy od interwałów wejść, więc wcześniejsze sortowanie po interwale
może przesunąć konsumenta przed producentów.

Przebiegi przepisujące plan są dodatkowo otoczone kontrolą
`verifyUserFieldNamesPreserved()`. Optymalizacja może zmieniać i usuwać
substraty wewnętrzne, ale nie może zmienić nazw pól żadnego publicznego
strumienia, ponieważ trafiają one do obserwowalnego deskryptora `.desc`.


Każdy etap zwraca `"OK"` lub komunikat błędu — wówczas kompilacja się zatrzymuje.
