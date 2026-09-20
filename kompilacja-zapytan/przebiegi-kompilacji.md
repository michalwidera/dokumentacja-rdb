# Przebiegi kompilacji

Kompilacja zapytań w RetractorDB przebiega w wielu etapach. Każdy etap transformuje wewnętrzną reprezentację zapytań - drzewo `qTree` - i przekazuje wynik do następnego. Kolejność jest ściśle ustalona: każdy etap zakłada, że poprzedni zakończył się sukcesem.

`qTree` to `std::vector<query>` - centralna struktura danych kompilatora i executora. Każdy element wektora odpowiada jednemu zapytaniu (`SELECT` lub `DECLARE`) i przechowuje jego schemat pól, sekwencję instrukcji stosu, interwał czasowy, ogon startowy oraz referencje do strumieni źródłowych. Nie każdy etap utrzymuje kolejność wektora: rozwiązanie interwałów sortuje go według `rInterval`. Dlatego kompilacja kończy się bezwarunkowym sortowaniem topologicznym, które gwarantuje, że podczas wykonania producent poprzedza konsumenta.

## Przykład śledzący

Przez cały rozdział śledzimy jedno zapytanie - `query.rql` - przez kolejne etapy:

```rql
DECLARE a BYTE, b INTEGER STREAM core0, 0.1 FILE 'sensor_a.txt'
DECLARE c INTEGER, d FLOAT STREAM core1, 0.2 FILE 'sensor_b.txt'
DECLARE e INTEGER STREAM core2, 0.3 FILE 'sensor_c.txt'

SELECT *                    STREAM merged FROM core0 + core1
SELECT merged[0], merged[2] STREAM result FROM merged
```

Po przejściu przez wszystkie etapy `xretractor -c query.rql` drukuje:

```rasm
{{#include ../regen/out/compile-flow.txt}}
```

Plan jest wydrukowany w końcowym porządku topologicznym: deklaracje `core0` i `core1` poprzedzają swojego konsumenta `merged`, a ten - zapytanie `result`. Nieużywana deklaracja `core2` trafia na koniec. `tail=1` to ogon startowy wyznaczony przez `computeStartupLatency`. Odwołania `PUSH_ID` wskazują pozycje w rekordzie wejściowym zapytania, zapisane pod jego własną nazwą: `result[2]` to trzecie pole rekordu `merged`, czyli `core1.c`.

Lista pól `result` odwołuje się wyłącznie do strumienia z własnej klauzuli `FROM`. Zapis `core1[0]` w tym miejscu kończy się błędem kompilacji `Stream 'result' refers to 'core1', which is not in its FROM clause`: `core1` jest źródłem `merged`, a nie `result` - patrz [Aliasowanie](aliasowanie.md).

Podrozdziały o substratach i symbolu `_` używają rozszerzonych wariantów tego samego zestawu deklaracji. Jak interpretować każdy element tego planu - patrz [Debugowanie kompilacji](debugowanie-kompilacji.md).

## Łańcuch etapów

Łańcuch dwudziestu trzech etapów definiuje funkcja `compiler::compile()`:

<div class="timeline compact">

- `checkFunctionCalls` - nazwy i arność funkcji skalarnych
- `checkStreamReducerFieldRefs` - reduktor strumieniowy poza klauzulą `FROM`
- `expandStreamGenerators` - rozwinięcie rodzin strumieni `nazwa[N]`
- `snapshotNamedSourceRefs` - migawka odwołań zapisanych przez użytkownika
- `extractIntermediateStreams` - wyrażenia `FROM` dwuargumentowe, substraty
- `expandSchemaWildcards` - rozwinięcie `*` oraz `[_]`
- `resolveStreamIntervals` - interwały strumieni, wykrywanie pętli
- `factorMatchedHashTimeMoves` - wyniesienie wspólnego przesunięcia przed przeplot
- `deduplicateSubstrats` - eliminacja powtórzonych substratów
- `validateSubstratNameUniqueness` - jednoznaczność nazw substratów
- `resolveFieldReferences` - odwołania do pól jako indeksy płaskie
- `resolveWindowAggregates` - grupy agregatów okna rekordowego
- `inferFieldShapes` - typ, długość i krotność każdego pola
- `checkRuleConditionShapes` - obliczalność warunków `RULE`
- `simplifyFieldExpressions` - uproszczenie programów pól i reguł
- `shareEquivalentSelectComputations` - współdzielenie równoważnych `SELECT`
- `localizeFieldOffsets` - przesunięcia pól w buforze wejściowym
- `computeLogicalOrigin` - początek logiczny strumienia
- `computeStartupLatency` - ogon startowy
- `computeRequiredCapacities` - wymagana historia buforów
- `validateConstraints` - kontrola semantyczna planu
- `applyCapacitiesToStreams` - zastosowanie pojemności
- `topologicalSort` - końcowy porządek producent–konsument

