#!/usr/bin/env python3
# generate_railroad.py — generuje diagramy railroad (SVG) dla poleceń RQL
# na podstawie gramatyki ANTLR4 (RQL.g4) z repozytorium retractordb.
#
# Skrypt samodzielnie parsuje podzbiór składni ANTLR4 używany przez reguły
# parsera w RQL.g4 (sekwencje, alternatywy, grupy, ?, *, +, etykiety elementów,
# etykiety alternatyw #...) i przekształca go na obiekty biblioteki
# railroad-diagrams (pip). Nie wymaga Javy ani ANTLR.
#
# Struktura diagramów podąża za gramatyką automatycznie. Etykiety (sekcja
# LANGUAGES poniżej) istnieją w dwóch wersjach językowych — "pl" dla repozytorium
# dokumentacja-rdb i "en" dla documentation-rdb — i są dopasowywane po etykietach
# elementów (np. stream_name=ID -> "nazwa"/"name") albo po nazwach tokenów/reguł.
# Jeśli po zmianie gramatyki na diagramie pojawi się surowa nazwa z gramatyki
# (np. ID, DECIMAL), uzupełnij odpowiednią mapę OBU wersji językowych.
#
# Użycie (zwykle przez scripts/generate-railroad.sh):
#   generate_railroad.py --grammar ŚCIEŻKA/RQL.g4 --outdir KATALOG_ASSETS
#   generate_railroad.py --grammar ... --outdir ... --lang en
#   generate_railroad.py --grammar ... --outdir ... --check   # tylko porównaj

import argparse
import io
import os
import re
import sys

try:
    from railroad import (
        Choice,
        Diagram,
        NonTerminal,
        OneOrMore,
        Optional,
        Sequence,
        Skip,
        Stack,
        Terminal,
        ZeroOrMore,
    )
except ImportError:
    print(
        "BŁĄD: brak biblioteki railroad-diagrams.\n"
        "Zainstaluj ją poleceniem:\n"
        "  scripts/install-local-tools.sh --install\n"
        "albo bezpośrednio:\n"
        "  python3 -m pip install railroad-diagrams",
        file=sys.stderr,
    )
    sys.exit(1)

# ---------------------------------------------------------------- KONFIGURACJA

# Diagramy do wygenerowania: (reguła gramatyki, nazwa pliku wynikowego).
DIAGRAMS = [
    ("select_statement", "railroad-select.svg"),
    ("declare_statement", "railroad-declare.svg"),
    ("rule_statement", "railroad-rule.svg"),
    ("compiler_option", "railroad-dyrektywy.svg"),
]

# Reguły wstawiane wprost do diagramu nadrzędnego (zamiast prostokąta
# z nazwą reguły).
INLINE_RULES = {
    "select_list",
    "retention_from",
    "asterisk",
    "field_declaration",
    "rational_se",
    "dumppart",
    "systempart",
}

# Maksymalna szerokość wiersza diagramu (px). Sekwencja szersza niż ta wartość
# jest łamana na kolejne wiersze (railroad.Stack) — inaczej diagram polecenia
# SELECT byłby jedną linią o szerokości ~1900 px, nieczytelną po wpasowaniu
# w szerokość strony.
MAX_ROW_WIDTH = 760

