---
description: VOLATILE tworzy zapytanie, które nie zajmuje miejsca na dysku.
---

# Klauzula VOLATILE

Klauzula `VOLATILE` w poleceniu `SELECT` tworzy strumień przechowujący wyłącznie jeden rekord w pamięci. Na dysku pojawia się jedynie plik deskryptora `.desc` opisujący schemat danych — same dane nigdy nie są zapisywane.

## Działanie

```
SELECT wyrażenie STREAM nazwa FROM źródło VOLATILE
```

Wewnętrznie kompilator ustawia typ przechowywania na `MEMORY` z pojemnością `1`:

```cpp
if (ctx->VOLATILE()) {
    qry.policy = std::make_pair("MEMORY", 1);
}
```

Oznacza to, że:

* bufor w pamięci przechowuje zawsze tylko jeden, ostatni rekord,
* dane nie trafiają na dysk,
* deskryptor `.desc` jest tworzony — inne procesy mogą poznać schemat strumienia.

## Różnica względem `STORAGE MEMORY`

| Cecha                | `VOLATILE`      | `STORAGE MEMORY`       |
| -------------------- | --------------- | ---------------------- |
| Pojemność bufora     | zawsze 1 rekord | zależna od `RETENTION` |
| Klauzula `RETENTION` | ignorowana      | stosowana              |
| Deskryptor na dysku  | tak             | tak                    |
| Dane na dysku        | nie             | nie                    |

`VOLATILE` przydaje się gdy wynik zapytania jest pobierany przez `xqry` na bieżąco i historia nie jest potrzebna — np. aktualna wartość czujnika udostępniana przez system operacyjny.

## Przykład

```
DECLARE a INTEGER STREAM sensor, 0.1 FILE '/dev/sensor0'

SELECT sensor[0] * 100 STREAM scaled VOLATILE
```

Strumień `scaled` zawiera w każdej chwili jedną, aktualną wartość. Proces `xqry` może ją odczytać przez pamięć współdzieloną.
