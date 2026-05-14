---
icon: tree-deciduous
---

# Algorytm przeglądu drzewa zapytań

## Przegląd ogólny

Algorytm przeglądu drzewa zapytań realizowany jest przez dwa współpracujące komponenty: `dataModel` (logika przetwarzania) oraz `executorsm` (pętla czasowa i IPC). Przed wejściem w główną pętlę system wykonuje **krok zerowy**, po czym cyklicznie iteruje po minimalnym zbiorze interwałów czasowych.

```mermaid
flowchart TD
    A([Inicjalizacja]) --> B
    B["processZeroStep()\nTylko DECLARE: revRead(0) → fire()"] --> C
    C["TimeLine::getNextTimeSlot()\nWyznacz następny slot czasowy"] --> D
    D["getAwaitedStreamsSet()\nFiltruj: rInterval dzieli bieżący slot"] --> E
    E["dataModel::processRows(inSet)\nPrzebieg 1: nie-deklaracje → input → output → zapis\nPrzebieg 2: deklaracje → odblokowanie"] --> F
    F["broadcast(inSet)\nKolejki Boost IPC → klienci xqry"] --> C
```

_Rys. 26. Algorytm przeglądu drzewa zapytań – przegląd ogólny_

***

## Struktura danych: qTree

`qTree` (`src/retractor/lib/qTree.cpp`) rozszerza `std::vector<query>` i jest **wektorem topologicznie posortowanych zapytań**. Sortowanie odbywa się przez DFS po grafie zależności budowanym z `query.getDepStream()`.

```mermaid
graph TD
    A["A (DECLARE)\nrInterval=1/3"] --> B["B\nSELECT FROM A\nrInterval=1/3"]
    A --> D["D\nSELECT FROM A,B\nrInterval=1"]
    B --> C["C\nSELECT FROM B\nrInterval=1/2"]
    B --> D
```

_Rys. 27. Przykładowy graf zależności dla qTree_

Po sortowaniu topologicznym kolejność w wektorze: `[A, B, C, D]`. Zapytanie C zależne od B zawsze trafi po B w iteracji — gwarantuje poprawność obliczeń.

Metoda `getAvailableTimeIntervals()` wyodrębnia ze wszystkich zapytań unikalne wartości `rInterval` (z pominięciem dyrektyw kompilatora i wartości zerowych) — wynik to wejście do konstruktora `TimeLine`.

***

## Minimalna siatka czasowa: TimeLine / CRSMath

`TimeLine` (`src/retractor/lib/CRSMath.cpp`) zarządza racjonalnymi interwałami czasowymi. Konstruktor redukuje zbiór interwałów — usuwa wielokrotności, zachowując tylko koprimalne:

```
Wejście: {1/2, 1, 4}  →  Wyjście: {1/2}
(1 = 2 × 1/2, więc redundantne; 4 = 8 × 1/2, więc redundantne)

Wejście: {1/2, 1/3}  →  Wyjście: {1/2, 1/3}
(żadne nie jest wielokrotnością drugiego)
```

`getNextTimeSlot()` wyznacza kolejny slot jako `min(delta × counter[delta])` po wszystkich deltach. Poniższy diagram ilustruje sloty dla delt `{1/2, 1/3}` i aktywne zapytania w każdym z nich:

```mermaid
timeline
    title Sloty czasowe dla delt {1/2, 1/3}
    section t = 1/3
        B (rInterval=1/3)
    section t = 1/2
        C (rInterval=1/2)
    section t = 2/3
        B (rInterval=1/3)
    section t = 1
        B (rInterval=1/3) : C (rInterval=1/2) : D (rInterval=1)
    section t = 4/3
        B (rInterval=1/3)
    section t = 3/2
        C (rInterval=1/2)
```

_Rys. 28. Minimalna siatka czasowa dla delt {1/2, 1/3}_

Sprawdzenie `isThisDeltaAwaitCurrentTimeSlot(inDelta)` zwraca `true`, gdy `ctSlot_ / inDelta` ma mianownik równy 1 (slot jest całkowitą wielokrotnością delty zapytania).

***

## Krok zerowy: `processZeroStep()`

Przed wejściem w pętlę `executorsm::run()` wywołuje `processZeroStep()` (`dataModel.cpp`, linia \~85). Przetwarza **wyłącznie deklaracje** (strumienie wejściowe `DECLARE`):

```cpp
for (auto &q : coreInstance_) {
    if (!q.isDeclaration()) continue;
    qSet[q.id]->bufferState = flux;   // odblokuj odczyt fizyczny
    qSet[q.id]->revRead(0);           // wczytaj z indeksu 0
    qSet[q.id]->fire();               // przepisz chamber_ → outputPayload
    assert(qSet[q.id]->bufferState == armed);
}
```

Po tym kroku każda deklaracja ma `bufferState = armed` — dane z fizycznego źródła są w `outputPayload`.

