#!/usr/bin/env bash
# genai_folder_info.sh
# Analyze a folder: count files and disk usage, and explain file contents.
# Usage:
#   ./genai_folder_info.sh [target_folder]
#   ./genai_folder_info.sh explain <relative-path-to-file>
#
# Default target_folder is the script directory (useful when run from repo root).

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

human_readable() {
  # humanize bytes
  num=$1
  awk 'function human(x){s="B KMGTPE"; i=0; while(x>=1024 && i<6){x/=1024; i++} printf("%.2f %s", x, substr(s, i*1+1,1) )} {human($1)}' <<< "$num"
}

usage() {
  cat <<'USAGE'
Usage:
  genai_folder_info.sh [target_folder]
    - Reports total number of regular files and disk space used by the target folder (default: script directory).

  genai_folder_info.sh explain <relative-path-to-file>
    - Shows detailed information about a particular file inside the repository/folder where the script resides.
    - The filename must be given relative to the script directory (e.g. "README.md" or "subdir/file.txt").
USAGE
}

# Ensure argument parsing
if [[ ${1:-} == "" ]]; then
  MODE="summary"
else
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
  fi
  if [[ "$1" == "explain" ]]; then
    MODE="explain"
    FILE_ARG=${2:-}
    if [[ -z "$FILE_ARG" ]]; then
      echo "Error: missing filename for explain." >&2
      usage
      exit 2
    fi
  else
    MODE="summary"
    TARGET_DIR_ARG=$1
  fi
fi

# resolve and safety helpers
resolve_realpath() {
  # prefer realpath if available
  if command -v realpath >/dev/null 2>&1; then
    realpath "$1"
  else
    # fallback: use python if present
    if command -v python3 >/dev/null 2>&1; then
      python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$1"
    else
      # best-effort: cd + pwd
      (cd "$1" 2>/dev/null && pwd) || return 1
    fi
  fi
}

# Summary mode: count files and disk usage
if [[ "$MODE" == "summary" ]]; then
  TARGET_DIR=${TARGET_DIR_ARG:-$SCRIPT_DIR}

  # make sure directory exists
  if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: target directory '$TARGET_DIR' does not exist." >&2
    exit 2
  fi

  TARGET_DIR_REAL=$(resolve_realpath "$TARGET_DIR") || { echo "Failed to resolve path" >&2; exit 2; }

  echo "Analyzing folder: $TARGET_DIR_REAL"

  # total regular files
  total_files=$(find "$TARGET_DIR_REAL" -type f | wc -l)

  # disk usage of the folder (du includes directories overhead). Use du -sb if available for bytes.
  if du --version >/dev/null 2>&1; then
    # GNU du
    disk_bytes=$(du -sb "$TARGET_DIR_REAL" 2>/dev/null | cut -f1)
  else
    # fallback to du -sk and multiply by 1024
    disk_kb=$(du -sk "$TARGET_DIR_REAL" 2>/dev/null | cut -f1)
    disk_bytes=$(( disk_kb * 1024 ))
  fi

  # total size of regular files only (sum of file sizes). This is more precise than du for contents.
  total_files_bytes=$(find "$TARGET_DIR_REAL" -type f -printf "%s\n" 2>/dev/null | awk '{s+=$1} END{print s+0}')

  echo "Total regular files: $total_files"
  echo "Disk usage (du for folder): $([ -n "$disk_bytes" ] && human_readable "$disk_bytes" || echo "N/A") ($disk_bytes bytes)"
  echo "Sum of regular files sizes: $([ -n "$total_files_bytes" ] && human_readable "$total_files_bytes" || echo "N/A") ($total_files_bytes bytes)"

  # top 10 largest files inside folder
  echo
  echo "Top 10 largest regular files (within folder):"
  # list files with sizes and relative paths
  find "$TARGET_DIR_REAL" -type f -printf "%s\t%p\n" 2>/dev/null | sort -nr | head -n 10 | awk -v base="$TARGET_DIR_REAL" 'BEGIN{OFS="\t"}{size=$1; $1=""; sub(/^\t/,"",$0); path=$0; rel=substr(path,length(base)+2); if(rel=="") rel=path; printf "%s\t%s\n", size, rel}' | while IFS=$'\t' read -r size relpath; do
    printf "%10s  %s\n" "$(human_readable $size)" "$relpath"
  done

  exit 0
fi

# Explain mode: show details for a specific file inside the script directory
if [[ "$MODE" == "explain" ]]; then
  # ensure filename is relative and inside SCRIPT_DIR
  requested="$FILE_ARG"

  # prevent absolute paths
  if [[ "$requested" = /* ]]; then
    echo "Error: please provide filename relative to repository/script directory (no absolute paths)." >&2
    exit 2
  fi

  target_path="$SCRIPT_DIR/$requested"
  target_real=$(resolve_realpath "$target_path") || { echo "Error: cannot resolve target path." >&2; exit 2; }
  base_real=$(resolve_realpath "$SCRIPT_DIR") || { echo "Error: cannot resolve script directory." >&2; exit 2; }

  case "$target_real" in
    "$base_real"|"$base_real"/*) ;;
    *) echo "Error: requested file is outside the allowed folder." >&2; exit 2;;
  esac

  if [[ ! -e "$target_real" ]]; then
    echo "Error: file '$requested' does not exist." >&2
    exit 3
  fi

  if [[ -d "$target_real" ]]; then
    echo "Requested path is a directory. Provide a file path." >&2
    exit 3
  fi

  echo "File: $requested"
  echo "Full path: $target_real"
  # size
  size_bytes=$(stat -c%s "$target_real" 2>/dev/null || stat -f%z "$target_real" 2>/dev/null || wc -c <"$target_real")
  echo "Size: $size_bytes bytes ($(human_readable $size_bytes))"
  # permissions and timestamps
  if stat --version >/dev/null 2>&1; then
    # GNU stat
    perms=$(stat -c "%A" "$target_real")
    mtime=$(stat -c "%y" "$target_real")
  else
    perms=$(stat -f "%Sp" "$target_real")
    mtime=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$target_real")
  fi
  echo "Permissions: $perms"
  echo "Last modified: $mtime"
  echo
  # file type
  if command -v file >/dev/null 2>&1; then
    ftype=$(file -b --mime-type "$target_real")
    echo "MIME type: $ftype"
  fi

  # if binary, warn and show limited info
  if command -v file >/dev/null 2>&1 && file -b --mime-encoding "$target_real" | grep -qi "binary"; then
    echo "(binary file detected)"
    # show hexdump of first 256 bytes
    echo "Hexdump (first 256 bytes):"
    dd if="$target_real" bs=1 count=256 2>/dev/null | hexdump -C | sed -n '1,8p'
    exit 0
  fi

  # textual file: lines, words, checksum, preview
  lines=$(wc -l < "$target_real" 2>/dev/null || echo 0)
  words=$(wc -w < "$target_real" 2>/dev/null || echo 0)
  echo "Lines: $lines"
  echo "Words: $words"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256=$(sha256sum "$target_real" | awk '{print $1}')
    echo "SHA256: $sha256"
  elif command -v shasum >/dev/null 2>&1; then
    sha256=$(shasum -a 256 "$target_real" | awk '{print $1}')
    echo "SHA256: $sha256"
  fi

  echo
  echo "--- File preview (first 200 lines) ---"
  # print up to 200 lines
  head -n 200 "$target_real" || true
  echo
  if (( lines > 200 )); then
    echo "(file truncated in preview — use a pager or cat to view full content)"
  fi

  exit 0
fi
