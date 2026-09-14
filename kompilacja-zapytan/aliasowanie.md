# Aliasowanie

W przypadku, w którym złączymy dwa strumienie danych operatorem sumy. Pojawi się nowy schemat danych. Do kolejnych wartości tego schematu możemy odwoływać się poprzez nazwę strumienia danych indeksowanych kolejno względem początku schematu.

Możemy jednak użyć też nazw z jakich strumień powstał. Na wartość wskazywać będzie nazwa strumienia wynikowego indeksowana względem początku schematu, jak również nazwa strumienia źródłowego przesunięta względem pozycji złączenia.

Przykład używa kanonicznych deklaracji z całego rozdziału:

```
DECLARE a BYTE, b INTEGER \
STREAM core0, 0.1 \
FILE 'sensor_a.txt'

DECLARE c INTEGER, d FLOAT \
STREAM core1, 0.2 \
FILE 'sensor_b.txt'

SELECT merged[0], merged[2], core0[0], core1[0] \
STREAM merged \
FROM core0 + core1
```

Po kompilacji otrzymamy:

```
$ xretractor -c query.rql
merged(1/10)
        :- PUSH_STREAM(core0)
        :- PUSH_STREAM(core1)
        :- STREAM_ADD
        merged_0: BYTE
                PUSH_ID(merged[0])
        merged_1: INTEGER
                PUSH_ID(merged[2])
        merged_2: BYTE
                PUSH_ID(merged[0])
        merged_3: INTEGER
                PUSH_ID(merged[2])
core0(1/10)     sensor_a.txt
        a: BYTE
        b: INTEGER
core1(1/5)      sensor_b.txt
        c: INTEGER
        d: FLOAT
```

`merged[0]` i `core0[0]` oba trafiają na `PUSH_ID(merged[0])` — to to samo pole. Natomiast `core1[0]` — pierwsze pole schematu `core1` — trafia na `PUSH_ID(merged[2])`, nie `merged[0]`. Kompilator przetłumaczył lokalny indeks `core1[0]` na absolutną pozycję w schemacie złączonym: `core0` zajmuje pozycje 0 i 1, więc `core1` zaczyna się na pozycji 2.

## Odwołanie spoza klauzuli `FROM`

Alias źródłowy działa tylko wtedy, gdy suma stoi bezpośrednio w klauzuli `FROM` zapytania. Jeżeli suma została nazwana osobnym zapytaniem, lista pól konsumenta widzi wyłącznie ten nazwany strumień:

```
SELECT * STREAM merged FROM core0 + core1
SELECT merged[0], core1[0] STREAM result FROM merged
```

Kompilacja kończy się błędem:

```
Check result:Stream 'result' refers to 'core1', which is not in its FROM clause. A field list reads only the streams named in FROM: refer to the field by its position in the record of a stream in FROM, or move the reference to a query whose FROM names 'core1'.
```

`merged` jest zapytaniem użytkownika z własnym interwałem i buforem, więc kompilator nie wyznacza pozycji jego źródeł w rekordzie `result`. Poprawny zapis wskazuje pole przez pozycję w rekordzie `merged` — `core1` zaczyna się tam od pozycji 2:

```
SELECT merged[0], merged[2] STREAM result FROM merged
```

Ograniczenie nie dotyczy substratów tworzonych automatycznie dla złożonej klauzuli `FROM`, np. `FROM (core0 + core1) > 1`: przez nie alias źródłowy nadal działa.

## Indeks poza zakresem

Indeks w zapisie `strumien[k]` musi wskazywać slot, który zapytanie rzeczywiście czyta. Kompilator odrzuca indeks poza tym zakresem, zamiast wygenerować plan czytający za końcem rekordu wejściowego. Granica zależy od tego, do czego odnosi się nazwa:

| Odwołanie | Granica | Przykład poprawny | Przykład odrzucony |
|---|---|---|---|
| strumień z klauzuli `FROM` | liczba slotów, które ten strumień wnosi do `FROM` | `core1[1]` przy `FROM core0 + core1` | `core1[2]` |
| strumień za oknem albo reduktorem | liczba slotów po operatorze, nie szerokość strumienia | `core0[2]` przy `FROM core0@(1,3)` | `core0[3]`; `acc[1]` przy `FROM SUMC(acc)` |
| własna nazwa na liście `SELECT` | szerokość rekordu wejściowego `FROM` | `merged[3]` w `STREAM merged FROM core0 + core1` | `merged[4]` |
| własna nazwa w warunku `RULE` | szerokość rekordu wyjściowego strumienia | `merged[3]` przy `SELECT * STREAM merged` | `merged[4]` |

