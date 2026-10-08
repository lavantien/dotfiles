#!/usr/bin/env bash

# shellcheck source=../lib/common.sh
# shellcheck source=../lib/version-check.sh

get_package_description() {
	local pkg="$1"
	case "$pkg" in
	git) echo "version control" ;;
	node | nodejs) echo "Node.js runtime" ;;
	python | python3) echo "Python runtime" ;;
	golang | go) echo "Go runtime" ;;
	rust) echo "Rust toolchain" ;;
	rust-analyzer) echo "Rust LSP" ;;
	bun) echo "JavaScript runtime" ;;
	dotnet-sdk) echo ".NET SDK" ;;
	default-jdk | openjdk) echo "Java development" ;;
	lua-language-server) echo "Lua LSP" ;;
	clangd) echo "C/C++ LSP" ;;
	gopls) echo "Go LSP" ;;
	pyright) echo "Python LSP" ;;
	typescript-language-server) echo "TypeScript LSP" ;;
	yaml-language-server) echo "YAML LSP" ;;
	csharp-ls) echo "C# LSP" ;;
	jdtls | eclipse-jdt) echo "Java LSP" ;;
	intelephense) echo "PHP LSP" ;;
	docker-compose-language-server) echo "Docker Compose LSP" ;;
	helm-ls) echo "Helm LSP" ;;
	tombi) echo "TOML LSP" ;;
	tinymist) echo "Typst LSP" ;;
	prettier) echo "code formatter" ;;
	yamllint) echo "YAML linter" ;;
	hadolint) echo "Dockerfile linter" ;;
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
	docker-compose) echo "Docker Compose CLI" ;;
	helm) echo "Kubernetes package manager" ;;
	kubectl) echo "Kubernetes CLI" ;;
	sqlite | sqlite3) echo "SQL database CLI" ;;
	vscode) echo "code editor" ;;
	latex | texlive) echo "document preparation" ;;
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
			log_info "Set core.autocrlf=false (no conversion on Linux)"
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

install_apt_package() {
	local package="$1"
	local min_version="${2:-}"
	local check_cmd="${3:-$package}"

	if needs_install "$check_cmd" "$min_version"; then
		log_step "Installing $package via apt..."
		if [[ "$DRY_RUN" == "false" ]]; then
			if ! sudo apt update >/dev/null 2>&1; then
				log_warning "apt update failed, continuing anyway"
			fi
			if run_cmd "sudo apt install -y $package"; then
				track_installed "$package" "$(get_package_description "$package")"
				return 0
			else
				track_failed "$package" "$(get_package_description "$package")"
				return 1
			fi
		else
			track_installed "$package" "$(get_package_description "$package")"
			return 0
		fi
	else
		track_skipped "$check_cmd" "$(get_package_description "$check_cmd")"
		return 0
	fi
}

