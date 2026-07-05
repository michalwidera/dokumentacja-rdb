# Wyrażenia algebraiczne

Zdefiniowana algebra pociąga za sobą możliwość definicji wyrażeń algebraicznych. Typowe wyrażenia algebraiczne w zbiorze liczb wymiernych to materiał przerabiany w szkole podstawowej. Wyrażenia algebraiczne w systemie RetractorDB występują w dwóch formach. Na liście pól polecenia SELECT – mamy wyrażenia typowe, znane ze szkoły podstawowej. Na liście argumentów polecenia SELECT w klauzuli FROM mamy wyrażenie algebraiczne zbudowane w oparciu o nową, zdefiniowaną algebrę.

Oznacza to że na liście pól po klauzuli SELECT operator plus oznacza jedno a w klauzuli FROM – oznacza zupełnie coś innego. Niewinnie wyglądające zapytanie z definicji łączy dwa zupełnie inne światy i pojęcia. Jeden algebry opartej na liczbach drugiej opartej na regularnych seriach czasowych.

Przykład. Jako przykład przedstawione zostanie wyrażenie algebraiczne zbudowane w zbiorze regularnych serii czasowych (zwanych dalej strumieniami). Zakładając istnienie dwóch strumieni: A(a<sub>1</sub> int, a<sub>2</sub> int),1 oraz B(b<sub>1</sub> int),½ – gdzie,

* A oznacza strumień zawierający w każdym rekordzie dwa pola o wartościach typu int – a<sub>1</sub> oraz a<sub>2</sub>, napływające raz na sekundę, oraz
* B zawierający w każdym rekordzie pole typu int o nazwie b<sub>1</sub> napływające dwa razy na sekundę.

To wyrażenie algebraiczne postaci C=A+B stworzy strumień danych o polach C(a<sub>1</sub> int, a<sub>2</sub> int, b<sub>1</sub> int),½.

Aby dokonać przeplotu strumienia danych zbiory A i B powinny posiadać te same schematy danych. Załóżmy więc że istnieje strumień D(d<sub>1</sub> int),1 – napływający podobnie jak strumień A – raz na sekundę.

To wyrażenie algebraiczne postaci E=B#D stworzy strumień: E(e<sub>1</sub> int),⅓. Szybkość ⅓ bierze się ze wzoru (1\*½)/(1+½). Wzór znajdziesz przy definicji operacji przeplotu.

W tak zdefiniowanych strumieniach nadal poprawne jest wyrażenie:

```
F=((B#D)+A)>2
```

I takie wyrażenia mogą się pojawić jako poprawne względem opracowanej algebry szeregów czasowych w treści zapytania.

## Dalsze przykłady

Pozostając przy zdefiniowanych powyżej strumieniach A(a<sub>1</sub> int, a<sub>2</sub> int),1, B(b<sub>1</sub> int),½ i D(d<sub>1</sub> int),1 oraz strumieniach wynikowych C=A+B i E=B#D – poniżej zestawiono kolejne poprawne wyrażenia algebraiczne. Odpowiedniki wszystkich tych wyrażeń występują w klauzulach FROM zapytań w testach integracyjnych systemu i są weryfikowane przy każdej kompilacji projektu.

Przeplot wyniku przeplotu:

```
G=E#D
```

Strumień E ma szybkość ⅓, strumień D szybkość 1, oba mają zgodny schemat z jednym polem int. Wzór z definicji przeplotu daje szybkość (⅓·1)/(⅓+1)=¼, więc G(g<sub>1</sub> int),¼. Wynik jednej operacji jest pełnoprawnym strumieniem i może być argumentem kolejnej.

Suma trzech strumieni:

```
H=A+B+D
```

Suma skleja krotki, więc schemat wyniku to konkatenacja schematów, a tempo narzuca najszybszy składnik: H(a<sub>1</sub> int, a<sub>2</sub> int, b<sub>1</sub> int, d<sub>1</sub> int),½.

Suma z przesuniętym składnikiem oraz przesunięcie argumentu przeplotu:

```
I=D+((A+B)>1)
J=(B>1)#D
```

