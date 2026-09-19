# Wiele instancji i magistrala

Na jednym hoście może działać równocześnie wiele procesów `xretractor`. Każda instancja ma własną nazwę, blokadę, obszar IPC, plan i klientów. Wspólna magistrala `xrdbbus` rejestruje żywe instancje, umożliwia ich wyszukiwanie przez `xqry` i pilnuje, aby dwa plany nie przejęły zasobów, których nie mogą bezpiecznie współdzielić.

<figure><img src="../assets/wiele-instancji-magistrala.svg" width="100%" alt=""><figcaption><p>Rys. 13. Równolegle działające instancje i wspólna magistrala xrdbbus</p></figcaption></figure>

Na Rys. 13 każda instancja kompiluje własny plan i zgłasza własny zestaw nazw strumieni w slocie magistrali; ponumerowane węzły zastępują tam nazwy, bo istotne jest tylko to, że nie powtarzają się one między instancjami. Rozłączne są nazwy obiektów, nie obszar pamięci: segment magistrali i obiekty IPC wszystkich instancji leżą w tym samym `/dev/shm`, a odróżnia je sufiks nazwy instancji - dla instancji `alfa` są to kolejka poleceń `RetractorQueryQueue.alfa`, segment odpowiedzi `RetractorShmemMap.alfa`, muteks mapy `RetractorMapMutex.alfa` i kolejka odpowiedzi klienta `brcdbr.alfa.<pid>`. Wspólny jest również katalog magazynu, w którym pliki poszczególnych instancji pozostają rozłączne.

Wyjątkiem jest tryb usługowy: w domyślnej przestrzeni hosta może działać dokładnie jedna instancja oznaczona jako usługa. Domyślnie otrzymuje ona stałą nazwę `service`, dzięki czemu skrypty mogą kierować polecenia do `--server service` bez wcześniejszego przeglądania magistrali.

## Tożsamość instancji

Instancję można wskazać na trzy sposoby:

| Mechanizm | Znaczenie |
| --- | --- |
| `xretractor --name pomiary plan.rql` | Stała nazwa podana przez operatora. |
| `xretractor --autoname plan.rql` | Losowa nazwa w stylu nazw kontenerów; jest wypisywana przy starcie. |
| `server.autoname = true` | Automatyczna nazwa ustawiona w pliku TOML, o ile nie podano `--name`. |

Jawne `--name` ma pierwszeństwo przed konfiguracją. Nazwa musi pasować do `[a-z][a-z0-9_-]*` i może mieć najwyżej 32 znaki. `--name` i `--autoname` wzajemnie się wykluczają.

Brak nazwy zachowuje historyczną tożsamość: nazwy obiektów IPC i pliku blokady nie mają sufiksu. Taka instancja również pojawia się w magistrali, jako `(unnamed)`, i uczestniczy w kontroli kolizji.

Zmienna `RDB_NAMESPACE` wybiera osobny segment magistrali oraz, jeżeli nie podano `--name` ani `--autoname`, staje się domyślną nazwą serwera i celem `xqry`. Jest używana przede wszystkim przez równoległe testy integracyjne. Jawne opcje `--name`, `--autoname` i `--server` pozostają nadrzędne. Limit jednej usługi jest egzekwowany osobno w każdej przestrzeni magistrali. Różne wartości `RDB_NAMESPACE` przy tej samej jawnej nazwie serwera nie rozdzielają jednak obiektów IPC: o ich nazwach decyduje wybrana tożsamość instancji.

Przed uruchomieniem instancja zajmuje blokadę swojego pliku w katalogu `paths.lock_dir` (domyślnie katalogu tymczasowym) oraz dodatkową blokadę tożsamości IPC pod `/tmp/xretractor_ipc.<nazwa-kolejki-poleceń>.lock`. Druga lokalizacja jest stała i niezależna od `TMPDIR` oraz `paths.lock_dir`. Zajęta tożsamość IPC blokuje start przed usuwaniem artefaktów i tworzeniem IPC, również gdy magistrala jest niedostępna. Zmiana katalogu blokad lub przestrzeni magistrali nie pozwala przejąć obiektów żywego serwera.

## Zasoby prywatne i wspólne

Nazwane instancje mają rozłączne obiekty Boost.Interprocess. Nazwy bazowe kolejki poleceń, segmentu odpowiedzi i muteksu otrzymują sufiks instancji, a kolejka subskrybenta zawiera również PID klienta. Zatrzymanie jednej instancji kończy tylko jej subskrypcje i usuwa jej IPC; może również posprzątać porzucone zasoby po martwych procesach. Zasoby żywych instancji pozostają chronione.