install_dnf_package() {
	local package="$1"
	local min_version="${2:-}"
	local check_cmd="${3:-$package}"

	if needs_install "$check_cmd" "$min_version"; then
		log_step "Installing $package via dnf..."
		if run_cmd "sudo dnf install -y $package"; then
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

install_pacman_package() {
	local package="$1"
	local min_version="${2:-}"
	local check_cmd="${3:-$package}"

	if needs_install "$check_cmd" "$min_version"; then
		log_step "Installing $package via pacman..."
		if run_cmd "sudo pacman -S --noconfirm $package"; then
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

install_zypper_package() {
	local package="$1"
	local min_version="${2:-}"
	local check_cmd="${3:-$package}"

	if needs_install "$check_cmd" "$min_version"; then
		log_step "Installing $package via zypper..."
		if run_cmd "sudo zypper install -y $package"; then
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

install_linux_package() {
	local package="$1"
	local min_version="${2:-}"
	local check_cmd="${3:-$package}"
	local distro_family
	distro_family="$(get_distro_family)"

	if needs_install "$check_cmd" "$min_version"; then
		:
	else
		track_skipped "$check_cmd" "$(get_package_description "$check_cmd")"
		return 0
	fi

	if cmd_exists brew; then
		case "$package" in

		nodejs)

			if dpkg -l | grep -q "ii  nodejs" 2>/dev/null; then
				log_warning "Found nodejs from apt (auto-removing for brew version)..."
				run_cmd "sudo apt remove -y nodejs npm 2>/dev/null || true"
			fi

			if snap list 2>/dev/null | grep -q "node"; then
				log_warning "Found node from snap (auto-removing for brew version)..."
				run_cmd "sudo snap remove node 2>/dev/null || true"
			fi
			;;
		python | python3)

			if pip list --user 2>/dev/null | grep -q " setuptools"; then
				:
			fi
			;;
		golang | go)

			if dpkg -l | grep -q "ii  golang-go" 2>/dev/null; then
				log_warning "Found golang from apt (auto-removing for brew version)..."
				run_cmd "sudo apt remove -y golang-go 2>/dev/null || true"
			fi
			;;
		php)

			if dpkg -l | grep -q "php8.*-cli" 2>/dev/null; then
				log_warning "Found PHP from apt (auto-removing for brew version with curl)..."
				run_cmd "sudo apt remove -y 'php8.*' 2>/dev/null || true"
			fi
			;;
		dotnet)

			if dpkg -l | grep -q "dotnet-sdk" 2>/dev/null; then
				log_warning "Found dotnet from apt (auto-removing for brew version)..."
				run_cmd "sudo apt remove -y 'dotnet-*' 2>/dev/null || true"
			fi
			;;

		clangd)

			if [[ "$(command -v clangd 2>/dev/null)" == /usr/bin/clangd ]]; then
				log_warning "Found clangd from apt (auto-removing for brew version)..."
				run_cmd "sudo apt remove -y clangd clang-format 2>/dev/null || true"
			fi
			;;
		lua-language-server)

			if dpkg -l | grep -q "lua-language-server" 2>/dev/null; then
				log_warning "Found lua-language-server from apt (auto-removing for brew version)..."
				run_cmd "sudo apt remove -y lua-language-server 2>/dev/null || true"
			fi

			if npm list -g "lua-language-server" &>/dev/null || pip3 show "lua-language-server" &>/dev/null; then
				log_warning "Found lua-language-server from npm/pip (auto-removing for brew version)..."
				run_cmd "npm uninstall -g 'lua-language-server' 2>/dev/null || true"
				run_cmd "pip3 uninstall -y 'lua-language-server' 2>/dev/null || true"
			fi
			;;
		jdtls | eclipse-jdtls)

			if dpkg -l | grep -q "eclipse-jdt" 2>/dev/null; then
				log_warning "Found eclipse-jdt from apt (auto-removing for brew version)..."
				run_cmd "sudo apt remove -y eclipse-jdt 2>/dev/null || true"
			fi
			;;
		rust-analyzer)

			if [[ -f "$HOME/.cargo/bin/rust-analyzer" ]]; then
				log_warning "Found rust-analyzer from cargo (auto-removing for brew version)..."
				run_cmd "cargo uninstall rust-analyzer 2>/dev/null || true"
			fi
			;;

		prettier | eslint | ruff | black | mypy | yamllint | shellcheck | shfmt | stylua | selene)

			local npm_pkg="$package"
			[[ "$package" == "shellcheck" ]] && npm_pkg="shellcheck"
			if npm list -g "$npm_pkg" &>/dev/null || pip3 show "$npm_pkg" &>/dev/null; then
				log_warning "Found $package from npm/pip (auto-removing for brew version)..."
				run_cmd "npm uninstall -g '$npm_pkg' 2>/dev/null || true"
				run_cmd "pip3 uninstall -y '$npm_pkg' 2>/dev/null || true"
			fi
			;;
		golangci-lint)

			if [[ -f "$HOME/go/bin/golangci-lint" ]]; then
				log_warning "Found golangci-lint from go install (auto-removing for brew version)..."
				run_cmd "rm -f '$HOME/go/bin/golangci-lint' 2>/dev/null || true"
			fi
			;;

		fzf)
			if dpkg -l | grep -q "ii  fzf" 2>/dev/null; then
				log_warning "Found fzf from apt (auto-removing for brew version)..."
				run_cmd "sudo apt remove -y fzf 2>/dev/null || true"
			fi
			;;
		zoxide)
			if dpkg -l | grep -q "ii  zoxide" 2>/dev/null; then
				log_warning "Found zoxide from apt (auto-removing for brew version)..."
				run_cmd "sudo apt remove -y zoxide 2>/dev/null || true"
			fi
			;;
		bat)
			if dpkg -l | grep -q "ii  bat" 2>/dev/null; then
				log_warning "Found bat from apt (auto-removing for brew version)..."
				run_cmd "sudo apt remove -y bat 2>/dev/null || true"
			fi
			;;
		eza)
			if dpkg -l | grep -q "ii  eza" 2>/dev/null; then
				log_warning "Found eza from apt (auto-removing for brew version)..."
				run_cmd "sudo apt remove -y eza 2>/dev/null || true"
			fi

			if dpkg -l | grep -q "ii  exa" 2>/dev/null; then
				log_warning "Found exa from apt (auto-removing for brew eza)..."
				run_cmd "sudo apt remove -y exa 2>/dev/null || true"
			fi
			;;
		lazygit)
			if dpkg -l | grep -q "ii  lazygit" 2>/dev/null; then
				log_warning "Found lazygit from apt (auto-removing for brew version)..."
				run_cmd "sudo apt remove -y lazygit 2>/dev/null || true"
			fi
			;;
		gh)
			if dpkg -l | grep -q "ii  gh" 2>/dev/null; then
				log_warning "Found gh from apt (auto-removing for brew version)..."
				run_cmd "sudo apt remove -y gh 2>/dev/null || true"
			fi

			if dpkg -l | grep -q "ii  github-cli" 2>/dev/null; then
				log_warning "Found github-cli from apt (auto-removing for brew version)..."
				run_cmd "sudo apt remove -y github-cli 2>/dev/null || true"
			fi
			;;
		tokei)
			if dpkg -l | grep -q "ii  tokei" 2>/dev/null; then
				log_warning "Found tokei from apt (auto-removing for brew version)..."
				run_cmd "sudo apt remove -y tokei 2>/dev/null || true"
			fi
			;;
		ripgrep)
			if dpkg -l | grep -q "ii  ripgrep" 2>/dev/null; then
				log_warning "Found ripgrep from apt (auto-removing for brew version)..."
				run_cmd "sudo apt remove -y ripgrep 2>/dev/null || true"
			fi
			;;
		fd | fd-find)
			if dpkg -l | grep -q "ii  fd-find" 2>/dev/null; then
				log_warning "Found fd-find from apt (auto-removing for brew version)..."
				run_cmd "sudo apt remove -y fd-find 2>/dev/null || true"
			fi
			if dpkg -l | grep -q "ii  fd" 2>/dev/null; then
				log_warning "Found fd from apt (auto-removing for brew version)..."
				run_cmd "sudo apt remove -y fd 2>/dev/null || true"
			fi
			;;
		bats)
			if dpkg -l | grep -q "ii  bats" 2>/dev/null; then
				log_warning "Found bats from apt (auto-removing for brew version)..."
				run_cmd "sudo apt remove -y bats 2>/dev/null || true"
			fi

			if npm list -g "bats" &>/dev/null; then
				log_warning "Found bats from npm (auto-removing for brew version)..."
				run_cmd "npm uninstall -g 'bats' 2>/dev/null || true"
			fi
			;;
		difftastic | difft)

			if [[ -f "$HOME/.cargo/bin/difft" ]]; then
				log_warning "Found difftastic from cargo (auto-removing for brew version)..."
				run_cmd "cargo uninstall difftastic 2>/dev/null || true"
			fi
			;;

		texlive)

			if dpkg -l | grep -q "texlive-base" 2>/dev/null; then
				log_warning "Found texlive from apt (auto-removing for brew version)..."
				sudo dpkg -r texlive-base texlive-binaries texlive-common texlive-extra-extra texlive-fonts-recommended texlive-latex-base texlive-latex-extra texlive-luatex texlive-xetex >/dev/null 2>&1 || true
			fi
			;;

		*)

			if cmd_exists snap && snap list 2>/dev/null | grep -q "^${package}$"; then
				log_warning "Found $package from snap (auto-removing for brew version)..."
				run_cmd "sudo snap remove $package 2>/dev/null || true"
			fi

			if cmd_exists flatpak && flatpak list 2>/dev/null | grep -qi "$package"; then
				log_warning "Found $package from flatpak (auto-removing for brew version)..."
				run_cmd "sudo flatpak uninstall -y $package 2>/dev/null || true"
			fi

			if [[ -f "$HOME/.local/bin/$package" ]] || [[ -L "$HOME/.local/bin/$package" ]]; then
				log_warning "Found $package in ~/.local/bin (may need manual cleanup)..."
			fi

			if ls ~/Applications/"${package}"*.AppImage 2>/dev/null; then
				log_warning "Found $package AppImage (may need manual cleanup)..."
			fi

			;;
		esac
	fi

	if cmd_exists brew; then
		local brew_package="$package"

		case "$package" in
		nodejs) brew_package="node" ;;
		golang) brew_package="go" ;;
		php) brew_package="php" ;;
		lua-language-server) brew_package="lua-language-server" ;;
		golangci-lint) brew_package="golangci-lint" ;;
		shellcheck) brew_package="shellcheck" ;;
		shfmt) brew_package="shfmt" ;;
		bat) brew_package="bat" ;;
		eza | exa) brew_package="eza" ;;
		fzf) brew_package="fzf" ;;
		zoxide) brew_package="zoxide" ;;
		lazygit) brew_package="lazygit" ;;
		gh) brew_package="gh" ;;
		ripgrep) brew_package="ripgrep" ;;
		fd-find) brew_package="fd" ;;
		tokei) brew_package="tokei" ;;
		docker-compose) brew_package="docker-compose" ;;
		helm) brew_package="helm" ;;
		helm-ls) brew_package="helm-ls" ;;
		kubectl) brew_package="kubernetes-cli" ;;
		yamllint) brew_package="yamllint" ;;
		hadolint) brew_package="hadolint" ;;
		texlive) brew_package="texlive" ;;
		neovim) brew_package="neovim" ;;
		clangd) brew_package="llvm" ;;
		prettier) brew_package="prettier" ;;
		eslint) brew_package="eslint" ;;
		ruff) brew_package="ruff" ;;
		black) brew_package="black" ;;
		mypy) brew_package="mypy" ;;
		stylua) brew_package="stylua" ;;
		selene) brew_package="selene" ;;
		jdtls) brew_package="eclipse-jdt" ;;
		powershell-es) brew_package="powershell" ;;
		rust-analyzer) brew_package="rust-analyzer" ;;
		esac

		log_step "Trying brew for $brew_package..."
		if install_brew_package "$brew_package" "$min_version" "$check_cmd" 2>/dev/null; then

			if [[ "$brew_package" == "llvm" ]] && [[ "$package" == "clangd" ]]; then

				ensure_path "/home/linuxbrew/.linuxbrew/opt/llvm/bin"

				if [[ -f "/home/linuxbrew/.linuxbrew/opt/llvm/bin/clangd" ]]; then
					ln -sf "/home/linuxbrew/.linuxbrew/opt/llvm/bin/clangd" "/home/linuxbrew/.linuxbrew/bin/clangd" 2>/dev/null || true
				fi
			fi
			return 0
		fi
		log_info "Brew install failed or package not available, trying next method..."
	fi

	case "$package" in
	claude)

		if cmd_exists curl; then
			log_step "Installing Claude Code via official script..."
			if run_cmd "curl -fsSL https://claude.ai/install.sh | bash"; then
				ensure_path "$HOME/.local/bin"
				fix_path_issues
				if cmd_exists claude; then
					track_installed "claude" "AI CLI"
					return 0
				fi
			fi
		fi
		;;
	dotnet-sdk)

		if [[ "$OS" == "macos" ]]; then

			:
		elif [[ "$distro_family" == "debian" ]] && [[ -f /etc/debian_version ]]; then
			log_step "Installing .NET SDK via Microsoft apt repository..."
			if run_cmd "wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg" &&
				run_cmd "echo \"deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/ubuntu/$(lsb_release -rs)/prod $(lsb_release -cs) main\" | sudo tee /etc/apt/sources.list.d/microsoft.list" &&
				run_cmd "sudo apt update >/dev/null 2>&1 && sudo apt install -y dotnet-sdk-10.0 >/dev/null 2>&1"; then
				track_installed "dotnet-sdk" ".NET SDK"
				return 0
			fi
		fi
		;;
	csharp-ls)

		if cmd_exists dotnet; then
			log_step "Installing csharp-ls via dotnet tool..."
			if run_cmd "dotnet tool install --global csharp-ls >/dev/null 2>&1"; then
				ensure_path "$HOME/.dotnet/tools"
				if cmd_exists csharp-ls; then
					track_installed "csharp-ls" "C# LSP"
					return 0
				fi
			fi
		fi
		;;
	php)

		if install_php; then
			return 0
		fi
		;;
	esac

	case "$package" in
	yaml-language-server | typescript-language-server | \
		intelephense | tinymist | tombi | \
		vscode-langservers-extracted | svelte-language-server)
		if cmd_exists npm; then
			log_step "Trying npm for $package..."
			if install_npm_global "$package" "$check_cmd" ""; then
				return 0
			fi
		fi
		;;
	esac

	case "$package" in
	gopls | goimports | gup)

		if cmd_exists go; then
			local go_package
			case "$package" in
			gopls) go_package="golang.org/x/tools/gopls@latest" ;;
			goimports) go_package="golang.org/x/tools/cmd/goimports@latest" ;;
			gup) go_package="github.com/nao1215/gup@latest" ;;
			esac
			log_step "Trying go install for $package..."
			if install_go_package "$go_package" "$check_cmd"; then
				return 0
			fi
		fi
		;;
	esac

	case "$package" in
	cargo_update | cargo-update)

		if cmd_exists cargo; then
			if install_cargo_update; then
				return 0
			fi
		fi
		;;
	difftastic)

		if cmd_exists cargo; then
			if install_cargo_package "difftastic" "difft" ""; then
				return 0
			fi
		fi
		;;
	*)

		:
		;;
	esac

	case "$package" in
	isort)

		if cmd_exists pip3 || cmd_exists pip; then
			log_step "Trying pip for $package..."
			if install_pip_global "$package" "$check_cmd" ""; then
				return 0
			fi
		fi
		;;
	esac

	case "$distro_family" in
	debian)
		install_apt_package "$package" "$min_version" "$check_cmd"
		;;
	fedora)
		install_dnf_package "$package" "$min_version" "$check_cmd"
		;;
	arch)
		install_pacman_package "$package" "$min_version" "$check_cmd"
		;;
	opensuse)
		install_zypper_package "$package" "$min_version" "$check_cmd"
		;;
	*)
		log_warning "Unknown distro family: $distro_family"
		track_failed "$package"
		return 1
		;;
	esac
}

