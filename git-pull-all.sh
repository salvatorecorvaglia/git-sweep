#!/bin/bash

set -euo pipefail

# Default base directory
BASE_DIR="${HOME}/Desktop/mase"

# Flags
DRY_RUN=0
merge_failed=0

# Counters for summary
total_repos=0
branches_updated=0
branches_skipped=0
branches_merge_failed=0

# Check if terminal supports colors
if [ -t 1 ]; then
  GREEN="\033[0;32m"
  RED="\033[0;31m"
  YELLOW="\033[1;33m"
  BLUE="\033[0;34m"
  RESET="\033[0m"
else
  GREEN=""
  RED=""
  YELLOW=""
  BLUE=""
  RESET=""
fi

# Check if git is installed
if ! command -v git >/dev/null 2>&1; then
  echo -e "${RED}❌ git command not found. Please install Git.${RESET}"
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
      echo -e "${YELLOW}Usage: $0 [--dry-run] [--dir <base-directory>]${RESET}" >&2
      exit 1
      ;;
  esac
done

# Check base directory exists
if [ ! -d "$BASE_DIR" ]; then
  echo -e "${RED}❌ The directory '$BASE_DIR' does not exist.${RESET}"
  exit 1
fi

echo -e "${BLUE}🔍 Running fetch and update for all tracked branches in repositories under: $BASE_DIR${RESET}"
echo

process_repo() {
  local repo_dir="$1"
  ((total_repos++))
  echo -e "${BLUE}➡️  Repository: $repo_dir${RESET}"

  cd "$repo_dir" || { echo -e "${RED}❌ Cannot enter $repo_dir${RESET}"; return; }

  # Check valid Git repository
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo -e "${RED}❌ Not a Git repository: $repo_dir${RESET}"
    return
  fi

  # Skip uncommitted changes
  if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}⚠️  Uncommitted changes found. Skipping.${RESET}"
    ((branches_skipped++))
    return
  fi

  # Get current branch
  local current_branch
  current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || true)
  if [ -z "$current_branch" ]; then
    echo -e "${YELLOW}⚠️  No active branch (detached HEAD or empty repo). Skipping.${RESET}"
    ((branches_skipped++))
    return
  fi

  # Fetch from all remotes
  git fetch --all --prune --quiet
  for remote in $(git remote); do
    echo -e "${BLUE}🌐 Fetched from remote: $remote${RESET}"
  done

  # Update branches with upstream
  while IFS=' ' read -r branch upstream; do
    if [ -n "$upstream" ]; then
      echo -e "${BLUE}🔄 Updating $branch from $upstream${RESET}"

      if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "${YELLOW}🧪 [Dry-run] Would checkout $branch and merge from $upstream${RESET}"
        continue
      fi

      if ! git checkout "$branch" --quiet; then
        echo -e "${RED}❌ Failed to checkout $branch${RESET}"
        ((branches_merge_failed++))
        merge_failed=1
        continue
      fi

      if git merge --ff-only "$upstream" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $branch updated${RESET}"
        ((branches_updated++))
      else
        echo -e "${YELLOW}⚠️  Merge failed on $branch (non fast-forward)${RESET}"
        local count
        count=$(git rev-list --count "$branch..$upstream" || echo 0)
        if [ "$count" -eq 0 ]; then
          echo -e "${BLUE}ℹ️  Branch is up to date with upstream.${RESET}"
        else
          echo -e "${BLUE}🔍 Commits to be merged:${RESET}"
          git log "$branch..$upstream" --oneline --graph --decorate
        fi
        ((branches_merge_failed++))
        merge_failed=1
      fi
    fi
  done < <(git for-each-ref --format='%(refname:short) %(upstream:short)' refs/heads/)

  # Return to original branch
  git checkout "$current_branch" --quiet 2>/dev/null || true
  echo "-----------------------------------"
}

# Process all repositories
while IFS= read -r -d '' gitdir; do
  process_repo "$(dirname "$gitdir")"
done < <(find "$BASE_DIR" -type d -name ".git" -print0)

# Summary
echo -e "${BLUE}📊 Summary:${RESET}"
echo -e "${GREEN}✅ Branches updated: $branches_updated${RESET}"
echo -e "${YELLOW}⚠️  Branches skipped: $branches_skipped${RESET}"
echo -e "${RED}❌ Branches merge failed: $branches_merge_failed${RESET}"
echo -e "${BLUE}📁 Total repositories processed: $total_repos${RESET}"

echo -e "${GREEN}✅ Update completed for all repositories.${RESET}"
exit $merge_failed