</div>

Etapy `factorMatchedHashTimeMoves`, `deduplicateSubstrats`, `simplifyFieldExpressions` i `shareEquivalentSelectComputations` są optymalizacjami, które przełączniki `RDB_OPT_*` mogą wyłączyć. Wyłączenie nie zmienia wartości wyniku; może najwyżej wydłużyć ogon startowy (patrz `factorMatchedHashTimeMoves`). Pozostałe etapy wykonują się zawsze.

#### checkFunctionCalls

Sprawdza nazwy i arność funkcji skalarnych względem jednej tabeli `rqlFunctions.hpp`. Dopasowanie ignoruje wielkość liter, a do tokena trafia postać kanoniczna nazwy. Nieznana funkcja lub niedozwolona szerokość kończy kompilację komunikatem `Check result:` jeszcze przed rozwinięciem generatorów, więc jeden błąd szablonu nie jest powielany N razy.

#### checkStreamReducerFieldRefs

Odrzuca reduktor strumieniowy (`MIN`, `MAX`, `AVG`, `SUMC` bez szerokości okna) użyty w programie pola `SELECT` albo w warunku `RULE`. Gramatyka dopuszcza go w wyrażeniu skalarnym, ale tam żaden mechanizm wykonawczy go nie obliczy: zapytanie `SELECT avg STREAM o FROM AVG(src)` przechodziło kompilację i nie emitowało potem ani jednego rekordu. Miejscem reduktora strumieniowego jest klauzula `FROM`; działające `SELECT * FROM AVG(src)` tej kontroli nie podlega. Etap stoi obok `checkFunctionCalls` z tego samego powodu - przed rozwinięciem generatorów.

#### expandStreamGenerators

