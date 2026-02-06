#!/bin/bash

# ============================================================================
# git-pull-all.sh
# Fetch and fast-forward merge all tracked branches across multiple repos
# ============================================================================

set -euo pipefail

# ============================================================================
# Configuration & Defaults
# ============================================================================
BASE_DIR="${HOME}/Desktop/apps"
DRY_RUN=0
VERBOSE=0

# Counters
total_repos=0
repos_updated=0
repos_skipped=0
total_branches_updated=0
total_commits_pulled=0
merge_failed=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# Functions
# ============================================================================

show_help() {
  cat << EOF
${CYAN}Usage:${NC} $0 [OPTIONS]

${CYAN}Description:${NC}
  Fetch and fast-forward merge all tracked branches in all Git repositories
  under a base directory. This script:
  - Fetches from all remotes
  - Updates all local branches that track an upstream (fast-forward only)
  - Skips repositories with uncommitted changes
  - Returns to the original branch after updates

${CYAN}Options:${NC}
  -d, --dir <path>          Base directory to scan (default: ${HOME}/Desktop/apps)
  -n, --dry-run             Show what would be done without making changes
  -v, --verbose             Show verbose output
  -h, --help                Show this help message

${CYAN}Examples:${NC}
  # Update all repositories in default directory
  $0

  # Dry-run to see what would be updated
  $0 --dry-run

  # Update repositories in a custom directory
  $0 --dir /path/to/repos

  # Verbose mode for detailed operations
  $0 --verbose

${CYAN}Exit Codes:${NC}
  0 - Success (all updates succeeded)
  1 - One or more non-fast-forward merges detected
EOF
  exit 0
}

print_verbose() {
  if [ "$VERBOSE" -eq 1 ]; then
    echo -e "${BLUE}[VERBOSE]${NC} $1"
  fi
}

print_error() {
  echo -e "${RED}❌ $1${NC}"
}

print_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
  echo -e "${CYAN}ℹ️  $1${NC}"
}

# ============================================================================
# Argument Parsing
# ============================================================================

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      ;;
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -d|--dir)
      BASE_DIR="$2"
      shift 2
      ;;
    -v|--verbose)
      VERBOSE=1
      shift
      ;;
    *)
      print_error "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# ============================================================================
# Validation
# ============================================================================

if ! command -v git >/dev/null 2>&1; then
  print_error "git command not found. Please install Git."
  exit 1
fi

if [ ! -d "$BASE_DIR" ]; then
  print_error "The directory '$BASE_DIR' does not exist."
  exit 1
fi

# ============================================================================
# Main Operation
# ============================================================================

print_verbose "Git version: $(git --version)"
print_verbose "Scanning directory: $BASE_DIR"

echo "🔍 Fetching and updating all tracked branches in: $BASE_DIR"
[ "$DRY_RUN" -eq 1 ] && echo "🧪 Running in dry-run mode (no changes applied)"
echo ""

