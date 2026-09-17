#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DEFAULT="$HOME/github/watermarks-remover/service/scripts"
SCRIPTS_DIR="${SCRIPTS:-$SCRIPTS_DEFAULT}"
INSPECTOR="$SCRIPTS_DIR/inspect_file.py"
AUDITOR="$SCRIPTS_DIR/audit_dir.py"
CLEANER="$SCRIPTS_DIR/clean_file.py"
REPORT_FILE="$ROOT_DIR/watermark_inspect_report.md"
DOCUMENTATION_DIR="${DOCUMENTATION_DIR:-$(dirname "$ROOT_DIR")/documentation-rdb}"
SCAN_ROOTS=("$ROOT_DIR" "$DOCUMENTATION_DIR")
# book/ to wygenerowany wynik mdBook, assets/ to grafiki - oba poza zakresem kontroli
AUDIT_SKIP_DIRS="book,assets"
TMP_STATUS="$(mktemp)"
TMP_AUDIT="$(mktemp)"
DO_CLEAN=0
DO_CLEAN_DRY_RUN=0
DO_CLEAN_BAK=0
DO_LIST_B_YES=0
STYLO_THRESHOLD="${STYLO_THRESHOLD:-0.65}"

print_help() {
  cat <<'EOF'
Usage: ./generate_watermark_report.sh [options] [report_path]

Options:
  -h, --help     Show this help message.
  -clean         Run clean_file.py --in-place for each file flagged as [YES],
                 then regenerate the report.
  -clean-dry-run Show which [YES] files would be cleaned, do not modify files.
  -clean-bak     Remove all *.bak files recursively under both scanned directories.
  -b-yes         Show files flagged by method B as YES.

Arguments:
  report_path    Optional output path for the report (default:
                 ./watermark_inspect_report.md)

Environment:
  SCRIPTS        Path to watermarks-remover service scripts directory.
  DOCUMENTATION_DIR Second scanned repository (default: ../documentation-rdb).
  STYLO_THRESHOLD Threshold for Layer B stylometry score (default: 0.65).
EOF
}

cleanup() {
  rm -f "$TMP_STATUS" "$TMP_AUDIT"
}
trap cleanup EXIT

if [[ ! -x "$(command -v python3)" ]]; then
  echo "ERROR: python3 not found in PATH" >&2
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      print_help
      exit 0
      ;;
    -clean)
      DO_CLEAN=1
      shift
      ;;
    -clean-dry-run)
      DO_CLEAN_DRY_RUN=1
      shift
      ;;
    -clean-bak)
      DO_CLEAN_BAK=1
      shift
      ;;
    -b-yes)
      DO_LIST_B_YES=1
      shift
      ;;
    -*)
      echo "ERROR: unknown option: $1" >&2
      echo "Use -h or --help for usage." >&2
      exit 1
      ;;
    *)
      REPORT_FILE="$1"
      shift
      ;;
  esac
done

if [[ "$DO_CLEAN" -eq 1 && "$DO_CLEAN_DRY_RUN" -eq 1 ]]; then
  echo "ERROR: use either -clean or -clean-dry-run, not both." >&2
  exit 1
fi

if [[ ! -f "$INSPECTOR" ]]; then
  echo "ERROR: inspector not found: $INSPECTOR" >&2
  echo "Set SCRIPTS env variable, e.g.:" >&2
  echo "  SCRIPTS=/path/to/watermarks-remover/service/scripts $0" >&2
  exit 1
fi

if [[ ! -f "$AUDITOR" ]]; then
  echo "ERROR: directory auditor not found: $AUDITOR" >&2
  echo "Set SCRIPTS env variable, e.g.:" >&2
  echo "  SCRIPTS=/path/to/watermarks-remover/service/scripts $0" >&2
  exit 1
fi

if [[ ! -f "$CLEANER" ]]; then
  echo "ERROR: cleaner not found: $CLEANER" >&2
  echo "Set SCRIPTS env variable, e.g.:" >&2
  echo "  SCRIPTS=/path/to/watermarks-remover/service/scripts $0" >&2
  exit 1
fi

if [[ ! -d "$DOCUMENTATION_DIR" ]]; then
  echo "ERROR: documentation directory not found: $DOCUMENTATION_DIR" >&2
  echo "Set DOCUMENTATION_DIR env variable, e.g.:" >&2
  echo "  DOCUMENTATION_DIR=/path/to/documentation-rdb $0" >&2
  exit 1
