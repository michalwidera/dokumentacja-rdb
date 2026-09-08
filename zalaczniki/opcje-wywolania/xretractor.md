# xretractor

Program `xretractor` jest podstawowym procesem systemu RetractorDB. Kompiluje pliki z zapytaniami RQL i realizuje plan przetwarzania danych. Przygotowany jest do uruchomienia autonomicznego jako proces demona systemd.

## Tryby pracy

`xretractor` uruchamia się w jednym z dwóch trybów:

| Tryb                     | Opis                                                                  |
| ------------------------ | --------------------------------------------------------------------- |
| **Przetwarzania**        | Domyślny — kompiluje zapytania i uruchamia pętlę realizacji zapytań   |
| **Tylko kompilacja** `-c` | Kompiluje zapytania bez uruchamiania pętli; umożliwia wizualizację planu |

Wywołanie `-h` pokazuje inną listę opcji w zależności od trybu — skróty opcji się nakładają, dlatego należy zwrócić uwagę, w którym trybie dana opcja funkcjonuje.

---

## Tryb przetwarzania (domyślny)

```
$ xretractor -h
xretractor - compiler & data processing tool.

Usage: xretractor queryfile [option]

Available options:
  -h [ --help ]               Show program options
  -b [ --build-info ]         show optimizer build configuration
  -c [ --onlycompile ]        compile only mode
  -q [ --queryfile ] arg      query set file
  -r [ --quiet ]              no output on screen, skip presenter
  -s [ --status ]             check service status
  -v [ --verbose ]            verbose mode (show stream params)
  -x [ --xqrywait ]           wait with processing for first query
  -n [ --name ] arg           instance name; own IPC area and lock
  -a [ --autoname ]           generate a docker-style instance name
  -k [ --noanykey ]           do not wait for any key to terminate
  -j [ --service ]            service mode: log to stderr (journald)
  -t [ --realtime ]           enable real-time scheduling
  -f [ --no-clock ]           offline mode: compute slots without waiting
  -u [ --until-eof ]          forces one-shot all sources
  -g [ --config ] arg         config file (TOML); overrides search
  -m [ --llimitqry ] arg (=0) loop iteration limit, 0 - no limit
```

### Opcje trybu przetwarzania