# Find all .git directories recursively under BASE_DIR
while IFS= read -r -d '' gitdir; do
  repo_dir=$(dirname "$gitdir")
  repo_name=$(basename "$repo_dir")
  echo "➡️  Repository: $repo_name"
  print_verbose "Full path: $repo_dir"

  total_repos=$((total_repos + 1))
  repo_had_updates=0
  branches_updated_in_repo=0

  prev_dir=$(pwd)
  if ! cd "$repo_dir" 2>/dev/null; then
    print_error "Failed to enter $repo_dir"
    repos_skipped=$((repos_skipped + 1))
    echo "-----------------------------------"
    continue
  fi

  # Confirm this is a valid Git working tree
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print_error "Not a Git repository: $repo_dir"
    repos_skipped=$((repos_skipped + 1))
    cd "$prev_dir" || true
    echo "-----------------------------------"
    continue
  fi

  # Get the current checked-out branch
  current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || true)
  if [ -z "$current_branch" ]; then
    print_warning "No active branch (detached HEAD or empty repo). Skipping."
    repos_skipped=$((repos_skipped + 1))
    cd "$prev_dir" || true
    echo "-----------------------------------"
    continue
  fi

  print_verbose "Current branch: $current_branch"

  # Skip if there are uncommitted changes
  if git rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
    if ! git diff-index --quiet HEAD --; then
      print_warning "Uncommitted changes found. Skipping."
      repos_skipped=$((repos_skipped + 1))
      cd "$prev_dir" || true
      echo "-----------------------------------"
      continue
    fi
  fi

  # Fetch updates from all remotes
  remotes=$(git remote)
  if [ -z "$remotes" ]; then
    print_info "No remotes configured. Skipping."
    repos_skipped=$((repos_skipped + 1))
    cd "$prev_dir" || true
    echo "-----------------------------------"
    continue
  fi

  for remote in $remotes; do
    echo "🌐 Fetching from remote: $remote"
    print_verbose "Executing: git fetch $remote --prune"
    git fetch "$remote" --prune --quiet
  done

  # For each local branch that tracks an upstream branch, attempt fast-forward merge
  while IFS=' ' read -r branch upstream; do
    if [ -n "$upstream" ]; then
      print_verbose "Processing branch: $branch -> $upstream"

      # If dry-run, just print what would be done
      if [ "$DRY_RUN" -eq 1 ]; then
        # Check if there are commits to pull
        ahead=$(git rev-list --count "$upstream..$branch" 2>/dev/null || echo 0)
        behind=$(git rev-list --count "$branch..$upstream" 2>/dev/null || echo 0)
        
        if [ "$behind" -gt 0 ]; then
          echo "🔄 $branch: ${behind} commit(s) behind $upstream"
          echo "🧪 [Dry-run] Would update $branch"
        else
          print_verbose "$branch is up to date"
        fi
        continue
      fi

      # Check how many commits behind we are
      commits_behind=$(git rev-list --count "$branch..$upstream" 2>/dev/null || echo 0)
      
      if [ "$commits_behind" -eq 0 ]; then
        print_verbose "$branch is up to date"
        continue
      fi

      echo "🔄 Updating $branch from $upstream ($commits_behind new commit(s))"

      # Checkout the branch
      if ! git checkout "$branch" --quiet 2>/dev/null; then
        print_error "Failed to checkout $branch"
        continue
      fi

      # Attempt a fast-forward merge
      if git merge --ff-only "$upstream" >/dev/null 2>&1; then
        print_success "$branch updated (+$commits_behind commit(s))"
        repo_had_updates=1
        branches_updated_in_repo=$((branches_updated_in_repo + 1))
        total_branches_updated=$((total_branches_updated + 1))
        total_commits_pulled=$((total_commits_pulled + commits_behind))
      else
        # Non-fast-forward merge required
        print_warning "Merge failed on $branch (non-fast-forward required)"
        count=$(git rev-list --count "$branch..$upstream" 2>/dev/null || echo 0)
        if [ "$count" -eq 0 ]; then
          print_info "Branch is up to date with upstream."
        else
          echo "🔍 $count commit(s) require manual merge:"
          git log "$branch..$upstream" --oneline | head -5
          [ "$count" -gt 5 ] && echo "   ... and $((count - 5)) more"
        fi
        merge_failed=1
      fi
    fi
  done < <(git for-each-ref --format='%(refname:short) %(upstream:short)' refs/heads/)

  # Return to the original branch
  git checkout "$current_branch" --quiet 2>/dev/null || true

  if [ "$repo_had_updates" -eq 1 ]; then
    repos_updated=$((repos_updated + 1))
    print_verbose "$branches_updated_in_repo branch(es) updated in this repository"
  else
    print_verbose "No updates needed for this repository"
  fi

  cd "$prev_dir" || true
  echo "-----------------------------------"

done < <(find "$BASE_DIR" -type d -name ".git" -print0)

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "🏁 Update completed."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Total repositories scanned: $total_repos"
echo -e "${GREEN}✅ Repositories updated: $repos_updated${NC}"
echo -e "${YELLOW}⏭️  Repositories skipped: $repos_skipped${NC}"
echo -e "${CYAN}🔄 Total branches updated: $total_branches_updated${NC}"
echo -e "${CYAN}📥 Total commits pulled: $total_commits_pulled${NC}"
if [ "$merge_failed" -gt 0 ]; then
  echo -e "${RED}⚠️  Non-fast-forward merges detected: manual intervention required${NC}"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit $merge_failed