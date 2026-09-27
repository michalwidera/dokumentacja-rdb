# Granice wymiarów planu

RetractorDB odrzuca plan, którego wymiary przekraczają bezpieczny zakres parsera, deskryptora lub pamięci historii. Kontrole działają przy zwykłym starcie, w `xretractor -c`, dla zapytań ad hoc i przy `xqry --reset`. W tym ostatnim przypadku odmowa nowego planu pozostawia działający plan bez zmian. Liczby graniczne są wspólne dla parserów RQL i DESC oraz kompilatora w `src/include/rdb/sizeLimits.hpp`.

## Warstwa 1: pojedynczy literal

| Wymiar | Dopuszczalna wartość | Dotyczy |
| --- | ---: | --- |
| Długość pola | `1..65536` | `TYP[N]`, `STRING[N]`, `to_string(x : N)`; parser DESC stosuje tę samą granicę pól. |
| Zasięg historii | do `65536` | Krok i wartość bezwzględna szerokości `@(step, window)`, szerokość okna rekordowego, przesunięcie `>N` i granice `DUMP -L TO R`. Krok i szerokości muszą być dodatnie; przesunięcie i granice `DUMP` mogą być zerem. |
| `DUMP ... RETENTION` | `0..256` | Liczba jednocześnie pamiętanych zadań zrzutu; `0` oznacza brak retencji zadań. |
| Rozmiar generatora | `1..128` | `STREAM nazwa[N]`; po rozwinięciu generatorów cały plan może mieć najwyżej 128 strumieni. |

Pojemność `RETENTION` magazynu musi być dodatnia. W dwuczłonowej postaci liczba segmentów może wynosić `0`, co oznacza brak limitu segmentów na dysku. Literał poza zakresem typu liczbowego jest błędem parsera, a przekroczenie powyższej granicy daje komunikat w rodzaju `AGSE step 65537 exceeds the limit 65536`. `to_string(x : 0)` daje `to_string width 0 must be greater than zero`; nie tworzy pola o zerowej szerokości.

## Warstwa 2: wymiary po rozwinięciu planu

| Kontrola kompilatora | Granica | Dlaczego jest osobna |
| --- | ---: | --- |
| Każde pole wynikowe, także pochodne | `65536` elementów lub bajtów napisu | Konkatenacja może przekroczyć granicę, mimo że każdy literal mieścił się w niej osobno. |
| Rekord wyjściowy strumienia | `1 MiB` (`1048576` bajtów) | Suma rozmiarów pól po ustaleniu schematu. |
| Rekord wejściowy strumienia | `1 MiB` (`1048576` bajtów) | Okno AGSE, suma lub przeplot mogą zbudować wejście większe od rekordu wynikowego. |
| Suma płaskich elementów rekordów w planie | `2^18` (`262144`) | Ogranicza koszt rozbudowy deskryptorów i wykonania, także przy wielu małych polach. |
| Początek logiczny i ogon startowy | `INT_MAX` (`2147483647`) slotów każdy | Wyniki obliczeń kompilatora muszą mieścić się w reprezentacji `int` używanej przez plan. |

Kontrola liczby 128 strumieni po rozwinięciu dotyczy planu z generatorem i następuje przed kopiowaniem jego instancji. Plan bez generatora może przejść ten etap, lecz limit slotu magistrali jest sprawdzany przy rejestracji lub wymianie planu. Rozmiary rekordów i pól są sprawdzane przed budową potencjalnie dużych deskryptorów.

Kompilator podaje strumień oraz przekroczony wymiar, np. `Stream 'x' reads an input record of 1048577 bytes; the limit is 1048576`, `Plan needs 262145 record elements; the limit is 262144 (reached at stream 'x')`, `Stream 'x' has a logical origin of ... slots; the limit is 2147483647` lub analogiczny komunikat o `startup latency`.

## Budżet historii w RAM

`[limits] history_memory_mib` w `retractor.toml` ustala łączny budżet historii planu, domyślnie `1024` MiB. Kompilator sumuje dla każdego źródła `DECLARE` i każdego magazynu `MEMORY` iloczyn liczby przechowywanych rekordów oraz rozmiaru rekordu powiększonego o narzut `rdb::payload`. Pojemność źródła wynika z potrzeb konsumentów, a pierścień `MEMORY` ma większą z wartości `RETENTION n` i potrzeby planu. Historia magazynów plikowych nie wchodzi do tego budżetu.

Przekroczenie budżetu kończy kompilację komunikatem `Plan keeps ... bytes of stream history in memory; the budget [limits] history_memory_mib = ... allows ...`, który wskazuje także strumień o największym udziale. Wartość konfiguracyjna musi być dodatnia; `0` lub liczba ujemna powoduje ostrzeżenie i użycie domyślnych `1024` MiB. Budżet nie jest limitem pamięci całego procesu ani rozmiaru kolejek IPC. Konfigurację opisuje [xretractor](../zalaczniki/opcje-wywolania/xretractor.md#plik-konfiguracyjny-toml), a zasady retencji - [Typy STORAGE](../konstrukcja-jezyka-zapytan/polecenie-select/typy-storage.md).
