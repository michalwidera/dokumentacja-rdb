# API Python i Jupyter

Ten rozdział opisuje API gałęzi `dev/445-jupyter-epic`, odebrane w #451, wraz z kontraktem katalogu z #450. [Instalację wheel i Jupyter](../instalacja-systemu/python-jupyter.md), [budowanie biblioteki](../instalacja-systemu/python-build.md) oraz [odbiór notebooków](notebook-acceptance.md) opisują osobne strony. [Historia C2/C3](embedded-integration-history.md) nie zastępuje tego kontraktu.

## Role i zakres

| Interfejs | Zastosowanie | Potrzebuje działającego serwera |
| --- | --- | --- |
| `retractordb.Engine` | Kompiluje RQL i liczy plan wewnątrz procesu Pythona | Nie |
| `retractordb.Storage`, `load_descriptor` | Czyta istniejące magazyny offline | Nie; aktywny serwer może wykluczać dostęp |
| `retractordb.client.Client` | Obserwuje strumienie działającej instancji przez `xqry` | Tak |

`Engine` liczy na osi czasu logicznej, bez zegara czasu rzeczywistego, wątku IPC ani terminala. Nie dołącza do magistrali, nie rezerwuje przestrzeni nazw i nie publikuje swoich strumieni dla `xqry`. Czas rzeczywisty zapewnia `xretractor`; strumienie jego serwisu czyta [API monitorowania](api-monitorowania-strumieni.md). Biblioteka osadzona nie deklaruje gwarancji czasu rzeczywistego.

Pakiet importuje `_core` dopiero przy żądaniu API osadzonego. Czysty klient może działać bez rozszerzenia. NumPy jest zależnością biblioteki osadzonej; PyTorch importuje wyłącznie jawnie zaimportowany `retractordb.torch`. Instalacja klienta `pip install ./api/python` zastępuje dystrybucję wheel o tej samej nazwie, włącznie z `_core`; używaj osobnych środowisk.

## Kompletny przykład

Przykład tworzy wejście poza katalogiem należącym do silnika, wykonuje plan, sprawdza wartości oraz współdzielenie tablicy przez DLPack. Część PyTorch jest opcjonalna.

```python
from pathlib import Path
from tempfile import TemporaryDirectory
import numpy as np
import retractordb as rdb

with TemporaryDirectory() as directory:
    source = Path(directory) / "input.txt"
    source.write_text("\n".join(str(value) for value in range(10, 81, 10)) + "\n")
    with rdb.Engine() as engine:
        engine.compile(f"""
            DECLARE a INTEGER STREAM src, 1/2 TEXTFILE '{source}'
            SELECT a*2 STREAM dst FROM src
        """)
        assert engine.run() == 8
        assert engine.slots_done == 8 and engine.time == 4
        assert [row[0] for row in engine.rows("dst")] == list(range(20, 161, 20))
        descriptor = engine.schema("dst")
        field = descriptor[0].name
        block = engine.to_numpy("dst", fields=[field], dtype="float64")
        np.testing.assert_array_equal(block[:, 0], np.arange(20, 161, 20))
        window = engine.window("dst", fields=[field], size=4, stride=2)
        assert window.shape == (3, 4, 1)
        try:
            import torch
        except ImportError:
            torch = None
        if torch is not None:
            tensor = torch.from_dlpack(window)
            assert tensor.data_ptr() == window.to_numpy().__array_interface__["data"][0]
    np.testing.assert_array_equal(block[:, 0], np.arange(20, 161, 20))
    assert window.shape == (3, 4, 1)
```

Osiem rekordów daje osiem slotów i czas logiczny 4 przy interwale 1/2. `Record`, tablica i okno są kopiami wyników; pozostają czytelne po `close()` silnika.

## Engine: cykl życia i wykonanie

| Element API | Kontrakt |
| --- | --- |
| `Engine(storage_dir="", lock_dir="", config="")` | Własna instancja i Memory Store; domyślnie prywatny katalog tymczasowy |
| `compile(rql, until_eof=True)` | Zamyka poprzedni plan, parsuje, kompiluje i tworzy nowy model |
| `step()` | Zwraca indeks wykonanego slotu od 0 albo `None` po końcu wejścia |
| `run(slots=None)` | Zwraca liczbę slotów wykonanych w tym wywołaniu; bez budżetu liczy do EOF |
| `has_plan`, `failed`, `end_of_input` | Stan planu, zatrzaśnięta awaria slotu oraz koniec wejścia |
| `slots_done`, `time` | Łączna liczba wykonanych slotów i dokładny czas logiczny `Fraction` |
| `storage_dir` | Efektywny katalog planu; bez planu katalog domyślny |
| `streams()`, `schema(stream)`, `is_declared(stream)` | Nazwy strumieni, deskryptor i informacja o deklarowanym źródle |
| `record_count(stream)`, `retained_from(stream)` | Łączny licznik rekordów oraz pierwszy nadal dostępny indeks |
| `record(stream, index)` | Kopia jednego rekordu; ujemny indeks liczy od końca |
| `rows(stream, first=None, count=None)` | Iterator kopii rekordów; domyślnie od najstarszego zachowanego |
| `close()`, `with Engine() as engine` | Zamyka plan i zwalnia jego zasoby; zwykłe zamknięcie jest idempotentne |

