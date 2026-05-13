---
description: To jest jedna z tych funkcji języka, na które się nie zwraca uwagi. Niedobrze.
icon: rotate
---

# Aliasowanie

W przypadku, w którym złączymy dwa strumienie danych operatorem sumy. Pojawi się nowy schemat danych. Do kolejnych wartości tego schematu możemy odwoływać się poprzez nazwę strumienia danych indeksowanych kolejno względem początku schematu.

Możemy jednak użyć też nazw z jakich strumień powstał. Na wartość wskazywać będzie nazwa strumienia wynikowego indeksowana względem początku schematu, jak również nazwa strumienia źródłowego przesunięta względem pozycji złączenia.

Przykład używa kanonicznych deklaracji z całego rozdziału:

```
DECLARE a BYTE, b INTEGER   STREAM core0, 0.1 FILE 'sensor_a.txt'
DECLARE c INTEGER, d FLOAT  STREAM core1, 0.2 FILE 'sensor_b.txt'

SELECT merged[0], merged[2], core0[0], core1[0]
STREAM merged
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

`merged[0]` i `core0[0]` oba trafiają na `PUSH_ID(merged[0])` — to to samo pole. Natomiast `core1[0]` — pierwsze pole schematu `core1` — trafia na `PUSH_ID(merged[2])`, nie `merged[0]`. Kompilator przetłumaczył lokalny indeks `core1[0]` na absolutną pozycję w schemacie złączonym: `core0` zajmuje pozycje 0 i 1, więc `core1` zaczyna się na pozycji 2. A co, jeśli operację `+` zastąpimy `#`? Zachęcam do eksperymentów.
