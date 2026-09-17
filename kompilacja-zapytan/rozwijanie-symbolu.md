# Rozwijanie symbolu \*

Każdy, który pisał w języku SQL poznał magiczny znak \* w tym języku. Wywołanie polecenia SELECT z tym argumentem rozwinie listę argumentów w oparciu o schematy tabel powstałych w wyniku złączeń relacyjnych. Coś podobnego chciałem osiągnąć w języku RQL.

Przykład używa kanonicznych deklaracji z całego rozdziału:

```rql
DECLARE a BYTE, b INTEGER STREAM core0, 0.1 FILE 'sensor_a.txt'

DECLARE c INTEGER, d FLOAT STREAM core1, 0.2 FILE 'sensor_b.txt'

SELECT *         STREAM merged FROM core0 + core1

SELECT merged[2] STREAM result FROM merged
```

Skompilujmy i zobaczmy efekt:

```bash
$ xretractor -c query.rql
```

```rasm
{{#include ../regen/out/wildcard.txt}}
```

Symbol `*` zamienił się w cztery pola: `core0_0`, `core0_1`, `core1_2`, `core1_3`. Konwencja nazewnictwa: nazwa strumienia źródłowego + absolutna pozycja w schemacie wynikowym. Typy pól decydują o kolejności — `core0` wnosi BYTE i INTEGER na pozycje 0 i 1, `core1` wnosi INTEGER i FLOAT na pozycje 2 i 3. Odwołując się przez `merged[2]` w zapytaniu `result` dostajemy pole typu INTEGER — trzecie w kolejności, pierwsze z `core1`.

> **_NOTE:_** Opisana funkcjonalność ma pokrycie w teście: `Pattern3` opisanym w załączniku pt. [Testy Integracyjne](../zalaczniki/testy-integracyjne.md).
