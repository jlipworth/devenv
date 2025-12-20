# Shell Aliases Guide

This document describes all shell aliases configured in `.shell_aliases` for modern CLI tools.

## Setup

The `.shell_aliases` file is automatically symlinked to `~/.shell_aliases` by:
- `make linking-prereq` (creates symlink)
- `make cli_tools` (installs tools, creates symlink, and configures shell)

To apply changes after editing:
```bash
source ~/.shell_aliases
# or restart your terminal
```

## Important Notes

**All aliases are conditional** - they only activate if the corresponding tool is installed via `make cli_tools`. This means:
- You can source `.shell_aliases` even if tools aren't installed (no errors)
- Aliases automatically become available when you install the tools
- The file is safe to use across different machines with different tool sets

### .gitignore Awareness

Many modern CLI tools **respect `.gitignore` by default** for cleaner output in git repositories:

**Tools configured to show everything by default (for maximum visibility):**
- **eza tree views** (`lt`, `lta`, `ltree`) - Show all files. Use `g` suffix variants (`ltg`, `ltag`, `ltreeg`) to respect `.gitignore`

**Tools that respect `.gitignore` by default (tool behavior):**
- **fd** - Respects `.gitignore` by default; use `fdall` to see everything
- **ripgrep** - Respects `.gitignore` by default; use `rgall` to search everything
- **fzf** (via `fcd`) - Respects `.gitignore` when using `fd`; use `fcdall` for all directories

**Quick reference:**
- Want to see everything? Use: `lt`, `ltree`, `fdall`, `rgall`, `fcdall`
- Want git-aware filtering? Use: `ltg`, `ltreeg`, `fd`, `rg`, `fcd` (default for most tools)

## File Management

### eza (ls replacement)

| Alias    | Command                                                    | Description                          |
|----------|------------------------------------------------------------|--------------------------------------|
| `ls`     | `eza --icons --group-directories-first`                    | Basic listing with icons             |
| `l`      | `eza -l --icons --group-directories-first --git --header`  | Long format with git status          |
| `la`     | `eza -la --icons --group-directories-first --git --header` | Long format with hidden files        |
| `ll`     | `eza -l --icons --group-directories-first --git --header`  | Long format (same as `l`)            |
| `lla`    | `eza -la --icons --group-directories-first --git --header` | Long format with all files           |
| `lt`     | `eza -T --icons --level=2`                                 | Tree view, shows everything (2 levels) |
| `lta`    | `eza -Ta --icons --level=2`                                | Tree view with hidden, shows everything |
| `ltree`  | `eza -T --icons`                                           | Full tree view, shows everything     |
| `ltg`    | `eza -T --icons --git-ignore --level=2`                    | Tree view, git-aware (respects .gitignore) |
| `ltag`   | `eza -Ta --icons --git-ignore --level=2`                   | Tree with hidden, git-aware          |
| `ltreeg` | `eza -T --icons --git-ignore`                              | Full tree, git-aware                 |
| `l.`     | `eza -ld --icons .*`                                       | Show only dotfiles                   |
| `lS`     | `eza -1 --icons`                                           | Single column listing                |

**Examples:**
```bash
ls                    # Quick directory listing
la                    # Show all files including hidden
lt                    # Tree view - shows EVERYTHING (2 levels)
ltg                   # Tree view - respects .gitignore (2 levels)
ltree Documents       # Full tree of Documents folder (all files)
ltreeg src            # Full tree of src (ignores files in .gitignore)
```

**Note:** Tree aliases without the `g` suffix (`lt`, `lta`, `ltree`) show all files for maximum visibility. Use the `g` variants (`ltg`, `ltag`, `ltreeg`) when you want a cleaner view that respects `.gitignore`.

### fd (find replacement)

| Alias   | Command              | Description                                      |
|---------|----------------------|--------------------------------------------------|
| `fd`    | (no alias needed)    | Fast find replacement (respects .gitignore)      |
| `fda`   | `fd -H`              | Include hidden files (still respects .gitignore) |
| `fdall` | `fd --no-ignore -H`  | Show everything, ignore .gitignore               |
| `fde`   | `fd -e`              | Search by extension                              |

**Note:** On macOS, install via `brew install fd`. On Debian/Ubuntu, the package is `fd-find` and the binary is `fdfind` - the alias automatically maps `fd` → `fdfind` on Linux.

**Examples:**
```bash
fd myfile             # Search for files named "myfile" (respects .gitignore)
fda config            # Search including hidden files
fdall myfile          # Search everywhere, ignoring .gitignore
fde txt               # Find all .txt files
```

**Note:** `fd` respects `.gitignore` by default. Use `fdall` or `--no-ignore` flag to see all files.

## Text Processing

### bat (cat replacement)

| Alias     | Command                       | Description             |
|-----------|-------------------------------|-------------------------|
| `cat`     | `bat --paging=never`          | Syntax highlighted cat  |
| `batp`    | `bat`                         | bat with paging enabled |
| `bathelp` | `bat --plain --language=help` | Format help pages       |

