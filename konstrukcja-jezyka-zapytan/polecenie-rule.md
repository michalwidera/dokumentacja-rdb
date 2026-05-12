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

## Składnia polecenia RULE

Pełna składnia polecenia RULE ma postać:

```
RULE <nazwa>
ON <strumień>
WHEN <warunek>
DO <akcja>
```

Gdzie `<akcja>` może przyjąć jedną z dwóch form:

```
SYSTEM '<polecenie_systemowe>'
DUMP [-]<krok_wstecz> TO [-]<krok_wprzód> [RETENTION <n>]
```

### Ograniczenie

Reguła może być podpięta wyłącznie pod strumień zadeklarowany poleceniem `SELECT` (artefakt lub substrat). Podpięcie pod strumień wejściowy `DECLARE` jest błędem kompilacji:

```
# NIEPRAWIDŁOWE — core0 jest deklaracją, nie można podpiąć reguły
RULE r1 ON core0 WHEN core0[0] > 10 DO SYSTEM 'echo alarm'
```

### Warunek WHEN

Warunek to wyrażenie logiczne ewaluowane do wartości prawda/fałsz po każdej nowej próbce strumienia.

Operatory porównania: `=`, `!=`, `<`, `>`, `<=`, `>=`. Operatory logiczne: `OR`, `AND`, `NOT`. Przykłady:

```
WHEN str1[0] > 100
WHEN str1[0] = 0 OR str1[0] = 255
WHEN str1[0] >= 10 AND str1[0] <= 90
WHEN NOT str1[0] = 0
```

## Akcja DO SYSTEM

Akcja `DO SYSTEM` wykonuje podane polecenie powłoki (przez wywołanie `system(3)`) w momencie spełnienia warunku. RetractorDB loguje kod wyjścia polecenia — niezerowy kod jest raportowany jako błąd w logu.

```
RULE alert1
ON wyniki
WHEN wyniki[0] > 1000
DO SYSTEM 'curl -s http://monitoring/alert'
```

W poleceniu można użyć dowolnego programu dostępnego w `PATH`: skryptów powłoki, programów Pythona, wywołań REST, wysyłki powiadomień, etc.

## Akcja DO DUMP

Akcja `DO DUMP` zapisuje okno próbek strumienia do pliku binarnego w momencie spełnienia warunku. Pozwala zachować kontekst zdarzenia: dane przed jego wystąpieniem i dane po nim.

```
RULE zdarzenie
ON wyniki
WHEN wyniki[0] > 500
DO DUMP -10 TO 5
```

Parametry zakresu:

| Parametr                       | Znaczenie                                           |
| ------------------------------ | --------------------------------------------------- |
| ujemny `step_back` (np. `-10`) | dołącz 10 próbek **historycznych** sprzed zdarzenia |
| `0` jako `step_back`           | zacznij zrzut od chwili zdarzenia                   |
| dodatni `step_back` (np. `2`)  | opóźnij start zrzutu o 2 próbki po zdarzeniu        |
| `step_forward` (np. `5`)       | zbierz łącznie `step_forward - step_back` próbek    |

Całkowita liczba zrzucanych rekordów: `abs(step_forward - step_back)`. Przykład: `DUMP -5 TO 5` → 10 rekordów (5 historycznych + 5 kolejnych). `DUMP 0 TO 1` → 1 rekord (bieżąca próbka).

Zakres `step_back` musi być mniejszy lub równy `step_forward`. Wartość `step_back` może być ujemna (historia) lub nieujemna (opóźnienie). Obie wartości ujemne nie są obsługiwane.

### Pliki zrzutu

Pliki są tworzone w katalogu konfigurowanym przez dyrektywę `STORAGE`. Konwencja nazewnictwa:

```
<strumień>_<nazwa_reguły>_dump.tmp          # bez RETENTION
<strumień>_<nazwa_reguły>_dump_<n>.tmp      # z RETENTION (n = 0..N-1)
```

Format pliku to surowe dane binarne zgodne z deskryptorem strumienia (bez nagłówka). Do odczytu pliku można użyć narzędzia `xtrdb`.

### Opcja RETENTION

Parametr `RETENTION <n>` ogranicza liczbę przechowywanych zrzutów — stary plik jest nadpisywany przez nowy (bufor cykliczny). Bez `RETENTION` każde wyzwolenie nadpisuje jeden plik `_dump.tmp`.

```
RULE zdarzenie
ON wyniki
WHEN wyniki[0] > 500
DO DUMP -10 TO 5 RETENTION 20
```

Powyższy przykład przechowuje 20 ostatnich zrzutów w plikach `wyniki_zdarzenie_dump_0.tmp` … `wyniki_zdarzenie_dump_19.tmp`.

## Wiele reguł dla jednego strumienia

Do jednego strumienia można przypiąć dowolną liczbę reguł różnych typów:

```
RULE alert_wysoki   ON pomiary WHEN pomiary[0] > 900 DO SYSTEM 'notify-send "Przekroczono prog"'
RULE alert_niski    ON pomiary WHEN pomiary[0] < 10  DO SYSTEM 'notify-send "Zbyt niska wartosc"'
RULE zapis_anomalii ON pomiary WHEN pomiary[0] > 900 DO DUMP -20 TO 10 RETENTION 5
```

Wszystkie reguły danego strumienia są ewaluowane przy każdej nowej próbce.