| Opcja | Znaczenie |
| ----- | --------- |
| `help` | Wyświetlenie tekstu podpowiedzi. Lista różni się w zależności od trybu (z `-c` lub bez). |
| `build-info` | Wypisuje konfigurację optymalizatora, z jaką zbudowano binarkę (flagi `RDB_OPT_*` oraz `RDB_BENCH_PROBE`), i kończy działanie bez uruchamiania silnika. Obsługiwana przed wczytaniem i walidacją pliku konfiguracyjnego, więc działa także na hoście z niepoprawnym `storage.dir`. Wynik jest stabilny i przeznaczony do przetwarzania automatycznego — korzystają z niego `scripts/buildrdb.sh` oraz test `it_optimizer_ablation-build-info`. Szczegóły w załączniku o budowaniu produkcyjnym i wariantach diagnostycznych. |
| `onlycompile` | Przełączenie narzędzia w tryb „tylko kompilacja". Pętla realizacji zapytań nie jest uruchamiana. |
| `queryfile` | Nazwa pliku z zapytaniami do kompilacji i uruchomienia. |
| `quiet` | Pominięcie wyświetlania wyników na ekranie. Przetwarzanie działa normalnie, ale prezenter wyników nie jest uruchamiany. |
| `status` | Sprawdzenie blokady instancji wskazanej przez `--name`, `RDB_NAMESPACE` albo historyczną pustą nazwę. Wynik `Running` oznacza, że inny proces utrzymuje tę samą tożsamość. |
| `verbose` | Tryb zwiększonej komunikatywności — wyświetla parametry strumieni. Pozostałość po fazie rozwojowej; prawdopodobnie zostanie zachowana. |
| `xqrywait` | Kompiluje zapytania i wstrzymuje pętlę przetwarzania do chwili nadejścia pierwszego zapytania z procesu `xqry`. Wymagane przy jednoczesnym użyciu `-m N` w skryptach i testach: bez tej flagi serwer może przetworzyć wszystkie N cykli zanim klient zdąży się podłączyć, co skutkuje brakiem danych i oczekiwaniem po stronie `xqry` aż do przekroczenia limitu czasowego. Pierwsze polecenie odebrane od `xqry` (np. `-d` lub `-s`) odblokowuje pętlę przetwarzania. |
| `name arg` | Nadaje instancji stałą nazwę. Nazwa wybiera osobny plik blokady i obszar IPC oraz pozwala kierować polecenia przez `xqry --server`. Dopuszczalne są najwyżej 32 znaki: małe litery, cyfry, `_` i `-`, przy czym pierwszy znak musi być literą. |
| `autoname` | Generuje nazwę instancji w stylu nazw kontenerów i wypisuje ją przy starcie. Wzajemnie wyklucza się z `--name`. |
| `noanykey` | Dowolny klawisz nie przerywa pętli przetwarzania. Bez tej opcji naciśnięcie dowolnego klawisza zatrzymuje system. |
| `service` | Tryb usługowy: dziennik trafia na `stderr` (przechwytywany przez journald), bez pliku dziennika w katalogu tymczasowym, bez własnego znacznika czasu i bez kodów ANSI. Tryb można włączyć również zmienną środowiskową `XRETRACTOR_SERVICE` o dowolnej wartości poza pustą i `0` — wygodne w jednostce systemd przez `Environment=`. |
| `realtime` | Włącza szeregowanie czasu rzeczywistego: `SCHED_FIFO`, `mlockall` i absolutne uśpienie wątku przetwarzającego. Wymaga uprawnień `CAP_SYS_NICE` i `CAP_IPC_LOCK` (lub root). Zalecane w środowisku produkcyjnym przy wymogu deterministycznego czasu reakcji. |
| `no-clock` | Tryb offline: zachowuje racjonalną oś czasu, indeksy logiczne, początki i ogony planu, ale pomija oczekiwanie na zegar ścienny. Nie może być łączony z `--realtime`. |
| `until-eof` | Przełącza deklarowane źródła plikowe w tryb bez zawijania i kończy przebieg, gdy pierwsze z nich wyczerpie dane. Źródło `DEVICE` nie ma końca pliku. |
| `config` | Ścieżka do pliku konfiguracyjnego w formacie TOML. Pomija standardową kolejność wyszukiwania (`/etc/retractor/retractor.toml`, następnie `$XDG_CONFIG_HOME/retractor/retractor.toml` lub `~/.config/retractor/retractor.toml`). Brak pliku konfiguracyjnego jest stanem poprawnym — program startuje z ustawieniami domyślnymi. |
| `llimitqry` | Ogranicza liczbę iteracji w pętli realizacji zapytań. Wartość `0` oznacza brak limitu. |

### Wiele instancji

Różne nazwane instancje mogą działać równocześnie:

```bash
xretractor pomiary.rql --name pomiary --noanykey &
xretractor diagnostyka.rql --name diagnostyka --noanykey &
xqry --bus
```

Każda otrzymuje własną blokadę i zestaw obiektów IPC. Wspólna magistrala odrzuca jednak
plan, który koliduje z żywą instancją nazwą strumienia, zapisywanym plikiem magazynu albo
plikiem licznika `:ROTATION`. Kontrola odbywa się przed usuwaniem artefaktów. Brak `--name`
zachowuje historyczną instancję bezimienną.

Tryb usługowy stanowi osobną gwarancję: w każdej przestrzeni `RDB_NAMESPACE` może działać
dokładnie jedna instancja usługowa, w domyślnej przestrzeni nazwana `service`. Szczegóły zawiera rozdział
[Wiele instancji i magistrala](../../architektura-systemu-przetwarzania-danych/wiele-instancji-i-magistrala.md).

