# A robust Dotfiles for Developer - Ubuntu & Neovim - Battery Included

- Quality Assurance: **100%**
- Supported: **AMD** & **Intel** (Wayland), **NVIDIA** (auto X11), **Windows** (Neovim)
- Turn off `Secure Boot` in your `BIOS` for a smooth installation process
- Install with `Minimal setup` and `ZFS full disk encryption` to avoid the feds diddling with your machine
- If you're floating on cash make sure to always use Mullvad VPN and Tor Network/Snowflake
- And if you're broke, use the free WARP and practice good OpSec hygiene
- A modern software engineering free quality resources library: <https://gist.github.com/lavantien/dc730dad7d7e8157000ddae845eddfd7>

## Step-by-Step Standardized Setup for a Fresh Ubuntu 24.04 LTS

<details>
  <summary>expand</summary>

### 0. Disable Wireless Powersaving and Files Open Limit; increase swap size

```bash
sudo vi /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf
```

```conf
[connection]
wifi.powersave = 2
```

```bash
sudo systemctl restart NetworkManager
```

```bash
sudo vi /etc/systemd/system.conf
```

```conf
DefaultLimitNOFILE=4096:2097152
```

```bash
sudo vi /etc/systemd/user.conf
```

```conf
DefaultLimitNOFILE=4096:2097152
```

```bash
cat /proc/sys/fs/inotify/max_user_watches && sudo sysctl fs.inotify.max_user_watches=2097152
```

```bash
sudo systemctl daemon-reexec
```

`reboot`

```bash
ulimit -n
```

```bash
sudo swapoff -a && sudo dd if=/dev/zero of=/swapfile bs=1G count=16 && sudo chmod 0600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile && grep Swap /proc/meminfo
```

Add this line to the end of your `/etc/fstab`:

```bash
/swapfile swap swap sw 0 0
```

- Add this line in `/etc/sysfs.conf`, if you're AMD, use `zenpower`:

```bash
mode class/powercap/intel-rapl:0/energy_uj = 0444
```

### 1. Install all necessary `APT` packages

```bash
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt install ubuntu-desktop ca-certificates apt-transport-https ubuntu-dev-tools glibc-source gcc xclip git curl zsh htop vim libutf8proc2 libutf8proc-dev libfuse2 cpu-checker screenkey cmake cmake-format ninja-build libjsoncpp-dev uuid-dev zlib1g-dev libssl-dev postgresql-all libmariadb-dev libsqlite3-dev libhiredis-dev jq bc xorg-dev libxcursor-dev cloud-init openssh-server ssh-import-id nvtop rar unrar sysfsutils latexmk mupdf -y
```


### 2. Install `Oh-my-zsh` and `Firefox`, then `reboot`

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

- Open `Firefox`, sync your profile, and go to <https://github.com/lavantien/dotfiles/blob/main/README.md> to continue the steps
- Recommended `Firefox Extensions`:

```text
Cookie Quick Manager
Dark Reader
Privacy Badger
Return YouTube Dislike
Search by Image
Sidebery
Snowflake
SponsorBlock
uBlock Origin
Vimium
Wikipedia (en)
```

### 3. After `reboot`, install `Linuxbrew`

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 4. Install `zsh-autosuggestions`

```bash
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```

### 5. Install the proper `.zshrc` by clone this repo to `~/temp`, copy all its content to `~`

```bash
git clone https://github.com/lavantien/dotfiles.git ~/temp && cp -r ~/temp/{*,.*} ~/ && cp -r ~/temp/.config/* ~/.config/ && cp ~/temp/.local/share/applications/* ~/.local/share/applications/ && source ~/.zshrc
```

### 6. Install `rust` and its toolchains, then `reboot`

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### 7. Install `gcc`, `gh`, `neovim`, and other necessary `Brew` packages

```bash
brew install gcc@11 gcc gh go lazygit fzf fd ripgrep bat tokei neovim hyperfine openjdk ruby lua maven node gopls rust-analyzer jdtls lua-language-server typescript-language-server marksman texlab yaml-language-server bash-language-server terraform terraform-ls sql-language-server sqlfluff prettier delve vscode-langservers-extracted loc llvm dotenv-linter checkmake luarocks pkg-config mpv macchina
```

```bash
pip3 install cmake-language-server python-lsp-server && npm install --global sql-formatter && sudo apt install python-is-python3 -y && go install github.com/charmbracelet/glow@latest && go install -v github.com/incu6us/goimports-reviser/v3@latest && go install github.com/fatih/gomodifytags@latest && npm i -g live-server
```

