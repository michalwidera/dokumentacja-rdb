#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DEFAULT="$HOME/github/watermarks-remover/service/scripts"
SCRIPTS_DIR="${SCRIPTS:-$SCRIPTS_DEFAULT}"
INSPECTOR="$SCRIPTS_DIR/inspect_file.py"
CLEANER="$SCRIPTS_DIR/clean_file.py"
REPORT_FILE="$ROOT_DIR/watermark_inspect_report.md"
TMP_STATUS="$(mktemp)"
DO_CLEAN=0
DO_CLEAN_DRY_RUN=0
DO_CLEAN_BAK=0

print_help() {
  cat <<'EOF'
Usage: ./generate_watermark_report.sh [options] [report_path]

Options:
  -h, --help     Show this help message.
  -clean         Run clean_file.py --in-place for each file flagged as [YES],
                 then regenerate the report.
  -clean-dry-run Show which [YES] files would be cleaned, do not modify files.
  -clean-bak     Remove all *.bak files recursively under ./dokumentacja-rdb.

Arguments:
  report_path    Optional output path for the report (default:
                 ./watermark_inspect_report.md)

Environment:
  SCRIPTS        Path to watermarks-remover service scripts directory.
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

if [[ ! -f "$CLEANER" ]]; then
  echo "ERROR: cleaner not found: $CLEANER" >&2
  echo "Set SCRIPTS env variable, e.g.:" >&2
  echo "  SCRIPTS=/path/to/watermarks-remover/service/scripts $0" >&2
  exit 1
fi

cd "$ROOT_DIR"

collect_statuses() {
  : > "$TMP_STATUS"
  find . -type f -name '*.md' | sort | while read -r file; do
    if python3 "$INSPECTOR" "$file" >/dev/null 2>&1; then
      status="NO"
    else
      status="YES"
    fi
    printf "%s\t%s\n" "${file#./}" "$status" >> "$TMP_STATUS"
  done
}

run_clean_for_yes_files() {
  local yes_count=0
  while IFS=$'\t' read -r path status; do
    if [[ "$status" == "YES" ]]; then
      python3 "$CLEANER" "$path" --in-place >/dev/null
      yes_count=$((yes_count + 1))
    fi
  done < "$TMP_STATUS"
  echo "Cleaned files: $yes_count"
}

show_yes_files_for_dry_run() {
  local yes_count=0
  echo "[clean-dry-run] Files marked as [YES]:"
  while IFS=$'\t' read -r path status; do
    if [[ "$status" == "YES" ]]; then
      echo "- $path"
      yes_count=$((yes_count + 1))
    fi
  done < "$TMP_STATUS"
  echo "[clean-dry-run] Total files to clean: $yes_count"
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

{
  echo "# Raport inspect_file.py dla plikow .md"
  echo
  echo "Legenda: YES = wykryto znaki/metadata przez inspect_file.py, NO = brak wykrycia"
  echo
  awk -F '\t' '
    BEGIN {
      print "dokumentacja-rdb/"
    }
    {
      path = $1
      status = $2
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
      print indent "- " parts[depth] " [" status "]"
    }
    END {
      print ""
    }
  ' "$TMP_STATUS"

  yes_count=0
  no_count=0
  while IFS=$'\t' read -r _ status; do
    if [[ "$status" == "YES" ]]; then
      yes_count=$((yes_count + 1))
    else
      no_count=$((no_count + 1))
    fi
  done < "$TMP_STATUS"

  total=$((yes_count + no_count))
  echo "Podsumowanie: YES=$yes_count, NO=$no_count, RAZEM=$total"
} > "$REPORT_FILE"

echo "Report written to: $REPORT_FILE"