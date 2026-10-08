#!/usr/bin/env bash

# shellcheck source=../lib/common.sh
# shellcheck source=../lib/version-check.sh

get_package_description() {
	local pkg="$1"
	case "$pkg" in
	brew) echo "package manager" ;;
	git) echo "version control" ;;
	node) echo "Node.js runtime" ;;
	nodejs) echo "Node.js runtime" ;;
	python | python3) echo "Python runtime" ;;
	go | golang) echo "Go runtime" ;;
	rust) echo "Rust toolchain" ;;
	rust-analyzer) echo "Rust LSP" ;;
	bun) echo "JavaScript runtime" ;;
	dotnet-sdk) echo ".NET SDK" ;;
	openjdk | default-jdk) echo "Java development" ;;
	lua-language-server) echo "Lua LSP" ;;
	llvm) echo "C/C++ toolchain" ;;
	clangd) echo "C/C++ LSP" ;;
	gopls) echo "Go LSP" ;;
	pyright) echo "Python LSP" ;;
	typescript-language-server) echo "TypeScript LSP" ;;
	yaml-language-server) echo "YAML LSP" ;;
	csharp-ls) echo "C# LSP" ;;
	eclipse-jdt) echo "Java LSP" ;;
	intelephense) echo "PHP LSP" ;;
	tombi) echo "TOML LSP" ;;
	tinymist) echo "Typst LSP" ;;
	prettier) echo "code formatter" ;;
	eslint) echo "JavaScript linter" ;;
	ruff) echo "Python linter" ;;
	black) echo "Python formatter" ;;
	isort) echo "Python import sorter" ;;
	mypy) echo "Python type checker" ;;
	gup) echo "Go package updater" ;;
	goimports) echo "Go import formatter" ;;
	golangci-lint) echo "Go linter" ;;
	cargo-update) echo "Cargo package updater" ;;
	clang-format) echo "C/C++ formatter" ;;
	shellcheck) echo "Shell script linter" ;;
	shfmt) echo "Shell script formatter" ;;
	scalafmt) echo "Scala formatter" ;;
	fzf) echo "fuzzy finder" ;;
	zoxide) echo "smart cd" ;;
	bat) echo "cat alternative" ;;
	eza | exa) echo "ls alternative" ;;
	lazygit) echo "Git TUI" ;;
	gh) echo "GitHub CLI" ;;
	tokei) echo "code stats" ;;
	ripgrep) echo "text search" ;;
	fd-find | fd) echo "find alternative" ;;
	jq) echo "JSON processor" ;;
	yazi) echo "file manager" ;;
	difftastic | difft) echo "diff viewer" ;;
	bats) echo "bash testing" ;;
	vscode) echo "code editor" ;;
	latex) echo "document preparation" ;;
	claude-code) echo "AI CLI" ;;
	opencode) echo "AI CLI" ;;
	*) echo "" ;;
	esac
}

configure_git_settings() {
	local current_autocrlf
	current_autocrlf="$(git config --global core.autocrlf 2>/dev/null || echo "")"
	if [[ "$current_autocrlf" != "false" ]]; then
		log_step "Configuring git line endings (core.autocrlf=false)..."
		if [[ "$DRY_RUN" == "false" ]]; then
			git config --global core.autocrlf false
			log_info "Set core.autocrlf=false (no conversion on macOS)"
		else
			log_info "[DRY-RUN] Would run: git config --global core.autocrlf false"
		fi
	else
		track_skipped "git autocrlf already configured"
	fi

	local ssh_dir="$HOME/.ssh"
	local known_hosts="$ssh_dir/known_hosts"
	local needs_github_key=true

	if [[ -f "$known_hosts" ]]; then
		if grep -q "github\.com" "$known_hosts" 2>/dev/null; then
			needs_github_key=false
		fi
	fi

	if [[ "$needs_github_key" == "true" ]]; then
		log_step "Adding GitHub SSH key to known_hosts..."
		if [[ "$DRY_RUN" == "false" ]]; then
			mkdir -p "$ssh_dir"
			if command -v ssh-keyscan >/dev/null 2>&1; then
				ssh-keyscan github.com >>"$known_hosts" 2>/dev/null
				log_info "GitHub SSH key added to known_hosts"
			else
				log_info "ssh-keyscan not available, skipping known_hosts setup"
			fi
		else
			log_info "[DRY-RUN] Would add GitHub SSH key to $known_hosts"
		fi
	else
		track_skipped "GitHub SSH key already in known_hosts"
	fi
}

