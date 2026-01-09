# Universal Bash Aliases - Works on Linux, macOS, and Git Bash/WSL on Windows
# Auto-detects available tools and falls back gracefully

# === FILE OPERATIONS ===
if command -v fzf >/dev/null 2>&1; then
    if command -v bat >/dev/null 2>&1; then
        alias f="fzf --preview 'bat --color=always --style=numbers --line-range=:1000 {}'"
    else
        alias f="fzf"
    fi
fi

if command -v mpv >/dev/null 2>&1; then
    alias m="mpv"
fi

if command -v rsync >/dev/null 2>&1; then
    alias rs="rsync"
fi

if command -v ffmpeg >/dev/null 2>&1; then
    alias ff="ffmpeg"
fi

if command -v difft >/dev/null 2>&1; then
    alias df="difft"
fi

if command -v lazygit >/dev/null 2>&1; then
    alias lg="lazygit"
fi

# Editor alias - prefers Neovim 0.12 (installed via snap edge)
if command -v nvim >/dev/null 2>&1; then
    alias n="nvim"
elif command -v vim >/dev/null 2>&1; then
    alias n="vim"
fi

if command -v bat >/dev/null 2>&1; then
    alias b="bat"
elif command -v cat >/dev/null 2>&1; then
    alias b="cat"
fi

if command -v tokei >/dev/null 2>&1; then
    alias t="tokei"
fi

# Directory listing - Try eza first, fall back to exa, then ls
if command -v eza >/dev/null 2>&1; then
    alias e="eza -a --group-directories-last"
    alias ls="eza -la --group-directories-last"
elif command -v exa >/dev/null 2>&1; then
    alias e="exa -a --group-directories-last"
    alias ls="exa -la --group-directories-last"
fi

# === GIT ALIASES ===
alias gs="git status"
alias gl="git log"
alias glg="git log --graph"
alias glf="git log --follow"
alias gb="git branch"
alias gbi="git bisect"
alias gd="git diff"
alias ga="git add"
alias gaa="git add ."
alias gcm="git commit -m"
alias gp="git push"
alias gf="git fetch"
alias gm="git merge"
alias gmt="git mergetool"
alias gr="git rebase"
alias gc="git checkout"
alias gcb="git checkout -b"
alias gcp="git cherry-pick"
alias gt="git tag"
alias gw="git worktree"
alias gwa="git worktree add"
alias gwd="git worktree delete"
alias gws="git worktree status"
alias gwc="git worktree clean"
alias gsuir="git submodule update --init --recursive"
alias gnuke="!git checkout -- . && git submodule foreach --recursive git checkout -- ."

# === DOCKER ALIASES ===
if command -v docker >/dev/null 2>&1; then
    alias d="docker"
    alias ds="docker start"
    alias dx="docker stop"
    alias dp="docker ps"
    alias dpa="docker ps -a"
    alias di="docker images"
    alias dl="docker logs"
    alias dlf="docker logs -f"
    alias dc="docker compose"
    alias dcp="docker compose ps"
    alias dcpa="docker compose ps -a"
    alias dcu="docker compose up"
    alias dcub="docker compose up --build"
    alias dcd="docker compose down"
    alias dcl="docker compose logs"
    alias dclf="docker compose logs -f"
    alias de="docker exec -it"
fi

# Update all packages alias
alias up="~/dev/update-all.sh"
alias update="~/dev/update-all.sh"