Okno i reduktor zmieniają liczbę slotów: `core0@(1,3)` wnosi trzy sloty, choć `core0` ma dwa pola, a `SUMC(acc)` wnosi jeden. Ta sama liczba wyznacza rozwinięcie `core0[_]`, więc zapis ręczny i zapis z `_` mają ten sam zakres.

Przykładowe komunikaty:

```
Check result:Stream 'merged': stream 'core1' has 2 element(s) in its FROM clause, so 'core1[2]' is out of range
Check result:Stream 'merged': the FROM record of 'merged' has 4 element(s), so 'merged[4]' is out of range
Check result:Stream 'merged': rule 'alarm' reads the record of 'merged', which has 4 element(s), so 'merged[4]' is out of range
```

Indeks zwinięty z `$` w generatorze strumieni podlega tej samej kontroli i daje ten sam komunikat co indeks napisany ręcznie.


Opisane wyżej aliasy źródłowe dotyczą operatora sumy `+`. Suma konkatenizuje schematy, dlatego zachowuje pozycję i tożsamość każdej składowej: `core0[0]` i `core1[0]` wskazują różne miejsca w rekordzie wynikowym.

Operator przeplotu `#` działa inaczej. Oba argumenty muszą mieć równoliczne schematy, a wynik ma jeden wspólny schemat. W danym slocie przeplot wybiera rekord jednej składowej, więc pozycja `k` lewego i prawego argumentu staje się tą samą pozycją `k` wyniku. Po wykonaniu `A#B` nazwa `A` albo `B` nie identyfikuje już źródła bieżącego rekordu.

Porównanie kompilacji dla deklaracji `core0` i `core1` z przykładu pokazuje różnicę bez uruchamiania zapytania:

| Wyrażenie `FROM` | Odwołania na liście `SELECT` | Wynik kompilacji |
|---|---|---|
| `core0 + core1` | `core0[0]`, `core1[0]` | `PUSH_ID(merged[0])`, `PUSH_ID(merged[2])` — schematy są skonkatenowane, więc składowe pozostają rozróżnialne |
| `core0 # core1` | `core0[0]`, `core1[0]` | błąd kompilacji — oba argumenty dzielą pozycję `0` jednego schematu wyniku |

Drugi wiersz odpowiada zapytaniu:

```
SELECT core0[0], core1[0] STREAM interleaved FROM core0#core1
```

Kompilator zatrzymuje je komunikatem, że `core0` jest składową przeplotu i takiego odwołania nie można odróżnić od odwołania do drugiej składowej. Nie powstaje plan, który po cichu mapowałby oba pola na `interleaved[0]`.

Z tego powodu kompilator odrzuca nazwane odwołania użytkownika, które przez `#` próbują sięgnąć do jego składowej. Zakaz obejmuje wszystkie formy:

- indeks liczbowy: `A[0]`;
- nazwę pola: `A.pole` oraz gołą nazwę pola rozwiązaną do `A`;
- indeks wieloznaczny: `A[_]`;
- kwalifikowany pełny skan: `A.*`;
- te same odwołania w warunku `RULE` oraz przez substraty wygenerowane dla złożonej klauzuli `FROM`.

Poprawny zapis odwołuje się do jedynego schematu wyniku:

```
SELECT wynik[0], wynik[1] STREAM wynik FROM A#B
SELECT wynik2.* STREAM wynik2 FROM A#B
```

Niekwalifikowane `*` również oznacza cały schemat wynikowy i pozostaje legalne. Jeżeli dalsze obliczenie wymaga `[_]`, najpierw należy nazwać przeplot, a następnie użyć jego wyniku:

```
SELECT * STREAM przeplot FROM A#B
SELECT przeplot[_] * 2 STREAM przeskalowany FROM przeplot
```

Gdy potrzebna jest ponownie konkretna składowa, należy odzyskać ją operatorem rozplotu `&` albo `%`, zamiast używać nazwy źródła przez węzeł `#`.

> **_NOTE:_** Aliasowanie po `+` ma pokrycie w teście integracyjnym `Pattern7`, a odrzucenie odwołania spoza `FROM` — w teście `field_ref_outside_from`. Odrzucanie nazwanych składowych `#` i kontrole pozytywne dla nazwy wyniku są pokryte testami jednostkowymi `ut_compiler`.
