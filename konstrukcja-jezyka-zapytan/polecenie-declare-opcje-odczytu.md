---
description: ONESHOT, DISPOSABLE i HOLD sterują cyklem życia źródła danych.
---

# Opcje odczytu w DECLARE

Polecenie `DECLARE` przyjmuje trzy opcjonalne dyrektywy wpływające na sposób odczytu i cykl życia zadeklarowanego źródła:

```
DECLARE pole typ STREAM nazwa, szybkość FILE źródło
    [DISPOSABLE]
    [ONESHOT]
    [HOLD]
```

## ONESHOT

Bez `ONESHOT` źródło danych czytane jest w nieskończonej pętli — po osiągnięciu końca pliku pozycja odczytu wraca na początek. `ONESHOT` wyłącza pętlę: plik czytany jest dokładnie raz, a po jego wyczerpaniu strumień zwraca wartości zerowe lub puste.

```
DECLARE pomiar INTEGER STREAM burst, 0.1 FILE 'dane.dat' ONESHOT
```

Zastosowanie: jednorazowe załadowanie danych historycznych do systemu.

## DISPOSABLE

Po zakończeniu przesyłania danych ze źródła system usuwa plik danych, plik deskryptora (`.desc`) i plik metadanych (`.meta`). Dyrektywa działa przy destrukcji obiektu `storage`.

```
DECLARE temp INTEGER STREAM jednorazowy, 0.1 FILE 'temp.dat' ONESHOT DISPOSABLE
```

`DISPOSABLE` używa się razem z `ONESHOT` — dane wczytane raz, po wczytaniu usunięte. Kombinacja przydatna do tymczasowych plików danych wejściowych.

## HOLD

Zadeklarowane źródło nie inicjuje odczytu od razu po starcie systemu. Fizyczny odczyt danych uruchamia się dopiero przy pierwszym zapytaniu wymagającym danych z tego strumienia (np. zapytanie Ad Hoc). Dopóki strumień nie zostanie odpytany — w systemie widoczne są wartości zerowe lub puste.

```
DECLARE rzadkie INTEGER STREAM opcjonalny, 1.0 FILE 'rzadkie.dat' HOLD
```

Zastosowanie: źródła danych aktywowane warunkowo, np. na żądanie użytkownika przez `xqry`.

## Tabela porównawcza

| Dyrektywa    | Pętla odczytu | Usuwa pliki po odczycie | Opóźniony start odczytu |
| ------------ | :-----------: | :---------------------: | :---------------------: |
| _(domyślnie)_| tak           | nie                     | nie                     |
| `ONESHOT`    | nie           | nie                     | nie                     |
| `DISPOSABLE` | tak           | tak                     | nie                     |
| `HOLD`       | tak           | nie                     | tak                     |
