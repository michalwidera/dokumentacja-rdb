# Załączniki

W obszarze załączników znalazły się dokumenty, które nie są związane bezpośrednio z konstrukcją systemu, ale stanowią opis motywacji decyzji projektowych, dokumentację narzędzi oraz materiał pomocniczy dla osób wdrażających lub rozwijających system.

<div class="timeline">

- **[Budowanie produkcyjne i warianty diagnostyczne](budowanie-produkcyjne-i-warianty-badawcze.md)**

  Opis kontraktu bezpieczeństwa produkcyjnego `release` oraz izolowanych trybów
  `release-ablation` i `probe`. Rozdział przedstawia kontrolę czystości źródeł,
  jawne wartości przełączników optymalizatora, rozdzielenie katalogów CMake i
  Conan, weryfikację konfiguracji gotowej binarki oraz niezmiennik zgodności
  wyniku między wariantami.

- **[API monitorowania strumieni](api-monitorowania-strumieni.md)**

  Wersjonowany kontrakt JSON Lines oraz opcjonalne biblioteki Python i C++ do
  obserwacji strumieni jawnie nazwanej instancji. Rozdział opisuje mapowanie typów,
  cykl życia subskrypcji, timeouty, ograniczone bufory, obsługę błędów oraz osobne
  cele budowania, instalowania i testowania API.

- **[Geneza systemu](geneza-systemu/README.md)**

  Opis historycznych okoliczności, które doprowadziły do powstania RetractorDB. Punkt wyjścia stanowi doświadczenie autora przy budowie systemu nadzoru neonatologicznego na początku XXI wieku — zderzenie z ograniczeniami relacyjnych baz danych przy rejestracji sygnałów o wysokiej granulacji, próby oparte na ówczesnych systemach strumieniowych oraz ewolucja ku dedykowanemu silnikowi przetwarzania serii czasowych. Rozdział wyjaśnia również, skąd pochodzi nazwa „Retractor" — nawiązanie do grupy narzędzi chirurgicznych rozdzielających i łączących struktury tkankowe, traktowane tu jako analogia do operacji na strumieniach danych.

- **[Kolorowanie składni RQL](kolorowanie-skladni/README.md)**

  Pliki zapytań RetractorDB (rozszerzenie `.rql`) mają dedykowane definicje kolorowania składni dla trzech środowisk:

  - **Visual Studio Code** — rozszerzenie `rql-vscode` instalowane z repozytorium GitHub,
  - **Vim** — pliki `syntax/rql.vim` i `ftdetect/rql.vim`, instalowane przez `scripts/buildrdb.sh vimsyntax` lub ręcznie do `~/.vim/`,
  - **bat / batcat** — definicja w formacie Sublime Text 3, instalowana przez `scripts/buildrdb.sh batsyntax`.

  Każde ze środowisk rozpoznaje słowa kluczowe RQL (`SELECT`, `DECLARE`, `RULE`, `STREAM`, …), typy danych, komentarze, literały łańcuchowe i wartości liczbowe.

- **[Opcje wywołania](opcje-wywolania/README.md)**

  Kompletna dokumentacja flag wiersza poleceń dla wszystkich trzech narzędzi systemu:

  | Narzędzie    | Rola                                                                  |
  | ------------ | --------------------------------------------------------------------- |
  | `xretractor` | Główny proces przetwarzania: kompiluje zapytania RQL i realizuje plan |
  | `xqry`       | Klient: odpytuje działający `xretractor` przez wspólną pamięć         |
  | `xtrdb`      | Narzędzie inspekcji: analizuje artefakty binarne i metadane           |

  Każde narzędzie opisano w osobnym podrozdziale wraz z przykładami wywołań i objaśnieniem znaczenia poszczególnych przełączników.

- **[Testy integracyjne](testy-integracyjne.md)**

  Katalog wszystkich testów integracyjnych systemu z opisem weryfikowanej funkcjonalności. Testy integracyjne uruchamiają rzeczywiste binaria (`xretractor`, `xqry`, `xtrdb`) i porównują wyniki z wzorcami — w odróżnieniu od testów jednostkowych GTest, które testują izolowane klasy bibliotek.

  Scenariusze znajdują się we wspólnym drzewie **`test/IntegrationTest`**. Testy
  uruchamiające serwer otrzymują jedną z szesnastu przestrzeni `RDB_NAMESPACE`
  i blokadę zasobu CTest dla swojego katalogu, dzięki czemu większość z nich może
  działać równolegle bez kolizji nazw strumieni, IPC ani plików roboczych. Tylko
  scenariusze badające produkcyjną, globalną tożsamość pozostają `RUN_SERIAL`.

  Uruchomienie: `ninja test` lub `ctest -R <nazwa> -V` w katalogu `build/Debug/`.

</div>