Przesunięcie sekwencji nie zmienia szybkości strumienia – zmienia tylko dostęp do danych o zadaną liczbę próbek. Dlatego I ma szybkość min(1,½)=½, a J – tak jak E – szybkość ⅓.

Rozplątanie:

```
K=E&1
L=E%½
```

Prawym argumentem operatorów rozplątania jest liczba wymierna, nie strumień. Podstawiając do wzorów z definicji rozplątania: K ma szybkość (⅓·1)/|⅓−1|=½ – rozplątanie lewostronne odzyskuje ze splotu E strumień B. Analogicznie L ma szybkość (⅓·½)/|⅓−½|=1 – rozplątanie prawostronne odzyskuje strumień D. Rozplątanie jest odwrotnością przeplotu, tak jak dzielenie jest odwrotnością mnożenia.

Różnica:

```
M=C-1
```

Różnica jest operacją odwrotną do sumy – wydobywa ze sklejonego strumienia C składnik wskazany liczbą wymierną po prawej stronie operatora.

Agregacja i serializacja:

```
N=A@(1,4)
P=A@(1,-4)
R=A@(2,2)
S=(A@(2,2))@(1,1)
```

N tworzy ruchome okno szerokości 4 przesuwane o jeden element, P – dzięki ujemnej szerokości – buduje te same okna w odbiciu lustrzanym, R tworzy okna rozłączne (skok równy szerokości). Wyrażenie S pokazuje, że wynik operacji Agse może być argumentem kolejnej operacji Agse.

Wszystkie powyższe formy można łączyć w dowolnie złożone wyrażenia – jak F=((B#D)+A)>2 z przykładu powyżej – o ile schematy danych argumentów spełniają wymagania poszczególnych operacji.

## Pokrycie przykładów w testach integracyjnych

Każda z przytoczonych form wyrażeń ma swój odpowiednik w testach integracyjnych repozytorium RetractorDB (katalogi `test/IntegrationTest_serial` i `test/IntegrationTest_parallel`), wykonywanych przy każdej kompilacji projektu:

| Wyrażenie z rozdziału | Forma w teście | Test integracyjny |
|---|---|---|
| C=A+B (suma) | `s1+s2`, `core0+core1` | `IntegrationTest_serial/issue167_dedup_positive`, `IntegrationTest_serial/Data` (all-operators) |
| E=B#D (przeplot) | `core0#core1` | `IntegrationTest_serial/operations`, `IntegrationTest_serial/Data` (all-operators) |
| G=E#D (przeplot kaskadowy) | `(s1#s2)#s3`, `s1#s2#s3` | `IntegrationTest_serial/issue167_triarg` |
| H=A+B+D (suma wieloargumentowa) | `s1+s2+s3`, `s1+s2+s3+s4` | `IntegrationTest_serial/issue167_triarg` |
| I=D+((A+B)>1) | `s3+((s1+s2)>1)` | `IntegrationTest_serial/issue167_dedup_cascaded` |
| J=(B>1)#D oraz (B#D)>1 | `(core1>1)#core2`, `(core1#core2)>1` | `IntegrationTest_parallel/subquery` |
| K=E&1, L=E%½ (rozplątanie) | `core0&1.5`, `core0%4` | `IntegrationTest_serial/Data` (all-operators) |
| M=C−1 (różnica) | `core0-1/2` | `IntegrationTest_serial/Data` (all-operators) |
| przesunięcie sumy, jak w F | `(s1+s2)>1`, `(core0+core1)>5` | `IntegrationTest_serial/issue167_dedup_field_names`, `IntegrationTest_serial/issue56_timeshift` |
| N=A@(1,4), P=A@(1,−4), R=A@(2,2) | `core1@(1,4)`, `core1@(1,-4)`, `core1@(2,2)` | `IntegrationTest_serial/agse1` (dalsze warianty skoku i szerokości: `agse2`, `agse3`) |
| S=(A@(2,2))@(1,1) (Agse kaskadowe) | `signalText3@(1,1)` | `IntegrationTest_serial/agse1` |

Testy porównują wyniki wykonania zapytań z plikami wzorcowymi (pattern), więc powyższe wyrażenia są weryfikowane nie tylko składniowo, ale i co do wartości oraz szybkości strumieni wynikowych.
