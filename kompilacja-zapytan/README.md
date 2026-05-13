---
description: >-
  Idąc tą ścieżką nie liczyłem się z koniecznością zdobycia umiejętności
  opisanych w księdze smoka.
icon: '4'
---

# Kompilacja zapytań

Uważny czytelnik zauważy zapewne, że w przedstawionych w poprzednim rozdziale skompilowanych planach realizacji zapytań pewne wartości nie odpowiadają temu, co zostało napisane w zapytaniu.

Kompilator prowadząc proces budowania planu zapytania prowadzi proces autonomicznie. Wydaje się czasem, że prosząc o jedno - dostaje się coś innego – na pierwszy rzut oka jest to zachowanie zupełnie nieoczywiste. I jako użytkownik nie mam zasadniczo na to wpływu. Co ciekawe efekt zapytania odpowiada temu o co prosiłem w zapytaniu. Być może poprawny tytuł tego rozdziału powinien brzmieć: Dlaczego kompilator robi po swojemu i do tego wie lepiej?

W tym rozdziale chcę wyjaśnić, jak rozwiązałem problemy syntaktyczne, które napotkałem w trakcie tworzenia języka zapytań.

## Wejście i wyjście kompilatora

Wejściem kompilatora jest plik `.rql` — tekst w języku RetractorQL. Parser ANTLR4 przetwarza go i buduje wewnętrzną reprezentację `qTree`: topologicznie posortowany wektor zapytań, w którym każde zapytanie opisuje jeden strumień wynikowy wraz z jego operacjami i zależnościami.

`qTree` przechodzi przez łańcuch dziesięciu etapów przekształceń. Na wyjściu kompilacji `qTree` jest gotowym planem wykonania — każde zapytanie ma wyznaczone: schemat pól z typami i offsetami bajtowymi, interwał czasowy (deltę), rozmiary buforów oraz sekwencję instrukcji stosu. Ten plan przejmuje `dataModel` i realizuje go cyklicznie w czasie rzeczywistym.

```
plik .rql  →  parser ANTLR4  →  qTree  →  10 etapów kompilacji  →  plan wykonania  →  dataModel
```

Tryb `-c` zatrzymuje `xretractor` po kompilacji i drukuje skompilowany plan na standardowe wyjście — bez uruchamiania przetwarzania. To główne narzędzie diagnostyczne podczas pisania zapytań.

## Przegląd poruszonych w rozdziale tematów

Rozdział zbudowany jest zgodnie z kolejnością etapów kompilatora — od opisu struktury danych i łańcucha etapów, przez poszczególne przekształcenia, aż po obsługę błędów.

{% stepper %}
{% step %}
[**Przebiegi kompilacji**](przebiegi-kompilacji.md) opisuje cały łańcuch etapów funkcji `compiler::compile()`. Kompilacja to nie jeden krok — to sekwencja dziesięciu kolejnych przekształceń wewnętrznej reprezentacji `qTree`, od sprowadzenia wyrażeń FROM do postaci dwuargumentowej, przez wyznaczanie interwałów i offsetów pól, aż po weryfikację semantyczną i alokację buforów. Każdy etap zakłada sukces poprzedniego i zwraca komunikat błędu, gdy warunki nie są spełnione.
{% endstep %}

{% step %}
[**Budowa drzewa zależności**](budowa-drzewa-zaleznosci.md) opisuje strukturę DAG powstającego w trakcie kompilacji — fundament, na którym opierają się wszystkie etapy. Korzeniami są deklaracje efemerydów (źródła zewnętrzne), wewnątrz grafu leżą substraty pośrednie, a liśćmi są artefakty. Flaga `-d` generuje wyjście w formacie DOT, które `graphviz` zamienia w wizualny graf zależności. Kolejność zapytań w pliku `.rql` ma znaczenie — odwołanie do niezdefiniowanego jeszcze strumienia kończy się błędem.
{% endstep %}

