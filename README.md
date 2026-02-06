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

### Common Features (All Scripts)
- 🎨 **Color-coded output** with emojis for easy interpretation (Red=errors, Green=success, Yellow=warnings, Blue=verbose, Cyan=info)
- 📖 **Comprehensive help system** - Use `--help` on any script for detailed documentation
- 🔍 **Verbose mode** - Add `-v` or `--verbose` flag for detailed operation logs
- 🧪 **Dry-run mode** - Preview actions with `-n` or `--dry-run` without making changes
- 🛡️ **Safety checks** - Detects and skips repositories with uncommitted changes
- 📊 **Enhanced statistics** - Detailed summary reports with operation counts
- 🌐 **Portable** - Tested on macOS, Linux, and WSL environments

### git-pull-all.sh Specific Features
- 🌐 **Multi-remote support** - Automatically fetches from all configured remotes
- 🔄 **Fast-forward updates** - Updates all tracked branches using fast-forward-only merges
- 📥 **Commit tracking** - Shows exact number of commits pulled per branch
- 📈 **Detailed statistics** - Reports total commits pulled, branches updated, and repositories affected
- ⚠️ **Conflict detection** - Identifies non-fast-forward situations requiring manual intervention

### git-switch-all.sh Specific Features
- 🔀 **Smart branch switching** - Switches to target branch or creates from remote if needed
- 📥 **Pull after switch** - Optional `--pull` flag to update branch after switching
- 🆕 **Branch creation tracking** - Separately tracks switched vs. newly created branches
- ℹ️ **Already on branch detection** - Skips repositories already on target branch (with optional pull)
- 🌐 **Remote branch support** - Automatically creates local branches from remote tracking branches

### delete-local-branch.sh Specific Features
- ✅ **Confirmation prompt** - Asks for confirmation before deletion (skip with `--yes`)
- 🔧 **Soft/Force delete** - Choose between safe soft delete (`-d`) or force delete (`-D`) with `--force` flag
- 🛡️ **Safety checks** - Skips deletion if branch is currently checked out
- 📊 **Operation summary** - Detailed report of deleted, skipped, and failed operations
- 🔒 **Default safety** - Uses soft delete by default to prevent accidental deletion of unmerged work

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

### Quick Start

All scripts support `--help` for comprehensive usage information:
```bash
./git-pull-all.sh --help
./git-switch-all.sh --help
./delete-local-branch.sh --help
```

### git-pull-all.sh - Update All Branches

Fetches and fast-forward merges all tracked branches across multiple repositories:

```bash
./git-pull-all.sh [OPTIONS]
```

**Options:**
- `-d, --dir <path>` - Base directory to scan (default: `~/Desktop/apps`)
- `-n, --dry-run` - Show what would be updated without making changes
- `-v, --verbose` - Show detailed operation logs
- `-h, --help` - Display help documentation

**Examples:**
```bash
# Update all repositories in default directory
./git-pull-all.sh

# Dry-run to preview updates and commit counts
./git-pull-all.sh --dry-run

# Update repositories in custom directory with verbose output
./git-pull-all.sh --dir /path/to/repos --verbose

# See all available options
./git-pull-all.sh --help
```

**Output Example:**
```
🔍 Fetching and updating all tracked branches in: ~/projects
➡️  Repository: my-app
🌐 Fetching from remote: origin
🔄 Updating main from origin/main (3 new commit(s))
✅ main updated (+3 commit(s))
-----------------------------------
🏁 Update completed.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Total repositories scanned: 10
✅ Repositories updated: 7
⏭️  Repositories skipped: 3
🔄 Total branches updated: 15
📥 Total commits pulled: 42
```

### git-switch-all.sh - Switch All Branches

Switches all repositories to a specified branch, creating from remote if needed:

```bash
./git-switch-all.sh --branch <branch-name> [OPTIONS]
```

**Options:**
- `-b, --branch <name>` - **Required** - Target branch to switch to
- `-d, --dir <path>` - Base directory to scan (default: `~/Desktop/apps`)
- `-n, --dry-run` - Show what would be done without making changes
- `-p, --pull` - Pull after switching to update the branch
- `-v, --verbose` - Show detailed operation logs
- `-h, --help` - Display help documentation

