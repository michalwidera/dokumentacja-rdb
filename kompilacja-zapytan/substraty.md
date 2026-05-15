---
description: Licencja poetica - jestem pierwszy to sobie wymyślam nazwy. Nie mam wyjścia.
icon: trash-can
---

# Substraty

O substratach, efemerydach i artefaktach wspomniałem w rozdziale dotyczącym architektury systemu. W tym przypadku przedstawię przykład.

Na początek chciałbym zwrócić uwagę na pewną własność wprowadzonych wyrażeń algebraicznych. W praktyce możemy zapisać dowolne wyrażenie, skompilować i przedstawić wzór na operacje na poszczególnych elementach serii czasowych umożliwiających uzyskanie pożądanego wyniku.

W praktyce w systemie realizuję wyłącznie operacje jedno lub dwuargumentowe. Przykładem operacji jednoargumentowych to przesunięcie w czasie lub operacja Agse. Tam argumentem jest tylko jeden strumień danych. Reszta operacji to operacje na dwóch strumieniach danych. W trakcie kompilacji wszystkie wyrażenia algebraiczne rozbijane są na takie, które mają dwa argumenty.

Przykład używa kanonicznych deklaracji z całego rozdziału — trzy strumienie o różnych typach i interwałach:

```
DECLARE a BYTE, b INTEGER
STREAM core0, 0.1
FILE 'sensor_a.txt'

DECLARE c INTEGER, d FLOAT
STREAM core1, 0.2
FILE 'sensor_b.txt'

DECLARE e INTEGER
STREAM core2, 0.3
FILE 'sensor_c.txt'

SELECT merged[0]
STREAM merged
FROM (core0 # core1) + core2
```

Kompilacja:

```
$ xretractor -c query.rql
STREAM_HASH_core0_core1(1/15)
        :- PUSH_STREAM(core0)
        :- PUSH_STREAM(core1)
        :- STREAM_HASH
        a: BYTE
                PUSH_ID(STREAM_HASH_core0_core1[0])
        b: INTEGER
                PUSH_ID(STREAM_HASH_core0_core1[1])
        c: INTEGER
                PUSH_ID(STREAM_HASH_core0_core1[2])
        d: FLOAT
                PUSH_ID(STREAM_HASH_core0_core1[3])
merged(1/15)
        :- PUSH_STREAM(STREAM_HASH_core0_core1)
        :- PUSH_STREAM(core2)
        :- STREAM_ADD
        merged_0: BYTE
                PUSH_ID(merged[0])
core0(1/10)     sensor_a.txt
        a: BYTE
        b: INTEGER
core1(1/5)      sensor_b.txt
        c: INTEGER
        d: FLOAT
core2(3/10)     sensor_c.txt
        e: INTEGER
```

Pojawił się niezapowiedziany strumień `STREAM_HASH_core0_core1` — to właśnie substrat. Kompilator rozbił `(core0 # core1) + core2` na dwie operacje dwuargumentowe i wstawił pośredni strumień. Delta substratu: Δ = (1/10 · 1/5) / (1/10 + 1/5) = 1/15.

Co się stanie po dołączeniu zapytania:

```
SELECT merged2[0] STREAM merged2 FROM (core0 # core1) > 2
```

Do planu dołączone zostanie tylko jedno nowe zapytanie:

```
merged2(1/15)
        :- PUSH_STREAM(STREAM_HASH_core0_core1)
        :- STREAM_TIMEMOVE(2)
        merged2_0: BYTE
                PUSH_ID(merged2[0])
```

Zastanawiasz się pewne dlaczego tylko jedno a nie ponownie dwa? Odpowiedź to optymalizacja. Korzystamy z pośrednich wyników poprzedniego. To jedna z nieoczekiwanych korzyści zastosowania RetractorDB.

Jest jeszcze jedna istotna rzecz o której należy wspomnieć w tym punkcie. Istnieje dyrektywa SUBSTRAT, której argumentem jest ciąg znaków ujęty w apostrofy. Można użyć następujących typów ‘memory’, ‘default’, ‘direct’, ‘posix’, ‘posixshd’, ‘generic’, ‘device’, ‘textsource’. Pełny opis każdego typu znajdziesz w rozdziale [Typy STORAGE](../konstrukcja-jezyka-zapytan/polecenie-select/typy-storage.md). Domyślny typ ‘default’ spowoduje, że substraty będą materializować się w całości na dysku. To nie jest oczekiwana wartość w systemie produkcyjnym, ale oczekiwana w trakcie rozwoju i debugowania. Typ użyteczny to ‘memory’. Substraty tego typu lądują tylko w pamięci. Ich dane nigdy nie lądują na dysku – wszystko odbywa się w pamięci, danych jest tylko tyle ile jest wymaganych do realizacji zapytań. Reszta typów na chwilę obecną jest nieprzetestowana i znajduje się w fazie rozwojowej.

