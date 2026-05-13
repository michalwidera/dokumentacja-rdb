# Opcje wywołania

### xretractor

Program o nazwie xretractor jest podstawowym procesem przetwarzania danych. Możliwe jest wywołanie go bezpośrednio z powłoki. Przygotowany jest do uruchomienia autonomicznego jako proces demona systemd (proces rozwoju w toku).

Program xretractor ma dwa podstawowe tryby pracy. W pierwszym trybie kompiluje wskazany plik z zapytaniami i przechodzi do realizacji planu przetwarzania zapytań. W drugim trybie jedynie kompiluje i udostępnia narzędzia wizualizujące zbudowane plany realizacji zapytań.

Pierwszy tryb osiąga się poprzez wydanie polecenia bez opcji ‘onlycompile’ w drugi tryb wchodzimy dołączając do linii wywołania tą opcję.

Wywołanie listy pomocy z opcją -h przedstawia inną listę dla jednego i drugiego trybu. Należy zwrócić uwagę w którym trybie dana opcja funkcjonuje, gdyż skróty opcji się nakładają.

```
$ xretractor -h
xretractor - compiler & data processing tool.

Usage: xretractor queryfile [option]

Available options:
  -h [ --help ]               Show program options
  -c [ --onlycompile ]        compile only mode
  -q [ --queryfile ] arg      query set file
  -r [ --quiet ]              no output on screen, skip presenter
  -s [ --status ]             check service status
  -v [ --verbose ]            verbose mode (show stream params)
  -x [ --xqrywait ]           wait with processing for first query
  -k [ --noanykey ]           do not wait for any key to terminate
  -t [ --realtime ]           enable real-time scheduling (SCHED_FIFO, mlockall, absolute wakeup)
  -m [ --tlimitqry ] arg (=0) query limit, 0 - no limit
Branch: issue_31-doc:2707ce0, Code compiler: GNU Ver. 13.3.0, Build time: 2512211449, Type: Debug
Log: /tmp/xretractor.log
This software is licensed under the MIT License and is provided ‘as is’,
without warranty of any kind. For more information, see the LICENSE file.
```

Poniższa tabela przedstawia wyjaśnienie poszczególnych opcji.

<table data-header-hidden><thead><tr><th width="139" valign="top"></th><th valign="top"></th></tr></thead><tbody><tr><td valign="top">Opcja</td><td valign="top">Znaczenie</td></tr><tr><td valign="top">help</td><td valign="top">Wyświetlenie tekstu podpowiedzi. Różne dla opcji onlycompile lub bez</td></tr><tr><td valign="top">onlycompile</td><td valign="top">Przełączenie narzędzia w tryb ‘tylko kompilacja’. W tym trybie nie jest uruchamiania pętla realizacji zapytań.</td></tr><tr><td valign="top">queryfile</td><td valign="top">Nazwa pliku z danymi do kompilacji i uruchomienia</td></tr><tr><td valign="top">quiet</td><td valign="top">Pominięcie wyświetlania wyników na ekranie. Proces przetwarzania działa normalnie, jednak nie jest uruchamiany prezenter wyników.</td></tr><tr><td valign="top">status</td><td valign="top">Sprawdzenie czy inny proces xretractor nie funkcjonuje lub pozostawił po sobie pliki zabezpieczające wielokrotne uruchomienie.</td></tr><tr><td valign="top">verbose</td><td valign="top">Wprowadzenie procesu w tryb zwiększonej komunikatywności. Pozostałość po okresie rozwojowym. Potencjalnie zostanie zachowana.</td></tr><tr><td valign="top">xqrywait</td><td valign="top">Wprowadzenie systemu w tryb – skompiluj zapytania i poczekaj na pierwsze zapytanie z procesu xqry w celu uruchomienia pętli realizacji zapytań.</td></tr><tr><td valign="top">noanykey</td><td valign="top">Włączenie procesu xretractor w trybie – dowolny klawisz nie przerywa procesu przetwarzania danych. Bez tej opcji dowolny klawisz, przerwie pętlę realizacji zapytań.</td></tr><tr><td valign="top">realtime</td><td valign="top">Włączenie trybu szeregowania czasu rzeczywistego: SCHED_FIFO, mlockall i absolutne uśpienie wątku przetwarzającego. Wymaga uprawnień CAP_SYS_NICE i CAP_IPC_LOCK (lub root). Zalecane w środowisku produkcyjnym gdy wymagany jest deterministyczny czas reakcji.</td></tr><tr><td valign="top">tlimitqry</td><td valign="top">Ograniczenie ilościowe w pętli realizacji zapytań.</td></tr></tbody></table>

