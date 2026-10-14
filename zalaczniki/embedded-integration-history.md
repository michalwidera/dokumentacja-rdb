# Historia integracji osadzonej

Materiał historyczny etapów C2/C3 epiku #446 oraz początków wiązania Python. Zastępuje notatki `core-phase-2.md`, `core-phase-3.md` i historyczne części `jupyter-integration.md` z dawnego katalogu `docs` repozytorium kodu. Bieżący kontrakt opisuje [API Python](python-jupyter-api.md), a polecenia [budowanie biblioteki](../instalacja-systemu/python-build.md). #450 później wprowadziło własność katalogu magazynu, a #476/#451 dopełniły politykę błędów i odbiór. Real-time w bibliotece, cele mobilne, ingest, DeviceWindowLoader i sprzętowy odbiór MPS pozostają poza zakończonym zakresem epiku.

Po scaleniu epiku #445 port #511 zastąpił historyczną granicę rzucania błędów przez `Result` i handler `rdb::fatal()`. Wydawane programy mają jednolity tryb wyjątków, a `RDB_NOEXCEPT_CHECK` sprawdza osobno rdzeń. Poniższe opisy C2/C3 zachowują stan tamtych etapów; aktualną granicę odzyskiwania opisuje [API Python](python-jupyter-api.md#błędy-i-granica-fatalna).

## C2: właściciel stanu instancji

Demon konstruował stan raz, więc stan procesu i stan silnika były trudne do odróżnienia. Notebook tworzy i niszczy silnik przy powtórnych wykonaniach komórek. C2 rozdzieliło własność, aby nazwy strumieni w różnych instancjach nie powodowały wspólnych wyników.

| Stan przed C2 | Zmiana albo pozostawiony zakres |
| --- | --- |
| Statyczna mapa rekordów MEMORY w `faccmemory.cc` | `rdb::MemoryStore` należy do właściciela; osobne instancje są izolowane |
| Statyczna flaga `Descriptor::singleLineOutput_` | Formatowanie należy do konkretnego `std::ostream`, przez slot `ios_base::xalloc` |
| `fatalErrorRaised` | Pozostał elementem ścieżki zakończenia `xretractor`; granica rzucania oddziela embedding |
| Domyślny logger spdlog | Konfigurację wykonują launchery lub host modułu, nie instancja silnika |
| Liczniki probe | Znany dług procesu; pomiary nie są wykonywane przez build Python |
| `pProc`, `core_mutex`, `esm::*` | Stan serwisu nie został przeniesiony do embedding; pełna przebudowa serwisu pozostała osobna |

Memory Store zachował układ bucketów: dane, mapy NULL, licznik zapisów, rozmiar rekordu i liczbę żywych użytkowników. Writer i reader jednego strumienia nadal współdzielą bucket wewnątrz jednego Store. Konstruktor `memoryFile` przyjmuje `MemoryStore&`, a `makeAccessor` i `storage` opcjonalny wskaźnik. Brak argumentu wybiera `MemoryStore::processDefault()`, zachowując zachowanie istniejącego serwisu i xtrdb. Ostatni użytkownik usuwa bucket; instancja o innym rozmiarze rekordu czyści niezgodne dane. Zmienił się właściciel, a nie format danych.

`ut_faccmemory` sprawdza niezależne Store z tą samą nazwą, współdzielenie w jednym Store, domyślny Store procesu i przekazanie przez `storage`. Sama sekwencja tworzenia i niszczenia `Storage` nie dowodziła jeszcze izolacji całego planu.

Flaga formatowania deskryptora wcześniej była procesowa i resetowana przez samo wypisanie. Po C2 `rdb::singleLineFormat` zmienia stan strumienia przez `isSingleLineOutput` / `setSingleLineOutput`; pozostaje jednorazowy, lecz nie wpływa na inny strumień. Binding mógł usunąć obejście save/restore.

Gate `test/embedding_boundary.py` utrwala granicę: niedozwolony stan procesu, konfiguracja loggera i ścieżki kończące proces nie mogą wracać do warstwy osadzonej poza jawnie kontrolowaną granicą. Gate jest testem struktury źródeł, nie ogólnym dowodem współbieżności.

Pierwsza fasada `rdb::embed::Engine` posiadała Memory Store i pozwalała otwierać magazyn przez `openStorage()`. Nie wykonywała jeszcze planu. Probe i stan executora pozostały długiem, a dowód izolacji strumieni VOLATILE powstał dopiero w C3, gdy Store został przekazany do modelu i `streamInstance`.

## C3: plan sterowany przez hosta

`retractorcore` zawiera parser i kompilator RQL, wyrażenia, `query`/`qTree`, `dataModel`, `streamInstance`, reguły, `dumpManager` i oś czasu. Oddzielono go od warstwy serwisowej `retractor`: executor z zegarem, terminalem, IPC, magistralą i konfigurowaniem procesu. `rdbembed` łączy fasadę z `retractorcore`; `_core` nie linkuje bibliotek serwisu. Reguły DUMP pozostały w rdzeniu, ale fasada odmawia ich użycia, ponieważ nie publikuje globalnego modelu `pProc`.

