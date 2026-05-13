# Opcje wywołania

RetractorDB składa się z trzech narzędzi wiersza poleceń, z których każde pełni odrębną rolę w architekturze systemu:

| Narzędzie      | Rola                                                                 |
| -------------- | -------------------------------------------------------------------- |
| `xretractor`   | Główny proces przetwarzania: kompiluje zapytania RQL i realizuje plan |
| `xqry`         | Klient: odpytuje działający `xretractor` przez wspólną pamięć        |
| `xtrdb`        | Narzędzie inspekcji: analizuje artefakty binarne i metadane          |

Każde z narzędzi opisano w osobnym podrozdziale.
