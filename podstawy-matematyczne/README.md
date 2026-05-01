---
description: >-
  "Każde równanie umieszczone w pracy zmniejsza liczbę czytelników o połowę" -
  Stephen Hawking. Trudno, bez ofiar się nie obejdzie.
---

# Podstawy matematyczne

## Podstawy matematyczne

Czy wiesz co to jest medal Fieldsa? Jest to nagroda przyznawana wyłącznie wybitnym matematykom w wieku poniżej 40 lat. Nazywana jest matematycznym Noblem. Co ciekawe żaden matematyk nie otrzyma nagrody Nobla – zgodnie z życzeniem fundatora. Sam John Charles Fields (1863-1932) był Kanadyjskim matematykiem. John Charles Fields miał jednego doktoranta – Samuela Beatty (1881-1970).

Samuel Beatty w 1926 roku opublikował następujące twierdzenie \[1]:

Jeśli p, q są dodatnimi liczbami niewymiernymi i zachodzi pomiędzy nimi zależność

$$
\frac{1}{p}+\frac{1}{q}=1
$$

to sekwencje

$$
\left\{
\left\lfloor np\right\rfloor \right\} _{n=1}^{\infty }=\left\lfloor
p\right\rfloor ,\left\lfloor 2p\right\rfloor ,\left\lfloor 3p\right\rfloor
,\ldots
$$

oraz

$$
\left\{ \left\lfloor nq\right\rfloor \right\}
_{n=1}^{\infty }=\left\lfloor q\right\rfloor ,\left\lfloor 2q\right\rfloor
,\left\lfloor 3q\right\rfloor ,\ldots
$$

oraz dokonują podziału zbioru dodatnich liczb całkowitych.

Te dwie sekwencje dokonują podziału zbioru liczb naturalnych. Oznacza to że dysponując dwoma liczbami niewymiernymi, pomiędzy którymi wskazana w twierdzeniu zależność – będziemy mogli podzielić zbiór wszystkich liczb naturalnych na dwa rozłączne zbiory (Rys. 1).

Twierdzenie Beaty samo w sobie jest bardzo ciekawą obserwacją – jednak w przypadku systemów komputerowych mamy pewien problem z liczbami niewymiernymi. Liczby rzeczywiste – pomimo faktu że w niektórych językach programowania pojawia się czasem słowo Real lub Float jako reprezentanta typu liczby rzeczywistej, z liczbami rzeczywistymi nie mają wiele wspólnego. Fundamentalny problem polega na tym że ich nie mamy i zapewne nigdy mieć nie będziemy.

I tu nasza podróż gwałtownie by się skończyła gdyby nie powstało kolejne twierdzenie. Sytuacja diametralnie uległa zmianie za sprawą matematyka – Aviezri Siegmund Fraenkel (1926) specjalizującego się w kombinatorycznych aspektach teorii gier.

Przedstawił on w 1969 roku następujące twierdzenie \[2]:

Sekwencje

$$
\mathcal{B}(\alpha ,\alpha ^{\prime })
:=
\left( \left\lfloor \frac{n-\alpha^{\prime }}{\alpha }\right\rfloor \right) _{n=1}^{\infty }
$$

oraz

$$
\mathcal{B}^{(c)}(\alpha ,\alpha ^{\prime }):=
\left( \left\lceil \frac{n-\alpha ^{\prime }}{\alpha }\right\rceil \right) _{n=1}^{\infty }
$$

dokonują podziału zbioru ℕ wtedy i tylko wtedy gdy następujące pięć warunków zostanie spełnionych:

1\.

$$
0<\alpha<1
$$

2\.

$$
\alpha+\beta=1
$$

3\.

$$
0\leq \alpha +\alpha ^{\prime }\leq 1
$$

4. Jeśli α jest liczbą niewymierną, wtedy:

$$
\alpha ^{\prime }+\beta ^{\prime }=0
$$

<p align="center">i</p>

$$
k\alpha +\alpha ^{\prime }\not\in \mathbb{Z}
$$

<p align="center">dla</p>

$$
2\leq k\in \mathbb{N}
$$

5. Jeśli α jest liczbą wymierną, (niech q∈N będzie najmniejszą liczbą taką że qα∈N), wtedy

$$
\frac{1}{q}\leq \alpha +\alpha ^{\prime }
$$

<p align="center">i</p>

$$
\left\lceil q\alpha ^{\prime }\right\rceil +\left\lceil q\beta ^{\prime}\right\rceil =1
$$

No i to jest to czego potrzebujemy! Liczb niewymiernych co prawda nie mamy, ale liczby wymierne rozumiane jako stosunek dwóch liczb naturalnych to jest temat do ogarnięcia za pomocą komputera.

W naszym przypadku najpierw stworzyłem prototypy równań w języku Python a następnie zacząłem poszukiwać podstaw matematycznych, które wyglądały podobnie i można było się oprzeć na nich jako dobrze udokumentowanych równaniach popartych formalnymi dowodami. Dowodami oczywiście przeprowadzonymi przez bardziej doświadczonych matematyków. Skromne umiejętności pozwoliły jednak na identyfikację tych dwóch publikacji w aspekcie moich pomysłów.

W tym dokumencie nie umieściłem formalnych dowodów. Dlatego przestawiłem tutaj jedynie stosowane w systemie równania i twierdzenia. Po formalne dowody odsyłam do moich publikacji naukowych \[3].
