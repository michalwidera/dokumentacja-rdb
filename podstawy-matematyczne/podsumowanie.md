---
icon: lambda
---

# Podsumowanie

Równania te z początku modelowałem w postaci programów w języku Python. Przedstawioną formalną formę przyjęły na sam koniec procesu poszukiwań. Dowodząc numerycznie poprawności opracowanych równań konstruowałem sekwencje operacji na strumieniach. Jeśli jakieś elementy gubiły się w trakcie realizacji przedstawionych operacji – oznaczało to że popełniłem błąd. Okazuje się np. ze istotne jest w implementacji aby nie opuszczać nawet na chwilę dziedziny liczb wymiernych. Błąd można popełnić przypadkiem, niejawnie rzutując wynik na liczbę zmiennoprzecinkową. Materializację wyniku w formie zmiennoprzecinkowej należy w obliczeniach odłożyć do momentu jawnego przeniesienia wyniku operacją podłogi lub sufitu. Jeśli program w Pytonie złożymy w sekwencję operacji na nieskończonych strumieniach i żadne dane w wyniku tej operacji nie znikną – mamy obiekt do dalszych badań i analizy formalnej, gotowy do formalnego dowodu matematycznego poprawności. Formalny dowód możemy znaleźć w pracy \[3].

Dział matematyki który zawiera prace badawcze związane z tymi równaniami nosi nazwę systemów pokrywających \[4] w obszarze teorii liczb.

{% hint style="info" %}
Przedstawienie podstaw matematycznych systemu jest konieczne w celu zrozumienia dalszych technicznych aspektów rozwiązania. Przedstawione metody wybiegają poza standardowy materiał prezentowany obecnie na studiach z zakresu nauk technicznych. Wynika to z faktu, że podstawy matematyczne wydobyłem z obszaru dotychczas niemającego zastosowań w znanej mi technice. Są to metody umożliwiające zbudowanie nowego sposobu przetwarzania danych. Na tym polega jeden z aspektów różniących RetractorDB od reszty podobnych rozwiązań.
{% endhint %}
