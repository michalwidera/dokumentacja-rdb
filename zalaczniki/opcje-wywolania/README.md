# Opcje wywołania

RetractorDB składa się z trzech narzędzi wiersza poleceń, z których każde pełni odrębną rolę w architekturze systemu:

| Narzędzie      | Rola                                                                 |
| -------------- | -------------------------------------------------------------------- |
| `xretractor`   | Proces przetwarzania: kompiluje RQL i realizuje jeden niezależny plan |
| `xqry`         | Klient: wyszukuje lub wskazuje instancję i komunikuje się przez jej IPC |
| `xtrdb`        | Narzędzie inspekcji: analizuje artefakty binarne i metadane          |

Każde z narzędzi opisano w osobnym podrozdziale.
