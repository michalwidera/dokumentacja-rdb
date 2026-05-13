# xqry

Program `xqry` jest integralną częścią systemu RetractorDB. Dzieli z `xretractor` wspólny obszar w pamięci (Boost IPC) używany do komunikacji. Służy do odpytywania działającego procesu przetwarzania, odbioru wyników z pętli zapytań oraz sterowania pracą serwera.

W odróżnieniu od `xretractor`, `xqry` może być uruchomiony w wielu instancjach jednocześnie.

## Uruchomienie

```
$ xqry -h
xqry - data query tool.

Usage: xqry [option]

Allowed options:
  -s [ --select ] arg         show this stream
  -t [ --detail ] arg         show details of this stream
  -a [ --adhoc ] arg          adhoc query mode
  -m [ --tlimitqry ] arg (=0) limit of elements, 0 - no limit
  -l [ --hello ]              diagnostic - hello db world
  -k [ --kill ]               kill xretractor server
  -d [ --dir ]                list of queries
  -y [ --diryaml ]            list of queries in yaml format
  -r [ --raw ]                raw output mode (default)
  -g [ --graphite ]           graphite output mode
  -f [ --influxdb ]           influxDB output mode
  -p [ --gnuplot ] arg        x,y - gnuplot output mode
  -h [ --help ]               produce help message
  -c [ --needctrlc ]          force ctl+c for stop this tool
```

---

## Odbiór danych ze strumieni

| Opcja                   | Znaczenie                                                                                                   |
| ----------------------- | ----------------------------------------------------------------------------------------------------------- |
| `-s` / `select arg`     | Odbiera dane z podanego strumienia udostępnianego przez `xretractor`.                                       |
| `-t` / `detail arg`     | Wyświetla szczegółowe informacje o strumieniu: nazwę, delta, treść zapytania i listę pól z typami (YAML).   |
| `-a` / `adhoc arg`      | Dołącza zapytanie do systemu w trakcie jego działania (tryb ad hoc).                                        |
| `-m` / `tlimitqry arg`  | Ogranicza liczbę odebranych wyników. Wartość `0` oznacza brak limitu. Szczególnie przydatne z opcją `-k`.   |

Przykładowa odpowiedź opcji `detail`:

```yaml
---
apiVersion: xqry/v1
stream:
  name: str4
  delta: 1
  query: SELECT (str4[0]+1)*2 STREAM str4 FROM core0>1
  fields:
    str4.str4_0:
      type: INTEGER
```

---

## Diagnostyka i sterowanie serwerem

| Opcja              | Znaczenie                                                                              |
| ------------------ | -------------------------------------------------------------------------------------- |
| `-l` / `hello`     | Weryfikacja działania kanału komunikacyjnego z `xretractor` (ping diagnostyczny).      |
| `-k` / `kill`      | Żądanie zatrzymania procesu `xretractor`.                                              |
| `-d` / `dir`       | Wylistowanie wszystkich zapytań realizowanych przez `xretractor` w formacie tekstowym. |
| `-y` / `diryaml`   | Wylistowanie wszystkich zapytań w formacie YAML.                                       |

---

## Formaty wyjścia

`xqry` obsługuje cztery formaty prezentacji danych. Format wybiera się flagą — można go łączyć z opcją `select`.

| Opcja              | Format         | Zastosowanie                                                                 |
| ------------------ | -------------- | ---------------------------------------------------------------------------- |
| `-r` / `raw`       | Tekstowy       | Domyślny. Dane bez dekoracji — przydatny do skryptów i potokowania.          |
| `-g` / `graphite`  | Graphite       | Format `metryka wartość znacznik_czasu` — gotowy do wysłania do Graphite.    |
| `-f` / `influxdb`  | InfluxDB       | Line protocol InfluxDB — gotowy do importu do bazy szeregów czasowych.       |
| `-p` / `gnuplot x,y` | Gnuplot      | Agregaty dla bezpośredniego zasilania `gnuplot`; argument podaje kolumny x,y.|

---

## Sterowanie trybem odbioru

| Opcja              | Znaczenie                                                                                          |
| ------------------ | -------------------------------------------------------------------------------------------------- |
| `-h` / `help`      | Wyświetlenie tekstu pomocy.                                                                        |
| `-c` / `needctrlc` | W normalnym trybie dowolny klawisz zatrzymuje odbiór danych. Ta opcja wymaga użycia `Ctrl+C`.      |

---

## Informacje o wersji

Informacje na dole listy pomocy są identyczne jak w przypadku `xretractor` — zawierają nazwę odnogi repozytorium, wersję kompilatora, czas budowy oraz ścieżkę do pliku dziennika (`/tmp/xqry.log`). Opis formatu znajdziesz w rozdziale [xretractor — Informacje o wersji](xretractor.md#informacje-o-wersji).
