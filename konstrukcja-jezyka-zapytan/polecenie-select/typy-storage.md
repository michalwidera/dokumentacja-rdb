---
description: Każdy typ STORAGE to inna klasa C++ z innym zachowaniem wobec dysku i retencji.
---

# Typy STORAGE

Klauzula `STORAGE` w poleceniu `SELECT` oraz dyrektywa `SUBSTRAT` przyjmują jeden z następujących identyfikatorów. Każdy mapuje się na konkretną klasę akcesora danych w implementacji.

## Tabela typów

| Słowo kluczowe | Klasa C++                             | Retencja | Shadow | Przeznaczenie                                   |
| -------------- | ------------------------------------- | :------: | :----: | ----------------------------------------------- |
| `DEFAULT`      | `groupFile<posixBinaryFileWithShadow>`| tak      | tak    | Domyślny tryb produkcyjny; plik `.shadow` chroni modyfikacje |
| `DIRECT`       | `groupFile<posixBinaryFile>`          | tak      | nie    | Retencja bez ochrony shadow                     |
| `MEMORY`       | `memoryFile`                          | nie      | nie    | Dane wyłącznie w pamięci; brak zapisu na dysk   |
| `POSIX`        | `posixBinaryFile`                     | nie      | nie    | Pojedynczy plik binarny; bez retencji           |
| `POSIXSHD`     | `posixBinaryFileWithShadow`           | nie      | tak    | Pojedynczy plik z ochroną shadow; bez retencji  |
| `GENERIC`      | `genericBinaryFile`                   | nie      | nie    | Generyczny plik binarny                         |
| `DEVICE`       | `binaryDeviceRO`                      | nie      | nie    | Urządzenie binarne; tylko odczyt; pętla zależna od `ONESHOT` |
| `TEXTSOURCE`   | `textSourceRO`                        | nie      | nie    | Plik tekstowy; tylko odczyt; pętla zależna od `ONESHOT` |

**Retencja** — artefakty rotowane, starsze pliki usuwane automatycznie (wymaga `RETENTION` w `SELECT`).\
**Shadow** — każda modyfikacja zapisywana jest do osobnego pliku `.shadow`; dane historyczne są chronione przed nadpisaniem.

## Kiedy używać

Wybór zależy od wymagań środowiska:

* **Środowisko produkcyjne, dane krytyczne** → `DEFAULT` (retencja + shadow)
* **Środowisko produkcyjne, dane nieistotne historycznie** → `MEMORY` (zero dysku)
* **Rozwój i debugowanie** → `DEFAULT` lub `DIRECT` (dane widoczne na dysku)
* **Odczyt z urządzenia lub pliku tekstowego** → `DEVICE` / `TEXTSOURCE` (odpowiednio)

## Przykład

```
SELECT str1[0] STREAM str1 FROM core0 STORAGE MEMORY
SELECT str2[0] STREAM str2 FROM core0 RETENTION 100 STORAGE DIRECT
```

Dla substratów globalnie — dyrektywa `SUBSTRAT`:

```
SUBSTRAT 'memory'
```
