# genai_folder_info - README

This README describes the genai_folder_info.sh utility included in this repository.

Purpose

- Analyze a folder (default: the script directory) to count regular files and report disk usage.
- Provide an "explain" mode to inspect a single file inside the folder and display metadata and a content preview.

Files

- `genai_folder_info.sh` — the script that performs the analysis and file explanation.
  - Script URL: https://github.com/i-am-abhitech/genai_task/blob/main/genai_folder_info.sh

Installation

1. Clone the repository (if not already):

   git clone git@github.com:i-am-abhitech/genai_task.git
   cd genai_task

2. Make the script executable:

   chmod +x genai_folder_info.sh

Usage

Summary mode (default)

- Run the script with no arguments to analyze the script directory:

  ./genai_folder_info.sh

- Or pass a directory path to analyze another folder:

  ./genai_folder_info.sh path/to/dir

What it reports (summary mode)

- Total regular files under the target folder.
- Disk usage reported by du for the folder (bytes and human-readable).
- Sum of regular-file sizes (bytes and human-readable).
- Top 10 largest regular files (human-readable sizes and relative paths).

Explain mode (file details)

- Usage:

  ./genai_folder_info.sh explain <relative-path-to-file>

  Example: ./genai_folder_info.sh explain README.md

- The filename must be specified relative to the repository/script directory (no absolute paths).
- The script will refuse to show files outside the allowed folder for safety.

What it shows (explain mode)

- Full path and resolved path.
- Size (bytes and human-readable) and basic permissions/timestamps.
- MIME type (if the file command is available).
- Line and word counts for text files.
- SHA256 checksum (if sha256sum or shasum is available).
- A preview of the file contents (first 200 lines) for text files.
- For binaries, a small hexdump of the first 256 bytes is shown instead of raw content.

Security and limits

- The script disallows absolute paths and prevents accessing files outside the script directory.
- Previews are truncated (200 lines for text, 256 bytes hexdump for binaries) to avoid huge output.

Exit codes

- 0 — success
- Non-zero — error (invalid arguments, missing file, or file outside allowed location)

Dependencies and fallbacks

- Uses common POSIX utilities: find, du, awk, stat, head, file, sha256sum/shasum.
- Where utilities are missing, the script attempts reasonable fallbacks (e.g., python3 realpath fallback).

Examples

1) Analyze the repository directory:

   ./genai_folder_info.sh

2) Analyze a subfolder called examples:

   ./genai_folder_info.sh examples/

3) Explain a file README.md:

   ./genai_folder_info.sh explain README.md

Notes

- This README is intentionally focused on genai_folder_info.sh. The repository also contains a VM health-check script (`vm_health_check.sh`).

- If you'd like, I can add a top-level documentation file that indexes both utilities, add a license file, or add a CI workflow to run shellcheck on commits.
