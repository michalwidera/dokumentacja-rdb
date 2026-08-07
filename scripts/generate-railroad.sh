#!/usr/bin/env bash
# generate-railroad.sh — aktualizuje diagramy railroad (assets/railroad-*.svg)
# na podstawie gramatyki ANTLR4 RQL.g4 z repozytorium retractordb.
#
# Użycie:
#   scripts/generate-railroad.sh              # regeneruje wersję PL i EN
#   scripts/generate-railroad.sh --lang pl    # tylko dokumentacja-rdb
#   scripts/generate-railroad.sh --check      # tylko sprawdza aktualność
#   scripts/generate-railroad.sh --grammar ŚCIEŻKA/RQL.g4
#
# Zakłada, że repozytoria leżą obok siebie:
#   …/dokumentacja-rdb    (to repozytorium — diagramy z polskimi etykietami)
#   …/documentation-rdb   (wersja angielska — etykiety po angielsku)
#   …/retractordb         (kod źródłowy z RQL.g4)
#
# Właściwą pracę wykonuje scripts/generate_railroad.py; wymaga biblioteki
# railroad-diagrams — instaluje ją scripts/install-local-tools.sh --install

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRAMMAR="${RQL_GRAMMAR:-$REPO_DIR/../retractordb/src/retractor/lib/RQL.g4}"
EN_REPO="${EN_REPO:-$REPO_DIR/../documentation-rdb}"
LANGS="all"
DO_CHECK=0

usage() {
  cat <<EOF
Użycie: $(basename "$0") [OPCJE]

Generuje diagramy składni (railroad) poleceń SELECT, DECLARE, RULE oraz
dyrektyw konfiguracyjnych na podstawie gramatyki RQL.g4 i zapisuje je jako
railroad-select.svg, railroad-declare.svg, railroad-rule.svg oraz
railroad-dyrektywy.svg do katalogów assets/ obu wersji językowych:

  pl -> $REPO_DIR/assets
  en -> $EN_REPO/assets

Domyślnie szuka gramatyki w repozytorium obok tego repozytorium:
  $REPO_DIR/../retractordb/src/retractor/lib/RQL.g4

Opcje:
  --lang pl|en|all     która wersja językowa (domyślnie: all)
  --check              nie zapisuje plików; kod wyjścia 1, gdy diagramy
                       w assets/ są nieaktualne względem gramatyki
  --grammar ŚCIEŻKA    inna lokalizacja pliku RQL.g4
                       (to samo robi zmienna środowiskowa RQL_GRAMMAR)
  -h, --help           wyświetla tę pomoc

Zmienne środowiskowe:
  RQL_GRAMMAR  ścieżka do RQL.g4
  EN_REPO      katalog repozytorium documentation-rdb

Przykłady:
  $(basename "$0")                                  # zaktualizuj PL i EN
  $(basename "$0") --lang en                        # tylko wersja angielska
  $(basename "$0") --check                          # sprawdź aktualność
  $(basename "$0") --grammar ~/src/rdb/RQL.g4       # inna gramatyka

Brakująca biblioteka railroad-diagrams:
  $REPO_DIR/scripts/install-local-tools.sh --install
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check)    DO_CHECK=1; shift ;;
    --lang)     LANGS="${2:-}"
                case "$LANGS" in
                  pl|en|all) ;;
                  *) echo "--lang przyjmuje: pl, en, all (jest: '${LANGS}')" >&2; exit 1 ;;
                esac
                shift 2 ;;
    --grammar)  GRAMMAR="${2:-}"; [ -n "$GRAMMAR" ] || { echo "--grammar wymaga ścieżki" >&2; exit 1; }; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "Nieznany argument: $1 (zobacz --help)" >&2; exit 1 ;;
  esac
done

[ "$LANGS" = "all" ] && LANGS="pl en"

# kolory tylko gdy terminal je obsługuje (i nie ustawiono NO_COLOR)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ] \
   && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  C_GREEN="$(tput setaf 2)"; C_RED="$(tput setaf 1)"; C_RESET="$(tput sgr0)"
else
  C_GREEN=""; C_RED=""; C_RESET=""
fi

# --- wymagania -----------------------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
  printf "  ${C_RED}[BRAK]${C_RESET}  python3\n" >&2
  echo "Zainstaluj: sudo apt-get install python3" >&2
  exit 1
fi

if ! python3 -c "import railroad" >/dev/null 2>&1; then
  printf "  ${C_RED}[BRAK]${C_RESET}  railroad-diagrams (biblioteka Pythona)\n" >&2
  echo >&2
  echo "Zainstaluj ją poleceniem:" >&2
  echo "  $REPO_DIR/scripts/install-local-tools.sh --install" >&2
  exit 1
fi

if [ ! -f "$GRAMMAR" ]; then
  printf "  ${C_RED}[BRAK]${C_RESET}  gramatyka: %s\n" "$GRAMMAR" >&2
  echo >&2
  echo "Sklonuj repozytorium retractordb obok tego repozytorium:" >&2
  echo "  cd $REPO_DIR/.. && git clone https://github.com/michalwidera/retractordb.git" >&2
  echo "albo wskaż plik: $(basename "$0") --grammar ŚCIEŻKA/RQL.g4" >&2
  exit 1
fi

printf "  ${C_GREEN}[OK]${C_RESET}    %-14s %s\n" "gramatyka" "$GRAMMAR"

outdir_for() {
  case "$1" in
    pl) echo "$REPO_DIR/assets" ;;
    en) echo "$EN_REPO/assets" ;;
  esac
}

# --- generowanie ---------------------------------------------------------------
status=0
generated=0
for lang in $LANGS; do
  outdir="$(outdir_for "$lang")"
  if [ ! -d "$outdir" ]; then
    printf "  ${C_RED}[BRAK]${C_RESET}  katalog wersji '%s': %s\n" "$lang" "$outdir" >&2
    if [ "$lang" = "en" ]; then
      echo "         sklonuj documentation-rdb obok tego repozytorium albo ustaw EN_REPO" >&2
      echo "         (pomijam wersję angielską)" >&2
      status=1
      continue
    fi
    exit 1
  fi

  echo "== wersja '$lang' -> $outdir"
  if [ "$DO_CHECK" -eq 1 ]; then
    python3 "$REPO_DIR/scripts/generate_railroad.py" \
      --grammar "$GRAMMAR" --outdir "$outdir" --lang "$lang" --check || status=1
  else
    python3 "$REPO_DIR/scripts/generate_railroad.py" \
      --grammar "$GRAMMAR" --outdir "$outdir" --lang "$lang"
    generated=1
  fi
done

if [ "$DO_CHECK" -eq 1 ]; then
  if [ "$status" -eq 0 ]; then
    printf "${C_GREEN}Diagramy są aktualne.${C_RESET}\n"
  fi
  exit "$status"
fi

if [ "$generated" -eq 1 ]; then
  printf "${C_GREEN}Gotowe.${C_RESET} Sprawdź zmiany:\n"
  for lang in $LANGS; do
    outdir="$(outdir_for "$lang")"
    [ -d "$outdir" ] && echo "  git -C $(dirname "$outdir") diff --stat assets/"
  done
fi
exit "$status"
