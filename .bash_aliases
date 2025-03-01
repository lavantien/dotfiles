alias f="fzf --preview 'bat --color=always --style=numbers --line-range=:1000 {}'"
alias m="mpv"
alias rs="rsync"
alias ff="ffmpeg"
alias df="difft"
alias lg="lazygit"
alias n="nvim"
alias b="bat"
alias t="tokei"
alias e="eza -a --group-directories-last"
alias ls="eza -la --group-directories-last"
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
