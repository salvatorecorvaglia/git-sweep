# Git Bulk Branch Updater

This Bash script recursively scans a base directory for Git repositories and updates each local branch that has a tracking upstream branch. It fetches the latest changes from all remotes and performs **fast-forward-only merges** to ensure local branches stay synchronized with their upstream counterparts.

## Features

- Detects all Git repositories under a given base directory.
- Skips repositories with uncommitted changes.
- Automatically fetches updates from all remotes.
- Updates all branches that have tracking branches, using **fast-forward-only merges**.
- Supports a **dry-run mode** to preview actions without making any changes.
- Handles **detached HEADs** and empty repositories gracefully.
- Provides detailed output with color-coded messages for clarity.
- Shows commits to be merged when fast-forward merge is not possible.
- Exits with non-zero status if any branch could not be fast-forwarded.
- Portable and tested on macOS, Linux, and WSL environments.

## Requirements

- Bash (with `set -euo pipefail` support)
- Git

## Installation

```bash
chmod +x git-pull-all.sh
```

## Usage

```bash
./git-pull-all.sh [--dry-run] [--dir <base-directory>]
```
