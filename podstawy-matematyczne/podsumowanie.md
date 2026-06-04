# Podsumowanie

Równania te z początku modelowałem w postaci programów w języku Python. Przedstawioną formalną formę przyjęły na sam koniec procesu poszukiwań. Dowodząc numerycznie poprawności opracowanych równań konstruowałem sekwencje operacji na strumieniach. Jeśli jakieś elementy gubiły się w trakcie realizacji przedstawionych operacji – oznaczało to że popełniłem błąd. Okazuje się np. ze istotne jest w implementacji aby nie opuszczać nawet na chwilę dziedziny liczb wymiernych. Błąd można popełnić przypadkiem, niejawnie rzutując wynik na liczbę zmiennoprzecinkową. Materializację wyniku w formie zmiennoprzecinkowej należy w obliczeniach odłożyć do momentu jawnego przeniesienia wyniku operacją podłogi lub sufitu. Jeśli program w Pytonie złożymy w sekwencję operacji na nieskończonych strumieniach i żadne dane w wyniku tej operacji nie znikną – mamy obiekt do dalszych badań i analizy formalnej, gotowy do formalnego dowodu matematycznego poprawności. Formalny dowód (formalizm matematyczny) znajdziemy w pracy pt. [Deterministyczna metoda przetwarzania ciagow danych](https://www.academia.edu/1840563/Deterministyczna_metoda_przetwarzania_ciagow_danych) \[[3](../literatura.md#3)].

Dział matematyki który zawiera prace badawcze związane z tymi równaniami nosi nazwę systemów pokrywających \[[4](../literatura.md#4)] w obszarze teorii liczb.

> **ℹ️ Info**
>
> Przedstawienie podstaw matematycznych systemu jest konieczne w celu zrozumienia dalszych technicznych aspektów rozwiązania. Przedstawione metody wybiegają poza standardowy materiał prezentowany obecnie na studiach z zakresu nauk technicznych. Wynika to z faktu, że podstawy matematyczne wydobyłem z obszaru dotychczas niemającego zastosowań w znanej mi technice. Są to metody umożliwiające zbudowanie nowego sposobu przetwarzania danych. Na tym polega jeden z aspektów różniących RetractorDB od reszty podobnych rozwiązań.

