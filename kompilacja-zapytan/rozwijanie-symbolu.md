---
description: Tą funkcjonalność ukradłem bezpośrednio z języka SQL
icon: star-shooting
---

# Rozwijanie symbolu \*

Każdy, który pisał w języku SQL poznał magiczny znak \* w tym języku. Wywołanie polecenia SELECT z tym argumentem rozwinie listę argumentów w oparciu o schematy tabel powstałych w wyniku złączeń relacyjnych. Coś podobnego chciałem osiągnąć w języku RQL.

Jako przykład można przytoczyć zapytanie:

```
DECLARE a BYTE STREAM core1, 0.1 FILE 'datafile1.dat'
DECLARE b INTEGER, c FLOAT STREAM core2, 0.2 FILE 'datafile2.txt'

SELECT *
STREAM str1
FROM core1+core2

SELECT str2[1]
STREAM str2
FROM str1
```

Rodzi się pytanie – dlaczego aż tak skomplikowany przykład?

Skompilujmy i zobaczmy efekt kompilacji:

```
$ xretractor -c query.rql
str1(1/10)
        :- PUSH_STREAM(core1)
        :- PUSH_STREAM(core2)
        :- STREAM_ADD
        core1_0: BYTE
                PUSH_ID(str1[0])
        core2_1: INTEGER
                PUSH_ID(str1[1])
        core2_2: FLOAT
                PUSH_ID(str1[2])
str2(1/10)
        :- PUSH_STREAM(str1)
        str2_0: INTEGER
                PUSH_ID(str2[1])
core1(1/10)     datafile1.dat
        a: BYTE
core2(1/5)      datafile2.txt
        b: INTEGER
        c: FLOAT
```

Taki zrzut kompilatora nie wyjaśnia zbyt wiele. Widzimy, że \* zamieniła się w trzy pola core1\_0, core2\_1, core2\_2. Pojawiają się też sekwencje operacji na stosie w których kolejne już str1 od 0 do 2 się pojawiają. Istotne okazują się jednak typy, które prowadzą nas z których pól, na które przeskoczyły nazwy. Specjalnie przydzieliłem różne typy do rożnych pól w deklaracjach. Dzięki temu w zapytaniu odwołując się do drugiego pola w kolejności przez str2\[1] widzimy, że wpadło pole typu Int. Pola ułożyły się zgodnie z tym jak zdefiniowano operator sumy strumieni.
