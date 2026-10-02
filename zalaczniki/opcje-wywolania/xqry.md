# xqry

Program `xqry` komunikuje się z działającym procesem `xretractor` przez Boost IPC. Odczytuje bieżące rekordy, pokazuje plan i schematy, dołącza pojedyncze polecenia RQL, wymienia cały plan oraz zatrzymuje wskazaną instancję. Wiele procesów `xqry` może działać równocześnie, także wobec różnych serwerów.

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
  -o [ --gnuplot-ohlc ]          gnuplot output: row = open, high, low, close,
                                 then the samples of that candle
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

Bez tej opcji klient czyta magistralę bieżącej przestrzeni nazw: domyślną `xrdbbus_v7` albo `xrdbbus_v7_<namespace>` przy ustawionym `RDB_NAMESPACE`. Przy jednej żywej instancji wybiera ją automatycznie. Przy kilku instancjach `--select` i `--detail` trafiają do właściciela podanego strumienia. Polecenia dotyczące całej instancji (`--hello`, `--dir`, `--kill`, `--reset`) są niejednoznaczne i wymagają `--server`. Zbiorcza lista `--bus` opisana niżej nie zmienia tego routingu.

Routing ad hoc analizuje źródła z `FROM`, a dla `RULE` strumień z `ON`. Wszystkie muszą należeć do jednego serwera. `DECLARE` nie zawiera adresata, więc przy wielu instancjach również wymaga `--server`. Literówka w nazwie i zapytanie przecinające granicę serwerów są odrzucane przed wysłaniem polecenia.

## Lista instancji: `--bus`

`xqry --bus` bez ustawiania `RDB_NAMESPACE` wykrywa dostępne magistrale bieżącej wersji i wypisuje osobną sekcję `NAMESPACE:` dla każdej z co najmniej jedną żywą instancją. Działa tak samo przy ustawionym `RDB_NAMESPACE`: lista obejmuje wszystkie dostępne przestrzenie nazw, podczas gdy pozostałe polecenia nadal używają bieżącej przestrzeni. `(default)` oznacza magistralę bez przestrzeni nazw, a `(unnamed)` - zgodną wstecz instancję uruchomioną bez nazwy. Sekcje są uporządkowane według nazwy magistrali, domyślna jest pierwsza, a instancje w sekcji są sortowane po nazwie.

Klient odczytuje rejestry w pamięci dzielonej bez kontaktowania się z serwerami. Pomija segmenty bez żywych instancji. Uprawnienia obiektów pamięci dzielonej ograniczają wykrywanie do magistral dostępnych dla bieżącego konta.

```text
$ xqry --bus
NAMESPACE: (default)
SERVER | PID    | MODE | QUERY              | STREAMS
-------+--------+------+--------------------+--------
alfa   | 249247 | N    | .../plans/alfa.rql | srca
       |        |      |                    | dsta
MODE: N=normal, R=realtime, F=no-clock, U=until-eof, M=llimitqry, X=xqrywait, S=service

NAMESPACE: bus_probe
SERVER | PID    | MODE | QUERY | STREAMS
-------+--------+------+-------+--------
probe  | 249249 | N    | -     | -
MODE: N=normal, R=realtime, F=no-clock, U=until-eof, M=llimitqry, X=xqrywait, S=service
```

Ścieżka w tabeli jest skracana dla czytelności. `--bus --yaml` zachowuje pełną ścieżkę i jedną listę `servers`, w której pole `namespace` wskazuje magistralę każdej instancji. `null` oznacza magistralę domyślną, a nazwa przestrzeni jest cytowanym napisem:

```yaml
---
apiVersion: xqry/v1
servers:
  - name: alfa
    namespace: null
    pid: 249247
    modes: N
    query: "/home/user/plans/alfa.rql"
    streams:
      - srca
      - dsta
  - name: probe
    namespace: "bus_probe"
    pid: 249249
    modes: N
    streams: []
```

Gdy żadna dostępna magistrala nie ma żywej instancji, wynik tabelaryczny na `stdout` jest pusty, a YAML zawiera `servers: []`. Komunikat `xqry: no live xretractor instance` trafia na `stderr`.

## Lista i szczegóły strumieni

`--dir` wypisuje wyrównaną tabelę:

```text
$ xqry --server alfa --dir
name  | duration | size | count | location      | cap
------+----------+------+-------+---------------+----
core0 | 1/10     | -1   | 0     | datafile2.dat | 4
str1  | 1/30     | 0    | 0     |               | 0
```

`duration` jest dokładnym interwałem strumienia, `size` rozmiarem zapisanych danych, `count` liczbą rekordów, `location` plikiem źródła, a `cap` pojemnością historii wyliczoną przez kompilator. Dla deklarowanego źródła `size` ma wartość `-1`.

