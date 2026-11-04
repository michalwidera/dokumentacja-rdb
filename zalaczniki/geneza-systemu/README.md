# Geneza systemu

Ponad dwadzieścia lat temu pracowałem w pewnym instytucie naukowym w Zabrzu. Zajmowałem się m.in. budową systemu nadzoru neonatologicznego. Stosunkowo niedawno ukończyłem studia, moja głowa nadal była wypełniona teorią dotyczącą budowy systemów opartych na centralnej bazie danych. Budując system monitorowania stwierdziłem – zrobię go tak jak sztuka każe – oparty na relacyjnej bazie danych. To nie był dobry pomysł. Trafiłem na problem ogólnej wydajności takiego rozwiązania. Rejestrowane sygnały cechowały się wysoką granulacją. Dodatkowo, dostępne systemy baz danych nie były przygotowane na ciągły i nieskończony napływ danych.

Rok 2003 był czasem, w którym bardzo obiecująco prezentowały się w literaturze naukowej tzw. bazy strumieniowe. Po analizie stwierdziłem, że to chyba najbliższa dziedzina w tym czasie, która odpowiada temu, czego potrzebuję. Przyjąłem założenie, że tworzę strumieniową bazę danych do przetwarzania sygnałów. Decyzja z czasem okazała się nie do końca zgodna z prawdą. Systemy strumieniowe przyszły i poszły – ale potrzeba systemów przetwarzających szeregi czasowe pozostała. Systemy strumieniowe przeobraziły się w systemy przetwarzające serie czasowe – Time Series Databases. Do dnia dzisiejszego systemy baz danych przetwarzające serie czasowe znajdują zastosowanie w systemach monitorowania.

Opracowany system nadzoru neonatologicznego obsługiwał kilkanaście pulsoksymetrów. Na sali nadzoru leżało kilkanaście noworodków wymagających ciągłego nadzoru. Każdy noworodek podłączony był m.in. do pulsoksymetru. Każdy pulsoksymetr monitorował rytm serca oraz zawartość tlenu we krwi noworodka. Noworodki się wierciły, sondy odpadały, pulsoksymetry podnosiły alarm co chwilę raportując różnego typu problemy. W takim szumie informacyjnym jeden z noworodków mógł się dusić. Nie działo się to nagle – ale powoli, można było to rozpoznać w szerszym horyzoncie czasowym. Ten jeden przypadek wymagał jednak natychmiastowej reakcji. Równocześnie i do tego bardzo głośno sygnalizowało dźwiękiem kilka urządzeń - a ten jeden z noworodków, ten, który potrzebował pomocy, łapał powietrze cichutko w rogu sali. Tak mniej więcej można opisać skalę problemu. Budowany system umożliwiał jednym rzutem oka stwierdzić, czy wycie urządzenia na sali nadzoru to efekt zsunięcia się czujnika, chwilowy problem czy może coś poważniejszego. Zmieniając skalę czasową można było od razu zidentyfikować problem. Szybka ocena zagrożenia w oparciu o wskazania systemu monitorującego w takim przypadku ratuje zdrowie i życie.

System monitorowania powstał i został wdrożony u klienta w jednym z Warszawskich szpitali. Byłem na miejscu i widziałem, jak działa. Niestety wewnątrz nie było systemu zarządzania danymi, który opisywałem w publikacjach naukowych. Rozwiązanie opracowałem ręcznie bez implementacji języka zapytań, algorytmów i mechanizmów zarządzania. Termin i ograniczone zasoby wymagały dowiezienia tematu na czas. Publikacje, które wtedy powstały opisywały szlachetne potrzeby i założenia – jednak praktyka była inna. Trzeba było dostarczyć produkt a czasu nie było.

Tak przedstawia się w ogólnym zarysie generyczna przyczyna, z której wynikła potrzeba stworzenia systemu zarządzania danymi dla potrzeb przetwarzania sygnałów. Z czasem doszły kolejne obszary zastosowań wynikające z rozszerzających się obszarów rozwojowych związanych z telemetrią, monitorowaniem oraz rozbudową systemów IoT.

Implementacja systemu rozwijała się jeszcze przed publikacją na GitHubie. Zachowana historia projektu `db-project` obejmuje 257 commitów z okresu od 8 sierpnia 2012 r. do 21 lipca 2016 r. [Najstarszy commit](https://github.com/michalwidera/retractordb/commit/df2c085069adc2c44034703e9dd8fddb60e07f39) zawiera już kod kompilatora zapytań, wykonawcy, konsoli i testów regresyjnych. Projekt pojawił się na GitHubie 5 grudnia 2019 r., kiedy udostępniono rozwijaną wcześniej implementację.

4 listopada 2026 r. w ramach [PR #598](https://github.com/michalwidera/retractordb/pull/598) do głównej gałęzi `master` dołączono pełną historię z archiwum `db-project`. Zachowano oryginalne identyfikatory i daty wszystkich 257 commitów. Scalenie uzupełniło historię repozytorium bez zmiany zawartości jego bieżących plików.

## W skrócie

<div class="timeline">

- **Początek XXI wieku - Zabrze**

  System nadzoru neonatologicznego oparty na relacyjnej bazie danych. Sygnały o wysokiej granulacji i ciągły napływ danych ujawniają ograniczenia wydajności.

- **2003 - bazy strumieniowe**

  Strumieniowe bazy danych jako najbliższa dziedzina. Założenie: strumieniowa baza danych do przetwarzania sygnałów.

- **Wdrożenie - szpital w Warszawie**

  System monitorowania działa u klienta, ale bez języka zapytań i mechanizmów zarządzania danymi opisywanych w publikacjach - termin wymusił rozwiązanie ręczne.

- **2012-2016 - prace nad implementacją**

  Archiwum projektu `db-project` obejmuje 257 commitów. Najstarszy, z 8 sierpnia 2012 r., zawiera już kompilator, wykonawcę, konsolę i testy regresyjne. Historię tę dołączono do gałęzi `master` 4 listopada 2026 r. w ramach technicznego scalenia, zachowując oryginalne identyfikatory i daty commitów. Bieżące pliki projektu pozostały bez zmian.

- **2019 - publikacja na GitHubie**

  5 grudnia 2019 r. projekt pojawia się na GitHubie. Do repozytorium trafia rozwijana wcześniej implementacja systemu zarządzania danymi dla przetwarzania sygnałów.

- **Dziś - telemetria, monitorowanie, IoT**

  Systemy strumieniowe przeobraziły się w bazy serii czasowych, a obszar zastosowań rozszerzył się na telemetrię i systemy IoT.

</div>

