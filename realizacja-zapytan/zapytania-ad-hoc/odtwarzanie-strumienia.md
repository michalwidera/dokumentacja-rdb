# Odtwarzanie strumienia

Serie czasowe bardzo często rozumiemy jako dane oznaczone znacznikami czasowymi. Dane zachowane np. w pliku możemy dowolnie przetwarzać – zachowując ich kolejność w oparciu o zarejestrowane zależności czasowe. System RetractorDB został wyposażony w możliwość ponownego wyemitowania takiego strumienia zachowując zarejestrowane zależności czasowe, tak jakby faktycznie ponownie te dane napływały.

W celu przedstawienia przykładu przygotujmy plik tekstowy wypełniony danymi np. od 30 do 45.

```
$ seq 30 45 > dane.txt
```

Tak przygotowany plik będziemy odtwarzać w systemie RetractorDB.

W kolejnym kroku stwórzmy następujący plik wypełniony zapytaniami dla systemu – query.rql zawierający tylko jedną deklarację zakończoną HOLD.

```
DECLARE a INTEGER STREAM core, 1 FILE 'dane.txt' HOLD
```

Uruchamiamy w jednym oknie polecenie:

```
$ xretractor query.rql
```

W kolejnym wydajemy polecenie:

```
$ xqry -s core
0
0
0
…
```

Zobaczymy ciąg zer …

W kolejnym oknie wydajemy następujące polecenie:

```
$ xqry -a "SELECT * STREAM ping FROM core VOLATILE”
snd: adhoc SELECT * STREAM ping FROM core VOLATILE
rcv: db OK
```

&#x20;W tym momencie w oknie prezentującym wartości ze strumienia core pojawią się wartości core

```
$ xqry -s core
0
0
0
…
0
0
0
30
31
32
33
…
```

Nagrany przykład poniżej:

<figure><img src="../../.gitbook/assets/adhoc-example.svg" alt=""><figcaption><p>Rys. 33 Nagrany przykład odtwarzania strumienia</p></figcaption></figure>
