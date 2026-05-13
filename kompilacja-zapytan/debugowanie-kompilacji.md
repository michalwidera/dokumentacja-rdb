---
description: Jak obserwować, co kompilator faktycznie zrobił z zapytaniem.
icon: bug
---

# Debugowanie kompilacji

Kompilator transformuje plik `.rql` w plan wykonania przez kilka etapów. Efekt każdego etapu jest widoczny przez flagi diagnostyczne `xretractor`. Opisane tutaj narzędzia pozwalają odpowiedzieć na pytania: dlaczego schemat wygląda inaczej niż napisałem? skąd ta delta? dlaczego pojawił się substrat?

## Podstawowe narzędzie: flaga `-c`

Flaga `-c` (`--onlycompile`) zatrzymuje `xretractor` po kompilacji i drukuje skompilowany plan na standardowe wyjście — bez uruchamiania przetwarzania:

```bash
xretractor -c query.rql
```

Kod wyjścia `0` oznacza sukces. Kod `1` — błąd kompilacji. Komunikaty błędów trafiają na stderr:

```bash
xretractor -c query.rql 2>errors.txt
echo $?
```

Kompilację można wywołać nawet gdy inny proces `xretractor` już działa — flaga `-c` nie próbuje przejąć blokady wykonania.

## Jak czytać plan kompilacji

Dla kanonicznego `query.rql` z tego rozdziału plan wygląda następująco:

```
merged(1/10)
        :- PUSH_STREAM(core0)
        :- PUSH_STREAM(core1)
        :- STREAM_ADD
        core0_0: BYTE
                PUSH_ID(merged[0])
        core0_1: INTEGER
                PUSH_ID(merged[1])
        core1_2: INTEGER
                PUSH_ID(merged[2])
        core1_3: FLOAT
                PUSH_ID(merged[3])
result(1/10)
        :- PUSH_STREAM(merged)
        result_0: BYTE
                PUSH_ID(merged[0])
        result_1: INTEGER
                PUSH_ID(merged[2])
        result_2: BYTE
                PUSH_ID(merged[0])
        result_3: INTEGER
                PUSH_ID(merged[2])
core0(1/10)     sensor_a.txt
        a: BYTE
        b: INTEGER
core1(1/5)      sensor_b.txt
        c: INTEGER
        d: FLOAT
core2(3/10)     sensor_c.txt
        e: INTEGER
```

Każdy blok ma ustalony format:

```
nazwaStrumienia(delta)
        :- operacjaStrumieniowa(arg)
        nazwaPolaWyjściowego: TYP
                instrukcja
                ...
```

| Element | Znaczenie |
|---------|-----------|
| `nazwaStrumienia(delta)` | Nazwa strumienia i jego interwał jako ułamek: `1/10` = 0.1 s = 10 Hz |
| `:- PUSH_STREAM(x)` | Pcha strumień `x` na stos strumieniowy; pojawia się raz na każdy argument FROM |
| `:- STREAM_ADD` | Operator sumy strumieni (`+` w FROM) |
| `:- STREAM_HASH` | Operator synchronizacji strumieni (`#` w FROM) |
| `:- STREAM_TIMEMOVE(n)` | Przesunięcie w czasie (`>n` w FROM) |
| `pole: TYP` | Pole schematu wynikowego po równaniu typów w górę |
| `PUSH_ID(s[n])` | Odkłada na stos wartość pola `n` ze strumienia `s` — tu widoczny efekt aliasowania |
| `PUSH_VAL(x)` | Odkłada stałą `x` na stos |
| `ADD`, `MULTIPLY`, ... | Operacja arytmetyczna: zdejmuje dwa argumenty ze stosu, odkłada wynik |

Bloki efemerydów (`DECLARE`) pojawiają się na końcu planu — zawierają listę pól i ścieżkę do pliku danych.

**Aliasowanie w planie**: jeśli dwa pola wyjściowe wskazują na ten sam `PUSH_ID`, są aliasami. W przykładzie `result_0` i `result_2` oba to `PUSH_ID(merged[0])` — potwierdzenie, że `merged[0]` i `core0[0]` to ta sama pozycja. Patrz [Aliasowanie](aliasowanie.md).

**Substraty w planie**: automatycznie wygenerowany substrat pojawia się jako blok z nazwą w stylu `STREAM_HASH_core0_core1` — bez odpowiadającego `SELECT` w pliku źródłowym. Patrz [Substraty](substraty.md).

## Wizualizacja grafu zależności

Zamiast tekstu można wygenerować graf w formacie DOT i przetworzyć przez `graphviz`:

```bash
xretractor -c -d -f -s query.rql > out.dot && dot -Tsvg out.dot -o out.svg
```

Dostępne flagi modyfikujące wyjście DOT:

| Flaga | Pełna nazwa     | Znaczenie |
|-------|-----------------|-----------|
| `-d`  | `--dot`         | generuj wyjście DOT zamiast tekstowego planu |
| `-f`  | `--fields`      | pokaż pola strumieni w węzłach grafu |
| `-s`  | `--streamprogs` | pokaż sekwencje instrukcji stosu w węzłach |
| `-u`  | `--rules`       | pokaż reguły RULE |
| `-p`  | `--transparent` | przezroczyste tło — do osadzania w dokumentach |

Graf pokazuje zależności między strumieniami jako krawędzie skierowane od źródeł do wyników. Substraty mają inny kolor niż strumienie jawnie zdefiniowane przez użytkownika. Patrz [Budowa drzewa zależności](budowa-drzewa-zaleznosci.md).

## Weryfikacja interwałów

Jeśli delta strumienia wynikowego jest niespodziewana:

1. Sprawdź delty strumieni źródłowych — widoczne w blokach DECLARE na końcu planu.
2. Sprawdź operator w klauzuli FROM — każdy operator ma inne równanie na deltę.

Przykład: `core0(1/10) # core1(1/5)` daje deltę `1/15` (średnia harmoniczna), nie `1/10`. Jeśli spodziewałeś się `1/10`, użyj `+` zamiast `#`. Pełne równania — patrz [Rozwiązywanie interwałów](rozwiazywanie-interwalow.md).

## Typowe błędy kompilacji

### Cykl w grafie zależności

```
[error] Circular dependency: stream interval resolution stalled with N unresolved streams
```

Strumień odwołuje się pośrednio lub bezpośrednio do samego siebie. Wygeneruj graf przez `-d` — cykl będzie widoczny jako pętla. Patrz [Wykrywanie pętli](wykrywanie-petli.md).

### Nieznany strumień

Odwołanie do strumienia, który nie został jeszcze zadeklarowany. Pliki `.rql` przetwarzane są sekwencyjnie — `SELECT` nie może odwoływać się do strumienia zdefiniowanego niżej w pliku. Przesuń `DECLARE` lub `SELECT` wyżej.

### Niezgodność krotności schematów przy `_`

Oba strumienie w wyrażeniu `core0[_] * core1[_]` muszą mieć schematy tej samej liczności. Sprawdź ile pól ma każdy z argumentów w blokach DECLARE planu. Patrz [Przetwarzanie symbolu \_](przetwarzanie-symbolu-_.md).

### Plik danych niedostępny

Błąd ten **nie pojawia się przy `-c`** — flaga weryfikuje poprawność zapytania, nie sprawdza czy pliki danych istnieją. Błąd dostępu do pliku pojawi się dopiero przy uruchamianiu przetwarzania bez `-c`.