### 8. Setup your `Git` environment

- For `gh`, run `gh auth login` and follow `HTTPS browser` instruction to setup `GitHub CLI`

### 9. Run `./git-clone-all $org_name` on `~/dev/personal` for cloning all of your repos

```bash
org_name=lavantien && mkdir -p ~/dev/personal && cp ~/git-clone-all.sh ~/dev/personal/ && cd ~/dev/personal && ./git-clone-all.sh $org_name && cd ~
```

- Rerun the script to sync with remote, replace `org_name` with your GitHub username or organization.

### 10. Install `Iosevka Nerd Font` (replace version `v3.2.1` with whatever latest)

```bash
cd ~/Downloads && wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Iosevka.zip && mkdir Iosevka && unzip Iosevka.zip -d Iosevka && cd Iosevka && sudo mkdir -p /usr/share/fonts/truetype/iosevka-nerd-font && sudo cp *.ttf /usr/share/fonts/truetype/iosevka-nerd-font/ && cd .. && rm -r Iosevka Iosevka.zip && cd ~ && sudo fc-cache -f -v
```

### 11. Install `wezterm`

```bash
brew tap wez/wezterm-linuxbrew && brew install wezterm
```

### 12. Install `GRPC`, `GRPC-Web`, and `protoc-gen`

```bash
brew install grpc protoc-gen-grpc-web && go install google.golang.org/protobuf/cmd/protoc-gen-go@latest && go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
```

### 14. Install `Qemu KVM`

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo && kvm-ok
```

```bash
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils -y
```

### 15. Install `VSCode` and extensions

```bash
cd ~/Downloads && wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg && sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg && sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list' && rm -f packages.microsoft.gpg && cd ~ && sudo apt update && sudo apt install code -y
```

Open VSCode, sync, and install extensions.

### 16. Install `Kreya` and `DBbGate`

```bash
sudo snap install kreya dbgate
```

### 17. Install `FlatHub`, `Docker Compose`, `Podman Desktop`, `Anki`, `Signal`, and `FreeCAD`

```bash
sudo apt install flatpak -y && sudo apt install gnome-software-plugin-flatpak -y && flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

```bash
sudo install -m 0755 -d /etc/apt/keyrings && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg && sudo chmod a+r /etc/apt/keyrings/docker.gpg && echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && sudo apt update && sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
```

```bash
sudo usermod -aG docker $USER && newgrp docker
```

`reboot`

```bash
docker run hello-world && flatpak install flathub io.podman_desktop.PodmanDesktop -y && flatpak install flathub net.ankiweb.Anki org.signal.Signal org.freecadweb.FreeCAD -y
```

