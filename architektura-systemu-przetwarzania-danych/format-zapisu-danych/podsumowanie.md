# Podsumowanie: uzasadnienie przyjętej struktury

## Punkt wyjścia — plik binarny bez metadanych

Najprostszy możliwy zapis serii czasowej to sekwencja surowych wartości w pliku binarnym: stały rozmiar rekordu, brak nagłówka, brak opisu struktury. Takie podejście ma jedną zaletę — minimalny narzut — i szereg istotnych ograniczeń:

- Interpretacja danych wymaga wiedzy zewnętrznej wobec pliku (nazwy pól, typy, kolejność).
- Brak informacji o przerwach w transmisji — ciągłość danych jest pozorna.
- Każda modyfikacja historycznego rekordu niszczy dane oryginalne nieodwracalnie.
- Zmiana struktury rekordu unieważnia cały plik.

RetractorDB rejestruje dane z czujników działających w czasie rzeczywistym, gdzie przerwy zasilania, zaniki sygnału i konieczność retrospektywnej korekty danych są normalnym zjawiskiem eksploatacyjnym, nie wyjątkiem. Struktura czterech plików odpowiada bezpośrednio na każde z tych ograniczeń.

## Co wnosi każdy plik

**Deskryptor (`.desc`) — samoopisywalność i niezależność od kodu**

Plik danych binarnych jest bezużyteczny bez znajomości struktury rekordu. Deskryptor przechowuje tę wiedzę obok danych, co oznacza:

- Dane można odczytać i zinterpretować bez dostępu do kodu źródłowego ani konfiguracji — wystarczy plik `.desc`.
- Narzędzie `xtrdb` może analizować dowolny artefakt bez dodatkowych parametrów.
- Zmiana struktury strumienia (dodanie pola, zmiana typu) jest jawna i wersjonowalna.
- Pole `TYPE` w deskryptorze decyduje o strategii składowania, co pozwala temu samemu silnikowi obsługiwać trwałe artefakty, ulotne efemerydy i zewnętrzne źródła danych bez zmiany logiki zapytań.

**Plik metadanych (`.meta`) — wiarygodność serii czasowej**

Seria czasowa z dziurami, traktowana jako ciągła, prowadzi do błędnych obliczeń okien czasowych, błędnych agregacji i fałszywych korelacji. Plik `.meta` zapewnia:

- Odróżnienie rekordu z wartością zero od rekordu nieobecnego (null) — semantycznie zupełnie różnych stanów.
- Rejestrację przerw w transmisji bez wstawiania fikcyjnych rekordów do pliku danych — plik binarny pozostaje gęsty i adresowalny pozycyjnie.
- Kompresję RLE — typowe serie czasowe mają długie okresy bez null, więc koszt metadanych jest bliski zeru dla danych dobrej jakości.
- Możliwość odtworzenia dokładnego harmonogramu rejestracji, w tym długości przerw, co jest niezbędne przy obliczaniu interwałów w algebrze strumieni.

**Plik cienia (`.shadow`) — niedestruktywna korekta danych**

W systemach pomiarowych korekta błędnych próbek po fakcie jest standardową procedurą. Nadpisanie pliku binarnego jest nieodwracalne i usuwa dowód oryginalnego pomiaru. Plik cienia:

- Pozwala skorygować dowolny historyczny rekord bez modyfikacji pliku głównego.
- Zachowuje oryginalny pomiar jako domyślny — usunięcie pliku `.shadow` w pełni przywraca stan wyjściowy.
- Umożliwia scalenie (`merge`) korekt do pliku głównego wtedy, gdy jest to świadoma decyzja operatora, nie skutek uboczny zapisu.
- Separuje dane certyfikowane (plik główny) od danych roboczych (plik cienia), co ma znaczenie w zastosowaniach wymagających audytowalności.

## Porównanie podejść

| Właściwość | Surowy plik binarny | Struktura RetractorDB |
| ---------- | ------------------- | --------------------- |
| Samoopisywalność | brak — wymaga zewnętrznej dokumentacji | tak — deskryptor `.desc` przy danych |
| Obsługa przerw w transmisji | brak — przerwy niewidoczne lub fikcyjne rekordy | tak — `.meta` rejestruje przerwy bez rozszerzania pliku danych |
| Wartości null per pole | brak — zero = null nierozróżnialne | tak — bitset null w `.meta` |
| Korekta danych historycznych | destruktywna | niedestruktywna — `.shadow` |
| Przywrócenie oryginału po korekcie | niemożliwe | tak — usunięcie `.shadow` |
| Wielokrotność strategii składowania | brak | tak — pole `TYPE` w deskryptorze |
| Koszt przy danych bez przerw i null | — | minimalny: `.meta` ≈ 17 B nagłówek + 1 wpis RLE |