Dodanie zapytania o tych samych operacjach, ale innej nazwie niż nazwa substratu niestety nie wygeneruje zapytania odwołującego się do substratu. Ta funkcjonalność znajduje się w planach rozwojowych.

## Redukcja substratów

Kompilator realizuje optymalizację zwaną **redukcją substratów** (funkcja `deduplicateSubstrats`). Polega ona na tym, że jeśli użytkownik zdefiniował zapytanie strukturalnie identyczne z wygenerowanym substratem, substrat jest usuwany z planu, a jego odwołania zastępowane są nazwą zapytania użytkownika.

### Warunki redukcji

Redukcja substratu do zapytania użytkownika następuje wtedy i tylko wtedy, gdy spełnione są jednocześnie trzy warunki:

1. **Ten sam schemat** — typy i nazwy pól wyjściowych są identyczne.
2. **Ta sama delta** — częstotliwość próbkowania strumieni jest taka sama.
3. **Te same operacje przetwarzania** — sekwencja instrukcji `PUSH_STREAM` / `STREAM_TIMEMOVE` / `STREAM_HASH` itp. jest identyczna.

### Przykład redukcji

Rozważmy zapytanie z kanonicznymi deklaracjami:

```
DECLARE a BYTE, b INTEGER   STREAM core0, 0.1 FILE 'sensor_a.txt'
DECLARE c INTEGER, d FLOAT  STREAM core1, 0.2 FILE 'sensor_b.txt'

SELECT merged[0] STREAM merged FROM (core0 > 2) + core1
SELECT shifted[0] STREAM shifted FROM core0 > 2
```

Bez redukcji kompilator wygenerowałby trzy strumienie: substrat `STREAM_TIMEMOVE_core0`, `merged` i `shifted`. Substrat i `shifted` mają identyczną strukturę — ten sam strumień źródłowy `core0` i tę samą operację `>2`. Po redukcji substrat jest usuwany, a odwołanie `PUSH_STREAM(STREAM_TIMEMOVE_core0)` w `merged` zostaje zastąpione przez `PUSH_STREAM(shifted)`:

```
merged(1/10)
        :- PUSH_STREAM(shifted)
        :- PUSH_STREAM(core1)
        :- STREAM_ADD
        merged_0: BYTE
                PUSH_ID(merged[0])
shifted(1/10)
        :- PUSH_STREAM(core0)
        :- STREAM_TIMEMOVE(2)
        shifted_0: BYTE
                PUSH_ID(shifted[0])
core0(1/10)     sensor_a.txt
        a: BYTE
        b: INTEGER
core1(1/5)      sensor_b.txt
        c: INTEGER
        d: FLOAT
```

### Ważne ograniczenie: tylko substraty są redukowane

Redukcja dotyczy wyłącznie substratów wygenerowanych przez kompilator (`isSubstrat = true`). Zapytania zdefiniowane jawnie przez użytkownika **nigdy** nie są redukowane, nawet jeśli dwa z nich mają identyczną strukturę.

Przykład — dwa zapytania użytkownika o tej samej operacji:

```
DECLARE a BYTE, b INTEGER   STREAM core0, 0.1 FILE 'sensor_a.txt'

SELECT shifted1[0] STREAM shifted1 FROM core0 > 2
SELECT shifted2[0] STREAM shifted2 FROM core0 > 2
```

Wynik kompilacji zachowa oba strumienie bez żadnej redukcji:

```
shifted1(1/10)
        :- PUSH_STREAM(core0)
        :- STREAM_TIMEMOVE(2)
        shifted1_0: BYTE
                PUSH_ID(shifted1[0])
shifted2(1/10)
        :- PUSH_STREAM(core0)
        :- STREAM_TIMEMOVE(2)
        shifted2_0: BYTE
                PUSH_ID(shifted2[0])
core0(1/10)     sensor_a.txt
        a: BYTE
        b: INTEGER
```

Semantyczna decyzja jest tu celowa: użytkownik zadeklarował dwa odrębne strumienie wynikowe i oba mają prawo istnieć niezależnie w planie wykonania.
