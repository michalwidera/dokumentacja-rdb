# Wyrażenia pól i funkcje skalarne

Wyrażenie pola oblicza jedną wartość rekordu wynikowego. Występuje na liście `SELECT`, w
warunku `RULE` oraz jako argument agregatu okna rekordowego. Nie należy go mylić z
wyrażeniem strumieniowym klauzuli `FROM`, które buduje i taktuje cały strumień.

## Budowanie wyrażenia

Operandami są literały liczbowe i tekstowe, symbol `$` wewnątrz generatora, odwołania do
pól oraz wyniki funkcji. Pole można wskazać nazwą, kwalifikowaną nazwą strumienia albo
płaskim indeksem, na przykład `temperature`, `src.temperature` i `src[0]`. Dla liczbowej
deklaracji `a T[N]` goła nazwa `a` oznacza cały wpis tablicowy i nie jest operandem
skalarnym; należy podać `a[0]`...`a[N-1]`. `STRING[N]` jest jednym polem tekstowym.

Podstawowe operatory arytmetyczne to `+`, `-`, `*`, `/` i `^`. Nawiasy zmieniają
grupowanie. Operatory `*` i `/` wiążą mocniej niż `+` i `-`, a potęgowanie `^` wiąże
najmocniej i jest prawostronnie łączne:

```rql
SELECT v*w^2, v^w^2, (v*w)^2 STREAM powers FROM source
```

Powyższe pola znaczą odpowiednio `v*(w^2)`, `v^(w^2)` i `(v*w)^2`. Literał ujemny jest
jednym atomem gramatyki: `-2^2` oznacza `(-2)^2`, natomiast `-v^2` oznacza `-(v^2)`.

Dla typów całkowitych i wymiernych nieujemna potęga całkowita ma semantykę powtarzanego
mnożenia, łącznie z promocją typu i przepełnieniem. Pozostałe przypadki korzystają z
obliczenia zmiennoprzecinkowego; wynik nieskończony albo `NaN` staje się `NULL`. Operandy
tekstowe są niedozwolone.

Wartość `NULL` jest propagowana przez zwykłą arytmetykę. Dzielenie przez zero daje `NULL`
dla każdego typu liczbowego i nie zatrzymuje dalszego przetwarzania strumienia. Reguły
porównań i trójwartościowej logiki warunku `RULE` opisuje rozdział
[Warunek logiczny](../polecenie-rule-warunek-logiczny.md).

> **⚠️ Ostrzeżenie** Po przeplocie `A#B` nie wolno odwoływać się do jego składowych przez
> `A[0]`, `A.pole`, `A[_]` ani `A.*`. Przeplot ma jeden wspólny schemat; należy użyć nazwy
> strumienia wynikowego albo odzyskać składową operatorem `&` lub `%`. Szczegóły opisuje
> rozdział [Aliasowanie](../../kompilacja-zapytan/aliasowanie.md).

## Dostępne funkcje skalarne

Jedyną listą nazw i arności wspólną dla kompilatora i ewaluatora jest tabela
`rqlFunctions.hpp`. Nazwy są dopasowywane bez względu na wielkość liter, a w planie
zapisywana jest postać kanoniczna. Nieznana funkcja albo błędna arność zatrzymuje kompilację;
błąd nie jest odkładany do wykonania.

| Grupa | Funkcje |
| ----- | ------- |
| Matematyczne | `Sqrt`, `Ceil`, `Floor`, `Abs`, `round`, `trunc`, `sin`, `cos`, `exp`, `tan`, `log`, `log2` |
| Obsługa wartości | `isnull`, `null2zero`, `IsZero`, `IsNonZero`, `Length` |
| Konwersje | `to_integer`, `to_float`, `to_double`, `to_string` |

Wszystkie funkcje przyjmują jeden argument wyrażeniowy. Jedynym wyjątkiem jest opcjonalna
szerokość pola wynikowego w `to_string(wyrażenie : szerokość)`.

### Predykaty i wartości brakujące

- `isnull(x)` zwraca 1 dla `NULL` i 0 dla wartości obecnej;
- `null2zero(x)` zamienia `NULL` na całkowite zero, ale wartość obecną przepuszcza bez
  zmiany jej typu;
- `IsZero(x)` i `IsNonZero(x)` zwracają całkowite 1 albo 0 dla argumentu liczbowego.

`null2zero` jest konwersją stratną: po jej wykonaniu nie da się odróżnić pierwotnego braku
od rzeczywistego zera. Nie zastępuje bitmapy `NULL` przechowywanej w pliku `.meta`.

### Długość napisu

`Length(x)` działa wyłącznie na napisie. Liczy długość rzeczywistej wartości do pierwszego
bajtu zerowego, a nie zadeklarowaną szerokość `STRING[N]`. Dla pola `STRING[8]` zawierającego
`alpha` wynikiem jest 5. Argument liczbowy jest błędem wykonania.

### Konwersje

`to_integer`, `to_float` i `to_double` konwertują wartość liczbową albo tekstową do
wskazanego typu. `NULL` przechodzi bez zmiany. `to_integer` obcina część ułamkową w stronę
zera, nie podłoguje: `to_integer(-8/3)` daje `-2`.

`to_string` tworzy pole tekstowe. Bez drugiego członu jego szerokość wynosi 32 bajty;
postać `to_string(x : N)` deklaruje N bajtów. Separatorem jest dwukropek, ponieważ przecinek
rozdziela pola listy `SELECT`:

```rql
SELECT to_string(value : 10), Length(label), null2zero(optional) \
STREAM converted FROM source
```

