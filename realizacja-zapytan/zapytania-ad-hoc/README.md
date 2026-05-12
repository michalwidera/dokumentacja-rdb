---
icon: rectangle-ad
---

# Zapytania Ad hoc

"Ad hoc" to łacińskie wyrażenie oznaczające "doraźnie", "w tym celu" lub "specjalnie". Używa się go do opisania działań, spotkań czy projektów realizowanych jednorazowo, bez długoterminowego planu, w odpowiedzi na konkretną potrzebę lub problem.

Przez zapytania Ad hoc rozumiemy zapytania kierowane do działającego systemu. W typowym scenariuszu jaki zakładano w przypadku rozwoju systemu, założono we wstępnie rozpatrywanych scenariuszach, że użytkownik systemu będzie znał wszystkie zapytania i źródła danych wymagane do uzyskania przetworzonych serii czasowych.

W trakcie rozwoju systemu pojawiły się jednak dodatkowe scenariusze, zakładające, że praca systemu nie powinna być przerywana a dodatkowe zapytania powinny zostać dołączone do planu realizacji zapytań. Tego typu funkcjonalność będziemy nazywać zapytaniami Ad hoc, dołączanymi do systemu w trakcie jego działania bez przerywania jego pracy.

<figure><img src="../../.gitbook/assets/przeplyw_sterowania_adhoc.png" alt=""><figcaption><p>Rys. 31 Przepływ sterowania dla zapytań Ad Hoc</p></figcaption></figure>

Na Rys. 31 przedstawiono opisany powyżej przepływ sterowania. Plik z zapytaniami i dyrektywami najpierw jest kierowany do procesu xretractor. Następnie poprzez pamięć współdzieloną proces xqry pobiera dane z xretractor. Tym samym procesem możemy wysłać do procesu xretractor polecenie. W tym poleceniu zawieramy tekst dodatkowego zapytania, które xretractor powinien dołączyć do przetwarzanego drzewa.