install_flatpak_app() {
	local app_id="$1"
	local check_cmd="${2:-}"
	local display_name="${3:-$app_id}"

	if [[ -z "$check_cmd" ]]; then

		check_cmd="${app_id##*.}"
	fi

	if ! cmd_exists flatpak; then
		log_info "flatpak not installed, skipping $display_name"
		return 1
	fi

	if needs_install "$check_cmd" ""; then
		log_step "Installing $display_name via flatpak..."
		if run_cmd "flatpak install -y --noninteractive flathub $app_id"; then
			track_installed "$display_name"
			return 0
		else
			track_failed "$display_name"
			return 1
		fi
	else
		track_skipped "$check_cmd"
		return 0
	fi
}

install_snap_app() {
	local app_name="$1"
	local check_cmd="${2:-$app_name}"

	if ! cmd_exists snap; then
		log_info "snap not installed, skipping $app_name"
		return 1
	fi

	if needs_install "$check_cmd" ""; then
		log_step "Installing $app_name via snap..."
		if run_cmd "sudo snap install $app_name --classic"; then
			track_installed "$app_name"
			return 0
		else
			track_failed "$app_name"
			return 1
		fi
	else
		track_skipped "$check_cmd"
		return 0
	fi
}

ensure_coursier() {
	if cmd_exists cs || cmd_exists coursier; then
		track_skipped "coursier" "JVM dependency manager"
		return 0
	fi

	if ! cmd_exists java; then
		log_warning "Java not found, skipping coursier install"
		track_failed "coursier" "JVM dependency manager"
		return 1
	fi

	log_step "Installing coursier..."

	if [[ "$DRY_RUN" == "true" ]]; then
		log_info "[DRY-RUN] Would install coursier to ~/.local/bin/cs"
		track_installed "coursier" "JVM dependency manager"
		return 0
	fi

	local arch="x86_64-pc-linux"
	if [[ "$(uname -m)" == "aarch64" || "$(uname -m)" == "arm64" ]]; then
		arch="aarch64-pc-linux"
	fi

	mkdir -p "$HOME/.local/bin"
	if curl -fsSL "https://github.com/coursier/coursier/releases/latest/download/cs-${arch}.gz" |
		gunzip >"$HOME/.local/bin/cs" && chmod +x "$HOME/.local/bin/cs"; then
		ensure_path "$HOME/.local/bin"
		track_installed "coursier" "JVM dependency manager"
		verify_installed cs coursier "JVM dependency manager"
		return 0
	fi

	track_failed "coursier" "JVM dependency manager"
	return 1
}

