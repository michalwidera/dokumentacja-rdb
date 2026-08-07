# Formalne podstawy i dowody

W rozdziale o [algebrze regularnych serii czasowych](algebra-regularnych-serii-czasowych.md) przedstawiłem zbiór operatorów i opisujące je równania. Świadomie pominąłem tam formalne dowody – chciałem najpierw pokazać _co_ system robi, zanim wyjaśnię _dlaczego_ wolno mu to robić. Ta strona uzupełnia tę lukę. Zebrałem tu formalny szkielet algebry: powiązanie operatorów strumieniowych z teorią układów pokrywających oraz dowody twierdzeń, na których opiera się poprawność i optymalizacja planów zapytań.

> **ℹ️ Info**
>
> Cała poniższa konstrukcja trzyma się w jednej dziedzinie – liczb wymiernych. To nie jest ozdobnik. To jest cały sens. Twierdzenie Beatty potrzebuje liczb niewymiernych, których w komputerze nie ma. Twierdzenie Fraenkela pozwala zejść do liczb wymiernych. Dowody na tej stronie pokazują, że operacje przeplotu i rozplątania są szczególnym przypadkiem sekwencji Beatty spełniającym postulaty Fraenkela – a więc są realizowalne wyłącznie na liczbach wymiernych.


## Układy pokrywające jako fundament

