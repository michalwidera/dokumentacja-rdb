---
description: To jest jedna z tych funkcji języka, na które się nie zwraca uwagi. Niedobrze.
icon: rotate
---

# Aliasowanie

W przypadku, w którym złączymy dwa strumienie danych operatorem sumy. Pojawi się nowy schemat danych. Do kolejnych wartości tego schematu możemy odwoływać się poprzez nazwę strumienia danych indeksowanych kolejno względem początku schematu.

Możemy jednak użyć też nazw z jakich strumień powstał. Na wartość wskazywać będzie nazwa strumienia wynikowego indeksowana względem początku schematu, jak również nazwa strumienia źródłowego przesunięta względem pozycji złączenia.

Przeanalizujmy następujące zapytanie:

```
DECLARE a INTEGER STREAM core0, 0.1 FILE 'datafile1.txt'
DECLARE b INTEGER STREAM core1, 0.2 FILE '/dev/urandom'

SELECT str1[0],str1[1],core0[0],core1[0]
STREAM str1
FROM core0+core1
```

Po kompilacji otrzymamy następujący wynik:

```
$ xretractor -c query.rql
str1(1/10)
        :- PUSH_STREAM(core0)
        :- PUSH_STREAM(core1)
        :- STREAM_ADD
        str1_0: INTEGER
                PUSH_ID(str1[0])
        str1_1: INTEGER
                PUSH_ID(str1[1])
        str1_2: INTEGER
                PUSH_ID(str1[0])
        str1_3: INTEGER
                PUSH_ID(str1[1])
core0(1/10)     datafile1.txt
        a: INTEGER
core1(1/5)      /dev/urandom
        b: INTEGER
```

Przeanalizujmy co zrobił kompilator. W zapytaniu poprosiliśmy o pierwsze pole wynikowego schematu danych. Otrzymaliśmy to o co prosiliśmy. W drugim polu schematu tak samo – drugie pole bez zmian zostało dostarczone. W trzecim polu prosimy o pole ze schematu, który bierze udział w operacji strumieniowej. Z core0\[0] kompilator zrobił str1\[0]. Podobna operacja nastąpiła z polem core1\[0]. Prosząc o nie kompilator dostarczył str1\[1]. A co, jeśli operacja strumieniowa zostanie zastąpiona #? Zachęcam do eksperymentów.
