# API monitorowania strumieni

Opcjonalne API klienckie służy do monitorowania strumieni działającej, jawnie nazwanej
instancji `xretractor` na tym samym hoście Linux. Warstwa transportowa uruchamia procesy
`xqry --jsonl`; dzięki temu API nie powiela protokołu Boost IPC i korzysta z tych samych
reguł wyboru strumienia oraz kończenia subskrypcji co narzędzie wiersza poleceń.

Dostępne są:

- pakiet Python 3.10+ bez zależności uruchomieniowych poza biblioteką standardową;
- statyczna biblioteka C++23 z publicznym nagłówkiem i konfiguracją CMake;
- wersjonowany kontrakt JSON Lines v1, który można obsłużyć także bez gotowej biblioteki.

API nie uruchamia serwera, nie ładuje planów, nie łączy się ponownie po awarii i nie
odtwarza pominiętych próbek. Jest interfejsem obserwacji na żywo, a nie transportem
trwałym ani bezstratnym.

## Kontrakt JSON Lines v1

`xqry --jsonl` obsługuje cztery polecenia tylko do odczytu:

```bash
xqry --server laboratory --jsonl --hello
xqry --server laboratory --jsonl --dir
xqry --server laboratory --jsonl --detail temperature
xqry --server laboratory --jsonl --select temperature --elimitqry 10
```

Każdy wiersz stdout jest kompletnym obiektem UTF-8 JSON z `version: 1` i `event`.
Komunikaty diagnostyczne trafiają na stderr.

| Zdarzenie | Zawartość |
| --- | --- |
| `pong` | Odpowiedź na `hello`. |
| `streams` | Tablica elementów `{name, delta}`; pusta dla serwera bezczynnego. |
| `schema` | Nazwa strumienia, delta, oryginalne zapytanie i uporządkowane pola. |
| `record` | Nazwa strumienia i spłaszczona tablica wartości. |
| `end` | Normalny koniec: `limit` albo `server_stopped_or_reloaded`. |
| `error` | Stabilny kod oraz opis błędu; proces kończy się niezerowo. |

Subskrypcja emituje najpierw schemat, potem rekordy i dokładnie jedno końcowe zdarzenie
`end` albo `error`. EOF bez zdarzenia końcowego jest błędem procesu, nawet gdy kod wyjścia
wynosi zero.

```json
{"version":1,"event":"schema","stream":"temperature","delta":"1/20","query":"...","fields":[{"name":"v","type":"INTEGER","count":2}]}
{"version":1,"event":"record","stream":"temperature","values":["21",null]}
{"version":1,"event":"end","reason":"limit"}
```

Pole `count` w schemacie jest licznością skalarną. Tablice liczbowe zachowują wszystkie
elementy i osobne wartości `NULL`; `STRING[N]` pozostaje jednym napisem. Niepuste wartości
na przewodzie są napisami interpretowanymi według typu ze schematu. Dzięki temu liczby
wymierne zachowują licznik i mianownik, a napis `"null"` nie miesza się z JSON `null`.

| Typ RQL | Python | C++ `Value` |
| --- | --- | --- |
| `NULL` | `None` | `std::monostate` |
| `BYTE`, `INTEGER`, `UINT` | `int` | `std::int64_t` |
| `FLOAT`, `DOUBLE` | `float` | `double` |
| `RATIONAL` | `fractions.Fraction` | `Rational` |
| `INTPAIR` | para liczb | `std::pair<int64_t, int64_t>` |
| `IDXPAIR` | para napis–liczba | `std::pair<std::string, int64_t>` |
| `STRING` | `str` | `std::string` |

Wiadomości nie niosą znacznika czasu źródła ani trwałego numeru sekwencji. Precyzję liczb
zmiennoprzecinkowych ogranicza istniejąca tekstowa serializacja IPC, a całe opakowanie INFO
musi mieścić się w limicie 1024 bajtów kolejki serwera.

`--idle-timeout N` kończy JSONL po N milisekundach bez rekordu; zero wyłącza limit. Jest to
niezależne od timeoutu pojedynczego odczytu w bibliotekach.

## Python

Pakiet instaluje się ze źródeł:

```bash
python3 -m venv .venv-api
.venv-api/bin/python -m pip install ./api/python
```

Każda subskrypcja posiada własny proces potomny `xqry`:

```python
from retractordb import Client, ReadTimeout

with Client("laboratory", xqry="/path/to/xqry") as db:
    print(db.streams())
    print(db.describe("temperature"))
    with db.subscribe("temperature", limit=10) as samples:
        for record in samples:
            print(record["v"])
        print(samples.end_reason)
```

