# Formalne podstawy i dowody

W rozdziale o [algebrze regularnych serii czasowych](algebra-regularnych-serii-czasowych.md) przedstawiłem zbiór operatorów i opisujące je równania. Świadomie pominąłem tam formalne dowody – chciałem najpierw pokazać _co_ system robi, zanim wyjaśnię _dlaczego_ wolno mu to robić. Ta strona uzupełnia tę lukę. Zebrałem tu formalny szkielet algebry: powiązanie operatorów strumieniowych z teorią układów pokrywających oraz dowody twierdzeń, na których opiera się poprawność i optymalizacja planów zapytań.

> **ℹ️ Info**
>
> Cała poniższa konstrukcja trzyma się w jednej dziedzinie – liczb wymiernych. To nie jest ozdobnik. To jest cały sens. Twierdzenie Beatty potrzebuje liczb niewymiernych, których w komputerze nie ma. Twierdzenie Fraenkela pozwala zejść do liczb wymiernych. Dowody na tej stronie pokazują, że operacje przeplotu i rozplątania są szczególnym przypadkiem sekwencji Beatty spełniającym postulaty Fraenkela – a więc są realizowalne wyłącznie na liczbach wymiernych.


## Układy pokrywające jako fundament

Literatura dotycząca układów pokrywających (ang. _Covering Systems_) [\[4\]](../literatura.md#4) związana jest z kombinatoryką i kryptoanalizą w obszarze teorii liczb. Rozważanym problemem jest sposób wyznaczania podziału zbioru dodatnich liczb naturalnych. Mówimy, że dwie sekwencje dokonują podziału zbioru dodatnich liczb naturalnych, jeśli zbiory powstałe z elementów tych sekwencji po operacji przecięcia tworzą zbiór pusty, a ich suma tworzy zbiór dodatnich liczb naturalnych.

Podstawą rozważań jest sekwencja nazywana sekwencją Beatty. W postaci ogólnej zapisujemy ją w wariancie z funkcją podłogi:

\\[
\mathcal{B}(\alpha ,\alpha ^{\prime }) := \left( \left\lfloor \frac{n-\alpha ^{\prime }}{\alpha }\right\rfloor \right) _{n=1}^{\infty }
\\]

lub w wariancie z funkcją sufitu:

\\[
\mathcal{B}^{(c)}(\alpha ,\alpha ^{\prime }) := \left( \left\lceil \frac{n-\alpha ^{\prime }}{\alpha }\right\rceil \right) _{n=1}^{\infty }
\\]

Parametry tej sekwencji mają czytelną interpretację geometryczną:

* α oznacza gęstość sekwencji,
* 1/α oznacza nachylenie,
* α′ oznacza przesunięcie,
* −α′/α oznacza y-przechwycenie (punkt przecięcia z osią rzędnych).

Twierdzenie [Beatty](../literatura.md#1) gwarantuje podział zbioru dla liczb niewymiernych. Twierdzenie [Fraenkela](../literatura.md#2) jest uogólnieniem, które – co dla nas kluczowe – dopuszcza również liczby wymierne, pod warunkiem spełnienia pięciu postulatów (przytoczonych w [rozdziale wstępnym](README.md)). Przystępny dowód twierdzenia Fraenkela można odnaleźć w pracy K. O'Bryanta _„Fraenkel's partition and Brown's decomposition"_.

Cała dalsza część tej strony sprowadza się do jednej myśli: pokazania, że operatory strumieniowe są w istocie maszynami generującymi sekwencje Beatty, które dokonują podziału (pokrycia) zbioru liczb naturalnych.

## Narzędzia: własności podłogi i sufitu

Dowody operują niemal wyłącznie na funkcjach podłogi (⌊x⌋ – część całkowita) i sufitu (⌈x⌉ – najmniejsza liczba całkowita nie mniejsza od x). Przytaczam więc najpierw zestaw tożsamości, które będą wielokrotnie wykorzystywane. Niech x ∈ ℝ, a C oznacza liczbę całkowitą:

\\[
\left\lfloor x\right\rfloor = \left\lceil x\right\rceil \iff x \in \mathbb{N}
\\]

\\[
\left\lfloor x\right\rfloor + 1 = \left\lceil x\right\rceil \iff x \in \mathbb{R} - \mathbb{N}
\\]

\\[
\left\lfloor x + C\right\rfloor = \left\lfloor x\right\rfloor + C \iff C \in \mathbb{N}
\\]

Dodatkowo, w analizie residuum sekwencji rozplątania wykorzystamy zależności wiążące największy wspólny dzielnik (nwd) z dziedziną ilorazu a/b:

\\[
\operatorname{nwd}(a,b) = b \iff \frac{a}{b} = c \in \mathbb{N}
\\]

\\[
1 \leq \operatorname{nwd}(a,b) \leq a \iff 0 < \frac{a}{b} < 1
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
> **Twierdzenie.** Operacja splątania (przeplotu) zapewnia sekwencyjne pokrycie obu zbiorów zawierających elementy strumieni danych będących jej argumentami.


**Dowód.** Dowód rozpoczynamy od analizy pierwszego warunku (warunku równości) w równaniu przeplotu. Oznaczmy ten warunek jako (∗):

\\[
(\ast):\quad \left\lfloor n z \right\rfloor = \left\lfloor \left( n+1\right) z \right\rfloor
\\]

Dla każdego n spełniającego warunek (∗) kolejne wartości wyrażenia n − ⌊nz⌋ tworzą drugi, skojarzony ciąg liczb naturalnych, wybierający kolejne elementy z ciągu b. Oznacza to, że dla każdego n spełniającego (∗) wyrażenie x = n − ⌊nz⌋ podlega zależności xₙ = xₙ₊₁ − 1. Formalnie:

\\[
n - \left\lfloor n z \right\rfloor = (n + 1) - \left\lfloor (n + 1) z \right\rfloor - 1
\\]

Podstawiając warunek (∗) do prawej strony otrzymujemy:

\\[
n - \left\lfloor (n + 1) z \right\rfloor = (n + 1) - \left\lfloor (n + 1) z \right\rfloor - 1
\\]

Po prostym uproszczeniu algebraicznym dochodzimy do tożsamości n = (n + 1) − 1, która jest prawdziwa. Tym samym indeksy wybierające elementy ze strumienia b następują po sobie kolejno, bez przerw i powtórzeń. Drugą część dowodu, opartą na warunku nierówności (wybór elementów ze strumienia a), prowadzi się analogicznie. ∎

## Twierdzenie 2: rozplątanie spełnia postulaty Fraenkela

To jest centralne twierdzenie tej strony. Dowodzi, że obie sekwencje opisujące operację rozplątania są szczególnym przypadkiem sekwencji Beatty spełniającym postulaty twierdzenia Fraenkela dla liczb wymiernych. Bez tego twierdzenia cały system pozostaje jedynie obietnicą.

> **✅ Uwaga**
>
> **Twierdzenie.** Operacja rozplątania spełnia postulaty twierdzenia Fraenkela.


**Dowód – część pierwsza (sprowadzenie do postaci Beatty).** Poszukujemy sposobu przedstawienia sekwencji wyboru kolejnych krotek w operacji rozplątania jako sekwencji Beatty. Sekwencja opisująca wybór krotek ma postać:

\\[
\left( n + \left\lfloor \frac{nb}{a} \right\rfloor \right) _{n=1}^{\infty }
\\]

Dla n ∈ ℕ, na mocy własności ⌊x + C⌋ = ⌊x⌋ + C, powyższe równanie można przyrównać do ogólnej postaci sekwencji Beatty:

\\[
\left( \left\lfloor \frac{n-\alpha ^{\prime }}{\alpha }\right\rfloor \right) _{n=1}^{\infty } = \left( \left\lfloor n + \frac{nb}{a} \right\rfloor \right) _{n=1}^{\infty }
\\]

Upraszczając lewą stronę i grupując prawą:

\\[
\left( \left\lfloor n\alpha ^{-1} - \frac{\alpha ^{\prime }}{\alpha } \right\rfloor \right) _{n=1}^{\infty } = \left( \left\lfloor n\frac{a + b}{a} \right\rfloor \right) _{n=1}^{\infty }
\\]

Symbol −α′/α oznacza y-przechwycenie. Jeśli przesunięcie sekwencji α′ = 0, to α = a/(a+b), a sekwencja przyjmuje postać:

\\[
\mathcal{B}\\!\left( \frac{a}{a + b}, 0 \right) := \left( \left\lfloor n\frac{a + b}{a} \right\rfloor \right) _{n=1}^{\infty }
\\]

W ten sposób, poprzez kilka prostych przekształceń algebraicznych, otrzymaliśmy postać sekwencji Beatty z sekwencji opisującej wybór kolejnych krotek w operacji rozplątania.

**Dowód – część druga (weryfikacja pięciu postulatów i wyznaczenie residuum).** Sprawdzamy kolejno postulaty twierdzenia Fraenkela dla wyznaczonej sekwencji:

1. Wartość α = a/(a+b) dla a, b > 0 jest większa od zera i mniejsza od jedności.
2. Warunek α + β = 1 jest spełniony dla β = b/(a+b).
3. Dla α′ = 0 postulat jest równoważny postulatowi 1.
4. Rozwiązań poszukujemy w zbiorze liczb wymiernych (przypadek α wymiernego).
5. Jeśli qα ∈ ℕ oraz q ∈ ℕ i zachodzi 1/q ≤ α + α′, to – skoro α′ = 0 – warunek ten jest prawdziwy dla q ≤ (a+b)/nwd(a,b). Wynika stąd, że ⌈((a+b)/nwd(a,b)) · β′⌉ = 1, czyli β′ = nwd(a,b)/(a+b).

Postać ciągu residuum (ciągu dopełniającego) dla sekwencji 𝓑(a/(a+b), 0), spełniająca postulaty twierdzenia Fraenkela, przedstawia się więc następująco:

\\[
\mathcal{B}\\!\left( \frac{b}{a + b}, \frac{\operatorname{nwd}(a, b)}{a + b} \right)
\\]

Przyjmujemy, że podział zbioru liczb naturalnych następuje w oparciu o tę sekwencję:

\\[
\mathcal{B}\\!\left( \frac{b}{a + b}, \frac{\operatorname{nwd}(a, b)}{a + b} \right) = \left( \left\lfloor \frac{(n + 1) - \frac{\operatorname{nwd}(a,b)}{a+b}}{\frac{b}{a+b}} \right\rfloor \right) _{n=1}^{\infty }
\\]

Po opuszczeniu nawiasów opisujących sekwencję i wykonaniu kilku prostych przekształceń można wykazać, że:

\\[
\left\lfloor \frac{(n + 1) - \frac{\operatorname{nwd}(a,b)}{a+b}}{\frac{b}{a+b}} \right\rfloor := \left\lfloor n\frac{a}{b} + n + \frac{a}{b} + 1 - \frac{\operatorname{nwd}(a, b)}{b} \right\rfloor
\\]

Poszukiwane równanie opisujące proces tworzenia sekwencji wyboru krotek przedstawia się następująco:

\\[
\left\lfloor n\frac{a}{b} + n + \frac{a}{b} + 1 - \frac{\operatorname{nwd}(a, b)}{b} \right\rfloor = n + \left\lceil \frac{(n + 1)a}{b} \right\rceil
\\]

Stąd, po wydzieleniu części całkowitej, otrzymujemy:

\\[
\left\lfloor \frac{(n + 1)a}{b} - \frac{\operatorname{nwd}(a, b)}{b} \right\rfloor + 1 = \left\lceil \frac{(n + 1)a}{b} \right\rceil
\\]

Podstawiając za n + 1 liczbę naturalną n, otrzymujemy równość, którą należy udowodnić:

\\[
\left\lfloor n\frac{a}{b} - \frac{\operatorname{nwd}(a, b)}{b} \right\rfloor + 1 = \left\lceil n\frac{a}{b} \right\rceil
\\]

**Dowód – część trzecia (analiza przypadków).** Korzystając z własności współczynnika nwd(a, b), rozważamy dwa rozłączne przypadki pokrywające całą dziedzinę.

_Przypadek 1: nwd(a, b) = b, czyli a/b = c ∈ ℕ._ Dowodzone równanie przyjmuje postać:

\\[
\left\lfloor \frac{(n + 1)a}{b} - \frac{b}{b} \right\rfloor + 1 = \left\lceil \frac{(n + 1)a}{b} \right\rceil
\\]

Uwzględniając tożsamości ⌊x⌋ = ⌈x⌉ ⟺ x ∈ ℕ oraz ⌊x + C⌋ = ⌊x⌋ + C, a także dziedzinę tego przypadku, stwierdzamy, że obie sekwencje tworzą te same elementy.

_Przypadek 2: 1 ≤ nwd(a, b) ≤ a, czyli 0 < a/b < 1._ Załóżmy, że istnieją takie dwie liczby a i b, dla których dowodzone równanie nie jest prawdziwe, tzn. dla wartości n·a/b − nwd(a,b)/b oraz n·a/b należących do ℕ nie zachodzi:

\\[
\left\lfloor n\frac{a}{b} - \frac{\operatorname{nwd}(a, b)}{b} + 1 \right\rfloor \neq \left\lceil n\frac{a}{b} \right\rceil
\\]

Korzystając z własności podłogi i sufitu, poszukujemy takich a i b, że:

\\[
n\frac{a}{b} - \frac{\operatorname{nwd}(a, b)}{b} + 1 \neq n\frac{a}{b}
\\]

Równanie to jest spełnione jedynie dla nwd(a, b) = b, a w rozważanej dziedzinie 1 ≤ nwd(a, b) ≤ a nie ma ono rozwiązań. Nie istnieją zatem takie a i b należące do tej dziedziny, które przeczyłyby dowodzonemu równaniu.

Rozpatrzmy jeszcze drugą własność (⌊x⌋ + 1 = ⌈x⌉ ⟺ x ∈ ℝ − ℕ). Załóżmy, że istnieją dwie liczby a i b, dla których równanie nie jest spełnione, czyli dla n·a/b − nwd(a,b)/b oraz n·a/b należących do ℝ∖ℕ powinna zawsze zachodzić zależność:

\\[
n\frac{a}{b} - \frac{\operatorname{nwd}(a, b)}{b} \neq n\frac{a}{b}
\\]

Nie istnieją jednak dwie takie liczby, dla których nwd(a, b) = 0. Czyli dla a/b ∈ ℝ − ℕ równanie to jest zawsze prawdziwe.

Tak więc oba równania opisujące operację rozplątania są przypadkiem sekwencji Beatty spełniającym postulaty twierdzenia Fraenkela dla liczb wymiernych. ∎

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


**Dowód.** Załóżmy, że C = Σ(A, B) oraz D = Σ(S, A). Korzystając ze wzoru na sumę strumieni danych, zapisujemy obie zależności i pomijamy kolejność atrybutów wynikającą z operacji połączenia krotek. Zmieniając kolejność warunków w definicji D oraz podstawiając za symbol S symbol B, otrzymujemy wzór tożsamy ze wzorem na C. Przypadek równych wartości ∆ obu strumieni jest trywialny i został pominięty. Dowodzi to przemienności operacji sumowania. ∎

### Metoda dopasowania przeplotu

Operacja przeplotu nie jest przemienna (co pokazano w [rozdziale o algebrze](algebra-regularnych-serii-czasowych.md)). Istnieje jednak algebraiczna metoda umożliwiająca zmianę kolejności jej argumentów przy określonych założeniach – co jest cenne w optymalizacji planów zapytań.

> **✅ Uwaga**
>
> **Twierdzenie.** Jeśli wybierzemy dwie liczby naturalne i, k, których stosunek jest równy stosunkowi wartości ∆ strumieni łączonych przeplotem, to przeplot strumieni przesuniętych względem tych wartości tworzy strumień równy strumieniowi powstałemu przez przeplot z zamienioną kolejnością argumentów i przesunięciem o sumę tych liczb.


Formalnie:

\\[
\varphi \left( \tau _{i}(A), \tau _{k}(B) \right) = \tau _{i+k}\left( \varphi (B, A) \right), \quad \frac{i}{k} = \frac{\Delta _{a}}{\Delta _{b}}, \quad i, k \in \mathbb{N}
\\]

**Dowód.** Analizując lewą stronę równania i korzystając z definicji przeplotu, otrzymujemy:

\\[
\varphi \left( \tau_{i}(A), \tau_{k}(B) \right):\quad c_{n}= \left\\{ \begin{array}{cc} b_{(n-\left\lfloor n z \right\rfloor)+i } & \left\lfloor n z \right\rfloor = \left\lfloor \left( n+1\right) z \right\rfloor \\\\ a_{\left\lfloor n z \right\rfloor +k} & \left\lfloor n z \right\rfloor \neq \left\lfloor \left( n+1\right) z \right\rfloor \end{array} \right.
\\]

Analizując prawą stronę równania, otrzymujemy:

\\[
\tau_{i+k}\left( \varphi (B, A) \right):\quad c_{n}= \left\\{ \begin{array}{cc} a_{\left\lfloor (n+i+k) z \right\rfloor } & \left\lfloor n z \right\rfloor = \left\lfloor \left( n+1\right) z \right\rfloor \\\\ b_{n+i+k-\left\lfloor (n+i+k) z \right\rfloor} & \left\lfloor n z \right\rfloor \neq \left\lfloor \left( n+1\right) z \right\rfloor \end{array} \right.
\\]

Porównując warunki, dla których oba równania wybierają próbki ze strumienia B, oraz zakładając poprawność tezy, stwierdzamy, że −⌊nz⌋ = k − ⌊(n+i+k)z⌋. Jednocześnie, z założenia o stosunku liczb:

\\[
i + k = \frac{\Delta _{a}}{\Delta _{b}}k + k = k\left( \frac{\Delta _{a}}{\Delta _{b}} + 1 \right) = \frac{k}{z}
\\]

Łącząc obie zależności, dochodzimy do równania:

\\[
-\left\lfloor n z \right\rfloor = k - \left\lfloor k + n z \right\rfloor
\\]

Ponieważ z założenia k ∈ ℕ, na mocy własności ⌊x + C⌋ = ⌊x⌋ + C powyższe równanie jest spełnione. Druga część dowodu, prowadzona w oparciu o warunek nierówności, jest analogiczna. ∎

## Dlaczego to ma znaczenie

Przedstawione twierdzenia nie są formalnością dla samej formalności. Każde z nich pełni konkretną rolę w działającym systemie:

* **Twierdzenie 1 i 2** gwarantują, że pary operacji przeplot/rozplątanie oraz suma/różnica są komplementarne – dane nie giną i nie powielają się w sposób niekontrolowany. To one pozwalają traktować te operacje jak mnożenie/dzielenie oraz dodawanie/odejmowanie w zbiorze regularnych serii czasowych.
* **Twierdzenie 2** w szczególności udowadnia, że całą konstrukcję da się zrealizować wyłącznie na liczbach wymiernych – a więc deterministycznie i dokładnie na komputerze. To jest warunek, bez którego system RetractorDB nie mógłby istnieć.
* **Twierdzenia o własnościach operatorów** (przemienność sumowania, dopasowanie przeplotu, zaburzenie kolejności) dostarczają reguł przepisywania wyrażeń strumieniowych. Optymalizator planów zapytań korzysta z nich, aby przekształcać plany do postaci tańszej w realizacji, nie zmieniając wyniku.

Dział matematyki, w którym osadzone są te równania, to teoria układów pokrywających [\[4\]](../literatura.md#4) w obszarze teorii liczb. Pełny formalizm wraz z kompletem dowodów przedstawiłem w pracy [Deterministyczna metoda przetwarzania ciągów danych](https://www.academia.edu/1840563/Deterministyczna_metoda_przetwarzania_ciagow_danych) [\[3\]](../literatura.md#3).

> **ℹ️ Info**
>
> Numeryczna weryfikacja powyższych równań – prototypy w języku Python operujące na liczbach wymiernych (biblioteka `Fraction`) – znajduje się na stronie [Implementacja modelu](implementacja-programowa.md) oraz w repozytorium [github.com/michalwidera/equations](https://github.com/michalwidera/equations).

