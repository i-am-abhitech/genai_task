#!/usr/bin/env bash
# genai_copy_and_archive.sh
# Copy one or more source files/directories to one or more destination directories
# and create tar archives at each destination. Records an operation log under
# a local operations folder inside the repository (genai_task_operations).
#
# Usage:
#   ./genai_copy_and_archive.sh <src1> [src2 ...] [--dest dst1 [dst2 ...]]
#
# If --dest is omitted, the script will prompt you to enter one or more
# destination directories (comma or space separated). Destinations may be
# absolute or relative paths. The script will refuse to write outside the
# destination directories you provide.
#
# For each destination, the script copies the source items into a timestamped
# subdirectory under the destination and creates a tar.gz archive of the
# copied items in the destination. A per-operation manifest/log is written
# to ./genai_task_operations/<timestamp>/manifest.txt in the script directory.
#
# Examples:
#  ./genai_copy_and_archive.sh /path/to/file1 /path/to/dir2 --dest /mnt/backup1 /mnt/backup2
#  ./genai_copy_and_archive.sh src_file.txt   # will prompt for destination(s)

set -euo pipefail
IFS=$' \t\n'

# Ensure bash
if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "Error: this script must be run with bash. Use: bash $0 ..." >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPS_ROOT="$SCRIPT_DIR/genai_task_operations"

timestamp() { date -u +"%Y%m%dT%H%M%SZ"; }

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") <src1> [src2 ...] [--dest dst1 [dst2 ...]]

If --dest is omitted, you'll be prompted to enter destination directories.
USAGE
}

if [[ ${#@} -eq 0 ]]; then
  usage
  exit 1
fi

# Parse args: collect srcs until optional --dest
SRCs=()
DESTs=()
MODE="src"
for arg in "$@"; do
  if [[ "$arg" == "--dest" ]]; then
    MODE="dest"
    continue
  fi
  if [[ "$MODE" == "src" ]]; then
    SRCs+=("$arg")
  else
    DESTs+=("$arg")
  fi
done

if [[ ${#SRCs[@]} -eq 0 ]]; then
  echo "Error: no source files/directories provided." >&2
  usage
  exit 1
fi

# If no destinations provided, prompt user
if [[ ${#DESTs[@]} -eq 0 ]]; then
  echo -n "Enter destination directory or directories (comma or space separated): "
  read -r dest_line
  if [[ -z "$dest_line" ]]; then
    echo "No destination provided. Exiting." >&2
    exit 2
  fi
  # split by commas and/or whitespace
  IFS=',' read -ra parts <<< "$dest_line"
  DESTs=()
  for p in "${parts[@]}"; do
    # trim
    trimmed=$(echo "$p" | xargs)
    if [[ -n "$trimmed" ]]; then
      # allow multiple whitespace-separated entries inside each part
      for q in $trimmed; do
        DESTs+=("$q")
      done
    fi
  done
fi

# Resolve and validate sources
resolved_srcs=()
for s in "${SRCs[@]}"; do
  if [[ ! -e "$s" ]]; then
    echo "Error: source '$s' does not exist." >&2
    exit 3
  fi
  # get absolute realpath
  if command -v realpath >/dev/null 2>&1; then
    r=$(realpath -m "$s")
  elif command -v python3 >/dev/null 2>&1; then
    r=$(python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$s")
  else
    # naive fallback
    (cd "$(dirname "$s")" 2>/dev/null && echo "$(pwd -P)/$(basename "$s")") >/dev/null 2>&1 || r="$s"
  fi
  resolved_srcs+=("$r")
done

# Resolve and prepare destinations
resolved_dests=()
for d in "${DESTs[@]}"; do
  # create destination if missing? ask the user
  if [[ -e "$d" && ! -d "$d" ]]; then
    echo "Error: destination exists and is not a directory: $d" >&2
    exit 4
  fi
  if [[ ! -e "$d" ]]; then
    echo -n "Destination '$d' does not exist. Create it? [y/N]: "
    read -r yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      mkdir -p "$d"
      echo "Created destination: $d"
    else
      echo "Skipping destination $d" >&2
      continue
    fi
  fi
  # resolve realpath
  if command -v realpath >/dev/null 2>&1; then
    rd=$(realpath -m "$d")
  elif command -v python3 >/dev/null 2>&1; then
    rd=$(python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$d")
  else
    (cd "$d" 2>/dev/null && echo "$(pwd -P)") >/dev/null 2>&1 || rd="$d"
  fi
  resolved_dests+=("$rd")
done

if [[ ${#resolved_dests[@]} -eq 0 ]]; then
  echo "No valid destinations to process. Exiting." >&2
  exit 5
fi

# Prepare operation folder
TS=$(timestamp)
OP_DIR="$OPS_ROOT/$TS"
mkdir -p "$OP_DIR"
MANIFEST="$OP_DIR/manifest.txt"
exec 3>&1 4>&2
# tee output to both stdout and manifest
# We'll write summary lines to manifest explicitly

echo "Operation timestamp: $TS" | tee "$MANIFEST"
echo "Script dir: $SCRIPT_DIR" | tee -a "$MANIFEST"
echo "Sources:" | tee -a "$MANIFEST"
for s in "${resolved_srcs[@]}"; do echo " - $s" | tee -a "$MANIFEST"; done
echo "Destinations:" | tee -a "$MANIFEST"
for d in "${resolved_dests[@]}"; do echo " - $d" | tee -a "$MANIFEST"; done

echo
# For each destination, create a subdir named copied_<TS>
for dest in "${resolved_dests[@]}"; do
  subdir="$dest/copied_$TS"
  echo "Processing destination: $dest" | tee -a "$MANIFEST"
  mkdir -p "$subdir"

  # copy each source into subdir
  for src in "${resolved_srcs[@]}"; do
    base=$(basename "$src")
    destpath="$subdir/$base"
    echo "Copying $src -> $destpath" | tee -a "$MANIFEST"
    if command -v rsync >/dev/null 2>&1; then
      # preserve attributes, copy recursively for dirs
      rsync -a --no-links "$src" "$destpath"
    else
      if [[ -d "$src" ]]; then
        cp -a "$src" "$destpath"
      else
        cp -p "$src" "$destpath"
      fi
    fi
  done

  # create tar.gz of the copied subdir contents (single archive per destination)
  archive_name="$dest/archive_${TS}.tar.gz"
  echo "Creating archive $archive_name" | tee -a "$MANIFEST"
  (cd "$dest" && tar -czf "archive_${TS}.tar.gz" "copied_$TS")
  echo "Archive created: $archive_name" | tee -a "$MANIFEST"

  # record sizes
  if command -v du >/dev/null 2>&1; then
    size_bytes=$(du -sb "$subdir" 2>/dev/null | cut -f1 || true)
  else
    size_bytes=0
  fi
  echo "Copied size (bytes): ${size_bytes:-0}" | tee -a "$MANIFEST"
  echo "---" | tee -a "$MANIFEST"
done

# final summary
echo
echo "Operation complete. Manifest: $MANIFEST"
echo "Operation artifacts written under: $OP_DIR"

exit 0