# Etykiety w obu wersjach językowych. Znaczenie kluczy:
#   rules          — reguły rysowane jako osobny prostokąt (non-terminal)
#   tokens         — tokeny bez dosłownej postaci (globalnie)
#   elements       — etykiety elementów gramatyki (np. stream_name=ID);
#                    klucz (reguła, etykieta), reguła "*" obowiązuje wszędzie
#   scoped_tokens  — token z innym podpisem w konkretnej regule: (reguła, token)
#   overrides      — ręczne definicje reguł, tam gdzie dokumentacja świadomie
#                    upraszcza gramatykę (patrz komentarze); zmiana gramatyki
#                    tych reguł NIE trafi na diagram bez zmiany definicji tutaj
LANGUAGES = {
    "pl": {
        "rules": {
            "expression": "wyrażenie",
            "stream_expression": "wyrażenie_strumieniowe",
            "logic": "warunek_logiczny",
            "field_type": "typ",
        },
        "tokens": {
            "ID": "nazwa",
            "STRING": "'tekst'",
            "STRING_PROFILE": "'profil'",
            "DECIMAL": "liczba",
            "FLOAT": "liczba",
            "TYPE_PROFILE": "profil",
        },
        "elements": {
            ("*", "stream_name"): "nazwa",
            ("*", "type_name"): "profil",
            ("*", "capacity"): "pojemność",
            ("*", "segments"): "segmenty",
            ("select_statement", "file_name"): "'plik'",
            ("declare_statement", "file_name"): "'źródło'",
            ("declare_statement", "type_size"): "N",
            ("rule_statement", "name"): "nazwa_reguły",
            ("rule_statement", "stream_name"): "strumień",
            ("rule_statement", "step_back"): "kroki_wstecz",
            ("rule_statement", "step_forward"): "kroki_w_przód",
            ("rule_statement", "rule_retnetion"): "segmenty",
            ("rule_statement", "syscmd"): "'polecenie_systemu'",
        },
        "scoped_tokens": {
            ("field_declaration", "ID"): "pole",
        },
        "overrides": {
            # asterisk : (ID DOT)? STAR — w dokumentacji po prostu gwiazdka.
            "asterisk": lambda: Terminal("*"),
            # rational_se : fraction_rule | FLOAT | DECIMAL — FLOAT i DECIMAL
            # dokumentacja zbiera w jedną gałąź "liczba".
            "rational_se": lambda: Choice(
                0,
                Sequence(NonTerminal("licznik"), Terminal("/"), NonTerminal("mianownik")),
                NonTerminal("liczba"),
            ),
        },
    },
    "en": {
        "rules": {
            "expression": "expression",
            "stream_expression": "stream_expression",
            "logic": "logical_condition",
            "field_type": "type",
        },
        "tokens": {
            "ID": "name",
            "STRING": "'text'",
            "STRING_PROFILE": "'profile'",
            "DECIMAL": "number",
            "FLOAT": "number",
            "TYPE_PROFILE": "profile",
        },
        "elements": {
            ("*", "stream_name"): "name",
            ("*", "type_name"): "profile",
            ("*", "capacity"): "capacity",
            ("*", "segments"): "segments",
            ("select_statement", "file_name"): "'file'",
            ("declare_statement", "file_name"): "'source'",
            ("declare_statement", "type_size"): "N",
            ("rule_statement", "name"): "rule_name",
            ("rule_statement", "stream_name"): "stream",
            ("rule_statement", "step_back"): "steps_back",
            ("rule_statement", "step_forward"): "steps_forward",
            ("rule_statement", "rule_retnetion"): "segments",
            ("rule_statement", "syscmd"): "'system_command'",
        },
        "scoped_tokens": {
            ("field_declaration", "ID"): "field",
        },
        "overrides": {
            "asterisk": lambda: Terminal("*"),
            "rational_se": lambda: Choice(
                0,
                Sequence(NonTerminal("numerator"), Terminal("/"), NonTerminal("denominator")),
                NonTerminal("number"),
            ),
        },
    },
}

# Styl zgodny z dotychczasowymi diagramami w assets/ (zielone terminale,
# białe kursywne non-terminale, czcionka DejaVu Sans Mono).
DIAGRAM_CSS = """\
	svg.railroad-diagram {
		background-color: transparent;
	}
	svg.railroad-diagram path {
		stroke-width: 2.2;
		stroke: #000000;
		fill: none;
	}
	svg.railroad-diagram text {
		font: bold 14px "DejaVu Sans Mono", monospace;
		text-anchor: middle;
		fill: #000000;
	}
	svg.railroad-diagram text.label {
		text-anchor: start;
	}
	svg.railroad-diagram text.comment {
		font: italic 12px "DejaVu Sans Mono", monospace;
	}
	svg.railroad-diagram rect {
		stroke-width: 2.2;
		stroke: #000000;
		fill: #d7f4d7;
	}
	svg.railroad-diagram rect.group-box {
		stroke: gray;
		stroke-dasharray: 10 5;
		fill: none;
	}
	svg.railroad-diagram g.non-terminal rect {
		fill: #ffffff;
	}
	svg.railroad-diagram g.non-terminal text {
		font-style: italic;
		font-weight: normal;
	}
"""

