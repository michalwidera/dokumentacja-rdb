---
description: Dotkniesz czegoś skomplikowanego, wszystko stanie się skomplikowane.
---

# Równanie typów w górę

Co się dzieje w przypadku, kiedy mnożymy dane typu BYTE z danymi typu INTEGER ? W systemie RetractorDB obowiązują ścisłe zasady równania typów w górę. Pomnożenie pola typu BYTE z wartością pola, które jest typu INTEGER spowoduje powstanie w schemacie typu pola INTEGER. To dzieje się na etapie kompilacji.

Na chwilę obecną system RetractorDB wspiera następujące typy danych:

1. BYTE – typ reprezentuje wartości 0-255,
2. INTEGER – typ reprezentuje 4 bajtowe wartości dla liczb ze znakiem,
3. UINT – podobnie jak INTEGER dla liczb bez znaku,
4. RATIONAL – liczby wymierne,
5. FLOAT – liczby zmiennoprzecinkowe,
6. DOUBLE – liczby zmiennoprzecinkowe podwójnej precyzji,
7. STRING – ciągi znaków.

Typy STRING  i RATIONAL wymagają jeszcze przeglądu, poprawek i pokrycia testami. W trakcie rozwoju oprogramowania skupiłem wysiłek na przetwarzaniu liczb. Chcę w przyszłości jeszcze dołączyć do tego zbioru typy liczb zespolonych i wymiernych liczb zespolonych Eisensteina.
