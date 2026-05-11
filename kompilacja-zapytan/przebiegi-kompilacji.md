---
description: Kompilacja to nie jeden krok, lecz łańcuch kolejnych przekształceń.
---

# Przebiegi kompilacji

Kompilacja zapytań w RetractorDB przebiega w wielu etapach. Każdy etap transformuje wewnętrzną reprezentację zapytań — drzewo `qTree` — i przekazuje wynik do następnego. Kolejność jest ściśle ustalona: każdy etap zakłada, że poprzedni zakończył się sukcesem.

Łańcuch etapów definiuje funkcja `compiler::compile()`:

```
extractIntermediateStreams
    ↓
expandSchemaWildcards
    ↓
resolveStreamIntervals      ← tu wykrywane są pętle
    ↓
deduplicateSubstrats
    ↓
resolveFieldReferences
    ↓
expandIndexWildcards
    ↓
localizeFieldOffsets
    ↓
computeRequiredCapacities
    ↓
validateConstraints
    ↓
applyCapacitiesToStreams
```

Każdy etap zwraca `"OK"` lub komunikat błędu — wówczas kompilacja się zatrzymuje.

## Opis etapów

### 1. extractIntermediateStreams

Sprowadza każde wyrażenie FROM do postaci co najwyżej dwuargumentowej. Złożone wyrażenia jak `(core0#core1)+core2` wymagają pośredniego strumienia. Etap tworzy automatycznie substraty — patrz [Substraty](substraty.md).

### 2. expandSchemaWildcards

Rozwija symbol `*` w klauzuli SELECT. Zastępuje go listą pól wynikających z schematu strumienia źródłowego — patrz [Rozwijanie symbolu \*](rozwijanie-symbolu.md).

### 3. resolveStreamIntervals

Wyznacza interwał czasowy (delta) każdego strumienia na podstawie operatorów algebraicznych i interwałów strumieni wejściowych. Algorytm iteracyjny — w każdej rundzie rozwiązuje tyle strumieni, ile jest możliwe. Wykrywa cykliczne zależności zatrzymując się, gdy liczba nierozwiązanych strumieni przestaje maleć — patrz [Rozwiązywanie interwałów](rozwiazywanie-interwalow.md) i [Wykrywanie pętli](wykrywanie-petli.md).

### 4. deduplicateSubstrats

Optymalizacja: jeśli dwa zapytania korzystają z tej samej operacji pośredniej (np. `core0#core1`), etap wskazuje drugie zapytanie na substrat utworzony przez pierwsze. Unika powielania obliczeń — patrz przykład w [Substraty](substraty.md).

### 5. resolveFieldReferences

Przekształca odwołania do pól ze schematów źródłowych na indeksy w schemacie wynikowym. Obsługuje aliasowanie — `core0[0]` zamienia na `str1[0]` itp. — patrz [Aliasowanie](aliasowanie.md).

### 6. expandIndexWildcards

Rozwija symbol `_` w indeksach pól. Powielenie formuły dla wszystkich pasujących par pól ze schematów argumentów — patrz [Przetwarzanie symbolu \_](przetwarzanie-symbolu-_.md).

### 7. localizeFieldOffsets

Wyznacza bajkowe offsety pól w buforach binarnych. Po tym etapie schemat każdego strumienia jest gotowy do alokacji pamięci.

### 8. computeRequiredCapacities

Oblicza wymagane pojemności buforów dla każdego strumienia na podstawie rozmiarów schematów i wymagań okien czasowych.

### 9. validateConstraints

Weryfikuje poprawność semantyczną skompilowanego planu: zgodność typów, rozmiary okien, dostępność źródeł danych.

### 10. applyCapacitiesToStreams

Aplikuje obliczone pojemności do obiektów strumieni. Po tym etapie plan jest gotowy do wykonania przez `dataModel`.
