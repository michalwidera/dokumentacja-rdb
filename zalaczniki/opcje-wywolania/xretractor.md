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
  -t [ --realtime ]           enable real-time scheduling (SCHED_FIFO, mlockall, absolute wakeup)
  -m [ --tlimitqry ] arg (=0) query limit, 0 - no limit
```

### Opcje trybu przetwarzania

<table data-header-hidden><thead><tr><th width="150" valign="top">Opcja</th><th valign="top">Znaczenie</th></tr></thead><tbody>
<tr><td valign="top"><code>help</code></td><td valign="top">Wyświetlenie tekstu podpowiedzi. Lista różni się w zależności od trybu (z <code>-c</code> lub bez).</td></tr>
<tr><td valign="top"><code>onlycompile</code></td><td valign="top">Przełączenie narzędzia w tryb „tylko kompilacja". Pętla realizacji zapytań nie jest uruchamiana.</td></tr>
<tr><td valign="top"><code>queryfile</code></td><td valign="top">Nazwa pliku z zapytaniami do kompilacji i uruchomienia.</td></tr>
<tr><td valign="top"><code>quiet</code></td><td valign="top">Pominięcie wyświetlania wyników na ekranie. Przetwarzanie działa normalnie, ale prezenter wyników nie jest uruchamiany.</td></tr>
<tr><td valign="top"><code>status</code></td><td valign="top">Sprawdzenie, czy inny proces <code>xretractor</code> jest uruchomiony lub pozostawił pliki blokujące wielokrotne uruchomienie.</td></tr>
<tr><td valign="top"><code>verbose</code></td><td valign="top">Tryb zwiększonej komunikatywności — wyświetla parametry strumieni. Pozostałość po fazie rozwojowej; prawdopodobnie zostanie zachowana.</td></tr>
<tr><td valign="top"><code>xqrywait</code></td><td valign="top">Kompiluje zapytania i wstrzymuje pętlę przetwarzania do chwili nadejścia pierwszego zapytania z procesu <code>xqry</code>.</td></tr>
<tr><td valign="top"><code>noanykey</code></td><td valign="top">Dowolny klawisz nie przerywa pętli przetwarzania. Bez tej opcji naciśnięcie dowolnego klawisza zatrzymuje system.</td></tr>
<tr><td valign="top"><code>realtime</code></td><td valign="top">Włącza szeregowanie czasu rzeczywistego: <code>SCHED_FIFO</code>, <code>mlockall</code> i absolutne uśpienie wątku przetwarzającego. Wymaga uprawnień <code>CAP_SYS_NICE</code> i <code>CAP_IPC_LOCK</code> (lub root). Zalecane w środowisku produkcyjnym przy wymogu deterministycznego czasu reakcji.</td></tr>
<tr><td valign="top"><code>tlimitqry</code></td><td valign="top">Ogranicza liczbę iteracji w pętli realizacji zapytań. Wartość <code>0</code> oznacza brak limitu.</td></tr>
</tbody></table>

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

<table data-header-hidden><thead><tr><th width="150" valign="top">Opcja</th><th valign="top">Znaczenie</th></tr></thead><tbody>
<tr><td valign="top"><code>help</code></td><td valign="top">Wyświetlenie tekstu podpowiedzi (identycznie jak w trybie przetwarzania, lista różni się w zależności od trybu).</td></tr>
<tr><td valign="top"><code>onlycompile</code></td><td valign="top">Włączony — w tej tabeli opisano opcje obowiązujące przy aktywnej fladze <code>-c</code>.</td></tr>
<tr><td valign="top"><code>queryfile</code></td><td valign="top">Nazwa pliku z zapytaniami do kompilacji.</td></tr>
<tr><td valign="top"><code>quiet</code></td><td valign="top">Testowanie samego procesu kompilacji bez prezentowania wyników. Pozostałe opcje prezentacji nie są uruchamiane. Opcja dołączona na potrzeby rozwojowe.</td></tr>
<tr><td valign="top"><code>dot</code></td><td valign="top">Tworzy plik tekstowy w formacie DOT opisujący hierarchiczne struktury wytworzone przez kompilator. Plik można przekazać do narzędzia Graphviz w celu wygenerowania graficznego opisu zależności.</td></tr>
<tr><td valign="top"><code>csv</code></td><td valign="top">Eksportuje hierarchiczne struktury danych do pliku CSV (wartości oddzielone przecinkami).</td></tr>
<tr><td valign="top"><code>fields</code></td><td valign="top">Dołącza do wykresu DOT pola i ich typy dla każdego strumienia danych.</td></tr>
<tr><td valign="top"><code>tags</code></td><td valign="top">Dołącza do wykresu DOT programy wewnętrznego języka systemu, które tworzą pola poszczególnych zapytań. Musi być wywołana razem z <code>fields</code> — wizualnie łączy pola z ich programami.</td></tr>
<tr><td valign="top"><code>streamprogs</code></td><td valign="top">Dołącza do wykresu DOT programy algebry strumieniowej tworzące poszczególne strumienie zapytań.</td></tr>
<tr><td valign="top"><code>rules</code></td><td valign="top">Dołącza reguły alarmowania do wykresu.</td></tr>
<tr><td valign="top"><code>hideruleprog</code></td><td valign="top">Ukrywa programy opisujące warunki alarmowania (używane razem z <code>rules</code>).</td></tr>
<tr><td valign="top"><code>transparent</code></td><td valign="top">Generuje wykres z przezroczystym tłem.</td></tr>
<tr><td valign="top"><code>diagram</code></td><td valign="top">Generuje diagramy kulkowe. Argument w postaci <code>typ:ilość_cykli</code>: <code>typ</code> (<code>0</code> lub <code>1</code>) określa, czy diagramy prezentują znaczniki czasu; <code>ilość_cykli</code> określa liczbę cykli na diagramie.</td></tr>
</tbody></table>

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
