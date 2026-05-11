---
description: Opis powiązań i elementów z których zbudowany jest cały system.
---

# Architektura systemu

Konstrukcja systemu przetwarzania danych to rozdział stricte techniczny. Przedstawię tutaj jak system został zaprojektowany, zbudowany gdzie i jak obecnie rozmieszczone są jego funkcjonalności.

System RetractorDB został zaimplementowany w języku C++ pod kontrolą systemu Linux. Kod źródłowy podlega procesowi ciągłej integracji i testowania na platformie GitHub wspieranej przez CircleCI. Kod uruchamiany i rozwijany jest lokalnie na platformie Linux WSL2. Porzuciłem rozwój i implementację systemu pod kontrolą systemu Windows. W początkowej fazie utrzymywałem taką opcję i być może w przyszłości do niej powrócę. Jednak utrzymanie zbyt wielu platform rozwojowych znacząco opóźnia proces szybkiego prototypowania i rozwoju systemu. Nadal zachowuję i utrzymuję funkcjonalność systemu na platformie Linux ARM. Kod kompiluję i testuje się pod kontrolą maszyn opartych na architekturze ARM i x86-64 pracujących w zasobach CircleCI. Raspberry PI to jedna z docelowych platform produkcyjnych systemu RetractorDB przewidziana dla potrzeb Edge IoT.

Kompilacja kodu systemu odbywa się ze wsparciem managera pakietów Conan \[[8](../literatura.md)]. Jeśli chcemy poznać jak zbudowany jest toolchain budujący kod systemu możemy zajrzeć do pliku /.circleci/config.yml zawierający procedurę budowy i uruchamiania systemu w środowisku kontenerów lub maszyn firmy CircleCI. W plikach `/docker/ci/Dockerfile` oraz `/docker/ci/DockerConan.txt` znajdują się instrukcje w jaki sposób obraz kontenera budującego system z prekonfigurowanymi dependencjami. Analiza tych plików wskaże co jest potrzebne i jak należy zainstalować w swoim systemie aby źródła systemu skompilować lokalnie u siebie.
