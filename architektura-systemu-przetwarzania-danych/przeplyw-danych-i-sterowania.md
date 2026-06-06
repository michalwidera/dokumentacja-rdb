# Przepływ danych i sterowania

Dane i sterowanie w systemie RetractorDB tworzą kilka potencjalnych sposobów użycia komponentów systemu. Na Rys. 10 przedstawiono schematycznie przepływ danych pomiędzy procesami systemu RetractorDB, procesami systemu Linux oraz danymi źródłowymi i rezultatami pracy poszczególnych procesów.

Najgrubsze linie przedstawiają przepływ, który występuje zawsze w procesie przetwarzania regularnych serii czasowych. Proces xretractor aby wystartować na chwilę obecną potrzebuje pliku .rql ze sekwencją zapytań. Po przeprowadzeniu kompilacji, proces xretractor buduje drzewo planu zapytania i rozpoczyna proces przetwarzania napływających danych i tworzenia plików binarnych zawierających artefakty.

> **_NOTE:_** Opisana funkcjonalność ma pokrycie w teście: `consistency` opisanym w załączniku pt. [Testy Integracyjne](../zalaczniki/testy-integracyjne.md).

Aby móc sterować procesem xretractor po wystartowaniu używamy procesu xqry. Za jego pomocą możemy zatrzymać proces xretractor, pobrać statystyki lub zażądać dostępu do danych bieżących.

Reszta strzałek prezentuje przepływy danych zależne od prowadzonego z użyciem RetractorDB procesu. Strzałki przerywane są typowo przeznaczone do celów diagnostycznych.

Każdy z procesów na schemacie został oznaczony dodatkowo liczbą utrzymywanych ciągłych procesów w systemie. Oznaczenie „1” przy procesie xretractor oznacza że ten program będzie pilnował aby tylko jedna instancja tego procesu funkcjonowała w systemie. Próba uruchomienia kolejnej zakończy się błędem i komunikatem przy uruchomieniu. Program xtrdb nie utrzymuje żadnych ciągłych i nieskończonych procesów. Czyta dane, przetwarza, zwraca wyniki i kończy pracę. Oferuje też opcję pracy w trybie interaktywnym. Proces xqry oznaczony został jako „N”. W ten sposób chciałem wyrazić że procesów xqry można wywoływać więcej niż jeden. Jest to typowy scenariusz pracy z systemem RetractorDB. Klientów komunikujących się z procesorem planów realizacji zapytań z definicji występuje kilka.

<figure><img src="../assets/przeplyw_danych_i_sterowania.svg" width="100%" alt=""><figcaption><p>Rys. 10. Przepływ danych i sterowania</p></figcaption></figure>

## Zatrzymanie xretractor

Proces xretractor obsługuje sygnały systemowe i kończy pracę w kontrolowany sposób po otrzymaniu:

| Sygnał    | Polecenie          | Znaczenie                             |
| --------- | ------------------ | ------------------------------------- |
| `SIGINT`  | Ctrl+C w terminalu | przerwanie interaktywne               |
| `SIGTERM` | `kill <pid>`       | standardowe zakończenie procesu       |
| `SIGHUP`  | `kill -HUP <pid>`  | zakończenie przy zamknięciu terminala |

Wszystkie trzy sygnały powodują ten sam efekt: graceful shutdown — pętla przetwarzania kończy bieżący cykl i zatrzymuje się. Pozwala to bezpiecznie zamknąć xretractor działającego jako usługa bez ryzyka uszkodzenia plików artefaktów.

### Zatrzymanie przez xqry

Obok sygnałów systemowych xretractor można zatrzymać programowo — za pomocą polecenia:

```bash
xqry --kill
```

#### Jak przebiega zamknięcie krok po kroku

**1. xqry wysyła żądanie „kill"**

Proces xqry buduje komunikat IPC i umieszcza go w kolejce komunikatów `RetractorQueryQueue` — wspólnym kanale łączącym wszystkich klientów z xretractor. Wiadomość zawiera identyfikator procesu xqry (PID) i polecenie `kill`.

**2. xretractor odbiera polecenie i ustawia flagę zatrzymania**

Wątek komunikacyjny xretractor (`commandProcessorLoop`) stale nasłuchuje na `RetractorQueryQueue`. Po odebraniu komunikatu `kill` ustawia atomową zmienną `iTimeLimitCnt` na wartość `stop_now`. Ten sam mechanizm jest używany przez obsługę sygnałów systemowych — niezależnie od źródła (sygnał `SIGINT`/`SIGTERM`/`SIGHUP` lub polecenie xqry `--kill`) efekt jest identyczny.

**3. Główna pętla przetwarzania wykrywa flagę i kończy bieżący cykl**

Pętla główna sprawdza `iTimeLimitCnt` przy każdej iteracji. Gdy wykryje wartość `stop_now`, kończy bieżący cykl i wychodzi z pętli — bez przerywania w połowie obliczeń. Zapewnia to integralność zapisywanych artefaktów.

**4. xretractor powiadamia wszystkich podłączonych klientów (broadcast OOB)**

Po wyjściu z pętli xretractor wywołuje `boradcastOutOfBussiness()`. Funkcja ta przegląda wewnętrzną mapę `id2StreamName_Relation`, która zawiera wpis dla każdego procesu xqry subskrybującego strumień danych (każde wywołanie `xqry --select` rejestruje się w tej mapie przez polecenie `show`). Dla każdego zarejestrowanego klienta xretractor wysyła do jego dedykowanej kolejki komunikat specjalny o wartości `OUT_OF_BUSSINESS`.

**5. Każdy klient xqry odbiera sygnał zakończenia i kończy działanie**

Każdy działający proces xqry ma własną, indywidualną kolejkę komunikatów o nazwie `brcdbr<PID>`. Po odebraniu komunikatu `OUT_OF_BUSSINESS` xqry ustawia wewnętrzną flagę `done` i kończy działanie w kontrolowany sposób — niezależnie od tego, ile danych zdążył odebrać.

**6. Sprzątanie zasobów IPC**

Na zakończenie xretractor usuwa wszystkie współdzielone zasoby IPC: segment pamięci współdzielonej `RetractorShmemMap`, kolejkę poleceń `RetractorQueryQueue`, mutex `RetractorMapMutex` oraz indywidualne kolejki wszystkich klientów.

#### Co się dzieje przy wielu procesach xqry

RetractorDB jest zaprojektowany do pracy z wieloma równoległymi klientami. Gdy w systemie działają jednocześnie — powiedzmy — trzy procesy xqry subskrybujące różne strumienie, a jeden z nich wywoła `xqry --kill`:

- xretractor przetworzy żądanie kill **jednorazowo**, niezależnie od tego, który klient je wysłał,
- mechanizm `boradcastOutOfBussiness()` roześle komunikat `OUT_OF_BUSSINESS` do **wszystkich** zarejestrowanych klientów jednocześnie,
- każdy z trzech procesów xqry otrzyma sygnał zakończenia i zakończy działanie samodzielnie,
- klienci, którzy nie subskrybowali żadnego strumienia (np. xqry wywołany tylko z `--dir` lub `--hello`), nie są wpisani do mapy i nie muszą być powiadamiani — te polecenia kończą działanie natychmiast po udzieleniu odpowiedzi.

Warto zwrócić uwagę, że xqry wykrywa również nieaktywność serwera: jeżeli przez 10 sekund nie napłyną żadne dane, klient sam się wyłącza z ostrzeżeniem w logu. Jest to zabezpieczenie na wypadek nagłej awarii xretractor bez możliwości rozesłania komunikatu OOB.

