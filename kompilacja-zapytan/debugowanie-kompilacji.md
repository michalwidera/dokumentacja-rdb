# Debugowanie kompilacji

Kompilator transformuje plik `.rql` w plan wykonania przez kilka etapów. Efekt każdego etapu jest widoczny przez flagi diagnostyczne `xretractor`. Opisane tutaj narzędzia pozwalają odpowiedzieć na pytania: dlaczego schemat wygląda inaczej niż napisałem? skąd ta delta? dlaczego pojawił się substrat?

## Podstawowe narzędzie: flaga `-c`

Flaga `-c` (`--onlycompile`) zatrzymuje `xretractor` po kompilacji i drukuje skompilowany plan na standardowe wyjście - bez uruchamiania przetwarzania:

```bash
xretractor -c query.rql
```

Kod wyjścia `0` oznacza sukces. Odmowa błędnego planu przez parser lub kompilator zwraca `EPROTO`, czyli `71` na Linuksie. Inne niepowodzenia, np. brak samego pliku `.rql` albo błąd wewnętrzny, mogą mieć inne kody; w skrypcie sprawdzaj każdy wynik różny od zera. Komunikaty błędów trafiają na stderr:

```bash
xretractor -c query.rql >plan.txt 2>errors.txt
status=$?
printf 'exit=%s\n' "$status"
cat errors.txt
```

Kompilację można wywołać nawet gdy inny proces `xretractor` już działa - flaga `-c` nie próbuje przejąć blokady wykonania.

Zapisz kod wyjścia od razu: po `cat` zmienna `$?` dotyczyłaby odczytu pliku, nie kompilacji. Przy odmowie `plan.txt` nie jest gotowym planem. Wczesne komunikaty programu, takie jak `fatal error: no input file`, mogą trafić na stdout; dlatego zachowuj oba pliki.

## Ustal etap odmowy

| Komunikat lub sytuacja | Etap i następny krok |
| --- | --- |
| `fatal error: no input file`, `file ... does not exist`, `Error: Unable to open file!` | Nie wczytano pliku RQL. Sprawdź argument programu, katalog roboczy i dostęp do samego pliku planu. |
| `fatal error: no queries to process` | `-c` nie znalazło planu do kompilacji, np. w pliku zawierającym wyłącznie komentarze. Zwykły start bez instrukcji może działać bezczynnie. |
| `Syntax error @Rql`, `Parse result:...` | Odmowa parsera. Sprawdź pierwszy błąd, pozycję i wskazany plik. |
| `Check result:...` | Odmowa kompilatora, a podczas zwykłego startu także błąd planu wykryty przy inicjalizacji. Odczytaj dalszy tekst; sam przedrostek nie określa poprawki. |
| `Fail parse:`, `Fail local chain compiler:`, `Fail compile:`, `Rejected:` | Odpowiedź na żądanie ad hoc lub reset. Sprawdź przyczynę i ograniczenia tego kanału. |
| `FATAL: internal compiler error: ...`, `engine error: ...` | Diagnostyka defektu silnika. Zapisz minimalny plan, pełny komunikat i informacje o buildzie. |

Przykłady błędnych i poprawionych zapytań zawiera katalog [Błędy składni i kompilacji](../konstrukcja-jezyka-zapytan/bledy-skladni-i-kompilacji.md). Po usunięciu pierwszej przyczyny ponów sprawdzenie; kompilator kończy pracę na pierwszej odmowie, więc następna może pochodzić z innego przebiegu.

## Jak czytać plan kompilacji

Dla kanonicznego `query.rql` z tego rozdziału plan wygląda następująco:

```rasm
{{#include ../regen/out/debug.txt}}
```

Blok strumienia obliczanego ma następujący format; nawiasy kwadratowe oznaczają opcjonalne adnotacje i nie są częścią wydruku:

```rasm
nazwaStrumienia(delta) [tail=W] [origin=O]
        :- operacjaStrumieniowa(arg)
        nazwaPolaWyjściowego: TYP
                instrukcja
                ...
```