Szerokość wyniku tekstowego jest ustalana po rozwiązaniu referencji do pól, dlatego czyste
przepisanie `STRING[N]` i konkatenacja tekstowa zachowują poprawny deskryptor. Typ całego
wyrażenia, także liczbowego, wyznacza `compiler::inferFieldShapes()` po rozwiązaniu odwołań
do pól; reguły opisuje rozdział [Równanie typów w górę](../../kompilacja-zapytan/rownanie-typow-w-gore.md).

Zadeklarowana szerokość jest własnością **pola**, a nie skutkiem konkretnego przebiegu
kompilacji. Obowiązuje także wtedy, gdy cały argument jest stały: `to_string(42 : 16)` daje
`STRING[16]`, a nie `STRING[2]`. Upraszczanie wyrażeń zwija argument pod wywołaniem, ale samego
`to_string` nie usuwa — inaczej deklaracja znikałaby razem z programem przy **ponownej**
kompilacji planu, czyli po zapytaniu ad hoc (`xqry -a`), które kompiluje żywy plan drugi raz.

### `sin`, `cos` i `exp`

Wszystkie trzy funkcje przyjmują argument liczbowy i zwracają `DOUBLE`, niezależnie od typu
argumentu. `sin` i `cos` interpretują kąt w **radianach**. Na przykład dla pola `k` typu
`INTEGER` wyrażenia `sin(k)`, `cos(k)` i `exp(k)` dają pola typu `DOUBLE`; wynik nie traci
części ułamkowej. `NULL` na wejściu daje `NULL`, a wynik niefinitywny (np. `exp(1000)`)
również daje `NULL` bez zatrzymania strumienia.

Wyjątkiem jest argument typu `RATIONAL`: kompilator go **odrzuca** i wymaga jawnego
`to_double` — tak samo jak dla `Sqrt`, patrz rozdział niżej.

Zmiana typu `sin` i `cos` względem starszego silnika może zmienić deskryptor `.desc` i układ
rekordu: `INTEGER` oraz `FLOAT` zajmują 4 bajty, a `DOUBLE` 8 bajtów. Istniejący artefakt o
starym schemacie wymaga ponownego utworzenia albo osobnego strumienia wynikowego.

### Funkcje niewymierne nad wartością RATIONAL

`Sqrt`, `sin`, `cos`, `exp`, `tan`, `log` i `log2` **nie przyjmują** argumentu typu `RATIONAL`
— kompilator odrzuca taki zapis kanałem `Check result:` i podaje obejście. Dotyczy to
w praktyce reduktorów strumieniowych, bo `MIN`/`MAX`/`AVG`/`SUMC` dają zawsze `RATIONAL`:

```rql
SELECT * STREAM m FROM AVG(src)
SELECT Sqrt(m[0]) STREAM o FROM m              // odrzucone przy kompilacji
SELECT Sqrt(to_double(m[0])) STREAM o FROM m   // poprawnie
```

Obowiązuje jedna reguła: **funkcja o niewymiernej przeciwdziedzinie nad wartością wymierną
wymaga jawnego `to_double`**. Ta sama reguła obejmuje warunek reguły (`RULE ... WHEN`), który
kompilator sprawdza osobnym przebiegiem.

Dla `Sqrt`, `tan`, `log` i `log2` powodem nie jest utrata precyzji, lecz cicha **błędna
wartość**. Te cztery liczą się przez `double` i wracają rzutem na typ argumentu, a powrót do
`RATIONAL` przybliża wynik ułamkiem o bardzo dużym mianowniku (`Sqrt(2)` daje `19601/13860`,
`log(2)` daje `2731/3940`). `RATIONAL` przechowuje licznik i mianownik w 32 bitach bez kontroli
zakresu, więc dwa kolejne mnożenia przepełniają go i `Sqrt(x)*Sqrt(x)*Sqrt(x)` zwracało
`-4,247` zamiast `+2,828` — ze złym znakiem i bez żadnego błędu.

Dla `sin`, `cos` i `exp` powód jest inny: te trzy kończą na `DOUBLE` i nigdy nie wracają do
`RATIONAL`, więc policzyłyby się poprawnie. Ich odrzucenie jest **decyzją o kontrakcie języka**,
podjętą po to, żeby nie trzeba było pamiętać listy wyjątków — jedna reguła zamiast siedmiu
osobnych zachowań. Ceną jest `to_double` w każdym zapytaniu liczącym np. RMS nad reduktorem.

Ograniczenie nie obejmuje pozostałych funkcji ani innych typów argumentu. Zaokrąglenia `Floor`,
`Ceil`, `round` i `trunc` nad `RATIONAL` są bezpieczne, bo ich wynik jest całkowity, czyli ma
mianownik 1, a `Abs` liczy się wprost na wartości i mianownika nie rusza w ogóle.

Bramka dotyczy **wyłącznie** pary z `RATIONAL` i nie zmienia typu wyniku żadnej funkcji. `tan`,
`log` i `log2` nad `INTEGER` nadal dają `INTEGER`, czyli obcinają część ułamkową — to strata
jawna i zamierzona, nie przepełnienie. Ewentualne doprowadzenie ich do `DOUBLE`, tak jak `sin`,
`cos` i `exp`, zmieniłoby typ pola w `.desc`, więc jest osobnym zadaniem.

> **_NOTE:_** Funkcje i propagację typów sprawdzają testy integracyjne `fncall_runtime_case`,
> `string_field_passthrough`, `issue121_isnull`, `issue128_numeric_to_string` i
> `issue128_string_to_numeric` oraz testy jednostkowe `ut_compiler`, `ut_expeval` i
> `ut_facctxtsrc`.