Druga lista przedstawia się następująco:

```
$ xretractor -h -c
xretractor - compiler & data processing tool.

Usage: xretractor -c queryfile [option]

Available options:
  -h [ --help ]          show help options
  -c [ --onlycompile ]   compile only mode
  -q [ --queryfile ] arg query set file
  -r [ --quiet ]         no output on screen, skip presenter
  -d [ --dot ]           create dot output
  -m [ --csv ]           create csv output
  -f [ --fields ]        show fields in dot file
  -t [ --tags ]          show tags in dot file
  -s [ --streamprogs ]   show stream programs in dot file
  -u [ --rules ]         show rules in dot file
  -i [ --hideruleprog ]  hide rule program in rules (-u) output
  -p [ --transparent ]   make dot background transparent
  -w [ --diagram ] arg   create diagram output
Branch: issue_31-doc:2707ce0, Code compiler: GNU Ver. 13.3.0, Build time: 2512211449, Type: Debug
Log: /tmp/xretractor.log
This software is licensed under the MIT License and is provided ‘as is’,
without warranty of any kind. For more information, see the LICENSE file.
```

Tutaj występują opcje związane z tworzeniem diagramów, wykresów lub zrzutów diagnostycznych szeroko wyjaśnianych w tym opracowaniu.

<table data-header-hidden><thead><tr><th width="137" valign="top"></th><th valign="top"></th></tr></thead><tbody><tr><td valign="top">Opcja</td><td valign="top">Znaczenie</td></tr><tr><td valign="top">help</td><td valign="top">Wyświetlenie tekstu podpowiedzi. Różne dla opcji onlycompile lub bez (podobnie jak w poprzedniej wersji)_</td></tr><tr><td valign="top">onlycompile</td><td valign="top">Przełączenie narzędzia w tryb ‘tylko kompilacja’. W tym trybie nie jest uruchamiania pętla realizacji zapytań. W tej tabeli przedstawiono opcje dla tej opcji włączonej.</td></tr><tr><td valign="top">queryfile</td><td valign="top">Nazwa pliku z danymi do kompilacji.</td></tr><tr><td valign="top">quiet</td><td valign="top"><p>W przypadku chęci przetestowania tylko procesu kompilacji, bez potrzeby prezentowania wyników należy użyć opcji quiet – „cisza”. Wewnątrz systemu zamieszczenie tej opcji powoduje, że reszta opcji związanych z prezentacją danych nie jest uruchamiana.</p><p>Ta opcja została dołączona dla celów rozwojowych.</p></td></tr><tr><td valign="top">dot</td><td valign="top">Proces xretractor w trakcie kompilacji tworzy hierarchiczne struktury danych. W celach prezentacji wytworzonych zależności możemy stworzyć po kompilacji plik tekstowy z którego można zbudować opisy graficzne. Opisy te są przekazywane do narzędzia Dot/Graphivz z którego można zbudować rysunki opisujące wytworzone zależności.</td></tr><tr><td valign="top">csv</td><td valign="top">Jeśli chcemy wytworzyć pliki opisujące wytworzone hierarchiczne struktury danych w postaci danych oddzielonych przecinkami. Należy użyć tej opcji.</td></tr><tr><td valign="top">fields</td><td valign="top">Dołączenie tej opcji spowoduje umieszczenie pól i ich typów w każdym tworzonym strumieniu danych.</td></tr><tr><td valign="top">tags</td><td valign="top">Dołączenie tej opcji spowoduje umieszczenie wytworzonych programów w wewnętrznym języku systemu tworzących pola poszczególnych zapytań. Ta opcja musi zostać wywołana z opcją fields. Gdyż wizualnie zostaną połączone pola z ich programami.</td></tr><tr><td valign="top">streamprogs</td><td valign="top">Dołączenie tej opcji spowoduje umieszczenie wytworzonych programów w wewnętrznym języku systemu tworzących strumienie poszczególnych zapytań. Przedstawione zostaną programy dla algebry strumieniowej.</td></tr><tr><td valign="top">rules</td><td valign="top">Dołączenie reguł alarmowania do wykresu</td></tr><tr><td valign="top">hideruleprog</td><td valign="top">Schowanie programów opisujących warunki alarmowania.</td></tr><tr><td valign="top">transparent</td><td valign="top">Wygenerowanie wykresu w wersji przeźroczystej</td></tr><tr><td valign="top">diagram</td><td valign="top">Wygenerowanie diagramów kulkowych. Diagramy kulkowe przyjmują argument w postaci typ:ilość_cykli.<br>Typ to 0 lub 1 – określa, czy diagramy prezentują znaczniki czasu,<br>Ilość_cykli – informuje ile cykli zaprezentować na diagramie kulkowym</td></tr></tbody></table>