Magistrala jest wspólna dla hosta lub przestrzeni `RDB_NAMESPACE`. Każdy żywy serwer publikuje w niej nazwę, PID, tryby pracy, plik planu i nazwy strumieni. Slot jest uznawany za żywy tylko wtedy, gdy PID oraz czas startu zgadzają się z `/proc`; proces zombie nie blokuje zasobów.

Bieżąca wersja układu używa segmentu `xrdbbus_v6`, a w przestrzeni testowej `xrdbbus_v6_<RDB_NAMESPACE>`. Użytkownicy segmentu utrzymują blokadę obecności `flock`; ostatni wychodzący może usunąć nieużywany segment. Wersje układu mają osobne rejestry: równoczesne uruchomienie binariów v5 i v6 nie zapewnia między nimi kontroli kolizji strumieni i magazynów. Przed aktualizacją należy zakończyć starsze instancje.

Przed uruchomieniem albo wymianą planu magistrala sprawdza rozłączność:

- nazw wszystkich strumieni, również wygenerowanych przez kompilator i dodanych ad hoc;
- znormalizowanych ścieżek zapisywanych plików magazynu;
- pliku licznika dyrektywy `:ROTATION`.

Roszczenie następuje przed usuwaniem starych artefaktów i zakładaniem IPC. Przegrana instancja nie może więc skasować danych działającego właściciela. Komunikat odmowy podaje kolidujący zasób, nazwę instancji i jej PID.

Przy `xqry --reset` zasoby nowego planu są najpierw rezerwowane. Dopiero po poprawnym zbudowaniu nowej epoki rezerwacja atomowo zastępuje aktywny zestaw. Błąd parsowania, kompilacji, limitu lub kolizja pozostawia dotychczasowy plan i jego roszczenia bez zmian.

> **⚠️ Ostrzeżenie**
>
> Niedostępność lub uszkodzenie magistrali nie zatrzymuje pojedynczego serwera, o ile może on zająć blokady instancji i tożsamości IPC. Start jest dopuszczany z ostrzeżeniem, ale globalna ochrona nazw strumieni i ścieżek magazynu nie jest wtedy egzekwowana. Blokada tożsamości IPC nadal obowiązuje. To tryb awaryjny, a nie poprawna konfiguracja wieloserwerowa.

## Routing poleceń `xqry`

`xqry` rozstrzyga cel na podstawie jednej migawki magistrali, bez odpytywania kolejnych serwerów i bez czekania na ich timeouty.

| Sytuacja | Wynik |
| --- | --- |
| Podano `--server nazwa` | Wskazana instancja jest używana bez automatycznego routingu. |
| Działa dokładnie jedna instancja | Klient wybiera ją automatycznie. |
| Kilka instancji, `--select` lub `--detail` | Wybierany jest właściciel strumienia. |
| Kilka instancji, ad hoc `SELECT` | Wszystkie źródła muszą należeć do jednej instancji. |
| Kilka instancji, ad hoc `RULE` | Celem jest właściciel strumienia z klauzuli `ON`. |
| Kilka instancji, ad hoc `DECLARE` | Trzeba podać `--server`, bo deklaracja nie ma właściciela wejścia. |
| Kilka instancji, polecenie całej instancji | `--hello`, `--dir`, `--kill` i `--reset` wymagają `--server`. |

Zapytanie ad hoc nie może łączyć źródeł z różnych instancji. RetractorDB nie przesyła strumieni pomiędzy serwerami; plany są niezależnymi grafami wykonania.

## Przegląd magistrali

Polecenie `xqry --bus` nie kontaktuje się z żadnym serwerem. Pokazuje nazwę, PID, tryb, plik zapytań i strumienie każdej żywej instancji. Modyfikator `--yaml` daje dokument `apiVersion: xqry/v1`, dogodny do przetwarzania przez skrypty.

Kolumna `MODE` może zawierać kilka liter:

| Litera | Tryb |
| --- | --- |
| `N` | zwykłe wykonanie taktowane zegarem |
| `R` | `--realtime` |
| `F` | `--no-clock` |
| `U` | `--until-eof` |
| `M` | ustawiony limit `--llimitqry` |
| `X` | `--xqrywait` |
| `S` | tryb usługowy lub jednostka systemd |

Przykładowa sesja:

```bash
xretractor alfa.rql --name alfa --noanykey &
xretractor beta.rql --name beta --noanykey &

xqry --bus
xqry --select temperatura          # routing według właściciela strumienia
xqry --server alfa --dir           # jawne polecenie całej instancji
xqry --server beta --kill          # zatrzymuje tylko instancję beta
```
