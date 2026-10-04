# xtrdb

Program `xtrdb` to interaktywne narzędzie do analizy artefaktów i substratów zapisanych przez system RetractorDB. Pracuje głównie w trybie interaktywnym (REPL), ale udostępnia także kilka opcji uruchomienia (np. `--help`, `--noprompt`, `--storagemap`).

> **⚠️ Ostrzeżenie**
>
> Tryb interaktywny i wsadowy `xtrdb` odmawiają pracy, gdy w katalogu blokad działa dowolna instancja `xretractor`, także nazwana. Przed ich użyciem zatrzymaj te instancje lub poczekaj na zakończenie. Narzędzie czyta ten sam `paths.lock_dir` z konfiguracji TOML co silnik (domyślnie katalog tymczasowy procesu), przegląda rodzinę `xretractor_service*.lock` i sprawdza, czy blokada jest trzymana. Sam porzucony plik blokady nie powoduje odmowy. Przy niestandardowym katalogu uruchom `xtrdb` z tą samą konfiguracją co serwer. Opcje `--help` i `--storagemap` kończą działanie przed tą kontrolą; `--storagemap` tylko odczytuje stan składowania.


---

## Uruchomienie

```
$ xtrdb                    # tryb interaktywny (z promptem)
$ xtrdb -n                 # tryb wsadowy (bez promptu i bez "ok")
$ xtrdb --noprompt         # to samo co -n
$ xtrdb noprompt           # zgodność wsteczna (legacy, argument pozycyjny)
$ xtrdb -s plik_danych     # pokaż strukturę storage dla wskazanego pliku
$ xtrdb --storagemap plik  # to samo co -s
$ xtrdb -h                 # help i informacje o buildzie, potem zakończ
```

Tryb `-n/--noprompt` usuwa kolorowanie, prompt `.` i komunikat `ok` - przydatny, gdy wejście pochodzi z pliku lub potoku. Wciąż działa też historyczny wariant pozycyjny `noprompt`.

```
$ xtrdb -n < script.xtrdb
```

Opcja `-s/--storagemap` uruchamia tylko raport struktury pliku danych i kończy działanie programu (bez wejścia do REPL).

Po uruchomieniu narzędzie wypisuje prompt `.` i czeka na polecenie. Każde polecenie kończy się naciśnięciem Enter.

---

## Przegląd poleceń

Polecenie `help` lub `h` wyświetla listę dostępnych poleceń:

```
$ xtrdb
.help
exit|quit|q                     exit
quitdrop|qd                     exit & drop artifacts (data, .desc, .meta)
open file [schema]              open or create database with schema
                                example: .open test_db { INTEGER dane 
                                STRING name[3] }
storage [path]                  set storage path for database
policy [name]                   set storage policy
dropfile [file1] [file2] ... }  remove listed file(s), end with }
desc|descc                      show schema
read|rread [n]                  read record from database into payload
write [n]                       from payload send record to database
purge                           remove all records from database
append                          append payload to database
set [field][value]              set payload field value
setpos [position][number value] set payload field number value
getpos [position]               show payload field value
status                          show current payload status
rox                             remove on exit flip (data, .desc, .meta)
print|printt                    show payload
list|rlist [count]              print first records
input [[field][value]]          fill payload
hex|dec                         type of input/output of byte/number fields
size                            show database size in records
cap [value]                     set device stream backread capacity
dump                            show payload memory
meta                            show meta index (null patterns) for open db
metaraw                         show internal meta file structure
echo                            print message on terminal
system                          execute system command
#|rem [text]                    comment line
help|h                          show this help
```

---

## Zarządzanie sesją

| Polecenie           | Opis                                                             |
| ------------------- | ---------------------------------------------------------------- |
| `exit`, `quit`, `q` | Zakończ narzędzie. Zapisane rekordy pozostają na dysku, o ile nie włączono usuwania przez `rox`; zmiany wyłącznie w buforze payload nie są automatycznie zapisywane. |
| `quitdrop`, `qd`    | Zakończ i usuń otwarte pliki artefaktu (dane, `.desc`, `.meta`). Plik danych wskazany przez `REF` z `.desc` poza katalogiem magazynu i `storage.ref_dirs` zostaje - usuwany jest tylko `.desc`. |

---

## Konfiguracja środowiska

| Polecenie           | Opis                                                                                        |
| ------------------- | ------------------------------------------------------------------------------------------- |
| `storage [ścieżka]` | Ustaw katalog roboczy. Kolejne polecenie `open` szuka pliku w tej ścieżce.                  |
| `policy [nazwa]`    | Ustaw politykę przechowywania (`DEFAULT`, `DIRECT`, `POSIX`, `MEMORY`, …). Musi poprzedzać `open`. |