`--detail strumień` pokazuje oryginalne zapytanie i pola. Modyfikator `--yaml` przełącza `--dir`, `--detail` i `--bus` na dokument `apiVersion: xqry/v1`; nie jest samodzielnym poleceniem. Nieznany strumień kończy działanie kodem `2`.

Odpowiedzi na polecenia są dopasowywane do konkretnego żądania klienta. Budżet czasu `ipc.client_response_max_fails` obejmuje wysłanie polecenia i odebranie odpowiedzi; pełna kolejka poleceń kończy się odmową po upływie tego terminu. Odpowiedź porzucona przez zabitego klienta może zostać odzyskana bez blokowania kolejnych klientów.

## Odbiór danych

| Opcja | Znaczenie |
| --- | --- |
| `-s` / `--select strumień` | Subskrybuje bieżące rekordy strumienia. |
| `-m` / `--elimitqry N` | Kończy po dokładnie N rekordach; `0` oznacza brak limitu. |
| `-n` / `--null` | Pomija rekordy, w których wszystkie wartości są `NULL`. |
| `-c` / `--needctrlc` | Wymaga Ctrl+C zamiast zakończenia dowolnym klawiszem. |

Jedna subskrypcja tworzy własną kolejkę odpowiedzi. Po zatrzymaniu lub wymianie planu serwer wysyła znacznik końca i klient zamyka odbiór. Nagła awaria bez znacznika jest wykrywana przez timeout `timing.query_no_data_timeout_ms`.

### Formaty prezentacyjne

| Opcja | Format |
| --- | --- |
| `-r` / `--raw` | Domyślny tekst bez dekoracji. |
| `-g` / `--graphite` | Wiersze zgodne z Graphite. |
| `-f` / `--influxdb` | Line protocol InfluxDB. |
| `-p` / `--gnuplot x,y` | Dane i polecenia do bezpośredniego zasilenia gnuplot. |
| `-z` / `--gnuplot-rtl` | Modyfikator gnuplot umieszczający najnowsze próbki po prawej. |
| `-o` / `--gnuplot-ohlc` | Modyfikator gnuplot rysujący wykres świecowy: rekord to otwarcie, maksimum, minimum, zamknięcie i dalej próbki tej świecy. |

Można wybrać tylko jeden format. `--gnuplot-rtl` i `-o` / `--gnuplot-ohlc` wymagają `--gnuplot` i można je łączyć. W trybie `--gnuplot-ohlc` pierwszy parametr `-p` liczy próbki, a nie świece; układ rekordu i reguły rysowania opisuje przykład [Wykres świecowy (OHLC)](../../przyklady-zastosowan/wykres-swiecowy-ohlc.md). Surowy format przesyła wszystkie elementy pól tablicowych; mapa `NULL` jest zachowywana per element.

W wyjściu OHLC rekordy bez poprawnych wartości świecy nie tworzą świec, ale nadal mogą tworzyć linię próbek. Gdy w całym aktualnym oknie nie ma poprawnych świec, `xqry` wysyła tylko serię próbek; gdy nie ma poprawnych próbek, tylko serię świec. Okno bez żadnego poprawnego punktu nie wysyła pustego polecenia `plot` do gnuplota.

## Polecenia ad hoc

`--adhoc` dołącza dokładnie jedno `SELECT`, `DECLARE` albo `RULE` do aktywnego planu:

```bash
xqry --server pomiary --adhoc \
  "SELECT AVG(value : 10) STREAM avg10 FROM sensor"
```

Dyrektywy kompilatora i kilka poleceń w jednym żądaniu są odrzucane. Szczegóły początku logicznego, deklaracji źródeł, reguł i roszczeń zasobów opisano w rozdziale [Zapytania Ad hoc](../../realizacja-zapytan/zapytania-ad-hoc.md).

## Wymiana całego planu: `--reset`

`--reset plik.rql` przesyła zawartość pliku i zastępuje cały plan wybranej instancji. To inna operacja niż ad hoc: pełny zestaw może zawierać wiele poleceń, reguły i dyrektywy `:STORAGE`, `:SUBSTRAT` oraz `:ROTATION`.

```bash
xqry --server service --reset plan.rql
```

Serwer przed zmianą aktywnego modelu parsuje i kompiluje zestaw, sprawdza zachowane pliki `.desc` (dla źródeł `DECLARE` zawsze, dla wyników `SELECT` i substratów przy `:ROTATION`), zgodność zachowanych magazynów, możliwość otwarcia plików wyjściowych na dysku oraz rezerwuje jego nazwy strumieni, pliki magazynu i licznik rotacji. Kontrola plików nie tworzy ich podczas walidacji; odmowa, np. `descriptor parse failed` ze ścieżką i miejscem błędu albo `cannot open output file`, nie zatrzymuje starego planu ani nie zmienia pliku startowego usługi. Przyjęty plan jest aktywowany na końcu bieżącego slotu, stare subskrypcje dostają znacznik końca, a artefakty poprzedniej epoki są sprzątane zgodnie z zasadami startu i rotacji. Pusty plik przełącza serwer w stan bezczynny.

