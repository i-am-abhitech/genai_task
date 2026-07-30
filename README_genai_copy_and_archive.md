# genai_copy_and_archive - README

This README describes the genai_copy_and_archive.sh utility included in this repository.

Purpose

- Copy given source files and/or directories to one or more destination directories.
- For each destination, create a timestamped subdirectory and produce a tar.gz archive of the copied content.
- Record an operation manifest/log per run under ./genai_task_operations/<timestamp>/manifest.txt.

Files

- `genai_copy_and_archive.sh` — the script that performs copy + archive operations.
  - Script URL: https://github.com/i-am-abhitech/genai_task/blob/main/genai_copy_and_archive.sh

Installation

1. Clone the repository (if not already):

   git clone git@github.com:i-am-abhitech/genai_task.git
   cd genai_task

2. Make the script executable:

   chmod +x genai_copy_and_archive.sh

Usage

- Command-line (provide sources and destinations):

  ./genai_copy_and_archive.sh <src1> [src2 ...] --dest <dst1> [dst2 ...]

  Example:
    ./genai_copy_and_archive.sh /path/to/file.txt /path/to/dir --dest /mnt/backup1 /mnt/backup2

- Interactive (omit --dest to be prompted):

  ./genai_copy_and_archive.sh /path/to/file.txt
  The script will prompt you to enter one or more destination directories (comma or space separated).

Behavior

- For each destination provided:
  - Creates a subdirectory: <destination>/copied_<timestamp> and copies each source item into it.
  - Creates an archive: <destination>/archive_<timestamp>.tar.gz containing the copied_<timestamp> subdirectory.
  - Writes an operation manifest under ./genai_task_operations/<timestamp>/manifest.txt listing sources, destinations, copy actions and sizes.

Examples

1) Copy two sources to two destinations (non-interactive):

   ./genai_copy_and_archive.sh ./file1 ./dir2 --dest /mnt/backupA /mnt/backupB

2) Copy and be prompted for destinations (interactive):

   ./genai_copy_and_archive.sh ./file1

3) Check operation logs:

   ls genai_task_operations/
   cat genai_task_operations/<timestamp>/manifest.txt

Notes & Safety

- The script will prompt to create destinations that do not exist.
- It relies on `rsync` when available for reliable copying; falls back to `cp -a` / `cp -p` otherwise.
- The script writes operation artifacts under the repository folder `genai_task_operations` by default; you can change this behavior by editing the script variable `OPS_ROOT`.

Exit codes

- 0 on success; non-zero on errors (missing sources, invalid destination, or failures during copy/archive).

Dependencies

- bash, tar, cp, mkdir, (optional) rsync, realpath (optional), python3 (fallback for realpath).

License

MIT