Prywatny `Plan` posiada `qTree`, kompilator, model, `TimeLine` i liczniki w kolejności zależności. Destrukcja odbywa się w kolejności odwrotnej. `compile()` wykonuje parsowanie, kompilację, kontrole magazynu, przygotowanie artefaktów, modelu i osi czasu. `step()` wykonuje ZERO-step przy pierwszym slocie, wybiera następną chwilę z osi czasu, buduje maskę należnych strumieni i wywołuje `dataModel::processRows` bez zegara, IPC i terminala.

`untilEof` oznacza źródła jako ONESHOT przed utworzeniem modelu, jak `xretractor -u`. Slot wykrywający EOF pozostawia poprawnie policzone rekordy; następne wywołanie sygnalizuje koniec. Domyślny brak zawijania został wybrany dla notebooka traktującego plik jako dataset.

Model i `streamInstance` otrzymały opcjonalny `MemoryStore*`. Fasada przekazuje Store swojej instancji; serwis bez argumentu używa domyślnego Store. `ut_embedEngine` i test Python dwóch silników z taką samą nazwą VOLATILE utrwalają tę izolację.

`dumpManager::processStreamChunk` najpierw sprawdza księgę zadań. Bez zadań nie potrzebuje `pProc`; z zadaniem jego brak pozostaje błędem wewnętrznym. Fasada odrzuca DUMP, SYSTEM, ROTATION i DEVICE podczas kompilacji: odpowiednio wymagają modelu serwisu, wykonywałyby shell hosta, wymagają licznika rotacji lub fazy odbioru DEVICE, której `step()` nie ma. Callback hosta zezwalający na SYSTEM nie został dodany.

Wczesne C3 zastępowało deskryptory deklaracji przy rekompilacji notebooka. Kontrakt tej operacji został później ograniczony w #450 do własnego, zablokowanego katalogu, po preflight. Nie należy traktować starej notatki jako zgody na nadpisywanie obcych katalogów. #451 później dodało jawną odmowę brakującego źródła w embedding, podczas gdy serwis nadal daje NULL.

Odmowy fasady `Refused` rozróżniały etapy Parse, Check i Request. Granica `ThrowOnFatalScope` zamieniała K1/K4 na `EngineFatal` zamiast kończyć hosta. Awaria slotu zatrzaskiwała stan planu. Późniejsze #476 i #491 ustaliły klasę `PlanError`, wielodziedziczenie `ConfigError`/`IOError`, errno oraz skazę całego modułu po K1. Historyczne stwierdzenie „pełna polityka błędów pozostaje do wykonania” dotyczyło momentu C3, nie aktualnego stanu.

`record()` zwraca kopię, a `project()` spłaszczone wartości double z NaN dla NULL. Deklaracje czytają historię modelu, a wyniki SELECT jego magazyn. Python dodaje `rows`, `to_numpy`, `window` i `Window`; okno posiada własną tablicę NumPy i eksportuje jej DLPack. Dane nie przypinają pamięci silnika, więc tensor może przetrwać następny slot.

GIL jest zwalniany podczas pracy rdzenia. Pętla `run()` odzyskuje go okresowo dla sygnałów Pythona. Moduł przekierowuje diagnostykę do loggera `retractordb`; statyczne, ukryte linkowanie spdlog ogranicza tę konfigurację do rozszerzenia. C3 nie zapewniło pełnej przebudowy `executorsm::run`, fazy DEVICE, callbacka SYSTEM ani ogólnej gwarancji współbieżności; globalny `core_mutex` nadal ogranicza równoległe wykonanie.

## Początkowy binding i decyzje dystrybucyjne

Etap 1a objął tylko magazyn, ponieważ parser, wykonanie i procesowy stan wymagały C2/C3. Utrwalił mapowanie `FieldType`, `Field`, `Descriptor`, `Storage` i `Record`, odczyty offline oraz wyjątki. Wybór nanobind zamiast pybind11 został potwierdzony tą próbą. Historyczny pomiar na macOS arm64, Apple clang, Debug, nanobind 3.1.0 i Python 3.14 obejmował kompilację `module.cpp` 1.6 s cold / 0.9 s incremental i moduł 8.8 MB bez strippingu. Są to dane tamtego bindingu, nie porównawczy wynik wydajności silnika ani aktualny rozmiar wheel.

| Etap roadmapy | Zakres i dalsze rozstrzygnięcie |
| --- | --- |
| J1 | `compile`, `step`, iteracja wyników i błędy planu po C2/C3 |
| J2 | NumPy, `Window`, DLPack i IterableDataset; kopie zamiast bufora silnika |
| J3 | KeyboardInterrupt w `run` i most do `logging` |
| J4 | Pakowanie scikit-build-core/cibuildwheel i Linux manylinux; publikacja PyPI pozostaje osobna |
| J5 | Notebook Colab i smoke zainstalowanego wheel; odbiór runtime zapisuje się osobno |
| J6 | Push ingest z Pythona; poza wykonanym zakresem |

Decyzje: nie dodawać twardej zależności torch, aby nie zastępować cudzej instalacji CUDA; w Colab instalować wheel zamiast kompilować sdist; eksportować kopię wyników zamiast przypinać pamięć silnika. Referencyjne około 20 s dla instalacji było celem roadmapy, nie kryterium zamknięcia zadania. Mobilne XCFramework/AAR, embedding real-time, DeviceWindowLoader i odbiór sprzętowy MPS pozostają odrębnymi zadaniami.
