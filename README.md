# RetractorDB

RetractorDB to brzegowy silnik przetwarzania sygnałów (ang. *Edge Signal Processing Engine*, ESPE), przeznaczony do ciągłego przetwarzania regularnych serii czasowych blisko źródła danych. Za pomocą deklaratywnego języka RQL opisuje przekształcenia, agregacje i reguły, a ich wyniki udostępnia na żywo lub materializuje w postaci artefaktów, które można później przeglądać i korygować. System wspiera centralne bazy szeregów czasowych i systemy strumieniowe, ograniczając ilość przesyłanych do nich danych, lecz ich nie zastępuje.

Nazwa odzwierciedla połączenie dwóch idei. **Retractor** oznacza narzędzie, które wydobywa, rozdziela, łączy i przetwarza dane zawarte w seriach czasowych, natomiast człon **DB** wskazuje na rozwiązania znane z baz danych: deklaratywny język zapytań, opis schematu, mechanizmy dostępu oraz trwałe przechowywanie wyników. Więcej o pochodzeniu nazwy można przeczytać w rozdziale [Dlaczego wybrano taką nazwę dla systemu?](zalaczniki/geneza-systemu/dlaczego-wybrano-taka-nazwe-dla-systemu.md).

Dokumentacja prowadzi od [podstaw matematycznych](podstawy-matematyczne/README.md) i [konstrukcji języka RQL](konstrukcja-jezyka-zapytan/README.md), przez [architekturę systemu](architektura-systemu-przetwarzania-danych/README.md), kompilację i realizację zapytań, aż po przykłady zastosowań oraz załączniki z opisem narzędzi. Przy pierwszym kontakcie najlepiej czytać rozdziały w kolejności podanej w spisie treści, ponieważ kolejne części korzystają z pojęć wprowadzonych wcześniej. Czytelnik szukający konkretnego rozwiązania może przejść bezpośrednio do odpowiedniego rozdziału, a następnie skorzystać z przykładów i załączników jako materiału praktycznego i referencyjnego.

## RetractorDB na tle sąsiednich dziedzin

Ten rozdział jest mapą, nie katalogiem. Zamiast wyliczać wszystko, co kiedykolwiek napisano o strumieniach i sygnałach, pokazuję pięć nurtów recenzowanej literatury, na styku których leży RetractorDB, i dla każdego z nich odpowiadam na trzy pytania: co ten nurt już rozwiązał, w czym RetractorDB się od niego różni i czego ten nurt **nie** dotyka. Dopiero nałożenie tych pięciu warstw na siebie pokazuje lukę, którą ten projekt wypełnia.

<div class="no-print">

> **📥 Pobierz dokumentację**
>
> Ta dokumentacja w całości jest kompilowana z plików w formacie markdown. Kopilowane są 3 cele. Pierwszy to strona html, którą teraz widzisz. Drugi to plik pdf, trzeci to dokument epub na czytnik. Za każdym razem po zmianie zawartości repozytorium na github gdzie przechowywane są pliki markdown uruchamiany jest proces tworzący te 3 cele. 
> * [retractordb.pdf](retractordb.pdf) 
> * [retractordb.epub](retractordb.epub)

</div>

> **✅ Uwaga**
>
> Ten system to: Edge Signal Processing Engine (Brzegowy System Przetwarzania Sygnałów). RetractorDB wspiera – a nie zastępuje – bazy szeregów czasowych (TSDB) i strumieniowe systemy zarządzania danymi (DSMS): pracuje blisko źródła sygnału, wstępnie przetwarza i filtruje wysokoczęstotliwościowe pomiary za pomocą deklaratywnego języka zapytań, utrzymuje częściowy, korygowalny zapis zdarzeń przeszłych i zaplanowanych przyszłych w inspekcjonowalnych artefaktach, a w górę architektury przekazuje dokładne, deterministyczne wyniki – tak, aby do centralnej architektury docierały wyłącznie zredukowane, już przetworzone strumienie.


> **ℹ Info**
>
> Dlaczego umieściłem ten rozdział tak wcześnie? Bo uczciwa odpowiedź na pytanie „czy to jest potrzebne?" wymaga najpierw pokazania, co już istnieje. Większość pomysłów w informatyce została już raz pomyślana – wymyślanie koła na nowo to marnowanie cudzego wysiłku. Ten rozdział jest moją próbą udowodnienia, że akurat tego koła jeszcze nie wynaleziono.


## Pięć sąsiednich dziedzin

Problem, który rozwiązuje RetractorDB, nie należy w całości do żadnej pojedynczej dyscypliny. Siedzi w szczelinie między pięcioma:

1. **Teoria liczb** – sekwencje Beatty'ego, twierdzenie Fraenkela, układy pokrywające. To dostarcza fundamentu formalnego.
2. **Szeregowanie zadań przez sekwencje Beatty'ego** – ta sama matematyka, inne zastosowanie. Najbliższy sąsiad aplikacyjny.
3. **Cyfrowe przetwarzanie sygnałów (DSP)** – próbkowanie niejednorodne i banki filtrów o wymiernych współczynnikach. To DSP-owy odpowiednik operacji przeplotu.
4. **Strumieniowe systemy zarządzania danymi (DSMS)** – algebry strumieni i semantyka zapytań ciągłych. To bazodanowy punkt odniesienia.
5. **Systemy szeregów czasowych (TSMS) i DSP wewnątrz bazy** – najwęższa, najsłabiej zaludniona nisza, najbliższa właściwemu celowi systemu.

Omawiam je kolejno, od fundamentu ku zastosowaniu.

## Teoria liczb: sekwencje Beatty'ego i układy pokrywające (1)

Cała algebra RetractorDB stoi na sekwencji Beatty'ego i jej uogólnieniu przez Fraenkela na liczby wymierne. Te wyniki przytaczam w [Formalnych podstawach i dowodach](podstawy-matematyczne/formalne-podstawy-i-dowody.md). Tutaj interesuje mnie szersze tło: jak ta matematyka funkcjonuje we współczesnej literaturze i czy ktoś zastosował ją już tam, gdzie ja.