**Examples:**
```bash
# Switch all repositories to main branch
./git-switch-all.sh --branch main

# Switch and pull to get latest changes
./git-switch-all.sh --branch develop --pull

# Dry-run to preview what would happen
./git-switch-all.sh --branch release/v2.0 --dry-run

# Switch with verbose output in custom directory
./git-switch-all.sh --branch hotfix --dir /opt/repos --verbose

# See all available options
./git-switch-all.sh --help
```

**Output Example:**
```
🔀 Switching all Git repositories to branch: develop
📁 Base directory: ~/projects
➡️  Repository: my-app
✅ Switched to develop (was on main)
➡️  Repository: api-service
🌐 Found remote branch on origin
✅ Created and switched to develop (tracking origin/develop)
-----------------------------------
🏁 Switch completed.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Total repositories scanned: 10
🔁 Branches switched: 8
🆕 Branches created from remote: 2
⏭️  Skipped: 0
❌ Failed: 0
```

### delete-local-branch.sh - Delete Local Branch

Deletes a specific local branch across all repositories with safety checks:

```bash
./delete-local-branch.sh --branch <branch-name> [OPTIONS]
```

**Options:**
- `-b, --branch <name>` - **Required** - Branch name to delete
- `-d, --dir <path>` - Base directory to scan (default: `~/Desktop/apps`)
- `-f, --force` - Force delete (git branch -D), even if unmerged
- `-y, --yes` - Skip confirmation prompt
- `-v, --verbose` - Show detailed operation logs
- `-h, --help` - Display help documentation

**Examples:**
```bash
# Safe delete with confirmation (default behavior)
./delete-local-branch.sh --branch feature/old-code

# Force delete unmerged branch without confirmation
./delete-local-branch.sh --branch experimental --force --yes

# Delete from custom directory with verbose output
./delete-local-branch.sh --branch hotfix/bug-123 --dir /workspace --verbose

# See all available options
./delete-local-branch.sh --help
```

**Output Example:**
```
⚠️  You are about to soft delete (-d) branch 'feature/old-api' from all repositories in:
  ~/projects

Are you sure you want to continue? (yes/no): yes

🗑️  Soft deleting local branch: 'feature/old-api' (only if merged)
📁 Base directory: ~/projects
➡️  Repository: my-app
✅ Branch deleted: feature/old-api
➡️  Repository: api-service
ℹ️  Local branch does not exist: feature/old-api
-----------------------------------
🏁 Operation completed.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Total repositories scanned: 10
🗑️  Successfully deleted: 6
⏭️  Skipped: 4
❌ Failed: 0
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

All scripts provide color-coded output with emojis for easy interpretation:

- ✅ **Green**: Successful operations and success messages
- ❌ **Red**: Errors and failed operations
- ⚠️ **Yellow**: Warnings and skipped operations
- ℹ️ **Cyan**: Informational messages
- 🔍 **Blue**: Verbose/debug information (when using `--verbose`)
- 🧪 **Yellow**: Dry-run mode indicators

### Summary Statistics

Each script provides a detailed summary with:
- Total repositories scanned
- Number of successful operations (color-coded)
- Number of skipped operations with reasons
- Number of failed operations
- Script-specific metrics (commits pulled, branches created, etc.)

## Exit Codes

All scripts follow consistent exit code conventions for easy integration with CI/CD:

### git-pull-all.sh
- `0` - All fast-forward merges succeeded
- `1` - One or more non-fast-forward merges detected (manual intervention required)

### git-switch-all.sh
- `0` - All switch operations succeeded
- `N` - Number of failed switch operations

### delete-local-branch.sh
- `0` - All deletions succeeded (or no branches found)
- `N` - Number of failed deletions

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

1. **Use `--help` first**: Run `./script.sh --help` to see all available options and examples
2. **Always test with dry-run**: Use `--dry-run` to preview changes before applying them
3. **Enable verbose mode for debugging**: Add `--verbose` to see detailed operation logs
4. **Commit your work**: All scripts skip repositories with uncommitted changes
5. **Use soft delete by default**: The delete script uses safe soft delete unless `--force` is specified
6. **Leverage confirmation prompts**: The delete script asks for confirmation unless `--yes` is used
7. **Monitor colored output**: Colors make it easy to spot errors (red) and successes (green) at a glance
8. **Pull after switching**: Use `git-switch-all.sh --pull` to ensure branches are up-to-date
9. **Check statistics**: Review the summary statistics to verify operations completed as expected
10. **Backup important work**: Though safe, always backup critical work before bulk operations

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
