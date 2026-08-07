#!/usr/bin/env bash
# install-local-tools.sh — narzędzia do lokalnego renderowania dokumentacji
# RetractorDB (odpowiednik kroków z .github/workflows/deploy.yml).
#
# Użycie:
#   scripts/install-local-tools.sh              # tylko sprawdza stan systemu
#   scripts/install-local-tools.sh --install    # instaluje narzędzia strony www
#   scripts/install-local-tools.sh --with-pdf   # instaluje www + toolchain PDF/EPUB
#
# Zakłada system Debian/Ubuntu (apt) dla zależności systemowych.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
DO_INSTALL=0
WITH_PDF=0

usage() {
  cat <<EOF
Użycie: $(basename "$0") [OPCJE]

Narzędzia do lokalnego renderowania dokumentacji RetractorDB — odpowiednik
kroków z .github/workflows/deploy.yml. Zakłada system Debian/Ubuntu.

Bez opcji skrypt działa w trybie TYLKO DO ODCZYTU: sprawdza, które narzędzia
są zainstalowane, czego brakuje, i wypisuje polecenie instalacji.
Nic nie zmienia w systemie.

Opcje:
  --install    instaluje narzędzia strony www:
               1. brakujące pakiety systemowe (curl, tar) przez apt,
               2. najnowszy release mdBook z GitHuba,
               3. prebuilt binarkę mdbook-mermaid (bez instalowania Rusta),
               4. uruchamia 'mdbook-mermaid install .' oraz 'mdbook build',
                  generując stronę www do katalogu book/
  --with-pdf   jak --install, plus toolchain PDF/EPUB z workflow:
               pandoc, texlive-xetex, texlive-lang-polish, texlive-latex-extra,
               fonts-dejavu, librsvg2-bin, imagemagick oraz mermaid-cli przez npm
               (uwaga: ok. 2 GB pobieranych danych)
  -h, --help   wyświetla tę pomoc

Zmienne środowiskowe:
  INSTALL_DIR  katalog instalacji binarek (domyślnie: \$HOME/.local/bin);
               np. INSTALL_DIR=/usr/local/bin $(basename "$0") --install

Przykłady:
  $(basename "$0")                 # sprawdź stan systemu (bez zmian)
  $(basename "$0") --install       # zainstaluj narzędzia strony www
  $(basename "$0") --with-pdf      # zainstaluj www + PDF/EPUB

Po instalacji podgląd na żywo:
  cd $REPO_DIR && mdbook serve --open
EOF
}

for arg in "$@"; do
  case "$arg" in
    --install)  DO_INSTALL=1 ;;
    --with-pdf) DO_INSTALL=1; WITH_PDF=1 ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "Nieznany argument: $arg (zobacz --help)" >&2; exit 1 ;;
  esac
done

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|aarch64) ;;
  *) echo "Nieobsługiwana architektura: $ARCH" >&2; exit 1 ;;
esac

# kolory tylko gdy terminal je obsługuje (i nie ustawiono NO_COLOR)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ] \
   && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  C_GREEN="$(tput setaf 2)"; C_RED="$(tput setaf 1)"; C_RESET="$(tput sgr0)"
else
  C_GREEN=""; C_RED=""; C_RESET=""
fi

report() { # report <nazwa> <komenda>
  if command -v "$2" >/dev/null 2>&1; then
    printf "  ${C_GREEN}[OK]${C_RESET}    %-14s %s\n" "$1" "$("$2" --version 2>/dev/null | head -1)"
    return 0
  else
    printf "  ${C_RED}[BRAK]${C_RESET}  %s\n" "$1"
    return 1
  fi
}

# --- tryb sprawdzania (bez parametrów) — nic nie zmienia ---------------------
if [ "$DO_INSTALL" -eq 0 ]; then
  missing=0
  echo "Stan systemu (tryb tylko do odczytu, nic nie zmieniam):"
  echo "Pakiety systemowe:"
  report curl curl || missing=1
  report tar tar || missing=1
  echo "Narzędzia strony www:"
  report mdbook mdbook || missing=1
  report mdbook-mermaid mdbook-mermaid || missing=1
  case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *) printf "  ${C_RED}[UWAGA]${C_RESET} %s nie jest w PATH\n" "$INSTALL_DIR"; missing=1 ;;
  esac
  echo
  if [ "$missing" -eq 0 ]; then
    printf "${C_GREEN}Wszystko zainstalowane.${C_RESET} Build strony:\n"
    echo "  cd $REPO_DIR && mdbook-mermaid install . && mdbook build"
  else
    printf "${C_RED}Brakujące narzędzia.${C_RESET} Aby je zainstalować, uruchom:\n"
    echo "  $0 --install        # narzędzia strony www"
    echo "  $0 --with-pdf       # www + toolchain PDF/EPUB"
  fi
  echo "Pomoc: $0 --help"
  exit 0
