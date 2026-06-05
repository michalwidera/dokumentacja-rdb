# Załączniki

W obszarze załączników znalazły się dokumenty, które nie są związane bezpośrednio z konstrukcją systemu, ale stanowią opis motywacji decyzji projektowych, dokumentację narzędzi oraz materiał pomocniczy dla osób wdrażających lub rozwijających system.

## Geneza systemu

Opis historycznych okoliczności, które doprowadziły do powstania RetractorDB. Punkt wyjścia stanowi doświadczenie autora przy budowie systemu nadzoru neonatologicznego na początku XXI wieku — zderzenie z ograniczeniami relacyjnych baz danych przy rejestracji sygnałów o wysokiej granulacji, próby oparte na ówczesnych systemach strumieniowych oraz ewolucja ku dedykowanemu silnikowi przetwarzania serii czasowych. Rozdział wyjaśnia również, skąd pochodzi nazwa „Retractor" — nawiązanie do grupy narzędzi chirurgicznych rozdzielających i łączących struktury tkankowe, traktowane tu jako analogia do operacji na strumieniach danych.

Pełny opis: [Geneza systemu](geneza-systemu/README.md)

## Dalsze kierunki rozwoju

Wskazanie potencjalnych rozszerzeń algebry leżącej u podstaw RQL. Głównym wątkiem jest poszukiwanie uogólnienia na liczby zespolone — próba bezpośredniego zastosowania gaussowskich liczb całkowitych okazała się nieskuteczna z powodu natury modułu (moduł liczby zesponoej o wymiernych składowych jest rzeczywisty, nie wymierny). Alternatywą są **liczby całkowite Eisensteina** — trójsymetryczny odpowiednik liczb gaussowskich, których moduł zachowuje własności wymierne. Rozdział zawiera wyprowadzenie ich definicji i wstępną analizę możliwości zastosowania w algebrze serii czasowych.

Pełny opis: [Dalsze kierunki rozwoju](dalsze-kierunki-rozwoju/README.md)

## Kolorowanie składni RQL

Pliki zapytań RetractorDB (rozszerzenie `.rql`) mają dedykowane definicje kolorowania składni dla trzech środowisk:

- **Visual Studio Code** — rozszerzenie `rql-vscode` instalowane z repozytorium GitHub,
- **Vim** — pliki `syntax/rql.vim` i `ftdetect/rql.vim`, instalowane przez `scripts/buildrdb.sh vimsyntax` lub ręcznie do `~/.vim/`,
- **bat / batcat** — definicja w formacie Sublime Text 3, instalowana przez `scripts/buildrdb.sh batsyntax`.

Każde ze środowisk rozpoznaje słowa kluczowe RQL (`SELECT`, `DECLARE`, `RULE`, `STREAM`, …), typy danych, komentarze, literały łańcuchowe i wartości liczbowe.

Pełny opis: [Kolorowanie składni](kolorowanie-skladni/README.md)

## Opcje wywołania

Kompletna dokumentacja flag wiersza poleceń dla wszystkich trzech narzędzi systemu:

| Narzędzie    | Rola                                                                  |
| ------------ | --------------------------------------------------------------------- |
| `xretractor` | Główny proces przetwarzania: kompiluje zapytania RQL i realizuje plan |
| `xqry`       | Klient: odpytuje działający `xretractor` przez wspólną pamięć         |
| `xtrdb`      | Narzędzie inspekcji: analizuje artefakty binarne i metadane           |

Każde narzędzie opisano w osobnym podrozdziale wraz z przykładami wywołań i objaśnieniem znaczenia poszczególnych przełączników.

Pełny opis: [Opcje wywołania](opcje-wywolania/README.md)

## Testy integracyjne

Katalog wszystkich testów integracyjnych systemu z opisem weryfikowanej funkcjonalności. Testy integracyjne uruchamiają rzeczywiste binaria (`xretractor`, `xqry`, `xtrdb`) i porównują wyniki z wzorcami — w odróżnieniu od testów jednostkowych GTest, które testują izolowane klasy bibliotek.

Testy dzielą się na dwa zestawy:

- **`IntegrationTest_serial`** — wymagają działającego serwera IPC; uruchamiane sekwencyjnie (jeden po drugim) z powodu współdzielonego pliku blokady i segmentów pamięci Boost,
- **`IntegrationTest_parallel`** — kompilacja zapytań i inspekcja plików bez serwera IPC; mogą działać równolegle.

Uruchomienie: `ninja test` lub `ctest -R <nazwa> -V` w katalogu `build/Debug/`.

Pełny opis: [Testy integracyjne](testy-integracyjne.md)
