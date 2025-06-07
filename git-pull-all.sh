#!/bin/bash

# Exit on error, undefined variable, or pipeline failure
set -euo pipefail

# Default base directory containing Git repositories
BASE_DIR="${HOME}/folder"

# Flag to indicate dry-run mode (0 = false, 1 = true)
DRY_RUN=0

# Flag to indicate if any merge failed (0 = success, 1 = failure)
merge_failed=0

# Check if git is available
if ! command -v git >/dev/null 2>&1; then
  echo "❌ git command not found. Please install Git."
  exit 1
fi

# Parse command-line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -d|--dir)
      BASE_DIR="$2"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--dry-run] [--dir <base-directory>]" >&2
      exit 1
      ;;
  esac
done

# Ensure the base directory exists
if [ ! -d "$BASE_DIR" ]; then
  echo "❌ The directory '$BASE_DIR' does not exist."
  exit 1
fi

echo "🔍 Running fetch and update for all tracked branches in repositories under: $BASE_DIR"
echo

# Find all .git directories recursively under BASE_DIR
# Use find -print0 and read with IFS= for filenames with spaces
find "$BASE_DIR" -type d -name ".git" -print0 | while IFS= read -r -d '' gitdir; do
  repo_dir=$(dirname "$gitdir")
  echo "➡️  Repository: $repo_dir"

  (
    cd "$repo_dir" || exit

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "❌ Not a Git repository: $repo_dir"
      continue
    fi

    if ! git diff-index --quiet HEAD --; then
      echo "⚠️  Uncommitted changes found. Skipping."
      continue
    fi

    current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || true)
    if [ -z "$current_branch" ]; then
      echo "⚠️  No active branch (detached HEAD or empty repo). Skipping."
      continue
    fi

    for remote in $(git remote); do
      echo "🌐 Fetching from remote: $remote"
      git fetch "$remote" --prune --quiet
    done

    git for-each-ref --format='%(refname:short) %(upstream:short)' refs/heads/ | while IFS=' ' read -r branch upstream; do
      if [ -n "$upstream" ]; then
        echo "🔄 Updating $branch from $upstream"

        if [ "$DRY_RUN" -eq 1 ]; then
          echo "🧪 [Dry-run] Would checkout $branch and merge from $upstream"
          continue
        fi

        git checkout "$branch" --quiet || {
          echo "❌ Failed to checkout $branch"
          continue
        }

        if git merge --ff-only "$upstream" > /dev/null 2>&1; then
          echo "✅ $branch updated"
        else
          echo "⚠️  Merge failed on $branch (non fast-forward)"
          count=$(git rev-list --count "$branch..$upstream" || echo 0)
          if [ "$count" -eq 0 ]; then
            echo "ℹ️  Branch is up to date with upstream."
          else
            echo "🔍 Commits to be merged:"
            git log "$branch..$upstream" --oneline
          fi
          merge_failed=1
        fi
      fi
    done

    git checkout "$current_branch" --quiet 2>/dev/null || true
  )

  echo "-----------------------------------"
done

echo "✅ Update completed for all repositories."
exit $merge_failed