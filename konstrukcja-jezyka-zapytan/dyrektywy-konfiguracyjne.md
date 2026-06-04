# Dyrektywy konfiguracyjne

Na chwilę obecną opracowałem trzy dyrektywy konfiguracyjne.

* STORAGE
* SUBSTRAT
* ROTATION

Po każdej z tych dyrektyw występuje ciąg tekstowy ujęty w cudzysłowy lub apostrofy. Przykład zastosowania obu dyrektywy konfiguracyjnych przedstawia się następująco:

```
STORAGE 'temp_folder'
SUBSTRAT 'memory'
ROTATION 'rotation_counter.txt'
```

Storage służy do wskazania w którym katalogu systemowym powinny powstawać wszystkie pliki wynikowe. Bez tej dyrektywy, domyślnie pliki tworzone przez system umieszczane są w bieżącym katalogu w którym został uruchomiony główny proces systemu RetractorDB.

Substraty to zapytania oraz ich efekty, które powstają w wyniku rozkładu poleceń systemu przez kompilator na podstawie wyrażeń algebry szeregów czasowych. Są to zapytania, które widać w planie realizacji zapytań ale nie są one specyfikowane bezpośrednio w pliku .rql. Wynikają one z implementacji procesu konstrukcji planu realizacji zapytań.

Domyślnie takie zapytania materializują dane na dysku w postaci nieskończonych plików. Tego typu zachowanie może być pożądane w przypadku prowadzenia procesu rozwoju oprogramowania, w przypadku umieszczenia systemu w środowisku produkcyjnym lepiej substraty przechowywać w tymczasowych obszarach pamięci.

Możliwe opcje w poleceniu SUBSTRAT to: memory, default, direct, posix, posixshd, generic, device, textsource. Pełny opis każdego typu — klasa C++, obsługa retencji i shadow — znajdziesz w rozdziale [Typy STORAGE](polecenie-select/typy-storage.md).

Ostatnia dyrektywa - Rotation to dyrektywa wskazująca na odmienny tryb kończenia pracy przez system. Domyślnie po kompilacji wszystkie pliki wytworzone przez system pozostają w stanie w jakim system zarejestrował dane. Po kolejnym wywołaniu polecenia systemowego – wszystkie pliki artefaktów i substratów są usuwane. Użycie dyrektywy Rotation w pliku rql z deklaracją zapytań sprawi że system utworzy plik wymieniony w parametrze dyrektywy i umieści tam licznik zwiększany z każdym uruchomieniem systemu. Plikom z artefaktami i substratami po każdym zakończeniu pracy systemu zostanie zmieniona nazwa – dostaną rozszerzenie .old oraz numer wynikający ze wzrastającego licznika. Ten proces nazywamy rotacją artefaktów.