fi

cd "$ROOT_DIR"

# Sciezka w raporcie ma postac <nazwa-repo>/<sciezka-w-repo>; zamiana na sciezke na dysku
resolve_path() {
  local path="$1" root
  for root in "${SCAN_ROOTS[@]}"; do
    if [[ "$path" == "$(basename "$root")/"* ]]; then
      echo "$root/${path#*/}"
      return
    fi
  done
}

collect_statuses() {
  local root
  : > "$TMP_STATUS"
  for root in "${SCAN_ROOTS[@]}"; do
    (cd "$root" && collect_statuses_in "$(basename "$root")") >> "$TMP_STATUS"
  done
}

collect_statuses_in() {
  local repo="$1" audit_rc=0
  python3 "$AUDITOR" --json --check-stylometry --skip "$AUDIT_SKIP_DIRS" . > "$TMP_AUDIT" || audit_rc=$?
  if [[ "$audit_rc" -ne 0 && "$audit_rc" -ne 1 ]]; then
    echo "ERROR: audit_dir.py failed in $repo (exit $audit_rc)" >&2
    exit 1
  fi

  python3 - "$TMP_AUDIT" "$STYLO_THRESHOLD" "$INSPECTOR" "$repo" <<'PY'
import json
import os
import subprocess
import sys

audit_path, threshold, inspector, repo = sys.argv[1], float(sys.argv[2]), sys.argv[3], sys.argv[4]
with open(audit_path, encoding="utf-8") as fh:
    audit = json.load(fh)


def layer_a_details(path):
    # audit_dir podaje tylko etykiety; offsety znakow daje inspect_file --json
    proc = subprocess.run(["python3", inspector, "--json", path], capture_output=True, text=True)
    hits = json.loads(proc.stdout).get("layer_a_hits", []) if proc.stdout else []
    with open(path, encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    details = []
    for hit in hits:
        lines = sorted({text.count("\n", 0, off) + 1 for off in hit.get("sample_offsets", [])})
        where = ", ".join(str(n) for n in lines) or "?"
        details.append(f"{hit['codepoint']} x{hit['count']} {hit['confidence']} ({hit['kind']}), linie: {where}")
    return details


rows = []
for item in audit["files"]:
    path = os.path.relpath(item["path"])
    if not path.endswith(".md"):
        continue
    confidences = item.get("confidence", [])
    status_a = "YES" if item.get("has_c2pa") or any(c in ("confirmed", "probable") for c in confidences) else "NO"

    score = (item.get("stylometry") or {}).get("score")
    if score is None:
        status_b = "n/a"
    else:
        status_b = "YES" if score >= threshold else "NO"
    status_final = "YES" if "YES" in (status_a, status_b) else "NO"

    details = []
    if item.get("findings"):
        details = layer_a_details(path) if item.get("suspicious_total") else []
        details += [f"{f} ({c})" for f, c in zip(item["findings"], confidences) if not f.startswith("layer-a")]
    rows.append((f"{repo}/{path}", status_a, status_b, status_final, " | ".join(details)))

for row in sorted(rows):
    print("\t".join(row))
PY
}

run_clean_for_yes_files() {
  local yes_count=0
  while IFS=$'\t' read -r path status_a _ _; do
    if [[ "$status_a" == "YES" ]]; then
      python3 "$CLEANER" "$(resolve_path "$path")" --in-place -q
      yes_count=$((yes_count + 1))
    fi
  done < "$TMP_STATUS"
  echo "Cleaned files (Layer A YES): $yes_count"
}

show_yes_files_for_dry_run() {
  local yes_count=0
  echo "[clean-dry-run] Files with Layer A [YES] (eligible for clean_file.py):"
  while IFS=$'\t' read -r path status_a status_b status_final _; do
    if [[ "$status_a" == "YES" ]]; then
      echo "- $path (A=$status_a, B=$status_b, FINAL=$status_final)"
      yes_count=$((yes_count + 1))
    fi
  done < "$TMP_STATUS"
  echo "[clean-dry-run] Total files to clean: $yes_count"
}

show_b_yes_files() {
  local b_yes_count=0
  echo "[b-yes] Files with B=YES:"
  while IFS=$'\t' read -r path status_a status_b status_final _; do
    if [[ "$status_b" == "YES" ]]; then
      echo "- $path (A=$status_a, B=$status_b, FINAL=$status_final)"
      b_yes_count=$((b_yes_count + 1))
    fi
  done < "$TMP_STATUS"
  echo "[b-yes] Total files with B=YES: $b_yes_count"
}

clean_bak_files() {
  local bak_count=0
  while IFS= read -r bak_file; do
    rm -f "$bak_file"
    echo "[clean-bak] Removed: $bak_file"
    bak_count=$((bak_count + 1))
  done < <(find "${SCAN_ROOTS[@]}" -type f -name '*.bak' | sort)
  echo "[clean-bak] Total removed: $bak_count"
}

print_summary() {
  local label="$1" prefix="$2"
  local yes_a=0 no_a=0 yes_b=0 no_b=0 na_b=0 yes_final=0 no_final=0
  while IFS=$'\t' read -r path status_a status_b status_final _; do
    [[ "$path" == "$prefix"* ]] || continue
    if [[ "$status_a" == "YES" ]]; then yes_a=$((yes_a + 1)); else no_a=$((no_a + 1)); fi
    if [[ "$status_b" == "YES" ]]; then
      yes_b=$((yes_b + 1))
    elif [[ "$status_b" == "n/a" ]]; then
      na_b=$((na_b + 1))
    else
      no_b=$((no_b + 1))
    fi
    if [[ "$status_final" == "YES" ]]; then yes_final=$((yes_final + 1)); else no_final=$((no_final + 1)); fi
  done < "$TMP_STATUS"

  echo "Podsumowanie $label:"
  echo "- A: YES=$yes_a, NO=$no_a"
  echo "- B: YES=$yes_b, NO=$no_b, n/a=$na_b"
  echo "- FINAL: YES=$yes_final, NO=$no_final, RAZEM=$((yes_final + no_final))"
  echo
}

collect_statuses

if [[ "$DO_CLEAN_BAK" -eq 1 ]]; then
  clean_bak_files
fi

if [[ "$DO_CLEAN" -eq 1 ]]; then
  run_clean_for_yes_files
  collect_statuses
elif [[ "$DO_CLEAN_DRY_RUN" -eq 1 ]]; then
  show_yes_files_for_dry_run
fi

if [[ "$DO_LIST_B_YES" -eq 1 ]]; then
  show_b_yes_files
fi

{
  echo "# Raport dwuetapowy dla plikow .md"
  echo
  echo "Katalogi: ${SCAN_ROOTS[*]}"
  echo
  echo "Legenda:"
  echo "- A = audit_dir.py (warstwa plikowa/Layer A; YES gdy trafienie confirmed/probable lub C2PA)"
  echo "- B = audit_dir.py --check-stylometry (metoda statystyczna/Layer B, prog STYLO_THRESHOLD=$STYLO_THRESHOLD;"
  echo "  n/a gdy tekst za krotki na skalibrowana ocene)"
  echo "- FINAL = YES gdy A=YES lub B=YES"
  echo
  awk -F '\t' '
    {
      path = $1
      status_a = $2
      status_b = $3
      status_final = $4
      depth = split(path, parts, "/")
      prefix = ""

      for (i = 1; i < depth; i++) {
        prefix = (prefix ? prefix "/" : "") parts[i]
        if (!(prefix in seen)) {
          seen[prefix] = 1
          indent = ""
          for (j = 1; j < i; j++) {
            indent = indent "  "
          }
          print indent parts[i] "/"
        }
      }

      indent = ""
      for (j = 1; j < depth; j++) {
        indent = indent "  "
      }
      print indent "- " parts[depth] " [" status_final "] (A:" status_a ", B:" status_b ")"
    }
    END {
      print ""
    }
  ' "$TMP_STATUS"

  echo "Szczegoly:"
  awk -F '\t' '$5 != "" { print "- " $1 ": " $5; n++ } END { if (!n) print "- brak trafien" }' "$TMP_STATUS"
  echo

  for root in "${SCAN_ROOTS[@]}"; do
    print_summary "$(basename "$root")" "$(basename "$root")/"
  done
  print_summary "razem (oba katalogi)" ""
} > "$REPORT_FILE"

echo "Report written to: $REPORT_FILE"