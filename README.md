# Universal Dotfiles

Cross-platform dotfiles supporting **Windows 11 native**, **Linux (Ubuntu)**, and **macOS**.

## Quick Start

### Windows

```powershell
# Clone the repository
git clone https://github.com/yourusername/dotfiles.git $HOME/dev/dotfiles

# Deploy
cd $HOME/dev/dotfiles
.\deploy.ps1

# Reload PowerShell
. $PROFILE
```

### Linux/macOS

```bash
# Clone the repository
git clone https://github.com/yourusername/dotfiles.git ~/dev/dotfiles

# Deploy
cd ~/dev/dotfiles
chmod +x deploy.sh
./deploy.sh

# Reload shell
source ~/.zshrc  # or source ~/.bashrc
```

## What Gets Installed

| File | Windows | Linux | macOS | Description |
|------|---------|-------|-------|-------------|
| `Microsoft.PowerShell_profile.ps1` | ✓ | - | - | PowerShell profile |
| `.zshrc` | - | ✓ | ✓ | Zsh configuration |
| `.bash_aliases` | ✓* | ✓ | ✓ | Bash aliases (works in Zsh too) |
| `.gitconfig` | ✓ | ✓ | ✓ | Git configuration |
| `init.lua` | ✓ | ✓ | ✓ | Neovim config |
| `lua/` | ✓ | ✓ | ✓ | Neovim plugins/config |
| `wezterm.lua` | ✓ | ✓ | ✓ | Wezterm terminal |
| `hooks/git/` | ✓ | ✓ | ✓ | Git hooks (pre-commit, commit-msg) |
| `hooks/claude/` | ✓ | ✓ | ✓ | Claude Code quality check |

*Via Git Bash or WSL

## Universal Git Hooks

The hooks auto-detect your project type and run appropriate tools:

### Supported Languages

| Language | Format | Lint | Type Check | Test |
|----------|--------|------|------------|------|
| **Go** | gofmt/goimports | golangci-lint | go vet | go test |
| **Rust** | cargo fmt | clippy | cargo check | cargo test |
| **C/C++** | clang-format | clang-tidy/cppcheck | compiler | - |
| **JavaScript/TypeScript** | Prettier | ESLint | tsc/svelte-check | vitest/jest |
| **Python** | ruff/black | ruff/flake8 | mypy | pytest |
| **C#** | dotnet format | Roslyn analyzers | dotnet build | dotnet test |
| **Java** | spotless | checkstyle | javac | JUnit |
| **Scala** | scalafmt | scalac | scalac | scalatest |
| **PHP** | Pint/php-cs-fixer | PHPStan/Psalm | PHPStan/Psalm | PHPUnit |

### Git Hooks Usage

```bash
# Pre-commit: runs format/lint/check automatically
git commit -m "feat: add new feature"

# Commit-msg: enforces conventional commits
# Valid: feat(auth): add OAuth2 login
# Valid: fix(api): resolve null pointer issue
# Invalid: added new feature (will fail)
```

### Bypass Hooks

```bash
git commit --no-verify -m "message"
```

## Claude Code Hooks

### Installation

Add to `~/.claude/settings.json` (Linux/macOS) or `%USERPROFILE%\.claude\settings.json` (Windows):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NoProfile -ExecutionPolicy Bypass -File ~/.claude/quality-check.ps1"
          }
        ]
      }
    ]
  }
}
```

## Shell Aliases

Common aliases available in all shells:

| Alias | Command |
|-------|---------|
| `n` | nvim (editor) |
| `ls` | eza -la (detailed listing) |
| `b` | bat (cat alternative) |
| `f` | fzf (fuzzy finder) |
| `lg` | lazygit |
| `gs` | git status |
| `ga` | git add |
| `gcm` | git commit -m |
| `gp` | git push |
| `d` | docker |
| `dc` | docker compose |

## Platform-Specific Setup

### Windows 11 Native

**Package Manager**: Use [Scoop](https://scoop.sh) or [winget](https://learn.microsoft.com/en-us/windows/package-manager/)

```powershell
# Install via Scoop
scoop install git neovim python go rust nodejs-lts
scoop install lazygit fzf bat eza zoxide oh-my-posh
scoop install docker
```

**Terminal**: Wezterm or Windows Terminal
**PowerShell 7+** is recommended

### Linux (Ubuntu)

```bash
# System tweaks
sudo vi /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf
# Set: wifi.powersave = 2
sudo systemctl restart NetworkManager

# File limits
sudo sysctl fs.inotify.max_user_watches=2097152

# Install packages
sudo apt update
sudo apt install -y git neovim python3 python3-pip
sudo apt install -y golang rustc cargo nodejs npm
sudo apt install -y zsh zsh-autosuggestions fzf ripgrep eza
```

### macOS

```bash
# Install via Homebrew
brew install git neovim python go rust node
brew install lazygit fzf bat eza zoxide
brew install --cask docker
```

## Neovim Configuration

Full-featured Neovim IDE setup with:
- **Multi-Language Support**: Lua, Go, JS/TS, Python, C/C++, Rust, Java, and more
- **Integrated Tools**: LSP, debugging, testing, code actions
- **Navigation**: Telescope, Oil, Harpoon
- **Git Integration**: Fugitive, Diffview

### Key Neovim Keybindings

| Key | Mode | Action |
|-----|------|--------|
| `<C-p>` | Normal | Find files (Telescope) |
| `<C-/>` | Normal | Grep string |
| `<leader>f` | Normal | Find in current buffer |
| `<leader>gt` | Normal | Toggle terminal |
| `<leader>g=` | Normal | Format file |
| `Q` | Normal | Quit |
| `<F5>` | Normal | Debug: Continue |
| `<leader>b` | Normal | Debug: Toggle breakpoint |
| `<leader>tf` | Normal | Test function |
| `<leader>ta` | Normal | Test all |
| `<C-z>` | Normal | Harpoon menu |
| `<leader>u` | Normal | Undo tree |
| `-` | Normal | Oil file browser |

See [hooks/README.md](hooks/README.md) for detailed hooks documentation.

## Updating

```bash
# Pull latest changes
cd ~/dev/dotfiles  # or $HOME/dev/dotfiles on Windows
git pull

# Re-run deploy script
./deploy.sh  # or .\deploy.ps1 on Windows
```

## Directory Structure

```
dotfiles/
├── .bash_aliases          # Bash aliases (universal)
├── .zshrc                 # Zsh configuration
├── Microsoft.PowerShell_profile.ps1  # PowerShell profile
├── .gitconfig             # Git configuration
├── init.lua               # Neovim config
├── lua/                   # Neovim plugins/LSP
├── wezterm.lua            # Wezterm terminal config
├── deploy.sh              # Deploy script (Unix)
├── deploy.ps1             # Deploy script (Windows)
├── hooks/
│   ├── README.md          # Hooks documentation
│   ├── git/               # Git hooks
│   └── claude/            # Claude Code hooks
├── .claude/               # Claude Code configs
└── assets/                # Background images, etc.
```

## License

MIT