install_coursier_package() {
	local pkg="$1"
	local desc="${2:-$pkg}"
	local cs_bin_dir="$HOME/.local/share/coursier/bin"

	ensure_coursier || return 1

	local cs_cmd
	cs_cmd="$(command -v cs || command -v coursier)" || {
		log_warning "coursier unavailable, skipping $pkg"
		return 1
	}

	if needs_install "$pkg"; then
		log_step "Installing $pkg via coursier..."

		if [[ "$DRY_RUN" == "true" ]]; then
			log_info "[DRY-RUN] Would coursier install $pkg"
			track_installed "$pkg" "$desc"
			return 0
		fi

		if "$cs_cmd" install "$pkg" >/dev/null 2>&1; then
			ensure_path "$cs_bin_dir"
			track_installed "$pkg" "$desc"
			verify_installed "$pkg" "$pkg" "$desc"
		else
			log_warning "Failed to install $pkg via coursier"
			track_failed "$pkg" "$desc"
			return 1
		fi
	else

		[[ -x "$cs_bin_dir/$pkg" ]] && ensure_path "$cs_bin_dir"
		log_verbose "$pkg already installed"
		track_skipped "$pkg" "$desc"
	fi

	return 0
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
		local npm_output
		npm_output="$(npm install -g "$package" 2>&1)"
		local exit_code=$?

		if echo "$npm_output" | grep -qiE "up to date|already installed|nothing to install"; then
			track_skipped "$cmd_name" "$(get_package_description "$cmd_name")"
			return 0
		fi

		if [ $exit_code -eq 0 ]; then
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

	log_step "Installing PHP with curl extension..."

	if cmd_exists brew; then
		if run_cmd "brew install php"; then
			track_installed "php" "$(get_package_description php)"
			return 0
		fi
	fi

	local php_version=""
	local php_curl_package=""

	if cmd_exists php; then
		php_version="$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;' 2>/dev/null)"
	fi

	if [[ -n "$php_version" ]]; then
		log_step "Installing curl extension for PHP $php_version..."
		php_curl_package="php${php_version}-curl"
	else
		php_curl_package="php-curl"
	fi

	if cmd_exists apt; then
		if run_cmd "sudo apt install -y $php_curl_package"; then
			track_installed "php" "$(get_package_description php)"
			return 0
		fi
	elif cmd_exists dnf; then
		if run_cmd "sudo dnf install -y php-curl"; then
			track_installed "php" "$(get_package_description php)"
			return 0
		fi
	elif cmd_exists pacman; then
		if run_cmd "sudo pacman -S --noconfirm php-curl"; then
			track_installed "php" "$(get_package_description php)"
			return 0
		fi
	elif cmd_exists zypper; then
		if run_cmd "sudo zypper install -y php-curl"; then
			track_installed "php" "$(get_package_description php)"
			return 0
		fi
	fi

	track_failed "php" "$(get_package_description php)"
	return 1
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

		if cmd_exists brew; then
			case "$package" in
			ruff | black | isort | mypy | pytest | pytest-cov)
				if run_cmd "brew install $package >/dev/null 2>&1"; then
					track_installed "$package" "$(get_package_description "$cmd_name")"
					return 0
				fi
				;;
			esac
		fi

		if run_cmd "$python_cmd -m pip install --break-system-packages --upgrade $package"; then
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
	local detected_pkg_manager=""

	if cmd_exists apt; then
		detected_pkg_manager="apt"
	elif cmd_exists dnf; then
		detected_pkg_manager="dnf"
	elif cmd_exists pacman; then
		detected_pkg_manager="pacman"
	elif cmd_exists zypper; then
		detected_pkg_manager="zypper"
	else
		log_warning "No supported package manager found for build dependencies"
		return 1
	fi

	if cmd_exists pkg-config; then
		track_skipped "build-deps" "build dependencies"
		return 0
	fi

	log_step "Installing build dependencies (pkg-config, OpenSSL headers)..."

	case "$detected_pkg_manager" in
	apt)
		if run_cmd "sudo apt install -y pkg-config libssl-dev"; then
			track_installed "build-deps" "build dependencies"
			return 0
		else
			track_failed "build-deps" "build dependencies"
			return 1
		fi
		;;
	dnf)
		if run_cmd "sudo dnf install -y pkg-config openssl-devel"; then
			track_installed "build-deps" "build dependencies"
			return 0
		else
			track_failed "build-deps" "build dependencies"
			return 1
		fi
		;;
	pacman)
		if run_cmd "sudo pacman -S --noconfirm pkg-config openssl"; then
			track_installed "build-deps" "build dependencies"
			return 0
		else
			track_failed "build-deps" "build dependencies"
			return 1
		fi
		;;
	zypper)
		if run_cmd "sudo zypper install -y pkg-config libopenssl-devel"; then
			track_installed "build-deps" "build dependencies"
			return 0
		else
			track_failed "build-deps" "build dependencies"
			return 1
		fi
		;;
	esac

	return 1
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