ensure_homebrew() {
	if cmd_exists brew; then
		track_skipped "brew" "$(get_package_description brew)"
		return 0
	fi

	log_step "Installing Homebrew..."
	if run_cmd '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'; then

		if [[ -d "/opt/homebrew/bin" ]]; then
			ensure_path "/opt/homebrew/bin"
		elif [[ -d "/usr/local/bin" ]]; then
			ensure_path "/usr/local/bin"
		fi
		track_installed "brew" "$(get_package_description brew)"
		return 0
	else
		track_failed "brew" "$(get_package_description brew)"
		return 1
	fi
}

install_brew_package() {
	local package="$1"
	local min_version="${2:-}"
	local check_cmd="${3:-$package}"

	if ! cmd_exists brew; then
		log_warning "Homebrew not installed, skipping $package"
		track_failed "$package" "$(get_package_description "$package")"
		return 1
	fi

	if needs_install "$check_cmd" "$min_version"; then
		log_step "Installing $package via brew..."
		if run_cmd "brew install $package"; then
			track_installed "$package" "$(get_package_description "$package")"
			return 0
		else
			track_failed "$package" "$(get_package_description "$package")"
			return 1
		fi
	else
		track_skipped "$check_cmd" "$(get_package_description "$check_cmd")"
		return 0
	fi
}

