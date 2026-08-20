# Ogony, początki logiczne i obserwowalność operatorów

Wykonanie przyczynowe rozszerza strumień \\(S=(s_n,\Delta_S)\\) o **dwie**
wielkości całkowite, a nie o jedną. Rozróżnienie jest istotne, bo odpowiadają
na różne pytania i różnie zachowują się przy przepisaniach planu.

| Wielkość | Pytanie | Znaczenie |
|---|---|---|
| początek logiczny \\(O_S\\) | *którego rekordu nie ma?* | indeks pierwszego rekordu, który **w ogóle istnieje**; rekordy o mniejszym indeksie nie mają definicji, bo sięgałyby przed początek strumienia źródłowego |
| ogon startowy \\(W_S\\) | *kiedy rekord jest gotowy?* | rekord \\(n\\) jest emitowany w chwili \\((n+1+W_S)\Delta_S\\) |

Żadna z nich nie jest prefiksem zer ani rekordów all-null. Zasada brzegu
obowiązuje bez zmian: `NULL` jest wartością danych, nigdy rezerwacją miejsca.
Liczba początkowych slotów, w których strumień milczy, wynosi
\\(O_S+W_S\\) — i tylko ta suma była widoczna przed rozdzieleniem obu wielkości.

Indeks logiczny jest walutą wszystkich odwzorowań między strumieniami.
Strumień o niezerowym \\(O_S\\) nie ma rekordów wcześniejszych, więc jego
rekord fizyczny 0 nosi indeks logiczny \\(O_S\\); przeliczenie na offset
w buforze wykonuje wyłącznie `dataModel::fetchForward()`.

## Audyt operatorów

W tabeli „własny ogon” oznacza opóźnienie wymagane przez operator ponad
dostępność producentów. Ogony producentów są wcześniej przeliczane na sloty
wyniku.

| Operator | Indeks źródłowy lub granica | Początek logiczny | Własny ogon | Test |
|---|---|---|---:|---|
| projekcja / `PUSH_STREAM` | bieżąca krotka | \\(O_S\\) | 0 | `ut_compiler` |
| przesunięcie `>N` | rekord \\(n-N\\) | \\(O_S+N\\) | \\(-N\\), patrz niżej | `ut_compiler`, `ut_h10aGate` |
| suma `+` | bieżące współindeksowane krotki | próg odwzorowania | 0 | `ut_compiler` |
| przeplot `#` | rekord \\(j(i)\\) składowej wybranej w slocie \\(i\\) | próg odwzorowania | wzór niżej | `deinterleave_roundtrip`, `ut_h10aGate` |
| lewy rozplot `&` (`DIV`) | \\(n+\lceil(n+1)\Delta_a/\Delta_b\rceil\\) | próg odwzorowania | wzór fazowy poniżej | `deinterleave_roundtrip`, `ut_h10aGate` |
| prawy rozplot `%` (`MOD`) | \\(n+\lfloor n\Delta_b/\Delta_a\rfloor\\) | próg odwzorowania | wzór fazowy poniżej | `deinterleave_roundtrip`, `ut_h10aGate` |
| różnica `C-Delta` | \\(\lceil n\Delta/\Delta_C\rceil\\) | próg odwzorowania | wzór fazowy poniżej | `it_k19_boundaries`, `ut_h10aGate` |
| AGSE `@(k,L)` | pola od \\(nk-(\lvert L\rvert-1)\\) do \\(nk\\) | wzór niżej | wzór niżej | `agse1`, `agse2`, `agse3`, `it_k19_boundaries`, `ut_h10aGate` |
| `sumc`, `avgc`, `minc`, `maxc` | bieżąca pełna krotka | \\(O_S\\) | 0 | `ut_dataModel`, `it_k19_boundaries` |

„Próg odwzorowania” oznacza najmniejszy indeks \\(n\\), **od którego** wszystkie
dalsze rekordy trafiają odwzorowaniem w istniejące rekordy składowych.
Nie jest to „pierwszy indeks o kompletnych zależnościach”: przy przeplocie
składowych o różnych początkach rekord 0 może mieć komplet, a rekord 1 już nie.
Strumień jest ciągiem rekordów, nie zbiorem z dziurami — zasada brzegu zabrania
wypełnić lukę `NULL`-em — więc początkiem logicznym jest pierwszy indeks bez
żadnej dalszej luki. Wszystkie odwzorowania rekord–rekord są niemalejące, więc
taki indeks istnieje i jest jednoznaczny.

Różnica przyjmuje docelowy interwał \\(\Delta\\), który nie może być mniejszy
od interwału źródła \\(\Delta_C\\). Dla stosunku
\\(r=\Delta/\Delta_C=p/q\\) maksymalne wyprzedzenie fazowe indeksu
\\(\lceil nr\rceil\\) wynosi \\((q-1)/q\\).

## Ogony operatorów fazowych