| Element | Znaczenie |
|---------|-----------|
| `nazwaStrumienia(delta)` | Nazwa strumienia i jego interwał jako ułamek: `1/10` = 0.1 s = 10 Hz |
| `tail=W` | Ogon: opóźnienie dostępności rekordu, wyrażone w slotach tego strumienia |
| `origin=O` | Początek logiczny: indeks pierwszego istniejącego rekordu; rekordy o mniejszych indeksach nie mają definicji |
| `:- PUSH_STREAM(x)` | Pcha strumień `x` na stos strumieniowy; pojawia się raz na każdy argument FROM |
| `:- STREAM_ADD` | Operator sumy strumieni (`+` w FROM) |
| `:- STREAM_HASH` | Operator przeplotu strumieni (`#` w FROM) |
| `:- STREAM_TIMEMOVE(n)` | Przesunięcie w czasie (`>n` w FROM) |
| `pole: TYP` | Pole schematu wynikowego po równaniu typów w górę |
| `PUSH_ID(s[n])` | Odkłada na stos wartość pola `n` ze strumienia `s` - tu widoczny efekt aliasowania |
| `PUSH_VAL(x)` | Odkłada stałą `x` na stos |
| `ADD`, `MULTIPLY`, ... | Operacja arytmetyczna: zdejmuje dwa argumenty ze stosu, odkłada wynik |

Adnotacje `tail` i `origin` są wypisywane tylko dla wartości dodatnich; brak danej adnotacji oznacza zero. Jeśli obie występują, `tail` poprzedza `origin`. Szczegóły obu wielkości opisuje rozdział [Ogony, początki logiczne i obserwowalność operatorów](../podstawy-matematyczne/ogony-i-obserwowalnosc-operatorow.md).

Plan jest uporządkowany topologicznie: każdy producent występuje przed strumieniami, które z niego korzystają. Bloki efemerydów (`DECLARE`) zawierają listę pól i ścieżkę do pliku danych.

**Aliasowanie w planie**: jeśli dwa pola wyjściowe wskazują na ten sam `PUSH_ID`, są aliasami. W przykładzie `result_0` i `result_2` oba to `PUSH_ID(merged[0])` - potwierdzenie, że `merged[0]` i `core0[0]` to ta sama pozycja. Patrz [Aliasowanie](aliasowanie.md).

**Substraty w planie**: automatycznie wygenerowany substrat pojawia się jako blok z nazwą w stylu `STREAM_HASH_core0_core1` - bez odpowiadającego `SELECT` w pliku źródłowym. Patrz [Substraty](substraty.md).

## Wizualizacja grafu zależności

Zamiast tekstu można wygenerować graf w formacie DOT i przetworzyć przez `graphviz`:

```bash
xretractor -c -d -f -t -s query.rql > out.dot && dot -Tsvg out.dot -o out.svg
```

Dostępne flagi modyfikujące wyjście DOT:

| Flaga | Pełna nazwa     | Znaczenie |
|-------|-----------------|-----------|
| `-d`  | `--dot`         | generuj wyjście DOT zamiast tekstowego planu |
| `-f`  | `--fields`      | pokaż pola strumieni w węzłach grafu |
| `-t`  | `--tags`        | pokaż programy poszczególnych pól (`-f`) |
| `-s`  | `--streamprogs` | pokaż sekwencje instrukcji stosu w węzłach |
| `-u`  | `--rules`       | pokaż reguły RULE |
| `-p`  | `--transparent` | przezroczyste tło - do osadzania w dokumentach |

Graf pokazuje zależności między strumieniami jako krawędzie skierowane od źródeł do wyników. Substraty mają inny kolor niż strumienie jawnie zdefiniowane przez użytkownika. Patrz [Budowa drzewa zależności](budowa-drzewa-zaleznosci.md).

Wyjście DOT powstaje dopiero po **udanej kompilacji**. `-d` nie pokazuje częściowego grafu odrzuconego planu. Uruchamiaj `dot` przez `&&`, jak powyżej, aby odmowa kompilacji nie prowadziła do przetwarzania pustego lub niekompletnego pliku.

> **_NOTE:_** Opisana funkcjonalność ma pokrycie w teście: `issue31_doc` opisanym w załączniku pt. [Testy Integracyjne](../zalaczniki/testy-integracyjne.md).

## Weryfikacja interwałów

Jeśli delta strumienia wynikowego jest niespodziewana:

1. Sprawdź delty strumieni źródłowych - widoczne w blokach DECLARE przed ich konsumentami.
2. Sprawdź operator w klauzuli FROM - każdy operator ma inne równanie na deltę.

