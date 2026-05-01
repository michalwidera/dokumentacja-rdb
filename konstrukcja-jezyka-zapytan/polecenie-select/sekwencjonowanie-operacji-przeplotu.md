# Sekwencjonowanie operacji przeplotu

Przenalizujmy teraz operację przeplotu. Stwórzmy plik qplan2.rql o następującej treści:

```
DECLARE a BYTE STREAM A, 1 FILE 'data1.txt'
DECLARE a BYTE STREAM B, 2 FILE 'data2.txt'
SELECT * STREAM str1 FROM A#B
```

Oprócz znaku # zamiast znaku + w klauzuli from oba pliki się niczym nie różnią. Wywołajmy kompilację oraz program swirly. Plik graficzny prezentować się będzie następująco:

<figure><img src="../../.gitbook/assets/image (3) (1) (1).png" alt=""><figcaption><p>Rys. 5 Schemat kulkowy - operacja przeplotu</p></figcaption></figure>

Na Rys. 5 widać zmianę. Kulki strumienia str1 zostały równomiernie uporządkowane w czasie. Zdarzenia występujące w zadeklarowanych strumieniach danych wejściowych nie uległy zmianie. Uległa natomiast zmianie zasada budowy strumienia wynikowego str1.

Jeśli zajrzymy do wygenerowanego schematu tekstowego – zobaczymy że wartości czasowe również uległy zmianie:

```
% Minimum interval is 666ms
% Maximum interval is 2000ms
% Grid time is 333ms, divider:2
% Full cycle step count in grid is 6
```

Zachęcam do dalszego eksperymentowania z tym sposobem prezentacji zdefiniowanych operacji na seriach czasowych.