fi

# --- instalacja ---------------------------------------------------------------
mkdir -p "$INSTALL_DIR"

apt_install() {
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -q
    sudo apt-get install -y -q "$@"
  else
    echo "Brak apt-get — zainstaluj ręcznie: $*" >&2
    exit 1
  fi
}

# zależności bazowe
need_pkgs=()
command -v curl >/dev/null 2>&1 || need_pkgs+=(curl)
command -v tar  >/dev/null 2>&1 || need_pkgs+=(tar)
if [ "${#need_pkgs[@]}" -gt 0 ]; then
  apt_install "${need_pkgs[@]}"
fi

# mdBook (jak w workflow: najnowszy release z GitHuba)
if command -v mdbook >/dev/null 2>&1; then
  echo "mdBook już zainstalowany: $(mdbook --version)"
else
  MDBOOK_TAG="$(curl -sL https://api.github.com/repos/rust-lang/mdBook/releases/latest \
    | grep '"tag_name"' | head -1 | cut -d'"' -f4)"
  if [ -z "$MDBOOK_TAG" ]; then
    echo "Nie udało się ustalić najnowszego tagu mdBook (API rate limit?)" >&2
    exit 1
  fi
  echo "Instaluję mdBook ${MDBOOK_TAG}"
  curl -sfL "https://github.com/rust-lang/mdBook/releases/download/${MDBOOK_TAG}/mdbook-${MDBOOK_TAG}-${ARCH}-unknown-linux-gnu.tar.gz" \
    | tar xz -C "$INSTALL_DIR"
fi

# mdbook-mermaid (prebuilt binary — bez potrzeby instalowania cargo)
if command -v mdbook-mermaid >/dev/null 2>&1; then
  echo "mdbook-mermaid już zainstalowany: $(mdbook-mermaid --version)"
else
  MERMAID_TAG="$(curl -sL https://api.github.com/repos/badboy/mdbook-mermaid/releases/latest \
    | grep '"tag_name"' | head -1 | cut -d'"' -f4)"
  if [ -z "$MERMAID_TAG" ]; then
    echo "Nie udało się ustalić najnowszego tagu mdbook-mermaid" >&2
    exit 1
  fi
  # dla aarch64 upstream publikuje wyłącznie build musl
  if [ "$ARCH" = "aarch64" ]; then
    MERMAID_TARGET="aarch64-unknown-linux-musl"
  else
    MERMAID_TARGET="${ARCH}-unknown-linux-gnu"
  fi
  echo "Instaluję mdbook-mermaid ${MERMAID_TAG}"
  curl -sfL "https://github.com/badboy/mdbook-mermaid/releases/download/${MERMAID_TAG}/mdbook-mermaid-${MERMAID_TAG}-${MERMAID_TARGET}.tar.gz" \
    | tar xz -C "$INSTALL_DIR"
fi

case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *) echo "UWAGA: $INSTALL_DIR nie jest w PATH — dodaj do ~/.bashrc: export PATH=\"$INSTALL_DIR:\$PATH\"" >&2 ;;
esac

# opcjonalnie: toolchain PDF/EPUB (kroki [skippdf] z workflow)
if [ "$WITH_PDF" -eq 1 ]; then
  apt_install pandoc texlive-xetex texlive-lang-polish texlive-latex-extra \
    fonts-dejavu librsvg2-bin imagemagick python3
  if command -v npm >/dev/null 2>&1; then
    npm install -g @mermaid-js/mermaid-cli
  else
    echo "UWAGA: brak npm — mermaid-cli (potrzebny do PDF) nie został zainstalowany." >&2
    echo "       Zainstaluj Node.js i uruchom: npm install -g @mermaid-js/mermaid-cli" >&2
  fi
fi

# build strony www (krok "Build" z workflow)
export PATH="$INSTALL_DIR:$PATH"
cd "$REPO_DIR"
mdbook-mermaid install .
mdbook build

echo
echo "Gotowe. Strona wyrenderowana w: $REPO_DIR/book/"
echo "Podgląd na żywo:  mdbook serve --open   (z katalogu $REPO_DIR)"
