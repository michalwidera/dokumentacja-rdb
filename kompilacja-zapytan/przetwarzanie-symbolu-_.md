---
description: Cukier syntaktyczny.
icon: overline
---

# Przetwarzanie symbolu \_

W niektórych zapytaniach można użyć symbolu podkreślenia. Ta technika to cukier syntaktyczny. Podobnie jak rozwijanie symbolu \* w wyniku pojawienia się jednego odwołania w wyniku kompilacji pojawi się wiele pól. Ile tych pól powstanie ma wpływ co z czym i w jakiej kolejności zostało złączone w klauzuli FROM.

Przykład używa kanonicznych deklaracji z całego rozdziału — `core0` ma dwa pola (BYTE, INTEGER), `core1` ma dwa pola (INTEGER, FLOAT), schematy są równoliczne:

```
DECLARE a BYTE, b INTEGER   STREAM core0, 0.1 FILE ‘sensor_a.txt’
DECLARE c INTEGER, d FLOAT  STREAM core1, 0.2 FILE ‘sensor_b.txt’

SELECT core0[_] * core1[_]
STREAM scaled
FROM core0 + core1
```

Po przeprowadzeniu kompilacji:

```
$ xretractor -c query.rql
scaled(1/10)
        :- PUSH_STREAM(core0)
        :- PUSH_STREAM(core1)
        :- STREAM_ADD
        scaled_0: INTEGER
                PUSH_ID(scaled[0])
                PUSH_ID(scaled[2])
                MULTIPLY
        scaled_1: FLOAT
                PUSH_ID(scaled[1])
                PUSH_ID(scaled[3])
                MULTIPLY
core0(1/10)     sensor_a.txt
        a: BYTE
        b: INTEGER
core1(1/5)      sensor_b.txt
        c: INTEGER
        d: FLOAT
```

Symbol `_` rozwinął się w dwa pola: `scaled[0] * scaled[2]` (czyli `a * c`) i `scaled[1] * scaled[3]` (czyli `b * d`). Odwołania do `core0` i `core1` zostały przetłumaczone przez aliasowanie na absolutne pozycje w schemacie złączonym. Typy wynikowe to INTEGER (`BYTE * INTEGER`) i FLOAT (`INTEGER * FLOAT`) — wynik równania typów w górę, opisanego w osobnym podrozdziale.

Po pojawieniu się w formule operatora \_ w indeksie tablicy, kompilator powieli formułę dla wszystkich pól argumentów. Schematy obu argumentów muszą być równoliczne. Czyli core0 i core1 muszą mieć schematy tej samej liczności – typy zostaną wyrównane do najwyższego. O równaniu typów wspomnę za chwilę.

Ta funkcjonalność ma główne zastosowanie w przypadku budowy zapytań w których budujemy algorytmy filtrów sygnałowych. Tam dochodzi do szeregu operacji matematycznych. Funkcjonalność związana z przetwarzaniem symbolu \_ nie jest wymagana w celu osiągnięcia pełnej funkcjonalności systemu RetractorDB. Jednak znacząco upraszcza budowę specyficznych zapytań w których należy połączyć operacje na dwóch schematach. Przykład zastosowania zostanie przedstawiony w trakcie prezentacji algorytmów przetwarzania sygnałów.
