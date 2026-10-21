# Python i Jupyter

Biblioteka osadzona wykonuje RQL wewnątrz Pythona, bez demona. Jej [kontrakt API](../zalaczniki/python-jupyter-api.md) obejmuje czas logiczny, a nie pracę w czasie rzeczywistym. Do czytania strumieni serwisu służy osobny [klient monitorowania](../zalaczniki/api-monitorowania-strumieni.md).

## Instalacja z PyPI

Pakiet [`retractordb` jest opublikowany na PyPI](https://pypi.org/project/retractordb/). Wydanie [v0.1.12](https://github.com/michalwidera/retractordb/releases/tag/v0.1.12) udostępnia gotowe koła Pythona zarówno na PyPI, jak i w GitHub Releases. Instalacja `pip install retractordb` pobiera pakiet z biblioteką osadzoną `retractordb._core`; nie wymaga lokalnej kompilacji silnika ani uruchamiania serwisu. [Strona projektu](https://retractordb.com/pl/) zawiera wprowadzenie do RetractorDB, a [instalator systemowy](https://retractordb.com/pl/install/) służy do instalacji osobnych programów CLI i serwisu.

Poniższy przykład przypina wersję `0.1.12` i tworzy środowisko w katalogu własnego projektu. `--only-binary=retractordb` wymaga gotowego koła zamiast próby budowania silnika ze źródeł:

```bash
python3.12 -m venv .venv-rdb
.venv-rdb/bin/python -m pip install --upgrade pip
.venv-rdb/bin/python -m pip install --only-binary=retractordb 'retractordb==0.1.12' jupyterlab ipykernel
.venv-rdb/bin/python -c 'import retractordb._core; print(retractordb._core.__file__)'
.venv-rdb/bin/python -m pip check
```

`pip` wybiera koło pasujące do interpretera i platformy oraz instaluje NumPy (`numpy>=1.23`). PyTorch jest opcjonalny i nie jest instalowany domyślnie. Polecenie importu potwierdza obecność rozszerzenia, a nie tylko czystego klienta monitorowania.

W wydaniu `0.1.12` opublikowano sześć kół:

| Platforma | Minimalna glibc | Warianty CPython |
| --- | --- | --- |
| Linux x86_64, także WSL2 | 2.27 | 3.10 (`cp310-cp310`), 3.11 (`cp311-cp311`), 3.12+ (`cp312-abi3`) |
| Linux aarch64 / ARM64 | 2.26 | 3.10 (`cp310-cp310`), 3.11 (`cp311-cp311`), 3.12+ (`cp312-abi3`) |

Koła `abi3` są przeznaczone dla CPython 3.12 i nowszych ze standardowym GIL. Dla CPython 3.10 lub 3.11 zastąp `python3.12` odpowiednim interpreterem; lokalne profile opisane niżej nadal wymagają 3.12. To wydanie nie zawiera kół macOS, natywnego Windows ani musllinux. Na macOS przygotuj [lokalny build](python-build.md), a na Windows użyj Linuksa w WSL2. Dostępność koła ARM64 nie jest potwierdzeniem wykonania na danym urządzeniu.

PyTorch instaluj zgodnie z własnym CPU/CUDA. Nie jest wymagany do wykonania planu, NumPy ani DLPack. W interpreterze lub kernelu używającym tego środowiska uruchom [kompletny przykład API](../zalaczniki/python-jupyter-api.md#kompletny-przykład).

## Gotowy wheel z GitHub Releases

Alternatywnie pobierz plik `.whl` z [wydania v0.1.12](https://github.com/michalwidera/retractordb/releases/tag/v0.1.12) albo z sekcji plików na PyPI. Zachowaj pełną nazwę, SHA-256 i informację o rewizji źródeł z procesu budowy. Koła tego wydania na GitHub i PyPI mają te same nazwy i sumy SHA-256.

Przykład dla Linux x86_64 i CPython 3.12+ pobiera konkretne koło i sprawdza jego opublikowaną sumę. Wykonaj go w katalogu własnego projektu; jeśli nie masz jeszcze środowiska, utwórz je poniższymi poleceniami:

```bash
python3.12 -m venv .venv-rdb
.venv-rdb/bin/python -m pip install 'numpy>=1.23' jupyterlab ipykernel
RDB_WHEEL="retractordb-0.1.12-cp312-abi3-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl"
curl -fLO "https://github.com/michalwidera/retractordb/releases/download/v0.1.12/$RDB_WHEEL"
printf '%s  %s\n' \
  '511ca1401d9d0e268dd99f8ecfadbeb1e6f8c96ffce141c1a69891e87cffd287' "$RDB_WHEEL" \
  | sha256sum --check
.venv-rdb/bin/python -m pip install --no-deps "$RDB_WHEEL"
.venv-rdb/bin/python -c 'import retractordb._core; print(retractordb._core.__file__)'
.venv-rdb/bin/python -m pip check
```

Inny plik `.whl` wymaga własnej sumy z GitHub Releases lub PyPI. `--no-deps` wymaga wcześniej przygotowanego NumPy; nie instaluje ani nie podmienia PyTorch. Można też instalować bezpośrednio z URL HTTPS zawierającego oryginalną nazwę koła, ale wtedy sumę należy sprawdzić osobno po pobraniu.

`pip install ./api/python` w repozytorium kodu instaluje tylko klienta monitorowania i może zastąpić pakiet zawierający `_core`. Używaj do tego osobnego środowiska.

## Kernel Jupyter

Kernel i rozszerzenie muszą używać zgodnej wersji Pythona. Można jawnie zarejestrować kernel własnego środowiska:

```bash
.venv-rdb/bin/python -m ipykernel install --user --name retractordb-wheel --display-name 'RetractorDB wheel'
.venv-rdb/bin/jupyter lab
```

W Jupyter wybierz „RetractorDB wheel”. Rejestracja powyżej jest świadomą zmianą konfiguracji użytkownika; skrypt lokalnych profili poniżej umieszcza kernel we własnym venv zamiast rejestrować go globalnie. Notebooki w repozytorium kodu to [`j0_storage.ipynb`](https://github.com/michalwidera/retractordb/blob/v0.1.12/api/python/notebooks/j0_storage.ipynb), [`j1_engine.ipynb`](https://github.com/michalwidera/retractordb/blob/v0.1.12/api/python/notebooks/j1_engine.ipynb) i [`colab_quickstart.ipynb`](https://github.com/michalwidera/retractordb/blob/v0.1.12/api/python/notebooks/colab_quickstart.ipynb).

## Google Colab

Do zwykłej instalacji pakietu w nowym runtime wystarczy komórka:

```python
%pip install --only-binary=retractordb retractordb==0.1.12
import retractordb._core
print(retractordb._core.__file__)
```

Pełny [`colab_quickstart.ipynb` otwórz w Colabie](https://colab.research.google.com/github/michalwidera/retractordb/blob/v0.1.12/api/python/notebooks/colab_quickstart.ipynb). Jego komórka instalacyjna nadal wymaga pliku `.whl` albo bezpośredniego URL, nie nazwy pakietu PyPI. Pobierz zgodne koło z wydania `v0.1.12`, prześlij je przez panel Files do `/content/` i ustaw `WHEEL` w pierwszej komórce kodu na ścieżkę; możesz też podać URL koła z GitHub Releases. Ustaw także `SOURCE_COMMIT` na pełne SHA podane w logu budowy. Notebook instaluje samo koło z `--no-deps`, porównuje wersje NumPy/torch przed i po, mierzy osobno pobranie, instalację i import oraz zapisuje `rdb-acceptance.json`.

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
  build/wheelhouse/retractordb-0.1.12-cp312-abi3-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl \
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