{% step %}
[**Substraty**](substraty.md) wyjaśnia etap `extractIntermediateStreams` — pierwszy krok kompilacji. Gdy wyrażenie FROM zawiera więcej niż dwa argumenty (np. `(core0#core1)+core2`), kompilator rozbija je na operacje dwuargumentowe i tworzy nazwane substraty. Późniejszy etap `deduplicateSubstrats` wykrywa, gdy substrat jest strukturalnie identyczny z zapytaniem użytkownika, i zastępuje odwołania — unikając powielania obliczeń.
{% endstep %}

{% step %}
[**Rozwijanie symbolu \***](rozwijanie-symbolu.md) wyjaśnia etap `expandSchemaWildcards`. Symbol `*` w klauzuli SELECT zostaje zastąpiony pełną listą pól wynikających ze schematu strumienia źródłowego — w tym polami pochodzącymi z operacji sumy strumieni. Przykład pokazuje, jak typy pól decydują o tym, które pole trafia na które miejsce w schemacie wynikowym.
{% endstep %}

{% step %}
[**Rozwiązywanie interwałów**](rozwiazywanie-interwalow.md) opisuje etap `resolveStreamIntervals`. Kompilator wyznacza deltę każdego strumienia wynikowego z równań algebry strumieniowej: dla operatora `+` delta to minimum wejść, dla `#` — średnia harmoniczna, dla `@(step, window)` — pochodna rozmiaru okna. Algorytm działa iteracyjnie — każda runda rozwiązuje co najmniej jeden strumień, aż wszystkie delty są znane.
{% endstep %}

{% step %}
[**Wykrywanie pętli**](wykrywanie-petli.md) opisuje mechanizm wbudowany w etap `resolveStreamIntervals`. Jeśli liczba nierozwiązanych strumieni przestaje maleć, żaden strumień nie może uzyskać delty — znak, że graf zależności zawiera cykl. Kompilacja kończy się błędem `"Circular dependency in stream definitions"`. Rozdział zawiera przykład cyklicznego zapytania i sposób jego naprawy.
{% endstep %}

{% step %}
[**Aliasowanie**](aliasowanie.md) opisuje etap `resolveFieldReferences`. Do pola wynikowego można odwoływać się zarówno przez indeks w schemacie sumarycznym (`str1[1]`), jak i przez nazwę strumienia źródłowego z lokalnym indeksem (`core1[0]`). Kompilator tłumaczy obie formy na tę samą pozycję w buforze wynikowym.
{% endstep %}

{% step %}
[**Przetwarzanie symbolu \_**](przetwarzanie-symbolu-_.md) opisuje etap `expandIndexWildcards` — cukier syntaktyczny do równoległych operacji na parach pól. Symbol `_` w indeksie powoduje powielenie formuły dla wszystkich par pól ze schematów obu argumentów — `core0[_] * core1[_]` przy dwupólowych schematach generuje dwa pola mnożące odpowiadające pary. Zastosowanie: budowa zapytań filtrów sygnałowych.
{% endstep %}

{% step %}
[**Równanie typów w górę**](rownanie-typow-w-gore.md) definiuje reguły promocji typów obowiązujące przez cały łańcuch kompilacji. Wynik działania `BYTE * INTEGER` ma typ `INTEGER` — kompilator wyznacza typ pola wyjściowego statycznie, zanim dane zostaną przetworzone. Opisano też kompletną hierarchię typów obsługiwanych przez RetractorDB.
{% endstep %}

{% step %}
[**Debugowanie kompilacji**](debugowanie-kompilacji.md) zbiera w jednym miejscu narzędzia diagnostyczne: flaga `-c` do inspekcji planu, pipeline `-c -d -f -s` do wizualizacji grafu przez `graphviz`, tablicę znaczeń instrukcji planu (PUSH\_ID, PUSH\_STREAM, STREAM\_ADD, ...) oraz katalog typowych błędów kompilacji z ich przyczynami i sposobem naprawy.
{% endstep %}
{% endstepper %}
