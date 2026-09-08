# xqry

Program `xqry` komunikuje się z działającym procesem `xretractor` przez Boost IPC.
Odczytuje bieżące rekordy, pokazuje plan i schematy, dołącza pojedyncze polecenia RQL,
wymienia cały plan oraz zatrzymuje wskazaną instancję. Wiele procesów `xqry` może działać
równocześnie, także wobec różnych serwerów.

## Uruchomienie

```text
$ xqry -h
xqry - data query tool.

Usage: xqry [option]

Allowed options:
  -s [ --select ] arg            show this stream
  -t [ --detail ] arg            show details of this stream
  -a [ --adhoc ] arg             adhoc query mode
  -q [ --reset ] arg             replace the whole plan of the target instance
                                 with this RQL file
  -m [ --elimitqry ] arg (=0)    limit of elements, 0 - no limit
  -n [ --null ]                  if null row appear - skip it in output
  -l [ --hello ]                 diagnostic - hello db world
  -k [ --kill ]                  kill xretractor server
  -d [ --dir ]                   list of queries
  -y [ --yaml ]                  yaml output format for --dir, --detail and
                                 --bus
  -j [ --jsonl ]                 versioned JSON Lines API output
  -i [ --idle-timeout ] arg (=0) JSONL idle timeout in ms; 0 disables
  -r [ --raw ]                   raw output mode (default)
  -g [ --graphite ]              graphite output mode
  -f [ --influxdb ]              influxDB output mode
  -p [ --gnuplot ] arg           x,y - gnuplot output mode
  -z [ --gnuplot-rtl ]           gnuplot output: newest samples on the right
  -e [ --config ] arg            config file (TOML); overrides search
  -h [ --help ]                  produce help message
  -c [ --needctrlc ]             force ctl+c for stop this tool
  -w [ --wait-server ]           poll until xretractor server is available
  -x [ --server ] arg            target xretractor instance name
  -b [ --bus ]                   list live xretractor instances and their streams
```

## Wybór instancji

Jawne `--server nazwa` wybiera instancję bez korzystania z automatycznego routingu:

```bash
xqry --server pomiary --dir
xqry --server pomiary --select temperatura
xqry --server pomiary --kill
```

Bez tej opcji klient czyta magistralę `xrdbbus`. Przy jednej żywej instancji wybiera ją
automatycznie. Przy kilku instancjach `--select` i `--detail` trafiają do właściciela
podanego strumienia. Polecenia dotyczące całej instancji (`--hello`, `--dir`, `--kill`,
`--reset`) są niejednoznaczne i wymagają `--server`.

Routing ad hoc analizuje źródła z `FROM`, a dla `RULE` strumień z `ON`. Wszystkie muszą
należeć do jednego serwera. `DECLARE` nie zawiera adresata, więc przy wielu instancjach
również wymaga `--server`. Literówka w nazwie i zapytanie przecinające granicę serwerów są
odrzucane przed wysłaniem polecenia.

## Lista instancji: `--bus`

`xqry --bus` odczytuje magistralę bez kontaktowania się z serwerami. Wiersze są sortowane
po nazwie, a `(unnamed)` oznacza zgodną wstecz instancję uruchomioną bez nazwy.

```text
$ xqry --bus
SERVER | PID    | MODE | QUERY              | STREAMS
-------+--------+------+--------------------+-----------
alfa   | 249247 | N    | .../plans/alfa.rql | srca, dsta
beta   | 249248 | FS   | .../plans/beta.rql | srcb, dstb
MODE: N=normal, R=realtime, F=no-clock, U=until-eof, M=llimitqry, X=xqrywait, S=service
```

Ścieżka w tabeli jest skracana dla czytelności. `--bus --yaml` zachowuje pełną ścieżkę:

```yaml
---
apiVersion: xqry/v1
servers:
  - name: alfa
    pid: 249247
    modes: N
    query: "/home/user/plans/alfa.rql"
    streams:
      - srca
      - dsta
```

Pusta magistrala daje poprawny dokument `servers: []` w YAML. Informacja diagnostyczna o
braku instancji trafia na `stderr`.

## Lista i szczegóły strumieni

`--dir` wypisuje wyrównaną tabelę:

```text
$ xqry --server alfa --dir
name  | duration | size | count | location      | cap
------+----------+------+-------+---------------+----
core0 | 1/10     | -1   | 0     | datafile2.dat | 4
str1  | 1/30     | 0    | 0     |               | 0
```

`duration` jest dokładnym interwałem strumienia, `size` rozmiarem zapisanych danych,
`count` liczbą rekordów, `location` plikiem źródła, a `cap` pojemnością historii wyliczoną
przez kompilator. Dla deklarowanego źródła `size` ma wartość `-1`.

`--detail strumień` pokazuje oryginalne zapytanie i pola. Modyfikator `--yaml` przełącza
`--dir`, `--detail` i `--bus` na dokument `apiVersion: xqry/v1`; nie jest samodzielnym
poleceniem. Nieznany strumień kończy działanie kodem `2`.

## Odbiór danych

| Opcja | Znaczenie |
| --- | --- |
| `-s` / `--select strumień` | Subskrybuje bieżące rekordy strumienia. |
| `-m` / `--elimitqry N` | Kończy po dokładnie N rekordach; `0` oznacza brak limitu. |
| `-n` / `--null` | Pomija rekordy, w których wszystkie wartości są `NULL`. |
| `-c` / `--needctrlc` | Wymaga Ctrl+C zamiast zakończenia dowolnym klawiszem. |