Sekwencje Beatty'ego mają bogatą literaturę kombinatoryczną oraz udokumentowane zastosowania w nieperiodycznych parkietażach (kwazikryształy), szeregowaniu okresowym, widzeniu komputerowym (linie cyfrowe) i teorii języków formalnych [\[11\]](literatura.md#11). Nurt jest żywy: Schaeffer, Shallit i Zorcic (2024) wykazali, że niejednorodna sekwencja Beatty'ego jest synchronizowalna automatem skończonym, co prowadzi do rozstrzygalności teorii pierwszego rzędu tych sekwencji [\[12\]](literatura.md#12). Dla mnie najistotniejsza jest jednak praca Bergera, Felzenbauma i Fraenkela (1986) o rozłącznych układach pokrywających opartych na **wymiernych** sekwencjach Beatty'ego [\[13\]](literatura.md#13) – to dokładnie ten wariant, na którym opieram rozplątanie, a którego w pierwotnej pracy nie przywołałem.

**Czego ten nurt nie dotyka:** teoria liczb bada te sekwencje jako obiekty matematyczne. Nie łączy ich z bazą danych, z modelem przetwarzania strumieni ani z przetwarzaniem sygnałów. Dostarcza cegieł, nie budowli.

## Szeregowanie zadań przez sekwencje Beatty'ego (2)

To jest nurt, który muszę omówić najuczciwiej, bo używa **tej samej maszynerii dowodowej** co moje twierdzenia – tyle że w innym celu. W problemie szeregowania okresowego (ang. _pinwheel scheduling_) zadania o różnych okresach powtarzania rozdziela się tak, że zadania o jednym czasie powtórzeń trafiają w sloty czasowe należące do pierwszej komplementarnej sekwencji Beatty'ego, a o drugim – do drugiej [\[14\]](literatura.md#14). Świeże prace (2025) prowadzą dowody na podziale Rayleigha/Beatty'ego z tożsamościami na funkcjach podłogi i sufitu typu ⌈(m+l)a⌉ − ⌈ma⌉ [\[15\]](literatura.md#15) – niemal kropka w kropkę aparat z mojego dowodu, że [rozplątanie spełnia postulaty Fraenkela](podstawy-matematyczne/formalne-podstawy-i-dowody.md).

Wniosek jest dla mnie podwójny. Z jednej strony – to niezależne potwierdzenie, że podejście jest poprawne i naturalne; skoro ktoś dochodzi tą samą drogą do działającego szeregowania, fundament jest solidny. Z drugiej – to zawęża to, co mogę nazwać nowością. „Sekwencje Beatty'ego do szeregowania" już istnieją i są aktywnie publikowane. Co ciekawe, mój system używa tej matematyki **wewnętrznie** właśnie do szeregowania zadań (patrz [Realizacja zapytań](realizacja-zapytan/)) – ale to nie tu leży wkład oryginalny.

**Czego ten nurt nie dotyka:** szeregowanie traktuje sekwencje jako narzędzie przydziału slotów czasowych procesorom. Nie buduje na nich algebry danych, nie wyraża nimi operacji na sygnałach, nie tworzy języka zapytań.

## Cyfrowe przetwarzanie sygnałów: próbkowanie niejednorodne i banki filtrów (3)

Operacja przeplotu i rozplątania to – w języku DSP – konwersja częstotliwości próbkowania między strumieniami o różnych Δ. Tu istnieje rozległa, dojrzała literatura. Najbliższym pomostem jest praca Samadiego, Ahmada i Swamy'ego (2004), która formułuje warunek perfekcyjnej rekonstrukcji niejednorodnych banków filtrów na podstawie odpowiedzi układu na opóźnione sygnały skoku jednostkowego [\[16\]](literatura.md#16) – wprowadza więc maszynerię funkcji skoku (a pośrednio podłogi) do dziedziny wielotempowego DSP. Szerszy nurt to próbkowanie okresowo-niejednorodne sygnałów pasmowo ograniczonych [\[17\]](literatura.md#17) oraz – bezpośrednio adekwatne – banki filtrów o **wymiernych** współczynnikach decymacji (Kovačević i Vetterli) [\[18\]](literatura.md#18).

Pojawiają się tam nawet konstrukcje teorioliczbowe: banki filtrów Ramanujana wydobywają składowe okresowe sygnału [\[19\]](literatura.md#19). Ale akurat sekwencji Beatty'ego ani twierdzenia Fraenkela w tej literaturze nie znalazłem – i to jest część luki.

**Czego ten nurt nie dotyka:** DSP operuje w dziedzinie z, dziedzinie częstotliwości, na ramkach i bazach. Nie ujmuje resamplingu jako deklaratywnego operatora algebraicznego ani nie osadza go w systemie bazodanowym. Współczynniki bywają wymierne, ale aparatem jest analiza, nie teoria liczb podziału zbioru.

## Strumieniowe systemy zarządzania danymi (DSMS) (4)

Po stronie bazodanowej kanonem jest CQL ze stanfordzkiego projektu STREAM (Arasu, Babu, Widom). W tym modelu strumień to potencjalnie nieskończony wielozbiór elementów ⟨s, τ⟩, gdzie s jest krotką, a τ stemplem czasowym [\[20\]](literatura.md#20); semantykę zapytań buduje się na oknach i odwzorowaniach strumień↔relacja. Drugim bliskim sąsiadem jest temporalna algebra Krämera i Seegera (system PIPES), zapewniająca deterministyczne wyniki zapytań ciągłych oraz bogaty zbiór reguł transformacji stanowiących podstawę optymalizacji [\[21\]](literatura.md#21).

To jest właściwy punkt odniesienia dla mojej algebry i moich [reguł przepisywania wyrażeń](podstawy-matematyczne/formalne-podstawy-i-dowody.md). Różnica jest jednak fundamentalna i dotyczy samego modelu danych. CQL i PIPES budują semantykę na modelu (s, τ) – każda krotka nosi własny stempel czasowy, a operatory działają przez okna. Ja przyjmuję model różnicowy (sₙ, Δ) z wymierną, stałą wartością Δ na strumień, a operatory wyrównujące strumienie o różnych Δ wyprowadzam z teorii liczb. To nie jest kosmetyczna różnica w składni – to inny model danych, prowadzący do innej klasy operatorów (przeplot, rozplątanie) i innej metody optymalizacji.

W kategoriach wdrożeniowych relacja jest przy tym komplementarna, nie konkurencyjna: RetractorDB działa jako brzegowy stopień wstępnego przetwarzania i buforowania, którego dokładne, deterministyczne wyniki mogą zasilać okienkowy DSMS.

**Czego ten nurt nie dotyka:** DSMS obejmują zarówno semantyki deterministyczne, jak i mechanizmy skalowania, okien, tolerancji na nieuporządkowanie oraz obsługi stanu. Przywołane systemy nie definiują jednak konkretnego, bezstratnego podziału pozycji regularnych próbek opartego na sekwencjach Beatty'ego ani nie używają teorii liczb jako semantyki resamplingu.

## Systemy szeregów czasowych (TSMS) i DSP wewnątrz bazy (5)

To najwęższa nisza – i najbliższa właściwemu celowi RetractorDB. Kanoniczny przegląd to praca Jensena, Pedersena i Thomsena „Time Series Management Systems: A Survey" (IEEE TKDE, 2017) [\[22\]](literatura.md#22). Opisany tam system Plato jest najbliższym prawdziwym „DSP wewnątrz bazy": łączy RDBMS z metodami przetwarzania sygnałów, eliminując potrzebę eksportu danych do narzędzi zewnętrznych typu R czy SPSS [\[22\]](literatura.md#22). Pozostałe podejścia do „sygnałów w bazie" sprowadzają się do aproksymacji i kompresji – reprezentacje falkowe, słownikowe, kształtowe.

Wszystkie one traktują jednak DSP jako aproksymację albo analitykę po fakcie. Żaden nie czyni z operacji przetwarzania sygnałów **dokładnych, deterministycznych operatorów pierwszej klasy** wewnątrz algebry zapytań. To potwierdza, że nisza jest cienka, a mój kąt natarcia – dokładność na liczbach wymiernych – jest odrębny.

**Czego ten nurt nie dotyka:** TSMS optymalizują skalę ingestii, kompresję i retencję. DSP jest w nich obywatelem drugiej kategorii – dodatkiem analitycznym, nie rdzeniem semantyki.

## Biała plama: gdzie leży wkład

Poniższa tabela jest jakościową mapą możliwości, a nie dowodem pierwszeństwa ani kompletności przeglądu. W ramach szerszego nurtu systemów strumieniowych wyodrębnia SDF/CSDF oraz języki synchroniczne, ponieważ są najbliższymi modelami systemowymi. „Częściowo” oznacza zdolność pokrewną, nie równoważność semantyczną.

| Dziedzina | Beatty/Fraenkel | Bezstratny podział próbek | Deklaratywny przepływ danych | Artefakty / odtwarzanie |
| --- | :---: | :---: | :---: | :---: |
| Teoria liczb | ✔ | – | – | – |
| Szeregowanie (pinwheel) | ✔ | – | – | częściowo |
| SDF / CSDF | – | częściowo | ✔ | – |
| Języki synchroniczne / rachunki zegarów | – | – | ✔ | – |
| DSP wielotempowy | – | częściowo | częściowo | – |
| DSMS (CQL, PIPES) | – | – | ✔ | częściowo |
| TSMS / DSP-w-bazie | – | częściowo | częściowo | częściowo |
| **RetractorDB** | **✔** | **✔** | **✔** | **✔** |

Najsilniejszymi sąsiadami są SDF/CSDF oraz języki synchroniczne i rachunki zegarów: zapewniają już wielotempowy deklaratywny przepływ danych, deterministyczną semantykę, statyczne harmonogramy albo wyznaczanie buforów. Zakres integracji RetractorDB jest węższy: system łączy zdefiniowany przez sekwencje Beatty'ego, dokładnie odwracalny podział pozycji próbek z kompilatorem zapytań, sekwencyjnym środowiskiem slotowym oraz trwałymi artefaktami dostępnymi do inspekcji i odtwarzania. Jest to opis architektury i semantyki systemu, nie twierdzenie, że poszczególne składniki są nowe. RetractorDB nie deklaruje gwarancji twardego czasu rzeczywistego.

> **⚠️ Ostrzeżenie**
>
> Stąd realne ryzyko, które wprost wskazuję: społeczność szeregowania publikuje tę samą maszynerię Beatty'ego/Fraenkela w latach 2023–2025. Sam problem – wraz z potrzebą deklaratywnej algebry strumieni i ciągłego języka zapytań – został sformułowany już w latach 2003–2005 w kontekście komputerowo wspomaganego monitorowania płodu [\[25\]](literatura.md#25); pomost „układy pokrywające ↔ wyrównanie strumieni i DSP" postawiłem publikacją w 2006 roku [\[3\]](literatura.md#3), lecz w miejscu o niskiej odnajdywalności. Jeśli ten wynik nie trafi do dobrze cytowanego obiegu, ten sam pomost może zostać niezależnie postawiony i przypisany komu innemu.


## Zastrzeżenie metodologiczne

To przegląd ukierunkowany, nie systematyczny – oparty na wyszukiwaniu w pięciu nurtach, nie na pełnej analizie cytowań. Przegląd cytowań „w przód" pracy Samadiego [\[16\]](literatura.md#16) potwierdza tezę: według Semantic Scholar (stan na lipiec 2026) jej jedyne odnotowane cytowania to praca o projektowaniu okien Gabora, dwie prace systemowo-teoretyczne o układach wielotempowych oraz sam pomost z 2006 roku [\[3\]](literatura.md#3) – żadna z nich nie używa sekwencji Beatty'ego ani twierdzenia Fraenkela. Najbliższym znanym mi użyciem tej maszynerii poza teorią liczb jest konstrukcja wykładniczych baz Riesza z sekwencji Beatty'ego–Fraenkela (Pfander, Revay i Walnut) [\[24\]](literatura.md#24) – należy ona jednak do czystej analizy harmonicznej i nie dotyka banków filtrów ani konwersji częstotliwości próbkowania. Do pełnego domknięcia pozostaje systematyczny przegląd nurtu szeregowania [\[14\]](literatura.md#14) oraz literatury banków filtrów w całości; jeśli istnieje użycie twierdzenia Fraenkela w wielotempowym DSP, zawęża to zakres roszczenia o nowość i należy je tu uwzględnić.
