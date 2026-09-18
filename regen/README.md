# Regeneracja planow xretractor

Uruchom `./regen/pic_and_qry.sh` z katalogu glownego dokumentacji. Skrypt wybiera `../retractordb/build/Debug/src/retractor/xretractor`; aby wskazac inny aktualny program, ustaw `XRETRACTOR=/sciezka/do/xretractor`. Przed uzyciem skrypt wywoluje `ninja xretractor` w katalogu buildu, wiec rysunki zawsze powstaja z biezacego `src/`; programu wskazanego przez `XRETRACTOR` nie przebudowuje.

Kazdy plik `.rql` jest zrodlem co najmniej jednego rysunku lub listingu w ksiazce.
Skrypt zapisuje listingi do `regen/out/`, a nastepnie mdBook wlacza je w oznaczone
bloki kodu przez `{{#include ...}}`. Rysunki DOT trafiaja bezposrednio do `assets/`.
Kazdy SVG generowany przez skrypt ma przezroczyste tlo (`xretractor -p`).

| Zrodla | Wynik w dokumentacji |
| --- | --- |
| `plan-basic.rql`, `runtime-plan.rql` | Rys. 27 i 29 oraz listing Rys. 27 |
| `dag-1.rql` - `dag-4.rql` | Rys. 33-36 |
| `alias.rql`, `compile-flow.rql`, `debug.rql` | listingi rozdzialow o aliasowaniu i kompilacji |
| `wildcard.rql`, `underscore.rql` | listingi rozwijania `*` i `[_]` |
| `substrate-hash*.rql`, `substrate-shift.rql` | listingi rozdzialu o substratach |
| `dedup.rql`, `dedup_przed.dot`, `absorb-auto.rql`, `absorb-named.rql` | Rys. 37-40 |
| `filter.rql` | Rys. 57 |
| `sum-sequence.rql` | listing diagramu sekwencji sumowania |

`dedup.rql` zasila `dedup_po.svg` (Rys. 38). Rys. 37 (`dedup_przed.svg`) skrypt rysuje z recznie napisanego `dedup_przed.dot`, bo kompilator nie pokaze planu sprzed deduplikacji nawet z `RDB_OPT_DEDUP_SUBSTRATES=OFF`: koncowe sortowanie topologiczne indeksuje zapytania po nazwie i skleja oba substraty `STREAM_ADD_core0_core1` w jeden wezel. Po zmianie `dedup.rql` albo stylu wezlow w `presenter::graphiz()` plik `.dot` trzeba poprawic recznie.
