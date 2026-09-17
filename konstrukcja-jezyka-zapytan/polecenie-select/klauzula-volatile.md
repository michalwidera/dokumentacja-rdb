# Klauzula VOLATILE

Klauzula `VOLATILE` w poleceniu `SELECT` tworzy strumień przechowywany w pamięci. Na dysku pojawia się jedynie plik deskryptora `.desc` opisujący schemat danych — same dane nigdy nie są zapisywane.

## Domyślna ulotność i wyjątek PERSISTENT

Dyrektywa `DEFAULT VOLATILE` ustawia przechowywanie w pamięci dla wyników
`SELECT` bez jawnej polityki oraz dla substratów kompilatora. Zastępuje więc
powtarzane `VOLATILE` i dyrektywę `SUBSTRAT 'memory'`:

```rql
DEFAULT VOLATILE
DECLARE a INTEGER STREAM sensor, 0.1 FILE '/dev/sensor0'
SELECT sensor[0]*100 STREAM scaled  FROM sensor
SELECT scaled[0]     STREAM history FROM scaled PERSISTENT
```

`scaled` pozostaje w pamięci, a `history` zapisuje dane na dysku według zwykłych
zasad `FILE`, `RETENTION` i `STORAGE`. `PERSISTENT` dotyczy tylko wyniku danego
`SELECT`; jego substraty nadal dziedziczą domyślną ulotność.

Dyrektywa może wystąpić tylko raz, przed pierwszym `DECLARE`, `SELECT` lub `RULE`.
Nie zmienia źródeł `DECLARE`. Bez niej dotychczasowe programy zachowują swoje
ustawienia. `VOLATILE` i `PERSISTENT` są wzajemnie wykluczającymi się klauzulami.

Jawne `STORAGE profil` przy `SELECT` zastępuje ustawienie domyślne; np.
`STORAGE DEFAULT` wybiera zwykły magazyn plikowy. Jawne `VOLATILE` zachowuje
pierwszeństwo nad `STORAGE`, tak jak wcześniej. Połączenie `PERSISTENT STORAGE
MEMORY` jest błędem. Jawne `SUBSTRAT 'profil'` wybiera magazyn substratów niezależnie
od kolejności tych dwóch dyrektyw w nagłówku. Samo `FILE` lub `RETENTION` nie
wyłącza domyślnej ulotności: do zapisu historii należy dodać `PERSISTENT`.

## Działanie

```rql
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

```rql
DECLARE a INTEGER STREAM sensor, 0.1 FILE '/dev/sensor0'

SELECT sensor[0] * 100 STREAM scaled FROM sensor VOLATILE
```

Strumień `scaled` zawiera w każdej chwili jedną, aktualną wartość. Proces `xqry` może ją odczytać przez pamięć współdzieloną.
