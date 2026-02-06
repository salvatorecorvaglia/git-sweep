#!/bin/bash

# ============================================================================
# git-switch-all.sh
# Switch all Git repositories to a specific branch
# ============================================================================

set -euo pipefail

# ============================================================================
# Configuration & Defaults
# ============================================================================
BASE_DIR="${HOME}/Desktop/apps"
DRY_RUN=0
TARGET_BRANCH=""
VERBOSE=0
PULL_AFTER_SWITCH=0

# Counters
total_repos=0
branches_switched=0
branches_skipped=0
branches_created=0
switch_failed=0

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
${CYAN}Usage:${NC} $0 --branch <branch-name> [OPTIONS]

${CYAN}Description:${NC}
  Switch all Git repositories under a base directory to a specific branch.
  If the branch exists locally, it will be checked out.
  If it doesn't exist locally but exists on a remote, it will be created and tracked.
  Repositories with uncommitted changes are skipped.

${CYAN}Required:${NC}
  -b, --branch <name>       Branch name to switch to

${CYAN}Options:${NC}
  -d, --dir <path>          Base directory to scan (default: ${HOME}/Desktop/apps)
  -n, --dry-run             Show what would be done without making changes
  -p, --pull                Pull after switching to update the branch
  -v, --verbose             Show verbose output
  -h, --help                Show this help message

${CYAN}Examples:${NC}
  # Switch all repositories to main branch
  $0 --branch main

  # Dry-run to see what would happen
  $0 --branch develop --dry-run

  # Switch and pull to get latest changes
  $0 --branch feature/new-api --pull

  # Switch repositories in custom directory
  $0 --branch release/v2.0 --dir /path/to/repos

  # Verbose mode for detailed operations
  $0 --branch hotfix --verbose

${CYAN}Exit Codes:${NC}
  0 - Success (all switches succeeded)
  N - Number of failed switches
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
    -b|--branch)
      TARGET_BRANCH="$2"
      shift 2
      ;;
    -p|--pull)
      PULL_AFTER_SWITCH=1
      shift
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

if [ -z "$TARGET_BRANCH" ]; then
  print_error "Missing required argument: --branch <branch-name>"
  echo "Use --help for usage information"
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

echo "🔀 Switching all Git repositories to branch: $TARGET_BRANCH"
echo "📁 Base directory: $BASE_DIR"
[ "$DRY_RUN" -eq 1 ] && echo "🧪 Running in dry-run mode (no changes applied)"
[ "$PULL_AFTER_SWITCH" -eq 1 ] && echo "📥 Will pull after switching"
echo ""