### 18. Install `kubectl`, and `minikube`, change `1.30` to whatever is the latest version

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg && echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list && sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list && sudo apt update && sudo apt install kubectl -y
```

```bash
cd ~/Downloads && curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb && sudo dpkg -i minikube_latest_amd64.deb && rm minikube_latest_amd64.deb && cd ~
```

```bash
minikube config set driver docker && minikube start && minikube addons enable metrics-server
```

```bash
❗  These changes will take effect upon a minikube delete and then a minikube start
🌟  The 'metrics-server' addon is enabled
```

```bash
minikube stop
```

### 19. Install `Graphics Drivers` and `Vulkan`, and `Sensors`

- If you have a `NVIDIA GPU`, replace `550` with whatever is the latest driver version as listed [here](https://launchpad.net/~graphics-drivers/+archive/ubuntu/ppa)

```bash
sudo add-apt-repository ppa:graphics-drivers/ppa -y && sudo dpkg --add-architecture i386 && sudo apt update && sudo apt install nvidia-driver-550 libvulkan1 libvulkan1:i386 libgl-dev libgl-dev:i386 -y
```

- Or with built-in NVIDIA driver:

```bash
sudo apt dpkg --add-architecture i386 && sudo apt update && sudo apt install libvulkan1:i386 libgl-dev:i386 
```

- and to `underwatt` your GPU: <https://www.pugetsystems.com/labs/hpc/quad-rtx3090-gpu-power-limiting-with-systemd-and-nvidia-smi-1983/>
- and to be able to save `nvidia-settings` config:

```bash
sudo nvidia-xconfig
```

```bash
sudo chmod +x /usr/share/screen-resolution-extra/nvidia-polkit
```

```bash
sudo nvidia-settings
```

- If not, just install `Vulkan`

```bash
sudo dpkg --add-architecture i386 && sudo apt update && sudo apt install libvulkan1 libvulkan1:i386 -y
```

- and the latest `AMD/Intel` drivers

```bash
sudo add-apt-repository ppa:kisak/kisak-mesa -y && sudo dpkg --add-architecture i386 && sudo apt update && sudo apt upgrade && sudo apt install libgl1-mesa-dri:i386 mesa-vulkan-drivers mesa-vulkan-drivers:i386 libgl-dev libgl-dev:i386 -y && sudo apt autoremove -y
```

`reboot`

```bash
sudo apt update && sudo apt install lm-sensors psensor libxcb-cursor0 -y && sudo sensors-detect
```

### 20. (Optional) Install `Wine`, `Lutris`, `MangoHud`, and `GOverlay`

```bash
sudo mkdir -pm755 /etc/apt/keyrings && sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/lunar/winehq-lunar.sources && sudo apt update && sudo apt install --install-recommends winehq-devel -y
```

- replace `0.5.17` with whatever is the latest

```bash
sudo apt install cabextract fluid-soundfont-gm fluid-soundfont-gs libmspack0 mesa-utils mesa-utils-bin p7zip python3-bs4 python3-html5lib python3-lxml python3-setproctitle python3-soupsieve python3-webencodings p7zip-full python3-genshi doc-base -y && cd ~/Downloads && wget https://github.com/lutris/lutris/releases/download/v0.5.13/lutris_0.5.13_all.deb && sudo dpkg -i lutris_0.5.17_all.deb && rm lutris_0.5.17_all.deb && cd ~
```

```bash
lutris
```

- Click the `gear button` next to `Wine` -> tick `Advanced` -> `System options` -> `Command prefix` -> `mangohud` -> `Save` -> exit Lutris
- For `Steam` games, set launch options: `mangohud %command%`
- Install `MangoHud` manually by building from source: [here](https://github.com/flightlessmango/MangoHud?tab=readme-ov-file#installation---build-from-source)

```bash
pip3 install mako && sudo apt install meson glslang-tools glslang-dev libxnvctrl-dev libdbus-1-dev goverlay -y
```

### 21. Install `LibreOffice`, `OBS`, `Gimp`, `Inkscape`, `Krita`, `Blender`, `Audacity`, `Kdenlive`, and `Avidemux`

```bash
sudo add-apt-repository ppa:obsproject/obs-studio -y && sudo apt update && sudo apt install ffmpeg obs-studio -y
```

- Then run `OBS`, setup proper resolution, framerate, encoder, and default whole screen scene

```bash
flatpak install flathub org.libreoffice.LibreOffice org.gimp.GIMP org.inkscape.Inkscape org.kde.krita org.blender.Blender org.audacityteam.Audacity org.avidemux.Avidemux
```

### 22. (Optional) `Helix`

```bash
brew install helix
```

### 23. (Optional) Install `Steam` (and optionally `Dota 2`, `Grim Dawn`, `Battlenet`, and `StarCraft 2`)

```bash
cd ~/Downloads && wget https://repo.steampowered.com/steam/archive/precise/steam_latest.deb && sudo dpkg -i steam_latest.deb && rm steam_latest.deb && cd ~
```

- Run `Steam`, login, enable `Shader Pre-Caching` and `SteamPlay`, restart `Steam`
- (Install `Dota 2` to test native `Vulkan`, `Grim Dawn` to test `Proton`, also `gd rainbow filter` is a must-have loot filter for `Grim Dawn`
- Install `Battlenet` by searching for `script` inside `Lutris`, do as instructed, then relaunch `Battlenet`, install `Diablo 2 Ressurrected`
- Run `Diablo 2 Resurrected` to check for stability and if `Fsync/Gsync` is working properly)

```bash
nvidia-smi
```

- Enable `Gsync/Fsync` inside `nvidia-settings`

</details>

## Development Toolchains

<details>
  <summary>expand</summary>

- [**NGINX**](https://nginx.org/en/docs/beginners_guide.html)

```bash
brew install nginx
```

<details>
	<summary>`NGINX` config</summary>

```nginx
worker_processes 1;

error_log /home/savaka/go/src/github.com/lavantien/go-laptop-booking/log/nginx/error.log;

events {
	worker_connections 10;
}

