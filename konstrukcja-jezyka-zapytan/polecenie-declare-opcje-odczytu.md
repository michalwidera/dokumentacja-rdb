# Opcje odczytu w DECLARE

Polecenie `DECLARE` przyjmuje trzy opcjonalne dyrektywy wpływające na sposób odczytu i cykl życia zadeklarowanego źródła plikowego:

```rql
DECLARE pole typ STREAM nazwa, szybkość BINFILE | TEXTFILE źródło
    [DISPOSABLE]
    [ONESHOT]
    [HOLD]
```

Dyrektywy są niezależne i można je łączyć w dowolny sposób. Dotyczą wyłącznie plików odtwarzanych (`BINFILE`, `TEXTFILE`). Źródło żywe `DEVICE` nie przyjmuje żadnej z nich - patrz [macierz](#macierz-opcji-i-rodzajów-źródeł) na końcu rozdziału.

## ONESHOT

Bez `ONESHOT` plik czytany jest w nieskończonej pętli - po osiągnięciu końca pliku pozycja odczytu wraca na początek. `ONESHOT` wyłącza pętlę: plik czytany jest dokładnie raz, a po jego wyczerpaniu strumień zwraca rekordy ze wszystkimi polami `NULL`. Bajty takiego rekordu są wyzerowane, ale znaczniki null odróżniają brak danych od wartości zero. Wyczerpanie pliku nie kończy procesu ani nie usuwa pliku.

```rql
DECLARE pomiar INTEGER STREAM burst, 0.1 BINFILE 'dane.dat' ONESHOT
```

Zastosowanie: jednorazowe załadowanie danych historycznych do systemu.

Opcja `--until-eof` (`-u`) programu `xretractor` czyta wszystkie pliki tak, jakby każda deklaracja niosła `ONESHOT`, i zatrzymuje przetwarzanie po wyczerpaniu pierwszego z nich.

## DISPOSABLE

Przy zamknięciu magazynu źródła - przy końcu pracy procesu albo przy wymianie planu - system usuwa sam plik wejściowy wskazany w deklaracji, deskryptor strumienia (`.desc`) oraz pliki metadanych (`.meta`, `.meta.shadow`), jeśli istnieją. Usunięcie nie zależy od końca danych ani od `ONESHOT`: również plik czytany w pętli zostanie usunięty przy zamknięciu, nawet jeśli nie został przeczytany do końca.

```rql
DECLARE temp INTEGER STREAM jednorazowy, 0.1 BINFILE 'temp.dat' DISPOSABLE ONESHOT
```

Połączenie `DISPOSABLE ONESHOT` jest przydatne dla tymczasowego wejścia jednorazowego, ale nie jest wymagane.

## HOLD

Plik jest otwierany przy starcie planu, ale fizyczny odczyt danych jest wstrzymany do pierwszego zapytania o dane tego strumienia - pobrania danych przez zapytanie albo przygotowania rekordu dla klienta (np. zapytanie Ad Hoc). Samo wyświetlenie planu nie zwalnia wstrzymania. Dopóki strumień nie zostanie odpytany, w systemie widoczne są wartości zerowe; pierwszy rekord pliku zostaje przeczytany w kolejnym kroku po zwolnieniu. Wstrzymanie jest jednorazowe - nie wraca, gdy odbiorcy znikną.

```rql
DECLARE rzadkie INTEGER STREAM opcjonalny, 1.0 BINFILE 'rzadkie.dat' HOLD
```

Zastosowanie: zachowanie początku nagrania do chwili pierwszego zapotrzebowania, np. na żądanie użytkownika przez `xqry`. Połączenie `ONESHOT HOLD` odtwarza plik raz, od chwili pierwszego zapytania.

## Tabela porównawcza

| Dyrektywa    | Pętla odczytu | Usuwa pliki przy zamknięciu | Opóźniony start odczytu |
| ------------ | :-----------: | :-------------------------: | :---------------------: |
| _(domyślnie)_| tak           | nie                         | nie                     |
| `ONESHOT`    | nie           | nie                         | nie                     |
| `DISPOSABLE` | tak           | tak                         | nie                     |
| `HOLD`       | tak           | nie                         | tak                     |

## Macierz opcji i rodzajów źródeł

| Opcja        | `BINFILE` | `TEXTFILE` | `DEVICE` |
| ------------ | :-------: | :--------: | :------: |
| `ONESHOT`    | tak       | tak        | nie      |
| `DISPOSABLE` | tak       | tak        | nie      |
| `HOLD`       | tak       | tak        | nie      |

`DEVICE` z którąkolwiek z tych dyrektyw jest błędem kompilacji z nazwą strumienia i opcji, np. `DECLARE s: DEVICE does not take HOLD`. Powody: żywe źródło nie ma początku, do którego można wrócić; wstrzymanie odczytu nie zatrzymuje producenta, tylko gromadzi zaległość; a `DISPOSABLE` usuwałby ścieżkę urządzenia albo FIFO, której cykl życia nie należy do czytnika.

Przestarzała forma `FILE` rozstrzygnięta jako `DEVICE` (ścieżka `/dev/...`) odrzuca `DISPOSABLE` i `HOLD`, a `ONESHOT` przyjmuje bez zmian - patrz [Forma przestarzała FILE](polecenie-declare.md#forma-przestarzała-file).