# ------------------------------------------------------------- PARSER ANTLR4
#
# AST jako krotki:
#   ("alt", seq, seq, ...)          alternatywa
#   ("seq", elem, elem, ...)        sekwencja
#   ("lit", "tekst")                literal '...'
#   ("tok", "NAZWA")                odwołanie do tokenu (wielkie litery)
#   ("rul", "nazwa")                odwołanie do reguły parsera
#   ("lab", "etykieta", elem)       element z etykietą (np. stream_name=ID)
#   ("opt", elem) / ("star", elem) / ("plus", elem)

TOKEN_RE = re.compile(
    r"""
      (?P<ws>\s+)
    | (?P<comment>//[^\n]*|/\*.*?\*/)
    | (?P<literal>'(?:[^'\\]|\\.)*')
    | (?P<ident>[A-Za-z_][A-Za-z_0-9]*)
    | (?P<number>[0-9]+)
    | (?P<arrow>->)
    | (?P<punct>[()|?*+=;:~{}\[\]#<>,.$!\\-])
    """,
    re.VERBOSE | re.DOTALL,
)


class GrammarError(Exception):
    pass


def tokenize(text):
    tokens = []
    pos = 0
    while pos < len(text):
        m = TOKEN_RE.match(text, pos)
        if not m:
            raise GrammarError(f"nierozpoznany znak na pozycji {pos}: {text[pos:pos+40]!r}")
        pos = m.end()
        kind = m.lastgroup
        if kind in ("ws", "comment"):
            continue
        tokens.append(m.group())
    return tokens


class Parser:
    def __init__(self, tokens):
        self.tokens = tokens
        self.pos = 0
        self.parser_rules = {}  # nazwa -> AST ("alt", ...)
        self.lexer_literals = {}  # NAZWA -> pierwszy literal albo None

    def peek(self, offset=0):
        i = self.pos + offset
        return self.tokens[i] if i < len(self.tokens) else None

    def next(self):
        tok = self.peek()
        self.pos += 1
        return tok

    def expect(self, tok):
        got = self.next()
        if got != tok:
            raise GrammarError(f"oczekiwano {tok!r}, jest {got!r}")

    def parse(self):
        # grammar RQL;
        if self.next() != "grammar":
            raise GrammarError("plik nie zaczyna się od 'grammar'")
        self.next()  # nazwa gramatyki
        self.expect(";")
        while self.peek() is not None:
            self.parse_toplevel()
        return self

    def parse_toplevel(self):
        name = self.next()
        if name in ("options", "channels"):
            self.skip_block()
            return
        if name == "fragment":
            name = self.next()
            self.skip_rule_body()
            return
        if name.startswith("@"):
            self.skip_block()
            return
        if self.peek() != ":":
            raise GrammarError(f"oczekiwano ':' po {name!r}, jest {self.peek()!r}")
        self.next()  # ':'
        if name[0].islower():
            self.parser_rules[name] = self.parse_alternatives()
            self.expect(";")
        else:
            self.lexer_literals[name] = self.scan_lexer_literal()

    def skip_block(self):
        # pomija { ... } z zagnieżdżeniem
        self.expect("{")
        depth = 1
        while depth:
            tok = self.next()
            if tok is None:
                raise GrammarError("niedomknięty blok { }")
            if tok == "{":
                depth += 1
            elif tok == "}":
                depth -= 1

    def skip_rule_body(self):
        depth = 0
        while True:
            tok = self.next()
            if tok is None:
                raise GrammarError("niedomknięta reguła")
            if tok == "(":
                depth += 1
            elif tok == ")":
                depth -= 1
            elif tok == ";" and depth == 0:
                return

    def scan_lexer_literal(self):
        # ciało reguły leksera: literal bierzemy pod uwagę tylko wtedy, gdy cała
        # reguła składa się wyłącznie z alternatywy literalów ('SELECT'|'select');
        # wpp. token nie ma jednej dosłownej postaci (np. STRING_PROFILE) -> None
        body = []
        depth = 0
        while True:
            tok = self.next()
            if tok is None:
                raise GrammarError("niedomknięta reguła leksera")
            if tok == "[":
                depth += 1
            elif tok == "]":
                depth -= 1
            elif tok == ";" and depth == 0:
                break
            body.append(tok)
        if body and all(t == "|" or t.startswith("'") for t in body):
            return unescape_literal(body[0])
        return None

    def parse_alternatives(self):
        # Jednoelementowe alternatywy i sekwencje są zwijane do samego elementu —
        # dzięki temu grupa '(' ... ')' nie wprowadza dodatkowego poziomu AST
        # i wzorce w conv_sequence (np. pętla z separatorem) są rozpoznawalne.
        seqs = [self.parse_sequence()]
        self.skip_alt_label()
        while self.peek() == "|":
            self.next()
            seqs.append(self.parse_sequence())
            self.skip_alt_label()
        if len(seqs) == 1:
            return seqs[0]
        return ("alt",) + tuple(seqs)

    def skip_alt_label(self):
        if self.peek() == "#":
            self.next()
            self.next()  # nazwa etykiety alternatywy

    def parse_sequence(self):
        elems = []
        while self.peek() is not None and self.peek() not in ("|", ")", ";", "#"):
            elems.append(self.parse_element())
        if len(elems) == 1:
            return elems[0]
        return ("seq",) + tuple(elems)

    def parse_element(self):
        label = None
        if self.peek(1) == "=":
            label = self.next()
            self.next()  # '='
        atom = self.parse_atom()
        node = ("lab", label, atom) if label else atom
        suffix = self.peek()
        if suffix in ("?", "*", "+"):
            self.next()
            kind = {"?": "opt", "*": "star", "+": "plus"}[suffix]
            node = (kind, node)
            if self.peek() == "?":  # znacznik niechciwy (??, *?, +?)
                self.next()
        return node

    def parse_atom(self):
        tok = self.next()
        if tok == "(":
            node = self.parse_alternatives()
            self.expect(")")
            return node
        if tok == "~":
            raise GrammarError("operator '~' nie jest obsługiwany")
        if tok == "{":
            raise GrammarError("predykaty { ... }? nie są obsługiwane")
        if tok.startswith("'"):
            return ("lit", unescape_literal(tok))
        if re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", tok):
            return ("tok", tok) if tok[0].isupper() else ("rul", tok)
        raise GrammarError(f"nieoczekiwany token {tok!r}")