### Przetwarzanie wsadowe bez zegara

Najprostszy przebieg całego pliku bez ręcznego dobierania liczby iteracji ma postać:

```bash
xretractor query.rql --no-clock --until-eof --noanykey --quiet
```

`--no-clock` usuwa wyłącznie uśpienia. Nie zmienia kolejności slotów ani zawartości
artefaktów, dlatego nadaje się do szybkiej weryfikacji po zakończeniu procesu. Może jednak
wyprzedzić klienta `xqry`, więc nie jest właściwym trybem do obserwacji na żywo.

`--until-eof` sprawia, że źródło sekwencyjne nie wraca na początek pliku. Koniec jest
sprawdzany po przetworzeniu slotu, dokładnie przed rekordem, który musiałby już powstać ze
syntetycznego `NULL` za końcem danych. Przy wielu źródłach kończy pierwsze wyczerpane, aby
plan nie kontynuował obliczeń z brakującym wejściem. Opcję można łączyć z `-m N`; działa
warunek, który wystąpi wcześniej.

> **⚠️ Ostrzeżenie** Skróty zależą od trybu. W wykonaniu `-f` oznacza `--no-clock`, a `-u`
> oznacza `--until-eof`. Przy `-c` te same litery oznaczają odpowiednio `--fields` i
> `--rules` oraz nie uruchamiają przetwarzania.

> **_NOTE:_** Równoważność wykonania taktowanego i offline sprawdza `noclock_offline`, a
> zatrzymanie na pierwszym końcu danych i kontrolę zawijania sprawdza `untileof_stop`.

---

## Tryb tylko kompilacja (`-c`)

```
$ xretractor -h -c
xretractor - compiler & data processing tool.

Usage: xretractor -c queryfile [option]

Available options:
  -h [ --help ]          show help options
  -b [ --build-info ]    show optimizer build configuration
  -c [ --onlycompile ]   compile only mode
  -q [ --queryfile ] arg query set file
  -r [ --quiet ]         no output on screen, skip presenter
  -d [ --dot ]           create dot output
  -m [ --csv ]           create csv output
  -f [ --fields ]        show fields in dot file
  -t [ --tags ]          show tags in dot file
  -s [ --streamprogs ]   show stream programs in dot file
  -u [ --rules ]         show rules in dot file
  -i [ --hideruleprog ]  hide rule program in rules (-u) output
  -p [ --transparent ]   make dot background transparent
  -w [ --diagram ] arg   create diagram output
  -z [ --shmbudget ]     show shared memory budget of the compiled plan
```

W tym trybie dostępne są opcje tworzenia diagramów i zrzutów diagnostycznych opisywanych szerzej w opracowaniu.

### Opcje wizualizacji i diagnostyki

