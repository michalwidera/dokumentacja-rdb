---
description: >-
  Format zapisu danych wymaga uwzględnienia zależności czasowych w opracowanym
  systemie. Zależności te powinny oprócz zarejestrowanych danych odtworzyć
  kolejność ich zarejestrowania oraz występujące mię
---

# Format zapisu artefaktów

W systemie przetwarzanie są serie czasowe w postaci artefaktów, efemerydów i substratów. Dane domyślnie zapisywane są w zwykłych plikach znajdujących się kontrolą systemu operacyjnego. Potencjalne zmiany w tym aspekcie są na etapie koncepcyjnym.

Napływające dane są organizowane w kolejne paczki danych opisane deskryptorami.

Deskryptory rejestrowanych artefaktów specyfikują stałą i niezmienną postać każdego z dodawanych lub modyfikowanych rekordów.

W systemie przewidziano sytuację w której użytkownik nie będzie chciał dopuścić do modyfikacji zarejestrowanych danych, aczkolwiek chciałby nanieść poprawki zachowując poprzednie, oryginalne zarejestrowane wartości. W celu realizacji tego wymagania stworzono pliki wyposażone w tzw. Cień.

Każdy przetwarzany artefakt lub substrat w systemie ma skojarzone ze sobą wymagania dla procesu rejestracji danych.

1. Dane są rejestrowane i dodawane na końcu pliku znajdującego się pod kontrolą systemu operacyjnego.
2. Zarejestrowane dane umieszczane są w buforze pamięciowym, jeśli system wymaga dostępu do danych historycznych - bufor jest rozszerzany do rozmiaru wymaganego przez skompilowane plany realizacji zapytań.
3. Jeśli użytkownik wyda polecenia modyfikacji zarejestrowanych danych to dane są modyfikowane w zrejestrowanym pliku jeśli nie istnieje skojarzony plik cienia.
4. Jeśli istnieje skojarzony plik cienia z danym plikiem zarejestrowanych danych modyfikacje są umieszczane w pliku cienia, a odczyt z pliku prezentuje dane zmodyfikowane.
5. Usunięcie pliku cienia ujawnia dane zarejestrowane oryginalnie.
6. W celu zapewnienia wsparcia dla przerw w przepływie danych zarejestrowane pliki wspierają logikę null
7. Jeśli w danym zarejestrowanym rekordzie znajdują się same wartości null oznacza to że dane nie zostały zarejestrowane w danym momencie czasu.
8. Wartości null są wspierane dodatkowym plikiem indeksu - oznaczonego jako .meta

<figure><img src="../.gitbook/assets/format-zapisu-indeks.svg" alt=""><figcaption><p>Rys. X Postać danych binarnych wraz ze skorzjonym indeksem.</p></figcaption></figure>

