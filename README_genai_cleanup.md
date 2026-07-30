# genai_cleanup_old_files - README

This README documents `genai_cleanup_old_files.sh`, a utility that finds regular files older than N days in a target directory, shows the list to the user, and optionally deletes them after confirmation.

Script
- `genai_cleanup_old_files.sh` — find and optionally delete old files.
  - Script URL (example): https://github.com/i-am-abhitech/genai_task/blob/main/genai_cleanup_old_files.sh

Purpose
- Help reclaim disk space by locating files older than a specified age and removing them with user approval.
- Provide safe modes (dry-run, interactive confirmation) to avoid accidental deletion.

Installation
1. Clone the repository (if not already):
   git clone git@github.com:i-am-abhitech/genai_task.git
   cd genai_task

2. Make the script executable:
   chmod +x genai_cleanup_old_files.sh

Usage
- Default: scan the script directory for files older than 30 days:
  ./genai_cleanup_old_files.sh

- Scan a specific directory, e.g. /var/log:
  ./genai_cleanup_old_files.sh /var/log

- Specify days explicitly:
  ./genai_cleanup_old_files.sh --days 60 /var/log

- Use long-form options:
  ./genai_cleanup_old_files.sh --target /var/log --days 90

- Dry-run (show files but do not delete):
  ./genai_cleanup_old_files.sh --days 30 --target /var/log --dry-run

- Non-interactive deletion (dangerous — use carefully):
  ./genai_cleanup_old_files.sh --target /var/log --days 30 --yes

What it does
1. Resolves the target directory (default: script directory).
2. Finds regular files older than N days using `find -type f -mtime +N`.
3. Prints a list of files found and the combined size of those files.
4. If `--dry-run` is given, stops after reporting (no deletion).
5. Otherwise prompts the user to confirm deletion (type `yes` to proceed).
6. Deletes the listed files and reports counts of deleted / failed.

Exit codes
- `0` — success (no errors)
- Non-zero — various error conditions (invalid args, missing path, etc.)

Safety notes and recommendations
- This script deletes files permanently (rm -f). Always use `--dry-run` first on a new target.
- Use `--yes` only in automated contexts when you are certain of the target and sources.
- Run in a user account with proper permissions; the script will fail to delete files it cannot remove.
- Consider testing on a small sample directory before running on system directories (e.g., /var/log).

Example session
1) Preview files older than 30 days in /var/log:
   ./genai_cleanup_old_files.sh --target /var/log --days 30 --dry-run

2) Confirm and delete interactively:
   ./genai_cleanup_old_files.sh --target /var/log --days 30
   (the script lists files and asks: "Do you want to delete these N files? Type 'yes' to confirm:")

3) Non-interactive deletion (CI or scheduled job):
   ./genai_cleanup_old_files.sh --target /var/log --days 90 --yes

Dependencies and platform
- Requires bash (the script uses bash features). Run with `bash` if your default `sh` is not bash.
- Uses standard POSIX utilities: find, stat, awk, rm. `realpath` or `python3` is used for path resolution when available.

License
- MIT
