# Uruchamianie

Zainstalowane narzędzia można uruchamiać jako standalone albo przez usługę. [Gotowe wydania](linux-releases.md) opisują instalację i systemd, a [opcje xretractor](../zalaczniki/opcje-wywolania/xretractor.md) konfigurację czasu rzeczywistego, przełączniki i wymianę planu. `Engine` w Pythonie wykonuje [plan na osi logicznej](../zalaczniki/python-jupyter-api.md), bez usługi i magistrali.

## Standalone: plik do EOF

W powłoce Linux przygotuj osobne wejście i katalog wyników:

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

`-u` zatrzymuje przetwarzanie po EOF; `-k` pomija oczekiwanie na klawisz przy zakończeniu. Bez `-u` źródło może zawijać się, a proces wymaga zatrzymania. Nazwa identyfikuje instancję na magistrali; równoczesne instancje muszą mieć różne nazwy i rozłączne zasoby planów. Do rozmowy z działającą instancją używaj `xqry --server installation-demo`; zakończonego przebiegu nie można już obserwować przez IPC. Gotowe artefakty czyta `xtrdb` albo offline Storage. Katalog przykładu pozostaje do inspekcji.

## Działająca usługa

Po instalacji z obsługą systemd sprawdź `systemctl status xretractor.service`. Pusta konfiguracja startowa oznacza instancję bezczynną. Plan dostarcza się przez `xretractor nowy-plan.rql` albo reset `xqry --server service --reset nowy-plan.rql`, zgodnie z [kontraktem usługi i wymiany planu](../zalaczniki/opcje-wywolania/xretractor.md#usługa-i-wymiana-planu). Kontrole środowiska, magazynów i odmowy różnią się od wykonania osadzonego; `OK` resetu nie gwarantuje trwałego zapisu planu startowego.

Strumienie serwisu czyta się przez `xqry` lub [klient monitorowania](../zalaczniki/api-monitorowania-strumieni.md). Nie otwieraj magazynu działającej usługi przez `Storage` w celu monitorowania. WSL2 wymaga działającego systemd dla wariantu usługowego; standalone i Engine nie wymagają systemd.
