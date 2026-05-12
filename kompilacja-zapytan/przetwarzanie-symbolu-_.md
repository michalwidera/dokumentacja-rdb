---
description: Cukier syntaktyczny.
icon: overline
---

# Przetwarzanie symbolu \_

W niektórych zapytaniach można użyć symbolu podkreślenia. Ta technika to cukier syntaktyczny. Podobnie jak rozwijanie symbolu \* w wyniku pojawienia się jednego odwołania w wyniku kompilacji pojawi się wiele pól. Ile tych pól powstanie ma wpływ co z czym i w jakiej kolejności zostało złączone w klauzuli FROM.

Zapytanie ilustrujące tą funkcjonalność przedstawia się następująco:

```
DECLARE a UINT, b UINT STREAM core0, 0.1 FILE 'file1.txt'
DECLARE c UINT, d UINT STREAM core1, 0.2 FILE 'file2.txt’

SELECT core0[_] * core1[_]
STREAM pomnozone
FROM core0+core1
```

Po przeprowadzeniu kompilacji poleceniem:

```
$ xretractor -c query.rql
pomnozone(1/10)
        :- PUSH_STREAM(core0)
        :- PUSH_STREAM(core1)
        :- STREAM_ADD
        pomnozone_0: UINT
                PUSH_ID(pomnozone[0])
                PUSH_ID(pomnozone[2])
                MULTIPLY
        pomnozone_1: UINT
                PUSH_ID(pomnozone[1])
                PUSH_ID(pomnozone[3])
                MULTIPLY
core0(1/10)     file1.txt
        a: UINT
        b: UINT
core1(1/5)      file2.txt
        c: UINT
        d: UINT
```

Jak widać poprosiliśmy o pomnożenie dwóch wartości w jednym polu, a wytworzyły się 2 pola mnożące wartości 1 z 3 oraz 2 z 4. Należy zauważyć, że odwołujemy się w zapytaniu nie do wartości pomnożone a do wartości schematów źródłowych. Tutaj stosujemy aliasowanie.

Po pojawieniu się w formule operatora \_ w indeksie tablicy, kompilator powieli formułę dla wszystkich pól argumentów. Schematy obu argumentów muszą być równoliczne. Czyli core0 i core1 muszą mieć schematy tej samej liczności – typy zostaną wyrównane do najwyższego. O równaniu typów wspomnę za chwilę.

Ta funkcjonalność ma główne zastosowanie w przypadku budowy zapytań w których budujemy algorytmy filtrów sygnałowych. Tam dochodzi do szeregu operacji matematycznych. Funkcjonalność związana z przetwarzaniem symbolu \_ nie jest wymagana w celu osiągnięcia pełnej funkcjonalności systemu RetractorDB. Jednak znacząco upraszcza budowę specyficznych zapytań w których należy połączyć operacje na dwóch schematach. Przykład zastosowania zostanie przedstawiony w trakcie prezentacji algorytmów przetwarzania sygnałów.
