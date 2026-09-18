#!/usr/bin/env python3
# unwrap_paragraphs.py - łączy zawinięte akapity Markdown w pojedyncze linie.
#
# Zasada repozytorium (CLAUDE.md, Authoring Rules): jeden akapit albo jeden punkt
# listy to jedna linia. Skrypt łączy wyłącznie linie, które parser CommonMark
# (markdown-it-py) zalicza do jednego akapitu - także w listach i cytatach - więc
# bloki kodu, tabele, bloki HTML i nagłówki pozostają nietknięte. Rendering się
# nie zmienia: miękkie złamanie linii i spacja dają w HTML ten sam tekst.
#
# Zostają bez zmian akapity, w których łamanie linii ma znaczenie dla mdBook:
#   * z matematyką blokową \\[...\\] albo $$ oraz z dyrektywą {{#include}},
#   * z linią zaczynającą się od ':' (lista definicji) albo '[^' (przypis).
# Twarde złamanie linii (dwie spacje albo nieparzysta liczba '\' na końcu) zostaje.
#
# Użycie:
#   scripts/unwrap_paragraphs.py              # łączy akapity w plikach .md z git
#   scripts/unwrap_paragraphs.py --check      # tylko sprawdza; kod 1, gdy jest co łączyć
#   scripts/unwrap_paragraphs.py PLIK.md ...  # tylko wskazane pliki
#
# Wymaga biblioteki markdown-it-py - instaluje ją scripts/install-local-tools.sh --install

import argparse
import re
import subprocess
import sys
from pathlib import Path

from markdown_it import MarkdownIt

REPO_DIR = Path(__file__).resolve().parent.parent
MD = MarkdownIt("commonmark").enable("table")
# Prefiks kontenera w linii kontynuacji: wcięcie listy i znaczniki cytatu.
PREFIX = re.compile(r"^[ \t>]*")


def hard_break(line):
    if line.endswith("  "):
        return True
    trailing = len(line) - len(line.rstrip("\\"))
    return trailing % 2 == 1


def protected(lines):
    text = "\n".join(lines)
    if "\\\\[" in text or "\\\\]" in text or "$$" in text or "{{#" in text:
        return True
    for line in lines[1:]:
        body = PREFIX.sub("", line)
        if body.startswith(":") or body.startswith("[^"):
            return True
    return False


def unwrap(source):
    lines = source.split("\n")
    ranges = [tok.map for tok in MD.parse(source) if tok.type == "paragraph_open" and tok.map]
    out = []
    cursor = 0
    for start, end in ranges:
        out.extend(lines[cursor:start])
        para = lines[start:end]
        cursor = end
        if len(para) < 2 or protected(para):
            out.extend(para)
            continue
        current = para[0]
        for prev, line in zip(para, para[1:]):
            if hard_break(prev):
                out.append(current)
                current = line
            else:
                current = current.rstrip() + " " + PREFIX.sub("", line).strip()
        out.append(current)
    out.extend(lines[cursor:])
    return "\n".join(out)


def tracked_markdown():
    listing = subprocess.run(["git", "ls-files", "*.md"], cwd=REPO_DIR, check=True, capture_output=True, text=True)
    return [REPO_DIR / name for name in listing.stdout.split()]


def main():
    parser = argparse.ArgumentParser(description="Łączy zawinięte akapity Markdown w pojedyncze linie.")
    parser.add_argument("--check", action="store_true", help="tylko sprawdza; kod 1, gdy jest co łączyć")
    parser.add_argument("files", nargs="*", type=Path, help="pliki .md (domyślnie: wszystkie z git)")
    args = parser.parse_args()

    pending = []
    for path in args.files or tracked_markdown():
        # newline="" - bez tego Python po cichu zamienia CRLF na LF przy odczycie.
        with open(path, encoding="utf-8", newline="") as f:
            source = f.read()
        if "\r" in source:
            print(f"pominięty (CRLF): {path}", file=sys.stderr)
            continue
        result = unwrap(source)
        if result == source:
            continue
        pending.append(path)
        if not args.check:
            with open(path, "w", encoding="utf-8", newline="") as f:
                f.write(result)

    for path in pending:
        print(path.relative_to(REPO_DIR) if path.is_relative_to(REPO_DIR) else path)
    verb = "do połączenia" if args.check else "zmienione"
    print(f"pliki {verb}: {len(pending)}", file=sys.stderr)
    return 1 if args.check and pending else 0


if __name__ == "__main__":
    sys.exit(main())
