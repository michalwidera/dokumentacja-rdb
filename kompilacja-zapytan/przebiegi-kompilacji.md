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

Przesunięcie przenosi milczenie do początku logicznego, a nie wstawia rekordy
prefiksu. Równość fizycznych przesunięć sprawia, że obie strony reguły mają ten
sam emitowany ciąg i ten sam początek logiczny. **Ogony równe nie są**: strona
sfaktoryzowana czyta treść wprost z przeplotu, więc jest gotowa nie później,
a zwykle wcześniej niż strona czytająca składowe po ich własnym przesunięciu.
Reguła jest zatem optymalizacją opóźnienia, nie przepisaniem neutralnym —
zakres twierdzenia R1 i kontrprzykład: [Formalne podstawy
i dowody](../podstawy-matematyczne/formalne-podstawy-i-dowody.md).

#### deduplicateSubstrats

Optymalizacja: jeśli dwa zapytania korzystają z tej samej operacji pośredniej (np. `core0#core1`), etap wskazuje drugie zapytanie na substrat utworzony przez pierwsze. Unika powielania obliczeń — patrz przykład w [Substraty](substraty.md).

#### resolveFieldReferences

Przekształca odwołania do pól ze schematów źródłowych na indeksy w schemacie wynikowym. Obsługuje aliasowanie po sumie — `core0[0]` zamienia na `str1[0]` itp. — oraz zapamiętuje, do którego źródła została rozwiązana goła nazwa pola. Nazwane odwołania zapisane przez użytkownika są śledzone osobno, aby późniejszy przebieg nie pomylił ich z tokenami syntetyzowanymi przez kompilator. Patrz [Aliasowanie](aliasowanie.md).

#### expandIndexWildcards

Rozwija symbol `_` w indeksach pól. Powielenie formuły dla wszystkich pasujących par pól ze schematów argumentów — patrz [Przetwarzanie symbolu \_](przetwarzanie-symbolu-_.md).

#### simplifyFieldExpressions

Upraszcza programy pól `SELECT` oraz warunki `RULE` po rozwiązaniu referencji,
ale przed współdzieleniem równoważnych obliczeń. Przebieg zwija wyrażenia
stałe, łączy ogony stałych w arytmetyce całkowitej i wymiernej oraz usuwa
zgodne typowo elementy neutralne (`E+0`, `E-0`, `E*1`, `E/1`).

Przebieg zachowuje semantykę wartości `NULL` i promocję typów. Dlatego nie
upraszcza `E*0`, nie reasocjuje `FLOAT` ani `DOUBLE` i pozostawia bez zmian
programy, których typu lub działania nie potrafi bezpiecznie ustalić.

#### shareEquivalentSelectComputations

Wykrywa jawne zapytania `SELECT` o równoważnych programach pól i drzewach `FROM` zawierających `STREAM_ADD`. Porządkuje tylko dwoje dzieci pojedynczego węzła `STREAM_ADD`, bez zmiany grupowania całego drzewa. Dla każdej klasy równoważności tworzy jeden substrat `STREAM_SELECT_*`, a publiczne zapytania pozostawia jako lekkie projekcje zachowujące własne nazwy, deskryptory, reguły i storage. Przebieg wykonuje się przed lokalizacją offsetów — patrz [Substraty](substraty.md).

#### localizeFieldOffsets

Przelicza odwołania do pól (`b[x]`, `c[y]`) na pozycje w spłaszczonym schemacie wyniku (`merged[z]`). Dla sumy `+` offset wynika z liczby pól wcześniejszych składowych. Dla przeplotu `#` oba argumenty dzielą te same pozycje wspólnego schematu; tożsamość składowej nie jest już dostępna przez jej nazwę.

Na tym etapie kompilator odrzuca napisane przez użytkownika `A[0]`, `A.pole`, `A[_]`, `A.*` i gołe nazwy pól, jeżeli wskazują składową osiąganą przez `#`. Kontrola obejmuje także warunki `RULE` oraz źródła ukryte w automatycznych substratach. Legalne pozostają odwołania przez nazwę strumienia wynikowego, niekwalifikowane `*` oraz jawne odzyskanie składowej przez `&` lub `%`.

#### computeLogicalOrigin

