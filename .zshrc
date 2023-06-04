export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(
	zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh
source .zprofile
source .aliases

# Default editor
export EDITOR="nvim"
export PRETTIERD_DEFAULT_CONFIG="/home/lavantien/.config/prettier/.prettierrc.yaml"
export PRETTIERD_LOCAL_PRETTIER_ONLY=1

# Wine
# export WINEPREFIX="/home/lavantien/.wine"
# export WINEDLLOVERRIDES=nvapi,nvapi64,dxgi=n
export DXVK_ENABLE_NVAPI=1
export MANGOHUD=1

# D2R
export D2R_SAVES_PATH="/home/lavantien/Games/battlenet/drive_c/users/lavantien/Saved Games/Diablo II Resurrected"

# Brew
export HOMEBREW_MAKE_JOBS=8
export HOMEBREW_VERBOSE=1

# Go
export PATH="$PATH:$(go env GOPATH)/bin"

# GRPC
export PATH="$PATH:$HOME/.local/bin"

# Nim
export PATH=$PATH:/home/lavantien/.nimble/bin

# DotNet
export PATH="$PATH:/home/lavantien/.dotnet/tools"

# Ruby
export RUBY_GEMS_PATH=/home/linuxbrew/.linuxbrew/lib/ruby/gems
export PATH="$PATH:$(find $RUBY_GEMS_PATH -mindepth 1 -maxdepth 1 -type d)/bin"

# Perl
export PATH=$PATH:/home/lavantien/perl5/bin
export PERL5LIB="/home/lavantien/perl5/lib/perl5"
export PERL_LOCAL_LIB_ROOT="/home/lavantien/perl5"
export PERL_MB_OPT="--install_base \"/home/lavantien/perl5\""
export PERL_MM_OPT="INSTALL_BASE=/home/lavantien/perl5"
