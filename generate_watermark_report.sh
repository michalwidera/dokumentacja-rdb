#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DEFAULT="$HOME/github/watermarks-remover/service/scripts"
SCRIPTS_DIR="${SCRIPTS:-$SCRIPTS_DEFAULT}"
INSPECTOR="$SCRIPTS_DIR/inspect_file.py"
TEXT_INSPECTOR="$SCRIPTS_DIR/inspect_text.py"
CLEANER="$SCRIPTS_DIR/clean_file.py"
REPORT_FILE="$ROOT_DIR/watermark_inspect_report.md"
TMP_STATUS="$(mktemp)"
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
  -clean-bak     Remove all *.bak files recursively under ./dokumentacja-rdb.
  -b-yes         Show files flagged by method B as YES.

Arguments:
  report_path    Optional output path for the report (default:
                 ./watermark_inspect_report.md)

Environment:
  SCRIPTS        Path to watermarks-remover service scripts directory.
  STYLO_THRESHOLD Threshold for Layer B stylometry score (default: 0.65).
EOF
}

cleanup() {
  rm -f "$TMP_STATUS"
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

if [[ ! -f "$TEXT_INSPECTOR" ]]; then
  echo "ERROR: text inspector not found: $TEXT_INSPECTOR" >&2
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

cd "$ROOT_DIR"

is_stylometry_yes() {
  local file="$1"
  local score

  score="$({
    python3 "$TEXT_INSPECTOR" --json --stylometry "$file" 2>/dev/null \
      | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("stylometry", {}).get("score", ""))'
  } || true)"

  if [[ -z "$score" ]]; then
    echo "NO"
    return
  fi

  if python3 - "$score" "$STYLO_THRESHOLD" <<'PY'
import sys
score = float(sys.argv[1])
threshold = float(sys.argv[2])
raise SystemExit(0 if score >= threshold else 1)
PY
  then
    echo "YES"
  else
    echo "NO"
  fi
}

collect_statuses() {
  : > "$TMP_STATUS"
  find . -type f -name '*.md' | sort | while read -r file; do
    if python3 "$INSPECTOR" "$file" >/dev/null 2>&1; then
      status_a="NO"
    else
      status_a="YES"
    fi

    status_b="$(is_stylometry_yes "$file")"
    if [[ "$status_a" == "YES" || "$status_b" == "YES" ]]; then
      status_final="YES"
    else
      status_final="NO"
    fi

    printf "%s\t%s\t%s\t%s\n" "${file#./}" "$status_a" "$status_b" "$status_final" >> "$TMP_STATUS"
  done
}

run_clean_for_yes_files() {
  local yes_count=0
  while IFS=$'\t' read -r path status_a _ _; do
    if [[ "$status_a" == "YES" ]]; then
      python3 "$CLEANER" "$path" --in-place >/dev/null
      yes_count=$((yes_count + 1))
    fi
  done < "$TMP_STATUS"
  echo "Cleaned files (Layer A YES): $yes_count"
}

show_yes_files_for_dry_run() {
  local yes_count=0
  echo "[clean-dry-run] Files with Layer A [YES] (eligible for clean_file.py):"
  while IFS=$'\t' read -r path status_a status_b status_final; do
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
  while IFS=$'\t' read -r path status_a status_b status_final; do
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
    echo "[clean-bak] Removed: ${bak_file#./}"
    bak_count=$((bak_count + 1))
  done < <(find . -type f -name '*.bak' | sort)
  echo "[clean-bak] Total removed: $bak_count"
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
  echo "Legenda:"
  echo "- A = inspect_file.py (warstwa plikowa/Layer A)"
  echo "- B = inspect_text.py --stylometry (metoda statystyczna/Layer B, prog STYLO_THRESHOLD=$STYLO_THRESHOLD)"
  echo "- FINAL = YES gdy A=YES lub B=YES"
  echo
  awk -F '\t' '
    BEGIN {
      print "dokumentacja-rdb/"
    }
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

  yes_count_a=0
  no_count_a=0
  yes_count_b=0
  no_count_b=0
  yes_count_final=0
  no_count_final=0
  while IFS=$'\t' read -r _ status_a status_b status_final; do
    if [[ "$status_a" == "YES" ]]; then yes_count_a=$((yes_count_a + 1)); else no_count_a=$((no_count_a + 1)); fi
    if [[ "$status_b" == "YES" ]]; then yes_count_b=$((yes_count_b + 1)); else no_count_b=$((no_count_b + 1)); fi
    if [[ "$status_final" == "YES" ]]; then yes_count_final=$((yes_count_final + 1)); else no_count_final=$((no_count_final + 1)); fi
  done < "$TMP_STATUS"

  total=$((yes_count_final + no_count_final))
  echo "Podsumowanie A: YES=$yes_count_a, NO=$no_count_a"
  echo "Podsumowanie B: YES=$yes_count_b, NO=$no_count_b"
  echo "Podsumowanie FINAL: YES=$yes_count_final, NO=$no_count_final, RAZEM=$total"
} > "$REPORT_FILE"

echo "Report written to: $REPORT_FILE"