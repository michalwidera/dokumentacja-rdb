---
description: To polecenie tworzy ulotne źródła prawdy - tzw. Efemerydy
---

# Polecenie DECLARE

Polecenie DECLARE służy do zadeklarowania źródła danych.

Jego składnia opisana jest następująco:

```
DECLARE pole typ[N] [, pole typ[N]]
STREAM nazwa, szybkość
FILE źródło
[DISPOSABLE]
[ONESHOT]
[HOLD]
```

## Typy pól

Każde pole ma nazwę i typ. Dostępne typy:

| Typ       | Rozmiar | Opis                               |
| --------- | ------- | ---------------------------------- |
| `BYTE`    | 1 B     | liczba całkowita bez znaku 8-bit   |
| `INTEGER` | 4 B     | liczba całkowita ze znakiem 32-bit |
| `UINT`    | 4 B     | liczba całkowita bez znaku 32-bit  |
| `FLOAT`   | 4 B     | liczba zmiennoprzecinkowa 32-bit   |
| `DOUBLE`  | 8 B     | liczba zmiennoprzecinkowa 64-bit   |
| `STRING`  | N B     | ciąg bajtów o stałej długości N    |

### Tablice pól (`typ[N]`)

Do każdego pola można dodać mnożnik tablicowy `[N]` — pole zajmuje `N × rozmiar_typu` bajtów i tworzy `N` kolejnych pozycji w schemacie rekordu:

```
DECLARE coef INTEGER[25]
STREAM filter, 1
FILE 'coefficients.txt'
```

Pole `coef INTEGER[25]` tworzy rekord o rozmiarze 25 × 4 = 100 bajtów i daje dostęp do indeksów `filter[0]` … `filter[24]`. Jest to standardowy sposób przekazywania tablic współczynników (np. filtry FIR) do systemu.

Wiele pól różnych typów można łączyć w jednym rekordzie:

```
DECLARE id UINT, wartosc FLOAT, nazwa STRING[16]
STREAM pomiar, 0.1
FILE 'czujnik.dat'
```

Rozmiar rekordu: 4 + 4 + 16 = 24 bajty.

System RetractorDB działając pod kontrolą systemu Linux pobiera i zapisuje dane do plików. W systemie Linux dostęp do większości zasobów jest realizowany za pomocą dostępu do różnego rodzaju plików. Takie rozwiązanie ujednolica sposób dostępu do danych.

Przykładem polecenia tworzącego w systemie RetractorDB obiekt zwracający wartości przypadkowe ze strumienia /dev/random 10 razy na sekundę o wartościach typu int wygląda następująco

```
DECLARE pole_przypadkowe INTEGER
STREAM random_stream, 0.1
FILE ‘/dev/random’
```

Wspominane w poleceniu źródło, jeśli zostanie zadeklarowane jako plik tekstowy z rozszerzeniem .txt zostanie zinterpretowane przez system jako ciągły i nieskończony plik danych czytany wiersz po wierszu. Po napotkaniu końca pliku, odczyt danych zaczyna się od początku. Ta funkcjonalność została wbudowana w system RetractorDB. Zapewnione jest podstawowe wsparcie dla formatu – jeśli podamy dwa pola całkowite w deklaracji a w pliku po spacji podamy dwie wartości całkowite – wartości te trafią jako kolejne elementy czytanego rekordu.

```
DECLARE pole_1 INTEGER
STREAM cykliczny_stream, 0.1
FILE ‘plik.txt’
```

Aby parsowanie pliku nastąpiło automatycznie, plik musi nosić rozszerzenie .txt. Na chwilę ta funkcjonalność została zaimplementowana na stałe i nie podlega parametryzacji. Planuję to zmienić w przyszłości.

Jeśli plik danych wejściowych będzie nosić rozszerzenie .dat – plik ten zostanie potraktowany jako plik binarny a odczyt danych z niego zostanie również zapętlony. Zapętlenie polega na tym że po przeczytaniu ostatniej wartości z pliku źródłowego, pozycja odczytu pliku kierowana jest na początek. Dane z takiego pliku czytane są w nieskończonej pętli, po zakończeniu wracając do początku.

Trzy opcjonalne dyrektywy (`ONESHOT`, `DISPOSABLE`, `HOLD`) sterują cyklem życia źródła danych — szczegółowy opis i tabela porównawcza znajdują się w rozdziale [Opcje odczytu](polecenie-declare-opcje-odczytu.md).

{% hint style="info" %}
Obsługa wartości NULL (per-pole) jest zaimplementowana w systemie RetractorDB. Metadane null przechowywane są w sidecar pliku `.meta` obok danych binarnych, zarządzanym przez klasę `metaDataStream`.
{% endhint %}