Domyślne `until_eof=True` zatrzymuje plan po slocie, w którym pierwsze deklarowane źródło się wyczerpało. `until_eof=False` pozwala źródłom zawijać się po EOF. Plan bez kończącego się wejścia wymaga budżetu, np. `run(slots=8)`, albo przerwania. Nie utożsamiaj slotu z liczbą rekordów każdego strumienia: plan może mieć różne interwały i opóźnione początki.

Nieudana rekompilacja również zamyka poprzedni plan; odmowa nie przywraca go. Po K2/K3 można poprawić żądanie i kompilować ponownie. Awaria podczas slotu ustawia `failed`; kolejne `step()` powtarza klasę awarii do rekompilacji. Dotychczasowe wyniki mogą pozostać czytelne po K4. K1 dodatkowo skazuje moduł do restartu interpretera.

`compile`, `step`, `run` i odczyty rekordów zwalniają GIL. `run()` sprawdza sygnały Pythona co około 50 ms pomiędzy slotami i umożliwia `KeyboardInterrupt`; to nie jest gwarantowany maksymalny czas przerwania długiego slotu. Diagnostyka silnika trafia do `logging.getLogger("retractordb")`.

## Katalog magazynu i dostęp offline

`Engine()` tworzy prywatny katalog, który pozostaje po `close()` i znika przy zniszczeniu instancji. Jawny `storage_dir` oraz nadpisująca go dyrektywa RQL `STORAGE` muszą wskazywać katalog pusty przy pierwszym użyciu albo należący do silnika przez poprawny znacznik `.retractordb-embedded`. Obcy katalog jest odrzucany. Znacznik nie jest dowodem, że proces właściciela nadal działa.

Blokada katalogu trwa do zamknięcia magazynów planu. Wyklucza drugi `Engine` oraz `Storage` w oznaczonym katalogu, także przez alias ścieżki i z innego procesu. Śmierć procesu zwalnia blokadę. Jawny katalog pozostaje na dysku; rekompilacja może zastąpić jego deskryptory i wyniki. Odmowa preflight zachowuje poprzednie artefakty, lecz zamyka plan; późniejsze błędy I/O nie są transakcyjne.

Wejścia muszą leżeć poza katalogiem wyników; wyjścia pozostają wewnątrz niego. Brak deklarowanego pliku źródłowego jest odrzucany podczas `compile()` jako `IOError` z `errno=ENOENT` i ścieżką w komunikacie. Serwis nadal daje dla tego przypadku rekordy NULL. Usunięcie źródła po kompilacji to osobny przypadek. Jawne `DISPOSABLE` nadal upoważnia do usunięcia źródła po użyciu.

Otwieranie `Storage` może odbudować indeks `.meta`; jest to dostęp offline. Dla katalogu używanego przez serwis podaj jego `lock_dir` albo `config` wskazujący TOML z `paths.lock_dir`; argument ma pierwszeństwo. Konfiguracja jest czytana wyłącznie po jawnym wskazaniu pliku. Bez obu parametrów kontrola zgaduje katalog z TMPDIR i zgłasza `UserWarning` oraz wpis INFO w loggerze `retractordb`.

`[embedded] lenient_lock_dirs` określa katalogi, w których tylko trzymana blokada odmawia dostępu. Bez klucza domyślnym katalogiem łagodnym jest systemowy katalog tymczasowy. Klucz zastępuje tę listę; inne katalogi są sprawdzane ściśle. Kontrola przy otwieraniu nie wyklucza późniejszego startu demona ani serwisu używającego innego katalogu blokad. Prywatny katalog `Engine()` pomija kontrolę blokad serwisu.

## Storage, Descriptor i Record