Jedna subskrypcja tworzy własną kolejkę odpowiedzi. Po zatrzymaniu lub wymianie planu
serwer wysyła znacznik końca i klient zamyka odbiór. Nagła awaria bez znacznika jest
wykrywana przez timeout `timing.query_no_data_timeout_ms`.

### Formaty prezentacyjne

| Opcja | Format |
| --- | --- |
| `-r` / `--raw` | Domyślny tekst bez dekoracji. |
| `-g` / `--graphite` | Wiersze zgodne z Graphite. |
| `-f` / `--influxdb` | Line protocol InfluxDB. |
| `-p` / `--gnuplot x,y` | Dane i polecenia do bezpośredniego zasilenia gnuplot. |
| `-z` / `--gnuplot-rtl` | Modyfikator gnuplot umieszczający najnowsze próbki po prawej. |

Można wybrać tylko jeden format. `--gnuplot-rtl` wymaga `--gnuplot`. Surowy format
przesyła wszystkie elementy pól tablicowych; mapa `NULL` jest zachowywana per element.

## Polecenia ad hoc

`--adhoc` dołącza dokładnie jedno `SELECT`, `DECLARE` albo `RULE` do aktywnego planu:

```bash
xqry --server pomiary --adhoc \
  "SELECT AVG(value : 10) STREAM avg10 FROM sensor"
```

Dyrektywy kompilatora i kilka poleceń w jednym żądaniu są odrzucane. Szczegóły początku
logicznego, deklaracji źródeł, reguł i roszczeń zasobów opisano w rozdziale
[Zapytania Ad hoc](../../realizacja-zapytan/zapytania-ad-hoc.md).

## Wymiana całego planu: `--reset`

`--reset plik.rql` przesyła zawartość pliku i zastępuje cały plan wybranej instancji. To
inna operacja niż ad hoc: pełny zestaw może zawierać wiele poleceń, reguły i dyrektywy
`:STORAGE`, `:SUBSTRAT` oraz `:ROTATION`.

```bash
xqry --server service --reset plan.rql
```

Serwer przed zmianą aktywnego modelu parsuje i kompiluje zestaw oraz rezerwuje jego nazwy
strumieni, pliki magazynu i licznik rotacji. Odmowa nie zatrzymuje starego planu. Przyjęty
plan jest aktywowany na końcu bieżącego slotu, stare subskrypcje dostają znacznik końca,
a artefakty poprzedniej epoki są sprzątane zgodnie z zasadami startu i rotacji. Pusty plik
przełącza serwer w stan bezczynny.

Jeżeli celem jest instancja usługowa, zaakceptowana treść zostaje także zapisana do jej
pliku startowego, aby przetrwała restart procesu.

## JSON Lines dla aplikacji

`--jsonl` udostępnia wersjonowane wyjście maszynowe dla `--hello`, `--dir`, `--detail`
i `--select`. Wymaga jednoznacznego serwera; aplikacje powinny zawsze podawać go jawnie.

```bash
xqry --server laboratory --jsonl --hello
xqry --server laboratory --jsonl --dir
xqry --server laboratory --jsonl --detail temperature
xqry --server laboratory --jsonl --select temperature --elimitqry 10
```

Każdy wiersz stdout jest kompletnym obiektem JSON z `version: 1` i polem `event`.
Obsługiwane zdarzenia to `pong`, `streams`, `schema`, `record`, `end` i `error`.
Diagnostyka trafia na `stderr`. `--idle-timeout N` podaje w milisekundach dopuszczalny
czas bez rekordu dla subskrypcji; zero wyłącza limit.

Polecenia modyfikujące, `--bus`, YAML, pozostałe formaty wyjścia, `--null` i
`--wait-server` nie łączą się z JSONL. Pełny kontrakt oraz gotowe klienty Python i C++
opisuje [API monitorowania strumieni](../api-monitorowania-strumieni.md).

## Jedno polecenie naraz

`--select`, `--detail`, `--adhoc`, `--reset`, `--dir`, `--bus` i `--hello` są różnymi
poleceniami; podanie kilku naraz kończy się kodem `22`. `--kill` może być świadomie
połączone z `--select -m N` albo z `--adhoc`, aby zatrzymać serwer po wykonaniu operacji.

## Czekanie na serwer

`--wait-server` odpytuje dostępność IPC zgodnie z `timing.server_startup_wait_s` i
`timing.server_startup_poll_ms`. Przy jawnej nazwie czeka na nią. Bez nazwy ponawia routing:
historycznie czeka na instancję bezimienną, a po pojawieniu się jednej nazwanej instancji
wybiera ją automatycznie. Niejednoznaczność przy wielu serwerach jest zgłaszana od razu.
`--bus` nie wymaga serwera i ignoruje czekanie.

Typowy wzorzec testowy:

```bash
xretractor query.rql --name test --llimitqry 100 --noanykey --xqrywait &
xqry --server test --wait-server --select strumien --elimitqry 10
```

## Informacje o wersji

Informacje pod listą pomocy zawierają nazwę odnogi, skrót commita, wersję kompilatora,
czas i typ budowania oraz ścieżkę dziennika. Opis formatu znajduje się w rozdziale
[xretractor — Informacje o wersji](xretractor.md#informacje-o-wersji).
