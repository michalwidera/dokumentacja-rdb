# xretractor

Program `xretractor` jest podstawowym procesem systemu RetractorDB. Kompiluje pliki z zapytaniami RQL i realizuje plan przetwarzania danych. Przygotowany jest do uruchomienia autonomicznego jako proces demona systemd.

## Tryby pracy

`xretractor` uruchamia się w jednym z dwóch trybów:

| Tryb                     | Opis                                                                  |
| ------------------------ | --------------------------------------------------------------------- |
| **Przetwarzania**        | Domyślny — kompiluje zapytania i uruchamia pętlę realizacji zapytań   |
| **Tylko kompilacja** `-c` | Kompiluje zapytania bez uruchamiania pętli; umożliwia wizualizację planu |

Wywołanie `-h` pokazuje inną listę opcji w zależności od trybu — skróty opcji się nakładają, dlatego należy zwrócić uwagę, w którym trybie dana opcja funkcjonuje.

---

## Tryb przetwarzania (domyślny)

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
  -t [ --realtime ]           enable real-time scheduling (SCHED_FIFO, mlockall,
>> absolute wakeup)
  -m [ --tlimitqry ] arg (=0) query limit, 0 - no limit
```

### Opcje trybu przetwarzania

| Opcja | Znaczenie |
| ----- | --------- |
| `help` | Wyświetlenie tekstu podpowiedzi. Lista różni się w zależności od trybu (z `-c` lub bez). |
| `onlycompile` | Przełączenie narzędzia w tryb „tylko kompilacja". Pętla realizacji zapytań nie jest uruchamiana. |
| `queryfile` | Nazwa pliku z zapytaniami do kompilacji i uruchomienia. |
| `quiet` | Pominięcie wyświetlania wyników na ekranie. Przetwarzanie działa normalnie, ale prezenter wyników nie jest uruchamiany. |
| `status` | Sprawdzenie, czy inny proces `xretractor` jest uruchomiony lub pozostawił pliki blokujące wielokrotne uruchomienie. |
| `verbose` | Tryb zwiększonej komunikatywności — wyświetla parametry strumieni. Pozostałość po fazie rozwojowej; prawdopodobnie zostanie zachowana. |
| `xqrywait` | Kompiluje zapytania i wstrzymuje pętlę przetwarzania do chwili nadejścia pierwszego zapytania z procesu `xqry`. Wymagane przy jednoczesnym użyciu `-m N` w skryptach i testach: bez tej flagi serwer może przetworzyć wszystkie N cykli zanim klient zdąży się podłączyć, co skutkuje brakiem danych i oczekiwaniem po stronie `xqry` aż do przekroczenia limitu czasowego. Pierwsze polecenie odebrane od `xqry` (np. `-d` lub `-s`) odblokowuje pętlę przetwarzania. |
| `noanykey` | Dowolny klawisz nie przerywa pętli przetwarzania. Bez tej opcji naciśnięcie dowolnego klawisza zatrzymuje system. |
| `realtime` | Włącza szeregowanie czasu rzeczywistego: `SCHED_FIFO`, `mlockall` i absolutne uśpienie wątku przetwarzającego. Wymaga uprawnień `CAP_SYS_NICE` i `CAP_IPC_LOCK` (lub root). Zalecane w środowisku produkcyjnym przy wymogu deterministycznego czasu reakcji. |
| `tlimitqry` | Ogranicza liczbę iteracji w pętli realizacji zapytań. Wartość `0` oznacza brak limitu. |

---

## Tryb tylko kompilacja (`-c`)

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
```

W tym trybie dostępne są opcje tworzenia diagramów i zrzutów diagnostycznych opisywanych szerzej w opracowaniu.

### Opcje wizualizacji i diagnostyki

| Opcja | Znaczenie    |
| ----- | ------------ |
| `help` | Wyświetlenie tekstu podpowiedzi (identycznie jak w trybie przetwarzania, lista różni się w zależności od trybu). |
| `onlycompile` | Włączony — w tej tabeli opisano opcje obowiązujące przy aktywnej fladze `-c`. |
| `queryfile` | Nazwa pliku z zapytaniami do kompilacji. |
| `quiet` | Testowanie samego procesu kompilacji bez prezentowania wyników. Pozostałe opcje prezentacji nie są uruchamiane. Opcja dołączona na potrzeby rozwojowe. |
| `dot` | Tworzy plik tekstowy w formacie DOT opisujący hierarchiczne struktury wytworzone przez kompilator. Plik można przekazać do narzędzia Graphviz w celu wygenerowania graficznego opisu zależności. |
| `csv` | Eksportuje hierarchiczne struktury danych do pliku CSV (wartości oddzielone przecinkami). |
| `fields` | Dołącza do wykresu DOT pola i ich typy dla każdego strumienia danych. |
| `tags` | Dołącza do wykresu DOT programy wewnętrznego języka systemu, które tworzą pola poszczególnych zapytań. Musi być wywołana razem z `fields` — wizualnie łączy pola z ich programami. |
| `streamprogs` | Dołącza do wykresu DOT programy algebry strumieniowej tworzące poszczególne strumienie zapytań. |
| `rules` | Dołącza reguły alarmowania do wykresu. |
| `hideruleprog` | Ukrywa programy opisujące warunki alarmowania (używane razem z `rules`). |
| `transparent` | Generuje wykres z przezroczystym tłem. |
| `diagram` | Generuje diagramy kulkowe. Argument w postaci `typ:ilość_cykli`: `typ` (`0` lub `1`) określa, czy diagramy prezentują znaczniki czasu; `ilość_cykli` określa liczbę cykli na diagramie. |

---

## Informacje o wersji

Na końcu każdego komunikatu pomocy wyświetlana jest linia z informacjami o buildzie:

```
Branch: issue_31-doc:2707ce0,
Code compiler: GNU Ver. 13.3.0,
Build time: 2512211449,
Type: Debug
```

| Pole             | Znaczenie                                                                              |
| ---------------- | -------------------------------------------------------------------------------------- |
| `Branch`         | Nazwa odnogi repozytorium i skrót commita (hash), z którego zbudowano program          |
| `Code compiler`  | Wersja kompilatora GCC użytego do budowy                                               |
| `Build time`     | Data i godzina kompilacji w formacie `YYMMDDHHММ` (tu: 21 grudnia 2025, godz. 14:49)  |
| `Type`           | Typ buildu: `Debug` lub `Release`                                                      |

Kolejna linia wskazuje lokalizację pliku dziennika:

```
Log: /tmp/xretractor.log
```

Plik `/tmp/xretractor.log` rejestruje historię wywołań i zdarzeń wewnętrznych systemu. W środowisku produkcyjnym należy zadbać o regularne czyszczenie lub rotację tego pliku.

Ostatnia linia zawiera informację o licencji MIT, która umożliwia bezpieczne użycie kodu w zastosowaniach korporacyjnych.
