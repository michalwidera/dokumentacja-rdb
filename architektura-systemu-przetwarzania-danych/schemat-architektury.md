---
description: Widok z lotu ptaka ...
icon: image-landscape
---

# Perspektywa ogólna

System zbudowany jest w oparciu o 3 programy dostępne jako polecenia systemowe. Pierwszym jest kompilator oraz system realizujący plany zapytań. Drugim jest klient dostępu do danych bieżących, trzecim jest program umożliwiający dostęp zrzutów binarnych. Ich nazwy to kolejno:

* xretractor
* xqry
* xtrdb

Program xretractor tworzy główny proces systemu RetractorDB. Program xqry tworzy procesy komunikujące się z systemem RetractorDB. Komunikacja zachodzi za pomocą wspólnego obszaru w pamięci. Program xtrdb służy do analizy danych i metadanych zapisywanych w plikach bazy danych.

Poniżej przedstawiona jest na Rys. 9 schematycznie architektura systemu RetractorDB. Uwzględniono wszystkie istniejące aktualnie komponenty. Obszary ujęte w prostokątach z nagłówkami wypełnionymi poleceniami systemowymi odpowiadają istniejącym komponentom. Obszar zapisu artefaktów to symboliczna reprezentacja systemu plików.

<figure><img src="../.gitbook/assets/schemat_architektury_retractordb.png" alt=""><figcaption><p>Rys. 9 Schemat przepływu danych pomiędzy procesami RetractorDB</p></figcaption></figure>

Na Rys. 9 widzimy procesy realizowane przez programy xretractor, xtrdb oraz xqry. Na rysunku schematycznie przedstawiono sposób komunikacji pomiędzy procesami w systemie RetractorDB. Rysunek pokazuje części wspólne opracowanych narzędzi.

Proces xretractor komunikuje się z procesami xqry poprzez obszar pamięci współdzielonej. W tej pamięci dla każdego procesu xqry tworzona jest przez xretractor kolejka danych. Dane są odbierane na bieżąco przez procesy xqry. Zadaniem procesów xqry jest wysyłka danych dalej do innych systemów lub procesów. Jeśli proces xqry ginie lub jest kończony xretractor zarządzający obszarem wspólnym zwalnia obszar dedykowany we wspólnym obszarze.

Oprócz kierowania danych do wysyłki poprzez pamięć współdzieloną, system RetractorDB zapisuje dane do tzw. Obszaru zapisu artefaktów. Aktualnie jest to katalog do którego zapisywane są na bieżąco efekty procesu przetwarzania strumieni danych w oparciu o plany realizacji zapytań realizowane w systemie RetractorDB.

{% hint style="warning" %}
Przedstawiona na rysunku Baza danych to nie jest Relacyjna baza danych. Przez bazę danych na przedstawionym rysunku rozumiemy zbiór plików binarnych lub tekstowych, którymi zarządza RetractorDB. Dane pobierane są z urządzeń i zapisywane w rotujących lub nie plikach binarnych lub tekstowych. Dostęp do tych danych realizowany jest za pomocą narzędzia xtrdb lub w trakcie działania systemu przez proces xqry.
{% endhint %}

Plik z zapytaniami i dyrektywami RQL podaje się jako wymagany, pierwszy argument polecenia uruchamiającego system. Takie zachowanie prawdopodobnie ulegnie w przyszłości zmianie – system docelowo powinien uruchomić się jako usługa i oczekiwać od operatora pliku z dyrektywami. Na chwilę obecną system jednak uruchamiamy z wkładem inicjującym. Jak chcemy coś dołożyć w trakcie pracy, odsyłam do rozdziału pt. Zapytania Ad hoc.