Literatura dotycząca układów pokrywających (ang. _Covering Systems_) [\[4\]](../literatura.md#4) związana jest z kombinatoryką i kryptoanalizą w obszarze teorii liczb. Rozważanym problemem jest sposób wyznaczania podziału zbioru dodatnich liczb naturalnych. Mówimy, że dwie sekwencje dokonują podziału zbioru dodatnich liczb naturalnych, jeśli zbiory powstałe z elementów tych sekwencji po operacji przecięcia tworzą zbiór pusty, a ich suma tworzy zbiór dodatnich liczb naturalnych.

Podstawą rozważań jest sparametryzowana sekwencja Beatty. W postaci ogólnej zapisujemy ją z funkcją podłogi:

\\[
\mathcal{B}(\alpha ,\alpha ^{\prime }) := \left( \left\lfloor \frac{n-\alpha ^{\prime }}{\alpha }\right\rfloor \right) _{n=1}^{\infty }
\\]

Ta jedna definicja generuje całą rodzinę sekwencji. Wyniki o podziale zbioru dotyczą zawsze **pary** jej egzemplarzy o różnych parametrach: parę zapisujemy jako B(α, α′) i B(β, β′), przy czym drugi zapis oznacza człon dopełniający.

Parametry tej sekwencji mają czytelną interpretację geometryczną:

* α oznacza gęstość sekwencji,
* 1/α oznacza nachylenie,
* α′ oznacza przesunięcie,
* −α′/α oznacza y-przechwycenie (punkt przecięcia z osią rzędnych).

Twierdzenie [Beatty](../literatura.md#1) gwarantuje podział zbioru dla liczb niewymiernych. Twierdzenie [Fraenkela](../literatura.md#2) jest uogólnieniem, które – co dla nas kluczowe – dopuszcza również liczby wymierne, pod warunkiem spełnienia pięciu postulatów (przytoczonych w [rozdziale wstępnym](README.md)). Przystępny dowód twierdzenia Fraenkela można odnaleźć w pracy K. O'Bryanta _„Fraenkel's partition and Brown's decomposition"_ [\[23\]](../literatura.md#23).

Cała dalsza część tej strony sprowadza się do jednej myśli: pokazania, że operatory strumieniowe są w istocie maszynami generującymi sekwencje Beatty, które dokonują podziału (pokrycia) zbioru liczb naturalnych.

## Narzędzia: własności podłogi i sufitu

Dowody operują niemal wyłącznie na funkcjach podłogi (⌊x⌋ – część całkowita) i sufitu (⌈x⌉ – najmniejsza liczba całkowita nie mniejsza od x). Przytaczam więc najpierw zestaw tożsamości, które będą wielokrotnie wykorzystywane. Niech x ∈ ℝ, a C oznacza liczbę całkowitą:

\\[
\left\lfloor x\right\rfloor = \left\lceil x\right\rceil \iff x \in \mathbb{Z}
\\]

\\[
\left\lfloor x\right\rfloor + 1 = \left\lceil x\right\rceil \iff x \in \mathbb{R} \setminus \mathbb{Z}
\\]

\\[
\left\lfloor x + C\right\rfloor = \left\lfloor x\right\rfloor + C
\\]

(ostatnia tożsamość zachodzi dla każdego C ∈ ℤ). Dodatkowo, w analizie residuum sekwencji rozplątania wykorzystamy zależności wiążące największy wspólny dzielnik (nwd) z dziedziną ilorazu a/b. Dla a, b ∈ ℕ<sub>>0</sub>:

\\[
\operatorname{nwd}(a,b) = b \iff \frac{a}{b} \in \mathbb{N}
\\]

a w przeciwnym przypadku:

\\[
1 \leq \operatorname{nwd}(a,b) \leq \min(a,b)
\\]

Te dwa przypadki rozłącznie pokrywają całą interesującą nas dziedzinę – co pozwoli przeprowadzić dowód „przez przypadki".

## Operatory w zapisie formalnym

Operatory wprowadzone w języku zapytań mają swoje formalne odpowiedniki. Poniższa tabela wiąże zapis formalny (stosowany w dowodach) z symbolami spotykanymi w [języku zapytań](../konstrukcja-jezyka-zapytan/README.md):

| Operacja | Symbol formalny | Symbol w języku zapytań |
| --- | --- | --- |
| Rzutowanie | π | lista pól po `SELECT` |
| Selekcja | σ | warunek logiczny |
| Suma | Σ | `+` |
| Różnica | δ | `-` |
| Przeplot (splątanie) | φ | `#` |
| Rozplątanie i jego dopełnienie | Θ, ∼Θ | `&` , `%` |
| Agregacja i serializacja (AGSE) | Ψ | `@` |
| Przesunięcie | τ | `>` |

Dla samodzielności dowodów przytaczam dwie definicje, do których będę się bezpośrednio odwoływał.

**Przeplot** φ(A, B) tworzy strumień wynikowy, którego kolejne krotki wyznacza reguła:

\\[
c_{n}= \left\\{ \begin{array}{cc} b_{n-\left\lfloor n z \right\rfloor } & \left\lfloor n z \right\rfloor = \left\lfloor \left( n+1\right) z \right\rfloor \\\\ a_{\left\lfloor n z \right\rfloor } & \left\lfloor n z \right\rfloor \neq \left\lfloor \left( n+1\right) z \right\rfloor \end{array} \right. , \ z = \frac{\Delta _{b}}{\Delta _{a}+\Delta _{b}}, \ \Delta _{c}=\frac{\Delta _{a}\Delta _{b}}{\Delta _{a}+\Delta _{b}}
\\]

**Rozplątanie** definiują dwa komplementarne wzory – operator Θ odtwarzający pierwotny strumień oraz operator ∼Θ wyznaczający „resztę" rozplątania:

\\[
a_{n} = c_{n+ \left\lceil \frac{(n+1)\Delta _{a}}{\Delta _{b}} \right\rceil },\ \Delta _{a}=\frac{\Delta _{c}\Delta _{b}}{\left\vert \Delta _{c}-\Delta _{b}\right\vert }
\\]

\\[
b_{n} = c_{n+\left\lfloor \frac{n\Delta_{b}}{\Delta_{a}}\right\rfloor},\ \Delta_{b}=\frac{\Delta_{c}\Delta_{a}}{\left\vert \Delta_{c}-\Delta_{a}\right\vert }
\\]

## Twierdzenie 1: przeplot zapewnia pokrycie zbiorów

> **✅ Uwaga**
>
> **Twierdzenie.** Operacja splątania (przeplotu) zapewnia sekwencyjne pokrycie obu zbiorów indeksów strumieni danych będących jej argumentami: każdy element strumienia A i każdy element strumienia B zostaje wybrany dokładnie raz, po kolei, bez przerw i bez powtórzeń.


**Dowód.** Ponieważ 0 < z < 1, przyrost

\\[
d_{n} := \left\lfloor \left( n+1\right) z \right\rfloor - \left\lfloor n z \right\rfloor
\\]

dla każdego n ≥ 0 równy jest 0 albo 1. Równanie przeplotu wybiera element strumienia B dokładnie w tych krokach, w których d<sub>n</sub> = 0 (gałąź równości), a element strumienia A dokładnie w krokach z d<sub>n</sub> = 1.

Rozważmy indeks wyboru z ciągu B: x<sub>n</sub> = n − ⌊nz⌋. W jednym kroku x<sub>n+1</sub> − x<sub>n</sub> = 1 − d<sub>n</sub>: indeks rośnie o dokładnie 1 w każdym kroku wybierającym z B, a poza tym pozostaje bez zmian. Jeśli więc n < n′ są dwoma kolejnymi krokami wybierającymi z B, to x<sub>n′</sub> = x<sub>n</sub> + 1. Pierwszym krokiem wybierającym z B jest n = 0, gdyż z 0 < z < 1 wynika ⌊0⌋ = ⌊z⌋ = 0, czyli d<sub>0</sub> = 0, a przy tym x<sub>0</sub> = 0. Wybory z ciągu B używają zatem indeksów 0, 1, 2, … po kolei, bez przerw i powtórzeń.

Symetrycznie: indeks wyboru z ciągu A, czyli ⌊nz⌋, rośnie o dokładnie 1 w każdym kroku wybierającym z A (d<sub>n</sub> = 1), a poza tym pozostaje bez zmian; w pierwszym takim kroku jego wartość wynosi 0 (wszystkie wcześniejsze kroki mają d = 0). Elementy ciągu A również są więc wybierane dokładnie raz każdy, po kolei. ∎

## Twierdzenie 2: rozplątanie spełnia postulaty Fraenkela

To jest centralne twierdzenie tej strony. Dowodzi, że obie sekwencje opisujące operację rozplątania są szczególnym przypadkiem sekwencji Beatty spełniającym postulaty twierdzenia Fraenkela dla liczb wymiernych. Bez tego twierdzenia cały system pozostaje jedynie obietnicą.

> **✅ Uwaga**
>
> **Twierdzenie.** Niech a, b ∈ ℕ<sub>>0</sub> reprezentują wymierny stosunek temp strumieni składowych, ∆<sub>a</sub>/∆<sub>b</sub> = a/b. Obie sekwencje wyboru krotek opisujące operację rozplątania są – z dokładnością do wyrównania indeksów wskazanego w dowodzie – szczególnym przypadkiem sekwencji Beatty spełniającym postulaty twierdzenia Fraenkela dla parametrów wymiernych. W konsekwencji dokonują one podziału zbioru ℕ₀ := ℕ ∪ {0}, czyli zbioru indeksów strumienia splątanego, a rozplątanie dokładnie odwraca splątanie przy użyciu wyłącznie arytmetyki liczb wymiernych.


**Dowód – część pierwsza (sprowadzenie do postaci Beatty).** Sekwencja wyboru krotek residuum rozplątania (operator ∼Θ) ma postać:

\\[
\left( n + \left\lfloor \frac{nb}{a} \right\rfloor \right) _{n=0}^{\infty }
\\]

Jej wyraz początkowy (n = 0) wynosi 0; wyrazy dla n ≥ 1 tworzą część Beatty. Dla n ∈ ℕ, na mocy własności ⌊x + C⌋ = ⌊x⌋ + C, zachodzi n + ⌊nb/a⌋ = ⌊n + nb/a⌋, poszukujemy więc α, α′ takich, że:

\\[
\left( \left\lfloor \frac{n-\alpha ^{\prime }}{\alpha }\right\rfloor \right) _{n=1}^{\infty } = \left( \left\lfloor n\frac{a + b}{a} \right\rfloor \right) _{n=1}^{\infty }
\\]

Odczytując nachylenie i wyraz wolny: przy przesunięciu α′ = 0 otrzymujemy α = a/(a+b), a sekwencja wyboru ograniczona do n ≥ 1 to dokładnie:

\\[
\mathcal{B}\\!\left( \frac{a}{a + b}, 0 \right) = \left( \left\lfloor n\frac{a + b}{a} \right\rfloor \right) _{n=1}^{\infty }
\\]

**Dowód – część druga (weryfikacja pięciu postulatów i wyznaczenie residuum).** Sprawdzamy kolejno postulaty twierdzenia Fraenkela dla α = a/(a+b), α′ = 0:

1. Wartość α = a/(a+b) dla a, b > 0 jest większa od zera i mniejsza od jedności.
2. Warunek α + β = 1 jest spełniony dla β = b/(a+b).
3. Dla α′ = 0 postulat jest równoważny postulatowi 1.
4. Postulat jest pusty, gdyż α jest liczbą wymierną.
5. Najmniejszą liczbą q, dla której qα ∈ ℕ, jest q = (a+b)/nwd(a,b); wówczas warunek 1/q ≤ α + α′ = α jest spełniony, a warunek ⌈qα′⌉ + ⌈qβ′⌉ = 1 przy α′ = 0 wymusza ⌈qβ′⌉ = 1, czyli 0 < β′ ≤ nwd(a,b)/(a+b). Każda dopuszczalna wartość generuje tę samą sekwencję (dopełnienie sekwencji B(a/(a+b), 0) w ℕ jest jednoznaczne); przyjmujemy β′ = nwd(a,b)/(a+b).

Sekwencją dopełniającą sekwencję B(a/(a+b), 0) w sensie postulatów Fraenkela jest zatem:

\\[
\mathcal{B}\\!\left( \frac{b}{a + b}, \frac{\operatorname{nwd}(a, b)}{a + b} \right)
\\]

Po przeindeksowaniu n ↦ n + 1, tak aby biegła od n = 0 – zgodnie z sekwencjami wyboru w definicji rozplątania – przyjmuje ona postać:

\\[
\left( \left\lfloor \frac{(n + 1) - \frac{\operatorname{nwd}(a,b)}{a+b}}{\frac{b}{a+b}} \right\rfloor \right) _{n=0}^{\infty }
\\]

Rozwijając powyższe wyrażenie:

\\[
\left\lfloor \frac{(n + 1) - \frac{\operatorname{nwd}(a,b)}{a+b}}{\frac{b}{a+b}} \right\rfloor = \left\lfloor n\frac{a}{b} + n + \frac{a}{b} + 1 - \frac{\operatorname{nwd}(a, b)}{b} \right\rfloor
\\]

Porównując to – wyraz po wyrazie dla n ≥ 0 – z sekwencją wyboru krotek strumienia odtwarzanego (operator Θ):

\\[
\left( n + \left\lceil \frac{(n + 1)a}{b} \right\rceil \right) _{n=0}^{\infty }
\\]

i wydzielając część całkowitą n + 1 na mocy własności ⌊x + C⌋ = ⌊x⌋ + C, teza sprowadza się (po podstawieniu n w miejsce n + 1, tak że n przebiega zbiór ℕ<sub>>0</sub>) do tożsamości:

\\[
\left\lfloor n\frac{a}{b} - \frac{\operatorname{nwd}(a, b)}{b} \right\rfloor + 1 = \left\lceil n\frac{a}{b} \right\rceil ,\quad n \in \mathbb{N}_{>0}
\\]

**Dowód – część trzecia (analiza przypadków).** Korzystając z własności współczynnika nwd(a, b), rozważamy dwa rozłączne przypadki pokrywające całą dziedzinę.

_Przypadek 1: nwd(a, b) = b, czyli a/b ∈ ℕ._ Wtedy n·a/b ∈ ℕ, więc na mocy tożsamości ⌊x⌋ = ⌈x⌉ ⟺ x ∈ ℤ mamy ⌈n·a/b⌉ = ⌊n·a/b⌋, a na mocy ⌊x + C⌋ = ⌊x⌋ + C:

\\[
\left\lfloor n\frac{a}{b} - 1 \right\rfloor + 1 = \left\lfloor n\frac{a}{b} \right\rfloor
\\]

Obie strony dowodzonej tożsamości pokrywają się.

_Przypadek 2: b ∤ a, czyli 1 ≤ nwd(a, b) < b oraz 0 < nwd(a,b)/b < 1._

Jeśli n·a/b ∉ ℤ, to na mocy ⌊x⌋ + 1 = ⌈x⌉ ⟺ x ∈ ℝ ∖ ℤ zachodzi ⌈n·a/b⌉ = ⌊n·a/b⌋ + 1. Część ułamkowa liczby n·a/b jest niezerową wielokrotnością nwd(a,b)/b, a więc wynosi co najmniej nwd(a,b)/b; odjęcie nwd(a,b)/b od n·a/b nie może zatem przekroczyć w dół liczby całkowitej poniżej ⌊n·a/b⌋, skąd:

\\[
\left\lfloor n\frac{a}{b} - \frac{\operatorname{nwd}(a, b)}{b} \right\rfloor = \left\lfloor n\frac{a}{b} \right\rfloor
\\]

i dowodzona tożsamość zachodzi.

Jeśli n·a/b ∈ ℤ, to ⌈n·a/b⌉ = n·a/b, a ponieważ 0 < nwd(a,b)/b < 1:

\\[
\left\lfloor n\frac{a}{b} - \frac{\operatorname{nwd}(a, b)}{b} \right\rfloor = n\frac{a}{b} - 1
\\]

co ponownie daje dowodzoną tożsamość.

Obie sekwencje wyboru opisujące operację rozplątania są więc – z dokładnością do jednostkowego przeindeksowania z części drugiej – sekwencjami Beatty spełniającymi postulaty Fraenkela dla parametrów wymiernych: para B(a/(a+b), 0) i B(b/(a+b), nwd(a,b)/(a+b)) dokonuje podziału zbioru ℕ, a wraz z początkowym wyrazem residuum 0 z części pierwszej – podziału zbioru ℕ₀, pełnego zbioru indeksów strumienia splątanego. Strumień odtworzony i residuum są zatem dokładne. ∎

> **✅ Uwaga**
>
> **Wniosek (dokładna odwracalność na liczbach wymiernych).** Dla strumieni o tempach wymiernych operatory Θ i ∼Θ odtwarzają strumienie składowe φ(A, B) dokładnie (bit w bit): żadna krotka nie ginie, nie dubluje się ani nie zmienia kolejności względem swojego strumienia składowego. Para (φ; Θ, ∼Θ) zachowuje się więc jak mnożenie i dzielenie, a para (Σ; δ) jak dodawanie i odejmowanie w zbiorze regularnych serii czasowych.

> **⚠️ Ostrzeżenie**
>
> Praktyczny morał z tego dowodu: w implementacji nie wolno opuszczać dziedziny liczb wymiernych nawet na chwilę. Niejawne rzutowanie wyniku pośredniego na liczbę zmiennoprzecinkową łamie założenia powyższego twierdzenia. Materializację do postaci zmiennoprzecinkowej należy odłożyć do momentu jawnego zastosowania operacji podłogi lub sufitu.


## Własności operatorów wykorzystywane w optymalizacji

W oparciu o przedstawioną algebrę można wykazać szereg własności strumieni danych. Mają one bezpośrednie zastosowanie w systemie zarządzania danymi – w trakcie optymalizacji planów zapytań oraz interpretacji wyników.

### Zaburzenie kolejności zdarzeń

> **✅ Uwaga**
>
> **Twierdzenie.** Kolejność elementów w strumieniu nie odzwierciedla faktycznej kolejności występowania elementów w świecie rzeczywistym.


**Dowód (przez kontrprzykład).** Rozważmy dwa strumienie:

```
Alfa(znak),2:    {1,2,3,4,5,6,...}
Epsilon(znak),3: {a,b,c,d,e,f,...}
```

Wyrażenie φ(Epsilon, Alfa) tworzy strumień wynikowy:

```
Tau(znak),6/5:   {1,2,a,3,b,4,5,c,6,d,...}
```

W strumieniu Tau krotka oznaczona literą `c` występuje po krotce oznaczonej cyfrą `5`. Tymczasem krotka `c` pojawia się w strumieniu Epsilon w 9. sekundzie, a krotka `5` w strumieniu Alfa – w 10. sekundzie. Naturalny porządek zdarzeń został w strumieniu wynikowym naruszony. Wniosek: prowadząc analizę względem czasu zawartego w strumieniach, konieczne jest zastosowanie operacji rozplątania w celu uzyskania pierwotnej postaci strumieni danych. ∎

### Przemienność sumowania

> **✅ Uwaga**
>
> **Twierdzenie.** Operacja sumowania strumieni danych, z pominięciem kolejności atrybutów, jest przemienna.


**Dowód.** Załóżmy ∆<sub>a</sub> ≤ ∆<sub>b</sub>; przypadek przeciwny jest symetryczny. Pierwszy przypadek definicji sumy daje jako n-ty element strumienia Σ(A, B) krotkę:

\\[
c_{n} = \left( a_{n},\ b_{\left\lfloor n\Delta_{a}/\Delta_{b} \right\rfloor} \right)
\\]

natomiast dla Σ(B, A) role argumentów są zamienione i zastosowanie ma jej drugi (a przy ∆<sub>a</sub> = ∆<sub>b</sub> – pierwszy) przypadek, co daje n-ty element:

\\[
c_{n} = \left( b_{\left\lfloor n\Delta_{a}/\Delta_{b} \right\rfloor},\ a_{n} \right)
\\]

Oba strumienie niosą ∆<sub>c</sub> = ∆<sub>a</sub>. Pokrywają się więc z dokładnością do kolejności sklejonych atrybutów. ∎

### Metoda dopasowania przeplotu

Operacja przeplotu nie jest w ogólności przemienna: ponieważ 0 < z < 1, w punkcie n = 0 zawsze zachodzi gałąź równości w definicji przeplotu, więc strumień φ(A, B) zaczyna się od elementu b₀, a strumień φ(B, A) – od elementu a₀. Przeplot jest jednak ekwiwariantny względem przesunięć czasowych dopasowanych do temp strumieni – co jest cenne w optymalizacji planów zapytań.

W realizacji przyczynowej strumień ma postać
\\(\widehat{S}=((s_n,\Delta),W_S)\\), gdzie \\(W_S\\) jest ogonem startowym.
Przeliczenie ogona producenta na sloty wyjścia definiujemy jako:

\\[
\operatorname{conv}(w,\Delta_s,\Delta_o)
:=\left\lceil\frac{w\Delta_s}{\Delta_o}\right\rceil
\\]

Dla przeplotu o interwale
\\(\Delta_c=\Delta_a\Delta_b/(\Delta_a+\Delta_b)\\) ogon wynosi:

Niech \\(\Delta_a/\Delta_b=p/q\\), gdzie \\(p,q\in\mathbb{N}_{>0}\\)
i \\(\gcd(p,q)=1\\). W fazie drugiego argumentu o numerze \\(j\\) wymagane
wyprzedzenie przyczynowe wynosi:

\\[
h_j
:=\left\lceil\frac{(j+1)q}{p}\right\rceil
-\left\lfloor\frac{jq}{p}\right\rfloor,
\qquad 0\le j<p
\\]

Własny ogon przeplotu musi zabezpieczyć najgorszą fazę całego okresu:

\\[
H_{a,b}
:=\max_{0\le j<p}h_j
=\left\lceil\frac{p+q-1}{p}\right\rceil
\\]

Rozpisanie \\(q=mp+r\\) i wykorzystanie faktu, że dla względnie pierwszych
\\(p,q\\) reszty \\(jq\bmod p\\) przebiegają wszystkie klasy reszt w jednym
okresie, daje powyższą postać zamkniętą. W szczególności samo
\\(\lceil\Delta_b/\Delta_a\rceil=\lceil q/p\rceil\\) zabezpiecza pierwszy
odczyt B, lecz nie zawsze najgorszą późniejszą fazę.

\\[
W_{\varphi(A,B)}
=\max\left(
\operatorname{conv}(W_A,\Delta_a,\Delta_c),
\operatorname{conv}(W_B,\Delta_b,\Delta_c)
+H_{a,b}
\right)
\\]

Składnik \\(H_{a,b}\\) jest fazowo bezpiecznym własnym wyprzedzeniem
przyczynowym przeplotu względem drugiego argumentu. Sloty ogona nie są
rekordami.

Przesunięcie \\(\tau_m\\) nie zmienia emitowanego ciągu rekordów, ale zmienia
**indeks**, pod którym ten ciąg się pojawia: rekord \\(n\\) niesie treść rekordu
\\(n-m\\). Rekordy o indeksie mniejszym od \\(O_S+m\\) nie mają definicji, więc

\\[
O_{\tau_m(S)}=O_S+m,
\qquad
W_{\tau_m(S)}=\max\left(0,\;W_S-m\right)
\\]

Ogon **maleje**: rekord \\(n-m\\) jest starszy od bieżącego, więc dostępny tym
bardziej — deficyt slotu wynosi \\(W_S-m\\) i jest stały. Szczegóły i pomiar:
[Ogony, początki logiczne i obserwowalność
operatorów](ogony-i-obserwowalnosc-operatorow.md).

> **✅ Uwaga**
>
> **Twierdzenie (R1, przemienność przesunięcia z przeplotem).** Jeśli liczby
> i, k ∈ ℕ wybrano tak, że i·∆<sub>a</sub> = k·∆<sub>b</sub> (oba argumenty
> przesunięte o ten sam czas), to przeplot strumieni przesuniętych i przeplot
> strumieni pierwotnych przesunięty o sumę tych liczb mają **ten sam ciąg
> rekordów, ten sam interwał i ten sam początek logiczny**. Ich ogony spełniają
> nierówność — strona sfaktoryzowana nigdy nie jest późniejsza.

Formalnie, dla \\(L:=i+k\\):

\\[
\operatorname{Obs}\Bigl(\varphi\bigl(\tau_{i}(A),\tau_{k}(B)\bigr)\Bigr)
=\operatorname{Obs}\Bigl(\tau_{i+k}\bigl(\varphi(A,B)\bigr)\Bigr),
\qquad i\Delta_{a}=k\Delta_{b},\quad i,k\in\mathbb{N}
\\]

\\[
W_{\mathrm{RHS}}=\max\left(0,\;W_{\varphi(A,B)}-L\right)\le W_{\mathrm{LHS}}
\\]

gdzie \\(\operatorname{Obs}\\) jest częścią wartościową obserwacji (interwał,
początek logiczny, ciąg rekordów z mapą `NULL`, deskryptor, ślad luk, polityka
materializacji) — patrz [Ogony, początki logiczne i obserwowalność
operatorów](ogony-i-obserwowalnosc-operatorow.md).

**Dowód.**

*Interwał.* Obie strony powstają z tego samego przeplotu, więc mają
\\(\Delta_c=\Delta_a\Delta_b/(\Delta_a+\Delta_b)\\).

*Krok pomocniczy.* Z założenia \\(i\Delta_a=k\Delta_b\\) wynika

\\[
\frac{i\Delta_a}{\Delta_c}
=\frac{i\Delta_a(\Delta_a+\Delta_b)}{\Delta_a\Delta_b}
=\frac{i\Delta_a}{\Delta_b}+i
=k+i
=L\in\mathbb{N},
\\]

i symetrycznie \\(k\Delta_b/\Delta_c=L\\). Przesunięcie każdego argumentu
o jego własną liczbę slotów odpowiada więc **tej samej** liczbie \\(L\\) slotów
wyniku.

*Ciąg rekordów i początek logiczny.* W jednym okresie przeplot pobiera \\(i\\)
rekordów z A i \\(k\\) rekordów z B, wypełniając dokładnie \\(L=i+k\\) slotów C.
Przesunięcie A o \\(i\\) i B o \\(k\\) przesuwa zatem próg odwzorowania obu
składowych o dokładnie \\(L\\) slotów wyniku, nie zmieniając ich wzajemnej fazy:
\\(O_{\mathrm{LHS}}=O_{\varphi(A,B)}+L=O_{\mathrm{RHS}}\\). Treść rekordu
o danym indeksie logicznym jest po obu stronach ta sama, bo wybór składowej
zależy wyłącznie od fazy, a ta jest niezmieniona.

*Ogony.* Ponieważ dodanie całkowitego \\(L\\) komutuje z sufitem,
\\(\operatorname{conv}(W_A-i,\Delta_a,\Delta_c)=\operatorname{conv}(W_A,\Delta_a,\Delta_c)-L\\)
i analogicznie dla B. Z \\(\max(0,W-m)\ge W-m\\) i monotoniczności
\\(\operatorname{conv}\\) dostajemy

\\[
\begin{aligned}
W_{\mathrm{LHS}}
&=\max\left(
\operatorname{conv}\bigl(\max(0,W_A-i),\Delta_a,\Delta_c\bigr),
\operatorname{conv}\bigl(\max(0,W_B-k),\Delta_b,\Delta_c\bigr)+H_{a,b}
\right)\\\\
&\ge\max\left(
\operatorname{conv}(W_A,\Delta_a,\Delta_c)-L,
\operatorname{conv}(W_B,\Delta_b,\Delta_c)+H_{a,b}-L
\right)
=W_{\varphi(A,B)}-L,
\end{aligned}
\\]

a ponieważ \\(W_{\mathrm{LHS}}\ge 0\\), zachodzi
\\(W_{\mathrm{LHS}}\ge\max(0,W_{\varphi(A,B)}-L)=W_{\mathrm{RHS}}\\). ∎

> **⚠️ Zakres twierdzenia**
>
> Równość ogonów **nie zachodzi**. Kontrprzykład: \\(\Delta_a=1/10\\),
> \\(\Delta_b=1/5\\), \\(W_A=W_B=0\\), \\(H_{a,b}=2\\), \\(i=2\\), \\(k=1\\),
> \\(L=3\\). Wtedy \\(W_{\mathrm{LHS}}=2\\), a \\(W_{\mathrm{RHS}}=\max(0,2-3)=0\\).
> Strona niesfaktoryzowana czyta składowe **po** ich własnym przesunięciu, więc
> na tę samą treść czeka dłużej; strona sfaktoryzowana czyta ją wprost
> z przeplotu.
>
> Konsekwencja praktyczna: reguła przepisywania
> \\(\varphi(\tau_i(A),\tau_k(B))\to\tau_{i+k}(\varphi(A,B))\\) jest
> **optymalizacją opóźnienia**, a nie przepisaniem neutralnym. Zachowuje całą
> część wartościową obserwacji i nigdy nie emituje rekordu przed określeniem
> jego zależności, ale wynik jest gotowy wcześniej.
>
> Do 2026-08-07 obie strony miały ten sam ogon wyłącznie dlatego, że realizacja
> \\(\tau_m\\) zawyżała swój ogon o \\(\min(W_S,m)\\). Zawyżenie zmierzono
> w kampanii `rdb-experiment/results_20260807_K24p` (6,6% węzłów klasy `>N`)
> i zdjęto, adresując producenta indeksem logicznym. Regresje strzegące tego
> zakresu: `it_r1_identity_nulls`, `it_optimizer_ablation-factor-name-collision-semantic`.

W kompilatorze dodatkowe niezmienniki zachowują nazwy pól publicznych
strumieni, mapy wartości pustych i politykę materializacji.

## Dlaczego to ma znaczenie

Przedstawione twierdzenia nie są formalnością dla samej formalności. Każde z nich pełni konkretną rolę w działającym systemie:

* **Twierdzenie 1 i 2** gwarantują, że pary operacji przeplot/rozplątanie oraz suma/różnica są komplementarne – dane nie giną i nie powielają się w sposób niekontrolowany. To one pozwalają traktować te operacje jak mnożenie/dzielenie oraz dodawanie/odejmowanie w zbiorze regularnych serii czasowych.
* **Twierdzenie 2** w szczególności udowadnia, że całą konstrukcję da się zrealizować wyłącznie na liczbach wymiernych – a więc deterministycznie i dokładnie na komputerze. To jest warunek, bez którego system RetractorDB nie mógłby istnieć.
* **Twierdzenia o własnościach operatorów** (przemienność sumowania, dopasowanie przeplotu, zaburzenie kolejności) dostarczają reguł przepisywania wyrażeń strumieniowych. Optymalizator planów zapytań korzysta z nich, aby przekształcać plany do postaci tańszej w realizacji, nie zmieniając wyniku.

Dział matematyki, w którym osadzone są te równania, to teoria układów pokrywających [\[4\]](../literatura.md#4) w obszarze teorii liczb. Pełny formalizm wraz z kompletem dowodów przedstawiłem w pracy [Deterministyczna metoda przetwarzania ciągów danych](https://www.academia.edu/1840563/Deterministyczna_metoda_przetwarzania_ciagow_danych) [\[3\]](../literatura.md#3).

> **ℹ️ Info**
>
> Numeryczna weryfikacja powyższych równań – prototypy w języku Python operujące na liczbach wymiernych (biblioteka `Fraction`) – znajduje się na stronie [Implementacja modelu](implementacja-programowa.md) oraz w repozytorium [github.com/michalwidera/equations](https://github.com/michalwidera/equations).