Oblicza `query::logicalOrigin`, czyli indeks pierwszego rekordu, który **w ogóle
istnieje**. Różnica wobec ogona jest jakościowa: ogon mówi „jeszcze nie teraz",
origin mówi „ten rekord nie ma definicji". Źródłem początku logicznego jest okno
`@(k,L)` stemplowane końcem przedziału — jego wczesne rekordy sięgałyby przed
początek źródła — oraz przesunięcie `>N`, którego rekord `n` niesie rekord `n-N`.
Pozostałe operatory origin wyłącznie przenoszą, tym samym odwzorowaniem indeksu,
którym czytają dane.

Dla `@` i `>N` postać jest zamknięta; dla `+`, `#`, `-`, `Theta` i `~Theta`
przebieg **szuka** najmniejszego indeksu osiągającego próg składowej, połowiąc
po niemalejącym odwzorowaniu. Listing planu pokazuje wartość jako `origin=`.

#### computeStartupLatency

Oblicza `query::startupLatency`, czyli liczbę początkowych slotów własnego
interwału strumienia, w których istniejący wynik nie jest jeszcze gotowy.
Źródła mają ogon 0; `>N` daje `max(0, W_src − N)`, bo czyta rekord starszy od
bieżącego; przeplot uwzględnia ogony obu wejść i fazę rzeczywiście wybieranej
składowej; suma bierze maksimum granic dostępności obu wejść. Różnica oraz oba
rozploty używają dokładnych granic fazowych — lewy rozplot nie dodaje
bezwarunkowo jednego slotu. AGSE używa granicy wynikającej z najnowszego pola
okna, a redukcje nie dodają własnego ogona. Listing planu pokazuje wartość jako
`tail=`; runtime nie emituje podczas ogona żadnego rekordu. Liczba slotów
milczenia wynosi `origin + tail`.

Ten przebieg biegnie po `computeLogicalOrigin` i przed obliczeniem pojemności:
ogon zależy od tego, które sloty są rekordami, a wymagana historia — od chwili
pierwszej emisji konsumenta.

#### computeRequiredCapacities

Oblicza wymagane pojemności buforów dla każdego strumienia na podstawie
odległości między czołem producenta a indeksem czytanym przez konsumenta. Dla
przesunięcia `>N` odległość wsteczna wynosi `W_out-W_src+N`, więc podstawowa
pojemność to `W_out-W_src+N+1`. Jeśli źródłem jest deklaracja, dochodzą dwa
rekordy wyprzedzenia: rekord uzbrojony przy otwarciu storage i zerowy prefetch.
Wynik jest ograniczany od dołu do jednego rekordu. Pojemność historii jest
wymaganiem wykonawczym, a nie prefiksem wyniku.

#### validateConstraints

Weryfikuje poprawność semantyczną skompilowanego planu: zgodność typów, rozmiary okien, dostępność źródeł danych.

#### applyCapacitiesToStreams

Aplikuje obliczone pojemności do obiektów strumieni.

Dla przeplotu kompilator redukuje stosunek
\\(\Delta_a/\Delta_b=p/q\\) do względnie pierwszych dodatnich \\(p,q\\)
i przegląda **jeden pełny okres fazowy** \\(p+q\\). Dla każdego slotu
\\(i\\) tego okresu ustala, którą składową wybiera przeplot i pod jakim
indeksem \\(j(i)\\), po czym bierze maksimum wymaganego opóźnienia:

\\[
W_{\\#}
=\max_{0\le i<p+q}\left(
\left\lceil\frac{\bigl(j(i)+1+W_{s(i)}\bigr)\Delta_{s(i)}}{\Delta_c}\right\rceil
-1-i
\right)
\\]

Wynik jest dokładny — ani nie zaniża, ani nie zawyża granicy przyczynowej.
Rachunek prowadzony jest w arytmetyce 64-bitowej, bo iloczyn
\\((j+1+W)\cdot\text{licznik}\cdot\text{mianownik}\\) przekracza zakres `int`
już dla umiarkowanych interwałów. Powyżej progu `kHashPhaseScanLimit`
(`SOperations.hpp`) koszt przeglądu przestaje być akceptowalny i wraca
poprzednia postać zamknięta \\(\lceil(p+q-1)/p\rceil\\), która zawyża ogon
o slot — wybór bezpieczny, bo zaniżenie oznaczałoby emisję rekordu przed
określeniem jego zależności.

Regresje obejmują między innymi stosunki \\(3/5\\), \\(3/2\\), \\(7/11\\)
i \\(160/147\\), w tym okresowe rekordy w całości `NULL` w nieprzepisanej
lewej stronie tożsamości R1; wzór operatorowy pilnuje test `ut_h10aGate`.

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
