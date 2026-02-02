#!/usr/bin/env bash
set -euo pipefail

# Script to change git commit author/committer using git-filter-repo
# Usage: ./git-reauthor.sh -o "old@example.com" -e "new@example.com" -n "New Name"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Change commit author/committer in git history using git-filter-repo.

Required:
  -o, --old-email EMAIL  Email address to replace (can be specified multiple times)

At least one of:
  -e, --new-email EMAIL  New email address
  -n, --new-name NAME    New author name

Optional:
  -r, --range RANGE      Git revision range (e.g., HEAD~5..HEAD, abc123..def456)
                         If omitted, rewrites entire history
  -d, --dry-run          Show what would be changed without modifying anything
  -h, --help             Show this help message

Examples:
  # Change all commits by old@example.com
  $(basename "$0") -o "old@example.com" -e "new@example.com" -n "New Name"

  # Map multiple email aliases to one identity
  $(basename "$0") -o "old@example.com" -o "12345+user@users.noreply.github.com" \\
    -o "user@work.com" -e "new@example.com" -n "New Name"

  # Change only last 5 commits
  $(basename "$0") -o "old@example.com" -e "new@example.com" -r "HEAD~5..HEAD"

  # Dry run to preview changes
  $(basename "$0") -o "old@example.com" -e "new@example.com" --dry-run

WARNING: This rewrites git history. Only use on commits that haven't been pushed,
         or coordinate with all collaborators if rewriting shared history.
EOF
    exit "${1:-0}"
}

# Check for git-filter-repo
check_dependencies() {
    if ! command -v git-filter-repo &>/dev/null; then
        cat <<EOF
Error: git-filter-repo is not installed.

Install it via:
  - macOS:   brew install git-filter-repo
  - pip:     pip install git-filter-repo
  - Linux:   Available in most package managers

See: https://github.com/newren/git-filter-repo
EOF
        exit 1
    fi
}

# Parse arguments
OLD_EMAILS=()
NEW_EMAIL=""
NEW_NAME=""
RANGE=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--old-email)
            OLD_EMAILS+=("$2")
            shift 2
            ;;
        -e|--new-email)
            NEW_EMAIL="$2"
            shift 2
            ;;
        -n|--new-name)
            NEW_NAME="$2"
            shift 2
            ;;
        -r|--range)
            RANGE="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage 0
            ;;
        *)
            echo "Unknown option: $1"
            usage 1
            ;;
    esac
done

# Validate required arguments
if [[ ${#OLD_EMAILS[@]} -eq 0 ]]; then
    echo "Error: At least one -o/--old-email is required"
    usage 1
fi

if [[ -z "$NEW_EMAIL" && -z "$NEW_NAME" ]]; then
    echo "Error: At least one of -e/--new-email or -n/--new-name is required"
    usage 1
fi

# Check we're in a git repo
if ! git rev-parse --git-dir &>/dev/null; then
    echo "Error: Not in a git repository"
    exit 1
fi

check_dependencies

# Build the mailmap content
# Format: New Name <new@email> <old@email>
# One line per old email
build_mailmap() {
    local new_identity=""

    # Build the new identity part
    if [[ -n "$NEW_NAME" ]]; then
        new_identity="$NEW_NAME "
    fi

    if [[ -n "$NEW_EMAIL" ]]; then
        new_identity+="<$NEW_EMAIL>"
    fi

    # Create a mailmap line for each old email
    for old_email in "${OLD_EMAILS[@]}"; do
        if [[ -n "$NEW_EMAIL" ]]; then
            echo "$new_identity <$old_email>"
        else
            # If only name changes, we need: New Name <old@email> <old@email>
            echo "$NEW_NAME <$old_email> <$old_email>"
        fi
    done
}

MAILMAP_CONTENT=$(build_mailmap)

echo "Rewriting commits matching:"
for old_email in "${OLD_EMAILS[@]}"; do
    echo "  - $old_email"
done
echo ""
echo "Replacing with:"
[[ -n "$NEW_NAME" ]] && echo "  Name:  $NEW_NAME"
[[ -n "$NEW_EMAIL" ]] && echo "  Email: $NEW_EMAIL"
echo ""

if [[ -n "$RANGE" ]]; then
    echo "Range: $RANGE"
else
    echo "Range: ALL commits"
fi
echo ""

# Show matching commits
echo "Commits that will be affected:"
for old_email in "${OLD_EMAILS[@]}"; do
    if [[ -n "$RANGE" ]]; then
        git log --format="  %h %s <%ae>" --author="$old_email" "$RANGE" 2>/dev/null || true
    else
        git log --format="  %h %s <%ae>" --author="$old_email" 2>/dev/null || true
    fi
done
echo ""

if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY RUN] No changes made."
    echo "Mailmap entries that would be used:"
    echo "$MAILMAP_CONTENT" | sed 's/^/  /'
    exit 0
fi

# Confirm before proceeding
read -rp "Proceed with rewriting history? (y/N) " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Create temporary mailmap file
MAILMAP_FILE=$(mktemp)
printf '%s\n' "$MAILMAP_CONTENT" > "$MAILMAP_FILE"
trap 'rm -f "$MAILMAP_FILE"' EXIT

echo ""
echo "Running git-filter-repo..."

# Build filter-repo command
CMD=(git-filter-repo --mailmap "$MAILMAP_FILE" --force)

if [[ -n "$RANGE" ]]; then
    # For ranges, we need to use --refs
    CMD+=(--refs "$RANGE")
fi

"${CMD[@]}"

echo ""
echo "Done! History has been rewritten."
echo ""
echo "If you need to push these changes to a remote:"
echo "  git push --force-with-lease origin <branch>"