| Opcja | Znaczenie    |
| ----- | ------------ |
| `help` | Wyświetlenie tekstu podpowiedzi (identycznie jak w trybie przetwarzania, lista różni się w zależności od trybu). |
| `build-info` | Znaczenie identyczne jak w trybie przetwarzania — wypisuje konfigurację optymalizatora i kończy działanie. Flaga `-c` nie ma na wynik wpływu; opcja jest dostępna w obu trybach, aby zrzut konfiguracji dał się pobrać niezależnie od sposobu wywołania. |
| `onlycompile` | Włączony — w tej tabeli opisano opcje obowiązujące przy aktywnej fladze `-c`. |
| `queryfile` | Nazwa pliku z zapytaniami do kompilacji. |
| `quiet` | Testowanie samego procesu kompilacji bez prezentowania wyników. Pozostałe opcje prezentacji nie są uruchamiane. Opcja dołączona na potrzeby rozwojowe. |
| `dot` | Tworzy plik tekstowy w formacie DOT opisujący hierarchiczne struktury wytworzone przez kompilator. Plik można przekazać do narzędzia Graphviz w celu wygenerowania graficznego opisu zależności. |
| `csv` | Eksportuje hierarchiczne struktury danych do pliku CSV (wartości oddzielone przecinkami). |
| `fields` | Dołącza do wykresu DOT pola i ich typy dla każdego strumienia danych. |
| `tags` | Dołącza do wykresu DOT programy wewnętrznego języka systemu, które tworzą pola poszczególnych zapytań. Musi być wywołana razem z `fields` — wizualnie łączy pola z ich programami. |
| `streamprogs` | Dołącza do wykresu DOT programy algebry strumieniowej tworzące poszczególne strumienie zapytań. |
| `rules` | Dołącza reguły alarmowania do wykresu. |
| `hideruleprog` | Ukrywa programy opisujące warunki alarmowania (używane razem z `rules`). |
| `transparent` | Generuje wykres z przezroczystym tłem. |
| `diagram` | Generuje diagramy kulkowe. Argument w postaci `typ:ilość_cykli`: `typ` (`0` lub `1`) określa, czy diagramy prezentują znaczniki czasu; `ilość_cykli` określa liczbę cykli na diagramie. |
| `shmbudget` | Raportuje stałą rezerwację IPC, pojemność i wolne miejsce systemu plików `shm_open` (zwykle `/dev/shm`) oraz koszt jednej kolejki klienta dla każdej delty planu. Pozwala oszacować liczbę równoczesnych subskrypcji przed uruchomieniem serwera. |

---

## Plik konfiguracyjny (TOML)

Opcja `--config` wskazuje plik konfiguracyjny; bez niej program przeszukuje warstwowo dwie lokalizacje, w podanej kolejności, a każda kolejna warstwa nadpisuje klucze poprzedniej:

1. `/etc/retractor/retractor.toml` — warstwa systemowa,
2. `$XDG_CONFIG_HOME/retractor/retractor.toml` (lub `~/.config/retractor/retractor.toml`) — warstwa użytkownika.

Brak plików jest **stanem poprawnym** — program startuje z wartościami domyślnymi. Błąd składni TOML w warstwie wyszukiwanej powoduje ostrzeżenie i pominięcie tej warstwy; przy jawnie podanej ścieżce (`--config`) brak pliku lub błąd składni są twarde, bo stanowią jawne żądanie użytkownika. Ten sam plik czyta również `xqry` (pod skrótem `-e`), dlatego sekcje `[ipc]` i `[timing]` dotyczą obu procesów.

| Klucz | Domyślnie | Znaczenie |
| ----- | --------- | --------- |
| `storage.dir` | _(brak)_ | Domyślny katalog artefaktów. Stosowany **tylko** gdy zestaw RQL nie zawiera dyrektywy `:STORAGE` — RQL ma pierwszeństwo. Katalog musi istnieć i być zapisywalny, inaczej program kończy się błędem `Configuration error: storage.dir …`. |
| `ipc.queue_buffer_seconds` | `10` | Głębokość kolejki IPC wyrażona w sekundach strumienia; liczba elementów to `sekundy / interwał`. |
| `ipc.min_queue_elements` | `100` | Dolna granica pojemności kolejki, niezależna od interwału strumienia. |
| `ipc.client_response_max_fails` | `300` | Liczba prób odczytu odpowiedzi z pamięci współdzielonej przez `xqry`. Efektywny czas oczekiwania to iloczyn tej wartości i interwału odpytywania. |
| `timing.server_startup_wait_s` | `30` | Maksymalny czas oczekiwania `xqry --wait-server` na gotowość serwera. |
| `timing.server_startup_poll_ms` | `100` | Interwał odpytywania podczas oczekiwania na start serwera. |
| `timing.query_no_data_timeout_ms` | `10000` | Czas braku danych, po którym klient `xqry` uznaje serwer za martwy. |
| `scheduling.rt_priority` | `50` | Priorytet `SCHED_FIFO` w trybie `--realtime`; dopuszczalny zakres 1–99. |
| `paths.lock_dir` | _(katalog tymczasowy systemu)_ | Katalog na pliki blokad instancji. Dla usług systemd zalecane `/var/run/retractor` lub `$XDG_RUNTIME_DIR`. Ścieżka musi być bezwzględna. |
| `server.autoname` | `false` | Generuje nazwę, gdy nie podano `--name` ani `--autoname`. Jawne `--name` wygrywa. Wartość `false` zachowuje historyczną instancję bezimienną. |
| `service.query_file` | _(wartość z konfiguracji budowania)_ | Plik zapytań nadpisywany przy przekazaniu zestawu działającej usłudze. Używany wyłącznie jako zapasowy, gdy usługa nie zaraportowała własnego `QUERYFILE` w pliku blokady. Musi być zgodny z argumentem `ExecStart` jednostki systemd — konfiguracja nie zmienia `ExecStart`. |