def unescape_literal(text):
    body = text[1:-1]
    return body.replace("\\'", "'").replace("\\\\", "\\")


# ------------------------------------------------------- KONWERSJA NA DIAGRAM


class Renderer:
    def __init__(self, grammar, entry_rule, labels):
        self.grammar = grammar
        self.entry_rule = entry_rule
        self.labels = labels
        self.inlining = set()
        self.inline_context = None

    def element_label(self, label):
        elements = self.labels["elements"]
        return elements.get((self.entry_rule, label)) or elements.get(("*", label))

    def token_item(self, name, label):
        mapped = self.element_label(label) if label else None
        if mapped:
            return NonTerminal(mapped)
        scoped = self.labels["scoped_tokens"].get((self.inline_context or self.entry_rule, name))
        if scoped:
            return NonTerminal(scoped)
        literal = self.grammar.lexer_literals.get(name)
        if literal:
            return Terminal(literal)
        return NonTerminal(self.labels["tokens"].get(name, name))

    def conv(self, node):
        kind = node[0]
        if kind == "lit":
            return Terminal(node[1])
        if kind == "tok":
            return self.token_item(node[1], None)
        if kind == "lab":
            _, label, atom = node
            if atom[0] == "tok":
                return self.token_item(atom[1], label)
            return self.conv(atom)
        if kind == "rul":
            name = node[1]
            if name in self.labels["overrides"]:
                return self.labels["overrides"][name]()
            if name in INLINE_RULES:
                if name in self.inlining:
                    raise GrammarError(f"rekurencyjne inline reguły {name!r}")
                if name not in self.grammar.parser_rules:
                    raise GrammarError(f"brak reguły {name!r} w gramatyce")
                self.inlining.add(name)
                prev = self.inline_context
                self.inline_context = name
                try:
                    return self.conv(self.grammar.parser_rules[name])
                finally:
                    self.inline_context = prev
                    self.inlining.discard(name)
            return NonTerminal(self.labels["rules"].get(name, name))
        if kind == "opt":
            return Optional(self.conv(node[1]))
        if kind == "star":
            return ZeroOrMore(self.conv(node[1]))
        if kind == "plus":
            return OneOrMore(self.conv(node[1]))
        if kind == "seq":
            return self.conv_sequence(node[1:])
        if kind == "alt":
            return Choice(0, *[self.conv(s) for s in node[1:]])
        raise GrammarError(f"nieznany węzeł AST: {node!r}")

    def seq_items(self, elems):
        # wzorzec "X (sep X)*" -> OneOrMore(X, sep) — pętla z separatorem
        items = []
        i = 0
        while i < len(elems):
            nxt = elems[i + 1] if i + 1 < len(elems) else None
            if (
                nxt is not None
                and nxt[0] == "star"
                and nxt[1][0] == "seq"
                and len(nxt[1]) == 3
                and nxt[1][2] == elems[i]
            ):
                items.append(OneOrMore(self.conv(elems[i]), self.conv(nxt[1][1])))
                i += 2
                continue
            items.append(self.conv(elems[i]))
            i += 1
        return items

    def conv_sequence(self, elems):
        items = self.seq_items(elems)
        if not items:
            return Skip()
        if len(items) == 1:
            return items[0]
        return Sequence(*items)