Rozwija każdy szablon `SELECT ... STREAM nazwa[N] ...` na `N` zwykłych zapytań o nazwach `nazwa$0`...`nazwa$(N-1)` i podstawia numer instancji pod `$` w polach, wartościach oraz odwołaniach klauzuli `FROM`. Jest pierwszym przebiegiem przepisującym plan (poprzedzają go tylko kontrole `checkFunctionCalls` i `checkStreamReducerFieldRefs`): po nim pozostała część kompilatora otrzymuje plan nieodróżnialny od ręcznie rozpisanych zapytań. Składnię i ograniczenia opisuje [Polecenie SELECT](../konstrukcja-jezyka-zapytan/polecenie-select/README.md#generatory-strumieni).

#### snapshotNamedSourceRefs

Zapamiętuje referencje źródłowe zapisane przez użytkownika przed tworzeniem substratów. Późniejsza lokalizacja pól używa tej migawki, aby odróżnić legalne tokeny syntetyczne od odwołań do składowej przeplotu `#`, której tożsamości wynik już nie zachowuje.

#### extractIntermediateStreams

Sprowadza każde wyrażenie FROM do postaci co najwyżej dwuargumentowej. Złożone wyrażenia jak `(core0#core1)+core2` oraz zapisy łańcuchowe bez nawiasów (`core0+core1+core2`, `core0#core1#core2`) wymagają pośrednich strumieni. Każde zapytanie jest redukowane do punktu stałego, więc etap obsługuje również sąsiadujące podwyrażenia jednoargumentowe, np. `(core0>2)#(core1>1)`. Etap tworzy automatycznie substraty - patrz [Substraty](substraty.md).

#### expandSchemaWildcards

Rozwija symbol `*` w klauzuli SELECT oraz indeks `[_]`. Gwiazdkę zastępuje listą pól wynikających ze schematu strumienia źródłowego. Formułę z `x[_]` powiela zgodnie z liczbą slotów, które `x` wnosi do rekordu całej klauzuli `FROM`, a nie według własnej szerokości strumienia `x`. Dzięki temu jednopolowy `x` pod oknem `x@(1,5)` daje pięć elementów. Jeżeli wkład wskazanej nazwy nie tworzy w `FROM` spójnego bloku pól, kompilacja kończy się błędem zamiast przyjąć przypadkową szerokość.

Na tym etapie schematy pochodne rozwijają liczbowy wpis `T[N]` do N pól skalarnych. Deskryptor deklaracji nadal zachowuje jeden wpis tablicowy, a układ bajtów i kolejność płaskich slotów nie zmieniają się. `STRING[N]` pozostaje jednym polem tekstowym. Dzięki temu operatory pochodne, reduktory, AGSE i payload używają tej samej jednostki indeksowania. Patrz [Rozwijanie symbolu \*](rozwijanie-symbolu.md) i [Przetwarzanie symbolu \_](przetwarzanie-symbolu-_.md).

#### resolveStreamIntervals (← tu wykrywane są pętle)

Wyznacza interwał czasowy (delta) każdego strumienia na podstawie operatorów algebraicznych i interwałów strumieni wejściowych. Algorytm iteracyjny - w każdej rundzie rozwiązuje tyle strumieni, ile jest możliwe. Agregat okna rekordowego w liście `SELECT` nie zmienia interwału i wymaga pojedynczego odwołania do strumienia w `FROM`; złożona klauzula jest tutaj odrzucana. Etap wykrywa cykliczne zależności zatrzymując się, gdy liczba nierozwiązanych strumieni przestaje maleć - patrz [Rozwiązywanie interwałów](rozwiazywanie-interwalow.md) i [Wykrywanie pętli](wykrywanie-petli.md).

#### factorMatchedHashTimeMoves

Rozpoznaje dopasowane przesunięcia argumentów przeplotu. Gdy `i·ΔA=k·ΔB`, przepisuje `(A>i)#(B>k)` do `(A#B)>(i+k)`, redukując dwa substraty przesunięcia do jednego substratu przeplotu. Przypadki niedopasowane oraz substraty współdzielone z innymi konsumentami pozostają bez zmian - patrz [Substraty](substraty.md).

Przesunięcie przenosi milczenie do początku logicznego, a nie wstawia rekordy prefiksu. Równość fizycznych przesunięć sprawia, że obie strony reguły mają ten sam emitowany ciąg i ten sam początek logiczny. **Ogony równe nie są**: strona sfaktoryzowana czyta treść wprost z przeplotu, więc jest gotowa nie później, a zwykle wcześniej niż strona czytająca składowe po ich własnym przesunięciu. Reguła jest zatem optymalizacją opóźnienia, nie przepisaniem neutralnym - zakres twierdzenia R1 i kontrprzykład: [Formalne podstawy i dowody](../podstawy-matematyczne/formalne-podstawy-i-dowody.md).

#### deduplicateSubstrats

Optymalizacja: jeśli dwa zapytania korzystają z tej samej operacji pośredniej (np. `core0#core1`), etap wskazuje drugie zapytanie na substrat utworzony przez pierwsze. Unika powielania obliczeń - patrz przykład w [Substraty](substraty.md).

#### validateSubstratNameUniqueness

Sprawdza, czy dwa substraty o tej samej nazwie opisują ten sam program. Nazwy dłuższe niż 200 bajtów są stabilnie skracane przez `composeStreamName()`, więc ta kontrola zamienia skrajnie mało prawdopodobną kolizję 64-bitowego skrótu w głośny błąd zamiast niejednoznacznego planu. Przebieg działa niezależnie od przełączników optymalizatora i następuje po deduplikacji, ponieważ przed nią identyczne duplikaty nazw są stanem przejściowym.

#### resolveFieldReferences

Przekształca odwołania do pól ze schematów źródłowych na indeksy płaskie w schemacie wynikowym. Obsługuje aliasowanie po sumie - `core0[0]` zamienia na `str1[0]` itp. - oraz zapamiętuje, do którego źródła została rozwiązana goła nazwa pola. Nazwane odwołania zapisane przez użytkownika są śledzone osobno, aby późniejszy przebieg nie pomylił ich z tokenami syntetyzowanymi przez kompilator. Goła nazwa liczbowej tablicy jest odrzucana: `a` nie znaczy `a[0]`; trzeba podać element. Patrz [Aliasowanie](aliasowanie.md).

#### resolveWindowAggregates

Wyodrębnia program argumentu każdego agregatu okna - `MIN`, `MAX`, `AVG` albo `SUMC(wyrażenie : W)` - z listy `SELECT` do tabeli `query::windowGroups`. Sprawdza dodatnią szerokość, typ liczbowy, jedno źródło historii, obecność odwołania do pola oraz zakazy zagnieżdżania i użycia w `RULE`. Identyczne trójki źródło–wyrażenie–szerokość współdzielą grupę i jedno przejście po historii. Token agregatu staje się bezargumentowym operandem wskazującym obliczony wynik grupy.

#### inferFieldShapes

Jedyny etap ustalający publiczny kształt pola `SELECT`: typ, długość i krotność. Kształt wynika z całego programu pola - przebieg odtwarza arytmetykę wykonawczą na stosie typów, łącznie z promocją `BYTE`, jawnymi konwersjami w środku wyrażenia, wynikiem agregatu okna oraz szerokością `STRING`. Etap zastąpił wcześniejsze reguły lokalne (`propagateCopiedFieldShapes`, `inferStringFieldTypes`), które rozstrzygały kształt tylko w wybranych przypadkach - patrz [Równanie typów w górę](rownanie-typow-w-gore.md).

Przebieg działa do punktu stałego, bo drzewo jest jeszcze posortowane według interwału i konsument może stać przed producentem. Obejmuje wyłącznie węzły kopiujące schemat operandu; reduktory i okno `@` zachowują schemat zbudowany przez swój operator, a deklaracje `DECLARE` pozostają nietknięte. Etap poprzedza upraszczanie wyrażeń: po zwinięciu stałych szerokość pola zależałaby od przełącznika optymalizacji.

#### checkRuleConditionShapes

Stosuje do warunków `RULE` tę samą kontrolę obliczalności, którą `inferFieldShapes` stosuje do pól. Warunek reguły wykonuje ten sam ewaluator wyrażeń, więc bez tego etapu niepoprawny warunek omijałby kontrolę i dawał po cichu złą wartość. Przebieg niczego nie zapisuje w planie - jedynie odrzuca warunki, których nie da się obliczyć.

#### simplifyFieldExpressions

Upraszcza programy pól `SELECT`, argumenty agregatów okna rekordowego oraz warunki `RULE` po rozwiązaniu referencji, ale przed współdzieleniem równoważnych obliczeń. Przebieg zwija wyrażenia stałe, łączy ogony stałych w arytmetyce całkowitej i wymiernej oraz usuwa zgodne typowo elementy neutralne (`E+0`, `E-0`, `E*1`, `E/1`). Powtórzone dokładne czynniki zapisuje jako potęgę, np. `E*E*E` jako `E^3`.

Przebieg zachowuje semantykę wartości `NULL` i promocję typów. Dlatego nie upraszcza `E*0`, nie reasocjuje `FLOAT` ani `DOUBLE` i pozostawia bez zmian programy, których typu lub działania nie potrafi bezpiecznie ustalić. Redukcja powtórzonego czynnika dotyczy tylko typów o dokładnym mnożeniu (`BYTE`, `INTEGER`, `UINT`, `RATIONAL`); dla `FLOAT` i `DOUBLE` pojedyncze mnożenie nie jest zastępowane wywołaniem `pow`.

#### shareEquivalentSelectComputations

Wykrywa jawne zapytania `SELECT` o równoważnych programach pól i drzewach `FROM` zawierających `STREAM_ADD`. Porządkuje tylko dwoje dzieci pojedynczego węzła `STREAM_ADD`, bez zmiany grupowania całego drzewa. Dla każdej klasy równoważności tworzy jeden substrat `STREAM_SELECT_*`, a publiczne zapytania pozostawia jako lekkie projekcje zachowujące własne nazwy, deskryptory, reguły i storage. Przebieg wykonuje się przed lokalizacją offsetów - patrz [Substraty](substraty.md).

#### localizeFieldOffsets

Przelicza odwołania do pól (`b[x]`, `c[y]`) na pozycje w spłaszczonym rekordzie wejściowym zapytania, zapisywane pod jego własną nazwą (`result[z]`). Dla sumy `+` offset wynika z liczby pól wcześniejszych składowych. Dla przeplotu `#` oba argumenty dzielą te same pozycje wspólnego schematu; tożsamość składowej nie jest już dostępna przez jej nazwę.

Pozycję da się wyznaczyć tylko dla strumieni z klauzuli `FROM` i dla źródeł osiąganych przez substraty wygenerowane przez kompilator. Odwołanie do źródła strumienia pośredniego, który jest zapytaniem użytkownika - np. `core1[0]` przy `FROM merged` - kończy kompilację błędem `Stream '…' refers to '…', which is not in its FROM clause`. Taki strumień ma własny interwał i bufor, więc pozycji jego źródeł w rekordzie wejściowym konsumenta nie ma czym wyznaczyć.

Na tym etapie kompilator odrzuca napisane przez użytkownika `A[0]`, `A.pole`, `A[_]`, `A.*` i gołe nazwy pól, jeżeli wskazują składową osiąganą przez `#`. Kontrola obejmuje także warunki `RULE` oraz źródła ukryte w automatycznych substratach. Legalne pozostają odwołania przez nazwę strumienia wynikowego, niekwalifikowane `*` oraz jawne odzyskanie składowej przez `&` lub `%`.

#### computeLogicalOrigin

Oblicza `query::logicalOrigin`, czyli indeks pierwszego rekordu, który **w ogóle istnieje**. Różnica wobec ogona jest jakościowa: ogon mówi „jeszcze nie teraz", origin mówi „ten rekord nie ma definicji". Źródłem początku logicznego jest okno `@(k,L)` stemplowane końcem przedziału - jego wczesne rekordy sięgałyby przed początek źródła - agregat okna rekordowego, który dodaje `W-1`, oraz przesunięcie `>N`, którego rekord `n` niesie rekord `n-N`. Pozostałe operatory origin wyłącznie przenoszą, tym samym odwzorowaniem indeksu, którym czytają dane.

Dla `@` i `>N` postać jest zamknięta; dla `+`, `#`, `-`, `Theta` i `~Theta` przebieg **szuka** najmniejszego indeksu osiągającego próg składowej, połowiąc po niemalejącym odwzorowaniu. Listing planu pokazuje wartość jako `origin=`.

#### computeStartupLatency

Oblicza `query::startupLatency`, czyli liczbę początkowych slotów własnego interwału strumienia, w których istniejący wynik nie jest jeszcze gotowy. Źródła mają ogon 0; `>N` daje `max(0, W_src − N)`, bo czyta rekord starszy od bieżącego; przeplot uwzględnia ogony obu wejść i fazę rzeczywiście wybieranej składowej; suma bierze maksimum granic dostępności obu wejść. Różnica oraz oba rozploty używają dokładnych granic fazowych - lewy rozplot nie dodaje bezwarunkowo jednego slotu. AGSE używa granicy wynikającej z najnowszego pola okna, a redukcje i agregaty okna rekordowego nie dodają własnego ogona. Listing planu pokazuje wartość jako `tail=`; runtime nie emituje podczas ogona żadnego rekordu. Liczba slotów milczenia wynosi `origin + tail`.

Ten przebieg biegnie po `computeLogicalOrigin` i przed obliczeniem pojemności: ogon zależy od tego, które sloty są rekordami, a wymagana historia - od chwili pierwszej emisji konsumenta.

#### computeRequiredCapacities

Oblicza wymagane pojemności buforów dla każdego strumienia na podstawie odległości między czołem producenta a indeksem czytanym przez konsumenta. Dla przesunięcia `>N` odległość wsteczna wynosi `W_out-W_src+N`, więc podstawowa pojemność to `W_out-W_src+N+1`. Jeśli źródłem jest deklaracja, dochodzą dwa rekordy wyprzedzenia: rekord uzbrojony przy otwarciu storage i zerowy prefetch. Wynik jest ograniczany od dołu do jednego rekordu. Pojemność historii jest wymaganiem wykonawczym, a nie prefiksem wyniku.

Agregat okna rekordowego wymaga zachowania co najmniej W kolejnych rekordów wskazanego źródła. Pojemność uwzględnia także jego początek logiczny, ogon i różnicę interwałów tak samo jak pozostałe odczyty historii; nie jest dobierana wyłącznie jako lokalne `W`.

#### validateConstraints

Weryfikuje poprawność semantyczną skompilowanego planu: zgodność typów i płaskich szerokości, rozmiary okien, dostępność źródeł danych oraz ograniczenia operatorów. Przeplot `#` wymaga równych płaskich schematów, niezależnie od tego, czy wejście zapisano jako `T[N]`, czy jako N pól skalarnych.

#### applyCapacitiesToStreams

Aplikuje obliczone pojemności do obiektów strumieni.

Dla przeplotu kompilator redukuje stosunek \\(\Delta_a/\Delta_b=p/q\\) do względnie pierwszych dodatnich \\(p,q\\) i przegląda **jeden pełny okres fazowy** \\(p+q\\). Dla każdego slotu \\(i\\) tego okresu ustala, którą składową wybiera przeplot i pod jakim indeksem \\(j(i)\\), po czym bierze maksimum wymaganego opóźnienia:

\\[
W_{\\#}
=\max_{0\le i<p+q}\left(
\left\lceil\frac{\bigl(j(i)+1+W_{s(i)}\bigr)\Delta_{s(i)}}{\Delta_c}\right\rceil
-1-i
\right)
\\]

Wynik jest dokładny - ani nie zaniża, ani nie zawyża granicy przyczynowej. Rachunek prowadzony jest w arytmetyce 64-bitowej, bo iloczyn \\((j+1+W)\cdot\text{licznik}\cdot\text{mianownik}\\) przekracza zakres `int` już dla umiarkowanych interwałów. Powyżej progu `kHashPhaseScanLimit` (`SOperations.hpp`) koszt przeglądu przestaje być akceptowalny i wraca poprzednia postać zamknięta \\(\lceil(p+q-1)/p\rceil\\), która zawyża ogon o slot - wybór bezpieczny, bo zaniżenie oznaczałoby emisję rekordu przed określeniem jego zależności.

Regresje obejmują między innymi stosunki \\(3/5\\), \\(3/2\\), \\(7/11\\) i \\(160/147\\), w tym okresowe rekordy w całości `NULL` w nieprzepisanej lewej stronie tożsamości R1; wzór operatorowy pilnuje test `ut_h10aGate`.

#### topologicalSort

Bezwarunkowo przywraca końcowy porządek producent–konsument. Jest to część poprawności wykonania, nie kosmetyka prezentacji planu: interwał wyniku `#` jest mniejszy od interwałów wejść, więc wcześniejsze sortowanie po interwale może przesunąć konsumenta przed producentów.

Przebiegi przepisujące plan są dodatkowo otoczone kontrolą `verifyUserFieldNamesPreserved()`. Optymalizacja może zmieniać i usuwać substraty wewnętrzne, ale nie może zmienić nazw pól żadnego publicznego strumienia, ponieważ trafiają one do obserwowalnego deskryptora `.desc`.


Etapy kontrolne i przepisujące zwracają `"OK"` lub komunikat błędu - wówczas kompilacja się zatrzymuje. Wyniku tego rodzaju nie zwracają `snapshotNamedSourceRefs`, `computeRequiredCapacities` (zwraca mapę pojemności) ani `topologicalSort`. Część niespójności planu, np. odwołanie do nieistniejącego strumienia, przerywa kompilację wyjątkiem zamiast komunikatu.