***

## Główna pętla: filtrowanie i przetwarzanie

### Filtrowanie zapytań: `getAwaitedStreamsSet()`

Dla bieżącego slotu `tl` (`executorsm.cpp`, linia \~88):

```cpp
std::set<std::string> retVal;
for (auto &q : *coreInstancePtr)
    if (TimeLine::isThisDeltaAwaitCurrentTimeSlot(q.rInterval))
        retVal.insert(q.id);
return retVal;
```

Wynik `inSet` to identyfikatory zapytań aktywnych w tym slocie — podzbiór wszystkich zapytań.

### Przetwarzanie: `processRows(inSet)`

Funkcja wykonuje **dwa przejścia** przez `inSet` (`dataModel.cpp`, linia \~98):

```mermaid
flowchart TD
    S([processRows - inSet]) --> P1

    subgraph P1["Przebieg 1 — nie-deklaracje (kolejność topologiczna)"]
        direction TB
        X1["constructInputPayload()\nbuduje dane wejściowe z FROM"] --> X2
        X2["constructOutputPayload()\newaluuje wyrażenia SELECT"] --> X3
        X3["write()\nzapis na dysk / pamięć"] --> X4
        X4["constructRulesAndUpdate()\newaluuje klauzule RULE"]
    end

    P1 --> P2

    subgraph P2["Przebieg 2 — deklaracje (odblokowanie na następny slot)"]
        direction TB
        Y1{"bufferState\n== armed?"} -->|tak| Y2
        Y2["bufferState = flux\nodblokuj odczyt"] --> Y3
        Y3["revRead(0)\nodczytaj nowe dane"] --> Y4
        Y4["fire()\nprzypisz do outputPayload"]
        Y1 -->|nie| Y5([pomiń])
    end

    P2 --> E([koniec])
```

_Rys. 29. Algorytm processRows – dwa przejścia przetwarzania_

Deklaracje są odblokowywane dopiero po tym, jak wszystkie zależne zapytania skonsumowały ich `outputPayload` w przejściu 1.

***

## Rozgłaszanie wyników: `broadcast()`

Po każdym `processRows()` wywoływane jest `broadcast(inSet)` (`executorsm.cpp`, linia \~449):

```mermaid
flowchart TB
    A([inSet]) --> B["printRowValue()\nserializuj do Boost property_tree"]
    B --> C{klienci\nsubskrybujący\nstrumień?}
    C -->|tak| D["kolejka brcdbr&lt;id&gt;\ntry_send(dane)"]
    D --> E{kolejka\npełna?}
    E -->|nie| F([wysłano])
    E -->|tak - brak odbiorcy| G["usuń kolejkę\nusuń id2StreamName_"]
    C -->|brak| H([pomiń])
```

_Rys. 30. Algorytm broadcast – rozsyłanie wyników przez Boost IPC_

`printRowValue()` buduje strukturę z nazwą strumienia, liczbą pól, wartościami i bitmapą null, zapisuje jako Boost info format i wysyła przez `boost::interprocess::message_queue`.

***

## Pełny przykład: zapytania A, B, C, D dla delt {1/2, 1/3}

```mermaid
sequenceDiagram
    participant TL as TimeLine
    participant ES as executorsm
    participant DM as dataModel
    participant IPC as Boost IPC

    ES->>DM: processZeroStep()
    DM->>DM: A: revRead(0) → fire() [armed]
    ES->>IPC: broadcast({A})

    TL-->>ES: nextSlot = 1/3
    ES->>DM: processRows({B})
    DM->>DM: Przebieg 1: B → input(A) → output → write()
    DM->>DM: Przebieg 2: A → flux → revRead(0) → fire()
    ES->>IPC: broadcast({B})

    TL-->>ES: nextSlot = 1/2
    ES->>DM: processRows({C})
    DM->>DM: Przebieg 1: C → input(B) → output → write()
    DM->>DM: Przebieg 2: A → flux → revRead(0) → fire()
    ES->>IPC: broadcast({C})

    TL-->>ES: nextSlot = 2/3
    ES->>DM: processRows({B})
    DM->>DM: Przebieg 1: B → input(A) → output → write()
    DM->>DM: Przebieg 2: A → flux → revRead(0) → fire()
    ES->>IPC: broadcast({B})

    TL-->>ES: nextSlot = 1
    ES->>DM: processRows({B, C, D})
    DM->>DM: Przebieg 1 (topologicznie): B → C → D
    DM->>DM: Przebieg 2: A → flux → revRead(0) → fire()
    ES->>IPC: broadcast({B, C, D})
```

_Rys. 31. Pełny przykład wykonania dla zapytań A, B, C, D przy deltach {1/2, 1/3}_

Drzewo zależności determinuje kolejność przejścia 1. Interwały czasowe z algebry Beatty'ego wyznaczają, które węzły drzewa są aktywne w danym slocie.
