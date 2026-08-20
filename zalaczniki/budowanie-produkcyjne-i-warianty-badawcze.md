# Budowanie produkcyjne i warianty diagnostyczne

Skrypt `scripts/buildrdb.sh` rozdziela budowanie produkcyjne od kompilacji
z wyłączanymi optymalizacjami oraz włączaną instrumentacją. Rozdzielenie
obejmuje konfigurację CMake, katalogi wynikowe, generatory Conan oraz kontrolę
gotowej binarki.

> **⚠️ Ostrzeżenie**
>
> Binarki z `release-ablation` i `probe` są wariantami diagnostycznymi. Nie należy
> ich instalować ani pakować jako wydania produkcyjne.

## Tryby budowania

| Polecenie | Przeznaczenie | Katalog binarny |
| --- | --- | --- |
| `scripts/buildrdb.sh release` | zweryfikowane wydanie produkcyjne | `build/Release` |
| `scripts/buildrdb.sh release-ablation` | wybrana konfiguracja optymalizatora i sondy | `build/Release-Ablation/<konfiguracja>` |
| `scripts/buildrdb.sh probe` | diagnostyka z włączoną sondą | `build/Release-Probe` |

Tryby diagnostyczne korzystają również z osobnych katalogów generatorów Conan:

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
RDB_OPT_SIMPLIFY_EXPRESSIONS=ON
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

## Warianty z wyłączanymi optymalizacjami

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
RDB_OPT_SIMPLIFY_EXPRESSIONS
```

Każdy wariant otrzymuje katalog opisujący pełną konfigurację, na przykład:

```text
build/Release-Ablation/dedup-OFF_share-ON_comm-ON_factor-ON_probe-OFF_simplify-ON
```

Wartości wszystkich sześciu przełączników są przekazywane jawnie. Zapobiega to
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
wybranymi w podmenu. Niezgodność jest błędem konfiguracji.

## Sonda pomiarowa

`RDB_BENCH_PROBE` jest opcjonalną instrumentacją, a nie optymalizacją planu.
Polecenie:

```bash
scripts/buildrdb.sh probe
```

buduje wariant ze wszystkimi optymalizacjami włączonymi oraz:

```text
RDB_BENCH_PROBE=ON
```

Binarka trafia do `build/Release-Probe`. Jest zbudowana na zoptymalizowanym
kodzie `Release`, ale nie jest binarką produkcyjną.

W `release-ablation` sondę można włączyć albo wyłączyć niezależnie od
konfiguracji optymalizatora.

Sonda nie uczestniczy w wyborze ani kolejności przebiegów optymalizatora. Nie
jest jednak instrumentacją o zerowym koszcie:
`RDB_BENCH_PLAN` dodatkowo przegląda plan i zapisuje statystyki, a
`RDB_BENCH_CSV` wykonuje pomiary zegara i operacje plikowe. Sonda jest więc
semantycznie nieinwazyjna, ale jej narzut może wpływać na mierzone czasy.

Jeżeli binarka ma `RDB_BENCH_PROBE=ON`, a podczas kompilacji ustawiona jest
zmienna `RDB_BENCH_PLAN`, kompilator zapisuje na standardowe wyjście błędów
stabilny wiersz:

```text
REWRITE_APPLIED r1=<liczba> r2=<liczba> r3=<liczba>
```

Liczniki są zerowane przed każdym wywołaniem kompilatora. `r1` oznacza liczbę
skutecznych przekształceń
`(A > i) # (B > k) -> (A # B) > (i + k)`. `r2` oznacza liczbę unikalnych
węzłów `STREAM_ADD`, w których kanoniczny odcisk planu rzeczywiście zamienił
kolejność dzieci. `r3` oznacza liczbę uproszczeń programów pól i warunków
`RULE`: zwinięć stałych, połączeń ogonów stałych i usuniętych elementów
neutralnych. Liczniki opisują zastosowane przepisania, a nie przyspieszenie.
Przy `RDB_BENCH_PROBE=OFF` kod liczników nie trafia do binarki i wiersz
`REWRITE_APPLIED` nie jest emitowany.

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
RDB_OPT_SIMPLIFY_EXPRESSIONS=ON
```

Nazwa katalogu jest pomocnicza; informacja z binarki jest ostatecznym
potwierdzeniem użytych definicji kompilatora.

## Testy wariantów

Wyłączenie optymalizacji może celowo zmienić strukturę planu i dostępność
testów wymagających konkretnego kształtu. Nie może natomiast zmienić części
wartościowej wyniku: interwału, początku logicznego, publicznego deskryptora,
rekordów z mapami wartości pustych ani polityki materializacji. Ogon startowy
podlega słabszej gwarancji opisanej poniżej.

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

Wariant z wyłączoną optymalizacją może zmienić strukturę planu, ale nie może
zmienić wartości, map `NULL`, publicznego deskryptora, początku logicznego ani
polityki materializacji. Ogon może się skrócić po włączeniu poprawnego
przepisania planu, lecz nie może spowodować emisji przed dostępnością danych.
Każde inne odchylenie jest regresją, a nie dopuszczalną właściwością wariantu.

## Pakowanie

Pakiety produkcyjne należy przygotowywać dopiero po poprawnym, zweryfikowanym
`release`:

```bash
scripts/buildrdb.sh release package
```

Opcja `package` ponownie ustawia produkcyjne wartości przełączników i
przebudowuje wybrany katalog przed uruchomieniem CPack. Nie należy uruchamiać
pakowania na katalogach `Release-Ablation` ani `Release-Probe`.
