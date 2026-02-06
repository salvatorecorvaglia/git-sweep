#!/bin/bash

# ============================================================================
# delete-local-branch.sh
# Delete a specific local branch from all Git repositories in a directory tree
# ============================================================================

set -euo pipefail

# ============================================================================
# Configuration & Defaults
# ============================================================================
BASE_DIR="${HOME}/Desktop/apps"
TARGET_BRANCH=""
FORCE_DELETE=0       # 0 = soft delete (-d), 1 = force delete (-D)
SKIP_CONFIRM=0       # 0 = ask confirmation, 1 = skip confirmation
VERBOSE=0            # 0 = normal, 1 = verbose

# Counters
total_repos=0
deleted=0
skipped=0
failed=0

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
  Delete a specific local branch from all Git repositories under a base directory.
  By default, uses soft delete (-d) which prevents deletion of unmerged branches.

${CYAN}Required:${NC}
  -b, --branch <name>       Branch name to delete

${CYAN}Options:${NC}
  -d, --dir <path>          Base directory to scan (default: ${HOME}/Desktop/apps)
  -f, --force               Force delete branch (git branch -D), even if unmerged
  -y, --yes                 Skip confirmation prompt
  -v, --verbose             Show verbose output
  -h, --help                Show this help message

${CYAN}Examples:${NC}
  # Delete feature branch (soft delete, will ask for confirmation)
  $0 --branch feature/old-feature

  # Force delete unmerged branch without confirmation
  $0 --branch experimental --force --yes

  # Delete branch from custom directory
  $0 --branch hotfix/bug-123 --dir /path/to/repos

  # Verbose mode to see detailed operations
  $0 --branch temp --verbose

${CYAN}Exit Codes:${NC}
  0 - Success (all deletions succeeded or no branches found)
  N - Number of failed deletions
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

confirm_operation() {
  if [ "$SKIP_CONFIRM" -eq 1 ]; then
    return 0
  fi

  local delete_type
  if [ "$FORCE_DELETE" -eq 1 ]; then
    delete_type="FORCE delete (-D)"
  else
    delete_type="soft delete (-d)"
  fi

  echo ""
  print_warning "You are about to ${delete_type} branch '${TARGET_BRANCH}' from all repositories in:"
  echo "  ${BASE_DIR}"
  echo ""
  read -p "Are you sure you want to continue? (yes/no): " -r confirmation
  echo ""

  if [[ ! "$confirmation" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Operation cancelled."
    exit 0
  fi
}

# ============================================================================
# Argument Parsing
# ============================================================================

if [ $# -eq 0 ]; then
  show_help
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      ;;
    -d|--dir)
      BASE_DIR="$2"
      shift 2
      ;;
    -b|--branch)
      TARGET_BRANCH="$2"
      shift 2
      ;;
    -f|--force)
      FORCE_DELETE=1
      shift
      ;;
    -y|--yes)
      SKIP_CONFIRM=1
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

# Check if git exists
if ! command -v git >/dev/null 2>&1; then
  print_error "Git not found. Please install it before running this script."
  exit 1
fi

# Check branch arg
if [ -z "$TARGET_BRANCH" ]; then
  print_error "You must specify: --branch <branch-name>"
  echo "Use --help for usage information"
  exit 1
fi

# Check directory
if [ ! -d "$BASE_DIR" ]; then
  print_error "Directory does not exist: $BASE_DIR"
  exit 1
fi

# ============================================================================
# Main Operation
# ============================================================================

print_verbose "Git version: $(git --version)"
print_verbose "Scanning directory: $BASE_DIR"

# Confirm operation
confirm_operation

if [ "$FORCE_DELETE" -eq 1 ]; then
  echo "🗑️  Force deleting local branch: '${TARGET_BRANCH}'"
else
  echo "🗑️  Soft deleting local branch: '${TARGET_BRANCH}' (only if merged)"
fi
echo "📁 Base directory: $BASE_DIR"
echo ""

# Loop through all repositories
while IFS= read -r -d '' gitdir; do
  repo_dir=$(dirname "$gitdir")
  repo_name=$(basename "$repo_dir")
  echo "➡️  Repository: $repo_name"
  print_verbose "Full path: $repo_dir"

  total_repos=$((total_repos + 1))

  prev_dir=$(pwd)
  if ! cd "$repo_dir" 2>/dev/null; then
    print_error "Error accessing repository: $repo_dir"
    failed=$((failed + 1))
    echo "-----------------------------------"
    continue
  fi

  # Validate Git repository
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print_error "Not a Git repository"
    skipped=$((skipped + 1))
    cd "$prev_dir"
    echo "-----------------------------------"
    continue
  fi

  # Check if local branch exists
  if ! git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
    print_info "Local branch does not exist: $TARGET_BRANCH"
    skipped=$((skipped + 1))
    cd "$prev_dir"
    echo "-----------------------------------"
    continue
  fi

  # Do not delete the currently checked-out branch
  current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "(detached)")

  if [ "$current_branch" = "$TARGET_BRANCH" ]; then
    print_warning "Branch '$TARGET_BRANCH' is currently checked out. Skipping."
    skipped=$((skipped + 1))
    cd "$prev_dir"
    echo "-----------------------------------"
    continue
  fi

  # Delete the branch
  if [ "$FORCE_DELETE" -eq 1 ]; then
    delete_flag="-D"
  else
    delete_flag="-d"
  fi

  print_verbose "Executing: git branch $delete_flag $TARGET_BRANCH"
  
  if error_msg=$(git branch "$delete_flag" "$TARGET_BRANCH" 2>&1); then
    print_success "Branch deleted: $TARGET_BRANCH"
    if [ "$VERBOSE" -eq 1 ]; then
      echo "$error_msg"
    fi
    deleted=$((deleted + 1))
  else
    print_error "Branch deletion failed"
    echo "$error_msg"
    failed=$((failed + 1))
  fi

  cd "$prev_dir"
  echo "-----------------------------------"

done < <(find "$BASE_DIR" -type d -name ".git" -print0)

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "🏁 Operation completed."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Total repositories scanned: $total_repos"
echo -e "${GREEN}🗑️  Successfully deleted: $deleted${NC}"
echo -e "${YELLOW}⏭️  Skipped: $skipped${NC}"
if [ "$failed" -gt 0 ]; then
  echo -e "${RED}❌ Failed: $failed${NC}"
else
  echo -e "${GREEN}❌ Failed: $failed${NC}"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit $failed