Na dole linii znajduje się skrócona informacja o sposobie wytworzenia kodu.

```
Branch: issue_31-doc:2707ce0,
Code compiler: GNU Ver. 13.3.0,
Build time: 2512211449,
Type: Debug
```

Powyższa linia oznacza, że program został zbudowany na odnodze repozytorium o nazwie issue\_31-doc w pozycji oznaczonej kluczem 2707ce0. Skompilowano kod na maszynie wyposażonej w kompilator GCC GNU w wersji 13.3.0, 21 grudnia 2025 o godzinie 14:49. Kod skompilowano w trybie Debug.

Linia poniżej informuje, gdzie szukać logów uruchomienia – w tym przypadku plik tekstowy /tmp/xretractor.log przechowuje historię wywołania i procesów zachodzących wewnątrz systemu. Trzeba go sprzątać regularnie. W trakcie rozwoju oprogramowania pozwalam na jego ciągły wzrost.

Ostatnia linii to informacja o zastosowanej licencji dla tego kodu. Licencja MIT jest licencją umożliwiającą bezpieczne użycie kodu w zastosowaniach korporacyjnych.

### xqry

Program xqry jest integralną częścią systemu. Dzieli z systemem xretractor wspólny obszar w pamięci używany do komunikacji. Narzędzie xqry służy do komunikacji z procesem przetwarzania planów realizacji zapytań i odbierania danych z pętli zapytań.

