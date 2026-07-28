# Ogony i obserwowalność operatorów

Wykonanie przyczynowe rozszerza strumień \\(S=(s_n,\Delta_S)\\) o ogon
startowy \\(W_S\\). Jest to liczba początkowych slotów interwału
\\(\Delta_S\\), w których strumień nie emituje rekordu. Ogon nie jest
prefiksem zer ani rekordów all-null.

## Audyt operatorów

W tabeli „własny ogon” oznacza opóźnienie wymagane przez operator ponad
dostępność producentów. Ogony producentów są wcześniej przeliczane na sloty
wyniku.

| Operator | Indeks źródłowy lub granica | Własny ogon | Test |
|---|---|---:|---|
| projekcja / `PUSH_STREAM` | bieżąca krotka | 0 | `ut_compiler` |
| przesunięcie `>N` | slot historii `N` | N | `ut_compiler` |
| suma `+` | bieżące współindeksowane krotki | 0 | `ut_compiler` |
| przeplot `#` | maksimum faz \\(H_{a,b}\\) | \\(H_{a,b}\\) | `deinterleave_roundtrip` |
| lewy rozplot `&` (`DIV`) | \\(n+\lceil(n+1)\Delta_a/\Delta_b\rceil\\) | 1 | `deinterleave_roundtrip` |
| prawy rozplot `%` (`MOD`) | \\(n+\lfloor n\Delta_b/\Delta_a\rfloor\\) | 0 | `deinterleave_roundtrip` |
| różnica `C-Delta` | \\(\lceil n\Delta/\Delta_C\rceil\\) | fazowy, najwyżej 1 przy \\(\Delta\ge\Delta_C\\) | `it_k19_boundaries` |
| AGSE `@(k,L)` | pola od \\(nk\\) do \\(nk+\lvert L\rvert-1\\) | fazowy, wzór poniżej | `agse1`, `agse2`, `agse3`, `it_k19_boundaries` |
| `sumc`, `avgc`, `minc`, `maxc` | bieżąca pełna krotka | 0 | `ut_dataModel`, `it_k19_boundaries` |

Różnica przyjmuje docelowy interwał \\(\Delta\\), który nie może być mniejszy
od interwału źródła \\(\Delta_C\\). Dla stosunku
\\(r=\Delta/\Delta_C=p/q\\) maksymalne wyprzedzenie fazowe indeksu
\\(\lceil nr\rceil\\) wynosi \\((q-1)/q\\). Producent deklarowany wymaga
jednego slotu również w fazie całkowitej, ponieważ publikuje następny rekord
po odczycie konsumentów w tym samym takcie.

## Pełne okno AGSE

Niech źródło ma \\(F\\) pól, krok okna wynosi \\(k\\), jego szerokość
\\(L\ne0\\), a \\(g=\gcd(F,k)\\). Reszty \\(nk\bmod F\\) przebiegają
wielokrotności \\(g\\). Największe wyprzedzenie ostatniego pola okna wynosi:

\\[
P_{F,k,L}
=\left\lfloor\frac{|L|-1}{g}\right\rfloor g
\\]

Dla ogona producenta \\(W_S\\) całkowity ogon AGSE ma postać:

\\[
W_{\operatorname{AGSE}}
=\left\lfloor\frac{F W_S+P_{F,k,L}}{k}\right\rfloor+1
\\]

Nierówność jest ostra: odczyt historii nie może zakładać, że rekord aktywnego
producenta został już domknięty w tym samym takcie. Dzięki temu każdy
wyemitowany rekord zawiera całe okno. Dodatnia szerokość zachowuje historyczną
konwencję RetractorDB — najnowsze pole jest pierwsze; ujemna szerokość daje
odbicie lustrzane, czyli kolejność napływu.

Historia źródła musi dodatkowo pokryć najgorszą fazę
\\((F-g)/F\\). Dla producenta obliczanego minimalna liczba rekordów historii
wynosi:

\\[
\left\lceil
W_{\operatorname{AGSE}}\frac{k}{F}-W_S+\frac{F-g}{F}
\right\rceil
\\]

Źródło deklarowane ma rekord uzbrojony przy otwarciu storage i zerowy
prefetch, dlatego jego granica pojemności zawiera dwa dodatkowe rekordy.
Pojemność jest własnością wykonania, nie częścią wyniku.

## Relacja obserwowalności

Dla K19 obserwacja strumienia jest krotką:

\\[
\operatorname{Obs}(S)
=\left(\Delta_S,W_S,D_S,(s_n,N_n)_{n\ge0},G_S,M_S\right)
\\]

gdzie:

* \\(D_S\\) jest publicznym deskryptorem i kolejnością nazw pól;
* \\(N_n\\) jest mapą `NULL` rekordu — prawdziwy `NULL` pozostaje wartością
  danych i jest przenoszony przez AGSE;
* \\(G_S\\) jest śladem luk; obecnie detekcja działa dla deklaracji, a dla
  strumieni obliczanych obowiązuje \\(G_S=\varnothing\\);
* \\(M_S\\) opisuje politykę materializacji (`DEFAULT`, `MEMORY`, `VOLATILE`
  i pozostałe storage).

Zmiana którejkolwiek składowej zmienia obserwowalny artefakt. W szczególności
przyszłe włączenie propagacji luk w strumieniach obliczanych wymaga
wersjonowanej zmiany semantyki.

Odczyt poza dostępną historią zwraca wewnętrznie rekord all-null jako
bezpiecznik. Poprawnie skompilowany plan nigdy go nie materializuje:
`startupLatency` pomija nieokreślone sloty, a pojemność historii zachowuje
każdy wymagany indeks. Test `it_k19_boundaries` rozróżnia ten przypadek od
prawdziwego `NULL` znajdującego się wewnątrz pełnego okna.

Niezależny oracle i pełna kampania faz znajdują się w
`rdb-experiment/results_20260728_K19`.
