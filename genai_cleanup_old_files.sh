#!/usr/bin/env bash
# genai_cleanup_old_files.sh
# Find files older than N days in a target directory, show the list, and ask user to confirm deletion.
# Usage:
#   ./genai_cleanup_old_files.sh [target_dir] [days]
#   ./genai_cleanup_old_files.sh --days 30 --target /path/to/dir
#   ./genai_cleanup_old_files.sh --days 60 --yes    # non-interactive (confirm)
#
# Defaults:
#  target_dir = script directory
#  days = 30

set -euo pipefail

# Ensure running under bash
if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "Error: this script requires bash. Run with: bash $0 ..." >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$SCRIPT_DIR"
DAYS=30
ASSUME_YES=false
DRY_RUN=false

usage(){
  cat <<USAGE
Usage: $(basename "$0") [options] [target_dir]

Options:
  --days N        Find files older than N days (default: 30)
  --target DIR    Target directory to scan (default: script directory)
  --yes           Do not prompt; delete automatically (USE WITH CAUTION)
  --dry-run       Show what would be deleted but do not delete
  -h, --help      Show this help

Examples:
  $(basename "$0")                      # scan script directory for files older than 30 days
  $(basename "$0") /var/log             # scan /var/log with default 30 days
  $(basename "$0") --days 90            # scan for files older than 90 days
  $(basename "$0") --days 7 --dry-run  # preview files older than 7 days
  $(basename "$0") --target /tmp --yes  # delete without prompting
USAGE
}

# simple arg parsing
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --days)
      DAYS="$2"; shift 2;;
    --target)
      TARGET_DIR="$2"; shift 2;;
    --yes)
      ASSUME_YES=true; shift;;
    --dry-run)
      DRY_RUN=true; shift;;
    -h|--help)
      usage; exit 0;;
    --) shift; break;;
    -*) echo "Unknown option: $1" >&2; usage; exit 2;;
    *) ARGS+=("$1"); shift;;
  esac
done

# If a positional arg remains, treat as target dir
if [[ ${#ARGS[@]} -gt 0 ]]; then
  TARGET_DIR="${ARGS[0]}"
fi

# validate days is integer
if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
  echo "Error: --days must be a non-negative integer." >&2
  exit 2
fi

# Resolve target dir
resolve_realpath(){
  if command -v realpath >/dev/null 2>&1; then
    realpath -m "$1"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$1"
  else
    (cd "$1" 2>/dev/null && pwd -P) || return 1
  fi
}

if [[ ! -e "$TARGET_DIR" ]]; then
  echo "Error: target directory '$TARGET_DIR' does not exist." >&2
  exit 3
fi
if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Error: target '$TARGET_DIR' is not a directory." >&2
  exit 3
fi

TARGET_REAL=$(resolve_realpath "$TARGET_DIR") || { echo "Failed to resolve path" >&2; exit 3; }

printf "Scanning directory: %s\n" "$TARGET_REAL"
printf "Finding regular files older than %s days...\n" "$DAYS"

# find files older than N days; exclude directories, follow symlinks? we avoid following symlinks to be safe
# Use -type f for regular files
mapfile -t OLD_FILES < <(find "$TARGET_REAL" -type f -mtime +$DAYS -print 2>/dev/null || true)

COUNT=${#OLD_FILES[@]}

if (( COUNT == 0 )); then
  echo "No regular files older than $DAYS days were found in $TARGET_REAL."
  exit 0
fi

echo
echo "Found $COUNT file(s) older than $DAYS days:" 
for f in "${OLD_FILES[@]}"; do
  printf " - %s\n" "${f}"
done

# show total size of files
TOTAL_BYTES=0
for f in "${OLD_FILES[@]}"; do
  if [[ -r "$f" ]]; then
    # use stat to get size
    size=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null || wc -c <"$f")
    TOTAL_BYTES=$((TOTAL_BYTES + size))
  fi
done

# human readable size
human_readable(){
  awk 'function human(x){s="B KMGTPE"; i=0; while(x>=1024 && i<6){x/=1024; i++} units[0]="B"; units[1]="KB"; units[2]="MB"; units[3]="GB"; units[4]="TB"; units[5]="PB"; printf("%.2f %s", x, units[i])} {human($1)}' <<< "$1"
}

printf "Total size of these files: %s (%d bytes)\n" "$(human_readable $TOTAL_BYTES)" "$TOTAL_BYTES"

# Prompt user to confirm deletion
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry-run mode enabled; no files will be deleted.";
  exit 0
fi

if [[ "$ASSUME_YES" == true ]]; then
  RESP="y"
else
  echo
  read -p "Do you want to delete these $COUNT files? Type 'yes' to confirm: " RESP
fi

if [[ "$RESP" != "y" && "$RESP" != "yes" ]]; then
  echo "Aborting: no files were deleted.";
  exit 0
fi

# Proceed to delete files; delete only those listed
DELETED=0
FAILED=0
for f in "${OLD_FILES[@]}"; do
  if rm -f -- "$f"; then
    ((DELETED++))
  else
    echo "Failed to delete: $f" >&2
    ((FAILED++))
  fi
done

echo
printf "Deletion complete. Deleted: %d, Failed: %d\n" "$DELETED" "$FAILED"

exit 0
