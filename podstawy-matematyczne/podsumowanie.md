# Podsumowanie

Model regularnych serii czasowych przypisuje strumieniowi uporządkowany ciąg rekordów i stały, wymierny interwał. Operatory opisują przekształcenia wartości, schematów i pozycji próbek. Sekwencje Beatty'ego oraz twierdzenie Fraenkela dostarczają podstaw do wykazania, że przeplot i rozplątanie rozdzielają i odtwarzają pozycje próbek bez strat.

Prototypy w Pythonie, opisane w [Implementacji modelu](implementacja-programowa.md), służą do sprawdzania przykładów i poszukiwania kontrprzykładów. Skończony eksperyment numeryczny nie jest dowodem twierdzenia o nieskończonych strumieniach. Uzasadnienia matematyczne znajdują się w [Formalnych podstawach i dowodach](formalne-podstawy-i-dowody.md), a formalizację w Lean oraz jej powiązanie z testami C++ opisuje [związek dowodów z implementacją](formalne-podstawy-i-dowody.md#związek-dowodów-z-implementacją).

Dokładność odwzorowań indeksów wymaga zachowania arytmetyki wymiernej aż do wyznaczenia całkowitego indeksu operacją podłogi lub sufitu. Przybliżenie zmiennoprzecinkowe może zmienić wybór próbki na granicy przedziału. W kodzie trzeba również kontrolować zakres typów liczbowych.

Realizacja przyczynowa rozróżnia początek logiczny, ogon startowy i pojemność historii. Reguła optymalizacji może zachować rekordy i ich indeksy, a jednocześnie skrócić czas oczekiwania na wynik. Te granice opisuje rozdział [Ogony, początki logiczne i obserwowalność operatorów](ogony-i-obserwowalnosc-operatorow.md).

Podstawy te służą do interpretacji [operatorów RQL](../konstrukcja-jezyka-zapytan/) i [przebiegów kompilacji](../kompilacja-zapytan/przebiegi-kompilacji.md). Do pierwszego uruchomienia wystarczy [krótki przykład](../instalacja-systemu/running.md#standalone-plik-do-eof); znajomość dowodów jest potrzebna przede wszystkim przy analizie semantyki i zmianach optymalizatora. Historyczne wyprowadzenie metody przedstawia publikacja [\[3\]](../literatura.md#3), a jej tłem jest teoria układów pokrywających [\[4\]](../literatura.md#4).