def stack_rows(items):
    # zachłanne łamanie sekwencji na wiersze o szerokości <= MAX_ROW_WIDTH
    rows = []
    row = []
    width = 0.0
    for item in items:
        if row and width + item.width > MAX_ROW_WIDTH:
            rows.append(row)
            row = []
            width = 0.0
        row.append(item)
        width += item.width
    if row:
        rows.append(row)
    if len(rows) == 1:
        return Sequence(*rows[0])
    return Stack(*[Sequence(*r) for r in rows])


def build_diagram(grammar, entry_rule, labels):
    if entry_rule not in grammar.parser_rules:
        raise GrammarError(f"brak reguły {entry_rule!r} w gramatyce")
    renderer = Renderer(grammar, entry_rule, labels)
    body = grammar.parser_rules[entry_rule]
    if body[0] == "seq":
        return Diagram(stack_rows(renderer.seq_items(body[1:])))
    return Diagram(renderer.conv(body))


def render_svg(grammar, entry_rule, labels):
    diagram = build_diagram(grammar, entry_rule, labels)
    buf = io.StringIO()
    diagram.writeStandalone(buf.write, css=DIAGRAM_CSS)
    return buf.getvalue()


def main():
    ap = argparse.ArgumentParser(
        description="Generuje diagramy railroad (SVG) poleceń RQL z gramatyki ANTLR4."
    )
    ap.add_argument("--grammar", required=True, help="ścieżka do RQL.g4")
    ap.add_argument("--outdir", required=True, help="katalog na pliki SVG (assets/)")
    ap.add_argument(
        "--lang",
        choices=sorted(LANGUAGES),
        default="pl",
        help="język etykiet na diagramach (domyślnie: pl)",
    )
    ap.add_argument(
        "--check",
        action="store_true",
        help="tylko porówna pliki; kod wyjścia 1 gdy diagramy są nieaktualne",
    )
    args = ap.parse_args()

    try:
        with open(args.grammar, encoding="utf-8") as f:
            grammar = Parser(tokenize(f.read())).parse()
    except (OSError, GrammarError) as e:
        print(f"BŁĄD: {e}", file=sys.stderr)
        return 1

    stale = []
    try:
        for rule, filename in DIAGRAMS:
            svg = render_svg(grammar, rule, LANGUAGES[args.lang])
            path = os.path.join(args.outdir, filename)
            if args.check:
                try:
                    with open(path, encoding="utf-8") as f:
                        current = f.read()
                except OSError:
                    current = None
                if current != svg:
                    stale.append(filename)
                    print(f"NIEAKTUALNY: {filename} (reguła {rule})")
                else:
                    print(f"OK:         {filename}")
            else:
                with open(path, "w", encoding="utf-8") as f:
                    f.write(svg)
                print(f"Wygenerowano: {path} (reguła {rule})")
    except GrammarError as e:
        print(f"BŁĄD: {e}", file=sys.stderr)
        return 1

    if args.check and stale:
        print("Uruchom scripts/generate-railroad.sh, aby zaktualizować diagramy.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