http {
	access_log /home/savaka/go/src/github.com/lavantien/go-laptop-booking/log/nginx/access.log;

	upstream auth_services {
		server 0.0.0.0:50051;
	}

	upstream laptop_services {
		server 0.0.0.0:50052;
	}

	server {
		listen 8080 ssl http2;

		# Mutual TLS between gRPC client and NGINX
		ssl_certificate cert/server-cert.pem;
		ssl_certificate_key cert/server-key.pem;

		ssl_client_certificate cert/ca-cert.pem;
		ssl_verify_client on;

		location /pb.AuthService {
			grpc_pass grpcs://auth_services;

			# Mutual TLS between NGINX and gRPC server
			grpc_ssl_certificate cert/server-cert.pem;
			grpc_ssl_certificate_key cert/server-key.pem;
		}

		location /pb.LaptopService {
			grpc_pass grpcs://laptop_services;

			# Mutual TLS between NGINX and gRPC server
			grpc_ssl_certificate cert/server-cert.pem;
			grpc_ssl_certificate_key cert/server-key.pem;
		}
	}
}

```

</details>

- [**GRPC Gateway**](https://github.com/grpc-ecosystem/grpc-gateway)

```bash
go install \
    github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway@latest \
    github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2@latest \
    google.golang.org/protobuf/cmd/protoc-gen-go@latest \
    google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
```

- [**Evan CLI**](https://github.com/ktr0731/evans)

```bash
go install github.com/ktr0731/evans@latest
```

- [**GoTestSum**](https://github.com/gotestyourself/gotestsum)

```bash
go install gotest.tools/gotestsum@latest
```

- [**Golang-Migrate**](https://github.com/golang-migrate/migrate/tree/master/cmd/migrate):

```bash
go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest && go install -tags 'mongodb' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
```

- [**SQLc**](https://docs.sqlc.dev/en/latest/overview/install.html):

```bash
go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest
```

- [**GoMock**](https://github.com/golang/mock):

```bash
go install github.com/golang/mock/mockgen@latest
```

- [**TestContainers**](https://testcontainers.com/):

```bash
go get github.com/jackc/pgx/v5 && go get github.com/testcontainers/testcontainers-go && go get github.com/testcontainers/testcontainers-go/modules/postgres && go get github.com/stretchr/testify
```

- [**Viper**](https://github.com/spf13/viper):

```bash
go get -u https://github.com/spf13/viper@latest
```

- [**Gin**](https://github.com/gin-gonic/gin#installation):

```bash
go get -u github.com/gin-gonic/gin && go install github.com/gin-gonic/gin@latest
```

- [**Paseto**](https://github.com/o1egl/paseto):

```bash
go get -u github.com/o1egl/paseto
```

- [**JWT**](https://github.com/golang-jwt/jwt):

```bash
go get -u https://github.com/golang-jwt/jwt
```

- [**Swagger Editor**](https://editor.swagger.io/)

- [**Coverage Badge**](https://eremeev.ca/posts/golang-test-coverage-github-action/)

</details>

## Auto-Update All and Healthcheck

```bash
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && rustup update && brew upgrade && flatpak update
```

<details>
  <summary>common commands</summary>

```bash
docker rm $(docker ps -a -q --filter "ancestor=${IMG_ID}")
```

```bash
gh repo list ${REPO_NAME} --limit 1000 | while read -r repo _; do
  gh repo clone "$repo" "$repo" -- -q 2>/dev/null || (
    cd "$repo" || exit
    git checkout -q main 2>/dev/null || true
    git checkout -q master 2>/dev/null || true
    git pull -q
  )
done
```

```vim
:'<,'>norm! @a
```

</details>

<details>
  <summary>docker, k8s, maven</summary>

### Docker

```bash
docker version && docker run hello-world
```

```bash
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

### KubeCTL and MiniKube

```bash
minikube start && minikube addons enable metrics-server && kubectl get po -A && minikube dashboard
```

```bash
NAMESPACE     NAME                               READY   STATUS    RESTARTS        AGE
kube-system   coredns-787d4945fb-s2w75           1/1     Running   0               2m52s
kube-system   etcd-minikube                      1/1     Running   0               3m6s
kube-system   kube-apiserver-minikube            1/1     Running   0               3m6s
kube-system   kube-controller-manager-minikube   1/1     Running   0               3m7s
kube-system   kube-proxy-fl25q                   1/1     Running   0               2m52s
kube-system   kube-scheduler-minikube            1/1     Running   0               3m6s
kube-system   storage-provisioner                1/1     Running   1 (2m22s ago)   3m5s
```