install_wezterm_apt() {
	if cmd_exists wezterm; then
		track_skipped "wezterm" "terminal emulator"
		return 0
	fi

	log_step "Installing WezTerm via official apt repository..."

	if ! run_cmd "curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg"; then
		log_error "Failed to add WezTerm GPG key"
		track_failed "wezterm" "terminal emulator"
		return 1
	fi

	if ! run_cmd "echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null"; then
		log_error "Failed to add WezTerm repository"
		track_failed "wezterm" "terminal emulator"
		return 1
	fi

	run_cmd "sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg" || true

	if run_cmd "sudo apt update >/dev/null 2>&1 && sudo apt install -y wezterm >/dev/null 2>&1"; then
		track_installed "wezterm" "terminal emulator"
		log_success "WezTerm installed"
		return 0
	else
		log_error "Failed to install WezTerm"
		track_failed "wezterm" "terminal emulator"
		return 1
	fi
}

install_google_chrome() {
	if cmd_exists google-chrome; then
		track_skipped "google-chrome" "web browser"
		return 0
	fi

	log_step "Installing Google Chrome..."

	local deb_url="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
	local tmp_deb="/tmp/google-chrome-stable_current_amd64.deb"

	if ! run_cmd "wget -q --show-progress -O '$tmp_deb' '$deb_url'"; then
		log_error "Failed to download Google Chrome .deb"
		track_failed "google-chrome" "web browser"
		return 1
	fi

	if run_cmd "sudo apt-get install -y '$tmp_deb' >/dev/null 2>&1"; then

		rm -f "$tmp_deb" 2>/dev/null || true
		track_installed "google-chrome" "web browser"
		log_success "Google Chrome installed"
		return 0
	else
		log_error "Failed to install Google Chrome"
		rm -f "$tmp_deb" 2>/dev/null || true
		track_failed "google-chrome" "web browser"
		return 1
	fi
}

