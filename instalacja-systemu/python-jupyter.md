# Python i Jupyter

Biblioteka osadzona wykonuje RQL wewnątrz Pythona, bez demona. Jej [kontrakt API](../zalaczniki/python-jupyter-api.md) obejmuje czas logiczny, a nie pracę w czasie rzeczywistym. Do czytania strumieni serwisu służy osobny [klient monitorowania](../zalaczniki/api-monitorowania-strumieni.md).

## Gotowy wheel

Użyj jawnie dostarczonego pliku `.whl` albo jego bezpośredniego URL HTTPS. Publikacja na PyPI jest osobnym zadaniem; ta instrukcja nie zakłada dostępności pakietu przez `pip install retractordb` ani istnienia wheel dla macOS. Linux x86_64 obejmuje WSL2. Nazwa pliku musi odpowiadać architekturze i ABI Pythona: `cp312-abi3` jest dla CPython 3.12 i nowszych, a `cp310`/`cp311` dla odpowiedniej wersji. Proces budowania przewiduje także aarch64; dostępność i wykonanie konkretnego artefaktu trzeba potwierdzić na tej architekturze.

Po pobraniu wheel zachowaj jego pełną nazwę, SHA-256 i SHA źródła podany przez dostawcę. Sprawdź sumę przed instalacją. Poniższe polecenia wykonuje się w katalogu własnego projektu; `RDB_WHEEL` wskazuje rzeczywiście pobrany plik:

```bash
python3.12 -m venv .venv-rdb
.venv-rdb/bin/python -m pip install 'numpy>=1.23' ipykernel
RDB_WHEEL="/sciezka/do/retractordb-0.1.11-cp312-abi3-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl"
sha256sum "$RDB_WHEEL"
.venv-rdb/bin/python -m pip install --no-deps "$RDB_WHEEL"
.venv-rdb/bin/python -c 'import retractordb._core; print(retractordb._core.__file__)'
.venv-rdb/bin/python -m pip check
```

Zamiast ścieżki można przypisać do `RDB_WHEEL` bezpośredni URL HTTPS dostarczonego wheel. Ścieżka URL musi zachować oryginalną nazwę pliku; parametry podpisanego URL są dopuszczalne. `--no-deps` wymaga wcześniej przygotowanego NumPy; nie instaluje ani nie podmienia PyTorch. Nie publikuj sekretów podpisanego URL w raportach. Polecenie importu potwierdza obecność rozszerzenia, a nie tylko czystego klienta.

