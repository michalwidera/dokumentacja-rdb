#!/usr/bin/env bash
# build-book.sh — buduje dokumentację RetractorDB do plików HTML (katalog book/).
#
# Użycie:
#   scripts/build-book.sh            # buduje stronę www do katalogu book/
#   scripts/build-book.sh --clean    # czyści katalog book/ i buduje od zera
#   scripts/build-book.sh --serve    # buduje i uruchamia podgląd na żywo
#
# Skrypt korzysta wyłącznie z już zainstalowanych narzędzi (mdbook,
# mdbook-mermaid) — niczego nie instaluje. Brakujące narzędzia doinstalujesz
# poleceniem: scripts/install-local-tools.sh --install

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DO_CLEAN=0
DO_SERVE=0

usage() {
  cat <<EOF
Użycie: $(basename "$0") [OPCJE]

Buduje dokumentację RetractorDB do plików HTML w katalogu book/
(odpowiednik kroku "Build" z .github/workflows/deploy.yml).
Korzysta wyłącznie z zainstalowanych narzędzi — niczego nie instaluje.

Opcje:
  --clean     usuwa katalog book/ przed budową (build od zera)
  --serve     po zbudowaniu uruchamia 'mdbook serve --open'
              (podgląd na żywo z przeładowywaniem po zmianach)
  -h, --help  wyświetla tę pomoc

Przykłady:
  $(basename "$0")              # zbuduj stronę do book/
  $(basename "$0") --clean      # wyczyść i zbuduj od zera
  $(basename "$0") --serve      # zbuduj i otwórz podgląd na żywo

Brakujące narzędzia: scripts/install-local-tools.sh --install
EOF
}

for arg in "$@"; do
  case "$arg" in
    --clean)    DO_CLEAN=1 ;;
    --serve)    DO_SERVE=1 ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "Nieznany argument: $arg (zobacz --help)" >&2; exit 1 ;;
  esac
done

# kolory tylko gdy terminal je obsługuje (i nie ustawiono NO_COLOR)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ] \
   && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  C_GREEN="$(tput setaf 2)"; C_RED="$(tput setaf 1)"; C_RESET="$(tput sgr0)"
else
  C_GREEN=""; C_RED=""; C_RESET=""
fi

# --- wymagane narzędzia --------------------------------------------------------
missing=0
for tool in mdbook mdbook-mermaid; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf "  ${C_GREEN}[OK]${C_RESET}    %-14s %s\n" "$tool" "$("$tool" --version 2>/dev/null | head -1)"
  else
    printf "  ${C_RED}[BRAK]${C_RESET}  %s\n" "$tool"
    missing=1
  fi
done
if [ "$missing" -ne 0 ]; then
  echo >&2
  echo "Brakujące narzędzia. Zainstaluj je poleceniem:" >&2
  echo "  $REPO_DIR/scripts/install-local-tools.sh --install" >&2
  exit 1
fi

cd "$REPO_DIR"

# --- build ---------------------------------------------------------------------
if [ "$DO_CLEAN" -eq 1 ]; then
  echo "Czyszczę katalog book/ ..."
  mdbook clean
fi

mdbook-mermaid install .
mdbook build

printf "${C_GREEN}Gotowe.${C_RESET} Strona wyrenderowana w: %s/book/\n" "$REPO_DIR"

if [ "$DO_SERVE" -eq 1 ]; then
  echo "Uruchamiam podgląd na żywo (Ctrl+C kończy) ..."
  mdbook serve --open
fi
