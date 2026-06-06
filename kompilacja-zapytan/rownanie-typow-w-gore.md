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