Kontrola plików jest wstępna: między odpowiedzią `OK` na `--reset` a rzeczywistym otwarciem magazynu ścieżka może się zmienić. Późny błąd otwarcia podczas wymiany planu nie jest obecnie odsyłany klientowi jako odmowa i może zatrzymać serwer; odpowiedź `OK` nie gwarantuje powodzenia tej późniejszej operacji.

Jeżeli celem jest instancja usługowa, zaakceptowana treść zostaje także zapisana do jej pliku startowego, aby przetrwała restart procesu.

### Reguła `DO SYSTEM` nie przechodzi tym kanałem

Plan zawierający regułę `DO SYSTEM` jest odrzucany **w całości**, z podaniem nazwy reguły i powodu:

```
$ xqry --reset z-regula-systemowa.rql --server service
xqry: plan reload refused at reset-commit: Rejected: rule 'evil' on stream 'alpha' uses DO SYSTEM; ...
```

Powód jest ten sam, dla którego odmawia kanał ad hoc: `DO SYSTEM` wykonuje dowolne polecenie powłoki na koncie instancji, a kanał IPC nie niesie autorstwa, więc nadawcy resetu nie czyni operatorem usługi. Regułę taką wolno zamówić wyłącznie w pliku planu, z którego instancja startuje. Odmowa obejmuje cały zestaw, a nie samą regułę, ponieważ przyjęty tekst jest zapisywany do pliku startowego usługi, którego start już żadnego sprawdzenia nie przechodzi - reguła wycięta w locie wróciłaby uzbrojona po najbliższym restarcie.

Operator, który świadomie oddaje ten kanał, ustawia `service.unrestricted = true` w konfiguracji TOML (→ [xretractor](xretractor.md#plik-konfiguracyjny-toml)). Instancja zostawia wtedy ostrzeżenie w dzienniku przy każdym starcie, a kanał ad hoc pozostaje zamknięty niezależnie od tej wartości.

## JSON Lines dla aplikacji

`--jsonl` udostępnia wersjonowane wyjście maszynowe dla `--hello`, `--dir`, `--detail` i `--select`. Wymaga jednoznacznego serwera; aplikacje powinny zawsze podawać go jawnie.

```bash
xqry --server laboratory --jsonl --hello
xqry --server laboratory --jsonl --dir
xqry --server laboratory --jsonl --detail temperature
xqry --server laboratory --jsonl --select temperature --elimitqry 10
```

Każdy wiersz stdout jest kompletnym obiektem JSON z `version: 1` i polem `event`. Obsługiwane zdarzenia to `pong`, `streams`, `schema`, `record`, `end` i `error`. Diagnostyka trafia na `stderr`. `--idle-timeout N` podaje w milisekundach dopuszczalny czas bez rekordu dla subskrypcji; zero wyłącza limit.

Polecenia modyfikujące, `--bus`, YAML, pozostałe formaty wyjścia, `--null` i `--wait-server` nie łączą się z JSONL. Pełny kontrakt oraz gotowe klienty Python i C++ opisuje [API monitorowania strumieni](../api-monitorowania-strumieni.md).

## Jedno polecenie naraz

`--select`, `--detail`, `--adhoc`, `--reset`, `--dir`, `--bus` i `--hello` są różnymi poleceniami; podanie kilku naraz kończy się kodem `22`. `--kill` może być świadomie połączone z `--select -m N` albo z `--adhoc`, aby zatrzymać serwer po wykonaniu operacji.

## Czekanie na serwer

`--wait-server` odpytuje dostępność IPC zgodnie z `timing.server_startup_wait_s` i `timing.server_startup_poll_ms`. Przy jawnej nazwie czeka na nią. Bez nazwy ponawia routing: historycznie czeka na instancję bezimienną, a po pojawieniu się jednej nazwanej instancji wybiera ją automatycznie. Niejednoznaczność przy wielu serwerach jest zgłaszana od razu. `--bus` nie wymaga serwera i ignoruje czekanie.

Gotowość wymaga otwieralnych obiektów IPC i żywej instancji w magistrali. Gdy magistrala jest niedostępna, sprawdzana jest utrzymywana blokada tożsamości IPC. Same obiekty pozostawione po awarii nie oznaczają gotowego serwera.

Typowy wzorzec testowy:

```bash
xretractor query.rql --name test --llimitqry 100 --noanykey --xqrywait &
xqry --server test --wait-server --select strumien --elimitqry 10
```

## Informacje o wersji

Informacje pod listą pomocy zawierają nazwę odnogi, skrót commita, wersję kompilatora, czas i typ budowania oraz ścieżkę dziennika. Opis formatu znajduje się w rozdziale [xretractor - Informacje o wersji](xretractor.md#informacje-o-wersji).
