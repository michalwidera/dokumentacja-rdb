# Załącznik A – opcje wywołania xretractor

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

&#x20;

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

&#x20;

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
