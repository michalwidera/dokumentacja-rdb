# Budowanie ze źródeł

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

Instalacja jest osobnym krokiem po budowaniu i domyślnie nie wymaga sudo. Testy integracyjne korzystają również z zainstalowanych programów, dlatego instalacja poprzedza testy. Opcjonalne biblioteki API mają [osobne cele instalacji i testowania](../zalaczniki/api-monitorowania-strumieni.md).

Produkcyjne wydanie ze źródeł wymaga czystego drzewa Git:

```bash
scripts/buildrdb.sh release
cmake --install build/Release
ctest --test-dir build/Release --output-on-failure
```

Tryb `release-dirty` służy do diagnostyki lokalnych zmian i nie tworzy wydania produkcyjnego. Szczegóły w [kontrakcie budowania](../zalaczniki/budowanie-produkcyjne-i-warianty-badawcze.md). Paczki dla odbiorców są przygotowywane osobno; skrypty i kontrole linuxowych wydań opisano w repozytorium kodu w `scripts/release_package/README.md`.

## Kontrola obsługi błędów rdzenia

Domyślne `RDB_NOEXCEPT_CHECK=ON` dodaje do pełnego buildu biblioteki kontrolne `rdb_noexcept_check`, `retractorcore_noexcept_check` i `rdbembed_noexcept_check`. Kompilują te same źródła rdzenia ponownie z `-fno-exceptions`, bez wyznaczonych jednostek obsługujących ANTLR, Boost.Stacktrace i konfigurację. Użycie `throw`, `try` lub `catch` w kontrolowanej części rdzenia jest wtedy błędem kompilacji. Obiekty kontrolne nie są linkowane do wydawanych programów.

Wydawane programy i moduł Python są kompilowane jednolicie z obsługą wyjątków. Biblioteki zewnętrzne nadal korzystają z wyjątków; mieszanie jednostek z `-fno-exceptions` i bez tej flagi w jednym programie naruszało zgodność funkcji inline Boosta i spdloga oraz pomijało destruktory przy przejściu wyjątku przez rdzeń. Dlatego `RDB_NOEXCEPT_CHECK` zastępuje pierwotne `RDB_NO_EXCEPTIONS` z portu #511.

Operacje rdzenia C++ zgłaszają obsługiwalne błędy przez `rdb::Result<T> = std::expected<T, Error>`, z kategorią, komunikatem i `errno`. Wywołujący sprawdza wynik, a tworzenie obiektów może wymagać fabryki `create` lub `make`. `RDB_NOEXCEPT_CHECK=OFF` wyłącza tylko dodatkową kontrolę kompilacji; nie przywraca wcześniejszego API C++ opartego na wyjątkach. Nie jest to przełącznik bezpieczeństwa kernela: `rdb::fatal()` kończy hosta niezależnie od tej flagi. Granicę opisuje [API Python](../zalaczniki/python-jupyter-api.md#błędy-i-granica-fatalna).

Pełny build uruchamia kontrolę automatycznie. Budowanie wyłącznie wybranego celu, np. `_core`, nie uruchamia niezależnych bibliotek kontrolnych; można zbudować je jawnie zgodnie z [procedurą dla Pythona](python-build.md#moduł-z-drzewa-budowy). Test `exception_mode_guard` sprawdza rzeczywiste flagi wydawanych celów oraz kompletność kontroli na podstawie `compile_commands.json`. Nie potwierdza, że build kontrolny został wykonany.

## Środowisko rozwojowe Apple

Port macOS służy do rozwoju i testowania. Ogólny kontrakt systemu, opis usług i procedury produkcyjne w tej instrukcji dotyczą Linuksa. Instalator `curl` opisany w [gotowych wydaniach](linux-releases.md) obsługuje Linux; na Apple buduje się ze źródeł.

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

Kontrolę możliwości platformy i dopuszczanie ścieżek zastępczych opisano w [załączniku o budowaniu](../zalaczniki/budowanie-produkcyjne-i-warianty-badawcze.md#możliwości-platformy-i-sanitizery).
