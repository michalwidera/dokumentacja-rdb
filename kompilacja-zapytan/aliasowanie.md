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

## Aliasowanie po sumie i przeplocie

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

> **_NOTE:_** Aliasowanie po `+` ma pokrycie w teście integracyjnym `Pattern7`. Odrzucanie nazwanych składowych `#` i kontrole pozytywne dla nazwy wyniku są pokryte testami jednostkowymi `ut_compiler`.
