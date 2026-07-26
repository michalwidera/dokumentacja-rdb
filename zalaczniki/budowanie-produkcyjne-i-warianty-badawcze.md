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
build/Release/src/retractor/xretractor --build-info
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

Po zbudowaniu wariantu skrypt porównuje `--build-info` z wartościami
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
ścieżka/do/xretractor --build-info
```

Polecenie wypisuje konfigurację i kończy działanie bez uruchamiania silnika
(równoważny skrót: `-b`). Jest obsługiwane przed wczytaniem i walidacją pliku
konfiguracyjnego, więc daje poprawny wynik także wtedy, gdy konfiguracja hosta
uniemożliwiłaby normalny start programu. Przykładowy wynik wariantu
produkcyjnego:

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

Wyłączenie optymalizacji może celowo zmienić strukturę planu i dostępność
testów wymagających konkretnego kształtu. Nie może natomiast zmienić
obserwowalnego wyniku: interwału, ogona startowego, publicznego deskryptora,
rekordów z mapami wartości pustych ani polityki materializacji.

CTest przypisuje testom wymagającym konkretnej optymalizacji etykiety
`requires_*` i może je wyłączyć dla niezgodnej konfiguracji. Etykieta
`expected_ablation_failure` opisuje wtedy oczekiwaną niedostępność testu
kształtu planu, a nie przyzwolenie na różnicę semantyczną.

Procedura oceny błędu powinna być następująca:

1. uruchomić ten sam test w konfiguracji produkcyjnej;
2. potwierdzić, że przechodzi z wymaganymi optymalizacjami;
3. uruchomić go w badanym wariancie;
4. wykazać związek błędu z wyłączonym przełącznikiem;
5. jeżeli test wymaga wyłączonego przebiegu, wyłączyć go dla tego wariantu;
6. każdy inny błąd traktować jako regresję.

Test `it_optimizer_ablation-build-info` kontroluje zgodność informacji
raportowanej przez binarkę z konfiguracją CMake. Pozostałe testy
`it_optimizer_ablation-*` sprawdzają strukturę planów i porównania semantyczne
między wariantami.

### Nazwane profile badawcze

Sonda G1 definiuje trzy profile, które należy zapisywać razem z wynikami:

| Profil | Deduplikacja | Współdzielenie `SELECT` | Przemienność `+` | Faktoryzacja R1 |
| --- | :---: | :---: | :---: | :---: |
| `OFF` | OFF | OFF | OFF | OFF |
| `STRUCT` | ON | ON | OFF | OFF |
| `ALGSTRUCT` | ON | ON | ON | ON |

`ALGSTRUCT` odpowiada domyślnej konfiguracji optymalizatora. Profile są
budowane przez
`examples/experiment/results_20260726_G1/build_profiles.sh`; źródłem prawdy
o konkretnej binarce pozostaje jej `--build-info`.

Po wprowadzeniu przyczynowego ogona startowego, jednej konwencji `tau`
i końcowego sortowania topologicznego nie ma oczekiwanych rozbieżności
semantycznych między profilami. Sonda potwierdza dla `OFF`, `STRUCT`
i konfiguracji domyślnej zgodność wartości, map `null`, braku prefiksu
i ogonów R1. Dwa dawne przypadki `WILL_FAIL` — inny wynik R1 bez faktoryzacji
oraz dodatkowy rekord zerowego prefiksu — zostały usunięte wraz z ich
przyczynami i nie są już dopuszczalnym wynikiem ablacji.

Ta trójka profili wystarcza do kontroli „algebra razem ze strukturą”,
ale nie rozdziela kosztu R1 od R2. Eksperyment przypisujący efekt konkretnej
regule powinien dodać profile pośrednie `STRUCT+R1` i `STRUCT+R2` oraz
liczniki zastosowań każdej reguły.

## Pakowanie

Pakiety produkcyjne należy przygotowywać dopiero po poprawnym, zweryfikowanym
`release`:

```bash
scripts/buildrdb.sh release package
```

Opcja `package` ponownie ustawia produkcyjne wartości przełączników i
przebudowuje wybrany katalog przed uruchomieniem CPack. Nie należy uruchamiać
pakowania na katalogach `Release-Ablation` ani `Release-Probe`.