`Client(server, xqry="xqry", timeout=5.0)` przyjmuje timeout w sekundach.
`subscribe(stream, limit=0, idle_timeout=0.0, capacity=1024)` zwraca obiekt ze schematem
znanym już przy zakończeniu wywołania. `next(timeout=...)` może zgłosić `ReadTimeout` bez
zamykania subskrypcji. Zwykła iteracja czeka bez limitu. Rekord mapuje nazwę pola na skalar
albo listę elementów tablicy.

Należy używać menedżerów kontekstu lub jawnego `close()`. Samo przerwanie pętli `for` nie
zamyka iteratora. Biblioteka nie instaluje obsługi sygnałów aplikacji.

## C++

Biblioteka wymaga C++23. W drzewie RetractorDB jej cele są dostępne na żądanie:

```bash
cmake --build build/Debug --target rdb_monitor
build/Debug/api/cpp/rdb_monitor laboratory temperature 10 /path/to/xqry
```

Projekt może dołączyć źródła bezpośrednio:

```cmake
add_subdirectory(/path/to/retractordb/api/cpp rdb-api)
target_link_libraries(my_monitor PRIVATE RetractorDB::client)
```

Po instalacji komponentu API dostępny jest pakiet CMake:

```cmake
find_package(RetractorDBClient CONFIG REQUIRED)
target_link_libraries(my_monitor PRIVATE RetractorDB::client)
```

Minimalna subskrypcja:

```cpp
#include <iostream>
#include "retractordb/client.hpp"

int main() {
  retractordb::Client db("laboratory");
  auto samples = db.subscribe("temperature", {.limit = 10});
  while (auto record = samples.next())
    std::cout << record->values.at("v").size() << '\n';
}
```

`SubscribeOptions` udostępnia `limit`, `idleTimeout` i `capacity`. `next(timeout)` zwraca
`std::optional<Record>`; brak wartości oznacza normalny koniec lub jawne zamknięcie. Błędy
rzucają `retractordb::Error` ze stabilnym polem `code`. Uchwyty subskrypcji są przenoszalne,
ale niekopiowalne; destruktor i `close()` kończą oraz zbierają własny proces potomny.

## Ograniczenia i obsługa błędów

Bufory bibliotek są ograniczone: domyślnie 1024 oczekujące zdarzenia, 1 MiB na wiersz JSONL
i 64 KiB zachowanego stderr. Przepełnienie bufora aplikacji daje `buffer_overflow` i zamyka
subskrypcję bez cichego pomijania rekordów. Przepełnienie kolejki po stronie serwera jest
ograniczeniem istniejącego IPC i może ujawnić się dopiero jako timeout bezczynności.

Zamknięcie jest idempotentne: biblioteka wysyła SIGTERM do własnego `xqry`, czeka do sekundy,
a w razie potrzeby używa SIGKILL i zbiera proces. Zamknięcie klienta zamyka wszystkie jego
subskrypcje; nigdy nie wysyła `xqry --kill` do serwera.

Kody błędów obejmują między innymi `read_timeout`, `idle_timeout`, `buffer_overflow`,
`stream_not_found`, `no_active_plan`, `server_stopping`, `server_no_response`,
`client_queue_missing`, `disconnected`, `communication_error`, `protocol_error`,
`spawn_error`, `process_exit`, `process_timeout` i `closed`.

## Budowanie i testowanie

API jest rozwijane razem z silnikiem, ale pozostaje opcjonalne. Zwykłe `ninja`,
`ninja install`, `ninja test` i `ninja package` nie budują, nie instalują ani nie pakują API.

| Polecenie | Efekt |
| --- | --- |
| `ninja install-withapi` | Buduje i instaluje silnik oraz komponent `api`. |
| `ninja test-api` | Buduje klienta testowego i uruchamia `ctest -L api`. |
| `cmake -DRDB_WITH_API=ON .` | Dołącza komponent `api` do pakietów CPack i testy API do zwykłego celu `test`. |

API C++ jest konfigurowane zawsze, ale jego cele mają `EXCLUDE_FROM_ALL`. `xqry` ma własną
jednostkę kompilacji Boost.JSON, dlatego silnik nie linkuje niczego z katalogu `api/`.
Zależność biegnie wyłącznie od API do publicznego interfejsu procesu `xqry`.

Testy `st_api_fake` i `st_api_real` sprawdzają oba języki. Pierwszy obejmuje typy,
`NULL`, błędne wyjście, przepełnienie i zamykanie procesu. Drugi używa prawdziwego
`xretractor` i sprawdza niezależne subskrypcje, tablice, liczby wymierne, brakujący strumień
oraz zatrzymanie serwera.
