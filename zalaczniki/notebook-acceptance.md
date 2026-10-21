# Odbiór notebooków i Colab

## Notebooki i ich smoke test

Trzy notebooki korzystają z aktualnej składni RQL i hierarchii wyjątków ([błędy](python-jupyter-api.md#błędy-i-granica-fatalna)). Wszystkie zapisane w repozytorium komórki mają puste wyjścia.

| Notebook w `api/python/notebooks/` | Przebieg |
|---|---|
| `j0_storage.ipynb` | deskryptor, kopia magazynu, wartości NULL, indeks ujemny i `CorruptDescriptor` z kernelem używalnym po błędzie |
| `j1_engine.ipynb` | `TEXTFILE`, compile/step/run, rekordy, okna NumPy/DLPack, odmowy planu i rekompilacja |
| `colab_quickstart.ipynb` | instalacja wheel, zaszumiony sygnał z `TEXTFILE`, `AVG(v:100)`, okna i pętla treningowa PyTorch |

Notebook Colab porównuje średnią kroczącą z NumPy przed importem PyTorch i ponownie po treningu. Bez torch nadal sprawdza sygnał i okna, a następnie zapisuje pominięcie ML. Z torch trenuje na CUDA, gdy jest dostępna, w przeciwnym razie na CPU. T4 używa fp16 z GradScaler; GPU z natywną obsługą bf16, np. L4/A100, używają bf16. Loss kolejnych epok na CUDA jest porównywany z modelem CPU o tej samej inicjalizacji i tych samych batchach (`rtol=0.05`, `atol=0.002`). Notebook korzysta z istniejącego API `StreamDataset` z `num_workers=0`.

Pierwsza komórka przyjmuje `WHEEL` jako lokalną ścieżkę lub wzorzec glob albo bezpośredni URL HTTPS wheel, a `SOURCE_COMMIT` jako pełne SHA źródła z logu budowy wheel. Wheel można przesłać przez panel Files w Colab albo zmienić obie wartości. Skrypt smoke przekazuje `RDB_WHEEL` i `RDB_SOURCE_COMMIT`. Instalacja używa interpretera kernela i `--no-deps`; wersje NumPy i PyTorch przed instalacją i po niej muszą być takie same. Instalacja, pobranie (jeśli występuje) i import mają osobne pomiary czasu. Żaden próg czasu nie decyduje o wyniku. Ostatnia komórka zapisuje `rdb-acceptance.json`.

Przy pracy lokalnej `RDB_PYTHON_MODULE_DIR` wskazuje we wszystkich trzech notebookach katalog zbudowanego pakietu ([budowanie biblioteki Python](../instalacja-systemu/python-build.md)); interpreter musi być zgodny z rozszerzeniem. Bez tej zmiennej `j0` i `j1` wybierają pierwszy w kolejności sortowania `build/*/python` zawierający rozszerzenie. Notebooki otwiera się z `api/python/notebooks` albo ustawia `RDB_REPO_DIR` na korzeń checkoutu. Skrypt smoke ustawia tę zmienną także w kontenerze z checkoutem tylko do odczytu. `j0` kopiuje wyłącznie fixtures danych, deskryptora i metadanych, pomijając aktualizację shadow, która zastąpiłaby pierwszy rekord.

`docker/wheel/notebook-smoke.sh` wykonuje wszystkie trzy notebooki przez `nbclient`, każdy w osobnym kernelu zarejestrowanym dla wybranego interpretera. Sprawdza ich JSON, odrzuca przestarzałe formy RQL, kończy się błędem przy błędzie komórki i w każdym notebooku sprawdza ścieżkę wybranego `_core`. `pip freeze --all` może zmienić się wyłącznie o dodany `retractordb`. Wyniki obejmują wersje Python/NumPy/PyTorch, nazwę pliku wheel, SHA źródła (podane z logu budowy), SHA-256 wheel, czasy instalacji i importu, czasy komórek, asercje NumPy oraz pomiary epok. Okna/s i średni czas kroku obejmują DataLoader, transfer na urządzenie i optymalizator; postęp silnika i trening referencyjny CPU są mierzone osobno. Pierwsza epoka obejmuje rozgrzewkę. Pomiary opisują tę demonstrację, a nie ogólną wydajność silnika.

Profil wheel tworzy czysty venv Python 3.12 z wersjami z `scripts/notebook-versions.sh`. Domyślny torch to wariant CPU. Te przypięte lokalne zależności nie deklarują bieżących wersji runtime Colab. Jawny profil `--without-torch` pomija torch i sprawdza, że pominięcie ML przebiegło poprawnie. Każdy profil potrzebuje osobnego katalogu wyników; wykonane notebooki i `acceptance.json` pozostają w nim po usunięciu tymczasowego venv. Bez `--output-dir` skrypt wypisuje zachowany katalog tymczasowy z wynikami.

### Ręczna kontrola wydania

Ten krok wykonuje się po zbudowaniu bieżącego wheel ([budowanie wheel](../instalacja-systemu/python-build.md)), przed przekazaniem go użytkownikowi Colab lub dystrybucją. Oba profile zainstalowanego wheel muszą przejść; sam smoke modułu z builda nie spełnia kontroli wydania. Log budowy wheel należy zachować razem z raportem, aby SHA źródła było możliwe do prześledzenia. Build musi pochodzić z wskazanego commita; niezacommitowane zmiany wpływające na wheel trzeba zapisać, a przed wydaniem przebudować artefakt po przeglądzie i commicie.

```bash
# Pełne SHA z logu budowy wheel, nie przypuszczenie na podstawie starego wheel.
SOURCE_COMMIT="paste-full-source-SHA-from-build-log"
mkdir -p build/notebook-results/with-torch build/notebook-results/without-torch

docker run --rm -v "$PWD:/src:ro" -v "$PWD/build/notebook-results/with-torch:/results" \
  python:3.12-slim bash /src/docker/wheel/notebook-smoke.sh \
  --source-commit "$SOURCE_COMMIT" --output-dir /results

docker run --rm -v "$PWD:/src:ro" -v "$PWD/build/notebook-results/without-torch:/results" \
  python:3.12-slim bash /src/docker/wheel/notebook-smoke.sh \
  --source-commit "$SOURCE_COMMIT" --without-torch --output-dir /results
```

Bez argumentu wheel w `build/wheelhouse/` musi być dokładnie jeden cp312-abi3 dla architektury hosta. Inny artefakt wybiera się jawnym plikiem lub URL HTTPS. `PYTHON` wybiera inny interpreter Python 3.12. `RDB_TORCH_INDEX` nadpisuje indeks CPU; `RDB_TORCH_INDEX=` (pusta wartość) rozwiązuje wersję wheel CPU z PyPI.

Kontrola modułu z builda wymaga istniejącego zgodnego interpretera z NumPy, `nbclient`, `nbformat` i `ipykernel` oraz torch, chyba że ustawiono `--without-torch`:

```bash
PYTHON="$PWD/.venv-jupyter-system-cpu/bin/rdb-python" \
  docker/wheel/notebook-smoke.sh --module-dir build/Debug-Python/python \
  --output-dir build/notebook-results/local-module
```

Ten profil niczego nie instaluje i nie mierzy instalacji wheel. Odbiór w rzeczywistym Colab CPU/GPU jest osobnym przebiegiem wykonywanym przez człowieka według [protokołu poniżej](#rzeczywisty-colab-cpu-następnie-gpu). Jego datę, runtime i wynik obserwacji restartu raportuje się osobno od wyników kontenera.

## Odbiór w kontenerze i w Google Colab

Protokół obejmuje gotowy wheel z pliku albo bezpośredniego URL HTTPS. Przebieg w kontenerze jest dowodem dla zainstalowanego wheel; odbiór w rzeczywistym Colab wymaga osobnych przebiegów CPU i GPU wykonanych przez człowieka. Ten protokół nie deklaruje żadnego wyniku z Colab.

## Przygotowanie artefaktu

1. Zbuduj wheel Linux x86_64 z zamierzonej rewizji źródeł przez `docker/wheel/build-wheels.sh x86_64`. Zachowaj pełne SHA źródła i log budowy. Zapisz niezacommitowane zmiany wpływające na wheel; przed dystrybucją przebuduj z przejrzanego commita. Dla Python 3.12+ użyj naprawionego wheel cp312-abi3.
2. Zapisz jego nazwę pliku i `sha256sum build/wheelhouse/<nazwa-wheel>.whl`. Ten sam wheel służy do odbioru w kontenerze i w Colab; nie starszy plik o tej samej wersji i nazwie.
3. Uruchom oba profile zainstalowanego wheel w kontenerze z [ręcznej kontroli wydania](#ręczna-kontrola-wydania). Zachowaj każdy `acceptance.json` i trzy wykonane notebooki. Wymagaj `notebook-smoke: OK - 3/3 notebooks`; profil bez torch musi zapisać `training.status = skipped` i udane asercje NumPy. Profil domyślny musi zapisać udany trening CPU. Porównaj SHA-256 wheel z krokiem 2.

## Rzeczywisty Colab: CPU, następnie GPU

Każdy przebieg wykonuje się w świeżym runtime. Lokalne wykonanie notebooka ani kontener nazwany jak Colab nie kończą tego kroku.

1. Prześlij `api/python/notebooks/colab_quickstart.ipynb` przez okno przesyłania notebooka w Colab. Użyj notebooka z tej samej rewizji źródeł co sprawdzany wheel.
2. W pierwszym przebiegu wybierz runtime CPU. Prześlij wheel przez panel Files do `/content/` albo ustaw `WHEEL` w pierwszej komórce kodu na bezpośredni URL HTTPS. Ścieżka URL musi zawierać oryginalną nazwę pliku wheel; podpisany query string jest dopuszczalny. Ustaw `SOURCE_COMMIT` na pełne SHA zapisane przez build.
3. Uruchom wszystkie komórki bez ręcznej instalacji lub podmiany NumPy i torch. Notebook instaluje wyłącznie `retractordb` z `--no-deps`. Zachowaj wersje przed/po z pierwszej komórki, osobne czasy pobrania, instalacji i importu oraz ścieżkę `_core`. Porównaj zgłoszone SHA-256 wheel z przygotowanym artefaktem.
4. Wymagaj ukończenia obu asercji NumPy i komórki treningu. Rzeczywisty runtime Colab z torch musi trenować; niespodziewane pominięcie ML nie jest odbiorem CPU/GPU. Opcjonalną ścieżkę bez torch pokrywa osobno kontener.
5. Pobierz `rdb-acceptance.json` i wykonany notebook. Zapisz wersję i datę runtime Colab, wybór CPU lub GPU oraz to, czy Colab rzeczywiście wymagał restartu. `restart_performed=false` opisuje wykonanie notebooka bez przerwy; `restart_required=null` celowo wymaga obserwacji człowieka. Nie zamieniaj tej nieznanej wartości na udowodniony brak restartu bez obserwacji przebiegu. Jeśli restart był wymagany, zachowaj wyjście sprzed restartu i jego powód, a następnie osobno zapisz ukończony przebieg po restarcie.
6. Powtórz w świeżym runtime GPU (np. T4). Wymagaj `training.device = cuda`, rzeczywistej nazwy GPU, przepustowości epok i czasów kroku oraz zgodności loss z referencją CPU. Fallback na CPU nie jest odbiorem GPU. T4 powinien zgłosić `torch.float16` z włączonym GradScaler; L4/A100 natywne `torch.bfloat16` bez skalowania fp16. Zapisz to, co przydzielony runtime faktycznie udostępnia, łącznie z wersjami torch i CUDA.

Model otrzymuje kopie okien CPU ze `StreamDataset`, z `num_workers=0`. CUDA to osobny transfer na urządzenie. Implementacja korzysta z [API AMP PyTorch](https://docs.pytorch.org/docs/stable/amp.html): skalowanie gradientu przy fp16 oraz bf16, gdy runtime zgłasza jego natywną obsługę. Pomiar czasu epok używa [synchronizacji CUDA](https://docs.pytorch.org/docs/stable/generated/torch.cuda.synchronize.html).

Okna/s = przetworzone okna / sekundy pętli treningowej. Średni czas kroku = ten sam czas / liczba batchy. Obie miary obejmują ładowanie, transfery i optymalizację; postęp silnika i trening referencyjny CPU są raportowane osobno. Pierwsza epoka obejmuje rozgrzewkę. Zapisz wszystkie epoki; nie podawaj samej najszybszej jako wyniku. Ten mały model jest demonstracją, a nie ogólnym benchmarkiem silnika. Porównanie loss CUDA i CPU używa tej samej inicjalizacji, kolejności danych i parametrów SGD, z `rtol=0.05, atol=0.002`. Niespełniona asercja oznacza nieudany przebieg.

Zapisz warunki: przesłanie pliku czy URL, czas pobrania, zimny czy ciepły runtime, wersję Pythona, typ CPU/GPU i to, czy cache pakietów był już wypełniony. Czasy porównuj tylko w porównywalnych warunkach; instalacja w kontenerze nie mierzy Colab.
