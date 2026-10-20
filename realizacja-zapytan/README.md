# Realizacja zapytań

Proces realizacji opiera się na ciągłym przeglądzie drzewa zapytań i sekwencyjnym i hierarchicznym wywoływaniu procedur budujących kolejne krotki strumieni i kolejne schematy danych.

Opis algorytmu należy zacząć od przedstawienia procedury sekwencjonowania. W systemie, w którym realizowane są zapytania z różnorodnymi wartościami definiującymi czasokres pomiędzy tworzonymi i napływającymi kolejnymi danymi potrzebny jest sposób wyznaczenia kolejnych interwałów.

Przeanalizujmy na początek następujący przykład. Załóżmy że w systemie występują dwa strumienie danych. Jeden napływa co sekundę drugi co dwie sekundy. Algorytm sekwencjonowania powinien zaproponować sekundowy interwał czasu pomiędzy wywoływaniem procedury przeznaczonej dla strumienia pierwszego i dwusekundowy dla strumienia drugiego. W praktyce przedstawiona zostanie sekundowa siatka czasowa – w której wszystkie sekundowe węzły zostaną wypełnione procedurą budowy krotek ze strumienia pierwszego i w tej samej siatce czasu – drugi strumień dołączy swoje procedury co drugą sekundę.

Wyznaczona w trakcie kompilacji siatka czasu jest bardzo istotna – to ona definiuje jak często i w jakich odstępach będą przetwarzane strumienie danych, które węzły zostaną pokryte przez wygenerowane procedury przetwarzania strumieni danych.

Rozważmy trzy strumienie o interwałach 1/3 s, 1/2 s i 2/3 s. Regularna siatka obejmująca wszystkie ich terminy miałaby krok 1/6 s: interwały są odpowiednio jego dwu-, trzy- i czterokrotnością. Krok 1/5 s nie spełnia tego warunku. Implementacja `TimeLine` nie odwiedza jednak każdego punktu wspólnej siatki; wybiera najbliższą chwilę, w której przypada kolejny rekord co najmniej jednego strumienia.

Generator terminów zachowuje interwały 1/3 i 1/2, ponieważ każdy termin strumienia 2/3 jest już terminem strumienia 1/3. Po slocie zerowym kolejne chwile to 1/3, 1/2, 2/3, 1, 4/3, 3/2, 5/3 i 2 sekundy. Dla każdej chwili silnik sprawdza należność wszystkich strumieni; wspólne terminy obsługuje w jednym slocie. Szczegóły opisuje [Algorytm przeglądu drzewa zapytań](algorytm-przegladu-drzewa-zapytan.md).

Analizując poniższy wywód może bardziej oczywiste staną się wspomniane w rozdziale komentarze generowane dla programu swirly przedstawiające generowane schematy kulkowe.
