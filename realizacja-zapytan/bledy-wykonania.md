# Błędy wykonania

Ten rozdział opisuje diagnostykę uruchamiania i wykonywania planu, dostępu do danych, magazynów, reguł oraz komunikacji `xretractor`, `xqry` i `xtrdb`. Obejmuje także opróżnianie i ponowne użycie kolejek odpowiedzi. Błędy zapisu RQL opisuje osobny rozdział [Błędy składni i kompilacji](../konstrukcja-jezyka-zapytan/bledy-skladni-i-kompilacji.md). Poprawna kompilacja nie potwierdza dostępności źródeł, miejsca na dysku, pamięci dzielonej ani uprawnień potrzebnych podczas pracy.

W tabelach podano charakterystyczne fragmenty komunikatów. Nazwy, PID, rozmiary i przyczyny systemowe są uzupełniane podczas wykonania. Ten sam objaw klienta, np. timeout, może mieć kilka przyczyn; właściwe rozpoznanie wymaga także dziennika serwera.

## Jak ustalić skutek błędu

Zachowaj pełny komunikat, kod zakończenia, nazwę instancji, plan i wynik `xretractor --build-info`. Sprawdź dziennik instancji oraz klienta z tego samego czasu. Poza usługą logi powstają w katalogu tymczasowym procesu; efektywną lokalizację wskazuje program. Dla jednostki systemd sprawdź również jej dziennik, np. `journalctl -u xretractor.service`.

| Sytuacja | Reakcja systemu | Dalsze postępowanie |
| --- | --- | --- |
| Odmowa planu przed uruchomieniem, np. niezgodny zachowany deskryptor | `EPROTO` (`71` na Linuksie). W jednostce systemd odmowa startu opróżnia plik planu usługi. | Popraw plan lub jego zachowane pliki, potem dostarcz go ponownie. |
| Błąd środowiska, np. brak źródła albo błąd I/O magazynu | Zwykle `EIO` (`5` na Linuksie); podczas wykonania `FATAL (environment):` lub `Engine error (IOError)`. Plik planu usługi pozostaje zachowany. | Napraw dostęp, pojemność lub nośnik przed ponownym startem. |
| Błąd zwrócony przez silnik w slocie, inny niż I/O | `FATAL:` i `Engine error (...)`; proces kończy się kodem `1`, a jednostka próbuje opróżnić plik planu. Dotyczy także zwróconego `EvalError`. | Zachowaj przyczynę i minimalny przykład; sprawdź typy i ograniczenia opisane niżej. |
| Wyjątek Boost.Interprocess, który opuścił pętlę wykonania | `IPC::interprocess exception`, kod `ECHILD`. | Sprawdź wcześniejszy komunikat IPC, zasoby i zgodność wersji. |
| Nieoczekiwany wyjątek standardowy w pętli wykonania | `IPC Fail.` i przyczyna; kod `EINTR`, ze ścieżką opróżniania planu jednostki. | Sam przedrostek nie dowodzi awarii transportu; przyczyną może być np. brak pamięci. Zachowaj pełną diagnostykę. |
| Odmowa resetu, ad hoc albo subskrypcji przed przyjęciem | Błąd wraca do klienta; dotychczasowy plan może dalej działać. | Usuń przyczynę i świadomie ponów polecenie. |
| Obsłużone ostrzeżenie albo błąd lokalny, np. uszkodzona kolejka jednego klienta lub nieudany `SYSTEM` | Reakcja zależy od operacji; sam poziom ERROR nie oznacza zakończenia procesu. | Ustal z odpowiedniej sekcji, czy utracono rekord, subskrypcję, zapis czy całe wykonanie. |

