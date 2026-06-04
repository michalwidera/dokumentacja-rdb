# RetractorDB

Ten rozdział jest mapą, nie katalogiem. Zamiast wyliczać wszystko, co kiedykolwiek napisano o strumieniach i sygnałach, pokazuję pięć nurtów recenzowanej literatury, na styku których leży RetractorDB, i dla każdego z nich odpowiadam na trzy pytania: co ten nurt już rozwiązał, w czym RetractorDB się od niego różni i czego ten nurt **nie** dotyka. Dopiero nałożenie tych pięciu warstw na siebie pokazuje lukę, którą ten projekt wypełnia.

> **📥 Pobierz dokumentację jako PDF**
>
> [retractordb.pdf](retractordb.pdf) — generowany automatycznie przy każdym `git push`.

> **✅ Uwaga**
>
> Ten system to: Edge Signal Processing Engine (Brzegowy System Przetwarzania Sygnałów)


> **ℹ️ Info**
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

## 1. Teoria liczb: sekwencje Beatty'ego i układy pokrywające

Cała algebra RetractorDB stoi na sekwencji Beatty'ego i jej uogólnieniu przez Fraenkela na liczby wymierne. Te wyniki przytaczam w [Formalnych podstawach i dowodach](podstawy-matematyczne/formalne-podstawy-i-dowody.md). Tutaj interesuje mnie szersze tło: jak ta matematyka funkcjonuje we współczesnej literaturze i czy ktoś zastosował ją już tam, gdzie ja.

