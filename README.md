---
description: Słowem wstępu.
---

# RetractorDB

System **RetractorDB** jest systemem przeznaczonym do przetwarzania i rejestrowania regularnych serii czasowych. System składa się z trzech współpracujących ze sobą programów. Programy zostały stworzone w języku C++ a repozytorium znajduje się pod ciągłą kontrolą testów i integracji. Kod testowany jest na platformach x64 i Arm64 działających pod kontrolą systemu Linux. System opracowano z zamiarem uruchamiania go w rygorze czasu rzeczywistego. Główny proces zarządza dwoma wątkami. Pierwszy wątek przetwarza plan realizacji zapytania. Ten wątek jest sekwencyjny i deterministyczny. Drugi wątek zapewniają komunikację ze światem zewnętrznym, wymianę danych i zarządzanie kolejkami komunikacyjnymi.

Kod źródłowy systemu został opublikowany na licencji MIT i znajduje się pod adresem [https://github.com/michalwidera/retractordb](https://github.com/michalwidera/retractordb). Główna strona internetowa jest dostępna pod adresem [https://retractordb.com](https://retractordb.com).

{% hint style="warning" %}
Wstępna analiza wykazała że system powinien być określony jako Edge Signal Processing Engine (Brzegowy System Przetwarzania Sygnałów) a nie jako System Zarządzania Seriami Czasowymi (Time Series Databasse). Prawdopodobnie ten system powinien pełnić komplementarną rolę dla inny systemów analitycznych a nie konkurować z nimi.
{% endhint %}

{% hint style="info" %}
UWAGA: Polecenia opracowanego języka zapytań prezentowane są z rozbiciem na słowa kluczowe, gdzie każde słowo kluczowe jest w nowej linii. Jest to zabieg edytorski dla celów tej publikacji i ułatwienia czytelnikowi rozpoznania słów kluczowych. W rzeczywistym systemie zaimplementowałem odczyt i kompilację poleceń linia po linii. Ta funkcjonalność być może też w przyszłości może ulec zmianie.
{% endhint %}

{% hint style="info" %}
Ta dokumentacja nie powstała w celu spełnienia jakiegoś formalnego wymagania. Ta dokumentacja powstała bo stworzone narzędzie - **RetractorDB** jest na tyle skomplikowane, że bez niego zrozumienie całości analizując jedynie stworzony kod wydaje mi się niewykonalne.\
Postawiłem użytkownikom wysoki próg wejścia. Mam nadzieję że stworzony dokument ułatwi pierwszym użytkownikom zrozumienie i potencjalne zastosowanie efektów mojego wysiłku. Liczę na to że po przeczytaniu, zrobieniu kilku eksperymentów znajdziesz potencjalne zastosowania w rozwiązaniu Twojego problemu. To właśnie było moją bazową motywacją. Stworzenie czegoś, co przyda się komuś, kiedyś... Bo wymyślanie koła na nowo za każdym razem to marnowanie wysiłku intelektualnego poprzednich pokoleń.\
Pozdrawiam,\
Michał &#x20;
{% endhint %}