**Function:**
- `help <command>` - View command help with syntax highlighting

**Examples:**
```bash
cat script.py         # View Python file with highlighting
batp longfile.txt     # View with paging
help ls              # View ls help with highlighting
```

### ripgrep (grep replacement)

| Alias   | Command               | Description                            |
|---------|-----------------------|----------------------------------------|
| `rg`    | `rg`                  | Fast grep (respects .gitignore)        |
| `rgi`   | `rg -i`               | Case insensitive search                |
| `rgl`   | `rg -l`               | List files with matches                |
| `rgc`   | `rg -c`               | Count matches                          |
| `rgall` | `rg --no-ignore -uuu` | Search everything, ignore .gitignore   |

**Examples:**
```bash
rg "TODO" src/        # Search for TODO in src (respects .gitignore)
rgi error logs/       # Case-insensitive search
rgl "function"        # List files containing "function"
rgall "TODO"          # Search everywhere, ignore .gitignore
```

**Note:** `rg` respects `.gitignore` by default. Use `rgall` or `--no-ignore` to search all files including ignored and hidden ones.

## Navigation

### zoxide (smart cd)

| Command   | Description                                 |
|-----------|---------------------------------------------|
| `z <dir>` | Jump to directory (provided by zoxide init) |
| `zi`      | Interactive directory picker                |

**Examples:**
```bash
z docs                # Jump to most frecent "docs" directory
z proj code           # Jump to directory matching "proj" and "code"
zi                    # Interactive selection
```

**Note:** `cd` is NOT aliased to `z` by default. You can uncomment this in `.shell_aliases` if desired.

## System Monitoring

### dust (du replacement)

| Alias | Command     | Description                   |
|-------|-------------|-------------------------------|
| `du`  | `dust`      | Visual disk usage             |
| `dua` | `dust -d 1` | Depth 1                       |
| `dus` | `dust -r`   | Reverse sort (smallest first) |

### htop

| Alias | Command | Description                |
|-------|---------|----------------------------|
| `top` | `htop`  | Interactive process viewer |

## Version Control

### lazygit (Git TUI)

| Alias | Command   | Description             |
|-------|-----------|-------------------------|
| `lg`  | `lazygit` | Open lazygit TUI        |
| `lzg` | `lazygit` | Alternate lazygit alias |

### git-delta (diff viewer)

| Function               | Description                  |
|------------------------|------------------------------|
| `diffview file1 file2` | Unified diff with delta      |
| `diffside file1 file2` | Side-by-side diff with delta |

**Examples:**
```bash
diffview file1.txt file2.txt        # Pretty diff
diffside -r dir1 dir2               # Side-by-side directory diff
```


## Additional Tools

### ranger (Terminal file manager)

| Alias | Command  | Description                |
|-------|----------|----------------------------|
| `r`   | `ranger` | Launch ranger file manager |

### fzf (Fuzzy finder)

| Function       | Description                                           |
|----------------|-------------------------------------------------------|
| `fcd [dir]`    | Interactive cd with fzf (respects .gitignore)         |
| `fcdall [dir]` | Interactive cd with fzf (shows all directories)       |

**Examples:**
```bash
fcd              # Search from current directory (respects .gitignore)
fcd ~/projects   # Search from ~/projects
fcdall           # Search all directories, ignore .gitignore
```

**Note:** `fcd` uses `fd` under the hood and respects `.gitignore` by default. Use `fcdall` to see all directories including those in `.gitignore`.

## Useful Functions

### mkcd

Create directory and cd into it:
```bash
mkcd new-project      # Creates and enters new-project/
```

### extract

Extract any archive format:
```bash
extract archive.tar.gz
extract package.zip
extract file.7z
```

Supports: `.tar.gz`, `.tar.bz2`, `.zip`, `.rar`, `.7z`, `.tar`, `.bz2`, `.gz`

## Customization

Add your own project-specific shortcuts at the bottom of `.shell_aliases`:

```bash
# Quick project navigation
alias proj='cd ~/projects'
alias gnu='cd ~/GNU_files'
alias dots='cd ~/.config'
```

## Tips

1. **Use tab completion** - All these tools support excellent tab completion
2. **Check tool help** - Use `<tool> --help` or `help <tool>` for more options
3. **Combine tools** - e.g., `rg TODO | bat` or `fd .rs | fzf`
4. **Override defaults** - Add your own aliases to override these in `.zshrc` if needed

## Tool Documentation Links

- [eza](https://github.com/eza-community/eza) - Modern ls
- [bat](https://github.com/sharkdp/bat) - Cat clone with wings
- [ripgrep](https://github.com/BurntSushi/ripgrep) - Fast grep
- [fd](https://github.com/sharkdp/fd) - Fast find
- [zoxide](https://github.com/ajeetdsouza/zoxide) - Smarter cd
- [dust](https://github.com/bootandy/dust) - Intuitive du
- [lazygit](https://github.com/jesseduffield/lazygit) - Git TUI
- [delta](https://github.com/dandavison/delta) - Git diff viewer
