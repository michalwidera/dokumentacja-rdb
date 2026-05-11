---
description: Warunek w klauzuli WHEN to wyrażenie logiczne zbudowane z operatorów porównania i spójników.
---

# Warunek logiczny w RULE

Klauzula `WHEN` polecenia `RULE` przyjmuje wyrażenie logiczne, które jest ewaluowane na każdym nowym rekordzie wskazanego strumienia. Jeśli wyrażenie zwraca prawdę — uruchamiany jest proces zdefiniowany w klauzuli `DO`.

## Operatory porównania

| Operator | Znaczenie       |
| -------- | --------------- |
| `=`      | równy           |
| `!=`     | różny           |
| `>`      | większy         |
| `<`      | mniejszy        |
| `>=`     | większy lub równy |
| `<=`     | mniejszy lub równy |

## Spójniki logiczne

| Operator | Znaczenie |
| -------- | --------- |
| `AND`    | koniunkcja — oba warunki muszą być spełnione |
| `OR`     | alternatywa — wystarczy jeden warunek        |
| `NOT`    | negacja — warunek musi być niespełniony      |

## Struktura wyrażenia

Warunek buduje się z pól schematu strumienia wskazanego w klauzuli `ON`. Pola identyfikowane są tak samo jak w `SELECT` — przez nazwę strumienia z indeksem:

```
WHEN strumień[indeks] operator wartość
```

Złożone warunki łączymy spójnikami:

```
WHEN strumień[0] > 10 AND strumień[1] != 0
WHEN strumień[0] = 5 OR strumień[0] = 7
WHEN NOT strumień[0] < 0
```

## Przykłady

```
RULE alarm_wysoki
ON pomiary
WHEN pomiary[0] > 100 OR pomiary[0] < -100
DO DUMP -10 TO 10 RETENTION 50

RULE sygnalizacja
ON status
WHEN status[0] = 1 AND status[1] != 0
DO SYSTEM 'systemctl restart sensor-reader'

RULE jednorazowy
ON dane
WHEN NOT dane[0] = 0
DO DUMP -5 TO 0
```

## Dostęp do pól

Warunek odwołuje się do pól strumienia wskazanego w `ON`. Indeks pola odpowiada pozycji w schemacie tego strumienia — tak samo jak w klauzuli `SELECT`. Aliasowanie działa identycznie jak opisano w rozdziale [Aliasowanie](../kompilacja-zapytan/aliasowanie.md).
