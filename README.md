# Git Sweep - Bulk Git Repository Management

This collection of Bash scripts provides tools for bulk management of Git repositories. The toolkit includes utilities to update, switch, and delete branches across multiple repositories simultaneously.

## Scripts

### 1. `git-pull-all.sh` - Branch Updater
Recursively scans a base directory for Git repositories and updates each local branch that has a tracking upstream branch. Fetches the latest changes from all remotes and performs **fast-forward-only merges** to ensure local branches stay synchronized with their upstream counterparts.

### 2. `git-switch-all.sh` - Branch Switcher  
Switches all Git repositories under a specified directory to a target branch. Can create local branches from remote tracking branches if they don't exist locally.

### 3. `delete-local-branch.sh` - Branch Deleter
Recursively scans a base directory and deletes a specified local branch from all repositories where it exists. Safely skips the branch if it is currently checked out.

## Features

### Common Features (Update & Switch Scripts)
- Detects all Git repositories under a given base directory
- Skips repositories with uncommitted changes
- Supports a **dry-run mode** to preview actions without making any changes
- Handles **detached HEADs** and empty repositories gracefully
- Provides detailed output with color-coded messages for clarity
- Portable and tested on macOS, Linux, and WSL environments

### git-pull-all.sh Specific Features
- Automatically fetches updates from all remotes
- Updates all branches that have tracking branches, using **fast-forward-only merges**
- Shows commits to be merged when fast-forward merge is not possible
- Exits with non-zero status if any branch could not be fast-forwarded

### git-switch-all.sh Specific Features
- Switches to a specified target branch across all repositories
- Creates local branches from remote tracking branches when needed
- Provides comprehensive summary of switch operations

### delete-local-branch.sh Specific Features
- Deletes a specified local branch across all repositories
- **Safety Check**: Skips deletion if the branch is currently checked out
- Uses force delete (`git branch -D`) to ensure removal
- Provides summary of deleted, skipped, and failed operations

## Requirements

- Bash (with `set -euo pipefail` support)
- Git

## Installation

Make both scripts executable:

```bash
chmod +x git-pull-all.sh
chmod +x git-switch-all.sh
chmod +x delete-local-branch.sh
```

## Usage

### git-pull-all.sh - Update All Branches

Updates all branches with tracking upstreams across multiple repositories:

```bash
./git-pull-all.sh [--dry-run] [--dir <base-directory>]
```

**Options:**
- `--dry-run` or `-n`: Preview actions without making changes
- `--dir <path>` or `-d <path>`: Specify base directory (default: `~/Desktop/mase`)

**Examples:**
```bash
# Update all repositories in default directory
./git-pull-all.sh

# Dry run to see what would be updated
./git-pull-all.sh --dry-run

# Update repositories in a specific directory
./git-pull-all.sh --dir /path/to/repositories
```

### git-switch-all.sh - Switch All Branches

Switches all repositories to a specified branch:

```bash
./git-switch-all.sh --branch <branch-name> [--dry-run] [--dir <base-directory>]
```

**Options:**
- `--branch <name>` or `-b <name>`: **Required** - Target branch to switch to
- `--dry-run` or `-n`: Preview actions without making changes
- `--dir <path>` or `-d <path>`: Specify base directory (default: `/c/apps/mase`)

**Examples:**
```bash
# Switch all repositories to main branch
./git-switch-all.sh --branch main

# Dry run to see what would be switched
./git-switch-all.sh --branch develop --dry-run

# Switch repositories in a specific directory
./git-switch-all.sh --branch feature/new-feature --dir /path/to/repositories
```

### delete-local-branch.sh - Delete Local Branch

Deletes a specific local branch across all repositories:

```bash
./delete-local-branch.sh --branch <branch-name> [--dir <base-directory>]
```

**Options:**
- `--branch <name>` or `-b <name>`: **Required** - Branch to delete
- `--dir <path>` or `-d <path>`: Specify base directory (default: `/c/apps/mase`)

**Examples:**
```bash
# Delete 'feature/login' branch from all repos
./delete-local-branch.sh --branch feature/login
```

## How It Works

### Repository Discovery
Both scripts use `find` to recursively locate all `.git` directories under the specified base directory. Each discovered `.git` directory indicates a Git repository that will be processed.

### Safety Checks
- **Git Repository Validation**: Confirms each directory is a valid Git working tree
- **Uncommitted Changes**: Skips repositories with uncommitted changes to prevent data loss
- **Branch Existence**: Validates branch existence before attempting operations

### git-pull-all.sh Workflow
1. Fetches from all configured remotes
2. Identifies all local branches with upstream tracking
3. For each tracked branch:
   - Attempts a fast-forward-only merge
   - Reports success or shows commits that would be merged
4. Returns to original branch after processing

### git-switch-all.sh Workflow
1. Checks if target branch exists locally
2. If not local but exists remotely, creates local tracking branch
3. Switches to target branch
4. Provides summary of operations

### delete-local-branch.sh Workflow
1. Validates repository
2. Checks if target branch exists locally
3. Checks if target branch is currently checked out (skips if true)
4. Force deletes the branch (`git branch -D`)
5. Reports success or failure

## Output Format

Both scripts provide color-coded output with emojis for easy interpretation:

- 🔍 **Blue**: Information and progress messages
- ✅ **Green**: Successful operations
- ⚠️ **Yellow**: Warnings and skipped operations
- ❌ **Red**: Errors and failures
- 🧪 **Yellow**: Dry-run mode indicators

## Exit Codes

### git-pull-all.sh
- `0`: All operations successful
- `1`: One or more branches failed to fast-forward merge

### git-switch-all.sh
- `0`: All operations completed (regardless of individual failures)

### delete-local-branch.sh
- `0`: All operations completed successfully
- `>0`: Number of failed deletions

## Common Use Cases

### Development Team Scenarios
- **Morning Sync**: Use `git-pull-all.sh` to update all repositories at start of day
- **Release Preparation**: Use `git-switch-all.sh` to switch all repos to release branch
- **Feature Development**: Switch all repos to feature branch for integrated development
- **Hotfix Deployment**: Quickly switch all repos to hotfix branch
- **Cleanup**: Use `delete-local-branch.sh` to remove feature branches after merging

### Continuous Integration
- **Build Pipeline**: Ensure all repositories are on correct branch before building
- **Testing**: Switch to specific branch across multiple related repositories
- **Deployment**: Update all repositories to latest changes before deployment

## Tips and Best Practices

1. **Always use dry-run first**: Test with `--dry-run` before making actual changes
2. **Commit your work**: Both scripts skip repositories with uncommitted changes
3. **Configure default directories**: Edit the scripts to set your preferred default directories
4. **Monitor output**: Pay attention to warnings and errors in the colored output
5. **Backup important work**: Though safe, always backup critical work before bulk operations

## Troubleshooting

### Common Issues

**Permission Denied**
```bash
chmod +x git-pull-all.sh git-switch-all.sh
```

**Directory Not Found**
```bash
# Verify the path exists
ls -la /path/to/your/repositories
```

**Git Command Not Found**
```bash
# Install Git or add to PATH
which git
```

**Uncommitted Changes**
The scripts will skip repositories with uncommitted changes. Commit or stash changes first:
```bash
git add . && git commit -m "WIP: temporary commit"
# or
git stash
```

## Contributing

Feel free to submit issues, feature requests, or pull requests to improve these scripts.
