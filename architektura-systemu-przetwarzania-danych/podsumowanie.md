---
icon: sigma
---

# Podsumowanie

W podsumowaniu należy wskazać na przekazy w rozdziale zakres wiedzy. Tutaj chciałem przedstawić jak poszczególne elementy systemu możemy uruchamiać, jak wyglądają ciągi poleceń w oparciu o które budujemy dalsze funkcjonalności z wykorzystaniem systemu RetractorDB.

Starałem się zredukować ilość potencjalnych poleceń do minimum. Na chwile obecną efektywnie zredukowałem zbiór do 3 poleceń. Wydaje mi się tak zaprojektowany system będzie maksymalnie użyteczny i w miarę efektywny. Osobną kwestią jest komplikacja. Samo tłumaczenie procesu przetwarzania, nowej algebry i dlaczego znak plus nie oznacza plus – jest problematyczne. Mam jednak nadzieję że po przeskoczeniu pewnej bariery poznania – reszta będzie oczywista. Podjęte decyzje były efektem przemyśleń, prób i błędów. Chcę podkreślić że zwyczajnie po ludzku nie znalazłem lepszej metody.

## Przegląd poruszonych tematów

Rozdział zbudowany jest warstwowo — od widoku ogólnego do szczegółów implementacyjnych.

**Perspektywa ogólna** przedstawia system jako trójkę współpracujących programów: `xretractor` jako singleton realizujący plan zapytań, `xqry` jako wieloinstancyjny klient danych bieżących, oraz `xtrdb` jako narzędzie inspekcji plików binarnych. Komunikacja między procesami odbywa się przez pamięć współdzieloną (Boost IPC). Na schemacie Rys. 8 widać granicę odpowiedzialności każdego z komponentów.

**Przepływ danych i sterowania** pokazuje, które ścieżki danych są zawsze aktywne (napływ danych → xretractor → artefakty), a które są opcjonalne lub diagnostyczne. Opisano też mechanizm graceful shutdown — xretractor reaguje na sygnały `SIGINT`, `SIGTERM` i `SIGHUP` kończąc bieżący cykl bez ryzyka uszkodzenia plików.

**Artefakty, substraty i efemerydy** to kluczowy podział taksonomiczny systemu. Każdy typ strumienia ma inne przeznaczenie i inną strategię składowania: artefakty są materializowane na dysku jako trwały wynik przetwarzania, substraty to strumienie pośrednie niezbędne podczas obliczeń, a efemerydy — ulotne źródła danych, których nie można ani nie warto przechowywać.

**Format zapisu danych** opisuje czteroplikową strukturę artefaktu: plik binarny z danymi (stałej długości rekordy, brak nagłówka), deskryptor `.desc` opisujący schemat rekordu w gramatyce ANTLR4, plik metadanych `.meta` przechowujący indeks wartości null i przerw w transmisji (kodowanie RLE), oraz opcjonalny plik cienia `.shadow` umożliwiający niedestruktywną modyfikację historycznych rekordów. Deskryptor określa też strategię składowania poprzez pole `TYPE` — ta sama logika zapytań obsługuje artefakty, efemerydy i zewnętrzne źródła danych bez rozgałęzień w kodzie.

**Kompilacja i budowa planu** demonstruje proces przekształcania pliku `.rql` w gotowy plan realizacji zapytania. Flaga `-c` uruchamia tryb kompilacji bez wykonania; połączona z `-d -f -s` generuje wyjście w formacie DOT, które `graphviz` zamienia w graf przepływu danych. Graf pokazuje dwie domeny: stos wyrażeń arytmetycznych (PUSH, ADD, itp.) i algebrę strumieniową (przesunięcia czasowe, operatory na strumieniach). Opisano też pełny zestaw flag trybu kompilacji i trybu wykonania.

**Przetwarzanie i dystrybucja danych** to kompletny walkthrough: od przygotowania pliku danych przez uruchomienie `xretractor`, przez podgląd statystyk strumieniowania (`xqry -d`), po wizualizację na żywo w gnuplot (`xqry -s str1 -p 50,50 | gnuplot`) i transmisję danych przez sieć za pomocą `nc`. Przykład łączy dwa źródła — plik tekstowy i `/dev/urandom` — ilustrując jak operator `+` w klauzuli FROM realizuje algebraiczne łączenie strumieni, a nie zwykłe dodawanie.

**Analiza artefaktów** opisuje narzędzie `xtrdb` — interaktywny inspektor plików binarnych wzorowany na stylu dbase. Polecenia `.open`, `.desc`, `.list`, `.rlist` i `.meta` pozwalają przeglądać zawartość artefaktów bez znajomości formatu binarnego. Narzędzie służy też do weryfikacji deterministyczności systemu: te same dane wejściowe powinny zawsze dawać identyczne wyniki.

---

Trzy polecenia wystarczające do uruchomienia kompletnego przepływu:

```bash
xretractor -c query.rql          # weryfikacja poprawności pliku zapytań
xretractor query.rql             # uruchomienie przetwarzania
xqry -s <strumień>               # odczyt danych bieżących
```

Czwarty element — `xtrdb` — pojawia się przy diagnostyce i testowaniu, nie w typowym przepływie produkcyjnym.
