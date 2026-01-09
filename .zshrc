# Universal Zsh Configuration - Linux, macOS, and Windows (WSL/Git Bash)
# Auto-detects platform and available tools

# ============================================================================
# PATH
# ============================================================================
export PATH=$HOME/bin:$HOME/.local/bin:$PATH

# Platform-specific PATH additions
case "$(uname -s)" in
    Linux*)
        # Homebrew on Linux
        if [ -d "/home/linuxbrew/.linuxbrew" ]; then
            export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
        fi
        # Snap (Ubuntu)
        if [ -d "/snap/bin" ]; then
            export PATH="$PATH:/snap/bin"
        fi
        ;;
    Darwin*)
        # Homebrew on macOS
        if [ -d "/opt/homebrew" ]; then
            export PATH="/opt/homebrew/bin:$PATH"
        elif [ -d "/usr/local" ]; then
            export PATH="/usr/local/bin:$PATH"
        fi
        ;;
    MINGW*|MSYS*|CYGWIN*)
        # Git Bash on Windows
        if [ -d "$HOME/scoop" ]; then
            export PATH="$PATH:$HOME/scoop/shims"
        fi
        ;;
esac

# ============================================================================
# OH MY ZSH
# ============================================================================
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="half-life"

# Only load Oh My Zsh if installed
if [ -d "$ZSH" ]; then
    plugins=(zsh-interactive-cd zsh-autosuggestions zsh-syntax-highlighting copypath copyfile)
    source $ZSH/oh-my-zsh.sh
fi

# ============================================================================
# EDITOR
# ============================================================================
export LANG=en_US.UTF-8
if [[ -n $SSH_CONNECTION ]]; then
    export EDITOR='vim'
else
    export EDITOR='nvim'
fi

# ============================================================================
# SOURCE ADDITIONAL FILES
# ============================================================================
# Source bash aliases (they work in zsh too)
if [ -f ~/.bash_aliases ]; then
    source ~/.bash_aliases
fi

# Source private keys file if exists
if [ -f ~/.keys ]; then
    source ~/.keys
fi

# ============================================================================
# TOOL CONFIGURATIONS (Auto-detect availability)
# ============================================================================

# Cargo (Rust)
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

# Homebrew shellenv
if command -v brew >/dev/null 2>&1; then
    export HOMEBREW_MAKE_JOBS=16
    # Already sourced via brew shellenv in PATH section for Linux
fi

# zoxide (z - smarter cd)
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh --cmd z)"

    # Enhanced zi (zoxide interactive) with fzf
    if command -v fzf >/dev/null 2>&1; then
        # Override zi with fzf-powered version
        zi() {
            local dir
            dir=$(zoxide query -l | fzf --height 50% --layout reverse --border --prompt="Directory> " --preview="eza -la --color=always {} 2>/dev/null || ls -la {}") && cd "$dir"
        }

        # zd - jump to directory with partial filter
        zd() {
            local dir
            if [ -n "$1" ]; then
                dir=$(zoxide query -l | fzf --height 50% --layout reverse --border --filter="$1" --preview="eza -la --color=always {} 2>/dev/null || ls -la {}") && cd "$dir"
            else
                dir=$(zoxide query -l | fzf --height 50% --layout reverse --border --prompt="Directory> " --preview="eza -la --color=always {} 2>/dev/null || ls -la {}") && cd "$dir"
            fi
        }
    fi
fi

# fzf (fuzzy finder)
if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --zsh)"
fi

# zsh-syntax-highlighting (fallback if not loaded by oh-my-zsh plugins)
if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# macOS: check for Homebrew-installed zsh-syntax-highlighting
if [ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Linux Homebrew: check for zsh-syntax-highlighting
if [ -f /home/linuxbrew/.linuxbrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /home/linuxbrew/.linuxbrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Custom oh-my-zsh plugins (linked from brew)
if [ -f "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# ============================================================================
# LANGUAGE-SPECIFIC CONFIGURATIONS
# ============================================================================

# Go
if command -v go >/dev/null 2>&1; then
    export PATH="$PATH:$(go env GOPATH)/bin"
fi

# Rust sccache (compiler cache)
if command -v sccache >/dev/null 2>&1; then
    export RUSTC_WRAPPER=$(which sccache)
fi

# Node.js (global packages)
if [ -d "$HOME/.npm-global" ]; then
    export PATH="$HOME/.npm-global/bin:$PATH"
fi

# Python (pyenv)
if command -v pyenv >/dev/null 2>&1; then
    eval "$(pyenv init -)"
fi

# ============================================================================
# PLATFORM-SPECIFIC SETTINGS
# ============================================================================

case "$(uname -s)" in
    Linux*)
        # Linux-specific settings
        ;;

    Darwin*)
        # macOS-specific settings
        # Fix for Unicode in Terminal
        export LC_ALL=en_US.UTF-8
        ;;

    MINGW*|MSYS*|CYGWIN*)
        # Git Bash on Windows-specific settings
        # MSYS no convert paths
        export MSYS_NO_PATHCONV=1
        ;;
esac