install_nerd_fonts() {
	local font_name="$1"
	local font_file="$2"
	local font_dir="$HOME/.local/share/fonts"

	if [[ -d "$font_dir" ]]; then
		if find "$font_dir" -iname "*${font_name}*" \( -name "*.ttf" -o -name "*.otf" \) | grep -q .; then
			track_skipped "$font_name" "Nerd Font"
			return 0
		fi
	fi

	log_step "Installing ${font_name} Nerd Font..."

	mkdir -p "$font_dir" || {
		log_error "Failed to create font directory: $font_dir"
		track_failed "$font_name" "Nerd Font"
		return 1
	}

	local tmp_dir
	tmp_dir="$(mktemp -d)"

	local download_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_file}.tar.xz"

	if ! run_cmd "curl -fsSL '$download_url' -o '$tmp_dir/${font_file}.tar.xz'"; then
		log_error "Failed to download $font_name"
		rm -rf "$tmp_dir"
		track_failed "$font_name" "Nerd Font"
		return 1
	fi

	if ! run_cmd "tar -xf '$tmp_dir/${font_file}.tar.xz' -C '$tmp_dir'"; then
		log_error "Failed to extract $font_name"
		rm -rf "$tmp_dir"
		track_failed "$font_name" "Nerd Font"
		return 1
	fi

	run_cmd "find '$tmp_dir' \( -name '*.ttf' -o -name '*.otf' \) -exec cp '{}' '$font_dir/' \;" || {
		log_error "Failed to copy $font_name fonts"
		rm -rf "$tmp_dir"
		track_failed "$font_name" "Nerd Font"
		return 1
	}

	rm -rf "$tmp_dir"

	if command -v fc-cache >/dev/null 2>&1; then
		run_cmd "fc-cache -f '$font_dir' >/dev/null 2>&1" || true
	fi

	track_installed "$font_name" "Nerd Font"
	log_success "$font_name Nerd Font installed"
}

