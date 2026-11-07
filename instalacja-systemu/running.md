# Uruchamianie

Zainstalowane narzędzia można uruchamiać jako standalone albo przez usługę. [Gotowe wydania](linux-releases.md) opisują instalację i systemd, a [opcje xretractor](../zalaczniki/opcje-wywolania/xretractor.md) konfigurację czasu rzeczywistego, przełączniki i wymianę planu. `Engine` w Pythonie wykonuje [plan na osi logicznej](../zalaczniki/python-jupyter-api.md), bez usługi i magistrali.

## Standalone: plik do EOF

Przykład wczytuje osiem liczb całkowitych, mnoży każdą przez dwa i zapisuje strumień `dst`. Po [instalacji narzędzi](linux-releases.md) wykonaj poniższe polecenia w tej samej powłoce Linux:

```bash
rdb_demo_dir=$(mktemp -d)
mkdir "$rdb_demo_dir/results"
printf '10\n20\n30\n40\n50\n60\n70\n80\n' > "$rdb_demo_dir/input.txt"
cat > "$rdb_demo_dir/plan.rql" <<EOF
STORAGE '$rdb_demo_dir/results'
DECLARE a INTEGER STREAM src, 1/2 TEXTFILE '$rdb_demo_dir/input.txt'
SELECT a*2 STREAM dst FROM src
EOF
xretractor "$rdb_demo_dir/plan.rql" --name installation-demo -u -k
```

Po zakończeniu `xretractor` odczytaj artefakt w tej samej powłoce, w której ustawiono `rdb_demo_dir`:

```bash
xtrdb --noprompt <<EOF
storage $rdb_demo_dir/results
open dst
size
list 8
quit
EOF
```

Oczekiwany wynik:

```text
8 Record(s)
4 Byte(s) per record.
{ dst_0:20 }
{ dst_0:40 }
{ dst_0:60 }
{ dst_0:80 }
{ dst_0:100 }
{ dst_0:120 }
{ dst_0:140 }
{ dst_0:160 }
```

`-u` zatrzymuje przetwarzanie po EOF; `-k` pomija oczekiwanie na klawisz przy zakończeniu. Bez `-u` źródło może zawijać się, a proces wymaga zatrzymania. Interwał `1/2` oznacza jedną próbkę co pół sekundy. Przy ponowieniu całego przykładu `mktemp` tworzy nowy katalog, dzięki czemu wyniki poprzedniego przebiegu pozostają oddzielne.

`size` potwierdza liczbę rekordów i rozmiar rekordu, a `list 8` pokazuje ich wartości w kolejności zapisu. Nazwę pola `dst_0` nadał kompilator wyrażeniu `a*2`. Plik `results/dst` zawiera dane binarne; `results/dst.desc` opisuje pole typu `INTEGER`. Do interpretacji danych używaj `xtrdb` lub [offline Storage](../zalaczniki/python-jupyter-api.md), które odczytują deskryptor i metadane.

Nazwa `installation-demo` identyfikuje instancję na magistrali; równoczesne instancje muszą mieć różne nazwy i rozłączne zasoby planów. `xtrdb` w trybie wsadowym lub interaktywnym wymaga zatrzymania instancji wykrywanych przez jego [kontrolę blokad i magistrali](../zalaczniki/opcje-wywolania/xtrdb.md). Jeśli zgłosi odmowę, poczekaj na zakończenie tych instancji. Działający silnik obserwuje się przez `xqry --server installation-demo`; po zakończeniu procesu pozostają pliki, a nie strumień IPC.

Jeśli wynik różni się od pokazanego, zachowaj pełne komunikaty `xretractor` i `xtrdb` oraz katalog przykładu. Sprawdź [błędy wykonania](../realizacja-zapytan/bledy-wykonania.md); sam kod wyjścia `xtrdb` równy zero nie potwierdza powodzenia każdej jego komendy. Katalog wskazany przez `rdb_demo_dir` pozostaje dostępny do dalszej inspekcji.

## Działająca usługa

Po instalacji z obsługą systemd sprawdź `systemctl status xretractor.service`. Pusta konfiguracja startowa oznacza instancję bezczynną. Plan dostarcza się przez `xretractor nowy-plan.rql` albo reset `xqry --server service --reset nowy-plan.rql`, zgodnie z [kontraktem usługi i wymiany planu](../zalaczniki/opcje-wywolania/xretractor.md#usługa-i-wymiana-planu). Kontrole środowiska, magazynów i odmowy różnią się od wykonania osadzonego; `OK` resetu nie gwarantuje trwałego zapisu planu startowego.

Strumienie serwisu czyta się przez `xqry` lub [klient monitorowania](../zalaczniki/api-monitorowania-strumieni.md). Nie otwieraj magazynu działającej usługi przez `Storage` w celu monitorowania. WSL2 wymaga działającego systemd dla wariantu usługowego; standalone i Engine nie wymagają systemd.
