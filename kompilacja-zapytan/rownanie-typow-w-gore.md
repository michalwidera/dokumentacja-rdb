# Równanie typów w górę

Co się dzieje w przypadku, kiedy mnożymy dane typu BYTE z danymi typu INTEGER ? W systemie RetractorDB obowiązują ścisłe zasady równania typów w górę. Pomnożenie pola typu BYTE z wartością pola, które jest typu INTEGER spowoduje powstanie w schemacie typu pola INTEGER. To dzieje się na etapie kompilacji.

Na chwilę obecną system RetractorDB wspiera następujące typy danych:

| Typ      | Opis                                         |
| -------- | -------------------------------------------- |
| BYTE     | wartości 0–255                               |
| INTEGER  | 4 bajtowe wartości dla liczb ze znakiem      |
| UINT     | podobnie jak INTEGER dla liczb bez znaku     |
| RATIONAL | liczby wymierne                              |
| FLOAT    | liczby zmiennoprzecinkowe                    |
| DOUBLE   | liczby zmiennoprzecinkowe podwójnej precyzji |
| STRING   | ciągi znaków                                 |

Typy STRING i RATIONAL wymagają jeszcze przeglądu, poprawek i pokrycia testami. W trakcie rozwoju oprogramowania skupiłem wysiłek na przetwarzaniu liczb. Chcę w przyszłości jeszcze dołączyć do tego zbioru typy liczb zespolonych i wymiernych liczb zespolonych Eisensteina.

Przykład równania typów w praktyce — zapytanie `scaled` z rozdziału [Przetwarzanie symbolu \_](przetwarzanie-symbolu-_.md):

```
SELECT core0[_] * core1[_] \
STREAM scaled \
FROM core0 + core1
```

`core0` ma pola BYTE i INTEGER, `core1` ma pola INTEGER i FLOAT. Po rozwinięciu `_` kompilator wyznacza typy pól wynikowych:

| Wyrażenie          | Lewy typ | Prawy typ | Typ wynikowy |
| ------------------ | -------- | --------- | ------------ |
| `scaled[0] * scaled[2]` | BYTE     | INTEGER   | INTEGER      |
| `scaled[1] * scaled[3]` | INTEGER  | FLOAT     | FLOAT        |

## Skąd bierze się typ pola wynikowego

Typ, długość i krotność pola wyznacza **jeden przebieg kompilatora** —
`compiler::inferFieldShapes()` — który wykonuje program pola w odwrotnej notacji polskiej na
stosie *typów*, dokładnie tak, jak `expressionEvaluator` wykonuje go na stosie *wartości*.
Przebieg stoi po rozwiązaniu odwołań do pól i agregatów okiennych, a **przed** upraszczaniem
wyrażeń, więc deskryptor nie zależy od żadnego przełącznika optymalizacji.

Do września 2026 na to samo pytanie odpowiadały cztery reguły lokalne, z których żadna nie
widziała całego wyrażenia. Parser zaczynał od `INTEGER` i rozpoznawał `FLOAT` albo `DOUBLE`
tylko wtedy, gdy rzutowanie było **ostatnim** tokenem programu; osobny przebieg wnioskował
`STRING`; typ redukcji okiennej ustalał się jeszcze gdzie indziej. Stąd brały się trzy wyniki
niezgodne z wartością, którą silnik do pola zapisywał: `SELECT source[0]` nad polem `DOUBLE`
dawało `INTEGER`, `to_float('2.5') * 2` dawało `INTEGER`, a `to_integer(AVG(x : 10)) + 1`
wracało do `RATIONAL`.

## Reguły kontraktu

**Czysty odczyt pola** zachowuje jego typ i długość. Odczyt jednego elementu tablicy
liczbowej daje pojedynczą wartość, więc krotność spada do jednego; `STRING[N]` jest jednym
slotem i zachowuje swoją szerokość.

**Operator dwuargumentowy** (`+`, `-`, `*`, `/`, `^`) daje typ o wyższym miejscu w porządku
`BYTE < INTEGER < UINT < RATIONAL < FLOAT < DOUBLE` — z jednym wyjątkiem: **`BYTE` z `BYTE`
daje `INTEGER`**. Nie jest to decyzja projektowa, tylko odwzorowanie języka: `uint8_t + uint8_t`
promuje się w C++ do `int` i właśnie `int` ląduje w wyniku. Ta sama promocja obowiązuje potęgę
typu dokładnego, bo `a^k` jest liczone tym samym mnożeniem, co zapisany wprost iloczyn.

**Operator jednoargumentowy** (`-x`, `NOT x`) zachowuje typ argumentu — tu promocji nie ma.

**Porównania** dają typ operandów po zrównaniu, bez promocji `BYTE`. Nie sięgają one listy
`SELECT`: żyją w warunku `RULE`.

