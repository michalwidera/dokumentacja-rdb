# Budowanie produkcyjne i warianty badawcze

Skrypt `scripts/buildrdb.sh` rozdziela budowanie produkcyjne od kompilacji
wykorzystywanych w badaniach optymalizatora i pomiarach wydajności. Rozdzielenie
obejmuje konfigurację CMake, katalogi wynikowe, generatory Conan oraz kontrolę
gotowej binarki.

> **⚠️ Ostrzeżenie**
>
> Binarki z `release-ablation` i `probe` są artefaktami badawczymi. Nie należy
> ich instalować ani pakować jako wydania produkcyjne.

## Tryby budowania

| Polecenie | Przeznaczenie | Katalog binarny |
| --- | --- | --- |
| `scripts/buildrdb.sh release` | zweryfikowane wydanie produkcyjne | `build/Release` |
| `scripts/buildrdb.sh release-ablation` | wybrana konfiguracja optymalizatora i sondy | `build/Release-Ablation/<konfiguracja>` |
| `scripts/buildrdb.sh probe` | pomiary z włączoną sondą | `build/Release-Probe` |

Tryby badawcze korzystają również z osobnych katalogów generatorów Conan:

- `build/Conan-Release-Ablation/<konfiguracja>`,
- `build/Conan-Release-Probe`.

Dzięki temu ich cache CMake, definicje kompilatora i binaria nie są zapisywane
w produkcyjnym `build/Release`.

## Kontrakt produkcyjnego `release`

Polecenie:

```bash
scripts/buildrdb.sh release
```

działa w trybie *fail closed*: każda niespełniona kontrola przerywa budowanie.
Skrypt:

1. wymaga repozytorium Git oraz całkowicie czystego drzewa roboczego;
2. odrzuca zmiany śledzone, staged i pliki nieśledzone;
3. usuwa poprzedni katalog `build/Release`;
4. usuwa z procesu konfiguracji typowe zmienne pozwalające wstrzyknąć flagi
   kompilatora, linkera lub CMake;
5. jawnie przekazuje pełną konfigurację produkcyjną;
6. buduje binarkę w świeżym katalogu;
7. odczytuje konfigurację z gotowego `xretractor`;
8. ponownie sprawdza czystość drzewa źródeł.

Zmienne usuwane ze środowiska procesu budowania to między innymi `CFLAGS`,
`CPPFLAGS`, `CXXFLAGS`, `LDFLAGS`, `CMAKE_ARGS`, `CMAKE_GENERATOR` oraz
`CMAKE_TOOLCHAIN_FILE`. Zmienne uruchomieniowe sondy `RDB_BENCH_CSV` i
`RDB_BENCH_PLAN` również nie są przekazywane.

Konfiguracja produkcyjna jest zawsze następująca:

```text
RDB_OPT_DEDUP_SUBSTRATES=ON
RDB_OPT_SHARE_EQUIVALENT_SELECTS=ON
RDB_OPT_COMMUTATIVE_ADD=ON
RDB_OPT_FACTOR_MATCHED_HASH_TIMEMOVES=ON
RDB_BENCH_PROBE=OFF
```

Po kompilacji skrypt wykonuje:

```bash
build/Release/src/retractor/xretractor --optimizer-build-info
```

i porównuje wynik z powyższym zestawem. Brak binarki albo choć jedna inna
wartość kończy `release` błędem.

> **ℹ️ Info**
>
> Kontrola czystości Git dowodzi, że budowanie nie korzysta z lokalnych,
> niezatwierdzonych zmian. Nie dowodzi poprawności zawartości zatwierdzonego
> commitu. Za tę część odpowiadają przegląd zmian, testy i CI.

## Warianty ablacyjne

Polecenie:

```bash
scripts/buildrdb.sh release-ablation
```

otwiera podmenu pozwalające niezależnie przełączać:

```text
RDB_OPT_DEDUP_SUBSTRATES
RDB_OPT_SHARE_EQUIVALENT_SELECTS
RDB_OPT_COMMUTATIVE_ADD
RDB_OPT_FACTOR_MATCHED_HASH_TIMEMOVES
RDB_BENCH_PROBE
```

