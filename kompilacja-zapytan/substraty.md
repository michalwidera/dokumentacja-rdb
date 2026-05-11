---
description: Licencja poetica - jestem pierwszy to sobie wymyślam nazwy. Nie mam wyjścia.
---

# Substraty

O substratach, efemerydach i artefaktach wspomniałem w rozdziale dotyczącym architektury systemu. W tym przypadku przedstawię przykład.

Na początek chciałbym zwrócić uwagę na pewną własność wprowadzonych wyrażeń algebraicznych. W praktyce możemy zapisać dowolne wyrażenie, skompilować i przedstawić wzór na operacje na poszczególnych elementach serii czasowych umożliwiających uzyskanie pożądanego wyniku.

W praktyce w systemie realizuję wyłącznie operacje jedno lub dwuargumentowe. Przykładem operacji jednoargumentowych to przesunięcie w czasie lub operacja Agse. Tam argumentem jest tylko jeden strumień danych. Reszta operacji to operacje na dwóch strumieniach danych. W trakcie kompilacji wszystkie wyrażenia algebraiczne rozbijane są na takie, które mają dwa argumenty.

Zobaczmy to na przykładzie:

```
DECLARE a INTEGER STREAM core0, 0.1 FILE 'datafile1.txt'
DECLARE b INTEGER STREAM core1, 0.2 FILE '/dev/urandom'
DECLARE c INTEGER STREAM core2, 0.3 FILE 'datafile2.txt'

SELECT str1[0] STREAM str1 FROM (core0#core1)+core2
```

I przeprowadźmy kompilację:

```
$ xretractor -c query.rql
STREAM_HASH_core0_core1(1/15)
        :- PUSH_STREAM(core0)
        :- PUSH_STREAM(core1)
        :- STREAM_HASH
        a: INTEGER
                PUSH_ID(STREAM_HASH_core0_core1[0])
str1(1/15)
        :- PUSH_STREAM(STREAM_HASH_core0_core1)
        :- PUSH_STREAM(core2)
        :- STREAM_ADD
        str1_0: INTEGER
                PUSH_ID(str1[0])
core0(1/10)     datafile1.txt
        a: INTEGER
core1(1/5)      /dev/urandom
        b: INTEGER
core2(3/10)     datafile2.txt
        c: INTEGER
```

Przenalizujmy co tu się wydarzyło? Pojawił się niezapowiedziany strumień STREAM\_HASH\_core0\_core1. To jest właśnie wspomniany substrat. Strumień danych pojawiający się w wyniku kompilacji i wymogu przetwarzania operacji dwuargumentowych.

A co się stanie jak dołączymy zapytanie o treści?

```
SELECT str2[0] STREAM str2 FROM (core0#core1)>2
```

Tutaj zostanie dołączone do efektów kompilacji tylko jedno zapytanie:

```
str2(1/15)
        :- PUSH_STREAM(STREAM_HASH_core0_core1)
        :- STREAM_TIMEMOVE(2)
        str2_0: INTEGER
                PUSH_ID(str2[0])
```

Zastanawiasz się pewne dlaczego tylko jedno a nie ponownie dwa? Odpowiedź to optymalizacja. Korzystamy z pośrednich wyników poprzedniego. To jedna z nieoczekiwanych korzyści zastosowania RetractorDB.

Jest jeszcze jedna istotna rzecz o której należy wspomnieć w tym punkcie. Istnieje dyrektywa SUBSTRAT, której argumentem jest ciąg znaków ujęty w apostrofy. Można użyć następujących typów ‘memory’, ‘default’, ‘posix’, ‘generic’, ‘device’, ‘textsource’. Domyślny typ ‘default’ spowoduje, że substraty będą materializować się w całości na dysku. To nie jest oczekiwana wartość w systemie produkcyjnym, ale oczekiwana w trakcie rozwoju i debugowania. Typ użyteczny to ‘memory’. Substraty tego typu lądują tylko w pamięci. Ich dane nigdy nie lądują na dysku – wszystko odbywa się w pamięci, danych jest tylko tyle ile jest wymaganych do realizacji zapytań. Reszta typów na chwilę obecną jest nieprzetestowana i znajduje się w fazie rozwojowej.

Dodanie zapytania o tych samych operacjach, ale innej nazwie niż nazwa substratu niestety nie wygeneruje zapytania odwołującego się do substratu. Ta funkcjonalność znajduje się w planach rozwojowych.