Przykład: `core0(1/10) # core1(1/5)` daje deltę `1/15`: częstości wejść sumują się (`10 Hz + 5 Hz = 15 Hz`), więc interwał wynosi `a*b/(a+b)`. Suma `core0 + core1` daje tu deltę `1/10`, ale również łączy pola obu wejść w jednym rekordzie; przeplot `#` wybiera rekord jednej ze składowych. Dobierz operator także do oczekiwanego schematu i wartości. Pełne równania - patrz [Rozwiązywanie interwałów](rozwiazywanie-interwalow.md).

## Typowe błędy kompilacji

### Niepoprawny literal lub interwał

Liczba spoza zakresu typu docelowego kończy parsowanie komunikatem `numeric literal ... is out of range` w `Parse result:`. Zerowy mianownik daje `fraction ... has a zero denominator`, a interwał równy zero - `interval ... must be greater than zero`. Dotyczy to zarówno pliku startowego, jak i żądania ad hoc; w drugim przypadku odmowa nie zatrzymuje serwera. Popraw liczbę lub wybierz dodatni interwał. Sam komunikat `Circular dependency` oznacza cykl zależności, a nie zerowy interwał.

### Cykl w grafie zależności

Status odmowy brzmi `Check result:Circular dependency in stream definitions`. W logu może mu towarzyszyć `Circular dependency: stream interval resolution stalled with N unresolved streams`.

Prześledź odwołania w klauzulach `FROM` w pliku RQL, aż znajdziesz powrót do wcześniejszego strumienia. Usuń zależność cykliczną; zmiana kolejności wierszy jej nie usuwa. Bezpośredni odczyt własnego wyniku może zostać odrzucony wcześniej komunikatem `a stream cannot be its own producer`. Dla odrzuconego planu `-d` również kończy się odmową, więc graf można wygenerować dopiero po poprawce. Patrz [Wykrywanie pętli](wykrywanie-petli.md).

### Nieznany strumień

