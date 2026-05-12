---
description: Kompilacja to nie jeden krok, lecz łańcuch kolejnych przekształceń.
icon: shoe-prints
---

# Przebiegi kompilacji

Kompilacja zapytań w RetractorDB przebiega w wielu etapach. Każdy etap transformuje wewnętrzną reprezentację zapytań — drzewo `qTree` — i przekazuje wynik do następnego. Kolejność jest ściśle ustalona: każdy etap zakłada, że poprzedni zakończył się sukcesem.

Łańcuch etapów definiuje funkcja `compiler::compile()`:

{% stepper %}
{% step %}
### extractIntermediateStreams

Sprowadza każde wyrażenie FROM do postaci co najwyżej dwuargumentowej. Złożone wyrażenia jak `(core0#core1)+core2` wymagają pośredniego strumienia. Etap tworzy automatycznie substraty — patrz [Substraty](substraty.md).
{% endstep %}

{% step %}
### expandSchemaWildcards

Rozwija symbol `*` w klauzuli SELECT. Zastępuje go listą pól wynikających z schematu strumienia źródłowego — patrz [Rozwijanie symbolu \*](rozwijanie-symbolu.md).
{% endstep %}

{% step %}
### resolveStreamIntervals   (← tu wykrywane są pętle)  &#x20;

Wyznacza interwał czasowy (delta) każdego strumienia na podstawie operatorów algebraicznych i interwałów strumieni wejściowych. Algorytm iteracyjny — w każdej rundzie rozwiązuje tyle strumieni, ile jest możliwe. Wykrywa cykliczne zależności zatrzymując się, gdy liczba nierozwiązanych strumieni przestaje maleć — patrz [Rozwiązywanie interwałów](rozwiazywanie-interwalow.md) i [Wykrywanie pętli](wykrywanie-petli.md).
{% endstep %}

{% step %}
### deduplicateSubstrats

Optymalizacja: jeśli dwa zapytania korzystają z tej samej operacji pośredniej (np. `core0#core1`), etap wskazuje drugie zapytanie na substrat utworzony przez pierwsze. Unika powielania obliczeń — patrz przykład w [Substraty](substraty.md).
{% endstep %}

{% step %}
### resolveFieldReferences

Przekształca odwołania do pól ze schematów źródłowych na indeksy w schemacie wynikowym. Obsługuje aliasowanie — `core0[0]` zamienia na `str1[0]` itp. — patrz [Aliasowanie](aliasowanie.md).
{% endstep %}

{% step %}
### expandIndexWildcards

Rozwija symbol `_` w indeksach pól. Powielenie formuły dla wszystkich pasujących par pól ze schematów argumentów — patrz [Przetwarzanie symbolu \_](przetwarzanie-symbolu-_.md).
{% endstep %}

{% step %}
### localizeFieldOffsets

Wyznacza bajkowe offsety pól w buforach binarnych. Po tym etapie schemat każdego strumienia jest gotowy do alokacji pamięci.
{% endstep %}

{% step %}
### computeRequiredCapacities

Oblicza wymagane pojemności buforów dla każdego strumienia na podstawie rozmiarów schematów i wymagań okien czasowych.
{% endstep %}

{% step %}
### validateConstraints

Weryfikuje poprawność semantyczną skompilowanego planu: zgodność typów, rozmiary okien, dostępność źródeł danych.
{% endstep %}

{% step %}
### applyCapacitiesToStreams

Aplikuje obliczone pojemności do obiektów strumieni. Po tym etapie plan jest gotowy do wykonania przez `dataModel`.
{% endstep %}
{% endstepper %}

Każdy etap zwraca `"OK"` lub komunikat błędu — wówczas kompilacja się zatrzymuje.

