# Regeneracja planow xretractor

Uruchom `./regen/pic_and_qry.sh` z katalogu glownego dokumentacji. Skrypt wybiera
`../retractordb/build/Debug/src/retractor/xretractor`; aby wskazac inny aktualny
program, ustaw `XRETRACTOR=/sciezka/do/xretractor`. Przed uzyciem skrypt wywoluje
`ninja xretractor` w katalogu buildu, wiec rysunki zawsze powstaja z biezacego `src/`;
programu wskazanego przez `XRETRACTOR` nie przebudowuje.

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
| `dedup.rql`, `absorb-auto.rql`, `absorb-named.rql` | Rys. 37-40 |
| `filter.rql` | Rys. 57 |
| `sum-sequence.rql` | listing diagramu sekwencji sumowania |

`dedup.rql` zasila dwa rysunki: `dedup_po.svg` z domyslnym kompilatorem oraz
`dedup_przed.svg` z binarnym programem, dla ktorego
`RDB_OPT_DEDUP_SUBSTRATES=OFF`. Skrypt wykrywa lokalny build ablacyjny
(`build/Release-Ablation/*` z `RDB_OPT_DEDUP_SUBSTRATES:BOOL=OFF` w `CMakeCache.txt`),
przebudowuje w nim `xretractor` albo
wymaga wskazania go przez `XRETRACTOR_NO_DEDUP=/sciezka/do/xretractor`.
