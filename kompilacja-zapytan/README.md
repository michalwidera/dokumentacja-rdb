# Kompilacja zapytań

Uważny czytelnik zauważy zapewne, że w przedstawionych w poprzednim rozdziale skompilowanych planach realizacji zapytań pewne wartości nie odpowiadają temu, co zostało napisane w zapytaniu.

Kompilator prowadząc proces budowania planu zapytania prowadzi proces autonomicznie. Wydaje się czasem, że prosząc o jedno - dostaje się coś innego – na pierwszy rzut oka jest to zachowanie zupełnie nieoczywiste. I jako użytkownik nie mam zasadniczo na to wpływu. Co ciekawe efekt zapytania odpowiada temu o co prosiłem w zapytaniu. Być może poprawny tytuł tego rozdziału powinien brzmieć: Dlaczego kompilator robi po swojemu i do tego wie lepiej?

W tym rozdziale chcę wyjaśnić, jak rozwiązałem problemy syntaktyczne, które napotkałem w trakcie tworzenia języka zapytań.

## Wejście i wyjście kompilatora

### Plik `.rql`

Wejście kompilatora - tekst w języku RQL zawierający instrukcje `DECLARE`, `SELECT` i `RULE` oraz dyrektywy konfiguracyjne (np. `:STORAGE`). Parser ANTLR4 czyta plik instrukcja po instrukcji.

Kolejność `DECLARE` i `SELECT` w pliku nie ma znaczenia: zapytanie może odwoływać się do strumienia zdefiniowanego niżej, bo zależności między strumieniami rozwiązuje dopiero kompilator. Wyjątkiem jest `RULE` - parser przypina regułę do strumienia już wczytanego, więc reguła musi stać po definicji swojego strumienia; w przeciwnym razie parser zgłasza błąd `Rule '…' refers to stream '…', but no such stream is defined`. Odwołanie do strumienia, którego w pliku nie ma wcale, przerywa kompilację błędem `Referenced Stream in QUERY _not found_ in CORE TREE`.

### Parser ANTLR4 → `qTree`

Parser buduje wewnętrzną reprezentację `qTree` - `std::vector<query>` - dopisując po jednym elemencie dla każdej instrukcji `DECLARE`, `SELECT` i dyrektywy konfiguracyjnej, w kolejności z pliku i bez sortowania. Element `SELECT` niesie schemat pól z programami stosowymi oraz program klauzuli `FROM` wskazujący strumienie źródłowe. Interwał czasowy (delta) jest na tym etapie znany tylko dla deklaracji `DECLARE`; dla zapytań `SELECT` wyznacza go kompilator. Szablon generatora `STREAM nazwa[N]` jest jeszcze jednym elementem, a reguła `RULE` nie tworzy własnego elementu - trafia na listę reguł swojego strumienia.

Kolejność wektora zmienia się w trakcie kompilacji: rozwiązanie interwałów sortuje go według delty, a porządek topologiczny (producent przed konsumentem) przywraca dopiero ostatni etap.

### 23 etapy kompilacji

`qTree` przechodzi przez łańcuch przekształceń: od rozbicia wyrażeń FROM na operacje dwuargumentowe, przez wyznaczenie delt i offsetów bajtowych, aż po weryfikację semantyczną i obliczenie rozmiarów buforów. Każdy etap zakłada sukces poprzedniego.

### Plan wykonania → `dataModel`

Na wyjściu kompilacji każde zapytanie w `qTree` ma wyznaczone: schemat pól z typami i offsetami, deltę, rozmiary buforów oraz gotową sekwencję instrukcji. Ten plan przejmuje `dataModel` i realizuje go cyklicznie w czasie rzeczywistym.

Flaga `-c` zatrzymuje `xretractor` po tym kroku i drukuje plan na standardowe wyjście - bez uruchamiania przetwarzania.


## Przegląd poruszonych w rozdziale tematów

Rozdział zbudowany jest zgodnie z kolejnością etapów kompilatora - od opisu struktury danych i łańcucha etapów, przez poszczególne przekształcenia, aż po obsługę błędów.

<div class="timeline">

- **[Przebiegi kompilacji](przebiegi-kompilacji.md)**

  Opisuje cały łańcuch etapów funkcji `compiler::compile()`. Kompilacja to nie jeden krok - to uporządkowana sekwencja dwudziestu trzech etapów wewnętrznej reprezentacji `qTree`, od rozwinięcia generatorów i sprowadzenia wyrażeń FROM do postaci dwuargumentowej, przez wyznaczanie interwałów, kontrolę nazw substratów, uproszczenia wyrażeń i lokalizację pól, aż po weryfikację semantyczną, alokację buforów i końcowe sortowanie topologiczne. Każdy etap zakłada sukces poprzedniego, a błąd na dowolnym etapie zatrzymuje kompilację.

