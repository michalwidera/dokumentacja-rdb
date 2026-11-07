# Architektura systemu

Ten rozdział opisuje komponenty RetractorDB, ich odpowiedzialności oraz przepływ danych i sterowania. Prowadzi od współpracy programów `xretractor`, `xqry` i `xtrdb` do formatu artefaktów i realizacji planu zapytań.

System jest zaimplementowany w C++. Platformą wdrożeniową jest Linux na x86-64 i ARM64, w tym urządzenia brzegowe takie jak Raspberry Pi. Rozwój i testy obejmują również Linux w WSL2 oraz rozwojowy port macOS. Natywna wersja dla Windows nie jest obecnie utrzymywana. Kod źródłowy jest przechowywany w GitHub, a konfiguracja ciągłej integracji korzysta z CircleCI.

Kompilacja kodu systemu korzysta z Conan 2, CMake i Ninja. Przygotowanie narzędzi, budowanie ze źródeł i instalację gotowych pakietów opisuje [Instalacja systemu](../instalacja-systemu/). Ograniczenia portu Apple opisano w [instrukcji budowania ze źródeł](../instalacja-systemu/source-build.md#środowisko-rozwojowe-apple).

## Przegląd poruszonych w rozdziale tematów

Rozdział zbudowany jest warstwowo - od widoku ogólnego do szczegółów implementacyjnych.

<div class="timeline">

- **[Perspektywa ogólna](schemat-architektury.md)**

  System jako trójka współpracujących programów: `xretractor` jako proces realizujący plan zapytań, `xqry` jako wieloinstancyjny klient danych bieżących, `xtrdb` jako narzędzie inspekcji plików binarnych. Na jednym hoście może działać wiele nazwanych procesów `xretractor`, każdy z własnym obszarem Boost IPC. Na schemacie Rys. 12 widać granicę odpowiedzialności komponentów dla jednej takiej instancji.

- **[Wiele instancji i magistrala](wiele-instancji-i-magistrala.md)**

  Nazwy instancji, rozdzielenie obiektów IPC, rejestr `xrdbbus`, globalna ochrona nazw strumieni i plików magazynu oraz reguły automatycznego kierowania poleceń `xqry`. Rozdział opisuje również stałą tożsamość `service`, wymianę całego planu przez `xqry --reset` i znaczenie trybów pokazywanych przez `xqry --bus`.

- **[Przepływ danych i sterowania](przeplyw-danych-i-sterowania.md)**

  Które ścieżki danych są zawsze aktywne (napływ danych → xretractor → artefakty), a które opcjonalne lub diagnostyczne. Opisano też mechanizm graceful shutdown - xretractor reaguje na sygnały `SIGINT`, `SIGTERM` i `SIGHUP` kończąc bieżący cykl bez ryzyka uszkodzenia plików.

- **[Artefakty, substraty i efemerydy](artefakty-substraty-efemerydy.md)**

  Kluczowy podział taksonomiczny systemu. Każdy typ strumienia ma inne przeznaczenie i inną strategię składowania: artefakty materializowane na dysku jako trwały wynik, substraty to strumienie pośrednie niezbędne podczas obliczeń, efemerydy - ulotne źródła danych, których nie można ani nie warto przechowywać.

- **[Format zapisu danych](format-zapisu-danych/)**

  Czteroplikowa struktura artefaktu: plik binarny z danymi (stałej długości rekordy, brak nagłówka), deskryptor `.desc` opisujący schemat rekordu w gramatyce ANTLR4, plik metadanych `.meta` z indeksem wartości null i przerw w transmisji (kodowanie RLE), opcjonalny plik cienia `.shadow` do niedestruktywnej modyfikacji historycznych rekordów. Deskryptor określa strategię składowania przez pole `TYPE`.

- **[Kompilacja i budowa planu](kompilacja-i-budowa-planu.md)**

  Proces przekształcania pliku `.rql` w gotowy plan realizacji zapytania. Flaga `-c` uruchamia tryb kompilacji bez wykonania; połączona z `-d -f -s` generuje wyjście DOT, które `graphviz` zamienia w graf przepływu danych. Graf pokazuje dwie domeny: stos wyrażeń arytmetycznych (PUSH, ADD, itp.) i algebrę strumieniową. Opisano pełny zestaw flag trybu kompilacji i wykonania.

- **[Przetwarzanie i dystrybucja danych](przetwarzanie-i-dystrybucja-danych.md)**

  Kompletny walkthrough: od przygotowania pliku danych przez uruchomienie `xretractor`, przez podgląd statystyk strumieniowania (`xqry -d`), po wizualizację na żywo w gnuplot (`xqry -s str1 -p 50,50 | gnuplot`) i transmisję przez sieć za pomocą `nc`. Przykład łączy dwa źródła - plik tekstowy i `/dev/urandom` - ilustrując jak operator `+` w klauzuli FROM realizuje algebraiczne łączenie strumieni.

- **[Analiza artefaktów](analiza-artefaktow.md)**

  Narzędzie `xtrdb` - interaktywny inspektor plików binarnych wzorowany na stylu dbase. Polecenia `.open`, `.desc`, `.list`, `.rlist` i `.meta` pozwalają przeglądać zawartość artefaktów bez znajomości formatu binarnego. Narzędzie służy też do weryfikacji deterministyczności: te same dane wejściowe powinny zawsze dawać identyczne wyniki.

</div>

***

Trzy polecenia wystarczające do uruchomienia kompletnego przepływu:

```bash
xretractor -c query.rql          # weryfikacja poprawności pliku zapytań
xretractor query.rql             # uruchomienie przetwarzania
xqry -s <strumień>               # odczyt danych bieżących
```

Czwarty element - `xtrdb` - pojawia się przy diagnostyce i testowaniu, nie w typowym przepływie produkcyjnym.
