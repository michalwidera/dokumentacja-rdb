# Debugowanie kompilacji

Kompilator transformuje plik `.rql` w plan wykonania przez kilka etapów. Efekt każdego etapu jest widoczny przez flagi diagnostyczne `xretractor`. Opisane tutaj narzędzia pozwalają odpowiedzieć na pytania: dlaczego schemat wygląda inaczej niż napisałem? skąd ta delta? dlaczego pojawił się substrat?

## Podstawowe narzędzie: flaga `-c`

Flaga `-c` (`--onlycompile`) zatrzymuje `xretractor` po kompilacji i drukuje skompilowany plan na standardowe wyjście - bez uruchamiania przetwarzania:

```bash
xretractor -c query.rql
```

Kod wyjścia `0` oznacza sukces. Odmowa błędnego planu przez parser lub kompilator zwraca `EPROTO`, czyli `71` na Linuksie. Inne niepowodzenia, np. brak samego pliku `.rql` albo błąd wewnętrzny, mogą mieć inne kody; w skrypcie sprawdzaj każdy wynik różny od zera. Komunikaty błędów trafiają na stderr:

```bash
xretractor -c query.rql 2>errors.txt
echo $?
```

Kompilację można wywołać nawet gdy inny proces `xretractor` już działa - flaga `-c` nie próbuje przejąć blokady wykonania.

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

```
[error] Circular dependency: stream interval resolution stalled with N
>> unresolved streams
```

Strumień odwołuje się pośrednio lub bezpośrednio do samego siebie. Wygeneruj graf przez `-d` - cykl będzie widoczny jako pętla. Patrz [Wykrywanie pętli](wykrywanie-petli.md).

### Nieznany strumień

Komunikat `Stream 'dst' reads from 'absent', which is not defined in the plan` oznacza brak producenta o wskazanej nazwie w całym planie. Sprawdź pisownię i dodaj brakującą deklarację lub zapytanie. `SELECT` może odwoływać się do producenta zdefiniowanego niżej w pliku, o ile zależności nie tworzą cyklu; samo przesunięcie istniejącej definicji nie naprawia brakującego producenta ani cyklu. Osobne reguły kolejności dotyczą `LET`/`VAR`, których deklaracja poprzedza użycie, oraz `RULE`, którego cel musi już istnieć przy parsowaniu. Szczegóły diagnostyki opisują [Błędy składni i kompilacji](../konstrukcja-jezyka-zapytan/bledy-skladni-i-kompilacji.md#nazwy-strumieni-pola-i-zależności).

### Różne szerokości wejść przy `[_]`

Wyrażenie `core0[_] * core1[_]` rozwija się do najmniejszej płaskiej szerokości wkładów obu argumentów w klauzuli `FROM`; równość szerokości nie jest wymagana. Dla wejść o dwóch i jednej pozycji powstaje jedno pole wynikowe. Tablica liczbowa zajmuje tyle pozycji, ile ma elementów, a `STRING[N]` jedną; wkład źródła ustala się w rzeczywistym drzewie `FROM`, po uwzględnieniu okien i reduktorów. Sprawdź schemat i klauzulę `FROM`, jeśli liczba wyników jest mniejsza od oczekiwanej. Nazwa spoza `FROM` albo wkład, który nie stanowi spójnego bloku pól, daje odmowę zamiast domyślnej szerokości. Patrz [Przetwarzanie symbolu \_](przetwarzanie-symbolu-_.md).

### Plik danych niedostępny

Błąd ten **nie pojawia się przy `-c`** - flaga weryfikuje poprawność zapytania, nie sprawdza czy pliki danych istnieją. Błąd dostępu do pliku pojawi się dopiero przy uruchamianiu przetwarzania bez `-c`.
