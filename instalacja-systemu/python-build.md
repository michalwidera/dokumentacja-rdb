# Budowanie biblioteki Python

Polecenia wykonuje się w repozytorium `retractordb`. Zwykły build silnika nie buduje rozszerzenia: jawne `RDB_PYTHON=ON` dodaje `_core` i dopiero wtedy wyszukuje Python i nanobind. Linux i macOS są obsługiwanymi hostami; żądanie flagi na innym hoście kończy konfigurację błędem. `RDB_IOS` i `RDB_ANDROID` są jedynie zarezerwowanymi nazwami, bez implementacji. Reguła dla konsumentów osadzonych to: domyślnie OFF, zależności tylko po włączeniu, flaga określa konsumenta, a niewspierany host jest błędem konfiguracji.

## Moduł z drzewa budowy

Potrzebne są zależności [budowy silnika](source-build.md), CPython 3.10+ z nagłówkami oraz nanobind importowalny przez wybrany interpreter. Do powtarzalnych profili Jupyter używaj Python 3.12. Venv zapobiega instalowaniu narzędzi do systemowego Pythona objętego PEP 668:

```bash
scripts/python-venv.sh --python python3.12 --venv .venv-python312
cmake -S . -B build/Debug-Python -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$PWD/build/Debug/generators/conan_toolchain.cmake" \
  -DCMAKE_BUILD_TYPE=Debug -DRDB_PYTHON=ON \
  -DPython_EXECUTABLE="$PWD/.venv-python312/bin/python3"
cmake --build build/Debug-Python --target _core --parallel 4
```

Przykład zakłada istniejący, zgodny build Conan `build/Debug` z toolchainem i zależnościami; nie tworzy samodzielnie profilu Conan. Bez niego najpierw wykonaj procedurę [budowania ze źródeł](source-build.md). Dla istniejącego osobnego `build/Debug-Python` można wyczyścić wykrywanie poprzedniego interpretera:

```bash
cmake -S . -B build/Debug-Python -U '_Python_*' -U nanobind_DIR \
  -DRDB_PYTHON=ON -DPython_EXECUTABLE="$PWD/.venv-python312/bin/python3"
cmake --build build/Debug-Python --target _core --parallel 4
```

Nie uruchamiaj `cmake .` w katalogu głównym repozytorium. Interpreter jest zapisany w cache. Moduł i kopie plików `.py` trafiają do `<build>/python/retractordb`; cache zapisuje ten katalog jako `RDB_PYTHON_MODULE_DIR`. Nie potrzeba `ninja install` do importu z builda. Nanobind używa celów `Python::`, a zwykły moduł `Development.Module`, bez linkowania libpython. W budowaniu abi3 dobierane jest `Development.SABIModule`.

`scripts/python-venv.sh` instaluje nanobind, NumPy, pytest oraz clang-format 21.1.7 i cmakelang. Torch pomija świadomie; pełne [profile Jupyter](python-jupyter.md) przygotowują go oddzielnie. Skrypt jest idempotentny, a `--python`, `--venv`, `--recreate`, `--print-python` wybierają interpreter, katalog, odtworzenie i samą ścieżkę. Próbka `python -m nanobind --cmake_dir` jest wykonywana także przez CMake.

Formatery są wywoływane przez nazwę i wymagają venv na PATH:

```bash
PATH="$PWD/.venv-python312/bin:$PATH" ninja -C build/Debug cformat
```

## Testy i pochodzenie modułu

```bash
RDB_PYTHON_MODULE_DIR="$PWD/build/Debug-Python/python" \
  .venv-python312/bin/python3 -m pytest api/python/tests
```

Bez jawnej zmiennej testy szukają pierwszego posortowanego `build/*/python` zawierającego `_core`; brak modułu oznacza pominięcia. Takie pominięcia nie potwierdzają odbioru. Pełny odbiór #451 potrzebuje również torch i świeżo zbudowanych `xretractor` oraz `xqry`; `RDB_XRETRACTOR` musi wskazać właściwy program. Jawne ustawienie obu zmiennych zamienia brak zależności albo binarki referencyjnej w błąd. Przed wynikiem sprawdź ścieżkę importowanego `_core`, równość kopii pakietu ze źródłem oraz program wybrany w środowisku testu.

`RDB_PYTHON=ON` włącza PIC dla bibliotek statycznych linkowanych do `_core`: `rdb`, `descparser`, `common`, `retractorcore`, `rqlparser` i `rdbembed`. Poza `rdbembed` te same biblioteki wchodzą w skład `xretractor`, `xqry` i `xtrdb`, więc na Linux x86_64 zmienia to również binaria silnika w tym buildzie. Pomiary porównawcze, bramkę badawczą i ablation uruchamiaj w osobnym buildzie z `RDB_PYTHON=OFF`. Na arm64 Darwin PIC nie zmienia tego aspektu kodu.

## Sanitizery