Konfiguracja TOML jest wczytywana ze standardowych lokalizacji: `/etc/retractor/retractor.toml`, następnie `$XDG_CONFIG_HOME/retractor/retractor.toml` lub `~/.config/retractor/retractor.toml`. `xtrdb` nie ma opcji `--config`; przy niestandardowym katalogu blokad lub ustawieniu `storage.ref_dirs` należy umieścić te klucze w jednej z tych warstw.

---

## Otwieranie artefaktu

```
open nazwa_pliku
open nazwa_pliku { TYP pole TYP pole ... }
```

Jeśli plik `.desc` istnieje - schemat jest z niego odczytany. Jeśli nie istnieje - schemat należy podać w nawiasach `{}`.

Jeśli otwarcie pliku danych nie powiedzie się, `open` wypisuje przyczynę (np. `cannot open output file`) i pozostawia magazyn nieotwarty, zamiast kończyć proces. Gdy próba utworzyła nowy `.desc`, a otwarcie danych zawiodło, plik deskryptora jest usuwany. Po usunięciu przyczyny można ponowić `open`.

Pole `REF` w istniejącym `.desc` wskazuje plik danych i może prowadzić poza katalog ustawiony poleceniem `storage` - tak silnik opisuje zewnętrzne źródła `BINFILE`, `TEXTFILE` i `DEVICE`, które `xtrdb` czyta bez ograniczeń. Magazynu zapisywalnego (`DEFAULT`, `DIRECT`, `POSIX` i pozostałe) z `REF` poza tym katalogiem `open` nie otwiera: kończy się odmową z nazwą `.desc` i pliku, zanim plik zostanie utworzony. Taki zapis dopuszcza klucz `storage.ref_dirs` konfiguracji TOML - lista bezwzględnych ścieżek katalogów, w których `REF` z `.desc` może umieścić plik danych (patrz [opcje xretractor](xretractor.md#plik-konfiguracyjny-toml)). Niepoprawny wpis tej listy zatrzymuje start `xtrdb` błędem `Configuration error: storage.ref_dirs …`. `REF` podany w schemacie `open nazwa { … }` jest decyzją operatora i nie podlega temu ograniczeniu.

Tablicowe typy pól: `STRING name[8]` oznacza pole tekstowe o długości 8 bajtów (array multiplicity = 8).

Przykłady:

```
.open str1                          # schemat z pliku str1.desc
.open dump.tmp { INTEGER wartosc }  # schemat podany ręcznie
.open wyniki { INTEGER a FLOAT b STRING name[8] }
```

---

## Odczyt i zapis rekordów

| Polecenie | Opis                                                       |
| --------- | ---------------------------------------------------------- |
| `read N`  | Odczytaj rekord N (0-based) z pliku do bufora payload.     |
| `rread N` | Jak `read`, ale odczytuje od końca pliku (reverse read).   |
| `write N` | Zapisz bieżący payload do rekordu N w pliku.               |
| `append`  | Dołącz bieżący payload jako nowy rekord na końcu pliku.    |
| `purge`   | Usuń wszystkie rekordy z pliku (skróć plik do 0 rekordów). |

Indeks poza zakresem magazynu wynikowego, także pustego, jest odrzucany przed odczytem: `read` i `rread` wypisują `record out of range - read command`, pozostawiając payload i jego poprzedni stan bez zmian. `list` i `rlist` wypisują `record out of range - list command` i przechodzą do następnego indeksu. Jeżeli sprawdzenie zakresu przepuści żądanie, ale sam odczyt zwróci brak rekordu lub błąd, stan payloadu zmienia się na `error`; `list` i `rlist` wypisują wtedy `fetch error`. Dla źródeł deklarowanych `read` i `rread` pomijają wstępną kontrolę zakresu i korzystają z wyniku odczytu źródła. Stan można sprawdzić poleceniem `status`.

Udane `write N` lub `append` ustawia stan payloadu na `stored`. Próba `append` do zadeklarowanego źródła `BINFILE`, `TEXTFILE` albo `DEVICE`, które obsługuje tylko odczyt, ustawia stan `error`: dane źródła i liczba jego rekordów pozostają bez zmian, a `xtrdb` nadal przyjmuje polecenia. Stan payloadu raportowany przez `status` jest oddzielny od kodu zakończenia procesu; taka odmowa nie wymusza zakończenia z błędem. Pozostałe błędy zapisu, np. błąd wejścia/wyjścia, mogą zakończyć proces.

Kontrakt stanu zapisu i odmowy dopisania sprawdza test integracyjny `it_xtrdb_write_status-run`.

---

## Przeglądanie zawartości

| Polecenie | Opis                                                                     |
| --------- | ------------------------------------------------------------------------ |
| `list N`  | Wypisz N pierwszych rekordów (od początku), jeden wiersz = jeden rekord. |
| `rlist N` | Jak `list`, ale odczytuje od końca pliku.                                |
| `print`   | Wypisz bieżący payload w formacie wieloliniowym.                         |
| `printt`  | Wypisz bieżący payload w jednym wierszu.                                 |
| `size`    | Wypisz liczbę rekordów i rozmiar jednego rekordu w bajtach.              |
| `dump`    | Wypisz surowe bajty bieżącego payload w formacie hex.                    |
| `desc`    | Wypisz schemat pól otwartego artefaktu (wieloliniowy).                   |
| `descc`   | Wypisz schemat w jednym wierszu (compact).                               |

---

## Edycja payload

| Polecenie          | Opis                                                                               |
| ------------------ | ---------------------------------------------------------------------------------- |
| `set pole wartość` | Ustaw pole o podanej nazwie w buforze payload.                                     |
| `setpos N wartość` | Ustaw pole o indeksie N (0-based) w buforze payload.                               |
| `getpos N`         | Wypisz wartość pola o indeksie N z bieżącego payload.                              |
| `input`            | Interaktywne wypełnienie payload - wpisz wartości po kolei dla każdego pola.       |
| `status`           | Wypisz stan payload: `clean`, `fetched`, `changed`, `stored`, `error`.                      |
| `hex` / `dec`      | Przełącz format wejścia/wyjścia pól liczbowych między szesnastkowym a dziesiętnym. |

---

## Metadane null (`.meta`)

| Polecenie | Opis                                                                                                             |
| --------- | ---------------------------------------------------------------------------------------------------------------- |
| `meta`    | Wypisz indeks null i przerw w transmisji z pliku `.meta` - opisowo (segmenty z liczbą rekordów i wzorcem null).  |
| `metaraw` | Wypisz surową strukturę binarną pliku `.meta` - każdy wpis RLE z polami `count`, `gap`, `bitsetHex`.             |

`meta` wyświetli segmenty z informacją o brakach (`null`) i przerwach w transmisji (`gap`). `metaraw` pokaże surową strukturę binarną pliku `.meta`.

---

## Pozostałe polecenia

| Polecenie            | Opis                                                                                     |
| -------------------- | ---------------------------------------------------------------------------------------- |
| `rox`                | Przełącz flagę „remove on exit" - po zakończeniu narzędzia usuwa dane, `.desc`, `.meta`; plik danych spoza katalogu magazynu i `storage.ref_dirs` zostaje jak przy `quitdrop`. |
| `cap N`              | Ustaw pojemność bufora cofania (backread) dla urządzeń strumiennych.                     |
| `dropfile f1 f2 … }` | Usuń wymienione pliki. Lista kończy się tokenem `}`.                                     |
| `echo tekst`         | Wypisz tekst na terminal (przydatne w skryptach).                                        |
| `system polecenie`   | Wywołaj polecenie powłoki.                                                               |
| `#` lub `rem`        | Linia komentarza (ignorowana). `#` nie wypisuje nawet promptu.                           |

---

## Przykłady użycia

### Podgląd artefaktu

```
$ xtrdb
.storage temp
.open str1
.size
.list 10
.quit
```

### Odczyt pliku DUMP bez deskryptora

Pliki zrzutu tworzone przez `DO DUMP` nie mają pliku `.desc` - schemat należy podać ręcznie:

```
$ xtrdb
.open wyniki_alarm_dump.tmp { INTEGER wartosc }
.size
.list 6
.quit
```

Zrzut nie ma też pliku `.meta`, więc polecenia `meta` i `metaraw` nie mają w nim czego pokazać. Znaczy to, że wypisane wartości są wszystkim, co plik niesie: zero w zrzucie może być prawdziwym zerem, polem `NULL` albo rekordem, którego silnik nie miał, a przerwa w transmisji nie ma tam żadnego znacznika. Kontrakt zrzutu opisuje [Realizacja alarmowania](../../realizacja-zapytan/realizacja-alarowania.md#kontrakt-zrzutu-same-wartości-bez-null-i-bez-przerw).

### Skrypt wsadowy

```bash
xtrdb noprompt << 'EOF'
storage /var/retractor
open sensor_dump.tmp { INTEGER a FLOAT b }
list 20
quit
EOF
```

### Inspekcja metadanych null

```
.open str1
.meta
.metaraw
```
