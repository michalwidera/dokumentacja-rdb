# Formalne podstawy i dowody

Rozdział o [algebrze regularnych serii czasowych](algebra-regularnych-serii-czasowych.md) definiuje operatory i opisujące je równania. Ta strona przedstawia ich uzasadnienie: związek z teorią układów pokrywających oraz dowody własności używanych do interpretacji i optymalizacji planów zapytań. Końcowa [część o związku z implementacją](#związek-dowodów-z-implementacją) wyjaśnia, które własności sformalizowano w Lean i jak testy porównują model z funkcjami C++.

> **ℹ️ Info**
>
> Dla implementacji istotny jest wariant wymierny. Twierdzenie Beatty'ego opisuje podział dla parametrów niewymiernych, a uogólnienie Fraenkela dopuszcza również parametry wymierne. Poniższe dowody pokazują, że wybór pozycji próbek przez przeplot i rozplątanie można wyznaczać dokładnie w tej dziedzinie, bez przybliżeń zmiennoprzecinkowych.


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

Twierdzenie [Beatty](../literatura.md#1) gwarantuje podział zbioru dla liczb niewymiernych. Twierdzenie [Fraenkela](../literatura.md#2) jest uogólnieniem, które – co dla nas kluczowe – dopuszcza również liczby wymierne, pod warunkiem spełnienia pięciu postulatów (przytoczonych w [rozdziale wstępnym](./)). Przystępny dowód twierdzenia Fraenkela można odnaleźć w pracy K. O'Bryanta _„Fraenkel's partition and Brown's decomposition"_ [\[23\]](../literatura.md#23).

Cała dalsza część tej strony sprowadza się do jednej myśli: pokazania, że operatory strumieniowe są w istocie maszynami generującymi sekwencje Beatty, które dokonują podziału (pokrycia) zbioru liczb naturalnych.

## Narzędzia: własności podłogi i sufitu

Dowody operują niemal wyłącznie na funkcjach podłogi (⌊x⌋ – część całkowita) i sufitu (⌈x⌉ – najmniejsza liczba całkowita nie mniejsza od x). Przytaczam więc najpierw zestaw tożsamości, które będą wielokrotnie wykorzystywane. Niech x ∈ ℝ, a C oznacza liczbę całkowitą:

\\[
\left\lfloor x\right\rfloor = \left\lceil x\right\rceil \iff x \in \mathbb{Z}
\\]

\\[
\left\lfloor x\right\rfloor + 1 = \left\lceil x\right\rceil \iff x \in \mathbb{R} \setminus \mathbb{Z}
\\]

Druga z tych tożsamości ma bezpośrednie przełożenie na same sekwencje Beatty. Wariant sufitowy sekwencji, B′<sub>α</sub>(n) = ⌈nα⌉, jest bowiem – dla niewymiernego α – wyłącznie przesuniętą o jeden wersją wariantu podłogowego:

\\[
B_{\alpha}^{\prime}(n) = \left\lceil n\alpha \right\rceil = \left\lfloor n\alpha \right\rfloor + 1
\\]

W klasycznym twierdzeniu Beatty'ego α jest niewymierne, więc nα nie jest liczbą całkowitą dla żadnego n > 0. Druga tożsamość zachodzi zatem dla każdego wyrazu: wariant sufitowy podnosi każdy wyraz wariantu podłogowego dokładnie o 1. Dla wymiernego α iloczyn nα bywa liczbą całkowitą i wtedy ⌈nα⌉ = ⌊nα⌋. Zależność trzeba więc rozstrzygać wyraz po wyrazie. Taką analizę przypadków przeprowadza część trzecia dowodu twierdzenia 2 (rozplątanie spełnia postulaty Fraenkela), wykorzystując nwd(a, b).

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

Operatory wprowadzone w języku zapytań mają swoje formalne odpowiedniki. Poniższa tabela wiąże zapis formalny (stosowany w dowodach) z symbolami spotykanymi w [języku zapytań](../konstrukcja-jezyka-zapytan/):

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

Twierdzenie wiąże obie sekwencje wyboru próbek w operacji rozplątania z sekwencjami Beatty'ego spełniającymi postulaty Fraenkela dla parametrów wymiernych. Uzasadnia w ten sposób dokładne odwrócenie przeplotu.

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

W realizacji przyczynowej strumień ma postać \\(\widehat{S}=((s_n,\Delta),W_S)\\), gdzie \\(W_S\\) jest ogonem startowym.

Ogon przeplotu o interwale \\(\Delta_c=\Delta_a\Delta_b/(\Delta_a+\Delta_b)\\) wynika z definicji operatora.

Rekord \\(i\\) strumienia \\(\varphi(A,B)\\) niesie treść rekordu \\(j(i)\\) jednej ze składowych - tej, którą w slocie \\(i\\) wybiera definicja przeplotu. Oznaczmy przez \\(\Delta_{s(i)}\\) i \\(W_{s(i)}\\) interwał oraz ogon wybranej składowej. Rekord \\(j(i)\\) jest określony w chwili \\(\bigl(j(i)+1+W_{s(i)}\bigr)\Delta_{s(i)}\\), a slot \\(i\\) konsumenta kończy się w chwili \\((i+1+W)\Delta_c\\). Warunek przyczynowości dla każdego \\(i\\):

\\[
W\ge
\left\lceil\frac{\bigl(j(i)+1+W_{s(i)}\bigr)\Delta_{s(i)}}{\Delta_c}\right\rceil
-1-i
\\]

Niech \\(\Delta_a/\Delta_b=p/q\\), gdzie \\(p,q\in\mathbb{N}_{>0}\\) i \\(\gcd(p,q)=1\\). Zarówno wybór składowej, jak i reszta wyznaczająca \\(j(i)\\) powtarzają się z okresem \\(p+q\\), więc maksimum prawej strony po **jednym** okresie jest maksimum po wszystkich rekordach:

\\[
W_{\varphi(A,B)}
=\max_{0\le i<p+q}\left(
\left\lceil\frac{\bigl(j(i)+1+W_{s(i)}\bigr)\Delta_{s(i)}}{\Delta_c}\right\rceil
-1-i
\right)
\\]

Wzór jest **dokładny**: nie zawyża ani nie zaniża granicy zdarzeniowej. Okresowość wymagań oznacza, że maksimum po \\([0,\,p+q)\\) jest takie samo jak po każdym pełnym okresie od dowolnego progu, także początku logicznego strumienia.

Dla \\(L=p+q\\) i nieujemnych ogonów \\(W_A,W_B\\) to maksimum ma **postać zamkniętą**:

\\[
W_{\varphi(A,B)}
=\max\left(
\left\lceil\frac{W_A L}{q}\right\rceil,\;
\left\lceil\frac{(1+W_B)L+p-1}{p}\right\rceil-1
\right)
\\]

Aby ją wyprowadzić, rozpatrujemy pozycje rekordów każdej składowej w przeplocie:

\\[
r_A(j)=\left\lceil\frac{(j+1)L}{q}\right\rceil-1,
\qquad
r_B(k)=\left\lfloor\frac{kL}{p}\right\rfloor
\\]

Po podstawieniu \\(r_A(j)\\) do warunku dostępności otrzymujemy różnicę dwóch sufitów. Jej maksimum wynosi \\(\lceil W_A L/q\rceil\\) i jest osiągane przy \\(j=q-1\\), w ostatnim slocie okresu. Dla B wymaganie ma postać \\(\lceil(k+1+W_B)L/p\rceil-1-\lfloor kL/p\rfloor\\). Ponieważ \\(\gcd(L,p)=1\\), reszta \\(kL\bmod p\\) przebiega wszystkie wartości od 0 do \\(p-1\\). Maksimum wypada przy reszcie \\(p-1\\) i daje drugi człon wzoru. Dotyczy to również \\(p=1\\), gdy jedyną resztą jest 0.

Równość z maksimum fazowym formalizuje `exactInterleaveTail_closed` w `InterleaveTailExact.lean`; `exactInterleaveTail_exact` stwierdza, że maksimum jest najmniejszym ogonem spełniającym warunek dostępności od dowolnego progu. `HashStartupLatency()` liczy postać zamkniętą dla każdego okresu, bez jego przeglądania. Dla zerowych ogonów wejść otrzymujemy \\(W_{\varphi(A,B)}=\lceil(L-1)/p\rceil\\).

Przesunięcie \\(\tau_m\\) nie zmienia emitowanego ciągu rekordów, ale zmienia **indeks**, pod którym ten ciąg się pojawia: rekord \\(n\\) niesie treść rekordu \\(n-m\\). Rekordy o indeksie mniejszym od \\(O_S+m\\) nie mają definicji, więc

\\[
O_{\tau_m(S)}=O_S+m,
\qquad
W_{\tau_m(S)}=\max\left(0,\;W_S-m\right)
\\]

Ogon **maleje**: rekord \\(n-m\\) jest starszy od bieżącego, więc dostępny tym bardziej - deficyt slotu wynosi \\(W_S-m\\) i jest stały. Szczegóły i pomiar: [Ogony, początki logiczne i obserwowalność operatorów](ogony-i-obserwowalnosc-operatorow.md).

> **✅ Uwaga**
>
> **Twierdzenie (R1, przemienność przesunięcia z przeplotem).** Jeśli liczby i, k ∈ ℕ wybrano tak, że i·∆<sub>a</sub> = k·∆<sub>b</sub> (oba argumenty przesunięte o ten sam czas), to przeplot strumieni przesuniętych i przeplot strumieni pierwotnych przesunięty o sumę tych liczb mają **ten sam ciąg rekordów, ten sam interwał i ten sam początek logiczny**. Ich ogony spełniają nierówność - strona sfaktoryzowana nigdy nie jest późniejsza.

Formalnie, dla \\(L:=i+k\\):

\\[
\operatorname{Obs}\Bigl(\varphi\bigl(\tau_{i}(A),\tau_{k}(B)\bigr)\Bigr)
=\operatorname{Obs}\Bigl(\tau_{i+k}\bigl(\varphi(A,B)\bigr)\Bigr),
\qquad i\Delta_{a}=k\Delta_{b},\quad i,k\in\mathbb{N}
\\]

\\[
W_{\mathrm{RHS}}=\max\left(0,\;W_{\varphi(A,B)}-L\right)\le W_{\mathrm{LHS}}
\\]

gdzie \\(\operatorname{Obs}\\) jest częścią wartościową obserwacji (interwał, początek logiczny, ciąg rekordów z mapą `NULL`, deskryptor, ślad luk, polityka materializacji) - patrz [Ogony, początki logiczne i obserwowalność operatorów](ogony-i-obserwowalnosc-operatorow.md).

**Dowód.**

*Interwał.* Obie strony powstają z tego samego przeplotu, więc mają \\(\Delta_c=\Delta_a\Delta_b/(\Delta_a+\Delta_b)\\).

*Krok pomocniczy.* Z założenia \\(i\Delta_a=k\Delta_b\\) wynika

\\[
\frac{i\Delta_a}{\Delta_c}
=\frac{i\Delta_a(\Delta_a+\Delta_b)}{\Delta_a\Delta_b}
=\frac{i\Delta_a}{\Delta_b}+i
=k+i
=L\in\mathbb{N},
\\]

i symetrycznie \\(k\Delta_b/\Delta_c=L\\). Przesunięcie każdego argumentu o jego własną liczbę slotów odpowiada więc **tej samej** liczbie \\(L\\) slotów wyniku.

*Ciąg rekordów i początek logiczny.* W jednym okresie przeplot pobiera \\(i\\) rekordów z A i \\(k\\) rekordów z B, wypełniając dokładnie \\(L=i+k\\) slotów C. Przesunięcie A o \\(i\\) i B o \\(k\\) przesuwa zatem próg odwzorowania obu składowych o dokładnie \\(L\\) slotów wyniku, nie zmieniając ich wzajemnej fazy: \\(O_{\mathrm{LHS}}=O_{\varphi(A,B)}+L=O_{\mathrm{RHS}}\\). Treść rekordu o danym indeksie logicznym jest po obu stronach ta sama, bo wybór składowej zależy wyłącznie od fazy, a ta jest niezmieniona.

*Ogony.* Niech \\(s(n)\in\\{A,B\\}\\) oznacza składową wybraną w fazie \\(n\\), a \\(j(n)\\) jej indeks. Oznaczmy przesunięcia przez \\(t_A=i\\) i \\(t_B=k\\). Po przesunięciu ogon składowej wynosi \\(W_s^{\prime}=\max(0,W_s-t_s)\ge W_s-t_s\\). Nie zmieniają się interwały ani wybór składowej i jej indeks w danej fazie przeplotu. Niech \\(R_n\\) będzie wymaganiem dostępności z powyższego wzoru fazowego dla ogonów \\(W_A,W_B\\), a \\(R_n^{\prime}\\) wymaganiem dla \\(W_A^{\prime},W_B^{\prime}\\). Z kroku pomocniczego mamy \\(t_s\Delta_s/\Delta_c=L\in\mathbb{N}\\) dla obu składowych. Monotoniczność sufitu i jego zgodność z przesunięciem o całkowite \\(L\\) dają w każdej fazie:

\\[
\begin{aligned}
R_n^{\prime}
&=\left\lceil
\frac{(j(n)+1+W_{s(n)}^{\prime})\Delta_{s(n)}}{\Delta_c}
\right\rceil-1-n\\\\
&\ge\left\lceil
\frac{(j(n)+1+W_{s(n)}-t_{s(n)})\Delta_{s(n)}}{\Delta_c}
\right\rceil-1-n
=R_n-L.
\end{aligned}
\\]

Maksimum bierzemy po tym samym pełnym okresie \\(p+q\\), ponieważ przesunięcia nie zmieniają stosunku interwałów. Korzystając dodatkowo z nieujemności ogonów, otrzymujemy:

\\[
W_{\mathrm{LHS}}
\ge\max\left(0,\max_{0\le n<p+q}R_n-L\right)
=\max\left(0,W_{\varphi(A,B)}-L\right)
=W_{\mathrm{RHS}}.
\\]

Postać zamknięta jest równa maksimum fazowemu dla każdego okresu, więc powyższy argument obejmuje wszystkie stosunki interwałów. ∎

> **⚠️ Zakres twierdzenia**
>
> Równość ogonów **nie zachodzi**. Kontrprzykład: \\(\Delta_a=1/10\\), \\(\Delta_b=1/5\\), \\(W_A=W_B=0\\), \\(W_{\varphi(A,B)}=2\\), \\(i=2\\), \\(k=1\\), \\(L=3\\). Wtedy \\(W_{\mathrm{LHS}}=2\\), a \\(W_{\mathrm{RHS}}=\max(0,2-3)=0\\). Strona niesfaktoryzowana czyta składowe **po** ich własnym przesunięciu, więc na tę samą treść czeka dłużej; strona sfaktoryzowana czyta ją wprost z przeplotu.
>
> Konsekwencja praktyczna: reguła przepisywania \\(\varphi(\tau_i(A),\tau_k(B))\to\tau_{i+k}(\varphi(A,B))\\) jest **optymalizacją opóźnienia**, a nie przepisaniem neutralnym. Zachowuje całą część wartościową obserwacji i nigdy nie emituje rekordu przed określeniem jego zależności, ale wynik jest gotowy wcześniej.
>
> Regresje strzegące tego zakresu: `it_r1_identity_nulls`, `it_optimizer_ablation-factor-name-collision-semantic`.

W kompilatorze dodatkowe niezmienniki zachowują nazwy pól publicznych strumieni, mapy wartości pustych i politykę materializacji.

## Dlaczego to ma znaczenie

Przedstawione własności określają granice poprawnych przekształceń strumieni:

* **Twierdzenia 1 i 2** uzasadniają pokrycie pozycji próbek przez przeplot oraz odzyskanie obu składowych przez rozplątanie, z zachowaniem kolejności każdej z nich.
* **Wariant wymierny** pozwala obliczać odwzorowania indeksów dokładnie. Implementacja musi dodatkowo kontrolować zakres reprezentacji liczbowej.
* **Własności operatorów** określają dozwolone przepisania i ograniczenia interpretacji. W szczególności R1 zachowuje część wartościową obserwacji, ale może skrócić ogon startowy, a przeplot nie zachowuje ogólnego porządku zdarzeń między składowymi.

Dział matematyki, w którym osadzone są te równania, to teoria układów pokrywających [\[4\]](../literatura.md#4) w obszarze teorii liczb. Historyczne wyprowadzenie metody przedstawia praca [Deterministyczna metoda przetwarzania ciągów danych](https://www.academia.edu/1840563/Deterministyczna_metoda_przetwarzania_ciagow_danych) [\[3\]](../literatura.md#3).

> **ℹ️ Info**
>
> Numeryczna weryfikacja powyższych równań – prototypy w języku Python operujące na liczbach wymiernych (biblioteka `Fraction`) – znajduje się na stronie [Implementacja modelu](implementacja-programowa.md) oraz w repozytorium [github.com/michalwidera/equations](https://github.com/michalwidera/equations).

## Związek dowodów z implementacją

Dowody matematyczne dotyczą modelu operatorów. Ich formalizacja w Lean oraz testy silnika tworzą kolejne poziomy weryfikacji o różnym zakresie. Źródła znajdują się w katalogu [`math_proofs`](https://github.com/michalwidera/retractordb/tree/master/math_proofs) repozytorium kodu; [instrukcja projektu Lean](https://github.com/michalwidera/retractordb/blob/master/math_proofs/README.md) opisuje przygotowanie narzędzi, sprawdzanie dowodów i generowanie dokumentów Verso.

| Własność | Formalizacja w `math_proofs/Profs/` |
| --- | --- |
| Pokrycie sekwencyjne przez przeplot | [InterleaveCovering.lean](https://github.com/michalwidera/retractordb/blob/master/math_proofs/Profs/InterleaveCovering.lean) |
| Podział pozycji i odwzorowania rozplątania | [BeattyPartition.lean](https://github.com/michalwidera/retractordb/blob/master/math_proofs/Profs/BeattyPartition.lean), [Deinterleave.lean](https://github.com/michalwidera/retractordb/blob/master/math_proofs/Profs/Deinterleave.lean) |
| Dokładna odwracalność | [ExactInvertibility.lean](https://github.com/michalwidera/retractordb/blob/master/math_proofs/Profs/ExactInvertibility.lean) |
| Kontrprzykład dla porządku zdarzeń i przemienność sumy | [EventOrder.lean](https://github.com/michalwidera/retractordb/blob/master/math_proofs/Profs/EventOrder.lean), [SumCommutativity.lean](https://github.com/michalwidera/retractordb/blob/master/math_proofs/Profs/SumCommutativity.lean) |
| Dopasowane przesunięcia R1 i realizacja przyczynowa | [ShiftMatching.lean](https://github.com/michalwidera/retractordb/blob/master/math_proofs/Profs/ShiftMatching.lean), [CausalShift.lean](https://github.com/michalwidera/retractordb/blob/master/math_proofs/Profs/CausalShift.lean) |
| Okresowość, minimalność i postać zamknięta ogona przeplotu | [InterleaveTailExact.lean](https://github.com/michalwidera/retractordb/blob/master/math_proofs/Profs/InterleaveTailExact.lean) |

Powiązanie z kodem C++ przebiega w czterech krokach:

1. **Sprawdzenie modelu w Lean.** Pliki `Profs/` zawierają definicje i dowody sprawdzane przez jądro Lean. Formalizacja podziału dodatnich pozycji korzysta z uogólnionego twierdzenia Rayleigha w Mathlib. Nie jest formalizacją pełnego twierdzenia Fraenkela. Po przygotowaniu środowiska polecenie `lake build Profs`, wykonane w katalogu `math_proofs`, sprawdza projekt dowodów.
2. **Wygenerowanie wyroczni.** [`OracleMain.lean`](https://github.com/michalwidera/retractordb/blob/master/math_proofs/OracleMain.lean) oblicza tablice z definicji modelu. Skrypt `gen-oracle.sh` zapisuje je do `test/UnitTest/proofOracle.hpp` wraz ze skrótami SHA-256 źródeł dowodów i plików określających wersje narzędzi.
3. **Porównanie z implementacją.** Test `ut_proofOracle` porównuje funkcje z `SOperations.hpp` z wygenerowanymi tablicami i sprawdza konsekwencje twierdzeń. Dla ogona przeplotu `ProofOracle.exactInterleaveTail_table` porównuje wynik C++ z tablicą Lean, a `ProofOracle.exactInterleaveTail_closed` sprawdza tę samą tablicę względem obu członów postaci zamkniętej dla parametrów względnie pierwszych. Asercje w C++ sprawdzają wybrane przypadki i zakresy parametrów; nie stanowią uniwersalnego dowodu zgodności całej implementacji z Lean.
4. **Kontrola aktualności powiązań.** Test `proof_drift` sprawdza skróty wejść wyroczni i [`test/proof_manifest.tsv`](https://github.com/michalwidera/retractordb/blob/master/test/proof_manifest.tsv). Manifest przypisuje twierdzenia do testów albo jawnie określa brak pokrycia lub zakres poza odpowiednikiem silnika. Zmiana źródeł dowodów lub wersji narzędzi wymaga ponownego wygenerowania wyroczni; sama kontrola skrótów nie zastępuje sprawdzenia dowodów w Lean.

Formalizacja obejmuje indeksy, wartości, interwały, dopasowane przesunięcia, początki logiczne oraz minimalność i postać zamkniętą dokładnego ogona przeplotu. Rachunek modelu używa liczb o nieograniczonym zakresie; kontrola reprezentacji `int64` i odmowa planu przy wyniku spoza `int` należą do implementacji C++. Zgodność deskryptorów, map `NULL`, luk, materializacji i pozostałych ścieżek wykonania C++ wymaga oddzielnych kontroli jednostkowych i integracyjnych. Ich rolę oraz odróżnienie opisu pokrycia od wyniku uruchomienia przedstawiają [Testy integracyjne](../zalaczniki/testy-integracyjne.md).
