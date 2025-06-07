# Git Bulk Branch Updater

This Bash script recursively scans a base directory for Git repositories and updates each local branch that has a tracking upstream branch. It fetches the latest changes and performs **fast-forward-only merges** to ensure the local branches are synchronized with their upstream counterparts.

## Features

- Detects all Git repositories under a given base directory.
- Skips repositories with uncommitted changes.
- Automatically fetches updates from all remotes.
- Updates all branches that have tracking branches, using fast-forward-only merges.
- Supports a dry-run mode to preview actions without making changes.
- Gracefully handles detached HEADs and non-fast-forward cases.
- Exits with non-zero status if any branch could not be fast-forwarded.
- Portable and tested on macOS, Linux, and WSL environments.

## Requirements

- Bash
- Git

## Usage

```bash
./git-pull-all.sh [--dry-run] [--dir <base-directory>]