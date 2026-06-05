# Przykłady zastosowań

W niniejszym rozdziale zostaną przedstawione krótkie przykłady zastosowania systemu RetractorDB w rozwiązaniu konkretnych zagadnień spotykanych w konstrukcjach systemów monitorowania.

Każdy przykład jest kompletny — zawiera opis problemu, projekt zapytań RQL, uruchomienie oraz interpretację wyników. Przykłady można uruchomić samodzielnie: wymagane pliki danych i skrypty są opisane krok po kroku.

**Filtracja sygnałów (FIR)**

Przykład demonstruje, jak zrealizować **cyfrowy filtr FIR** bezpośrednio w strumieniu zapytań RQL, bez zewnętrznych bibliotek DSP. Zagadnienie jest reprezentatywne dla szerokiej klasy problemów przetwarzania sygnałów: filtracja szumów, separacja pasm częstotliwości, wygładzanie serii czasowych.

Przykład obejmuje:

- projektowanie współczynników filtru w programie GNU Octave (algorytm Remeza, metoda `remez()`),
- przeniesienie współczynników do pliku tekstowego i wczytanie ich jako strumień `DECLARE`,
- implementację splotu dyskretnego jako zestawu zapytań `SELECT` z operatorem ruchomego okna `@` i rozwinięciem symbolu `_`,
- wizualizację przebiegu filtracji w czasie rzeczywistym za pomocą `xqry` i `gnuplot`.

Wynikiem jest działający system filtrujący sygnał pseudolosowy (50 Hz) do pasma 0–2 Hz, obserwowany na żywo podczas działania xretractor.

Pełny opis: [Implementacja filtru sygnałowego](implementacja-filtru-sygnalowego.md)

**Analiza sygnałów EKG (MIT-BIH)**

Przykład demonstruje zastosowanie RetractorDB do **przetwarzania klinicznych sygnałów EKG** z publicznej bazy MIT-BIH Arrhythmia Database (PhysioNet). Jest to złożony przypadek użycia łączący kilka mechanizmów systemu: wielokanałowe strumienie wejściowe, wieloetapowy potok filtracji FIR, adaptacyjny próg detekcji oraz wizualizację w czasie rzeczywistym.

Przykład obejmuje:

- przygotowanie danych: konwersja nagrań MIT-BIH (format WFDB) do plików tekstowych kompatybilnych z RetractorDB,
- implementację pięcioetapowego algorytmu Pan-Tompkins w RQL: filtr pasmowoprzepustowy → różniczkowanie → potęgowanie → całkowanie ruchome → detekcja progowa,
- wizualizację sygnału EKG i wyniku detekcji QRS w oknie gnuplot (tryb RTL — najnowsze próbki po prawej),
- interpretację wyników: odczyty interwałów RR, identyfikacja epizodów arytmii na rekordzie 205 MIT-BIH.

Wynikiem jest działający detektor QRS przetwarzający dwukanałowy sygnał EKG (MLII + V1) z częstotliwością 360 Hz, realizowany wyłącznie zapytaniami RQL bez specjalistycznych bibliotek.

Pełny opis: [Wizualizacja EKG i detekcja arytmii](wizualizacja-ekg-mit-bih.md)
