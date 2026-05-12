---
description: >-
  Podobnie jak SQL oparto na algebrze zbiorów, RQL jest oparty na algebrze
  regularnych serii czasowych - rozdział: Podstawy matematyczne
icon: '2'
---

# Konstrukcja języka zapytań

Komunikacja pomiędzy opracowanym systemem a użytkownikiem odbywa się za pomocą opracowanego, deklaratywnego języka zapytań. Konstrukcja języka oparta jest na przedstawionej w poprzednim rozdziale algebrze. Podobnie jak w przypadku systemów relacyjnych, gdzie algebra relacji tworzy podstawę dla języka SQL – w moim przypadku opracowana algebra tworzy podstawę dla języka zapytań RQL.

RQL to skrót od _RetractorDB Query Language_. Jego składnia jest bardzo podobna do składni języka SQL. Należy mieć jednak na uwadze, że właściwym określeniem w tym przypadku jest ang. _False Friend_. Czyli wygląda to jak SQL, ale nie ma z nim zbyt wiele wspólnego.

Poprawne zdania w języku RQL na chwilę obecną zaczynają się od kilku słów kluczowych. Najbardziej rozpoznawalne to polecenie zaczynające się od słowa kluczowego SELECT za którym występuje lista atrybutów w postaci wyrażeń algebraicznych. Algebry opartej na liczbach rzeczywistych.

Polecenia zapisuje się w pliku tekstowym. Jego rozszerzenie to zwyczajowo .rql ale dowolne inne też zostanie przyjęte i przetworzone. Plik tekstowy języka RQL zawiera ciąg poleceń zaczynających się od zdefiniowanych słów kluczowych. Komentarze poprzedza się znakiem #.

Język zapytań został zaimplementowany przy pomocy generatora parserów Antlr4 \[[5](../literatura.md)]. Gramatyka języka RQL została zapisana, zdefiniowana i po każdej modyfikacji jest kompilowana do języka w którym stworzono system RetractorDB. Każde zdanie pliku zbioru zapytań nie będące komentarzem jest kompilowane, przetwarzane i modyfikuje wewnętrzny stan systemu.
