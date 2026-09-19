# Proces instalacji

Podstawową platformą wdrożeniową RetractorDB jest Linux na x86-64 i ARM64 (AArch64). Można zainstalować gotowe wydanie albo zbudować programy ze źródeł. Instalator pobierany przez `curl` instaluje gotowe binaria; kompilację wykonuje się osobno. Apple jest środowiskiem rozwojowym, opisanym w [wydzielonej sekcji](#środowisko-rozwojowe-apple).

## Wybór sposobu instalacji

| Sposób | Zastosowanie | Lokalizacja programów |
| --- | --- | --- |
| Instalator `install.sh --user` | Instalacja dla bieżącego użytkownika, bez uprawnień administratora | `~/.local/bin` |
| Instalator `install.sh --system` | Instalacja dla całego systemu, opcjonalnie z usługą systemd | `/usr/local/bin` |
| Pakiet DEB | Debian lub Ubuntu; utrzymanie przez apt | `/usr/bin` |
| Budowanie ze źródeł | Rozwój, testy albo własne wydanie | Domyślnie `~/.local/bin` |

Instalator korzysta z [GitHub Releases](https://github.com/michalwidera/retractordb/releases). Opis szybkiej instalacji znajduje się również na [stronie projektu](https://retractordb.com/pl/install/). Kontrakt produkcyjnego budowania i warianty diagnostyczne opisuje [załącznik o budowaniu](budowanie-produkcyjne-i-warianty-badawcze.md).

## Instalacja gotowego wydania na Linuksie

Instalator wymaga Bash, `curl`, `python3` i `sha256sum`. Rozpoznaje x86-64 i AArch64, wybiera archiwum `retractordb-<wersja>-linux-<architektura>-portable.tar.gz` i sprawdza SHA-256 z pola `digest` zasobu GitHub Releases. Przed instalacją kontroluje zawartość archiwum, architekturę ELF i możliwość uruchomienia wszystkich trzech programów. System z niezgodną wersją `glibc` lub `libstdc++`, dystrybucja oparta na musl albo ARM 32-bit może wymagać osobnego budowania ze źródeł.

Dostępne wydania dla architektury hosta można sprawdzić poleceniem:

```bash
curl -fsSL https://retractordb.com/install.sh | bash -s -- list
```

Domyślnie wybierana jest najnowsza stabilna wersja z odpowiednim archiwum. Wydania oznaczone jako draft lub prerelease są pomijane. Instalacja dla użytkownika:

```bash
curl -fsSL https://retractordb.com/install.sh | bash -s -- install --user
```

Programy `xretractor`, `xqry` i `xtrdb` są dostępne przez dowiązania w `~/.local/bin`. Jeżeli katalogu nie ma w `PATH`, należy go dodać w konfiguracji swojej powłoki. Instalator wypisuje taką wskazówkę, ale sam nie zmienia konfiguracji powłoki.

Można też najpierw pobrać i przeczytać skrypt:

```bash
curl -fsSLO https://retractordb.com/install.sh
less install.sh
bash install.sh install --user
```

## Instalacja systemowa i usługa systemd

Instalacja systemowa wymaga uprawnień roota i używa prefiksu `/usr/local`:

```bash
curl -fsSL https://retractordb.com/install.sh | sudo bash -s -- install --system
```

Na hoście z systemd opcja `--service` dodatkowo instaluje, włącza i uruchamia usługę:

```bash
curl -fsSL https://retractordb.com/install.sh | sudo bash -s -- install --system --service
systemctl status xretractor.service
```

Instalator tworzy konto `retractor` oraz pusty `/etc/retractor/startup.rql`, jeśli jeszcze nie istnieją. Pusty plik uruchamia instancję bezczynną, gotową do przyjęcia planu. Istniejące zapytania pozostają bez zmian. Prefiks usługi musi należeć do roota i nie może być zapisywalny przez innych użytkowników. Samo archiwum portable nie zawiera jednostki systemd; tworzy ją instalator.

Sposoby dostarczania planu działającej usłudze opisano w [opcjach xretractor](opcje-wywolania/xretractor.md#usługa-i-wymiana-planu).

## Aktualizacja, wersje, status i usuwanie

```bash
curl -fsSL https://retractordb.com/install.sh | bash -s -- upgrade --user
curl -fsSL https://retractordb.com/install.sh | bash -s -- status --user
curl -fsSL https://retractordb.com/install.sh | bash -s -- uninstall --user
```

`install` i `upgrade` przyjmują `--version <wersja>` z numerem wydania dostępnym przez `list`. Własny katalog wybiera `--prefix /sciezka/bezwzgledna`; ten sam prefiks trzeba podać przy aktualizacji, sprawdzaniu i usuwaniu. W instalacji systemowej należy używać `--system`, a operacje zmieniające instalację wykonywać jako root.

Instalator zapisuje programy w `<prefix>/lib/retractordb/versions/<wersja>` i utrzymuje plik `installer-state` w `<prefix>/lib/retractordb`. Polecenie `status` pokazuje stan zarządzanej instalacji i dowiązania programów; nie sprawdza gotowości silnika do obsługi zapytań. Do kontaktu z działającą instancją służy np. `xqry --server service --hello`.

Aktualizacja zarządzanej usługi systemd restartuje ją z nowym binarium. `uninstall` usuwa programy i własną jednostkę, zachowując konfigurację, pliki zapytań i konto usługi. Instalator nie przejmuje binariów zainstalowanych inną metodą w tym samym prefiksie; w takim przypadku należy wybrać osobny prefiks albo utrzymać dotychczasową metodę instalacji.

Przed aktualizacją binariów należy zatrzymać działające instancje. Wersje korzystające z różnych układów magistrali mają osobne rejestry i nie zapewniają wspólnej kontroli kolizji nazw strumieni ani plików magazynu. Aktualny układ opisano w rozdziale [Wiele instancji i magistrala](../architektura-systemu-przetwarzania-danych/wiele-instancji-i-magistrala.md).

## Pakiet DEB

Dla Debiana lub Ubuntu można pobrać zgodny z architekturą pakiet DEB z GitHub Releases i zainstalować go przez apt. Poniżej `pakiet.deb` oznacza pobrany plik:

```bash
sudo apt install ./pakiet.deb
```

Pakiet instaluje programy w `/usr/bin`, przygotowuje konfigurację i włącza usługę na następny start systemu. Aby uruchomić ją od razu:

```bash
sudo systemctl start xretractor.service
systemctl status xretractor.service
```

Aktualizację wykonuje się przez `apt install ./<nowy-plik>.deb`, a usunięcie przez `sudo apt remove retractordb`. Instalator portable nie zarządza pakietami Debiana. Nie należy instalować wariantu DEB i wariantu portable z `--service` na jednym hoście: oba używają nazwy `xretractor.service`.

## Budowanie i instalacja ze źródeł

Budowanie na Linuksie korzysta z Conan 2, CMake i Ninja. Wymagany jest kompilator C++23 z `<print>` i `std::println` (GCC 14 lub nowszy). Toolchain projektu wymaga CMake co najmniej 4.4.2. Skrypt `scripts/buildrdb.sh` przygotowuje narzędzia i profil Conan; ścieżka instalowania zależności na Linuksie korzysta z apt.

W katalogu pobranego repozytorium `retractordb`:

```bash
scripts/buildrdb.sh toolchain
scripts/buildrdb.sh conan ninja
scripts/buildrdb.sh bashrc
```

Po dodaniu `~/.local/bin` do `PATH` trzeba odświeżyć powłokę, np. otwierając nowy terminal. Budowanie i instalacja wariantu Debug:

```bash
scripts/buildrdb.sh debug
cmake --install build/Debug
ctest --test-dir build/Debug --output-on-failure
```

Instalacja jest osobnym krokiem po budowaniu i domyślnie nie wymaga sudo. Testy integracyjne korzystają również z zainstalowanych programów, dlatego instalacja poprzedza testy. Opcjonalne biblioteki API mają [osobne cele instalacji i testowania](api-monitorowania-strumieni.md).

Produkcyjne wydanie ze źródeł wymaga czystego drzewa Git:

```bash
scripts/buildrdb.sh release
cmake --install build/Release
ctest --test-dir build/Release --output-on-failure
```

Tryb `release-dirty` służy do diagnostyki lokalnych zmian i nie tworzy wydania produkcyjnego. Szczegóły w [kontrakcie budowania](budowanie-produkcyjne-i-warianty-badawcze.md). Paczki dla odbiorców są przygotowywane osobno; skrypty i kontrole linuxowych wydań opisano w repozytorium kodu w `scripts/release_package/README.md`.

## Weryfikacja instalacji i konfiguracja

```bash
xretractor --build-info
xqry -h
xtrdb -h
```

`--build-info` pokazuje flagi optymalizatora gotowej binarki, bez uruchamiania silnika. Nie zastępuje testu działania własnego planu. Po instalacji warto sprawdzić również `command -v xretractor`, aby upewnić się, że `PATH` wskazuje wybraną instalację.

Instalator portable kopiuje domyślny TOML wyłącznie wtedy, gdy pliku jeszcze nie ma: do `/etc/retractor/retractor.toml` dla instalacji systemowej albo `$XDG_CONFIG_HOME/retractor/retractor.toml` (domyślnie `~/.config/retractor/retractor.toml`) dla użytkownika. W dostarczonym pliku `storage.dir` jest zakomentowane. Przed ustawieniem tej opcji należy utworzyć katalog i nadać prawo zapisu użytkownikowi uruchamiającemu silnik. Pełną kolejność konfiguracji i pierwszeństwo dyrektyw RQL opisano w [opcjach xretractor](opcje-wywolania/xretractor.md#plik-konfiguracyjny-toml).

Instalacja przez `cmake --install` umieszcza domyślny TOML w `<prefix>/share/retractordb/retractor.toml`; nie aktywuje go jako konfiguracji użytkownika. Można skopiować go do swojej lokalizacji konfiguracji albo wskazać przez `--config`.

## Środowisko rozwojowe Apple

Port macOS służy do rozwoju i testowania. Ogólny kontrakt systemu, opis usług i procedury produkcyjne w tej instrukcji dotyczą Linuksa. Instalator `curl` opisany powyżej obsługuje Linux; na Apple buduje się ze źródeł.

Sprawdzona konfiguracja portu to Apple silicon z macOS 27 i Apple clang 21. Intel Mac i starsze wydania systemu pozostają niezweryfikowane. Xcode 16.3+ Command Line Tools i deployment target macOS 14.4+ są dolnymi wymaganiami wynikającymi z użycia `std::print`, a nie deklaracją przetestowania wszystkich takich konfiguracji.

Przed budowaniem należy przygotować Command Line Tools (`xcode-select --install`), Homebrew oraz dostępne w `PATH` CMake, Python 3 i Git. `scripts/buildrdb.sh toolchain` korzysta na macOS z Homebrew. Skrypt poniżej może doinstalować brakujące Conan i Ninja przez Homebrew; korzysta też ze środowiska Conan zapewniającego wymaganą wersję CMake:

```bash
scripts/macos-build.sh
scripts/macos-build.sh --sanitize
```

Domyślny przebieg to Debug: konfiguracja, budowanie, instalacja, odświeżenie kopii testów, ponowne budowanie, CTest i osobny cel `test-api`. Dziennik trafia do `build/macos-build.log`. `--sanitize` włącza AddressSanitizer i UndefinedBehaviorSanitizer. `--no-install` wyłącza doinstalowywanie narzędzi, ale nie instalację zbudowanych programów. `--skip-tests` pomija testy, pozostawiając instalację. `scripts/macos-build.sh release` wybiera konfigurację Release, lecz nie wykonuje kontroli produkcyjnego `scripts/buildrdb.sh release`.

### Różnice istotne podczas rozwoju

| Obszar | Zachowanie portu macOS |
| --- | --- |
| Konfiguracja | Bez `--config` warstwy są odczytywane kolejno z `/etc/retractor/retractor.toml`, `/usr/local/etc/retractor/retractor.toml`, `/opt/homebrew/etc/retractor/retractor.toml`, a następnie z lokalizacji użytkownika. Późniejsza warstwa nadpisuje klucze wcześniejszej. Obecność ścieżki Homebrew nie oznacza dostępności formuły instalacyjnej. |
| IPC | Boost.Interprocess używa plikowego zaplecza pod `/tmp/boost_interprocess/...`; raport `--shmbudget` dotyczy tego woluminu, a nie linuxowego tmpfs `/dev/shm`. Zbyt długie nazwy obiektów otrzymują deterministyczny skrót; publiczna nazwa serwera zachowuje limit 32 znaków. |
| Żywotność procesu | PID i czas startu odczytuje `sysctl`; brak `/proc` nie oznacza braku kontroli żywego właściciela. Zamek magistrali ma ścieżkę zastępczą odporną na śmierć właściciela. |
| Czas rzeczywisty | `SCHED_FIFO` jest ustawiane na wątku przetwarzającym przez `pthread_setschedparam`. Priorytet z TOML (1..99) jest ograniczany do zakresu jądra. Brakuje affinity CPU i odpowiednika PREEMPT_RT; `mlockall` może zwrócić `ENOSYS`, po czym wykonanie trwa bez blokowania stron pamięci. Sen absolutny korzysta z interfejsu Mach. Nie jest to platforma pomiarowa dla linuxowych gwarancji czasu rzeczywistego. |
| Usługa | Kod rozpoznaje zadanie launchd przez `XPC_SERVICE_NAME` i rodzica PID 1 oraz buduje restart przez `launchctl kickstart -k`. Wybór domeny z efektywnego UID jest heurystyką: systemowy daemon uruchomiony jako użytkownik inny niż root może otrzymać błędną domenę. Pakiet nie dostarcza `.plist` ani instalatora usługi launchd. |
| Testy pamięci | Na Apple silicon testy działają bez Valgrinda. Kontrolę pamięci należy uruchamiać w osobnej konfiguracji z sanitizerami; samo przejście zwykłego CTest, również wpisów z `-vg` w nazwie, jej nie potwierdza. |
| API | Skrypt uruchamia jawny `test-api`, obejmujący klientów Python i C++ oraz tworzenie procesów. API nadal jest komponentem opcjonalnym; ta ścieżka rozwojowa nie rozszerza produkcyjnego kontraktu API na macOS. |
| Pakowanie | CPack tworzy TGZ bez komponentu usługowego systemd. Możliwość lokalnego utworzenia archiwum Darwin nie oznacza jego dostępności w instalatorze webowym. |

Kontrolę możliwości platformy i dopuszczanie ścieżek zastępczych opisano w [załączniku o budowaniu](budowanie-produkcyjne-i-warianty-badawcze.md#możliwości-platformy-i-sanitizery).