install_brew_packages() {
	local packages=("$@")
	local to_install=()

	for pkg in "${packages[@]}"; do
		if needs_install "$pkg" ""; then
			to_install+=("$pkg")
		else
			track_skipped "$pkg" "$(get_package_description "$pkg")"
		fi
	done

	if [[ ${#to_install[@]} -gt 0 ]]; then
		log_step "Installing ${#to_install[@]} packages via brew..."
		local pkg_list
		pkg_list="$(
			IFS=' '
			echo "${to_install[*]}"
		)"
		if run_cmd "brew install $pkg_list"; then
			for pkg in "${to_install[@]}"; do
				track_installed "$pkg" "$(get_package_description "$pkg")"
			done
			return 0
		else
			for pkg in "${to_install[@]}"; do
				track_failed "$pkg" "$(get_package_description "$pkg")"
			done
			return 1
		fi
	fi

	return 0
}

install_brew_cask() {
	local cask="$1"
	local check_cmd="${2:-}"
	local min_version="${3:-}"

	if [[ -z "$check_cmd" ]]; then

		check_cmd="${cask,,}"
	fi

	if ! cmd_exists brew; then
		log_warning "Homebrew not installed, skipping $cask"
		track_failed "$cask" "$(get_package_description "$cask")"
		return 1
	fi

	if needs_install "$check_cmd" "$min_version"; then
		log_step "Installing $cask via brew cask..."
		if run_cmd "brew install --cask $cask"; then
			track_installed "$cask" "$(get_package_description "$cask")"
			return 0
		else
			track_failed "$cask" "$(get_package_description "$cask")"
			return 1
		fi
	else
		track_skipped "$check_cmd" "$(get_package_description "$check_cmd")"
		return 0
	fi
}

install_npm_global() {
	local package="$1"
	local cmd_name="${2:-}"
	local min_version="${3:-}"

	if [[ -z "$cmd_name" ]]; then
		cmd_name="${package##*/}"
		cmd_name="${cmd_name#@}"
	fi

	if ! cmd_exists npm; then
		log_warning "npm not found, skipping $package"
		track_failed "$package" "$(get_package_description "$cmd_name")"
		return 1
	fi

	if npm_package_needs_update "$package"; then
		log_step "Installing $package via npm..."
		if run_cmd "npm install -g $package"; then
			track_installed "$package" "$(get_package_description "$cmd_name")"
			return 0
		else
			track_failed "$package" "$(get_package_description "$cmd_name")"
			return 1
		fi
	else
		log_info "$package already at latest version"
		track_skipped "$cmd_name" "$(get_package_description "$cmd_name")"
		return 0
	fi
}

install_go_package() {
	local package="$1"
	local cmd_name="${2:-}"
	local min_version="${3:-}"

	if [[ -z "$cmd_name" ]]; then
		cmd_name="${package##*/}"
	fi

	if ! cmd_exists go; then
		log_warning "go not found, skipping $package"
		track_failed "$package" "$(get_package_description "$cmd_name")"
		return 1
	fi

	local gopath
	gopath="$(go env GOPATH)"
	if [[ -n "$gopath" ]]; then

		ensure_path "$gopath/bin"

		if [[ ":$PATH:" != *":$gopath/bin:"* ]]; then
			export PATH="$gopath/bin:$PATH"
		fi
	fi

	if cmd_exists "$cmd_name"; then
		track_skipped "$cmd_name" "$(get_package_description "$cmd_name")"
		return 0
	fi

	local clean_package="${package%%@*}"
	log_step "Installing $clean_package via go..."
	if run_cmd "go install $clean_package@latest"; then
		track_installed "$clean_package" "$(get_package_description "$cmd_name")"
		return 0
	else
		track_failed "$clean_package" "$(get_package_description "$cmd_name")"
		return 1
	fi
}

install_cargo_package() {
	local package="$1"
	local cmd_name="${2:-$package}"
	local min_version="${3:-}"

	if ! cmd_exists cargo; then
		log_warning "cargo not found, skipping $package"
		track_failed "$package" "$(get_package_description "$cmd_name")"
		return 1
	fi

	if needs_install "$cmd_name" "$min_version"; then
		log_step "Installing $package via cargo..."
		if run_cmd "cargo install $package"; then
			ensure_path "$HOME/.cargo/bin"
			track_installed "$package" "$(get_package_description "$cmd_name")"
			return 0
		else
			track_failed "$package" "$(get_package_description "$cmd_name")"
			return 1
		fi
	else
		track_skipped "$cmd_name" "$(get_package_description "$cmd_name")"
		return 0
	fi
}

install_cargo_update() {
	if cmd_exists cargo-install-update; then
		track_skipped "cargo-update" "$(get_package_description cargo-update)"
		return 0
	fi

	if ! cmd_exists cargo; then
		log_warning "cargo not found, skipping cargo-update"
		track_failed "cargo-update" "$(get_package_description cargo-update)"
		return 1
	fi

	install_build_dependencies

	log_step "Installing cargo-update..."
	if run_cmd "cargo install cargo-update"; then
		ensure_path "$HOME/.cargo/bin"
		track_installed "cargo-update" "$(get_package_description cargo-update)"
		return 0
	else
		track_failed "cargo-update" "$(get_package_description cargo-update)"
		return 1
	fi
}

install_php() {
	if cmd_exists php && php -m | grep -q curl 2>/dev/null; then
		track_skipped "php" "PHP with curl extension"
		return 0
	fi

	log_step "Installing PHP with curl extension via brew..."

	if run_cmd "brew install php"; then
		track_installed "php" "$(get_package_description php)"
		return 0
	else
		track_failed "php" "$(get_package_description php)"
		return 1
	fi
}

install_pip_global() {
	local package="$1"
	local cmd_name="${2:-$package}"
	local min_version="${3:-}"

	local python_cmd=""
	if cmd_exists python3; then
		python_cmd="python3"
	elif cmd_exists python; then
		python_cmd="python"
	else
		log_warning "Python not found, skipping $package"
		track_failed "$package" "$(get_package_description "$cmd_name")"
		return 1
	fi

	if needs_install "$cmd_name" "$min_version"; then
		log_step "Installing $package via pip..."
		if run_cmd "$python_cmd -m pip install --user --upgrade $package"; then
			track_installed "$package" "$(get_package_description "$cmd_name")"
			return 0
		else
			track_failed "$package" "$(get_package_description "$cmd_name")"
			return 1
		fi
	else
		track_skipped "$cmd_name" "$(get_package_description "$cmd_name")"
		return 0
	fi
}

install_dotnet_tool() {
	local package="$1"
	local cmd_name="${2:-$package}"
	local min_version="${3:-}"

	if ! cmd_exists dotnet; then
		log_warning "dotnet not found, skipping $package"
		track_failed "$package" "$(get_package_description "$cmd_name")"
		return 1
	fi

	if needs_install "$cmd_name" "$min_version"; then
		log_step "Installing $package via dotnet..."
		if run_cmd "dotnet tool install --global $package"; then
			ensure_path "$HOME/.dotnet/tools"
			track_installed "$package" "$(get_package_description "$cmd_name")"
			return 0
		else

			if run_cmd "dotnet tool update --global $package"; then
				track_installed "$package" "$(get_package_description "$cmd_name")"
				return 0
			else
				track_failed "$package" "$(get_package_description "$cmd_name")"
				return 1
			fi
		fi
	else
		track_skipped "$cmd_name" "$(get_package_description "$cmd_name")"
		return 0
	fi
}

install_build_dependencies() {
	if cmd_exists pkg-config; then
		track_skipped "build-deps" "build dependencies"
		return 0
	fi

	if ! cmd_exists brew; then
		log_warning "Homebrew not found, skipping build dependencies installation"
		log_info "Run 'brew install openssl pkg-config' manually if needed"
		return 1
	fi

	log_step "Installing build dependencies (pkg-config, OpenSSL)..."
	if run_cmd "brew install pkg-config openssl"; then
		track_installed "build-deps" "build dependencies"
		return 0
	else
		track_failed "build-deps" "build dependencies"
		return 1
	fi
}

install_rustup() {
	install_build_dependencies

	if cmd_exists rustup; then
		track_skipped "rust" "$(get_package_description rust)"
		return 0
	fi

	log_step "Installing Rust via rustup..."
	if run_cmd "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"; then
		# shellcheck disable=SC1091
		[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
		ensure_path "$HOME/.cargo/bin"
		track_installed "rust" "$(get_package_description rust)"
		return 0
	else
		track_failed "rust" "$(get_package_description rust)"
		return 1
	fi
}

install_rust_analyzer_component() {
	if ! cmd_exists rustup; then
		log_warning "rustup not found, skipping rust-analyzer"
		track_failed "rust-analyzer" "$(get_package_description rust-analyzer)"
		return 1
	fi

	if needs_install rust-analyzer ""; then
		log_step "Adding rust-analyzer component..."
		if run_cmd "rustup component add rust-analyzer"; then
			track_installed "rust-analyzer" "$(get_package_description rust-analyzer)"
			return 0
		else
			track_failed "rust-analyzer" "$(get_package_description rust-analyzer)"
			return 1
		fi
	else
		track_skipped "rust-analyzer" "$(get_package_description rust-analyzer)"
		return 0
	fi
}

install_bun() {
	if cmd_exists bun; then
		log_step "Upgrading Bun..."
		if run_cmd "bun upgrade"; then

			# shellcheck disable=SC1091
			[[ -f "$HOME/.bun/bin/bun" ]] && ensure_path "$HOME/.bun/bin"
			track_skipped "bun" "$(get_package_description bun)"
			return 0
		else
			log_warning "Bun upgrade failed, keeping existing version"
			track_skipped "bun" "$(get_package_description bun)"
			return 0
		fi
	fi

	log_step "Installing Bun..."
	if run_cmd "curl -fsSL https://bun.sh/install | bash"; then

		# shellcheck disable=SC1091
		[[ -f "$HOME/.bun/bin/bun" ]] && ensure_path "$HOME/.bun/bin"
		track_installed "bun" "$(get_package_description bun)"
		return 0
	else
		track_failed "bun" "$(get_package_description bun)"
		return 1
	fi
}

install_macports_package() {
	local package="$1"
	local min_version="${2:-}"
	local check_cmd="${3:-$package}"

	if ! cmd_exists port; then
		log_warning "MacPorts not installed, skipping $package"
		return 1
	fi

	if needs_install "$check_cmd" "$min_version"; then
		log_step "Installing $package via MacPorts..."
		if run_cmd "sudo port install $package"; then
			track_installed "$package" "$(get_package_description "$package")"
			return 0
		else
			track_failed "$package" "$(get_package_description "$package")"
			return 1
		fi
	else
		track_skipped "$check_cmd" "$(get_package_description "$check_cmd")"
		return 0
	fi
}

install_zsh() {
	if cmd_exists zsh; then
		track_skipped "zsh" "shell (built-in)"
		return 0
	fi

	log_step "Installing zsh via brew..."

	if run_cmd "brew install zsh >/dev/null 2>&1"; then
		track_installed "zsh" "shell (brew)"
		log_success "zsh installed via brew"
		return 0
	else
		log_error "Failed to install zsh"
		track_failed "zsh" "shell"
		return 1
	fi
}

install_oh_my_zsh() {
	local omz_dir="$HOME/.oh-my-zsh"

	if [[ -d "$omz_dir" ]]; then
		track_skipped "oh-my-zsh" "zsh framework"
		return 0
	fi

	log_step "Installing oh-my-zsh..."

	if run_cmd 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'; then
		track_installed "oh-my-zsh" "zsh framework"
		log_success "oh-my-zsh installed"
		return 0
	else
		log_error "Failed to install oh-my-zsh"
		track_failed "oh-my-zsh" "zsh framework"
		return 1
	fi
}

install_zsh_plugins() {
	log_step "Installing zsh plugins..."

	local plugins_installed=0

	if [[ ! -d "$HOME/.oh-my-zsh/plugins/zsh-autosuggestions" ]]; then
		log_step "Installing zsh-autosuggestions..."
		if run_cmd "git clone https://github.com/zsh-users/zsh-autosuggestions '$HOME/.oh-my-zsh/plugins/zsh-autosuggestions' >/dev/null 2>&1"; then
			track_installed "zsh-autosuggestions" "zsh plugin"
			log_success "zsh-autosuggestions installed"
			plugins_installed=1
		fi
	else
		track_skipped "zsh-autosuggestions" "zsh plugin"
	fi

	if [[ ! -d "$HOME/.oh-my-zsh/plugins/zsh-syntax-highlighting" ]]; then
		log_step "Installing zsh-syntax-highlighting..."
		if run_cmd "git clone https://github.com/zsh-users/zsh-syntax-highlighting '$HOME/.oh-my-zsh/plugins/zsh-syntax-highlighting' >/dev/null 2>&1"; then
			track_installed "zsh-syntax-highlighting" "zsh plugin"
			log_success "zsh-syntax-highlighting installed"
			plugins_installed=1
		fi
	else
		track_skipped "zsh-syntax-highlighting" "zsh plugin"
	fi

	if [[ ! -d "$HOME/.oh-my-zsh/plugins/zsh-interactive-cd" ]]; then
		log_step "Installing zsh-interactive-cd..."
		if run_cmd "git clone https://github.com/changyuheng/zsh-interactive-cd '$HOME/.oh-my-zsh/plugins/zsh-interactive-cd' >/dev/null 2>&1"; then
			track_installed "zsh-interactive-cd" "zsh plugin"
			log_success "zsh-interactive-cd installed"
			plugins_installed=1
		fi
	else
		track_skipped "zsh-interactive-cd" "zsh plugin"
	fi

	if [[ $plugins_installed -eq 1 ]]; then
		log_success "zsh plugins installation complete"
	fi

	return 0
}
