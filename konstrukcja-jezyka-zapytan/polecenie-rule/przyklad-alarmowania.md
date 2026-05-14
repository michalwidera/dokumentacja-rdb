# Przykład alarmowania

W oknie terminala uruchamiamy proces xretractor uruchamiając przedstawiony z początku rozdziału plik query.rql

```
$ xretractor query.rql
test
test
test
…
```

W drugim oknie terminala proponuję uruchomić polecenie:

```
$ xqry -s str4
27
28
20
21
22
23
24
25
26
27
```

Oba okna proponuję ustawić obok siebie. Zobaczymy, że pojawianie się wartości 20 i 23 powoduje uruchomienie akcji po stronie serwera wyświetlającej napis test. Należy pamiętać, że w systemie może pojawić się dowolne polecenie systemowe lub wywołanie dowolnego programu w zależności o tego co umieścimy w deklaracji DO SYSTEM.

Zapis sesji:

<figure><img src="../../.gitbook/assets/alarm-example.svg" alt=""><figcaption><p>Rys. 8 Zapis sesji przykładu alarmowania</p></figcaption></figure>

## Przykład 2: zapis kontekstu zdarzenia (DO DUMP)

Akcja `DO DUMP` pozwala utrwalić okno próbek z otoczenia zdarzenia — dane sprzed i po jego wystąpieniu. Jest to przydatne gdy chcemy zachować kontekst anomalii do późniejszej analizy.

Tworzymy plik `query.rql`:

```
STORAGE 'temp'

DECLARE a INTEGER STREAM core0, 1 FILE 'datafile1.txt'
SELECT str1[0] STREAM str1 FROM core0

RULE zapis_anomalii
ON str1
WHEN str1[0] > 24
DO DUMP -3 TO 3
```

Dane wejściowe — liczby od 20 do 28:

```
$ seq 20 28 > datafile1.txt
```

Uruchamiamy xretractor:

```
$ xretractor query.rql
```

Gdy wartość strumienia `str1` przekroczy 24, reguła wyzwoli zapis 6 rekordów (3 historyczne + 3 kolejne) do pliku binarnego `temp/str1_zapis_anomalii_dump.tmp`.

### Odczyt pliku zrzutu

Plik zrzutu nie zawiera nagłówka `.desc` — przy otwieraniu w `xtrdb` należy podać schemat ręcznie:

```
$ xtrdb
> storage temp
> open str1_zapis_anomalii_dump { INTEGER a }
> size
> list 6
> quit
```

## Przykład 3: rotacja zrzutów (DO DUMP z RETENTION)

Bez `RETENTION` każde kolejne wyzwolenie reguły nadpisuje ten sam plik. Gdy zdarzenia powtarzają się, użyj `RETENTION N` aby zachować ostatnie N zrzutów w osobnych plikach.

```
STORAGE 'temp'

DECLARE a INTEGER STREAM core0, 1 FILE 'datafile1.txt'
SELECT str1[0] STREAM str1 FROM core0

RULE zapis_anomalii
ON str1
WHEN str1[0] > 24
DO DUMP -3 TO 3 RETENTION 5
```

Każde wyzwolenie tworzy kolejny plik (rotacja cykliczna):

```
temp/str1_zapis_anomalii_dump_0.tmp
temp/str1_zapis_anomalii_dump_1.tmp
temp/str1_zapis_anomalii_dump_2.tmp
temp/str1_zapis_anomalii_dump_3.tmp
temp/str1_zapis_anomalii_dump_4.tmp
```

Po przekroczeniu pojemności (`RETENTION 5`) najstarszy plik jest nadpisywany przez nowy.

## Przykład 4: wiele reguł na jednym strumieniu

Do jednego strumienia można przypiąć dowolną liczbę reguł. Poniższy przykład łączy obie akcje — powiadomienie systemowe i zapis kontekstu:

```
STORAGE 'temp'

DECLARE a INTEGER STREAM core0, 1 FILE 'datafile1.txt'
SELECT str1[0] STREAM str1 FROM core0

RULE prog_dolny
ON str1
WHEN str1[0] < 21
DO SYSTEM 'echo "ALARM: wartosc ponizej progu dolnego" >> alarm.log'

RULE prog_gorny
ON str1
WHEN str1[0] > 26
DO SYSTEM 'echo "ALARM: wartosc powyzej progu gornego" >> alarm.log'

RULE zapis_kontekstu
ON str1
WHEN str1[0] > 26
DO DUMP -5 TO 5 RETENTION 10
```

Reguły `prog_gorny` i `zapis_kontekstu` reagują na ten sam warunek niezależnie — przekroczenie progu górnego jednocześnie zapisuje log i utrwala okno danych. Reguła `prog_dolny` obsługuje osobno próg dolny.

Wszystkie trzy reguły są ewaluowane przy każdej nowej próbce strumienia `str1`.