install_zsh() {
	if cmd_exists zsh; then
		track_skipped "zsh" "shell"
		return 0
	fi

	log_step "Installing zsh..."

	if cmd_exists brew; then
		if run_cmd "brew install zsh >/dev/null 2>&1"; then
			track_installed "zsh" "shell (brew)"
			log_success "zsh installed via brew"
			return 0
		fi
	fi

	if [[ -f /etc/debian_version ]]; then
		if run_cmd "sudo apt update >/dev/null 2>&1 && sudo apt install -y zsh >/dev/null 2>&1"; then
			track_installed "zsh" "shell (apt)"
			log_success "zsh installed via apt"
			return 0
		fi
	fi

	log_error "Failed to install zsh"
	track_failed "zsh" "shell"
	return 1
}

install_oh_my_zsh() {
	local omz_dir="$HOME/.oh-my-zsh"

	if [[ -d "$omz_dir" ]]; then
		track_skipped "oh-my-zsh" "zsh framework"
		return 0
	fi

	log_step "Installing oh-my-zsh..."

	# shellcheck disable=SC2016  # $(curl) expands inside sh -c, not here
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

ensure_homebrew() {
	if cmd_exists brew; then
		track_skipped "brew" "$(get_package_description brew)"
		return 0
	fi

	log_step "Installing Homebrew for Linux..."
	# shellcheck disable=SC2016  # $(curl) expands inside bash -c, not here
	if run_cmd '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'; then

		if [[ -d "/home/linuxbrew/.linuxbrew/bin" ]]; then
			ensure_path "/home/linuxbrew/.linuxbrew/bin"
		elif [[ -d "$HOME/.linuxbrew/bin" ]]; then
			ensure_path "$HOME/.linuxbrew/bin"
		fi
		track_installed "brew"
		return 0
	else
		track_failed "brew"
		return 1
	fi
}

install_brew_package() {
	local package="$1"
	local min_version="${2:-}"
	local check_cmd="${3:-$package}"

	if ! cmd_exists brew; then
		log_warning "Homebrew not installed, skipping $package"
		return 1
	fi

	if needs_install "$check_cmd" "$min_version"; then
		log_step "Installing $package via brew..."
		local brew_output
		local exit_code=0
		brew_output="$(brew install "$package" 2>&1)" || exit_code=$?

		if echo "$brew_output" | grep -qiE "already installed|up-to-date|not installed|reinstall.*to"; then

			track_skipped "$package"

			echo "$brew_output" | grep -vE "^$" | head -5 | sed 's/^/  /'
			return 0
		fi

		if [ $exit_code -eq 0 ]; then
			track_installed "$package"
			return 0
		else
			track_failed "$package"
			return 1
		fi
	else
		track_skipped "$check_cmd"
		return 0
	fi
}

ensure_brew_version() {
	local brew_pkg="$1"
	local check_cmd="$2"
	local apt_pkg="${3:-$check_cmd}"

	if ! cmd_exists "$check_cmd"; then
		install_brew_package "$brew_pkg" "" "$check_cmd"
		return 0
	fi

	local cmd_path
	cmd_path="$(which "$check_cmd" 2>/dev/null || echo "")"

	if [[ -z "$cmd_path" ]]; then

		install_brew_package "$brew_pkg" "" "$check_cmd"
		return 0
	fi

	if [[ "$cmd_path" == *"/linuxbrew/"* ]] || [[ "$cmd_path" == *"/.linuxbrew/"* ]]; then
		track_skipped "$check_cmd" "$(get_package_description "$check_cmd")"
		log_info "$check_cmd already from brew, skipping replacement"
		return 0
	fi

	log_step "Replacing system $check_cmd with brew version..."
	log_info "Current location: $cmd_path"

	if [[ -n "$apt_pkg" ]] && [[ "$apt_pkg" != "$brew_pkg" ]]; then
		run_cmd "sudo apt remove -y $apt_pkg >/dev/null 2>&1" || true
	fi

	log_step "Installing $brew_pkg via brew..."
	local brew_output
	local exit_code=0
	brew_output="$(brew install "$brew_pkg" 2>&1)" || exit_code=$?

	if echo "$brew_output" | grep -qiE "already installed|up-to-date|not installed|reinstall.*to"; then

		track_skipped "$brew_pkg" "$(get_package_description "$check_cmd")"

		echo "$brew_output" | grep -vE "^$" | head -5 | sed 's/^/  /'
		log_warning "May need to reload shell to see new $check_cmd location"
		return 0
	fi

	if [ $exit_code -eq 0 ]; then
		track_installed "$brew_pkg" "$(get_package_description "$check_cmd")"
	else
		track_failed "$brew_pkg" "$(get_package_description "$check_cmd")"
		return 1
	fi

	fix_path_issues

	local new_path
	new_path="$(which "$check_cmd" 2>/dev/null || echo "")"
	if [[ "$new_path" != "$cmd_path" ]] && [[ -n "$new_path" ]]; then
		log_success "Replaced $check_cmd: $new_path"
	else
		log_warning "May need to reload shell to see new $check_cmd location"
	fi

	return 0
}

BREW_PREFERRED_PACKAGES=(
	"git:git"
	"gcc:gcc"
	"node:node"
	"go:go"
	"lua-language-server:lua-language-server"
	"golangci-lint:golangci-lint"
	"shellcheck:shellcheck"
	"shfmt:shfmt"
	"bat:bat"
	"eza:eza"
	"fzf:fzf"
	"zoxide:zoxide"
	"lazygit:lazygit"
	"gh:gh"
	"ripgrep:rg"
	"fd:fd"
	"tokei:tokei"
)

ensure_brew_packages() {
	if ! cmd_exists brew; then
		return 0
	fi

	log_step "Ensuring key packages are from brew..."

	for pkg_pair in "${BREW_PREFERRED_PACKAGES[@]}"; do
		local brew_pkg="${pkg_pair%%:*}"
		local check_cmd="${pkg_pair##*:}"

		local apt_pkg=""
		case "$check_cmd" in
		node) apt_pkg="nodejs" ;;
		go) apt_pkg="golang" ;;
		eza) apt_pkg="eza" ;;
		rg) apt_pkg="ripgrep" ;;
		fd) apt_pkg="fd-find" ;;
		*) apt_pkg="$check_cmd" ;;
		esac

		ensure_brew_version "$brew_pkg" "$check_cmd" "$apt_pkg"
	done

	log_success "Package self-correction complete"
}