```bash
minikube stop
```

### Test Docker Maven Workflow

```bash
cd ~/dev/personal/lavantien/springboot-restapi && dcu -d
```

```bash
dp && de postgres bash
```

```bash
psql -U postgres
```

```bash
create database player;
```

`<C-d> <C-d>`

```bash
mvn install
```

```bash
mvn test
```

```bash
[INFO] Tests run: 1, Failures: 0, Errors: 0, Skipped: 0, Time elapsed: 3.162 s - in com.lavantien.restapi.RestapiApplicationTests
[INFO]
[INFO] Results:
[INFO]
[INFO] Tests run: 2, Failures: 0, Errors: 0, Skipped: 0
[INFO]
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  6.718 s
[INFO] Finished at: 2023-06-05T10:12:21+07:00
[INFO] ------------------------------------------------------------------------
```

```bash
mvn spring-boot:run
```

- Open browser at `http://localhost:8081/api/players`

`<C-c>`

```bash
dcd && cd ~
```

### Helix LSP

```bash
hx --health
```

</details>

## Neovim Cross-Platform Full IDE Minimal Setup From Scratch

### Install

- Install Git, Neovim, GCC/LLVM-Clang, Go, NodeJS, Python3, Rust, Lua, Java, SQLite, Docker, K8s, OpenTofu
- Neovim Deps:

```bash
npm i -g neovim && pip3 install neovim
```

- If you're on Windows you need to set the `HOME` environment variable to `C:\Users\<your account name>`
- Run `nvim` the first time and wait for it to auto initialize plugins, then press `S` to sync packages
- Run `:MasonUpdate` to install all registries, then `:Mason` and press `U` if there's any update

### Features

- Fully support Go, Rust, Lua, JavaScript/TypeScript, Python, Java, HTML/CSS, LaTeX, Markdown and DevOps techs
- Intellisense, Snippets, Debugging, Code Objects, Pin Headers, Display Statuses, Disect Token Tree, Fuzzy Picker
- Surround Motions, Improved Floating UIs, Inline Diagnostics, Cute Statusbar, Multifiles Jumper, Refactoring
- Rainbow Indentation Guides, Smart Help, Disect Undo Tree, Git Integration, SQL/NoSQL Client, File Handler
- Pre-setup 3 themes - `Gruvbox`, `Tokyo Night`, `Pine Rose` - you can just uncomment any one of them

### Key Bindings

- In Neovim Normal Mode, hit `:nmap` to see the list of all bindings
- To see bindings of a certain key, hit `:nmap <leader>`
- Or you can just use Telescope to do the deed `<leader>vk`, in this case, holding space and pressing `vk`

### Mason Built-in Packages to `:MasonInstall `

- All language `servers` and `treesitters` are pre-installed when you first initialize Neovim
- All 50 Packages:

```text
gopls delve staticcheck gotests golangci-lint golangci-lint-langserver go-debug-adapter gomodifytags impl goimports-reviser rust-analyzer codelldb lua-language-server stylua luacheck clangd clang-format jdtls java-test java-debug-adapter google-java-format typescript-language-server prettier js-debug-adapter chrome-debug-adapter html-lsp css-lsp tailwindcss-language-server pyright debugpy flake8 blue yaml-language-server yamllint yamlfmt buf-language-server buf terraform-ls sqlls sqlfluff sql-formatter tflint tfsec marksman ltex-ls vale proselint markdown-toc cbfmt nginx-language-server
```

- Specific Languages:

<details>
	<summary>go, rust, lua, c/c++, java, javascript/typescript, html, css, python, yaml, protobuf, sql, terraform, markdown, nginx</summary>

- Go:

```text
gopls delve staticcheck gotests golangci-lint golangci-lint-langserver go-debug-adapter gomodifytags impl goimports-reviser
```

- Rust:

```text
rust-analyzer codelldb
```

- Lua:

```text
lua-language-server stylua luacheck
```

- C/C++:

```text
clangd clang-format
```

- Java:

```text
jdtls java-test java-debug-adapter google-java-format
```

- JavaScript/TypeScript:

```text
typescript-language-server prettier js-debug-adapter chrome-debug-adapter
```

- HTML:

```text
html-lsp
```

- CSS:

```text
css-lsp tailwindcss-language-server
```

- Python:

```text
pyright debugpy flake8 blue
```

- YAML:

```text
yaml-language-server yamllint yamlfmt
```

- Protobuf:

```text
buf-language-server buf
```

- SQL:

```text
sqlls sqlfluff sql-formatter
```

- Terraform:

```text
terraform-ls tflint tfsec
```

- Markdown:

```text
marksman ltex-ls vale proselint markdown-toc cbfmt
```

- Nginx:

```text
nginx-language-server
```

</details>

- Make sure to run `$ nvim +che` to ensure all dependencies are installed

### Plugins List

<details>
	<summary>expand</summary>

- nvim-treesitter/nvim-treesitter
- nvim-treesitter/nvim-treesitter-context
- nvim-treesitter/playground
- neovim/nvim-lspconfig
- hrsh7th/nvim-cmp
- hrsh7th/cmp-nvim-lsp
- L3MON4D3/LuaSnip
- onsails/lspkind.nvim
- williamboman/mason.nvim
- williamboman/mason-lspconfig.nvim
- VonHeikemen/lsp-zero.nvim
- mfussenegger/nvim-dap
- jay-babu/mason-nvim-dap.nvim
- leoluz/nvim-dap-go
- rcarriga/nvim-dap-ui
- nvim-neotest/nvim-nio
- folke/neodev.nvim
- theHamsta/nvim-dap-virtual-text
- j-hui/fidget.nvim
- nvim-telescope/telescope.nvim
- kylechui/nvim-surround
- stevearc/dressing.nvim
- ellisonleao/gruvbox.nvim
- (folke/tokyonight.nvim)
- (rose-pine/neovim)
- folke/trouble.nvim
- nvim-lualine/lualine.nvim
- theprimeagen/harpoon
- theprimeagen/refactoring.nvim
- mbbill/undotree
- tpope/vim-fugitive
- lewis6991/gitsigns.nvim
- lervag/vimtex
- MeanderingProgrammer/markdown.nvim
- tpope/vim-dadbod
- stevearc/oil.nvim
- nvim-tree/nvim-web-devicons

</details>

### References

<details>
  <summary>expand</summary>

- 0 to LSP: <https://youtu.be/w7i4amO_zaE>
- Zero to IDE: <https://youtu.be/N93cTbtLCIM>
- Effective Neovim: Instant IDE: <https://youtu.be/stqUbv-5u2s>
- The Only Video You Need to Get Started with Neovim: <https://youtu.be/m8C0Cq9Uv9o>
- Kickstart.nvim: <https://github.com/nvim-lua/kickstart.nvim>
- TJDevries/config.nvim: <https://github.com/tjdevries/config.nvim>
- Debugging in Neovim: <https://youtu.be/0moS8UHupGc>
- Simple neovim debugging setup: <https://youtu.be/lyNfnI-B640>
- My neovim autocomplete setup: explained: <https://youtu.be/22mrSjknDHI>
- Oil.nvim - My Favorite Addition to my Neovim Config: <https://youtu.be/218PFRsvu2o>
- Vim Dadbod - My Favorite SQL Plugin: <https://youtu.be/ALGBuFLzDSA>

</details>

![neovim-demo](/assets/neovim-demo.png)

## Handle Corrupted Providers

<details>
  <summary>expand</summary>

### Fix borked MKV file (remux to rebuild the metadata)

```bash
ffmpeg -i "<interrrupted mkv>" -c copy "fixed.mkv"
```

### Google Cloud CLI (broken installation & missing python2 dep)

```bash
echo "deb [signed-by=/etc/apt/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor | sudo tee /etc/apt/keyrings/cloud.google.gpg > /dev/null
sudo apt update && sudo apt install kubectl google-cloud-cli
gcloud init

wget https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tgz
tar xzf Python-2.7.18.tgz
cd Python-2.7.18
./configure --enable-optimizations
sudo make altinstall
python2.7 -V
sudo ln -sfn '/usr/local/bin/python2.7' '/usr/bin/python2'
python2 -V
sudo rm /usr/local/lib/pkgconfig/python-2.7.pc /usr/local/lib/libpython2.7.a
sudo rm -rf /usr/local/include/python2.7

sudo apt install google-cloud-cli-app-engine-go google-cloud-cli-app-engine-grpc google-cloud-cli-cloud-build-local google-cloud-cli-firestore-emulator google-cloud-cli-minikube google-cloud-cli-tests
# still failed due to python2.7
````

</details>