Każdy wariant otrzymuje katalog opisujący pełną konfigurację, na przykład:

```text
build/Release-Ablation/dedup-OFF_share-ON_comm-ON_factor-ON_probe-OFF
```

Wartości wszystkich pięciu przełączników są przekazywane jawnie. Zapobiega to
dziedziczeniu wartości zapisanych przez wcześniejszą konfigurację w
`CMakeCache.txt`.

Konfiguracja:

```text
RDB_OPT_SHARE_EQUIVALENT_SELECTS=OFF
RDB_OPT_COMMUTATIVE_ADD=ON
```

jest niedozwolona. Kanonizacja przemiennego dodawania jest częścią
współdzielenia równoważnych obliczeń `SELECT`, dlatego podmenu i CMake odrzucają
takie połączenie.

Po zbudowaniu wariantu skrypt porównuje `--optimizer-build-info` z wartościami
wybranymi w podmenu. Niezgodność jest błędem konfiguracji, a nie wynikiem
badania ablacyjnego.

## Sonda pomiarowa

`RDB_BENCH_PROBE` jest instrumentacją pomiarową, a nie optymalizacją planu.
Polecenie:

```bash
scripts/buildrdb.sh probe
```

buduje wariant ze wszystkimi optymalizacjami włączonymi oraz:

```text
RDB_BENCH_PROBE=ON
```

Binarka trafia do `build/Release-Probe`. Sonda jest przeznaczona do pomiarów
wykonywanych na zoptymalizowanym kodzie `Release`, ale nie jest binarką
produkcyjną.

W `release-ablation` sondę można włączyć albo wyłączyć niezależnie od poprawnej
konfiguracji optymalizatora. Pozwala to porównać te same warianty zarówno bez
instrumentacji, jak i z instrumentacją.

Analiza kodu potwierdza, że sonda nie zmienia wyboru, kolejności ani wyniku
przebiegów optymalizatora. Nie jest jednak instrumentacją o zerowym koszcie:
`RDB_BENCH_PLAN` dodatkowo przegląda plan i zapisuje statystyki, a
`RDB_BENCH_CSV` wykonuje pomiary zegara i operacje plikowe. Sonda jest więc
semantycznie nieinwazyjna, ale jej narzut może wpływać na mierzone czasy.

## Ręczna kontrola wariantu

Każdy `xretractor` udostępnia:

```bash
ścieżka/do/xretractor --optimizer-build-info
```

Polecenie wypisuje konfigurację i kończy działanie bez uruchamiania silnika.
Przykładowy wynik wariantu produkcyjnego:

```text
RDB_OPT_DEDUP_SUBSTRATES=ON
RDB_OPT_SHARE_EQUIVALENT_SELECTS=ON
RDB_OPT_COMMUTATIVE_ADD=ON
RDB_OPT_FACTOR_MATCHED_HASH_TIMEMOVES=ON
RDB_BENCH_PROBE=OFF
```

Nazwa katalogu jest pomocna przy organizacji eksperymentów, ale informacja z
binarki jest ostatecznym potwierdzeniem użytych definicji kompilatora.

## Testy w procesie ablacji

Wyłączenie optymalizacji może celowo zmienić strukturę planu, prefiks wyniku
albo zachowanie znanego przypadku wykonawczego. Taki wynik nie powinien być
automatycznie uznawany za niezwiązaną regresję.

CTest przypisuje testom wymagającym konkretnej optymalizacji etykiety
`requires_*` i może je wyłączyć dla niezgodnej konfiguracji. Znane, potwierdzone
różnice zachowania otrzymują etykietę `expected_ablation_failure`; test może
być oznaczony właściwością `WILL_FAIL`.

Procedura oceny błędu powinna być następująca:

1. uruchomić ten sam test w konfiguracji produkcyjnej;
2. potwierdzić, że przechodzi z wymaganymi optymalizacjami;
3. uruchomić go w badanym wariancie;
4. wykazać związek błędu z wyłączonym przełącznikiem;
5. dopiero wtedy zapisać wynik jako oczekiwaną różnicę ablacyjną albo wyłączyć
   test dla tego wariantu;