Po wywołaniu programu za pomocą polecenia -h przedstawi się nam następujący obraz:

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
Branch: issue_31-doc:2707ce0, Code compiler: GNU Ver. 13.3.0, Build time: 2512211449, Type: Debug
Log: /tmp/xqry.log
This software is licensed under the MIT License and is provided ‘as is’,
without warranty of any kind. For more information, see the LICENSE file.
```

Poniższa tabela przestawia opisz poszczególnych opcji.

<table data-header-hidden><thead><tr><th width="140" valign="top"></th><th valign="top"></th></tr></thead><tbody><tr><td valign="top">Opcja</td><td valign="top">Znaczenie</td></tr><tr><td valign="top">select</td><td valign="top">Odebrania danych z danego strumienia udostępnianego przez proces xretractor</td></tr><tr><td valign="top">detail</td><td valign="top"><p>Przedstawienie szczegółów na temat danego strumienia danych.</p><p>Przykładowa odpowiedź:</p><p><code>---</code><br><code>apiVersion: xqry/v1</code><br><code>stream:</code><br><code>name: str4</code><br><code>delta: 1</code><br><code>query: SELECT (str4[0]+1)*2 STREAM str4 FROM core0>1</code><br><code>fields:</code><br><code>str4.str4_0:</code><br><code>type: INTEGER</code></p></td></tr><tr><td valign="top">adhoc</td><td valign="top">Dołączenie zapytania do systemu w biegu</td></tr><tr><td valign="top">tlimitqry</td><td valign="top">Ograniczenie ilościowe odbieranych od systemu rezultatów. Bardzo potrzebna funkcjonalność w złączeniu z opcją -k do celów testowych</td></tr><tr><td valign="top">hello</td><td valign="top">Weryfikacja funkcji kanału komunikacyjnego z systemem</td></tr><tr><td valign="top">kill</td><td valign="top">Żądanie zatrzymania działania procesu xretractor</td></tr><tr><td valign="top">dir</td><td valign="top">Wylistowanie wszystkich zapytań realizowanych w procesie realizacji zapytań przez system xretractor w formie tekstowej</td></tr><tr><td valign="top">diryaml</td><td valign="top">Wylistowanie wszystkich zapytań realizowanych w procesie realizacji zapytań przez system xretractor w formacie yaml</td></tr><tr><td valign="top">raw</td><td valign="top">Tryb tekstowy odpowiedzi systemu. Dane prezentowane są bez zbędnych dekoracji</td></tr><tr><td valign="top">graphite</td><td valign="top">Tryb odpowiedzi przygotowujący dane dla systemu graphite</td></tr><tr><td valign="top">influxdb</td><td valign="top">Tryb odpowiedzi przygotowujący dane dla systemu influxdb</td></tr><tr><td valign="top">gnuplot</td><td valign="top">Przygotowanie agregatów dla bezpośredniego wywoływania strumienia danych dla programu gnuplot</td></tr><tr><td valign="top">help</td><td valign="top">Wyświetlenie tekstu pomocy</td></tr><tr><td valign="top">needctrlc</td><td valign="top">W normlanym trybie pracy – dowolny klawisz zatrzyma proces odbioru danych. W tym trybie, konieczne jest użycie ctrl+c</td></tr></tbody></table>

Informacje poniżej listy dostępnych opcji narzędzia są identyczne z tymi opisywanymi w poprzednim załączniku dla narzędzia xretractor.

### xtrdb

Program `xtrdb` to interaktywne narzędzie do analizy artefaktów i substratów zapisanych przez system RetractorDB. W odróżnieniu od `xretractor` i `xqry` nie przyjmuje flag wiersza poleceń z opisem zapytań — zamiast tego pracuje w trybie interaktywnym (REPL), odczytując polecenia ze standardowego wejścia.

{% hint style="warning" %}
Wywołanie `xtrdb` blokuje uruchomiony równolegle `xretractor` — przed użyciem `xtrdb` zatrzymaj serwer lub poczekaj na zakończenie pracy systemu. Narzędzie samo wykrywa blokadę i zgłosi błąd jeśli `xretractor` działa.
{% endhint %}

#### Uruchomienie

```
$ xtrdb           # tryb interaktywny (z promptem)
$ xtrdb noprompt  # tryb wsadowy (bez promptu, bez kolorów — wygodny w skryptach)
$ xtrdb -h        # wyświetl informacje o wersji i zakończ
```

Tryb `noprompt` usuwa kolorowanie i prompt `.` — przydatny gdy wejście pochodzi z pliku lub potoku:

```
$ xtrdb noprompt < script.xtrdb
```

#### Polecenia interaktywne

Po uruchomieniu narzędzie wypisuje prompt `.` i czeka na polecenie. Każde polecenie kończy się naciśnięciem Enter. Polecenie `help` lub `h` wyświetla listę dostępnych poleceń:

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

#### Zarządzanie sesją

| Polecenie           | Opis                                                             |
| ------------------- | ---------------------------------------------------------------- |
| `exit`, `quit`, `q` | Zakończ narzędzie. Dane niezapisane w bazie pozostają na dysku.  |
| `quitdrop`, `qd`    | Zakończ i usuń otwarte pliki artefaktu (dane, `.desc`, `.meta`). |

#### Konfiguracja

| Polecenie           | Opis                                                                                       |
| ------------------- | ------------------------------------------------------------------------------------------ |
| `storage [ścieżka]` | Ustaw katalog roboczy. Kolejne `open` szuka pliku w tej ścieżce.                           |
| `policy [nazwa]`    | Ustaw politykę przechowywania (DEFAULT, DIRECT, POSIX, MEMORY, …). Musi poprzedzać `open`. |

#### Otwieranie pliku

```
open nazwa_pliku
open nazwa_pliku { TYP pole TYP pole ... }
```

Jeśli plik `.desc` istnieje — schemat jest z niego odczytany. Jeśli nie istnieje — schemat należy podać w nawiasach `{}`. Przykłady:

```
.open str1                          # schemat z pliku str1.desc
.open dump.tmp { INTEGER wartosc }  # schemat podany ręcznie
.open wyniki { INTEGER a FLOAT b STRING name[8] }
```

Tablicowe typy pól: `STRING name[8]` oznacza pole tekstowe o długości 8 bajtów (array multiplicity = 8).

#### Odczyt i zapis rekordów

| Polecenie | Opis                                                       |
| --------- | ---------------------------------------------------------- |
| `read N`  | Odczytaj rekord N (0-based) z pliku do bufora payload.     |
| `rread N` | Jak `read`, ale odczytuje od końca pliku (reverse read).   |
| `write N` | Zapisz bieżący payload do rekordu N w pliku.               |
| `append`  | Dołącz bieżący payload jako nowy rekord na końcu pliku.    |
| `purge`   | Usuń wszystkie rekordy z pliku (skróć plik do 0 rekordów). |

#### Przeglądanie zawartości

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

#### Edycja payload

| Polecenie          | Opis                                                                               |
| ------------------ | ---------------------------------------------------------------------------------- |
| `set pole wartość` | Ustaw pole o podanej nazwie w buforze payload.                                     |
| `setpos N wartość` | Ustaw pole o indeksie N (0-based) w buforze payload.                               |
| `getpos N`         | Wypisz wartość pola o indeksie N z bieżącego payload.                              |
| `input`            | Interaktywne wypełnienie payload — wpisz wartości po kolei dla każdego pola.       |
| `status`           | Wypisz stan payload: `clean`, `fetched`, `changed`, `stored`.                      |
| `hex` / `dec`      | Przełącz format wejścia/wyjścia pól liczbowych między szesnastkowym a dziesiętnym. |

#### Metadane null (`.meta`)

| Polecenie | Opis                                                                                                            |
| --------- | --------------------------------------------------------------------------------------------------------------- |
| `meta`    | Wypisz indeks null i przerw w transmisji z pliku `.meta` — opisowo (segmenty z liczbą rekordów i wzorcem null). |
| `metaraw` | Wypisz surową strukturę binarną pliku `.meta` — każdy wpis RLE z polami `count`, `gap`, `bitsetHex`.            |

#### Pozostałe

| Polecenie            | Opis                                                                                     |
| -------------------- | ---------------------------------------------------------------------------------------- |
| `rox`                | Przełącz flagę „remove on exit" — po zakończeniu narzędzia usuwa dane, `.desc`, `.meta`. |
| `cap N`              | Ustaw pojemność bufora cofania (backread) dla urządzeń strumiennych.                     |
| `dropfile f1 f2 … }` | Usuń wymienione pliki. Lista kończy się tokenem `}`.                                     |
| `echo tekst`         | Wypisz tekst na terminal (przydatne w skryptach).                                        |
| `system polecenie`   | Wywołaj polecenie powłoki.                                                               |
| `#` lub `rem`        | Linia komentarza (ignorowana). `#` nie wypisuje nawet promptu.                           |

#### Przykłady użycia

* Podgląd artefaktu

```
$ xtrdb
.storage temp
.open str1
.size
.list 10
.quit
```

* Odczyt pliku DUMP bez deskryptora

Pliki zrzutu tworzone przez `DO DUMP` nie mają pliku `.desc` — schemat należy podać ręcznie:

```
$ xtrdb
.open wyniki_alarm_dump.tmp { INTEGER wartosc }
.size
.list 6
.quit
```

* Skrypt wsadowy

```bash
xtrdb noprompt << 'EOF'
storage /var/retractor
open sensor_dump.tmp { INTEGER a FLOAT b }
list 20
quit
EOF
```

* Inspekcja metadanych null

```
.open str1
.meta
.metaraw
```

`meta` wyświetli segmenty z informacją o brakach (`null`) i przerwach w transmisji (`gap`). `metaraw` pokaże surową strukturę binarną pliku `.meta` z polami `count`, `gap` i `bitsetHex`.