- **[Budowa drzewa zależności](budowa-drzewa-zaleznosci.md)**

  Opisuje strukturę DAG powstającego w trakcie kompilacji - fundament, na którym opierają się wszystkie etapy. Korzeniami są deklaracje efemerydów (źródła zewnętrzne), wewnątrz grafu leżą substraty pośrednie, a liśćmi są artefakty. Flaga `-d` generuje wyjście w formacie DOT, które `graphviz` zamienia w wizualny graf zależności. Kolejność `DECLARE` i `SELECT` w pliku `.rql` nie ma znaczenia - graf zależności buduje kompilator; tylko `RULE` musi stać po definicji strumienia, do którego się odnosi.

- **[Substraty](substraty.md)**

  Wyjaśnia etap `extractIntermediateStreams` - pierwszy krok po rozwinięciu generatorów. Gdy wyrażenie FROM zawiera więcej niż dwa argumenty (np. `(core0#core1)+core2`, `core0+core1+core2`), kompilator rozbija je na operacje dwuargumentowe i tworzy nazwane substraty. Późniejszy etap `deduplicateSubstrats` wykrywa, gdy substrat jest strukturalnie identyczny z zapytaniem użytkownika, i zastępuje odwołania - unikając powielania obliczeń.

- **[Rozwijanie symbolu \*](rozwijanie-symbolu.md)**

  Wyjaśnia etap `expandSchemaWildcards`. Symbol `*` w klauzuli SELECT zostaje zastąpiony pełną listą pól wynikających ze schematu strumienia źródłowego - w tym polami pochodzącymi z operacji sumy strumieni. Przykład pokazuje, jak typy pól decydują o tym, które pole trafia na które miejsce w schemacie wynikowym.

- **[Rozwiązywanie interwałów](rozwiazywanie-interwalow.md)**

  Opisuje etap `resolveStreamIntervals`. Kompilator wyznacza deltę każdego strumienia wynikowego z równań algebry strumieniowej: dla operatora `+` delta to minimum wejść, dla `#` - średnia harmoniczna, dla `@(step, window)` - pochodna rozmiaru okna. Algorytm działa iteracyjnie - każda runda rozwiązuje co najmniej jeden strumień, aż wszystkie delty są znane.

- **[Wykrywanie pętli](wykrywanie-petli.md)**

  Opisuje mechanizm wbudowany w etap `resolveStreamIntervals`. Jeśli liczba nierozwiązanych strumieni przestaje maleć, żaden strumień nie może uzyskać delty - znak, że graf zależności zawiera cykl. Kompilacja kończy się błędem `"Circular dependency in stream definitions"`. Rozdział zawiera przykład cyklicznego zapytania i sposób jego naprawy.

- **[Aliasowanie](aliasowanie.md)**

  Opisuje etapy `resolveFieldReferences` i `localizeFieldOffsets`. Po sumie `+` do pola wynikowego można odwołać się zarówno przez indeks w schemacie sumarycznym (`str1[1]`), jak i przez nazwę strumienia źródłowego z lokalnym indeksem (`core1[0]`). Po przeplocie `#` składowe dzielą jeden schemat, dlatego nazwane odwołania do składowych są odrzucane; należy użyć nazwy strumienia wynikowego albo rozplotu `&`/`%`.

- **[Przetwarzanie symbolu \_](przetwarzanie-symbolu-_.md)**

  Opisuje etap `expandIndexWildcards` - cukier syntaktyczny do równoległych operacji na parach pól. Symbol `_` w indeksie powoduje powielenie formuły dla wszystkich zgodnych slotów, które wskazany strumień wnosi do rekordu całej klauzuli `FROM`. Dlatego `src[_] * coef[_]` przy `FROM src@(1,5)+coef` generuje pięć iloczynów, mimo że sam `src` jest jednopolowy. Zastosowanie: budowa zapytań filtrów sygnałowych.

- **[Równanie typów w górę](rownanie-typow-w-gore.md)**

  Definiuje reguły promocji typów obowiązujące przez cały łańcuch kompilacji. Wynik działania `BYTE * INTEGER` ma typ `INTEGER` - kompilator wyznacza typ pola wyjściowego statycznie, zanim dane zostaną przetworzone. Opisano też kompletną hierarchię typów obsługiwanych przez RetractorDB.

- **[Debugowanie kompilacji](debugowanie-kompilacji.md)**

  Zbiera w jednym miejscu narzędzia diagnostyczne: flaga `-c` do inspekcji planu, pipeline `-c -d -f -s` do wizualizacji grafu przez `graphviz`, tablicę znaczeń instrukcji planu (PUSH\_ID, PUSH\_STREAM, STREAM\_ADD, ...) oraz katalog typowych błędów kompilacji z ich przyczynami i sposobem naprawy.

</div>