| Element API | Kontrakt |
| --- | --- |
| `load_descriptor(path)` | Odczytuje `.desc`; brak pliku to `NoSuchStream`, uszkodzony deskryptor to `CorruptDescriptor` |
| `Descriptor` | Sekwencja `Field`; `size_bytes` pomija pola konfiguracyjne, `flat_element_count` liczy elementy danych |
| `Field` | Właściwości `name`, `length`, `array_count`, `type` (`FieldType`) |
| Metody deskryptora | `has_field`, `field_index`, `byte_offset`, `field_type_name`, `storage_policy` |
| `Storage(qry_id, file_name, storage_param="", storage_type="DEFAULT", lock_dir="", config="")` | Otwiera istniejący magazyn offline, bez kompilowania planu |
| `Storage.descriptor`, `record_count`, `is_declared`, `closed` | Schemat, licznik, rodzaj źródła i stan uchwytu |
| `Storage.read(i)`, `storage[i]`, `len(storage)` | Kopia rekordu lub liczba rekordów; ujemny indeks od końca |
| `Storage.close()` i context manager | Zamyka magazyn, indeks i blokadę katalogu; odczyt po zamknięciu jest odrzucany |
| `Record.index`, `descriptor`, `record[i]` | Indeks, schemat i spłaszczone elementy własnej kopii payload |

Wartości wychodzą jako `int`, `float`, `str`, `Fraction` dla RATIONAL, krotka dla par i `None` dla NULL. `STRING[N]` stanowi jeden element wartości, a tablica numeryczna N elementów. Pola konfiguracyjne deskryptora nie zajmują pozycji w rekordzie. Bezpośredni `Storage` nie odczytuje źródeł `BINFILE`, `TEXTFILE` ani `DEVICE`; wyniki źródła należącego do planu można czytać przez `Engine` w granicach jego historii.

Retencja może wygasić indeksy. `record_count` jest licznikiem logicznym, nie liczbą wszystkich nadal dostępnych rekordów; użyj `retained_from`. Domyślne `rows()` i `to_numpy()` czytają zachowany ogon. Wygasły indeks jest odrzucany zamiast wskazywać inną pozycję pierścienia.

## Błędy i granica fatalna

```text
RetractorDBError
+-- ConfigError (także ValueError)
|   +-- PlanError
|       +-- RQLSyntaxError
|       +-- CompileError
|       +-- CorruptDescriptor
+-- IOError (także OSError)
+-- InternalError
+-- NoSuchStream
+-- StorageError
```

| Klasa | Wynik w Pythonie | Stan po błędzie |
| --- | --- | --- |
| K1, naruszenie niezmiennika | `InternalError` | Moduł skazany; chronione wejścia odmawiają do restartu interpretera; `close()` pozostaje dostępne |
| K2, odmowa planu | `PlanError`: składnia, kompilacja, uszkodzony deskryptor | Można poprawić dane i spróbować ponownie; nieudany `compile()` nie pozostawia starego planu |
| K3, odmowa żądania | `ConfigError`, również `ValueError` | Instancja pozostaje używalna |
| K4, błąd środowiska | `IOError`, również `OSError` | Awaria slotu zatrzymuje plan do rekompilacji; odmowa kompilacji nie tworzy planu |
| K5, niepoprawna wartość danych | `None` lub `NaN` | Plan pracuje dalej; ostrzeżenie silnika jest kompilowane poza Release |
| K6, przestarzała składnia | `DeprecationWarning` z `compile()` | Plan pozostaje używalny |
| K7, abort lub błąd poza obsługiwaną granicą | Zakończenie procesu | Kernel trzeba uruchomić ponownie |

`IOError.errno` zachowuje kod systemowy albo używa EIO bez kodu; `filename` jest ustawiane, gdy wywołanie przyjmowało ścieżkę jako argument. W innych przypadkach ścieżka może być w komunikacie. Błędy nazwy pola/strumienia, indeksu, konwersji tablic i sygnatury mogą dawać standardowe `KeyError`, `IndexError`, `ValueError` lub `TypeError`; nie każdy wyjątek dziedziczy po `RetractorDBError`.

Obsługiwane wejścia przechwytują K1/K4 do wyjątków, ale nie zapewniają przeżycia każdej awarii rdzenia. `FatalError` lub `EnvironmentError` w funkcji `noexcept`, podczas destrukcji albo zwijania stosu mogą zakończyć interpreter. Dotyczy to także granicy `Engine.close()` i destruktora. Nie przechwytuj `InternalError` z zamiarem dalszego liczenia w tym samym kernelu.

## Własność pamięci, NumPy i DLPack

| Operacja | Kształt i własność |
| --- | --- |
| `to_numpy(stream, fields=None, dtype="float64", first=None, count=None)` | `(rekordy, wartości)`; nowa tablica, kopia wyników silnika |
| `window(stream, fields=..., size=..., stride=1, dtype="float32")` | `(liczba_okien, size, wartości)`; ciągła tablica należąca do `Window` |
| `Window.to_numpy()`, `np.asarray(window)` | Udostępnia tablicę okna bez kolejnej kopii przy zgodnym dtype |
| `torch.from_dlpack(window)` | Współdzieli tę tablicę CPU; nie pamięć silnika |

