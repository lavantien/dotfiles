# Handle WSL file number limit
unameOut=$(uname -a)
case "${unameOut}" in
	*Microsoft*)	OS="WSL";; # wsl must be first since it will have Linux in the name too
	*microsoft*)    OS="WSL2";;
	Linux*)     	OS="Linux";;
	Darwin*)    	OS="Mac";;
	CYGWIN*)    	OS="Cygwin";;
	MINGW*)     	OS="Windows";;
	*Msys)     	OS="Windows";;
	*)          	OS="UNKNOWN:${unameOut}"
esac
if [[ ${OS} == "WSL2" ]]; then
	sudo prlimit -p "$$" --nofile=4096:1048576
fi
echo ${OS};

# Start of zshrc
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
# export WINEDLLOVERRIDES=nvapi,nvapi64,dxgi=n
export DXVK_ENABLE_NVAPI=1
export MANGOHUD=1

# Brew
export HOMEBREW_MAKE_JOBS=16
export HOMEBREW_VERBOSE=1

# Go
export PATH="$PATH:$(go env GOPATH)/bin"

# GRPC
export PATH="$PATH:$HOME/.local/bin"