W standardowym Release makra `SPDLOG_WARN` są wycinane przy kompilacji, a ERROR i CRITICAL pozostają. Dotyczy to m.in. ostrzeżeń o danych źródłowych, ustawieniach RT i puli kolejek. Część komunikatów RT jest wypisywana bezpośrednio na stdout także w Release. Brak ostrzeżenia w logu nie potwierdza poprawności danych ani dotrzymania terminów. Szczegóły polityki usługi opisuje [odmowa planu a awaria środowiska](../zalaczniki/opcje-wywolania/xretractor.md#odmowa-planu-a-awaria-środowiska).

Po SIGABRT albo OOM kill proces nie wykona zwykłego sprzątania. Aktualna jednostka systemd uruchamia `xretractor-stop-post`, który próbuje opróżnić plan i raportuje `cleared plan after ...` albo `cannot clear plan after ...`. Ta ochrona wymaga zainstalowanej jednostki i pomocnika. Sprawdź dziennik jednostki, limity pamięci i przyczynę abortu; sam restart nie usuwa przyczyny. Plik planu operatora uruchamiającego program poza jednostką nie jest opróżniany przez tę politykę.

## Konfiguracja, blokady i kolizje instancji

| Komunikat lub objaw | Przyczyna i reakcja | Jak usunąć przyczynę i zapobiegać |
| --- | --- | --- |
| `Configuration error:` z plikiem TOML lub nazwą klucza | Niedostępna lub wadliwa konfiguracja, błędny katalog albo niedopuszczalne ustawienie; program odmawia pracy. | Sprawdź wszystkie ładowane warstwy konfiguracji oraz dostęp z konta usługi. Popraw wskazany klucz; nie polegaj wyłącznie na konfiguracji użytkownika uruchamiającego klienta. |
| `Invalid config ... Using default ...` | Niektóre wartości liczbowe są zastępowane domyślnymi; to ostrzeżenie, nie ogólna polityka tolerowania wadliwego TOML. | Ustaw poprawną wartość jawnie. Wadliwe `storage.default_retention` pozostawia strumienie bez tej domyślnej retencji; błędne `sources.timeout_s` powoduje odmowę startu. |
| `cannot acquire lock`, `IPC identity lock ... is held`, `is already running` | Inna instancja trzyma blokadę lub żywy wpis magistrali ma tę samą tożsamość; nowy proces nie przejmuje jej zasobów. | Użyj innej nazwy i rozłącznych zasobów albo poprawnie zatrzymaj właściciela. Zmiana `TMPDIR` lub katalogu blokad nie rozdziela jawnie tej samej tożsamości IPC. |
| `Stream ... is already served`, `Storage file ... is already written`, `Rotation counter file ... is already used` | Plan koliduje z zasobami innej instancji; start, dostarczenie lub zmiana planu dostają odmowę. | Rozdziel nazwy strumieni, zapisywane pliki i licznik rotacji. Sama inna nazwa procesu nie wystarcza. |
| Odmowa kontroli pliku blokady: typ, właściciel, dowiązania, błąd systemowy | Nie można bezpiecznie potwierdzić wyłączności. | Sprawdź właściciela i katalog blokad; użyj zwykłego pliku zgodnego z wymaganiami. Nie usuwaj blokady działającego procesu. |
| `CRITICAL ERROR: Lost service lock!` | Instancja utraciła sprawdzaną blokadę i kończy pracę. | Sprawdź usuwanie lub podmianę plików przez administratora i narzędzia czyszczące; zachowaj tożsamość blokady przez całe życie procesu. |

Pusty plan usługi i odpowiedź `no active plan` są poprawnym stanem bezczynnym. Plan zawierający wyłącznie dyrektywy może natomiast dotrzeć do wykonania i dać `plan holds no streams - only directives`; dodaj rzeczywisty strumień. Zasady nazw i blokad opisuje [Wiele instancji i magistrala](../architektura-systemu-przetwarzania-danych/wiele-instancji-i-magistrala.md).

## Źródła, katalog magazynu i deskryptory

| Fragment diagnostyki | Scenariusz i skutek | Zalecane działanie |
| --- | --- | --- |
| `source file does not exist`, `cannot inspect source`, `cannot read source`, `cannot open TEXTFILE source` | Plik zniknął, nie jest zamontowany albo konto procesu nie ma dostępu. Kontrola przed startem daje błąd środowiska i nie usuwa poprzednich wyników. | Przygotuj źródła przed startem; sprawdź ścieżkę i prawo przejścia przez katalogi z konta usługi. Samo `-c` nie sprawdza dostępności wejścia. |
| Niezgodny rodzaj źródła `BINFILE`, `TEXTFILE` lub `DEVICE` | Zwykły plik, FIFO i urządzenie znakowe nie są wymienne. Plan lub rzeczywiście otwarty obiekt zostaje odrzucony. | Dla pliku wybierz `BINFILE` albo `TEXTFILE`; dla FIFO lub urządzenia znakowego `DEVICE`. Kontroluj typ obiektu, który tworzy producent. |
| `storage: directory ... does not exist`, `is not a directory` | Katalog z `STORAGE` nie istnieje albo ścieżka wskazuje inny obiekt; to odmowa planu, także przy strumieniach MEMORY. | Utwórz katalog przed startem i ustaw właściwe uprawnienia. Silnik nie tworzy go na podstawie dyrektywy. |
| `cannot open output file`, `cannot inspect output file` | Brak dostępu, katalog zamiast pliku, dowiązanie symboliczne w końcowym komponencie lub zmiana ścieżki po kontroli. | Sprawdź konto, montowanie i wolne miejsce; używaj właściwych zwykłych plików. Ochrona `O_NOFOLLOW` dotyczy końcowej nazwy, nie całego łańcucha katalogów. |
| `descriptor schema mismatch`, błędny/pusty `.desc`, nieobsługiwany `TYPE` lub niezgodny `REF` | Zachowany deskryptor opisuje inny rekord, źródło albo profil magazynu. Odmowa chroni przed interpretacją danych z obcym schematem. | Przywróć zgodny plan i rodzinę plików. Rozpoczęcie nowego magazynu po archiwizacji starych danych musi być świadomą decyzją. Nie poprawiaj samego `.desc` tak, aby ukryć różnicę formatu bajtów. |
| Odmowa zapisywalnego `REF` poza dozwolonymi katalogami | Deskryptor kieruje zapis poza katalog magazynu i `storage.ref_dirs`. | Popraw `REF` albo jawnie skonfiguruj zaufany katalog. Zewnętrzne źródło tylko do odczytu ma inny kontrakt. |

Kontrola wstępna nie rezerwuje ścieżek na przyszłość. Zmiana katalogu lub praw po przyjęciu resetu może ujawnić błąd dopiero przy budowie nowego modelu. Szczegóły: [Pliki magazynu](../architektura-systemu-przetwarzania-danych/format-zapisu-danych/pliki.md), [DECLARE](../konstrukcja-jezyka-zapytan/polecenie-declare.md) i [Zapytania ad hoc](zapytania-ad-hoc.md).

## Niepoprawne dane, brak wejścia i wartości NULL

| Komunikat lub objaw | Reakcja wykonania | Jak zapobiegać |
| --- | --- | --- |
| `invalid numeric token ... read as NULL` | Niepoprawna liczba w TEXTFILE staje się NULL. Błąd jednego elementu tablicy oznacza NULL całego pola deskryptora. Ostrzeżenie podaje plik, rekord, pole i token, tylko dla pierwszego takiego przypadku danego akcesora. | Waliduj cały token i zakres typu przed zapisaniem źródła; sprawdź m.in. ujemne UINT, BYTE ponad 255, nadmiarowe znaki, `inf` i `nan`. Popraw wszystkie wadliwe rekordy, nie tylko pierwszy zgłoszony. |
| `Read failure from declared source ... Returning null row.` | Po błędzie odczytu innym niż błąd treści EILSEQ bufor przekazuje rekord i mapę NULL zwrócone przez akcesor; nie zatrzymuje z tego powodu całego wykonania. Ostrzeżenie pojawia się raz na źródło. | Sprawdź wcześniejszą diagnostykę źródła, producenta i nośnik. Uruchomienie wymagało dostępnego źródła; późniejsze wartości NULL nie oznaczają, że brak pliku przy starcie jest dozwolony. |
| `DEVICE ... no writer (end of file)`, `read failed ... due records are all-null` | Brak producenta lub błąd odczytu urządzenia daje NULL w należnych rekordach. Powrót danych jest raportowany jako `data resumed`. | Uruchom producenta, sprawdź połączenie i dobierz `TIMEOUT` lub `sources.timeout_s` do rzeczywistego czasu dostarczania rekordów. Akcesor nie otwiera automatycznie nowego obiektu podstawionego pod tę samą ścieżkę. |
| `writer left after ... bytes ... incomplete record dropped` | Producent zamknął urządzenie po części rekordu; ta część jest odrzucana. | Zapisuj pełne rekordy binarne zgodne ze schematem i kontroluj błędy oraz krótkie zapisy producenta. |
| `awaitRecords: poll failed ... no further wait in this slot` | W tym slocie nie będzie dalszego czekania na urządzenia; dostępność danych oceniają ich akcesory. | Sprawdź przyczynę systemową i stan deskryptorów urządzeń. Zwiększenie timeoutu nie naprawia błędu `poll`. |

Koniec pliku przy `--until-eof` jest normalnym zakończeniem na pierwszym wyczerpanym źródle. Bez tej opcji pliki są czytane z zawijaniem; pusty plik tekstowy w pętli daje błąd odczytu i rekordy NULL. Oczekiwanie na ogon początkowy operatora może oznaczać brak emisji, a nie awarię. Również wynik NULL, np. przy dzieleniu przez zero, nie jest sam w sobie błędem zatrzymującym proces. Trzeba odróżnić go od zwróconego `EvalError`.

## Błędy obliczeń i stanu wewnętrznego

`Operator ... not defined for ...`, `math functions require numeric operand`, `toLogicValue: ... not supported`, `aggregation not supported for this field type` oznaczają operację niedostępną dla danych typów. Jeżeli błąd wróci podczas wykonywania slotu, `xretractor` zatrzymuje plan ścieżką błędu silnika. Sprawdź typy pól, argumenty funkcji i warunek reguły; porównaj je z [wyrażeniami pól i funkcjami skalarnymi](../konstrukcja-jezyka-zapytan/polecenie-select/wyrazenia-pol-i-funkcje-skalarne.md). Większość niepoprawnych konstrukcji powinna zostać odrzucona wcześniej przez parser lub kompilator; powtarzalny błąd dopiero podczas wykonania warto zgłosić z minimalnym planem i wejściem.

`internal record count mismatch`, brak podpiętego payloadu, indeks poza pojemnością bufora, niespójna maska wykonania i komunikaty `RDB_ASSERT` wskazują naruszenie warunku wewnętrznego. Nie należy zgadywać naprawy przez zmianę bajtów magazynu. Zachowaj wersję, plan, deskryptory, wejście i log; zatrzymaj automatyczne powtarzanie wadliwego przebiegu i zgłoś błąd. Nie każda kontrola wewnętrzna kończy proces: `Engine invariant violated while handling command` może zwrócić klientowi `engine error: ...` bez zakończenia serwera. Dalsze działanie w takim przypadku nie potwierdza poprawności stanu.

`getRow ... timeOffset beyond history` lub `fetchForward ... record ... not available` dotyczą żądania rekordu, którego magazyn nie udostępnia; część takich ścieżek zwraca NULL zamiast wyjątku. Sprawdź długość zachowanej historii, retencję, początki logiczne i to, czy źródło dostarczyło potrzebne dane. Zwiększ zasoby historii dopiero po potwierdzeniu, że problemem jest rzeczywiście jej pojemność; limity opisują [Granice wymiarów planu](../kompilacja-zapytan/granice-wymiarow-planu.md).

## Zapis magazynu, metadane, rotacja i DUMP

| Fragment komunikatu | Scenariusz i reakcja | Co zrobić |
| --- | --- | --- |
| `::write ... failed`, `made no progress`, `::pread ... failed`, `partial read`, błąd `stat`, `file_size` lub otwarcia segmentu | Nośnik jest pełny, tylko do odczytu, niedostępny albo plik został obcięty. Propagowany błąd I/O magazynu kończy `xretractor` kodem EIO. | Sprawdź przyczynę systemową, miejsce i i-węzły, montowanie oraz uprawnienia. Nie zmieniaj plików pracującej instancji. Zachowaj kopię przed naprawą częściowego zapisu. |
| `trailing bytes; truncating ...` | Akcesor POSIX/POSIXSHD znalazł niepełny rekord lub wpis cienia i próbuje obciąć końcówkę do granicy formatu. Błędy `lseek`/`ftruncate` są raportowane osobno. | Zbadaj wcześniejsze przerwanie zapisu i stan nośnika. Obcięcie nie odtwarza utraconej końcówki; zapobiegaj nagłemu zanikowi zasilania i współbieżnej edycji plików. |
| Błąd otwarcia lub przepisania `.meta` / `.meta.shadow` | Uszkodzony lub niedostępny indeks może odmówić otwarcia, odłączyć persystencję metadanych albo zwrócić I/O, zależnie od operacji. | Zachowaj razem dane i indeksy; sprawdź format oraz prawa. Nie zakładaj, że każdy błąd metadanych zatrzymuje proces ani że każda awaria ich zapisu jest propagowana. |
| `Rotation counter file ...`, `Cannot reserve rotation number`, `Rotation counter ... NOT saved` | Wadliwa treść licznika jest odmową przy kontroli planu; niedostępność lub późny błąd rezerwacji jest awarią środowiska. | Przywróć zweryfikowany licznik i dostęp do jego katalogu. Usunięcie licznika zaczyna numerację od 0 i może doprowadzić do nadpisania istniejących archiwów. |
| `saved, but directory fsync failed`, błędy `Rotation of ...` | Rezerwacja lub operacja na archiwum nie ma pełnego potwierdzenia trwałości. Nie wszystkie te błędy zatrzymują start lub strumień. `overwrote existing archive ... previous content is lost` oznacza rzeczywistą utratę poprzedniego archiwum. | Sprawdź pliki i licznik po zatrzymaniu, stan nośnika oraz wcześniejsze komunikaty; nie uznawaj samego dalszego działania za potwierdzenie archiwizacji. |
| `dumpManager::createDumpFile: failed to remove/create`, błąd pozycjonowania, `write to ... failed after ... bytes` | Nie udało się utworzyć lub zapisać zrzutu. Propagowany błąd DUMP kończy wykonanie jako I/O z EIO, zachowując plan usługi. | Przygotuj katalog i miejsce; sprawdź wskazaną ścieżkę. Po częściowym zapisie plik może zawierać początek rekordu; operacja nie jest wycofywana. |
| `Stream ... grows without bound on disk` | Ostrzeżenie o braku ograniczenia wzrostu; samo nie kończy wykonania. | Dobierz `RETENTION capacity segment_count`, magazyn MEMORY lub właściwy profil substratów zgodnie z celem planu. Monitoruj pojemność także dla metadanych i zrzutów. |

Udany zapis danych nie oznacza transakcji z metadanymi ani synchronizacji całego wyniku na trwały nośnik. Plan zachowany po EIO nie jest checkpointem. Po naprawie zweryfikuj ostatnie kompletne rekordy i sposób ponownego przetworzenia wejścia. Szczegóły: [Pliki](../architektura-systemu-przetwarzania-danych/format-zapisu-danych/pliki.md), [Rotacja](../architektura-systemu-przetwarzania-danych/format-zapisu-danych/rotacja.md) i [Realizacja alarmowania](realizacja-alarowania.md).

## Reguły SYSTEM i ustawienia czasu rzeczywistego

`system() call failed`, `system() command exited with status: ...` i `system() command did not terminate normally` dotyczą polecenia uruchomionego przez regułę `DO SYSTEM`. Silnik loguje błąd i kontynuuje wykonywanie reguł; nie ponawia automatycznie nieudanego polecenia. Sprawdź polecenie z konta usługi, jego środowisko, ścieżki i zależności. Kod programu potomnego nie jest kodem zakończenia `xretractor`. Długie, synchroniczne polecenie może opóźniać slot; przenieś długą pracę do osobnego procesu obsługującego krótkie zlecenia.

`mlockall failed`, `SCHED_FIFO failed`, niedostępna polityka RT lub odmowa ustawienia powinowactwa CPU oznaczają słabsze warunki wykonania, zwykle z kontynuacją. Sprawdź uprawnienia i limity blokowania pamięci oraz priorytetów, dostępne CPU i konfigurację hosta. Dobierz priorytet z obsługiwanego zakresu; samo jego zwiększanie nie usuwa kosztu I/O ani przeciążenia. Na platformie bez odpowiedniej funkcji działa jawnie słabsza ścieżka. Test poprawnych wartości i zakończenie kodem 0 nie są dowodem dotrzymania terminów; harmonogram i pomiary opisuje [Algorytm przeglądu drzewa zapytań](algorytm-przegladu-drzewa-zapytan.md).

## Magistrala i bezpieczne otwieranie IPC

| Komunikat | Przyczyna i reakcja | Działanie |
| --- | --- | --- |
| `xrdbbus: cannot access/create/map`, `stayed undersized`, `was never initialized`, `foreign or incompatible layout` | Brak dostępu, uszkodzony albo niezgodny segment. Start może przejść w tryb bez globalnej ochrony nazw i zasobów; nie jest to bezpieczny stan dla dowolnego zestawu wielu instancji. | Sprawdź konto, wersje i pamięć dzieloną. Naprawę lub usunięcie wskazanego segmentu wykonuj dopiero po zatrzymaniu wszystkich instancji, które go mapują. |
| `ENOTRECOVERABLE`, `Running WITHOUT name uniqueness`, błąd muteksu magistrali | Muteks lub protokół blokady nie pozwala użyć rejestru. Reset może zostać odrzucony przed przyjęciem; późna awaria aktywacji ma inny skutek. | Zachowaj diagnostykę segmentu. Nie usuwaj go spod działających procesów: rozdzieliłoby to rejestr zasobów. |
| `process entry ... is unreadable ... treated as alive` | Nie można wiarygodnie ustalić życia właściciela, np. przez `hidepid` lub `ProtectProc`; jego roszczenia są zachowywane. | Sprawdź widoczność procesów z konta serwera. Sam brak dostępu do `/proc` nie uzasadnia kasowania zasobów. |
| `IPC object ... untrusted owner`, `mode ... required 0600`, `not a regular object with a single link`, `name no longer identifies ...`, nieufny katalog | Kontrola właściciela, praw, typu lub tożsamości odmówiła użycia obiektu. Obca kolejka poleceń lub segment odpowiedzi blokują start; obca kolejka klienta blokuje jego subskrypcję. | Uruchom klienta z tym samym efektywnym UID co serwer, również przy użyciu konta root. Sprawdź katalog i pochodzenie obiektu, bez rozszerzania praw na inne konta. |
| `IPC startup refused`, `IPC resources could not be created`, `Startup aborted: IPC resources unavailable.` | Serwer nie mógł bezpiecznie posprzątać poprzednika lub utworzyć własnego IPC; start nie powiódł się. | Sprawdź wcześniejszy powód: właściciela, prawa, kolizję nazwy, pojemność i zgodność wersji. |
| `IPC communication thread stopped, server no longer accepts commands` | Wyjątek zakończył wątek komunikacyjny; dalsza obsługa poleceń jest niedostępna, po wcześniejszym ogłoszeniu gotowości nie wywołuje callbacku odmowy startu. Przetwarzanie może nadal trwać bez obsługi poleceń. | Zachowaj przyczynę i sprawdź rzeczywisty stan procesu; przywróć instancję po usunięciu problemu. |

Obiekty żywych instancji są chronione blokadami i magistralą. `xretractor --cleanup` służy do obsługi porzuconych zasobów w granicach tego mechanizmu; nie wyszukuje wszystkich kolejek klientów pozostawionych po SIGKILL. Procedurę i ograniczenia opisuje [Wiele instancji i magistrala](../architektura-systemu-przetwarzania-danych/wiele-instancji-i-magistrala.md).

## Pojemność IPC i za duże odpowiedzi

| Fragment diagnostyki | Przyczyna i skutek | Jak zapobiegać |
| --- | --- | --- |
| `shared memory too small: fixed reservation needs ...` | Za mało miejsca na stałe obiekty instancji; odmowa przed wykonaniem. | Sprawdź `xretractor -c --shmbudget plan.rql`, pojemność `/dev/shm` na Linuksie i limit kontenera. Rozłączne nazwy instancji nie zwiększają pojemności. |
| `response queue for stream ... needs ... shared memory has ... free` | Brakuje miejsca na kolejkę nowej subskrypcji. Serwer najpierw zwalnia bezczynne wpisy puli, jeżeli nie ma gotowej kolejki o właściwej pojemności. | Ogranicz liczbę klientów lub świadomie zmniejsz `ipc.queue_buffer_seconds` / `ipc.min_queue_elements`; uwzględnij większe ryzyko przepełnienia. Zwiększ pojemność pamięci dzielonej, jeśli wymaga tego obciążenie. |
| `serialized row is ... does not fit the ... response queue slot; subscribers ... receive no data` | Wiersz po serializacji przekracza slot 1024 B. Emisja jest pomijana; błąd pojawia się raz na strumień, a serwer nadal przetwarza plan. | Subskrybuj węższą projekcję lub ogranicz tablice i napisy. Zwiększenie liczby elementów kolejki nie zwiększa rozmiaru jednego wiersza. Dla pełnego wyniku rozważ zapis do artefaktu. |
| `IPC response ... a response slot holds ... replaced with an error` | Odpowiedź na polecenie przekroczyła 128 KiB; zamiast niej klient dostaje błąd. To inny limit niż slot wiersza subskrypcji. | Ogranicz rozmiar odpowiedzi/rozbudowanego planu; zachowaj przykład, jeśli przekracza go poprawny plan. |
| `all ... response slots are held by live clients` | Wszystkie 16 slotów odpowiedzi na polecenia jest zajętych; nowa odpowiedź jest odrzucana. Sloty potwierdzonych martwych klientów mogą być odzyskane. | Ogranicz równoczesne żądania, upewnij się, że klienci odbierają odpowiedzi i kończą żądania; sprawdź zawieszone procesy. |
| `command queue ... stayed full until the deadline`, `server not found` | Polecenie nie weszło do kolejki lub odpowiedź nie przyszła przed wspólnym terminem. `server not found` nie dowodzi nieistnienia procesu. | Sprawdź stan i obciążenie serwera, dziennik IPC oraz liczbę klientów. Zwiększ `ipc.client_response_max_fails` tylko dla uzasadnionego czasu oczekiwania. |

Raport `--shmbudget` jest oszacowaniem, a nie rezerwacją miejsca. Pojemność kolejki zależy od częstotliwości strumienia i ustawień buforowania. Miejsce zużywają też inne instancje oraz pozostawione w puli kolejki.

## Pełne, porzucone i ponownie używane kolejki klientów

Serwer wysyła rekord bez czekania na miejsce. Pełna kolejka lub wykryty porzucony muteks powodują natychmiastowe wyrejestrowanie subskrypcji; wątek komunikacyjny zajmuje się jej późniejszym zwolnieniem albo przekazaniem do puli. Wolny klient, zablokowany potok wyjścia, zatrzymany proces odbiorcy i nagłe zabicie klienta mogą więc dać podobny końcowy objaw: brak kolejnych rekordów.

| Poziom i fragment komunikatu | Znaczenie i reakcja | Zalecane działanie |
| --- | --- | --- |
| ERROR `response queue of client ... abandoned by a process that died holding its lock` | Właściciel umarł w sekcji krytycznej kolejki; jej muteks jest nienaprawialny. Serwer wyłącza tę subskrypcję i sprząta kolejkę. | Używaj normalnego zakończenia klienta; zbadaj jego awarie lub wymuszone SIGKILL. Nowa subskrypcja dostaje sprawną kolejkę. |
| WARN `queue erased on timeout, procId=...` | Kolejka została skierowana do usunięcia po wyłączeniu klienta; nie spełniła warunków puli lub jej ponowne użycie się nie udało. | Sprawdź wcześniejszy powód i tempo odbioru. Słowo `timeout` jest nazwą tej ścieżki logowania; w `broadcast` wyzwala ją nieudana nieblokująca wysyłka, nie pomiar wieku rekordu. |
| WARN `queue pooled on timeout, procId=...` | Kolejka potwierdzonego nieistniejącego procesu została przeniesiona do puli; może jeszcze czekać na zakończenie opróżniania. | Sam wpis opisuje obsłużone odłączenie. Utrzymujące się zajęcie pamięci przez pulę jest oczekiwane; powtarzalne odłączenia wymagają zbadania klienta. |
| WARN `response queue '...' not drained for reuse: ...` | Odbiór podczas opróżniania rzucił wyjątek, np. przez nienaprawialny muteks. Kolejka nie zostanie ponownie użyta; serwer zamyka mapowanie i próbuje usunąć nazwę. | Sprawdź dołączoną przyczynę. Nie odtwarzaj ręcznie liczników kolejki; ponów potrzebną subskrypcję po wyjaśnieniu awarii. |
| WARN `response queue '...' not empty after receiving its capacity; not reused` | Wyczerpano budżet odbiorów równy pojemności, a kolejka nadal nie jest pusta. Serwer rezygnuje z ponownego użycia i ją zwalnia. | Zachowaj log i wersję; sprawdź własnych klientów lub obcy zapis do kolejki. Prawidłowo wyrejestrowana kolejka nie powinna dostawać nowych rekordów. |
| WARN `broadcastOutOfBusiness: end marker not sent ...`, `queue erased on out-of-business` | Zatrzymanie lub reset kończy epokę; wysłanie znacznika jest jednorazowe i może się nie udać. Sprzątanie subskrypcji trwa dalej. | Klient powinien obsłużyć zarówno znacznik końca, jak i brak danych/timeout. Po resecie sprawdź nowy schemat i ponów subskrypcję. |
| ERROR `command queue ... abandoned ... recreating it` | Klient umarł z muteksem kolejki poleceń; serwer próbuje odtworzyć kolejkę. Żądania będące w starej kolejce mogą zostać utracone. | Sprawdź wynik każdego polecenia i stan serwera przed ponowieniem operacji zmieniającej plan. |

Pula ma najwyżej dwa wpisy na instancję. Dla instancji `alfa` noszą nazwy `brcdbr.alfa.p0` i `brcdbr.alfa.p1`; instancja bezimienna używa `brcdbrp0` i `brcdbrp1`. Kolejka jest oddawana następnemu klientowi dopiero po opróżnieniu i przy dokładnie tej samej pojemności. Opróżnianie odbywa się porcjami do 256 komunikatów: pierwsza jeszcze pod nazwą klienta, następne w kolejnych obrotach pętli komunikacyjnej, po jednej porcji dla najstarszego niegotowego wpisu. Żywy proces, zombie i niepewny wynik kontroli procesu wykluczają przyjęcie jego kolejki do puli. Nowy klient nie dostaje pozostawionych w niej rekordów poprzednika.

Aby uniknąć odłączeń, odbieraj dane na bieżąco i zapewnij drożne wyjście klienta. Większy bufor pomaga na krótkie opóźnienia, ale nie rozwiązuje trwałej różnicy tempa i zużywa więcej pamięci. Wyrejestrowana subskrypcja nie jest automatycznie wznawiana; ponowne `xqry --select` zaczyna odbiór bieżący i nie odtwarza luki. Gdy potrzebna jest pełna historia, zachowuj wynik w magazynie.

### Odmowa zmiany nazwy kolejki puli

Ponowne użycie zachowuje obiekt i mapowanie, zmieniając jego nazwę. Kontrolowane odmowy mają postać `IPC object '...': ... (owner UID ..., expected UID ...)`; gdy właściciela nie można ustalić, pojawia się `owner UID unavailable`. Ogólny błąd operacji może nie zawierać danych UID.

| Fragment ERROR | Przyczyna | Reakcja i działanie operatora |
| --- | --- | --- |
| `cannot inspect object for rename` | Nie dało się sprawdzić obiektu źródłowego, np. wpis zniknął albo odmówiono dostępu. | Ponowne użycie odpada; sprawdź katalog i zewnętrzne usuwanie obiektów. |
| `rename target already exists` | Docelowa nazwa jest zajęta, także przez obiekt obcego UID. | Istniejący cel pozostaje nietknięty; sprawdź jego pochodzenie i właściciela. |
| `cannot inspect rename target` | Sprawdzenie celu dało inny wynik niż potwierdzony brak wpisu. | Sprawdź przyczynę systemową i dostęp do katalogu IPC. |
| `rename to '...' failed` | System odrzucił zmianę nazwy albo wystąpił wyjątek operacji. | Sprawdź wskazany powód, prawa i stan systemu plików IPC. |

Przy oddawaniu porzuconej kolejki do puli nieudana zmiana nazwy prowadzi do zwykłego zwolnienia. Przy pobieraniu z puli serwer zwalnia nieudany wpis i próbuje utworzyć nową kolejkę; to tworzenie również może się nie udać. Odmowa samej operacji zmiany nazwy zachowuje źródło i cel, ale jej wywołujący może następnie posprzątać własny obiekt. Pozostałość obcego konta pod nazwą puli nie blokuje sama w sobie startu serwera. Sprawdzane są również właściciel, pojedyncze dowiązanie, tryb 0600 i zaufana przestrzeń nazw, jak przy pozostałych obiektach IPC.

## Błędy klienta xqry i zdarzenia JSONL

| Werdykt formatu prezentacyjnego | Kod symboliczny | Typowa przyczyna i działanie |
| --- | --- | --- |
| `stream unknown to the server` | `ENOENT` | Zła nazwa, inny serwer lub strumień usunięty przez reset; sprawdź `--server`, `--dir` i schemat. |
| `server did not answer within the timeout` | `ETIMEDOUT` | Brak odpowiedzi; sprawdź proces, IPC i obciążenie, nie tylko obecność plików w `/dev/shm`. |
| `server did not create the client response queue` | `ENOSR` | Odmowa `show`, brak pamięci, błąd kontroli IPC lub koniec epoki. Przyczyna z `error.response` jest zapisywana w logu klienta. |
| `no data in stream` | `ENOMSG` | Odbiór nie dał rekordu; sprawdź źródło, ogon początkowy, emitowany strumień i `timing.query_no_data_timeout_ms`. |
| `server has no plan loaded (idle); load one with --reset` | `ENOENT` | Bezczynna instancja; dostarcz plan, jeżeli ma przetwarzać. Sam poprawny spis pustej instancji może zakończyć się kodem 0. |
| `server is shutting down` | `ECANCELED` | Polecenie trafiło w zamykanie; poczekaj i sprawdź nową instancję lub plan. |
| `select loop failed in the client; reason in the client log` | `EINTR` | Wyjątek odbioru lub renderowania; sprawdź log klienta. Już wypisane rekordy są wynikiem częściowym. |

`response queue ... did not appear after ... attempts` rozróżnia `budget exhausted` od `aborted by client`; drugi przypadek nie dowodzi, że serwer nie utworzył kolejki. `incompatible layout` segmentu odpowiedzi wymaga sprawdzenia wersji klienta i serwera oraz ich zasobów. Niejednoznaczny routing naprawia jawne `--server`; zapytanie obejmujące strumienie z różnych instancji nie tworzy rozproszonego planu.

W `--jsonl` błędy są zdarzeniami `error` z polami `code` i `message`, a kod zakończenia błędu wynosi `1`. Kody obejmują `server_no_response`, `stream_not_found`, `no_active_plan`, `server_stopping`, `client_queue_missing`, `disconnected`, `idle_timeout`, `protocol_error` i `communication_error`. `idle_timeout` dotyczy jawnego limitu bezczynności `--idle-timeout`; `protocol_error` oznacza m.in. rekord obcego strumienia. Zdarzenie `end` z powodem `limit` lub `server_stopped_or_reloaded` jest poprawnym zakończeniem. Klienty API mają dodatkowo własne błędy uruchomienia procesu i dekodowania protokołu, opisane w [API monitorowania](../zalaczniki/api-monitorowania-strumieni.md).

## Odmowy poleceń, resetu i importu ad hoc

| Komunikat lub rodzina | Scenariusz i reakcja | Zalecane działanie |
| --- | --- | --- |
| `IPC command rejected: INFO directive`, `missing or invalid db.id`, `IPC message dropped` | Własny klient wysłał wadliwą lub niedozwoloną wiadomość. Serwer odrzuca ją; w tych przypadkach odpowiedź może nie powstać. | Używaj obsługiwanego klienta i formatu; nie wysyłaj dyrektyw INFO, np. linii `#include`. `#` wewnątrz wartości RQL ma inny kontekst. |
| `command processor failure: ...`, `command handler failure: ...` | Obsłużony wyjątek handlera jest zwracany w `error.response`; serwer nadal może przyjmować polecenia. | Sprawdź pełną przyczynę po stronie klienta i serwera. Po timeoutach operacji zmieniającej stan sprawdź efekt przed ponowieniem. |
| `plan epoch ended while subscribing ... repeat the command` | Reset lub zatrzymanie zamknęły epokę przed rejestracją; przygotowana kolejka jest usuwana. | Zaczekaj na zakończenie wymiany, potwierdź nazwę i schemat, ponów subskrypcję. |
| `reset-begin/chunk/commit rejected`, `Rejected: ...` | Zła liczba/kolejność porcji, brak lub niepełny transfer, za duży plan, za dużo transferów albo trwający reset. | Serializuj zmiany planu; używaj `xqry --reset`. Po przerwaniu rozpocznij cały transfer od nowa, a przy przeciążeniu odczekaj. |
| `AdHoc rejected: ...`, odmowa `DO SYSTEM` lub kolizja zasobów | Nie udało się bezpiecznie dołączyć polecenia; import nowych węzłów i roszczeń może zostać wycofany. | Usuń wskazaną przyczynę. Ad hoc zawsze odmawia `DO SYSTEM`; reset wymaga do niego jawnego `service.unrestricted`. Nie włączaj go tylko po to, by ominąć niewyjaśnioną odmowę. |
| `Plan reload failed ... falling back to idle mode` | Ponowne parsowanie/kompilowanie przy instalacji przyjętego planu zawiodło; stary model został już rozebrany. | Sprawdź aktywny plan i dostarcz poprawioną wersję. |
| `Plan is running but could NOT be persisted`, błąd zapisu pliku startowego usługi | Nowy plan działa, ale nie udało się zachować go na restart. | Napraw dostęp do pliku startowego i ponownie dostarcz zweryfikowany plan; sprawdź jego trwałą treść przed restartem. |

Odpowiedź `OK` na reset oznacza przyjęcie, a nie zakończenie wszystkich późniejszych otwarć ani trwały zapis. Późny błąd budowy modelu może zakończyć proces bez przywrócenia poprzedniego modelu. Podobnie wycofanie ad hoc nie jest ogólną transakcją dla wszystkich skutków I/O; obsługa późnej odmowy otwarcia nie obejmuje profilu GENERIC. Szczegóły: [Zapytania ad hoc](zapytania-ad-hoc.md) i [usługa i wymiana planu](../zalaczniki/opcje-wywolania/xretractor.md#usługa-i-wymiana-planu).

## xtrdb oraz wykonanie osadzone Python

`xtrdb` odmawia edycji przy wykrytej działającej instancji. `cannot verify whether xretractor is running` oznacza, że błąd kontroli blokady nie pozwolił bezpiecznie potwierdzić jej braku. Zatrzymaj instancje i użyj tej samej konfiguracji katalogu blokad; nie omijaj ochrony inną ścieżką. Przy `open: ...` sprawdź deskryptor i metadane. `record out of range` odrzuca indeks przed odczytem i zachowuje payload, natomiast nieudany odczyt dopuszczonego indeksu ustawia `error`, a lista może pokazać `fetch error`. Błędy `write: ...`, `append: ...` oraz próba dopisania do źródła tylko do odczytu również ustawiają stan payloadu `error`; terminal działa dalej. Kod procesu 0 po `quit` nie potwierdza powodzenia wcześniejszych poleceń. Szczegóły: [xtrdb](../zalaczniki/opcje-wywolania/xtrdb.md).

Osadzony `Engine` nie ma IPC ani zegara usługi. Binding mapuje błędy rdzenia na `ConfigError`, `RQLSyntaxError`, `CompileError`, `CorruptDescriptor`, `IOError` i `InternalError`. Zwrócone `Errc::Eval` i `Errc::Logic` dają `InternalError`, który skaża cały moduł: chronione wejścia odmawiają do restartu interpretera, a `close()` pozostaje dostępne. Nieudany `run()` z błędem I/O zatrzymuje postęp planu do rekompilacji, zachowując dostęp do już uzyskanych wyników. Błędy argumentów mogą dawać także `KeyError`, `IndexError`, `ValueError` lub `TypeError`. Sprawdź nazwy, indeksy, wymiary i typ eksportu; NULL nie daje poprawnej wartości całkowitoliczbowej przy eksporcie do NumPy.

`rdb::fatal()` i `RDB_ASSERT` mają osobną ścieżkę: domyślnie kończą hosta przez `abort`, także kernel Jupyter; nie stają się zwykłym wyjątkiem Pythona. Nie zakładaj, że każdy błąd da się obsłużyć `try/except`. Używaj wspieranego zakresu planów, serializuj dostęp do Engine i zgłaszaj naruszenia niezmienników z przykładem. Pełny kontrakt opisuje [API Python i Jupyter](../zalaczniki/python-jupyter-api.md).

## Podstawa implementacyjna i testy

Opis sprawdzono w kodzie `master` w rewizji `e0857dc8ba5387929c0e79d172cb8c45a669e3a3`. Poniższe testy wskazują istniejące pokrycie zachowania; tabela nie deklaruje nowego przebiegu testów ani weryfikacji wszystkich platform.

| Obszar | Źródła w repozytorium silnika | Testy i scenariusze |
| --- | --- | --- |
| Klasy błędów i zatrzymanie | `src/include/rdb/error.hpp`, `src/include/fatalError.hpp`, `src/retractor/lib/executorsm.cpp` | `ut_fatalError`, `it_fatal_exit_path-run`, `it_env_error_exit-run` |
| Kontrole źródeł, deskryptorów i magazynów | `planSource.cpp`, `src/rdb/lib/storage.cc`, akcesory `facc*` | `ut_planSource`, `ut_rdb`, `ut_facctxtsrc`, `ut_sourceBuffer`, `it_storage_refusal-*`, `it_untileof_stop-missing-sources` |
| Urządzenia i reguły | `src/rdb/lib/faccbindev.cc`, `streamInstance.cpp`, `dumpManager.cpp` | `ut_faccbindev`, `ut_dumpManager`, `ut_expeval`, `it_issue42_rule-*` |
| Magistrala i IPC | `bus.cpp`, `ipcServer.cpp`, `ipcResponses.cpp`, `src/common/ipcSecurity.cpp` | `ut_bus`, `ut_ipcServer`, `ut_ipcResponses`, `ut_ipcSecurity`, `it_ipc_security-*` |
| Pula i opróżnianie kolejki | `ipcServer.cpp`, `src/include/constants.hpp` | `IpcServerQueues.abandoned_queue_of_dead_client_is_reused_empty_by_next_subscriber`, `abandoned_queue_larger_than_one_batch_is_drained_over_several_turns`, `dead_mutex_between_drain_batches_releases_the_pool_entry`, `IpcSecurity.RenameMovesOwnQueueWithItsMappingAndRefusesUnsafeCases` |
| Polecenia i klienci | `executorsmCommands.cpp`, `executorsmPlanReload.cpp`, `executorsmAdHoc.cpp`, `src/qry/`, `src/rdb/cmdStorage.cpp` | `it_subscribe_epoch_race-run`, `it_select_loop_failure-run`, `it_service_reset*`, `it_adhoc_register_rollback*`, `it_xtrdb_write_status-run`, `st_api_fake`, `st_api_real` |
| Silnik osadzony | `src/embed/`, `src/python/module.cpp` | `ut_embedEngine`, Python `test_error_classes.py`, `test_fatal_paths.py`, `test_storage.py` |

Mapa pokrycia i znaczenie identyfikatorów wymagań znajdują się w [Testach integracyjnych](../zalaczniki/testy-integracyjne.md#wymagania-w-kodzie-i-powiązanie-z-testami). Przy zgłoszeniu awarii podaj pierwszy błąd, jego skutek oraz najmniejszy plan i dane pozwalające go odtworzyć; usuń z materiału dane, których nie wolno udostępniać.
