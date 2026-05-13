---
description: Opis powiązań i elementów z których zbudowany jest cały system.
icon: '3'
---

# Architektura systemu

Konstrukcja systemu przetwarzania danych to rozdział stricte techniczny. Przedstawię tutaj jak system został zaprojektowany, zbudowany gdzie i jak obecnie rozmieszczone są jego funkcjonalności.

System RetractorDB został zaimplementowany w języku C++ pod kontrolą systemu Linux. Kod źródłowy podlega procesowi ciągłej integracji i testowania na platformie GitHub wspieranej przez CircleCI. Kod uruchamiany i rozwijany jest lokalnie na platformie Linux WSL2. Porzuciłem rozwój i implementację systemu pod kontrolą systemu Windows. W początkowej fazie utrzymywałem taką opcję i być może w przyszłości do niej powrócę. Jednak utrzymanie zbyt wielu platform rozwojowych znacząco opóźnia proces szybkiego prototypowania i rozwoju systemu. Nadal zachowuję i utrzymuję funkcjonalność systemu na platformie Linux ARM. Kod kompiluję i testuje się pod kontrolą maszyn opartych na architekturze ARM i x86-64 pracujących w zasobach CircleCI. Raspberry PI to jedna z docelowych platform produkcyjnych systemu RetractorDB przewidziana dla potrzeb Edge IoT.

Kompilacja kodu systemu odbywa się ze wsparciem managera pakietów Conan \[[8](../literatura.md)]. Jeśli chcemy poznać jak zbudowany jest toolchain budujący kod systemu możemy zajrzeć do pliku /.circleci/config.yml zawierający procedurę budowy i uruchamiania systemu w środowisku kontenerów lub maszyn firmy CircleCI. W plikach `/docker/ci/Dockerfile` oraz `/docker/ci/DockerConan.txt` znajdują się instrukcje w jaki sposób obraz kontenera budującego system z prekonfigurowanymi dependencjami. Analiza tych plików wskaże co jest potrzebne i jak należy zainstalować w swoim systemie aby źródła systemu skompilować lokalnie u siebie.

### Przegląd poruszonych w rozdziale tematów

Rozdział zbudowany jest warstwowo — od widoku ogólnego do szczegółów implementacyjnych.

**Perspektywa ogólna** przedstawia system jako trójkę współpracujących programów: `xretractor` jako singleton realizujący plan zapytań, `xqry` jako wieloinstancyjny klient danych bieżących, oraz `xtrdb` jako narzędzie inspekcji plików binarnych. Komunikacja między procesami odbywa się przez pamięć współdzieloną (Boost IPC). Na schemacie Rys. 8 widać granicę odpowiedzialności każdego z komponentów.

**Przepływ danych i sterowania** pokazuje, które ścieżki danych są zawsze aktywne (napływ danych → xretractor → artefakty), a które są opcjonalne lub diagnostyczne. Opisano też mechanizm graceful shutdown — xretractor reaguje na sygnały `SIGINT`, `SIGTERM` i `SIGHUP` kończąc bieżący cykl bez ryzyka uszkodzenia plików.

**Artefakty, substraty i efemerydy** to kluczowy podział taksonomiczny systemu. Każdy typ strumienia ma inne przeznaczenie i inną strategię składowania: artefakty są materializowane na dysku jako trwały wynik przetwarzania, substraty to strumienie pośrednie niezbędne podczas obliczeń, a efemerydy — ulotne źródła danych, których nie można ani nie warto przechowywać.

**Format zapisu danych** opisuje czteroplikową strukturę artefaktu: plik binarny z danymi (stałej długości rekordy, brak nagłówka), deskryptor `.desc` opisujący schemat rekordu w gramatyce ANTLR4, plik metadanych `.meta` przechowujący indeks wartości null i przerw w transmisji (kodowanie RLE), oraz opcjonalny plik cienia `.shadow` umożliwiający niedestruktywną modyfikację historycznych rekordów. Deskryptor określa też strategię składowania poprzez pole `TYPE` — ta sama logika zapytań obsługuje artefakty, efemerydy i zewnętrzne źródła danych bez rozgałęzień w kodzie.

**Kompilacja i budowa planu** demonstruje proces przekształcania pliku `.rql` w gotowy plan realizacji zapytania. Flaga `-c` uruchamia tryb kompilacji bez wykonania; połączona z `-d -f -s` generuje wyjście w formacie DOT, które `graphviz` zamienia w graf przepływu danych. Graf pokazuje dwie domeny: stos wyrażeń arytmetycznych (PUSH, ADD, itp.) i algebrę strumieniową (przesunięcia czasowe, operatory na strumieniach). Opisano też pełny zestaw flag trybu kompilacji i trybu wykonania.

**Przetwarzanie i dystrybucja danych** to kompletny walkthrough: od przygotowania pliku danych przez uruchomienie `xretractor`, przez podgląd statystyk strumieniowania (`xqry -d`), po wizualizację na żywo w gnuplot (`xqry -s str1 -p 50,50 | gnuplot`) i transmisję danych przez sieć za pomocą `nc`. Przykład łączy dwa źródła — plik tekstowy i `/dev/urandom` — ilustrując jak operator `+` w klauzuli FROM realizuje algebraiczne łączenie strumieni, a nie zwykłe dodawanie.

**Analiza artefaktów** opisuje narzędzie `xtrdb` — interaktywny inspektor plików binarnych wzorowany na stylu dbase. Polecenia `.open`, `.desc`, `.list`, `.rlist` i `.meta` pozwalają przeglądać zawartość artefaktów bez znajomości formatu binarnego. Narzędzie służy też do weryfikacji deterministyczności systemu: te same dane wejściowe powinny zawsze dawać identyczne wyniki.

***

Trzy polecenia wystarczające do uruchomienia kompletnego przepływu:

```bash
xretractor -c query.rql          # weryfikacja poprawności pliku zapytań
xretractor query.rql             # uruchomienie przetwarzania
xqry -s <strumień>               # odczyt danych bieżących
```

Czwarty element — `xtrdb` — pojawia się przy diagnostyce i testowaniu, nie w typowym przepływie produkcyjnym.
