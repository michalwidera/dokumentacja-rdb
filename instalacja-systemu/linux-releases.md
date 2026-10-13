# Gotowe wydania na Linuksie

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

Sposoby dostarczania planu działającej usłudze opisano w [opcjach xretractor](../zalaczniki/opcje-wywolania/xretractor.md#usługa-i-wymiana-planu).

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

## Weryfikacja instalacji i konfiguracja

```bash
xretractor --build-info
xqry -h
xtrdb -h
```

`--build-info` pokazuje flagi optymalizatora gotowej binarki, bez uruchamiania silnika. Nie zastępuje testu działania własnego planu. Po instalacji warto sprawdzić również `command -v xretractor`, aby upewnić się, że `PATH` wskazuje wybraną instalację.

Instalator portable kopiuje domyślny TOML wyłącznie wtedy, gdy pliku jeszcze nie ma: do `/etc/retractor/retractor.toml` dla instalacji systemowej albo `$XDG_CONFIG_HOME/retractor/retractor.toml` (domyślnie `~/.config/retractor/retractor.toml`) dla użytkownika. W dostarczonym pliku `storage.dir` jest zakomentowane. Przed ustawieniem tej opcji należy utworzyć katalog i nadać prawo zapisu użytkownikowi uruchamiającemu silnik. Pełną kolejność konfiguracji i pierwszeństwo dyrektyw RQL opisano w [opcjach xretractor](../zalaczniki/opcje-wywolania/xretractor.md#plik-konfiguracyjny-toml).

Instalacja przez `cmake --install` umieszcza domyślny TOML w `<prefix>/share/retractordb/retractor.toml`; nie aktywuje go jako konfiguracji użytkownika. Można skopiować go do swojej lokalizacji konfiguracji albo wskazać przez `--config`.

W konfiguracji operator może ograniczyć historię w RAM i wzrost plików strumieni `DEFAULT`/`DIRECT` bez własnej retencji:

```toml
[limits]
history_memory_mib = 1024

[storage]
default_retention = [1000, 4]
```

`history_memory_mib` jest dodatnim budżetem MiB dla źródeł i pierścieni `MEMORY`; zbyt duży plan zostaje odrzucony podczas kompilacji. `default_retention` wymaga dwóch dodatnich liczb `[pojemność, segmenty]`, dotyczy też substratów plikowych i nie zastępuje jawnego `RETENTION`. Bez tego klucza strumienie plikowe bez retencji nadal rosną; `xretractor` wymienia je przy starcie i w `-c`. Plik TOML może też zawierać `server.autoname` (domyślnie `false`) oraz `service.unrestricted` (domyślnie `false`, dopuszcza `DO SYSTEM` przez `xqry --reset`); ich skutki i zasady pierwszeństwa opisują [opcje xretractor](../zalaczniki/opcje-wywolania/xretractor.md#plik-konfiguracyjny-toml).