Sekwencje Beatty'ego mają bogatą literaturę kombinatoryczną oraz udokumentowane zastosowania w nieperiodycznych parkietażach (kwazikryształy), szeregowaniu okresowym, widzeniu komputerowym (linie cyfrowe) i teorii języków formalnych [\[11\]](literatura.md#11). Nurt jest żywy: Schaeffer, Shallit i Zorcic (2024) wykazali, że niejednorodna sekwencja Beatty'ego jest synchronizowalna automatem skończonym, co prowadzi do rozstrzygalności teorii pierwszego rzędu tych sekwencji [\[12\]](literatura.md#12). Dla mnie najistotniejsza jest jednak praca Bergera, Felzenbauma i Fraenkela (1986) o rozłącznych układach pokrywających opartych na **wymiernych** sekwencjach Beatty'ego [\[13\]](literatura.md#13) – to dokładnie ten wariant, na którym opieram rozplątanie, a którego w pierwotnej pracy nie przywołałem.

**Czego ten nurt nie dotyka:** teoria liczb bada te sekwencje jako obiekty matematyczne. Nie łączy ich z bazą danych, z modelem przetwarzania strumieni ani z przetwarzaniem sygnałów. Dostarcza cegieł, nie budowli.

## 2. Szeregowanie zadań przez sekwencje Beatty'ego

To jest nurt, który muszę omówić najuczciwiej, bo używa **tej samej maszynerii dowodowej** co moje twierdzenia – tyle że w innym celu. W problemie szeregowania okresowego (ang. _pinwheel scheduling_) zadania o różnych okresach powtarzania rozdziela się tak, że zadania o jednym czasie powtórzeń trafiają w sloty czasowe należące do pierwszej komplementarnej sekwencji Beatty'ego, a o drugim – do drugiej [\[14\]](literatura.md#14). Świeże prace (2026) prowadzą dowody na podziale Rayleigha/Beatty'ego z tożsamościami na funkcjach podłogi i sufitu typu ⌈(m+l)a⌉ − ⌈ma⌉ [\[15\]](literatura.md#15) – niemal kropka w kropkę aparat z mojego dowodu, że [rozplątanie spełnia postulaty Fraenkela](podstawy-matematyczne/formalne-podstawy-i-dowody.md).

Wniosek jest dla mnie podwójny. Z jednej strony – to niezależne potwierdzenie, że podejście jest poprawne i naturalne; skoro ktoś dochodzi tą samą drogą do działającego szeregowania, fundament jest solidny. Z drugiej – to zawęża to, co mogę nazwać nowością. „Sekwencje Beatty'ego do szeregowania" już istnieją i są aktywnie publikowane. Co ciekawe, mój system używa tej matematyki **wewnętrznie** właśnie do szeregowania zadań (patrz [Realizacja zapytań](realizacja-zapytan/)) – ale to nie tu leży wkład oryginalny.

**Czego ten nurt nie dotyka:** szeregowanie traktuje sekwencje jako narzędzie przydziału slotów czasowych procesorom. Nie buduje na nich algebry danych, nie wyraża nimi operacji na sygnałach, nie tworzy języka zapytań.

## 3. Cyfrowe przetwarzanie sygnałów: próbkowanie niejednorodne i banki filtrów

Operacja przeplotu i rozplątania to – w języku DSP – konwersja częstotliwości próbkowania między strumieniami o różnych Δ. Tu istnieje rozległa, dojrzała literatura. Najbliższym pomostem jest praca Samadiego, Ahmada i Swamy'ego (2004), która formułuje warunek perfekcyjnej rekonstrukcji niejednorodnych banków filtrów na podstawie odpowiedzi układu na opóźnione sygnały skoku jednostkowego [\[16\]](literatura.md#16) – wprowadza więc maszynerię funkcji skoku (a pośrednio podłogi) do dziedziny wielotempowego DSP. Szerszy nurt to próbkowanie okresowo-niejednorodne sygnałów pasmowo ograniczonych [\[17\]](literatura.md#17) oraz – bezpośrednio adekwatne – banki filtrów o **wymiernych** współczynnikach decymacji (Kovačević i Vetterli) [\[18\]](literatura.md#18).

Pojawiają się tam nawet konstrukcje teorioliczbowe: banki filtrów Ramanujana wydobywają składowe okresowe sygnału [\[19\]](literatura.md#19). Ale akurat sekwencji Beatty'ego ani twierdzenia Fraenkela w tej literaturze nie znalazłem – i to jest część luki.

**Czego ten nurt nie dotyka:** DSP operuje w dziedzinie z, dziedzinie częstotliwości, na ramkach i bazach. Nie ujmuje resamplingu jako deklaratywnego operatora algebraicznego ani nie osadza go w systemie bazodanowym. Współczynniki bywają wymierne, ale aparatem jest analiza, nie teoria liczb podziału zbioru.

## 4. Strumieniowe systemy zarządzania danymi (DSMS)

Po stronie bazodanowej kanonem jest CQL ze stanfordzkiego projektu STREAM (Arasu, Babu, Widom). W tym modelu strumień to potencjalnie nieskończony wielozbiór elementów ⟨s, τ⟩, gdzie s jest krotką, a τ stemplem czasowym [\[20\]](literatura.md#20); semantykę zapytań buduje się na oknach i odwzorowaniach strumień↔relacja. Drugim bliskim sąsiadem jest temporalna algebra Krämera i Seegera (system PIPES), zapewniająca deterministyczne wyniki zapytań ciągłych oraz bogaty zbiór reguł transformacji stanowiących podstawę optymalizacji [\[21\]](literatura.md#21).

To jest właściwy punkt odniesienia dla mojej algebry i moich [reguł przepisywania wyrażeń](podstawy-matematyczne/formalne-podstawy-i-dowody.md). Różnica jest jednak fundamentalna i dotyczy samego modelu danych. CQL i PIPES budują semantykę na modelu (s, τ) – każda krotka nosi własny stempel czasowy, a operatory działają przez okna. Ja przyjmuję model różnicowy (sₙ, Δ) z wymierną, stałą wartością Δ na strumień, a operatory wyrównujące strumienie o różnych Δ wyprowadzam z teorii liczb. To nie jest kosmetyczna różnica w składni – to inny model danych, prowadzący do innej klasy operatorów (przeplot, rozplątanie) i innej metody optymalizacji.

**Czego ten nurt nie dotyka:** DSMS celują w przybliżone, skalowalne przetwarzanie nieograniczonych strumieni z tolerancją na nieuporządkowanie czasowe. Nie dążą do dokładnych, deterministycznych operacji DSP w rygorze twardego czasu rzeczywistego i nie sięgają po teorię liczb dla semantyki resamplingu.

## 5. Systemy szeregów czasowych i DSP wewnątrz bazy

To najwęższa nisza – i najbliższa właściwemu celowi RetractorDB. Kanoniczny przegląd to praca Jensena, Pedersena i Thomsena „Time Series Management Systems: A Survey" (IEEE TKDE, 2017) [\[22\]](literatura.md#22). Opisany tam system Plato jest najbliższym prawdziwym „DSP wewnątrz bazy": łączy RDBMS z metodami przetwarzania sygnałów, eliminując potrzebę eksportu danych do narzędzi zewnętrznych typu R czy SPSS [\[22\]](literatura.md#22). Pozostałe podejścia do „sygnałów w bazie" sprowadzają się do aproksymacji i kompresji – reprezentacje falkowe, słownikowe, kształtowe.

Wszystkie one traktują jednak DSP jako aproksymację albo analitykę po fakcie. Żaden nie czyni z operacji przetwarzania sygnałów **dokładnych, deterministycznych operatorów pierwszej klasy** wewnątrz algebry zapytań. To potwierdza, że nisza jest cienka, a mój kąt natarcia – dokładność na liczbach wymiernych – jest odrębny.

**Czego ten nurt nie dotyka:** TSMS optymalizują skalę ingestii, kompresję i retencję. DSP jest w nich obywatelem drugiej kategorii – dodatkiem analitycznym, nie rdzeniem semantyki.

## Biała plama: gdzie leży wkład

Po nałożeniu pięciu warstw obraz staje się czytelny. Każda dziedzina dotyka jednej lub dwóch ścian problemu, ale **żadna nie zajmuje ich przecięcia**:

| Dziedzina               | Beatty/Fraenkel | Dokładny DSP | Algebra strumieni / język zapytań | Twardy czas rzeczywisty |
| ----------------------- | :------------------: | :----------------: | :---------------------: | :------------------: |
| Teoria liczb            |        ✔        |       –      |                 –                 |            –            |
| Szeregowanie (pinwheel) |        ✔        |       –      |                 –                 |        częściowo        |
| DSP wielotempowy        |        –        |       ✔      |                 –                 |            –            |
| DSMS (CQL, PIPES)       |        –        |       –      |                 ✔                 |            –            |
| TSMS / DSP-w-bazie      |        –        |   częściowo  |             częściowo             |            –            |
| **RetractorDB**         |      **✔**      |     **✔**    |               **✔**               |          **✔**          |

Wkład RetractorDB nie leży w żadnym pojedynczym składniku – leży w ich **syntezie**: w użyciu układów pokrywających (wymiernych sekwencji Beatty'ego i twierdzenia Fraenkela) jako semantycznego fundamentu deklaratywnej algebry strumieni, która realizuje dokładne operatory przetwarzania sygnałów wewnątrz systemu bazodanowego, w rygorze twardego czasu rzeczywistego. Teoria liczb ma Beatty'ego i nawet szeregowanie, ale nie łączy ich z bazą ani z DSP. DSP ma multirate i wymierne banki filtrów, ale nie sięga po Fraenkela i nie ujmuje tego jako języka zapytań. DSMS ma algebry strumieni i reguły optymalizacji, ale na modelu okienkowym (s, τ), nie różnicowym (sₙ, Δ). To przecięcie jest puste.

> **⚠️ Ostrzeżenie**
>
> Stąd realne ryzyko, które wprost wskazuję: społeczność szeregowania publikuje tę samą maszynerię Beatty'ego/Fraenkela w latach 2023–2026. Pomost „układy pokrywające ↔ wyrównanie strumieni i DSP" postawiłem publikacją już w 2006 roku [\[3\]](literatura.md#3), lecz w miejscu o niskiej odnajdywalności. Jeśli ten wynik nie trafi do dobrze cytowanego obiegu, ten sam pomost może zostać niezależnie postawiony i przypisany komu innemu.


## Zastrzeżenie metodologiczne

To przegląd ukierunkowany, nie systematyczny – oparty na wyszukiwaniu w pięciu nurtach, nie na pełnej analizie cytowań. Do pełnej, recenzowanej publikacji wymaga domknięcia o przegląd cytowań „w przód" prac Samadiego [\[16\]](literatura.md#16) i nurtu szeregowania [\[14\]](literatura.md#14), a także o weryfikację, czy ktokolwiek użył wprost twierdzenia Fraenkela w kontekście wielotempowego DSP. Z mojego przeszukania – nie znalazłem takiej pracy. Jeśli istnieje, zmienia to zakres roszczenia o nowość i należy ją tu uwzględnić.