Wartości spoza sensownego zakresu nie zatrzymują usługi: program zapisuje ostrzeżenie w dzienniku i używa wartości domyślnej. Wyjątkiem jest `storage.dir`, którego niepoprawność jest błędem twardym — wskazywałaby, że wyniki trafiłyby w niezamierzone miejsce lub nigdzie.

Przykładowy plik:

```toml
[storage]
dir = "/var/lib/retractor"

[ipc]
queue_buffer_seconds = 30

[scheduling]
rt_priority = 60

[paths]
lock_dir = "/var/run/retractor"

[server]
autoname = false
```

> **_NOTE:_** Wczytywanie warstw i walidację pokrywa test jednostkowy `ut_appConfig`; twarde odrzucenie niepoprawnego `storage.dir` — test integracyjny `config_storage_validation`.

---

## Usługa i wymiana planu

Start bez pliku `.rql` albo z pustym plikiem tworzy bezczynną instancję z działającym IPC.
Pierwszy lub kolejny pełny plan można załadować bez restartu:

```bash
xqry --server service --reset plan.rql
```

Serwer parsuje i kompiluje całą treść, sprawdza kolizje zasobów, rezerwuje nowy zestaw,
a następnie przełącza plan na granicy slotu. Odmowa pozostawia poprzedni plan bez zmian.
Pusty plik resetu przywraca stan bezczynny. W instancji usługowej zaakceptowana treść jest
również zapisywana w pliku startowym usługi.

Alternatywna ścieżka `xretractor nowy-plan.rql` wykrywa działającą jednostkę systemd,
weryfikuje zestaw, atomowo nadpisuje jej plik startowy i wywołuje restart. Jawne wskazanie
innej tożsamości przez `--name` albo `--autoname` oznacza zamiast tego start osobnej
instancji. W razie krytycznego błędu plan usługowy jest opróżniany, aby systemd uruchomił
proces ponownie w bezpiecznym stanie bezczynnym.

---

## Informacje o wersji

Na końcu każdego komunikatu pomocy wyświetlana jest linia z informacjami o buildzie:

```
Branch: issue_31-doc:2707ce0,
Code compiler: GNU Ver. 13.3.0,
Build time: 2512211449,
Type: Debug
```

| Pole             | Znaczenie                                                                              |
| ---------------- | -------------------------------------------------------------------------------------- |
| `Branch`         | Nazwa odnogi repozytorium i skrót commita (hash), z którego zbudowano program          |
| `Code compiler`  | Wersja kompilatora GCC użytego do budowy                                               |
| `Build time`     | Data i godzina kompilacji w formacie `YYMMDDHHMM` (tu: 21 grudnia 2025, godz. 14:49)  |
| `Type`           | Typ buildu: `Debug` lub `Release`                                                      |

Kolejna linia wskazuje lokalizację pliku dziennika:

```
Log: /tmp/xretractor.log
```

Plik `/tmp/xretractor.log` rejestruje historię wywołań i zdarzeń wewnętrznych systemu. W środowisku produkcyjnym należy zadbać o regularne czyszczenie lub rotację tego pliku.

Ostatnia linia zawiera informację o licencji MIT, która umożliwia bezpieczne użycie kodu w zastosowaniach korporacyjnych.
