#!/bin/bash

# Exit on error, undefined variable, or pipeline failure
set -euo pipefail

# Base directory containing Git repositories
BASE_DIR="/c/apps/"

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
# Supports: -n or --dry-run to simulate actions without making changes
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=1       # Enable dry-run mode
      shift           # Move to next argument
      ;;
    *)
      # Print usage and exit if unknown option is provided
      echo "Usage: $0 [--dry-run]" >&2
      exit 1
      ;;
  esac
done

# Ensure the base directory exists
if [ ! -d "$BASE_DIR" ]; then
  echo "❌ The directory '$BASE_DIR' does not exist."
  exit 1
fi

# Inform the user that the script is starting
echo "🔍 Running fetch and update for all tracked branches in repositories under: $BASE_DIR"
echo

# Find all .git directories recursively under BASE_DIR
# Then process each Git repository found
find "$BASE_DIR" -type d -name ".git" -print0 | while IFS= read -r -d '' gitdir; do
  # Get parent directory of the .git folder (the repository root)
  repo_dir=$(dirname "$gitdir")
  echo "➡️  Repository: $repo_dir"

  (
    # Enter the repository directory
    cd "$repo_dir" || exit

    # Check if the directory is a valid Git worktree
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "❌ Not a Git repository: $repo_dir"
      continue
    fi

    # Skip repositories with uncommitted changes
    if ! git diff-index --quiet HEAD --; then
      echo "⚠️  Uncommitted changes found. Skipping."
      continue
    fi

    # Determine the currently checked-out branch
    current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    if [ -z "$current_branch" ]; then
      echo "⚠️  No active branch (detached HEAD or empty repo). Skipping."
      continue
    fi

    # Fetch latest updates from all remotes
    for remote in $(git remote); do
      echo "🌐 Fetching from remote: $remote"
      git fetch "$remote" --prune --quiet
    done

    # Iterate through local branches with upstream tracking branches
    git for-each-ref --format='%(refname:short) %(upstream:short)' refs/heads/ | while IFS=' ' read -r branch upstream; do
      if [ -n "$upstream" ]; then
        echo "🔄 Updating $branch from $upstream"

        if [ "$DRY_RUN" -eq 1 ]; then
          # In dry-run mode, show what would be done
          echo "🧪 [Dry-run] Would checkout $branch and merge from $upstream"
          continue
        fi

        # Checkout the branch
        git checkout "$branch" --quiet || {
          echo "❌ Failed to checkout $branch"
          continue
        }

        # Attempt a fast-forward-only merge from the upstream
        if git merge --ff-only "$upstream" > /dev/null 2>&1; then
          echo "✅ $branch updated"
        else
          # If fast-forward is not possible, show the commits to be merged
          echo "⚠️  Merge failed on $branch (non fast-forward)"
          count=$(git rev-list --count "$branch..$upstream")
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

    # Return to the originally checked-out branch
    git checkout "$current_branch" --quiet 2>/dev/null
  )

  # Separator between repositories
  echo "-----------------------------------"
done

# Final message
echo "✅ Update completed for all repositories."

# Exit with 1 if any merge failed, 0 otherwise
exit $merge_failed
