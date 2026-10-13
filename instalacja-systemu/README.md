# Instalacja systemu

Podstawową platformą wdrożeniową RetractorDB jest Linux na x86-64 i ARM64 (AArch64). Można zainstalować gotowe wydanie albo zbudować programy ze źródeł. Instalator pobierany przez `curl` instaluje gotowe binaria; kompilację wykonuje się osobno. Apple jest środowiskiem rozwojowym, opisanym w [wydzielonej sekcji](source-build.md#środowisko-rozwojowe-apple).

## Wybór sposobu instalacji

| Sposób | Zastosowanie | Lokalizacja programów |
| --- | --- | --- |
| Instalator `install.sh --user` | Instalacja dla bieżącego użytkownika, bez uprawnień administratora | `~/.local/bin` |
| Instalator `install.sh --system` | Instalacja dla całego systemu, opcjonalnie z usługą systemd | `/usr/local/bin` |
| Pakiet DEB | Debian lub Ubuntu; utrzymanie przez apt | `/usr/bin` |
| Budowanie ze źródeł | Rozwój, testy albo własne wydanie | Domyślnie `~/.local/bin` |

Instalator korzysta z [GitHub Releases](https://github.com/michalwidera/retractordb/releases). Opis szybkiej instalacji znajduje się również na [stronie projektu](https://retractordb.com/pl/install/). Kontrakt produkcyjnego budowania i warianty diagnostyczne opisuje [załącznik o budowaniu](../zalaczniki/budowanie-produkcyjne-i-warianty-badawcze.md).

`Engine` wykonuje plan w procesie Pythona na osi czasu logicznej. Nie zapewnia pracy w czasie rzeczywistym ani nie publikuje strumieni na magistrali. Do przetwarzania w czasie rzeczywistym służy `xretractor`, a do obserwacji jego strumieni klient monitorowania.

## Dalsza lektura

- [Gotowe wydania](linux-releases.md): portable, DEB, systemd, aktualizacja i konfiguracja.
- [Budowanie ze źródeł](source-build.md): Linux i rozwojowy port macOS.
- [Uruchamianie](running.md): standalone oraz plan działającego serwisu.
- [Python i Jupyter](python-jupyter.md): wheel, Colab i środowiska lokalne.
- [Budowanie biblioteki Python](python-build.md): RDB_PYTHON, testy i pakowanie.