PyTorch instaluj zgodnie z własnym CPU/CUDA. Nie jest wymagany do wykonania planu, NumPy ani DLPack. W interpreterze lub kernelu używającym tego środowiska uruchom [kompletny przykład API](../zalaczniki/python-jupyter-api.md#kompletny-przykład).

## Kernel Jupyter

Kernel i rozszerzenie muszą używać zgodnej wersji Pythona. Można jawnie zarejestrować kernel własnego środowiska:

```bash
.venv-rdb/bin/python -m ipykernel install --user --name retractordb-wheel --display-name 'RetractorDB wheel'
```

W Jupyter wybierz „RetractorDB wheel”. Rejestracja powyżej jest świadomą zmianą konfiguracji użytkownika; skrypt lokalnych profili poniżej umieszcza kernel we własnym venv zamiast rejestrować go globalnie. Notebooki w repozytorium kodu to `api/python/notebooks/j0_storage.ipynb`, `j1_engine.ipynb` i `colab_quickstart.ipynb`.

## Google Colab

W nowym runtime wczytaj `colab_quickstart.ipynb`, prześlij wheel przez panel Files do `/content/` i ustaw `WHEEL` w pierwszej komórce na ścieżkę albo bezpośredni URL. Ustaw także `SOURCE_COMMIT` na pełne SHA podane w logu budowy. Notebook instaluje samo wheel z `--no-deps`, porównuje wersje NumPy/torch przed i po, mierzy osobno pobranie, instalację i import oraz zapisuje `rdb-acceptance.json`.

Asercje NumPy sprawdzają sygnał przed i po treningu. Bez torch komórki ML jawnie pomijają trening; z torch używają CUDA, gdy jest dostępna, albo CPU. T4 używa fp16 z GradScaler; natywne bf16 jest wybierane, gdy runtime zgłasza jego obsługę. Nie zakładaj, że dowolny GPU został odebrany. Wersje i konieczność restartu obserwuje się w danym runtime; lokalny kontener nie potwierdza zachowania Colaba. Pełny [protokół odbioru](../zalaczniki/notebook-acceptance.md) oddziela oba rodzaje dowodów.

## Lokalne profile Jupyter i PyTorch

W repozytorium kodu `scripts/jupyter-env.sh` tworzy trwałe, izolowane środowiska dla zainstalowanego Python 3.12. Potrzebuje już zbudowanego zgodnego `_core` albo wheel; nie kompiluje silnika, nie instaluje do systemowego Pythona i nie zmienia `~/.local/bin` ani PATH wywołującej powłoki. Dla modułu lokalnego przygotuj [osobny build Python](python-build.md).

```bash
scripts/jupyter-env.sh system
.venv-jupyter-system-cpu/bin/rdb-python -m pytest api/python/tests -ra
PYTHON="$PWD/.venv-jupyter-system-cpu/bin/rdb-python" \
  docker/wheel/notebook-smoke.sh --module-dir build/Debug-Python/python

scripts/jupyter-env.sh user
.venv-jupyter-user-cpu/bin/rdb-jupyter api/python/notebooks

scripts/jupyter-env.sh user --wheel \
  build/wheelhouse/retractordb-0.1.11-cp312-abi3-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl \
  --venv .venv-jupyter-wheel
.venv-jupyter-wheel/bin/rdb-jupyter api/python/notebooks
```

W profilu użytkownika wybierz „RetractorDB (user, cpu)”. `rdb-python` i kernel używają jawnego katalogu modułu i sprawdzają rzeczywistą ścieżkę `_core`. Profil modułu importuje go z builda bez kopiowania do site-packages; profil wheel instaluje do swojego venv i przekazuje jego ścieżkę do komórki notebooka.

Opcje `--module-dir`, `--python`, `--venv` wskazują moduł, interpreter i środowisko. Istniejący venv także musi mieć Python 3.12. Ponowne uruchomienie odświeża zależności i kernel; osobne moduły i backendy torch powinny mieć osobne venv. Aktywacja powłoki nie jest potrzebna.

Wersje powtarzalnego lokalnego profilu określa `scripts/notebook-versions.sh`: Python 3.12, NumPy 2.0.2, nanobind, pytest, nbclient, nbformat i ipykernel. Linux używa torch 2.11.0+cpu z indeksu CPU, profil użytkownika także JupyterLab. Nie są to deklaracje bieżących wersji Colaba. Instalator sprawdza `pip check`, pochodzenie `_core` i współdzielenie DLPack, mierzy czas i rozmiar venv oraz zapisuje `requirements-resolved.txt`.

| Platforma | Profil i zakres |
| --- | --- |
| Linux x86_64 / WSL2 | Domyślny CPU; główna platforma weryfikacji |
| Linux aarch64 | Instalator obsługuje CPU; wykonanie wymaga dowodu na tym hoście |
| macOS arm64, macOS 14+ | Domyślny profil MPS, torch 2.14.1 z PyPI; wymagany lokalny build, dopóki nie ma wheel macOS |
| Linux CUDA | Jawne `--torch cuda`, torch 2.11.0+cu128; kontrola pakietu bez GPU nie potwierdza obliczeń na GPU |

Na macOS launchery trafiają do `.venv-jupyter-user-mps` i `.venv-jupyter-system-mps`. Setup sprawdza obecność obsługi MPS w torch, ale nie wymaga dostępnego urządzenia MPS. Sam guard float64 nie jest odbiorem sprzętowym.

Opcjonalny profil pakietu CUDA pobiera kilka GB i pozostaje poza domyślnym profilem CPU. Nie potrzebuje GPU ani sterownika i nie weryfikuje obliczeń CUDA:

```bash
CUDA_VISIBLE_DEVICES='' scripts/jupyter-env.sh system --torch cuda
CUDA_VISIBLE_DEVICES='' .venv-jupyter-system-cuda/bin/rdb-python -m pytest api/python/tests -ra
CUDA_VISIBLE_DEVICES='' PYTHON="$PWD/.venv-jupyter-system-cuda/bin/rdb-python" \
  docker/wheel/notebook-smoke.sh --module-dir build/Debug-Python/python
```