**Funkcje** mają jedną wspólną politykę:

| Funkcje                                                                | Typ wyniku          |
| ---------------------------------------------------------------------- | ------------------- |
| `isnull`, `IsZero`, `IsNonZero`, `Length`                              | zawsze `INTEGER`    |
| `sin`, `cos`, `exp`                                                     | zawsze `DOUBLE`; nad `RATIONAL` **odrzucane** |
| `Sqrt`, `tan`, `log`, `log2`                                            | typ argumentu; nad `RATIONAL` **odrzucane** |
| `Ceil`, `Floor`, `round`, `trunc`                                       | typ argumentu       |
| `Abs`, `null2zero`                                                     | typ argumentu       |
| `to_integer`, `to_float`, `to_double`, `to_string`                     | typ docelowy        |

`sin`, `cos` i `exp` liczą w `double` i **zwracają `DOUBLE`** również dla argumentów
całkowitych. Pozostałe funkcje matematyczne liczą przez `double` i rzutują
wynik z powrotem na typ argumentu: `Ceil` nad polem `DOUBLE` daje `DOUBLE`, a `Sqrt` nad
`INTEGER` daje `INTEGER`. Jawne
konwersje wyznaczają typ swojego wyniku **także wtedy, gdy stoją w środku wyrażenia**:
`to_float('2.5') * 2` jest `FLOAT`, a `to_integer(AVG(x : 10)) + 1` jest `INTEGER`.

Siedem funkcji o niewymiernej przeciwdziedzinie — `Sqrt`, `sin`, `cos`, `exp`, `tan`,
`log` i `log2` — **nie kompiluje się** nad argumentem typu `RATIONAL`: kompilator odrzuca
plan i wymaga jawnego `to_double`. Ma to znaczenie praktyczne, bo reduktory `MIN`, `MAX`,
`AVG` i `SUMC` są z definicji `RATIONAL`. Powód, komunikat błędu, zasięg bramki (obejmuje
też warunek `RULE ... WHEN`) i wyjątek dla funkcji zaokrąglających opisuje rozdział
[Wyrażenia pól i funkcje skalarne](../konstrukcja-jezyka-zapytan/polecenie-select/wyrazenia-pol-i-funkcje-skalarne.md);
tutaj nie jest to powtarzane, żeby obie strony nie rozjechały się przy następnej zmianie.

**Agregat okna rekordowego** bierze typ z całego programu swojego argumentu, przepuszczonego
przez tę samą regułę, co reduktory strumieniowe: źródło arytmetyczne (`BYTE`, `INTEGER`,
`UINT`, `RATIONAL`) redukuje się do `RATIONAL`, żeby średnia nie traciła dokładności, a
`FLOAT` i `DOUBLE` zostają sobą. Dlatego `MIN(k : 4)` nad polem `INTEGER` daje `RATIONAL`,
ale `MIN(to_double(k) : 4)` daje `DOUBLE`.

**`NULL` nie jest typem.** Pole ma typ, a brak wartości jest znacznikiem w metadanych rekordu.
Wyrażenie, które na danym rekordzie policzy się na `NULL`, nie zmienia przez to typu swojego
pola. `null2zero(x)` przepuszcza typ argumentu, a zero zapisuje się w tym właśnie typie.

## Propagacja przez plan

Operatory, które **kopiują** schemat operandu — `SELECT *`, przesunięcie `>N`, decymacja `-r`,
przeplot `#`, rozploty `&` i `%` oraz suma strumieni `+` — niosą kształt pola producenta slot po
slocie. Typ przechodzi przez dowolnie długi łańcuch strumieni pośrednich.

Operatory, które schemat **syntetyzują**, zachowują własny: reduktor `MIN`/`MAX`/`AVG`/`SUMC`
w klauzuli `FROM` daje jedno pole `RATIONAL` niezależnie od typu źródła, a okno `@(krok,
szerokość)` daje pola typu najszerszego z rekordu źródła.

Deklaracja `DECLARE` jest umową z plikiem źródłowym i **nie podlega wnioskowaniu** — żaden
przebieg kompilatora jej nie zmienia.

## Zmiana formatu artefaktu

Poprawne typowanie zmienia `.desc` i układ rekordu tam, gdzie dotąd wychodził `INTEGER`:
`DOUBLE` zajmuje 8 bajtów zamiast 4, więc przesuwa offsety kolejnych pól. Strumień policzony
starszą wersją silnika ma artefakt o innym układzie i przy starcie zostanie odrzucony jako
niezgodny schemat — tak samo jak po każdej innej zmianie listy pól. Okresu zgodności nie ma:
deskryptor opisuje teraz to, co silnik naprawdę zapisuje, a poprzednio opisywał co innego.
