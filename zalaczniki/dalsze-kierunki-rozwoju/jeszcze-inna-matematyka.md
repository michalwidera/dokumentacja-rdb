# Jeszcze inna matematyka

Kilka lat temu poszukiwałem rozszerzenia algebry przedstawionej w rozdziale o podstawach matematycznych o liczby zespolone. Bezpośrednie zastosowanie gaussowskich liczb zespolonych - zakładając, że bazą obliczeń będą liczby wymierne nie dało spodziewanych efektów. Modele obliczeniowe wskazywały na to, że rozkład zbioru liczb naturalnych w oparciu o te liczby nie działa.

Moje wewnętrze przeczucie wskazywało, że problem leży w samej naturze przetwarzanych liczb zespolonych. Moduł liczby zespolonej, której oba elementy są liczbami wymiernymi jest liczbą Rzeczywistą. Inaczej, długość przeciwprostokątnej w trójkącie, którego przyprostokątne są wyrażone liczbami wymiernymi – wyląduje w zbiorze liczb rzeczywistych.

Sytuacja nie była komfortowa. Zacząłem przeglądać literaturę. Trafiłem na coś ciekawego – liczby Eisensteina. (Proszę zwróć uwagę – nie Einsteina tylko Eisensteina). Na Wikipedii znajdziesz artykuł pt. „[Liczby całkowite Eisensteina](https://pl.wikipedia.org/wiki/Liczby_ca%C5%82kowite_Eisensteina)”. Eisenstein – a tak naprawdę [Ferdinand Gotthold Max Eisenstein](https://pl.wikipedia.org/wiki/Ferdinand_Gotthold_Max_Eisenstein) – to niemiecki matematyk, który żył jedynie 29 lat – zostawił po sobie wkład w matematykę, który możemy wykorzystać.

Liczby całkowite Eisensteina definiujemy w postaci:

$$
z_{C} = a + b\omega \qquad a, b \in \mathbb{Z}
$$

$$
\omega = \frac{-1 + i\sqrt 3}{2} = e^{ \frac{2}{3}\pi i}
$$

jednostka _i_ jest jednostką urojoną.

Tak przedstawione liczby postanowiłem zmodyfikować w następujący sposób:

$$
z_{W} = \frac{a}{b} + \frac{c}{d}\omega \qquad
a, b, c, d \in \mathbb{Z}
$$

I takie właśnie wymierne liczby zespolone użyłem do budowy algebry rozkładającej zbiór liczb naturalnych - działają.

Opracowany model numeryczny znajdziesz tutaj: [https://github.com/michalwidera/equations](https://github.com/michalwidera/equations)
