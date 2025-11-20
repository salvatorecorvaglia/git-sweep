#!/bin/bash

# Exit immediately on error, undefined variable usage, or pipeline failure
set -euo pipefail

# Default base directory containing Git repositories
BASE_DIR="${HOME}/Desktop/apps"

# Flag indicating dry-run mode (0 = false, 1 = true)
DRY_RUN=0

# Flag to indicate if any merge has failed (0 = success, 1 = failure)
merge_failed=0

# Check if git command is available
if ! command -v git >/dev/null 2>&1; then
  echo "❌ git command not found. Please install Git."
  exit 1
fi

# Parse command-line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      # Enable dry-run mode: do not perform actual merges, only show what would be done
      DRY_RUN=1
      shift
      ;;
    -d|--dir)
      # Set the base directory to scan for Git repositories
      BASE_DIR="$2"
      shift 2
      ;;
    *)
      # Unknown option or usage error
      echo "Usage: $0 [--dry-run] [--dir <base-directory>]" >&2
      exit 1
      ;;
  esac
done

# Check that the base directory exists
if [ ! -d "$BASE_DIR" ]; then
  echo "❌ The directory '$BASE_DIR' does not exist."
  exit 1
fi

echo "🔍 Running fetch and update for all tracked branches in repositories under: $BASE_DIR"
echo

# Find all .git directories recursively under BASE_DIR, handling filenames with spaces
while IFS= read -r -d '' gitdir; do
  # Get the repository root directory (parent of .git folder)
  repo_dir=$(dirname "$gitdir")
  echo "➡️  Repository: $repo_dir"

  # Save current directory and change to the repository directory
  prev_dir=$(pwd)
  cd "$repo_dir" || { echo "❌ Failed to enter $repo_dir"; continue; }

    # Confirm this is a valid Git working tree
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "❌ Not a Git repository: $repo_dir"
      continue
    fi

    # Get the current checked-out branch
    current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || true)
    if [ -z "$current_branch" ]; then
      echo "⚠️  No active branch (detached HEAD or empty repo). Skipping."
      cd "$prev_dir" || true
      continue
    fi

    # Skip if there are uncommitted changes in the working tree (only if HEAD exists)
    if git rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
      if ! git diff-index --quiet HEAD --; then
        echo "⚠️  Uncommitted changes found. Skipping."
        cd "$prev_dir" || true
        continue
      fi
    fi

    # Fetch updates from all remotes quietly, pruning deleted branches
    for remote in $(git remote); do
      echo "🌐 Fetching from remote: $remote"
      git fetch "$remote" --prune --quiet
    done

    # For each local branch that tracks an upstream branch, attempt fast-forward merge
    while IFS=' ' read -r branch upstream; do
      if [ -n "$upstream" ]; then
        echo "🔄 Updating $branch from $upstream"

        # If dry-run, just print what would be done without making changes
        if [ "$DRY_RUN" -eq 1 ]; then
          echo "🧪 [Dry-run] Would checkout $branch and merge from $upstream"
          continue
        fi

        # Checkout the branch
        git checkout "$branch" --quiet || {
          echo "❌ Failed to checkout $branch"
          continue
        }

        # Attempt a fast-forward merge from the upstream branch
        if git merge --ff-only "$upstream" > /dev/null 2>&1; then
          echo "✅ $branch updated"
        else
          # If fast-forward merge fails, show commits to be merged and mark failure
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
    done < <(git for-each-ref --format='%(refname:short) %(upstream:short)' refs/heads/)

    # Return to the original branch after updates
    git checkout "$current_branch" --quiet 2>/dev/null || true

    # Return to the previous working directory
    cd "$prev_dir" || true

  echo "-----------------------------------"
done < <(find "$BASE_DIR" -type d -name ".git" -print0)

echo "✅ Update completed for all repositories."
exit $merge_failed