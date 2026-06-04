# xtrdb

Program `xtrdb` to interaktywne narzędzie do analizy artefaktów i substratów zapisanych przez system RetractorDB. Pracuje głównie w trybie interaktywnym (REPL), ale udostępnia także kilka opcji uruchomienia (np. `--help`, `--noprompt`, `--storagemap`).

> **⚠️ Ostrzeżenie**
>
> Wywołanie `xtrdb` blokuje uruchomiony równolegle `xretractor` — przed użyciem `xtrdb` zatrzymaj serwer lub poczekaj na zakończenie pracy systemu. Narzędzie samo wykrywa blokadę i zgłosi błąd, jeśli `xretractor` działa.


---

## Uruchomienie

```
$ xtrdb                    # tryb interaktywny (z promptem)
$ xtrdb -n                 # tryb wsadowy (bez promptu i bez "ok")
$ xtrdb --noprompt         # to samo co -n
$ xtrdb noprompt           # zgodność wsteczna (legacy, argument pozycyjny)
$ xtrdb -s plik_danych     # pokaż strukturę storage dla wskazanego pliku i zakończ
$ xtrdb --storagemap plik  # to samo co -s
$ xtrdb -h                 # help i informacje o buildzie, potem zakończ
```

Tryb `-n/--noprompt` usuwa kolorowanie, prompt `.` i komunikat `ok` — przydatny, gdy wejście pochodzi z pliku lub potoku.
Wciąż działa też historyczny wariant pozycyjny `noprompt`.

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
                                example: .open test_db { INTEGER dane STRING name[3] }
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
| `exit`, `quit`, `q` | Zakończ narzędzie. Dane niezapisane w bazie pozostają na dysku.  |
| `quitdrop`, `qd`    | Zakończ i usuń otwarte pliki artefaktu (dane, `.desc`, `.meta`). |

---

## Konfiguracja środowiska

| Polecenie           | Opis                                                                                        |
| ------------------- | ------------------------------------------------------------------------------------------- |
| `storage [ścieżka]` | Ustaw katalog roboczy. Kolejne polecenie `open` szuka pliku w tej ścieżce.                  |
| `policy [nazwa]`    | Ustaw politykę przechowywania (`DEFAULT`, `DIRECT`, `POSIX`, `MEMORY`, …). Musi poprzedzać `open`. |

---

## Otwieranie artefaktu

```
open nazwa_pliku
open nazwa_pliku { TYP pole TYP pole ... }
```

Jeśli plik `.desc` istnieje — schemat jest z niego odczytany. Jeśli nie istnieje — schemat należy podać w nawiasach `{}`.

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
| `input`            | Interaktywne wypełnienie payload — wpisz wartości po kolei dla każdego pola.       |
| `status`           | Wypisz stan payload: `clean`, `fetched`, `changed`, `stored`.                      |
| `hex` / `dec`      | Przełącz format wejścia/wyjścia pól liczbowych między szesnastkowym a dziesiętnym. |

---

## Metadane null (`.meta`)

| Polecenie | Opis                                                                                                             |
| --------- | ---------------------------------------------------------------------------------------------------------------- |
| `meta`    | Wypisz indeks null i przerw w transmisji z pliku `.meta` — opisowo (segmenty z liczbą rekordów i wzorcem null).  |
| `metaraw` | Wypisz surową strukturę binarną pliku `.meta` — każdy wpis RLE z polami `count`, `gap`, `bitsetHex`.             |

`meta` wyświetli segmenty z informacją o brakach (`null`) i przerwach w transmisji (`gap`). `metaraw` pokaże surową strukturę binarną pliku `.meta`.

---

## Pozostałe polecenia

| Polecenie            | Opis                                                                                     |
| -------------------- | ---------------------------------------------------------------------------------------- |
| `rox`                | Przełącz flagę „remove on exit" — po zakończeniu narzędzia usuwa dane, `.desc`, `.meta`. |
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

Pliki zrzutu tworzone przez `DO DUMP` nie mają pliku `.desc` — schemat należy podać ręcznie:

```
$ xtrdb
.open wyniki_alarm_dump.tmp { INTEGER wartosc }
.size
.list 6
.quit
```

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
