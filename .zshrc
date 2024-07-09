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

ZSH_THEME="half-life"

plugins=(
	zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh
source ~/.zprofile
source ~/.aliases

# Default editor
export EDITOR="nvim"
export PRETTIERD_DEFAULT_CONFIG="$HOME/.config/prettier/.prettierrc.yaml"
export PRETTIERD_LOCAL_PRETTIER_ONLY=1

# Wine
# export WINEDLLOVERRIDES=nvapi,nvapi64,dxgi=n
export DXVK_ENABLE_NVAPI=1
export MANGOHUD=1

# Brew
export HOMEBREW_MAKE_JOBS=16
export HOMEBREW_VERBOSE=1

# Cargo
export RUSTC_WRAPPER="/home/linuxbrew/.linuxbrew/bin/sccache"

# Go
export PATH="$PATH:$(go env GOPATH)/bin"

# GRPC and other local bins
export PATH="$PATH:$HOME/.local/bin"

# Android SDK
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools

# DotNet
export DOTNET_ROOT="/home/linuxbrew/.linuxbrew/opt/dotnet/libexec"
export PATH="$PATH:/home/lavantien/.dotnet/tools"

# Ripgrep-all and fzf integration
rga-fzf() {
	RG_PREFIX="rga --files-with-matches"
	local file
	file="$(
		FZF_DEFAULT_COMMAND="$RG_PREFIX '$1'" \
			fzf --sort --preview="[[ ! -z {} ]] && rga --pretty --context 5 {q} {}" \
				--phony -q "$1" \
				--bind "change:reload:$RG_PREFIX {q}" \
				--preview-window="70%:wrap"
	)" &&
	echo "opening $file" &&
	xdg-open "$file"
}

# pman & zoxide
eval "$(pman completion zsh)"
eval "$(zoxide init zsh)"


# BEGIN opam configuration
# This is useful if you're using opam as it adds:
#   - the correct directories to the PATH
#   - auto-completion for the opam binary
# This section can be safely removed at any time if needed.
[[ ! -r '/home/lavantien/.opam/opam-init/init.zsh' ]] || source '/home/lavantien/.opam/opam-init/init.zsh' > /dev/null 2> /dev/null
# END opam configuration