Kolejność `fields` określa oś wartości; tablice numeryczne są spłaszczane. STRING, INTPAIR i IDXPAIR nie mają gęstej reprezentacji numerycznej. Typy eksportu to `float32`, `float64`, `int32`, `int64`. NULL staje się NaN dla float; dla int NULL, nieskończoność i wynik poza zakresem powodują `ValueError`. Skończone wartości ułamkowe są obcinane w kierunku zera. Projekcja przechodzi przez double, dlatego pełnej dokładności dużych liczb całkowitych szukaj w `Record`, nie w gęstej tablicy.

`size` i `stride` muszą być dodatnie. Dla mniej niż `size` rekordów powstaje `(0, size, wartości)`. Dla N zachowanych rekordów liczba okien wynosi `1 + (N-size)//stride`, gdy N >= size. Okno korzysta z `sliding_window_view`, po czym kopiuje wybrane okna do ciągłej tablicy. Tablice i tensory pozostają ważne po następnych slotach, zamknięciu i zniszczeniu silnika. Zmiana tablicy okna jest widoczna we współdzielącym tensorze, ale nie modyfikuje wyników silnika.

## Urządzenia, PyTorch i wątki

`retractordb.torch.as_tensor(window, device="cpu")` współdzieli pamięć CPU; jawny inny `device` wykonuje transfer i kopię. `StreamDataset(engine, stream, fields=..., window=..., stride=1, dtype=torch.float32, device="cpu")` daje elementy `(size, wartości)`. Każda iteracja odczytuje bieżące wyniki, więc nowe sloty mogą dodać okna do kolejnej epoki.

Używaj `DataLoader(..., num_workers=0)`. Worker jest odrzucany przed dostępem do silnika; `fork` oraz tworzenie Engine w initializerze workera nie należą do kontraktu tego datasetu. Serializuj wszystkie wywołania jednej instancji, również odczyty, właściwości, `compile()` i `close()` podczas `run()`. GIL nie chroni stanu silnika; równoczesna kompilacja lub wykonanie osobnych instancji nie ma ogólnej gwarancji bezpieczeństwa wątkowego.

CPU/DLPack nie przypina buforów silnika i nie zapewnia przypiętej pamięci hosta dla CUDA. Transfer na CUDA jest osobną operacją. MPS odrzuca float64 przed transferem; wybierz float32. Test CPU tej odmowy nie jest odbiorem sprzętowym MPS. Demonstracja Colab T4 z #448 używa CUDA, fp16 i GradScaler; nie stanowi dowodu dla wszystkich urządzeń. DeviceWindowLoader, odbiór MPS i publikacja PyPI pozostają opcjonalnymi dalszymi zadaniami poza epikiem.

## Ograniczenia planu osadzonego

`compile()` odrzuca `DUMP`, `SYSTEM`, `:ROTATION` oraz źródła `DEVICE` jako `CompileError`: wymagają stanu lub fazy wykonania serwisu, których Engine nie ma. Brak pliku wejścia daje opisany wyżej `IOError`. Push ingest z Pythona i cele mobilne nie są dostępne. Pełny serwis oraz jego konfiguracja pozostają domeną `xretractor`.

## Źródła i testy kontraktu

| Obszar | Źródła w repozytorium silnika | Testy w `api/python/tests` |
| --- | --- | --- |
| Plan, EOF, rekompilacja i katalog | `src/embed/engine.cc`, `storageGuard.cc`, `src/python/module.cpp` | `test_engine.py`, C++ `ut_embedEngine` |
| Deskryptory i odczyt offline | `src/python/module.cpp`, `src/rdb/lib/descriptor.cc` | `test_descriptor.py`, `test_storage.py` |
| K1-K7 i powtórne użycie | `src/include/fatalError.hpp`, `src/python/module.cpp` | `test_error_classes.py`, `test_fatal_paths.py`, `test_reentry.py` |
| Kopie, okna i urządzenia | `retractordb/engine.py`, `retractordb/torch.py`, `src/python/module.cpp` | `test_window.py` |
| Izolacja i zgodność logiczna | `src/embed/engine.cc`, `src/retractor/lib/dataModel.cpp` | `test_isolation.py`, `test_reference.py` |

Ścieżki `retractordb/*.py` są względem `api/python/`. Nazwy testów określają pokrycie, nie deklarują wykonania na wszystkich platformach. `test_reference.py` porównuje wspólny zakres z `xretractor -u`, włącznie ze schematem, NULL, metadanymi i logicznym harmonogramem; nie mierzy czasu rzeczywistego. Brak źródła i funkcje tylko serwisowe są poza tym przecięciem. Warunki i wyniki konkretnego odbioru należy zapisać osobno.
