---
description: >-
  Tym poleceniem wytworzysz artefakty i substraty. Substraty stworzą się same,
  jako efekt uboczny.
---

# Polecenie SELECT

Każde polecenie SELECT w systemie RetractorDB tworzy ciągłe zapytania. Zapytania te realizowane są od momentu pojawienia się w systemie aż do zakończenia pracy systemu.

Składnia polecenia SELECT przedstawia się następująco:

```
SELECT wyrażenie_algebraiczne [, wyrażenie_algebraiczne] 
STREAM nazwa_budowanego_strumienia
FROM strumieniowe_wyrażnie_algebraiczne 
[FILE 'nazwa_pliku_artefaktu'] 
[RETENTION pojemoność [segmenty]]
[VOLATILE]
[STORAGE profile]
```

Osoby posługujące się językiem SQL zauważą od razu że przedstawione powyżej polecenie odbiega znacząco od tego co znają z zakresu relacyjnych baz danych.

Pierwsza różnica poza składnią to fakt że polecenia te wprowadzone do systemu realizują się aż do zakończenia pracy systemu. Każde polecenie SELECT jest zapytaniem ciągłym. Klauzula STREAM wymaga nadania przez twórcę każdemu zapytaniu unikalnej nazwy. O ile wyrażenia algebraiczne na liście klauzuli SELECT nie odbiegają od formy znanej z systemów relacyjnych o tyle strumieniowe wyrażenie algebraiczne musi spełniać warunki przedstawione w poprzednim rozdziale dotyczącym wyrażeń algebraicznych. Opcjonalne klauzule FILE oraz RETENTION zapewniają procesy kierowania wyników i zarządzania formą ich retencji. Stare, podzielone pliki wynikowe mogą być usuwane na bieżąco zapewniając systemowi miejsce na nowe dane w ruchu ciągłym.

Przykładem zapytania tworzącego nowy strumień danych może być następujące polecenie w języku RQL.

```
SELECT str1[0]*10 + str1[1]*10, str[2]
STREAM str1
FROM A+B
```

Tak zbudowane zapytanie zakłada że ktoś zadeklarował strumienie A i B. Operację tą mógł wykonać za pomocą słowa kluczowego DECLARE lub innego polecenia SELECT. W oparciu tylko o wiersz zawierający zapytanie nie jesteśmy w stanie stwierdzić jak szybko dane strumienia str1 napływają. Ta informacja jest wyliczana na etapie kompilacji w oparciu o strumienie A i B i wyrażenie algebraiczne w klauzuli FROM.

Klauzula VOLATILE - tworzy ulotną formę zapytania. Zapytanie z tą klauzulą przechowują tylko jeden rekord w pamięci - na dysku pojawia się tylko deskryptor opisujący strukturę danych.

Klauzula STORAGE umożliwia wybrór sposobu tworzenia i zarządzania tworzonymi artefaktami. Wybranie opcji:

* DEFAULT wytworzy obiekt typu Posix Group Accessor (retencjonowany opcjonalnie) zarządzaca danych
* SHADOW wytworzy obiekt typu Posix Group Accessor with Shadow (retncjonowany opcjonalnie) zarządza danych chroniący modyfikacje danych zarejestrowanych. W tym trybie modyfikacje zapisywane są do osobnego pliku z rozszerzeniem .shadow

(inne typy wymagają testów i sprawdzenia np. MEMORY, POSIX, SHADOW, GENERIC, ...)
