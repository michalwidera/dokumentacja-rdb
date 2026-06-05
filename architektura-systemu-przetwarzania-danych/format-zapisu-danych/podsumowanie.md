# Podsumowanie: uzasadnienie przyjętej struktury

Rozdział zbiera wnioski z wszystkich części dokumentacji formatu zapisu danych i wyjaśnia, dlaczego przyjęta struktura czterech plików jest minimalna i wystarczająca dla systemu rejestracji serii czasowych działającego w czasie rzeczywistym.

## Zestaw plików i typy akcesorów

Każdy artefakt lub substrat składa się z maksymalnie czterech plików — plik danych binarnych, deskryptor `.desc`, indeks `.meta` i plik cienia `.shadow`. Pole `TYPE` w deskryptorze wybiera implementację `FileInterface`: `DEFAULT` (dane + cień + retencja), `MEMORY` (wyłącznie RAM, efemerydy), `DEVICE` / `TEXTSOURCE` (zewnętrzne źródła tylko do odczytu) i warianty pośrednie. Wybór akcesora następuje raz przy inicjalizacji `storage` — logika zapytań RQL nie zna szczegółów składowania.

## Pliki artefaktu

**Deskryptor (`.desc`)** definiuje schemat rekordu w gramatyce ANTLR4: nazwy pól, typy (`BYTE`, `INTEGER`, `FLOAT`, `DOUBLE`, `RATIONAL`, `STRING`), rozmiary tablic, politykę retencji (`RETENTION`, `RETMEMORY`) i typ akcesora (`TYPE`). Rozmiar rekordu `R` to suma bajtów wszystkich pól danych — pola metadeskryptora nie zajmują miejsca w rekordzie. Deskryptor przy danych oznacza samoopisywalność: narzędzie `xtrdb` lub dowolny kod może zinterpretować artefakt bez dostępu do kodu źródłowego.

**Plik danych binarnych** to płaska sekwencja rekordów stałej długości `R` bez nagłówka. Rekord `i` leży zawsze na offsecie `i × R`. Operacja `append` dopisuje na koniec; operacja `update` — przy obecnym `.shadow` — trafia do pliku cienia, nie nadpisuje pliku głównego.

**Plik metadanych (`.meta`)** przechowuje kompresowany RLE indeks wartości null i przerw w transmisji. Każdy wpis RLE opisuje ciąg kolejnych rekordów z identycznym wzorcem null: flagę `isGap`, liczbę rekordów `recordCount`, rozmiar bitset i sam bitset. Przerwa w transmisji (`gap`) istnieje wyłącznie w `.meta` — plik binarny jej nie rejestruje i pozostaje gęsty. Klasą zarządzającą jest `rdb::metaDataStream`: buforuje bieżący segment w `currentEntry_`, zapisuje segment na dysk tylko przy zmianie wzorca, a mechanizm `tailDirty_` zapewnia, że rozmiar pliku nie rośnie przy ciągłym napływie jednorodnych danych. Po restarcie `loadIndex()` odtwarza stan i przenosi ostatni niegapowy segment z powrotem do pamięci, umożliwiając kontynuację RLE.

**Plik cienia (`.shadow`)** gromadzi modyfikacje rekordów jako sekwencję wpisów `(position, data)`. Odczyt rekordu sprawdza `.shadow` od końca (najnowsza modyfikacja wygrywa), przy braku wpisu czyta z pliku głównego. Usunięcie `.shadow` w pełni przywraca stan wyjściowy. Operacja `merge()` przepisuje poprawki do pliku głównego i zeruje plik cienia.

## Mechanizm rotacji

Dyrektywa `ROTATION rdb_counter` włącza tryb zachowania historii sesji. `PersistentCounter` przechowuje monotonicznie rosnący numer sesji `N`. Rotacja jest procesem rozłożonym w czasie: przy **starcie** sesji N funkcja `detectStartupState()` wykrywa niezgodność (plik danych pusty, `.meta` niepusty) i przemianowuje `.meta` na `.meta.oldN`; przy **zamknięciu** sesji destruktor `posixBinaryFile` przemianowuje plik danych na `.oldN` i plik cienia na `.shadow.oldN`. Konsekwencją tej kolejności jest przesunięcie o 1: `.meta.oldN` zawiera metadane sesji `N−1`, a `.oldN` — dane sesji `N`. Bez dyrektywy `ROTATION` pliki artefaktów są usuwane przy każdym starcie.

## Narzędzie inspekcji `xtrdb -s`

Polecenie `xtrdb -s <ścieżka>` jest jedynym narzędziem do inspekcji stanu składowania bez uruchamiania `xretractor`. Raport składa się z mapy poglądowej (kolumny: shadow, binary data, meta index) i sekcji szczegółowych: `DESCRIPTOR`, `DATA` (lub `DATA TOTAL` przy retencji segmentowej), `META` z paskiem RLE, `SHADOW` z liczbą niezatwierdzonych modyfikacji oraz `ROTATED FILES` z historią rotacji. Pasek META używa czterech symboli: `=` (dane bez null), `-` (częściowe null), `~` (nullfill), `X` (gap). Narzędzie jest tylko do odczytu i działa gdy proces `xretractor` nie działa.

---

## Porównanie podejść

| Właściwość  | Surowy plik binarny | Struktura RetractorDB |
| ----------- | ------------------- | --------------------- |
| Samoopisywalność | brak — wymaga zewnętrznej dokumentacji | tak — deskryptor `.desc` przy danych |
| Obsługa przerw w transmisji | brak — przerwy niewidoczne lub fikcyjne rekordy | tak — `.meta` rejestruje przerwy bez rozszerzania pliku danych |
| Wartości null per pole | brak — zero = null nierozróżnialne | tak — bitset null w `.meta` |
| Korekta danych historycznych | destruktywna | niedestruktywna — `.shadow` |
| Przywrócenie oryginału po korekcie | niemożliwe | tak — usunięcie `.shadow` |
| Wielokrotność strategii składowania | brak | tak — pole `TYPE` w deskryptorze |
| Koszt przy danych bez przerw i null | — | minimalny: `.meta` ≈ 17 B nagłówek + 1 wpis RLE |