# Find all .git directories recursively under BASE_DIR
while IFS= read -r -d '' gitdir; do
  repo_dir=$(dirname "$gitdir")
  repo_name=$(basename "$repo_dir")
  echo "➡️  Repository: $repo_name"
  print_verbose "Full path: $repo_dir"

  total_repos=$((total_repos + 1))

  prev_dir=$(pwd)
  if ! cd "$repo_dir" 2>/dev/null; then
    print_error "Failed to enter $repo_dir"
    branches_skipped=$((branches_skipped + 1))
    echo "-----------------------------------"
    continue
  fi

  # Confirm this is a valid Git working tree
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print_error "Not a Git repository: $repo_dir"
    branches_skipped=$((branches_skipped + 1))
    cd "$prev_dir" || true
    echo "-----------------------------------"
    continue
  fi

  # Check for uncommitted changes
  if git rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
    if ! git diff-index --quiet HEAD --; then
      print_warning "Uncommitted changes found. Skipping."
      branches_skipped=$((branches_skipped + 1))
      cd "$prev_dir" || true
      echo "-----------------------------------"
      continue
    fi
  fi

  current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "(detached)")
  print_verbose "Current branch: $current_branch"

  # Check if already on target branch
  if [ "$current_branch" = "$TARGET_BRANCH" ]; then
    print_info "Already on $TARGET_BRANCH"
    
    # If pull flag is set, try to pull
    if [ "$PULL_AFTER_SWITCH" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
      upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)
      if [ -n "$upstream" ]; then
        print_verbose "Pulling from $upstream"
        if git pull --ff-only >/dev/null 2>&1; then
          print_success "Pulled latest changes"
        else
          print_warning "Pull failed (non-fast-forward or no changes)"
        fi
      fi
    fi
    
    branches_skipped=$((branches_skipped + 1))
    cd "$prev_dir" || true
    echo "-----------------------------------"
    continue
  fi

  # Verify if target branch exists locally
  if git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
    exists_locally=1
    print_verbose "Branch exists locally"
  else
    exists_locally=0
    print_verbose "Branch does not exist locally"
  fi

  remote_found=""
  if [ "$exists_locally" -eq 0 ]; then
    # Check all remotes for the branch
    print_verbose "Checking remotes for branch..."
    for remote in $(git remote); do
      print_verbose "Checking remote: $remote"
      if git ls-remote --exit-code "$remote" "refs/heads/$TARGET_BRANCH" >/dev/null 2>&1; then
        remote_found="$remote"
        print_verbose "Found on remote: $remote"
        break
      fi
    done
  fi

  # Branch exists on remote but not locally - create it
  if [ "$exists_locally" -eq 0 ] && [ -n "$remote_found" ]; then
    echo "🌐 Found remote branch on $remote_found"
    if [ "$DRY_RUN" -eq 0 ]; then
      print_verbose "Fetching from $remote_found"
      git fetch --quiet "$remote_found" || git fetch --quiet
      print_verbose "Creating local branch tracking $remote_found/$TARGET_BRANCH"
      if git checkout -b "$TARGET_BRANCH" "$remote_found/$TARGET_BRANCH" --quiet; then
        print_success "Created and switched to $TARGET_BRANCH (tracking $remote_found/$TARGET_BRANCH)"
        branches_created=$((branches_created + 1))
        branches_switched=$((branches_switched + 1))
      else
        print_error "Failed to create branch from remote $remote_found"
        switch_failed=$((switch_failed + 1))
      fi
    else
      echo "🧪 [Dry-run] Would create local branch tracking $remote_found/$TARGET_BRANCH"
      branches_skipped=$((branches_skipped + 1))
    fi
    cd "$prev_dir" || true
    echo "-----------------------------------"
    continue
  fi

  # Branch doesn't exist locally or remotely
  if [ "$exists_locally" -eq 0 ]; then
    print_error "Branch '$TARGET_BRANCH' not found locally or on any remote"
    switch_failed=$((switch_failed + 1))
    cd "$prev_dir" || true
    echo "-----------------------------------"
    continue
  fi

  # Branch exists locally - switch to it
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "🧪 [Dry-run] Would switch from $current_branch to $TARGET_BRANCH"
    branches_skipped=$((branches_skipped + 1))
    cd "$prev_dir" || true
    echo "-----------------------------------"
    continue
  fi

  print_verbose "Switching to existing local branch"
  if git checkout "$TARGET_BRANCH" --quiet; then
    print_success "Switched to $TARGET_BRANCH (was on $current_branch)"
    branches_switched=$((branches_switched + 1))
    
    # Pull if requested
    if [ "$PULL_AFTER_SWITCH" -eq 1 ]; then
      upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)
      if [ -n "$upstream" ]; then
        print_verbose "Pulling from $upstream"
        if git pull --ff-only >/dev/null 2>&1; then
          print_success "Pulled latest changes"
        else
          print_warning "Pull failed (non-fast-forward or no changes)"
        fi
      else
        print_verbose "No upstream configured, skipping pull"
      fi
    fi
  else
    print_error "Failed to switch branch"
    switch_failed=$((switch_failed + 1))
  fi

  cd "$prev_dir" || true
  echo "-----------------------------------"

done < <(find "$BASE_DIR" -type d -name ".git" -print0)

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "🏁 Switch completed."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Total repositories scanned: $total_repos"
echo -e "${GREEN}🔁 Branches switched: $branches_switched${NC}"
if [ "$branches_created" -gt 0 ]; then
  echo -e "${CYAN}🆕 Branches created from remote: $branches_created${NC}"
fi
echo -e "${YELLOW}⏭️  Skipped: $branches_skipped${NC}"
if [ "$switch_failed" -gt 0 ]; then
  echo -e "${RED}❌ Failed: $switch_failed${NC}"
else
  echo -e "${GREEN}❌ Failed: $switch_failed${NC}"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit $switch_failed
