# Klauzula VOLATILE

Klauzula `VOLATILE` w poleceniu `SELECT` tworzy strumień przechowywany w pamięci. Na dysku pojawia się jedynie plik deskryptora `.desc` opisujący schemat danych — same dane nigdy nie są zapisywane.

## Działanie

```
SELECT wyrażenie STREAM nazwa FROM źródło VOLATILE
```

Parser ustawia typ przechowywania na `MEMORY` z początkową pojemnością `1`:

```cpp
if (ctx->VOLATILE()) {
    qry.policy = std::make_pair("MEMORY", 1);
}
```

Następnie kompilator wyznacza pojemność wymaganą przez plan. Jeśli inny strumień czyta
historię wyniku `VOLATILE`, bufor może pomieścić więcej niż jeden rekord. Oznacza to, że:

* bufor w pamięci przechowuje co najmniej ostatni rekord oraz historię potrzebną konsumentom,
* dane nie trafiają na dysk,
* deskryptor `.desc` jest tworzony — inne procesy mogą poznać schemat strumienia.

## Różnica względem `STORAGE MEMORY`

| Cecha                | `VOLATILE`                                      | `STORAGE MEMORY`                        |
| -------------------- | ----------------------------------------------- | --------------------------------------- |
| Pojemność bufora     | początkowo 1 rekord; może wzrosnąć według planu | zależna od `RETENTION` i potrzeb planu  |
| Klauzula `RETENTION` | ignorowana                                      | stosowana                               |
| Deskryptor na dysku  | tak                                             | tak                                     |
| Dane na dysku        | nie                                             | nie                                     |

`VOLATILE` przydaje się gdy wynik zapytania jest pobierany przez `xqry` na bieżąco i historia nie jest potrzebna — np. aktualna wartość czujnika udostępniana przez system operacyjny.

## Przykład

```
DECLARE a INTEGER STREAM sensor, 0.1 FILE '/dev/sensor0'

SELECT sensor[0] * 100 STREAM scaled FROM sensor VOLATILE
```

Strumień `scaled` zawiera w każdej chwili jedną, aktualną wartość. Proces `xqry` może ją odczytać przez pamięć współdzieloną.
