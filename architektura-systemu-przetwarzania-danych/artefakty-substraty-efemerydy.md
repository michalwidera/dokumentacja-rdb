---
description: Nadawanie nazw - prawo i konieczność w przypadku wejścia na niezbadany teren.
icon: '1'
---

# Artefakty, Substraty, Efemerydy

Z racji faktu, że system przeznaczony jest do pracy ciągłej i teoretycznie otrzymywane wyniki bez prowadzenia procesu retencji danych zapełniłby każdy nośnik danych wprowadzamy dodatkowe definicje związane z charakterem przetwarzanych danych.

Przedstawiając opis Rys. 9 wspominano o artefaktach. Jest to jedna z definicji wymagających wyjaśnienia.

{% hint style="success" %}
Definicja (Artefakt): Przez artefakty rozumiemy dane przetwarzane w systemie w postaci strumieni, które docelowo zostają zmaterializowane jako utrwalony wynik i efekt przetwarzania innych danych.
{% endhint %}

Ciągłe serie czasowe możemy czytać z urządzeń, następnie je przetwarzać – redukować lub dopasowywać rozmiar danych w czasie i wymiarze. Ale z reguły pewne dane powinny zostać zapisane. Czy te dane potem będą podlegać retencji – jest sprawą drugorzędną. Takie dane, które stanowią efekt i oczekiwaną odpowiedź systemu będziemy nazywać artefaktami. Czymś co oczekujemy i materializujemy dla potrzeb użytkownika końcowego.

{% hint style="success" %}
Definicja (Substrat): Substraty to obiekty pośrednie. W wyniku przetwarzania serii czasowych mogą powstać strumienie danych, które są ulotne. Potrzebne jedynie do i w trakcie przetwarzania.
{% endhint %}

Ich rozmiar może być znaczący biorąc pod uwagę jak daleko cofamy się wstecz w przypadku np. konieczności zrzutów danych monitorowania z przeszłości. Jednak ich istnienie jest bez znaczenia w aspekcie pożądanych wyników działania systemu. Takie strumienie danych nazywamy substratami. Pojawiają się w wyniku działania systemu, nie występują z reguły jawnie w zapytaniach – ale wynikają z procesu przetwarzania serii czasowych, jednak ich wyniki są niezbędne do realizacji zadania.

{% hint style="success" %}
Definicja (Efemeryd): Efemerydy to obiekty, w oparciu o które tworzymy źródłowe strumienie danych, danych których nie można zmagazynować. Są to z reguły dane ulotne, efemeryczne.
{% endhint %}

System czyta np. liczby przypadkowe z odpowiednią częstotliwością i to właśnie źródło danych dostarcza danych ulotnych. Nie można ich zwrócić, przechowywanie ich z reguły mija się z celem – należy je przekazać do dalszego przetwarzania w celu wytworzenia artefaktów lub substratów a następnie zniszczyć i pobrać, nowe aktualne.
