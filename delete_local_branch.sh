#!/bin/bash

# Exit immediately on error, unset variables, or pipeline failure
set -euo pipefail

BASE_DIR="${HOME}/Desktop/apps"
TARGET_BRANCH=""

# Counters
total_repos=0
deleted=0
skipped=0
failed=0

# Check if git exists
if ! command -v git >/dev/null 2>&1; then
  echo "❌ Git not found. Please install it before running this script."
  exit 1
fi

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dir)
      BASE_DIR="$2"
      shift 2
      ;;
    -b|--branch)
      TARGET_BRANCH="$2"
      shift 2
      ;;
    *)
      echo "Usage: $0 --branch <branch> [--dir <path>]"
      exit 1
      ;;
  esac
done

# Check branch arg
if [ -z "$TARGET_BRANCH" ]; then
  echo "❌ You must specify: --branch <branch-name>"
  exit 1
fi

# Check directory
if [ ! -d "$BASE_DIR" ]; then
  echo "❌ Directory does not exist: $BASE_DIR"
  exit 1
fi

echo "🗑️  Deleting local branch: '$TARGET_BRANCH'"
echo "📁 Base directory: $BASE_DIR"
echo

# Loop through all repositories
while IFS= read -r -d '' gitdir; do
  repo_dir=$(dirname "$gitdir")
  echo "➡️  Repository: $repo_dir"

  total_repos=$((total_repos + 1))

  prev_dir=$(pwd)
  cd "$repo_dir" || { echo "❌ Error accessing repository"; failed=$((failed + 1)); continue; }

  # Validate Git repository
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Not a Git repository"
    skipped=$((skipped + 1))
    cd "$prev_dir"
    echo "-----------------------------------"
    continue
  fi

  # Check if local branch exists
  if ! git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
    echo "⏭️  Local branch does not exist: $TARGET_BRANCH"
    skipped=$((skipped + 1))
    cd "$prev_dir"
    echo "-----------------------------------"
    continue
  fi

  # Do not delete the currently checked-out branch
  current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "(detached)")

  if [ "$current_branch" = "$TARGET_BRANCH" ]; then
    echo "⚠️  Branch '$TARGET_BRANCH' is currently checked out. Skipping."
    skipped=$((skipped + 1))
    cd "$prev_dir"
    echo "-----------------------------------"
    continue
  fi

  # Delete the branch
  if git branch -D "$TARGET_BRANCH" >/dev/null 2>&1; then
    echo "✅ Branch deleted: $TARGET_BRANCH"
    deleted=$((deleted + 1))
  else
    echo "❌ Branch deletion failed"
    failed=$((failed + 1))
  fi

  cd "$prev_dir"
  echo "-----------------------------------"

done < <(find "$BASE_DIR" -type d -name ".git" -print0)

echo "🏁 Operation completed."
echo "📦 Total repositories: $total_repos"
echo "🗑️  Deleted branches: $deleted"
echo "⏭️  Skipped: $skipped"
echo "❌ Failed: $failed"

exit $failed
