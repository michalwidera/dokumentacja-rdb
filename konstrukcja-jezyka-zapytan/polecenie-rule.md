---
description: >-
  Tym poleceniem możesz wytworzyć reakcje systemu na zachodzące zjawiska.
  Alarmowanie ma szerokie zastosowanie.
---

# Polecenie RULE

To polecenie to jedno z ostatnich opracowanych przeze mnie rozszerzeń systemu. Rozszerza ono funkcjonalność systemu o mechanizm alarmowania.

Składnia polecenia RULE przedstawia się następująco:

```
RULE nazwa_reguły
ON nazwa_strumienia_danych
WHEN warunek_logiczny
DO DUMP kroki_wstecz TO kroki_w_przód [RETENTION segmenty]
```

Lub w taki sposób:

```
RULE nazwa_reguły
ON nazwa_strumienia_danych
WHEN warunek_logiczny
DO SYSTEM polecenie_systemu
```

Tak zdefiniowane zdarzenia podpinają się do zdefiniowanych strumieni danych. Nazwa reguły powinna być unikalna. Strumień danych powinien zostać zdefiniowany przed pojawieniem się polecenia stworzenia reguły w pliku rql.

W obu wersjach polecenia RULE tworzona jest nazwa reguły, warunek logiczny oraz nazwa strumienia do którego proces uruchamiany poleceniem DO jest podłączany. Warunek logiczny powinien odwoływać się do zmiennych dostępnych w schemacie strumienia danych występującego po klauzuli ON.

W pierwszej wersji polecenia w której występuje klauzula DO DUMP definiujemy proces, który umożliwia zebranie danych, które napłyną w przyszłości. Jeśli pominiemy klauzulę RETENTION, zrzut nastąpi bezpośrednio do pliku z nazwą reguły poprzedzonej nazwą strumienia. Jeśli dołączymy klauzulę RETENTION, pliki będą podlegały retencji w zakresie zdefiniowanej w parametrze ‘segmenty’. Będą dołączane sekwencyjne numery na końcu każdego zrzutu. Zrzuty są binarne i zachowują schemat wszystkich pól źródłowego strumienia danych. Tutaj na uwagę powinno zasługiwać to, że polecenie tworzy proces w systemie, który po pojawieniu się warunku logicznego którego wartość powinna być prawdą – pobiera dane z przeszłości oraz zakłada ich napływ i rejestrację w przyszłości. Nic nie stoi na przeszkodzie aby jednak zebrać dane tylko z przeszłości lub tylko z przyszłości. Jeśli wartości kroki\_\* przyjmą wartości ujemne to odnosimy się do przeszłości (tzn. do danych historycznych w stosunku do momentu wystąpienia zdarzenia opisanego warunkiem logicznym)

Klauzula DO SYSTEM umożliwia wywołanie zdarzenia systemowego po zajściu w warunku logicznego opartego na zarejestrowanych danych. W ten sposób dowolne polecenie systemowe może zostać wywołane.

Przykłady deklaracji reguł w języku RQL:

```
RULE testrule1
ON str1
WHEN str1[0] > 11
DO DUMP -5 TO 5 RETENTION 100

RULE testrule2
ON str1
WHEN str1[0] = 13 OR str1[0] = 11
DO SYSTEM 'echo "systemcall"'
```

Zakładamy, że zdefiniowano uprzednio strumień str1 którego dane w postaci liczb o typie całkowitym pojawiają się co sekundę. W takim przypadku pierwsza reguła podpinając się do tego strumienia oczekuje aż dane, których wartość przekracza wartość 11. Jeśli takie zdarzenie zajdzie dokona się zrzut danych obejmujących obszar 5 sekund wstecz i 5 sekund po zajściu zdarzenia opisanego w warunku logicznym.

Druga reguła z trochę innym warunkiem logicznym wyświetli na ekranie w którym został uruchomiony proces systemu RetractorDB tekst o treści „systemcall”.