6. każdy inny błąd traktować jako regresję.

Test `it_optimizer_ablation-build-info` kontroluje zgodność informacji
raportowanej przez binarkę z konfiguracją CMake. Pozostałe testy
`it_optimizer_ablation-*` sprawdzają strukturę planów i porównania semantyczne
między wariantami.

### Macierz wyników względem konfiguracji bez ablacji

Punktem odniesienia jest konfiguracja bez ablacji: wszystkie cztery
optymalizacje są włączone, a sonda jest wyłączona. Dokumentacja nie zapisuje
bezwzględnej liczby testów, ponieważ zestaw testowy może się zmieniać.

Skróty w tabeli oznaczają:

- `D` — deduplikację substratów;
- `S` — współdzielenie równoważnych obliczeń `SELECT`;
- `C` — kanonizację przemiennego dodawania;
- `F` — faktoryzację dopasowanych przesunięć hash/czas.

Kolumna „Δ sukcesów (oczekiwane/rzeczywiste)” podaje dwie różnice względem
konfiguracji bez ablacji:

- pierwsza liczba jest zmianą oczekiwaną na podstawie właściwości `DISABLED`
  i `WILL_FAIL`;
- druga liczba jest zmianą zaobserwowaną podczas pełnego uruchomienia CTest.

Przykładowo `-2/-2` oznacza dwa oczekiwane i dwa faktycznie odnotowane sukcesy
mniej, a `+1/+1` — jeden sukces więcej. Niezgodność, na przykład `-2/-3`,
oznaczałaby jeden nieoczekiwany błąd. Test z właściwością `WILL_FAIL` nadal
jest sukcesem CTest, jeżeli polecenie kończy się oczekiwanym błędem.

| Aktywne | Wariant | D | S | C | F | Δ sukcesów (oczekiwane/rzeczywiste) |
| ---: | --- | :---: | :---: | :---: | :---: | ---: |
| 0 | `all_off` | OFF | OFF | OFF | OFF | -9/-9 |
| 1 | `dedup_only` | ON | OFF | OFF | OFF | -4/-4 |
| 1 | `share_only` | OFF | ON | OFF | OFF | -9/-9 |
| 1 | `factor_only` | OFF | OFF | OFF | ON | -6/-6 |
| 2 | `dedup_share` | ON | ON | OFF | OFF | -4/-4 |
| 2 | `dedup_factor` | ON | OFF | OFF | ON | -1/-1 |
| 2 | `share_comm` | OFF | ON | ON | OFF | -8/-8 |
| 2 | `share_factor` | OFF | ON | OFF | ON | -6/-6 |
| 3 | `dedup_share_comm` | ON | ON | ON | OFF | -3/-3 |
| 3 | `dedup_share_factor` | ON | ON | OFF | ON | -1/-1 |
| 3 | `share_comm_factor` | OFF | ON | ON | ON | -5/-5 |
| 4 | `all_on` | ON | ON | ON | ON | 0/0 |

Każdy zaobserwowany wynik jest zgodny z oczekiwaniem. Różnice wynikają z
rozłącznych wymagań testów: wyłączenie `D` usuwa pięć sukcesów, wyłączenie `F`
usuwa trzy, a brak jednocześnie aktywnych `S` i `C` usuwa jeden. Dlatego
wartości można sumować bez odnoszenia ich do stałej liczebności zestawu
testowego.

Znane różnice wykonawcze oznaczone `WILL_FAIL` nie zmieniają liczby sukcesów:
bez `F` oczekiwany jest odmienny wynik przypadku faktoryzacji, natomiast przy
jednoczesnym wyłączeniu `D`, `F` i `S` oczekiwany jest dodatkowy zerowy rekord
prefiksu.

## Pakowanie

Pakiety produkcyjne należy przygotowywać dopiero po poprawnym, zweryfikowanym
`release`:

```bash
scripts/buildrdb.sh release package
```

Opcja `package` ponownie ustawia produkcyjne wartości przełączników i
przebudowuje wybrany katalog przed uruchomieniem CPack. Nie należy uruchamiać
pakowania na katalogach `Release-Ablation` ani `Release-Probe`.