Różnica oraz oba rozploty używają wspólnej reguły dostępności. Niech
\\(r=\Delta_{out}/\Delta_{src}\\), \\(W_S\\) będzie ogonem źródła, a
\\(e_{max}\\) — największą osiąganą fazą odwzorowania indeksu. Wtedy:

\\[
W_{out}=\max\left(0,
\left\lceil\frac{e_{max}+W_S+1}{r}\right\rceil-1
\right)
\\]

Dla różnicy \\(e_{max}=(q-1)/q\\), gdzie \\(q\\) jest mianownikiem
skróconego stosunku \\(r\\). Dla lewego rozplotu, przy
\\(\Delta_{out}/\Delta_{other}=a/b\\), wartość wynosi
\\(e_{max}=(a+b-1)/b\\). Dla prawego rozplotu \\(e_{max}=0\\). Oznacza to
między innymi, że lewy rozplot nie dodaje bezwarunkowo jednego slotu: dla
stosunku całkowitego jego własny ogon może wynosić zero.

## Ogon przeplotu

Przeplot jest jedynym operatorem, którego ogon nie rozkłada się na „przeliczone
ogony producentów plus stała własna". Rekord \\(i\\) niesie treść rekordu
\\(j(i)\\) tylko jednej ze składowych — tej, którą w slocie \\(i\\) wybiera
definicja operatora — więc wymagane opóźnienie zależy od tego, na którą
składową i na którą jej fazę wypada dany slot:

\\[
W_{\\#}
=\max_{0\le i<p+q}\left(
\left\lceil\frac{\bigl(j(i)+1+W_{s(i)}\bigr)\Delta_{s(i)}}{\Delta_c}\right\rceil
-1-i
\right),
\qquad \frac{\Delta_a}{\Delta_b}=\frac{p}{q},\quad \gcd(p,q)=1
\\]

Wybór składowej i faza powtarzają się z okresem \\(p+q\\), więc maksimum po
jednym okresie jest maksimum po wszystkich rekordach; początek logiczny
przesuwa oba indeksy o tyle samo i nie zmienia wyniku. Wzór jest dokładny.
Dla okresów przekraczających `kHashPhaseScanLimit` implementacja używa
bezpiecznej postaci zamkniętej. Może ona opóźnić emisję, ale nie może dopuścić
do emisji rekordu przed udostępnieniem jego zależności.

## Przesunięcie \\(\tau_N\\)

Rekord \\(n\\) niesie treść rekordu \\(n-N\\) producenta. Stąd obie wielkości:

\\[
O_{\tau_N(S)}=O_S+N,
\qquad
W_{\tau_N(S)}=\max\left(0,\;W_S-N\right)
\\]

Ogon **maleje**, a nie rośnie. Rekord \\(n-N\\) jest starszy od bieżącego, więc
jest dostępny tym bardziej: deficyt slotu \\(n\\) wynosi
\\((n-N+1+W_S)-(n+1)=W_S-N\\) i jest **stały**, niezależny od \\(n\\).
Przesunięcie przenosi więc milczenie z ogona do początku logicznego i dodatkowo
pochłania ogon producenta, gdy \\(N\ge W_S\\).

Suma \\(O+W\\) nie jest przy tym niezmiennikiem: dla \\(N<W_S\\) wynosi
\\(N+W_S-N=W_S\\) po lewej, a była \\(W_S+N\\) w realizacji sprzed
rozdzielenia wielkości. Wcześniejsza realizacja zawyżała ogon o
\\(\min(W_S,N)\\); zawyżenie zdjęto, adresując producenta indeksem
logicznym zamiast offsetem względnym.

## Pełne okno AGSE

Okno jest stemplowane **końcem** przedziału: rekord \\(n\\) obejmuje spłaszczone
pozycje źródła od \\(nk-(\lvert L\rvert-1)\\) do \\(nk\\). Dzięki temu jego
najnowsze pole leży dokładnie w pozycji \\(nk\\), a indeks logiczny okna oznacza
tę samą chwilę co indeks logiczny źródła — złączenie okna z jego własnym
źródłem (potok FIR) nie wyprzedza sygnału.

Ceną konwencji jest to, że dla małych \\(n\\) okno sięgałoby przed początek
źródła. Te rekordy nie powstają. Niech źródło ma \\(F\\) pól i początek
logiczny \\(O_S\\); warunek zmieszczenia się całego okna daje

\\[
O_{\operatorname{AGSE}}
=\left\lceil\frac{O_S F+\lvert L\rvert-1}{k}\right\rceil
\\]

O dostępności decyduje pole najnowsze, leżące w rekordzie
\\(\lfloor nk/F\rfloor\\). Podstawiając \\(r_n=(nk)\bmod F\\) warunek
dostępności dla każdego \\(n\\) przyjmuje postać
\\(W\ge\bigl(F(1+W_S)-r_n\bigr)/k-1\\). Reszty \\(r_n\\) przebiegają
wielokrotności \\(\gcd(F,k)\\) okresowo, więc minimum \\(r_n=0\\) jest osiągane
niezależnie od tego, od którego \\(n\\) zaczyna się strumień. Stąd

\\[
W_{\operatorname{AGSE}}
=\left\lceil\frac{(1+W_S)F}{k}\right\rceil-1
\\]

Człon fazowy \\(P_{F,k,L}=\lfloor(\lvert L\rvert-1)/g\rfloor\,g\\), obecny
w postaci sprzed przestemplowania, **zniknął z ogona**: rozpiętość okna nie jest
czekaniem, tylko niedefiniowalnością, i przeszła w całości do początku
logicznego. Suma \\(O+W\\) opisuje to samo milczenie co poprzednio.

Dodatnia szerokość zachowuje historyczną konwencję RetractorDB — najnowsze pole
jest pierwsze; ujemna szerokość daje odbicie lustrzane, czyli kolejność napływu.

Pojemność historii źródła nie ma tu postaci zamkniętej. Odległość wsteczna
w chwili emisji rekordu \\(n\\),

\\[
\left\lfloor\frac{(n+1+W)k}{F}\right\rfloor-W_S-1
\;-\;
\left\lfloor\frac{nk-\lvert L\rvert+1}{F}\right\rfloor,
\\]

jest okresowa o okresie \\(F/\gcd(F,k)\\) slotów wyjścia, więc maksimum liczy się
**dokładnie**, przeglądając jeden pełny okres od \\(O_{\operatorname{AGSE}}\\).
Postać zamknięta byłaby w tym miejscu domysłem, a zaniżenie oznacza odczyt poza
historią, nie tylko slot opóźnienia. Źródło deklarowane ma rekord uzbrojony przy
otwarciu storage i zerowy prefetch, dlatego jego granica pojemności zawiera dwa
dodatkowe rekordy. Pojemność jest własnością wykonania, nie częścią wyniku.

## Relacja obserwowalności

Obserwacja strumienia rozpada się na dwie części, bo przepisania planu
zachowują je w różnym stopniu.

**Część wartościowa** — zachowywana przez przepisania dokładnie:

\\[
\operatorname{Obs}(S)
=\left(\Delta_S,O_S,D_S,(s_n,N_n)_{n\ge O_S},G_S,M_S\right)
\\]

gdzie:

* \\(O_S\\) jest początkiem logicznym, czyli indeksem pierwszego rekordu;
* \\(D_S\\) jest publicznym deskryptorem i kolejnością nazw pól;
* \\(N_n\\) jest mapą `NULL` rekordu — prawdziwy `NULL` pozostaje wartością
  danych i jest przenoszony przez AGSE;
* \\(G_S\\) jest śladem luk; obecnie detekcja działa dla deklaracji, a dla
  strumieni obliczanych obowiązuje \\(G_S=\varnothing\\);
* \\(M_S\\) opisuje politykę materializacji (`DEFAULT`, `MEMORY`, `VOLATILE`
  i pozostałe storage).

**Część opóźnieniowa** — ogon \\(W_S\\) — podlega słabszej gwarancji:

> przepisanie planu nigdy nie **zwiększa** \\(W_S\\) i nigdy nie emituje rekordu
> przed określeniem jego zależności; wolno mu natomiast \\(W_S\\) **zmniejszyć**.

Rozdzielenie nie jest formalnością. Faktoryzacja \\(R_1\\)
(\\(\varphi(\tau_i(A),\tau_k(B))\to\tau_{i+k}(\varphi(A,B))\\)) zachowuje całą
część wartościową, ale **skraca** ogon: postać sfaktoryzowana czyta treść
bezpośrednio z przeplotu, podczas gdy postać niefaktoryzowana czyta składowe
dopiero po ich własnym przesunięciu. Uzasadnienie: [Formalne podstawy
i dowody](formalne-podstawy-i-dowody.md), twierdzenie o przemienności
przesunięcia z przeplotem. Regresje: `it_r1_identity_nulls`,
`it_optimizer_ablation-factor-name-collision-semantic`.

Zmiana którejkolwiek składowej części wartościowej zmienia obserwowalny
artefakt. W szczególności przyszłe włączenie propagacji luk w strumieniach
obliczanych wymaga wersjonowanej zmiany semantyki.

Odczyt poza dostępną historią zwraca wewnętrznie rekord all-null jako
bezpiecznik. Poprawnie skompilowany plan nigdy go nie materializuje:
`logicalOrigin` pomija sloty bez definicji, `startupLatency` — sloty jeszcze
nieokreślone, a pojemność historii zachowuje każdy wymagany indeks. Test
`it_k19_boundaries` rozróżnia ten przypadek od prawdziwego `NULL` znajdującego
się wewnątrz pełnego okna.

Wzory operatorowe z tego rozdziału są egzekwowane przy każdym commicie: granice
i obserwowalność przez `it_k19_boundaries`, głębokości historii przez
`it_k24_capacity`, a zgodność początku logicznego i ogona wszystkich
kanonicznych klas operatorów oraz ich złożeń przez test jednostkowy
`ut_h10aGate`.
