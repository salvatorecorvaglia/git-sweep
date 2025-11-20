#!/bin/bash

# Exit immediately on error, undefined variable usage, or pipeline failure
set -euo pipefail

# Default base directory containing Git repositories
BASE_DIR="${HOME}/Desktop/apps"

# Flag indicating dry-run mode (0 = false, 1 = true)
DRY_RUN=0

# Target branch to switch to (default empty)
TARGET_BRANCH=""

# Counters
total_repos=0
branches_switched=0
branches_skipped=0
switch_failed=0

# Check if git command is available
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
    -b|--branch)
      TARGET_BRANCH="$2"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--dry-run] [--dir <base-directory>] [--branch <branch-name>]" >&2
      exit 1
      ;;
  esac
done

# Check target branch specified
if [ -z "$TARGET_BRANCH" ]; then
  echo "❌ Missing required argument: --branch <branch-name>"
  exit 1
fi

# Check that the base directory exists
if [ ! -d "$BASE_DIR" ]; then
  echo "❌ The directory '$BASE_DIR' does not exist."
  exit 1
fi

echo "🔀 Switching all Git repositories under: $BASE_DIR"
echo "➡️  Target branch: $TARGET_BRANCH"
[ "$DRY_RUN" -eq 1 ] && echo "🧪 Running in dry-run mode (no changes applied)"
echo

# Find all .git directories recursively under BASE_DIR
while IFS= read -r -d '' gitdir; do
  repo_dir=$(dirname "$gitdir")
  echo "➡️  Repository: $repo_dir"

  # Increase total repos (done in main shell so value persists)
  total_repos=$((total_repos + 1))

  # Save current directory and change to the repository directory
  prev_dir=$(pwd)
  cd "$repo_dir" || { echo "❌ Failed to enter $repo_dir"; branches_skipped=$((branches_skipped + 1)); continue; }

  # Confirm this is a valid Git working tree
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Not a Git repository: $repo_dir"
    branches_skipped=$((branches_skipped + 1))
    cd "$prev_dir" || true
    echo "-----------------------------------"
    continue
  fi

  # Check for uncommitted changes (skip if HEAD doesn't exist)
  if git rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
    if ! git diff-index --quiet HEAD --; then
      echo "⚠️  Uncommitted changes found. Skipping."
      branches_skipped=$((branches_skipped + 1))
      cd "$prev_dir" || true
      echo "-----------------------------------"
      continue
    fi
  fi

  current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "(detached)")

  # Verify if target branch exists locally
  if git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
    exists_locally=1
  else
    exists_locally=0
  fi

  remote_found=""
  if [ "$exists_locally" -eq 0 ]; then
    # Check all remotes for the branch
    for remote in $(git remote); do
      if git ls-remote --exit-code "$remote" "refs/heads/$TARGET_BRANCH" >/dev/null 2>&1; then
        remote_found="$remote"
        break
      fi
    done
  fi

  if [ "$exists_locally" -eq 0 ] && [ -n "$remote_found" ]; then
    echo "🌐 Found remote branch $TARGET_BRANCH on $remote_found"
    if [ "$DRY_RUN" -eq 0 ]; then
      git fetch --quiet "$remote_found" || git fetch --quiet
      if git checkout -b "$TARGET_BRANCH" "$remote_found/$TARGET_BRANCH" --quiet; then
        echo "✅ Created local branch $TARGET_BRANCH from $remote_found/$TARGET_BRANCH"
        branches_switched=$((branches_switched + 1))
        cd "$prev_dir" || true
        echo "-----------------------------------"
        continue
      else
        echo "❌ Failed to create branch from remote $remote_found."
        switch_failed=$((switch_failed + 1))
        cd "$prev_dir" || true
        echo "-----------------------------------"
        continue
      fi
    else
      echo "🧪 [Dry-run] Would create local branch from $remote_found/$TARGET_BRANCH"
      branches_skipped=$((branches_skipped + 1))
      cd "$prev_dir" || true
      echo "-----------------------------------"
      continue
    fi
  fi

  if [ "$exists_locally" -eq 0 ]; then
    echo "❌ Branch '$TARGET_BRANCH' not found locally or on any remote."
    switch_failed=$((switch_failed + 1))
    cd "$prev_dir" || true
    echo "-----------------------------------"
    continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "🧪 [Dry-run] Would switch from $current_branch to $TARGET_BRANCH"
    branches_skipped=$((branches_skipped + 1))
    cd "$prev_dir" || true
    echo "-----------------------------------"
    continue
  fi

  if git checkout "$TARGET_BRANCH" --quiet; then
    echo "✅ Switched to $TARGET_BRANCH (was $current_branch)"
    branches_switched=$((branches_switched + 1))
  else
    echo "❌ Failed to switch branch."
    switch_failed=$((switch_failed + 1))
  fi

  # Return to the previous working directory
  cd "$prev_dir" || true

  echo "-----------------------------------"
done < <(find "$BASE_DIR" -type d -name ".git" -print0)

echo "✅ Switch completed."
echo "📦 Total repos: $total_repos"
echo "🔁 Switched: $branches_switched"
echo "⚠️  Skipped: $branches_skipped"
echo "❌ Failed: $switch_failed"
exit $switch_failed
