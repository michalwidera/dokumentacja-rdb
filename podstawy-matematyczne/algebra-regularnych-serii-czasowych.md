---
description: >-
  Przypomnę że w typowym systemie relacyjnym też używamy algebry zbiorów, tylko
  nie musimy się tym przejmować.
icon: square-root
---

# Algebra regularnych serii czasowych

Algebra – rozumiana jako konstrukcja w postaci zdefiniowanego zbioru i zdefiniowanych operacji na nim, stanowi podstawę dla opracowanego deklaratywnego język zapytań. W dalszej części pracy odnosząc się do Algebry (bez dodatkowego przymiotnika) będę ją rozumiał jako Algebrę regularnych serii czasowych. Jeśli będę chciał odwołać się do Algebry Relacji – jasno wyspecyfikuję przymiotnik.

Zaproponowałem \[[3](../literatura.md#3)] następującą definicje regularnej serii czasowej (tzw. Modelu danych) oraz następujące operacje i definicje.

{% hint style="success" %}
Przez strumień danych rozumiemy uporządkowaną parę S := (s<sub>n</sub>,∆) – gdzie pierwszy element to uporządkowania seria danych a drugi, oznaczony symbolem delty to regularny odstęp czasu pomiędzy kolejnymi elementami serii danych.
{% endhint %}

Tak zdefiniowaną serię danych w systemie określam jako strumień danych. Taki regularnie przepływający przez system zestaw danych, zazwyczaj opisany schematem danych zawiera pola różnych typów. Każdy odczyt występuje w równym odstępie czasu pomiędzy kolejnymi pomiarami. Taka konstrukcja bardziej przypomina sygnał cyfrowy niż nieregularny strumień danych – jednak oznaczenie jej jako strumień w dalszej części prac badawczych okaże się uzasadnione.

{% hint style="info" %}
Uwaga:\
Pojęcie strumień i Seria czasowa w tej pracy używane są zamiennie i oznaczają to samo.\
Formalnie w literaturze naukowej strumień oznaczany jest jako zbiór par (a,t) – gdzie a oznacza krotkę, a czast oznacza jej moment zarejestrowania lub wystąpienia.\
W strumieniu dopuszczalne są krotki, których czas t pokrywa się dla różnych krotek. W przypadku serii czasowej rozróżniamy dwa typy serii – regularne i nieregularne.\
\- W przypadku serii nieregularnych – seria to sekwencja uporządkowanych krotek w czasie – {a<sub>t</sub>,t<sub>n</sub>}, gdzie czas t<sub>n</sub> jest unikalny w zbiorze dla każdej krotki.\
\- Natomiast seria regularnej serii czasowej może zostać opisana sekwencją krotek i regularnym odstępem czasu pomiędzy ich występowaniem – ({a<sub>t</sub>},D) – i to ta ostatnia definicja jest bazą dalszych operacji w opracowanym systemie.
{% endhint %}

Operacje jakie możemy na takim zbiorze danych wykonać zdefiniowałem następująco:

* przeplot i rozplątanie
* suma i różnica
* przesunięcie sekwencji
* agregacja i serializacja

W operacji przeplotu biorą udział dwa różne strumienie danych.

Definiujemy ją następująco:

$$
c_{n}=\left\{ 
\begin{array}{cc}
b_{n-\left\lfloor n z \right\rfloor } & \left\lfloor n z
\right\rfloor =\left\lfloor \left( n+1\right) z \right\rfloor \\ 
a_{\left\lfloor n z \right\rfloor } & \left\lfloor n z \right\rfloor
\neq \left\lfloor \left( n+1\right) z \right\rfloor%
\end{array}%
\right. , z =\frac{\Delta _{b}}{\Delta _{a}+\Delta _{b}},\Delta _{c}=%
\frac{\Delta _{a}\Delta _{b}}{\Delta _{a}+\Delta _{b}}
$$

Argumentem operacji splątania (przeplotu) są dwa strumienie danych A i B, każdy z własną szybkością napływu danych. Wynikiem jest strumień wynikowy C – z nową różną od dwóch poprzednich szybkością napływu wyznaczoną wzorem powyżej.

Operację będziemy oznaczać symbolem #.

Operację rozplątania definiujemy poprzez dwie operacje.

1\. Rozplątanie lewostronne jako strumień A w postaci:

$$
a_{n} = c_{n+ \left\lceil  \frac{(n+1)\Delta _{a}}{\Delta _{b}} \right\rceil },\ \Delta _{a}=\frac{\Delta _{c}\Delta _{b}}{\left\vert \Delta _{c}-\Delta _{b}\right\vert }
$$

2. Rozplątanie prawostronne jako strumień B w postaci:

$$
b_{n} = c_{n+\left\lfloor \frac{n\Delta _{b}}{\Delta _{a}}\right\rfloor},\ \Delta _{b}=\frac{\Delta _{c}\Delta _{a}}{\left\vert \Delta _{c}-\Delta_{a}\right\vert }
$$

Operacje rozplątania 1 i 2 będziemy oznaczać symbolami & i %.

Argumentem operacji rozplątania jest splątany strumień danych oraz wymierna liczba określająca szybkość napływu odplątywanego strumienia danych. W wyniku operacji otrzymujemy strumień danych z wyznaczoną szybkością wzorem powyżej.

Operacje splątania i rozplątania są komplementarne. Oznacza to że przypominają operacje mnożenia i dzielenia w zbiorze liczb naturalnych. W wyniku mnożenia otrzymujemy pewien wynik natomiast w wyniku dzielenia – czasem dochodzi reszta, istotne jest również to co przez co dzielimy i w jakiej kolejności.

Operacje sumy zdefiniowałem następująco:

$$
c_{n}=\left\{ 
\begin{array}{cc}
a_{n}|b_{ \left\lfloor  \frac{n\Delta _{a}}{\Delta _{b}} \right\rfloor }  & \Delta
_{c}=\Delta _{a} \\ 
a_{ \left\lfloor  \frac {n\Delta _{b}}{\Delta _{a}} \right\rfloor }|b_{n} & \Delta
_{c}=\Delta _{b}
\end{array}
\right. ,\Delta _{c}=\min \left( \Delta _{a},\Delta _{b}\right)
$$

Natomiast różnicę opisuje wzór:

$$
a_{n}=\left\{ 
\begin{array}{cc}
c_{n} & \Delta _{b}\geqslant \Delta _{a} \\ 
c_{\left\lceil \frac{n\Delta _{a}}{\Delta _{b}}\right\rceil } & \Delta
_{b}<\Delta _{a}
\end{array}
\right.
$$

Te operacje oznaczać będziemy znakami + oraz -.

Operacja przesunięcia sekwencji zawiera argument w postaci opóźnienia dostępu do danych o daną ilość odstępów czasu pomiędzy kolejnymi elementami. I tak np. dane napływające co sekundę ze strumienia źródłowego po wykonaniu operacji przesunięcia o 3 – pojawią się jako wynik opóźnione o 3 sekundy.

Operację przesunięcia oznaczać będę za pomocą >.

Ostatnią operacją w ramach zdefiniowanej algebry jest operacja agregacji i serializacji – w skrócie Agse. O ile wydaje się że to dwie oddzielne operacje, zdefiniowałem dwuargumentowy operator implementujący logikę ruchomego okna danych. Pierwszym argumentem jest skok okna, drugim jest jego szerokość. Skok jest liczbą naturalną o ile ruchome okno danych należy przesunąć nad strumieniem. Zakładamy że źródłowy strumień danych rozbity zostaje względem schematu danych, modyfikując jego szybkość napływu. Szerokość okna jest liczbą całkowitą, różną od zera. Wartości ujemne szerokości przenoszą kolejność tworzonych elementów w odbiciu lustrzanym. Wartości dodatnie – zachowują sekwencyjny charakter tworzonych ruchomych okien danych.

Operację Agse oznaczać będę znakiem @.

Podsumowując, algebra będąca podstawą dla deklaratywnego języka zapytań prezentuje się następująco:

$$
A_{rql}::=((s_n,\Delta_s), (\#,\&,\%,+,-,>,@))
$$

Gdzie pierwszy element pary definiującej algebrę to model danych (s\_n — seria danych, ∆\_s — jej regularny odstęp czasu) a drugi to zdefiniowane formalnie na tym modelu danych operacje.