Wybierz osobny build bez `RDB_SANITIZE` do zwykłego Jupyter. Moduł ASan ładowany przez `dlopen` może zakończyć import, jeśli runtime nie został załadowany wcześniej. Do testowania modułu z sanitizerami trzeba go jawnie wstępnie załadować; `asan-build` oznacza istniejący build z sanitizerami:

```bash
# Linux / GCC; Python jest programem C, dlatego potrzebuje także libstdc++.
LD_PRELOAD="$(g++ -print-file-name=libasan.so) $(g++ -print-file-name=libstdc++.so)" \
ASAN_OPTIONS=detect_leaks=0 RDB_PYTHON_MODULE_DIR=asan-build/python \
  .venv-python312/bin/python3 -m pytest api/python/tests

# macOS / Apple clang
DYLD_INSERT_LIBRARIES="$(clang -print-resource-dir)/lib/darwin/libclang_rt.asan_osx_dynamic.dylib" \
ASAN_OPTIONS=detect_container_overflow=0 RDB_PYTHON_MODULE_DIR=asan-build/python \
  .venv-python312/bin/python3 -m pytest api/python/tests
```

Te warianty wyłączają odpowiednio LSan albo kontrolę container-overflow; raport ma wskazywać ten zakres. W testach C++ domyślne wyłączenie container-overflow zapobiega fałszywemu alarmowi przy mieszaniu instrumentowanych wektorów libc++ z niesanitizowanym GoogleTest. Inne kontrole ASan pozostają aktywne; `ASAN_OPTIONS=detect_container_overflow=1` przywraca tę jedną. Zwykły pytest nie zastępuje kontroli pamięci.

## Obraz manylinux i budowanie wheel

`docker/wheel/Dockerfile` rozszerza przypięty obraz PyPA manylinux_2_28: valgrind, venv narzędzi z Conan, CMake >= 4.4.2 i Ninja oraz cache Release w `/opt/conan`. `RDB_USE_MOLD=OFF` wybiera dostępny linker. x86_64 i aarch64 używają tego samego Dockerfile; jego nagłówek podaje digesty baz. Zależności Conan, włącznie z narzędziami, budują się w obrazie, by nie wnosić wymagań nowszego glibc.

```bash
docker build --platform linux/amd64 --build-arg RDB_VERSION="$(cat VERSION)" \
  -f docker/wheel/Dockerfile \
  -t micwide/buildenv-retractordb-wheel:manylinux_2_28_x86_64 .
docker run --rm --platform linux/amd64 -v "$PWD:/src:ro" \
  micwide/buildenv-retractordb-wheel:manylinux_2_28_x86_64 \
  bash /src/docker/wheel/smoke.sh
```

`toolchain-probe.cpp` sprawdza wymagania biblioteki C++23. `audit-so.py` korzysta z `auditwheel show --json`, odrzuca glibc ponad politykę obrazu i biblioteki spoza niej. Kontroluje także brak kodu `bus`, `ipcServer`, `serverName`, `lockManager` i `shmBudget`; mapa linkera uzupełnia kontrolę odartego z symboli modułu Release.

`smoke.sh` kopiuje źródła do kontenera z hostem zamontowanym read-only, sprawdza cache przez `--build never`, buduje `_core`, audytuje go i uruchamia testy Pythona z jawnym pochodzeniem modułu. `jobs.sh` ogranicza równoległość do jednego zadania na 2 GiB, respektując cgroup.

Główny `pyproject.toml` używa scikit-build-core i wersji z `VERSION`, buduje tylko `_core`, instaluje komponent `python` oraz pliki `api/python/retractordb`. NumPy jest zależnością runtime, torch opcjonalną. `api/python/pyproject.toml` pozostaje instalacją klienta bez kompilacji; oba pakiety mają nazwę `retractordb` i zastępują się w jednym venv.

```bash
pipx install cibuildwheel
docker/wheel/build-wheels.sh x86_64
```

Argument może być `aarch64` albo `all`. Skrypt kopiuje checkout bez ignorowanych artefaktów i zapisuje wheel w `build/wheelhouse/`. Używa lokalnie otagowanych obrazów; ich publikacja jest osobną decyzją. Buduje CPython 3.10, 3.11 oraz jedno `cp312-abi3` dla 3.12+. cibuildwheel naprawia tag manylinux, wykonuje `abi3audit --strict` oraz testuje zainstalowane wheel z jawnym `_core` i `RDB_PYTHON_MODULE_DIR`. W tej konfiguracji torch i binarka referencyjna mogą być nieobecne; pominięcia nie są pełnym odbiorem #451.

`EXCLUDE_FROM_ALL` pozostawia `_core` poza zwykłym `ninja install`, a lista komponentów CPack nie zawiera `python`. Budowa wheel nie publikuje na PyPI ani nie wykonuje automatycznie [odbioru Colab](../zalaczniki/notebook-acceptance.md). Wheel macOS, CI publikacji i ingest pozostają odrębnymi etapami.
