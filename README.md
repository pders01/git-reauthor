# git-reauthor

Rewrite git commit author/committer history using [git-filter-repo](https://github.com/newren/git-filter-repo).

## Installation

### 1. Install git-filter-repo

```bash
# macOS
brew install git-filter-repo

# pip
pip install git-filter-repo
```

### 2. Add to PATH (optional)

To use as `git reauthor` from anywhere:

```bash
# Copy to a directory in your PATH
cp git-reauthor.sh ~/.local/bin/git-reauthor

# Or symlink it
ln -s "$(pwd)/git-reauthor.sh" ~/.local/bin/git-reauthor
```

Make sure `~/.local/bin` is in your PATH (add to `~/.bashrc` or `~/.zshrc`):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Now you can run `git reauthor` instead of `./git-reauthor.sh`.

## Usage

```bash
./git-reauthor.sh -o "old@example.com" -e "new@example.com" -n "New Name"
```

### Options

| Short | Long | Description |
|-------|------|-------------|
| `-o` | `--old-email` | Email to replace (can be specified multiple times) |
| `-e` | `--new-email` | New email address |
| `-n` | `--new-name` | New author name |
| `-r` | `--range` | Git revision range (e.g., `HEAD~5..HEAD`) |
| `-d` | `--dry-run` | Preview changes without modifying anything |
| `-h` | `--help` | Show help |

### Examples

**Basic usage:**
```bash
./git-reauthor.sh -o "old@example.com" -e "new@example.com" -n "New Name"
```

**Multiple email aliases:**
```bash
./git-reauthor.sh \
  -o "paul@personal.com" \
  -o "49939682+user@users.noreply.github.com" \
  -o "paul@work.com" \
  -e "paul@example.com" \
  -n "Paul Derscheid"
```

**Rewrite only recent commits:**
```bash
./git-reauthor.sh -o "old@example.com" -e "new@example.com" -r "HEAD~10..HEAD"
```

**Preview changes first:**
```bash
./git-reauthor.sh -o "old@example.com" -e "new@example.com" -d
```

## Warning

This rewrites git history. After running:

```bash
git push --force-with-lease origin <branch>
```

Only use on commits that haven't been shared, or coordinate with collaborators.
