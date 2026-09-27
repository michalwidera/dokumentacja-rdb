# Typy STORAGE

Klauzula `STORAGE` w poleceniu `SELECT` oraz dyrektywa `SUBSTRAT` przyjmują jeden z następujących identyfikatorów. Każdy mapuje się na konkretną klasę akcesora danych w implementacji.

## Tabela typów

| Słowo kluczowe | Klasa C++                             | Retencja | Shadow | Przeznaczenie                                   |
| -------------- | -------------------------------------------------- | :------: | :----: | ------------------------------- |
| `DEFAULT`      | `groupFile<posixBinaryFileWithShadow>`| tak      | tak    | Domyślny tryb produkcyjny; plik `.shadow` chroni modyfikacje |
| `DIRECT`       | `groupFile<posixBinaryFile>`          | tak      | nie    | Retencja bez ochrony shadow                     |
| `MEMORY`       | `memoryFile`                          | tak (RAM)| nie    | Dane wyłącznie w pamięci; bufor kołowy bez zapisu na dysk |
| `POSIX`        | `posixBinaryFile`                     | nie      | nie    | Pojedynczy plik binarny; bez retencji           |
| `POSIXSHD`     | `posixBinaryFileWithShadow`           | nie      | tak    | Pojedynczy plik z ochroną shadow; bez retencji  |
| `GENERIC`      | `genericBinaryFile`                   | nie      | nie    | Generyczny plik binarny                         |
| `DEVICE`       | `binaryDeviceRO`                      | nie      | nie    | Urządzenie binarne; tylko odczyt; pętla zależna od `ONESHOT` |
| `TEXTSOURCE`   | `textSourceRO`                        | nie      | nie    | Plik tekstowy; tylko odczyt; pętla zależna od `ONESHOT` |

**Retencja** - artefakty rotowane, starsze pliki usuwane automatycznie (wymaga `RETENTION pojemność segmenty` w `SELECT`).\
**Shadow** - każda modyfikacja zapisywana jest do osobnego pliku `.shadow`; dane historyczne są chronione przed nadpisaniem.

W przypadku `MEMORY` retencja działa w pamięci jako bufor kołowy: kolejne dopisania nadpisują najstarszy slot (`index % capacity`). Dane nie są segmentowane do plików i nie trafiają na dysk. `RETENTION n` ustala rozmiar pierścienia (co najmniej tyle, ile wymaga plan) - tak samo przy `STORAGE MEMORY` i przy `VOLATILE`; postać z segmentami `RETENTION n s` jest tu błędem kompilacji.

Także bez `RETENTION` magazyn `MEMORY` ma skończoną pojemność: co najmniej jeden rekord, powiększoną przez kompilator do potrzeb konsumentów. Dawniejszy `STORAGE MEMORY` mógł rosnąć bez końca albo, przy `RETENTION n`, zapisać dane na dysk z niewłaściwym typem magazynu. Obecnie rozmiar pierścienia i łączny koszt historii podlegają [budżetowi planu](../../kompilacja-zapytan/granice-wymiarow-planu.md#budżet-historii-w-ram). Reguła ad hoc `DO DUMP` sięgająca głębiej niż istniejący pierścień jest odrzucana; dołączenie reguły nie zwiększa pojemności działającego magazynu.

### Retencja na dysku

Magazyny `DEFAULT` i `DIRECT` trzymają dane w segmentach: `RETENTION pojemność segmenty` zachowuje co najwyżej `segmenty` plików po `pojemność` rekordów, a najstarszy segment jest kasowany przy otwarciu nowego. Postać jednoargumentowa `RETENTION n` oznacza wyłącznie rozmiar pierścienia `MEMORY`; na magazynie plikowym jest błędem kompilacji z podpowiedzią `RETENTION n <segmenty>`. `segmenty = 0` znaczy „bez limitu segmentów”.

Przykładowo `RETENTION 100 STORAGE DIRECT` jest odrzucane, ponieważ nie podaje liczby segmentów. Poprawny zapis to `RETENTION 100 4 STORAGE DIRECT`. Dla `STORAGE MEMORY` obowiązuje odwrotna zasada: `RETENTION 100` ustala pierścień, a `RETENTION 100 4` jest odrzucane jako retencja segmentowa przy magazynie w RAM.

Tuż po rotacji na dysku zostaje tylko `(segmenty - 1) * pojemność + 1` rekordów. Plan, który czyta wstecz więcej rekordów strumienia (przesunięcie `>N`, okno `@`, zakres `DUMP`), jest błędem kompilacji - odczyt skasowanego segmentu kończyłby działający serwer.

Strumień plikowy bez `RETENTION`, z `segmenty = 0` albo w magazynie bez retencji (`POSIX`, `POSIXSHD`, `GENERIC`) rośnie na dysku bez granicy. Jest to dozwolone - historia trwała - ale jawne: `xretractor` przy starcie i w trybie `-c` wypisuje na stderr takie strumienie, łącznie ze strumieniami pośrednimi wydzielonymi przez kompilator. Granicę dla wszystkich strumieni `DEFAULT`/`DIRECT` bez `RETENTION` może postawić operator kluczem `default_retention = [pojemność, segmenty]` w sekcji `[storage]` pliku `retractor.toml`; bez tego klucza silnik nie kasuje żadnych danych.

Start bez dyrektywy `ROTATION` zaczyna od zera wyniki `SELECT` i substraty: kasuje całą rodzinę ich plików - dane z plikiem `.shadow`, `.desc`, `.meta` i segmenty retencji. Nie usuwa plików źródeł `DECLARE`. Z dyrektywą `ROTATION` zachowane pliki magazynów dyskowych muszą pasować do planu: jeśli `.desc` ma inny typ magazynu albo inną retencję, start (i `xqry --reset`) jest odmową z nazwą strumienia i obiema konfiguracjami. W przypadku `MEMORY` także przy `ROTATION` usuwane są stare pliki deskryptora i metadanych, aby nowy pierścień nie odziedziczył konfiguracji poprzedniego planu. Zmiana pojemności przy zachowanych segmentach przestawiłaby adresowanie rekordów, dlatego operator wybiera: przywrócić poprzednią konfigurację w planie albo usunąć pliki strumienia.

> **_NOTE:_** Typ `MEMORY` (SUBSTRAT 'memory') ma pokrycie w testach: `issue61_tmpmem` (sekwencyjny i równoległy) opisanych w załączniku pt. [Testy Integracyjne](../../zalaczniki/testy-integracyjne.md).

## Kiedy używać

Wybór zależy od wymagań środowiska:

* **Środowisko produkcyjne, dane krytyczne** → `DEFAULT` (retencja + shadow)
* **Środowisko produkcyjne, dane nieistotne historycznie** → `MEMORY` (zero dysku, retencja w RAM)
* **Rozwój i debugowanie** → `DEFAULT` lub `DIRECT` (dane widoczne na dysku)
* **Odczyt z urządzenia lub pliku tekstowego** → `DEVICE` / `TEXTSOURCE` (odpowiednio)

## Przykład

```rql
SELECT str1[0] STREAM str1 FROM core0 STORAGE MEMORY
SELECT str2[0] STREAM str2 FROM core0 RETENTION 100 4 STORAGE DIRECT
```

Dla substratów globalnie - dyrektywa `SUBSTRAT`:

```rql
SUBSTRAT 'memory'
```
