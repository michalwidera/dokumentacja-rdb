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

<figure><img src="../.gitbook/assets/format-zapisu-indeks.svg" alt=""><figcaption><p>Rys. 8 Postać danych binarnych wraz ze skorzjonym indeksem.</p></figcaption></figure>

W przypadku rejestracji danych, kórych przepływ jest ciągły i niczym nie zakłócony oraz żadne zmiany w danych nie muszą być wporwadzane - pliki indeksu i cienia są zbędne. Problem jaki rozwiązuje plik indeksu to dane brakujące oraz przerwy w transmisji. Plik cienia natomiast zapewnia że zarejestrowane dane zostaną przysłonięte zmianami - natomiast nadal będziemy w razie potrzeby mieli dostęp danych orginalnych - zarejestrowanych pierwotnie.

Na Rys.8 przedstawiono relację jaka zachodzi pomiędzy zarejestrowanym plikiem danych a plikiem indeksu. Jak widać w przypadku trywialnym plik zarejestrowanych danych będzie zawierał bardzo dużo danych zarejestrowanych i tylko jeden wpis w pliku indeksu w którym kolumna count będzie odpowiadać ilości rekordów zarejestrowanych oraz wartości F - informującej że rekord nie przedstawia przerwy (gap) a wszystkie dane są obecne we wszystkich zarejestrowanych polach (rekord null bitset który odpowiada ilośći kolumn w pliku z zapisem danych binarnych będzie wypełniony wartościami false).

Sytuacja się komplikuje w momencie pojawienia się wartości null. Wartości null mogą pojawić się w pojedyńczych polach lub we wszystkich. Pojawienie się wartości null w dowolnym polu w zrejestrowanym rekordzie spowoduje wytworzenie kolejnego wpisu w pliku indeksu. Nowe pole będzie zbiorze null bitset zawierać informację które to pole zawiera wartości null i ile ich występuje w kolejności po sobie.

Plik indeksu wspiera również zanik danych. Zanik danych możemy wspierać na dwa różne sposoby. Tworzyć zapisy, które możemy zmodyfikować w pliku cienia, rejestrując rekordy zawierające wszystkie pola zbioru null bitset jako null wskazujące na zarjestrowane puste dane w pliku zapisem danych binarnych. Drugim sposobem jest zarejestrowanie obszaru przerwy w transmisji (np. w trakcie wyłączenia systemu, lub zaniku rejestrowanych danych w wyniku zewnętrznej ingerencji). Takie dane nie są dołączane do pliku zarejestrowanych danych binarnych a informacja o przerwie przechowywana jest tylko w pliku indeksu. W takim rekordzie informacja o przerwie (gap) jest ustawiona na wartość True i wszystkie wartości null bit set ustawione są na wartość True. Długość trwania przerwy określa parametr Count a czas trwania przerwy wyznaczany jest poprzez pomnożenie wartości tego parametru pomnożony z interwałem otrzymanym z opisowych danych zapytania tworzącego strumień.
