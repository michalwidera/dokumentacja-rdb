# Realizacja zapytań

Proces realizacji opiera się na ciągłym przeglądzie drzewa zapytań i sekwencyjnym i hierarchicznym wywoływaniu procedur budujących kolejne krotki strumieni i kolejne schematy danych.

Opis algorytmu należy zacząć od przedstawienia procedury sekwencjonowania. W systemie, w którym realizowane są zapytania z różnorodnymi wartościami definiującymi czasokres pomiędzy tworzonymi i napływającymi kolejnymi danymi potrzebny jest sposób wyznaczenia kolejnych interwałów.

Przeanalizujmy na początek następujący przykład. Załóżmy że w systemie występują dwa strumienie danych. Jeden napływa co sekundę drugi co dwie sekundy. Algorytm sekwencjonowania powinien zaproponować sekundowy interwał czasu pomiędzy wywoływaniem procedury przeznaczonej dla strumienia pierwszego i dwusekundowy dla strumienia drugiego. W praktyce przedstawiona zostanie sekundowa siatka czasowa – w której wszystkie sekundowe węzły zostaną wypełnione procedurą budowy krotek ze strumienia pierwszego i w tej samej siatce czasu – drugi strumień dołączy swoje procedury co drugą sekundę.

Wyznaczona w trakcie kompilacji siatka czasu jest bardzo istotna – to ona definiuje jak często i w jakich odstępach będą przetwarzane strumienie danych, które węzły zostaną pokryte przez wygenerowane procedury przetwarzania strumieni danych.

Zastanówmy się nad bardziej skomplikowanym przykładem. Załóżmy istnienie trzech strumieni danych. Pierwszy z częstotliwością napływu ⅓ drugi z szybkością ½ oraz trzeci napływający z szybkością ⅔. Wyznaczenie siatki i umieszczenie kolejnych procedur przetwarzania wymaga bardziej skomplikowanego rozwiązania. Wartość ⅔ może zostać uproszczona do ⅓. Bowiem istnieje naturalny podzielnik tych wartości. Nie istnieje natomiast naturalny podzielnik wartości ½ oraz ⅓. Wartość siatki jaka zostanie wyznaczona to ⅕. Jest to największa możliwa liczba wymierna, która jeśli zbuduje się na osi liczb wymiernych siatkę pomieści regularne serie czasowe o częstotliwości napływa ½ oraz ⅓.

Na wyznaczoną siatkę nakładane są wszystkie strumienie i wyznaczany jest zbiór minimalnych odstępów czasu dla zapytań w których istnieją mnożniki naturalne. W naszym przypadku minimalny zbiór odstępów czasu dla zapytań o mnożnikach (⅓, ½, ⅔) to zbiór (⅓, ½). Odstępy ⅓ oraz ⅔ będą współdzielić slot czasowy na siatce.

Analizując poniższy wywód może bardziej oczywiste staną się wspomniane w rozdziale komentarze generowane dla programu swirly przedstawiające generowane schematy kulkowe.