Komunikat `Stream 'dst' reads from 'absent', which is not defined in the plan` oznacza brak producenta o wskazanej nazwie w całym planie. Sprawdź pisownię i dodaj brakującą deklarację lub zapytanie. `SELECT` może odwoływać się do producenta zdefiniowanego niżej w pliku, o ile zależności nie tworzą cyklu; samo przesunięcie istniejącej definicji nie naprawia brakującego producenta ani cyklu. Osobne reguły kolejności dotyczą `LET`/`VAR`, których deklaracja poprzedza użycie, oraz `RULE`, którego cel musi już istnieć przy parsowaniu. Szczegóły diagnostyki opisują [Błędy składni i kompilacji](../konstrukcja-jezyka-zapytan/bledy-skladni-i-kompilacji.md#nazwy-strumieni-pola-i-zależności).

### Różne szerokości wejść przy `[_]`

Wyrażenie `core0[_] * core1[_]` rozwija się do najmniejszej płaskiej szerokości wkładów obu argumentów w klauzuli `FROM`; równość szerokości nie jest wymagana. Dla wejść o dwóch i jednej pozycji powstaje jedno pole wynikowe. Tablica liczbowa zajmuje tyle pozycji, ile ma elementów, a `STRING[N]` jedną; wkład źródła ustala się w rzeczywistym drzewie `FROM`, po uwzględnieniu okien i reduktorów. Sprawdź schemat i klauzulę `FROM`, jeśli liczba wyników jest mniejsza od oczekiwanej. Nazwa spoza `FROM` albo wkład, który nie stanowi spójnego bloku pól, daje odmowę zamiast domyślnej szerokości. Patrz [Przetwarzanie symbolu \_](przetwarzanie-symbolu-_.md).

### Plik danych niedostępny

Błąd ten **nie pojawia się przy `-c`** - flaga weryfikuje poprawność zapytania, nie sprawdza czy pliki danych istnieją. Błąd dostępu do źródła może wystąpić podczas zwykłego startu, walidacji resetu lub importu ad hoc. Nie myl go z brakiem samego pliku `.rql`, który uniemożliwia również kompilację.

## Gdy kompilacja przechodzi, a start nie

Kontrole stanu źródeł i magazynów działają przed uruchomieniem przetwarzania, również przy walidacji nowego planu przez reset i nowych strumieni ad hoc. `-c` je pomija, aby można było kompilować plan na maszynie bez jego danych.

| Fragment komunikatu | Co sprawdzić |
| --- | --- |
| `source file does not exist`, `cannot inspect source`, `cannot read source` | Ścieżkę i uprawnienia konta uruchamiającego silnik. Ścieżka względna zależy od katalogu roboczego procesu. |
| `not a regular file`, `not a character device or FIFO` | Czy `BINFILE`/`TEXTFILE` lub `DEVICE` odpowiadają rzeczywistemu rodzajowi źródła. |
| `directory ... from the STORAGE directive does not exist`, `is not a directory` | Wartość `STORAGE` lub katalog z konfiguracji. Silnik nie tworzy tego katalogu. |
| `descriptor schema mismatch`, `was written for TYPE`, `was written for source` | Zgodność zachowanego `.desc` z aktualnym schematem, rodzajem i ścieżką źródła. Ustal, czy zamiarem jest kontynuacja danych, czy nowy strumień. |
| `rotation counter file ... is unreadable`, `cannot be read` | Treść licznika i możliwość odczytu. Poprawna wartość mieści się w `0..INT_MAX-1`; usunięcie pliku zaczyna numerację od zera i może nadpisać archiwa `.old<N>`. |
| `dataModel: stream '...': ... open-files limit RLIMIT_NOFILE is ...` | Limit otwartych plików procesu. Komunikat podaje limit miękki, twardy i liczbę strumieni. Sprawdź `ulimit -n` lub limity jednostki usługi. |

Nie usuwaj deskryptorów ani licznika rotacji bez ustalenia skutku dla zachowanych danych. Pełny katalog przyczyn i skutków odmowy startu zawiera rozdział [Błędy wykonania](../realizacja-zapytan/bledy-wykonania.md).

### Pamięć historii i pamięć dzielona

`Plan keeps ... bytes of stream history in memory; the budget [limits] history_memory_mib = ...` to odmowa kompilatora. Ogranicz szerokość rekordów i historię wymaganą przez okna lub przesunięcia; sprawdź największy udział strumienia podany w komunikacie. Jest to inny zasób niż kolejki IPC.

Tryb `-c` sprawdza także, czy w pamięci dzielonej mieści się stała rezerwacja instancji. Dlatego poprawny plan może skończyć się komunikatem `shared memory too small: fixed reservation needs ..., only ... free (see -c --shmbudget)` i kodem `ENOBUFS` (`105` na Linuksie). Raport budżetu uzyskasz osobno:

```bash
xretractor -c --shmbudget query.rql >shm-budget.txt
```

`--shmbudget` wymaga udanej kompilacji, wypisuje raport zamiast planu i nie odmawia tylko dlatego, że brakuje miejsca na stałą rezerwację. Raport pomaga ocenić koszt IPC; nie potwierdza dostępności plików ani możliwości uruchomienia wszystkich subskrypcji.

## Ostrzeżenia i materiał do zgłoszenia

`warning: ... is declared but never used`, `TIMEOUT ... is longer than the interval`, informacja o przestarzałym `FILE` i `grows without bound on disk` nie są odmowami kompilacji. O powodzeniu decyduje kod wyjścia. Nieużyte nazwy i zbyt długi `TIMEOUT` są raportowane także bez `-v`; ostrzeżenia o przestarzałym źródle `FILE` i nieograniczonym wzroście magazynów są wypisywane na stderr z `--verbose`. Część wpisów logu zależy od konfiguracji builda; brak wpisu nie dowodzi braku problemu.

Do zgłoszenia dołącz minimalny plik RQL, dokładne polecenie, kod wyjścia, oba pliki wyjściowe oraz wynik `xretractor --build-info`. Dla problemu występującego tylko przy starcie zachowaj też użyty TOML, katalog roboczy, istotne deskryptory i log serwera; usuń z kopii dane poufne. Lokalizację logu wskazuje wiersz `Log:` w `xretractor --help`. Dla usługi sprawdź również jej dziennik. W przypadku ad hoc zapisz wysłaną instrukcję i nazwę instancji oraz odpowiedź klienta, bo szczegółowy `msg:` parsera trafia na stderr serwera.
