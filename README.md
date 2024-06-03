# A robust Dotfiles for Developer - Ubuntu & Neovim - Battery Included

- Quality Assurance: **100%**; Demonstration video: <https://youtu.be/a28SZdUkpKw>
- Supported: **AMD** & **Intel** (Wayland), **NVIDIA** (auto X11), **Windows** (Neovim)
- Turn off `Secure Boot` in your `BIOS` for a smooth installation process
- Install with `Minimal setup` and **LVM full disk encryption** to avoid the feds raiding your machine
- If you're floating on cash make sure to always use Mullvad VPN and Tor Network/Snowflake
- And if you're broke, use the free WARP and practice good OpSec hygiene
- A modern software engineering free quality resources library: [gist](https://gist.github.com/lavantien/dc730dad7d7e8157000ddae845eddfd7)

## Step-by-Step Standardized Setup for a Fresh Ubuntu 24.04 LTS

<details>
  <summary>expand</summary>

### 0. Install `Firefox`, `Flatpak`, `OBS`; disable Wireless Powersaving and Files Open Limit; increase swap size

- Open `Firefox`, sync your profile, and go to <https://github.com/lavantien/dotfiles/blob/main/README.md> to continue the steps
- Go to uBlock settings and enable all filters. Recommended Firefox Extensions:

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
```

- Edit Ubuntu repo source file like this and replace `us.` with yours:

```bash
sudo vi /etc/apt/sources.list.d/ubuntu.sources
```

```config
Types: deb deb-src
URIs: http://us.archive.ubuntu.com/ubuntu/
Suites: noble noble-updates noble-backports noble-proposed
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb deb-src
URIs: http://security.ubuntu.com/ubuntu/
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
```

- Go to `Software & Updates` and enable `main`, `universe`, and `restricted`

```bash
sudo apt update && sudo apt upgrade -y
```

```bash
sudo apt install flatpak -y && sudo apt install gnome-software-plugin-flatpak -y && flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

```bash
sudo flatpak install com.obsproject.Studio && sudo apt install ffmpeg -y
```

- Then `reboot`, and run `OBS`, setup proper resolution, framerate, encoder, and default whole screen scene

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
# uncomment first
DefaultLimitNOFILE=4096:2097152
```

```bash
sudo vi /etc/systemd/user.conf
```

```conf
# uncomment first
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

- Add this line to the end of your `/etc/fstab`:

```bash
/swapfile swap swap sw 0 0
```

- With encrypted ZFS enable you have to use this insetad: <https://askubuntu.com/a/1198916>
- And with LVM: <https://askubuntu.com/a/1412400>

- Add this line in `/etc/sysfs.conf`:

```bash
mode class/powercap/intel-rapl:0/energy_uj = 0444
```

### 1. Install all necessary `APT` packages

```bash
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt install ubuntu-desktop ca-certificates apt-transport-https ubuntu-dev-tools glibc-source gcc xclip git curl zsh htop vim libfuse2 cpu-checker cmake cmake-format ninja-build libjsoncpp-dev uuid-dev zlib1g-dev libssl-dev postgresql-all libmariadb-dev libsqlite3-dev libhiredis-dev jq bc xorg-dev libxcursor-dev cloud-init openssh-server ssh-import-id sysfsutils latexmk mupdf python3-pip python-is-python3 -y
```

- When prompted for entering a mirror for `pbuilder` enter this: `http://http.us.debian.org/debian`

### 2. Install `Oh-my-zsh`, then `reboot`

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### 3. Install `Linuxbrew`

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

### 6. Install `rust` and its toolchains

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### 7. Install `gcc`, `gh`, `neovim`, and other necessary `Brew` packages

```bash
brew install gcc gh go lazygit fzf fd ripgrep bat tokei glow neovim hyperfine openjdk ruby lua maven node gopls rust-analyzer jdtls lua-language-server typescript-language-server marksman texlab yaml-language-server bash-language-server opentofu terraform-ls sql-language-server sqlfluff prettier delve vscode-langservers-extracted loc llvm dotenv-linter checkmake luarocks pkg-config mpv macchina cmake-language-server python-lsp-server sql-language-server sql-lint gomodifytags golangci-lint
```

### 8. Setup your `Git` environment

- For `gh`, [`gh-f`](https://github.com/gennaro-tedesco/gh-f), run `gh auth login` and follow `HTTPS browser` instruction to setup `GitHub CLI`

```bash
git config --global http.postBuffer 524288000 && gh extension install gennaro-tedesco/gh-f
```

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
brew install protobuf grpc && go install google.golang.org/protobuf/cmd/protoc-gen-go@latest && go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest && brew install protoc-gen-grpc-web
```

### 13. Install `Qemu KVM`

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo && kvm-ok
```

```bash
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils -y
```

### 14. Install `VSCode` and extensions

```bash
cd ~/Downloads && wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg && sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg && sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list' && rm -f packages.microsoft.gpg && cd ~ && sudo apt update && sudo apt install code -y
```

Open VSCode, sync, and install extensions.

### 15. Install `GRPCUI`, `DBbGate`, `Anki`, and `Signal`

- Kreya is coming to flatpak soon: <https://github.com/riok/Kreya/issues/64>

```bash
brew install grpcui && flatpak install flathub org.dbgate.DbGate net.ankiweb.Anki org.signal.Signal -y
```

### 16. Install `Docker Compose`, `Podman Desktop` and reboot, then use Wezterm to continue the steps

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
docker run hello-world && flatpak install flathub io.podman_desktop.PodmanDesktop -y
```

### 17. Install `kubectl`, and `minikube`, change `1.30` to whatever is the latest version

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

### 18. Install `Graphics Drivers` and `Vulkan`, and `Sensors`

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

### 19. (Optional) Install `Wine`, `Lutris`, `MangoHud`, and `GOverlay`

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

### 20. Install `LibreOffice`, `Gimp`, `Inkscape`, `Krita`, `Blender`, `Audacity`, `Kdenlive`, and `Avidemux`

- Remove old `LibreOffice` or `snap` packages in the system first

```bash
sudo apt install libreoffice && flatpak install flathub org.gimp.GIMP org.inkscape.Inkscape org.kde.krita org.blender.Blender org.audacityteam.Audacity org.avidemux.Avidemux org.kde.kdenlive
```

### 21. (Optional) `Helix`

```bash
brew install helix && hx --health
```

### 22. (Optional) Install `Steam` and `Aseprite` (and optionally `Dota 2`, `Grim Dawn`, `Battlenet`, and `Diablo 2 Resurrected`)

```bash
sudo apt install steam -y
```

- Run `Steam`, login, enable `Shader Pre-Caching` and `SteamPlay`, restart `Steam` and install `Aseprite`
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
sudo systemctl daemon-reload
```

```bash
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && rustup update && brew upgrade && flatpak update -y
```

<details>
  <summary>helpful commands</summary>

```bash
docker rm $(docker ps -a -q --filter "ancestor=${IMG_ID}")
```

```bash
ffmpeg -i input.mkv -filter:v "setpts=PTS/8,fps=32" -an output.mkv
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

- Git, GH CLI, Neovim, GCC/LLVM-Clang, Go, NodeJS, Python3, Rust, Lua, Java, SQLite, Docker, K8s, OpenTf
- Neovim Deps:

```bash
npm i -g neovim && mkdir -p ~/notes
```

- If you're on Windows you need to
  - remove `make install_jsregexp` from `luasnip` build config
  - remove `checkmake`, `luacheck`, `semgrep`, `ansible-lint`, or other packages that don't support Windows from `mason-tools-installer` list
  - set the `HOME` environment variable to `C:\Users\<name>`
  - copy `.config/nvim` directory to `C:\Users\<name>\AppData\Local\`
  - add to `PATH` this value `C:\Users\<name>\AppData\Local\nvim-data\mason\bin`
  - install [sqlite3](https://gist.github.com/zeljic/d8b542788b225b1bcb5fce169ee28c55), rename `sqlite3.dll` to `libsqlite3.dll` and `sqlite3.lib` to `libsqlite3.lib`, and add its location to`PATH`
- Run `nvim` the first time and wait for it to auto initialize plugins, then press `S` to sync packages
- Run `:MasonUpdate` to install all registries, then `:Mason` and press `U` if there's any update
- All language `servers`, `linters`, and `treesitters` are pre-installed when you first initialize Neovim
- Make sure to run `$ nvim +che` to ensure all related dependencies are installed

### Features

- Fully support lua, go, javascript/typescript & vue, html/htmx & css/tailwind, python, c/cpp, rust, java, assembly, markdown, latex & typos, bash, make & cmake, json, yaml, toml, sql, protobuf, graphql, docker/compose, ci/cd, kubernetes/helm, ansible, opentofu
- Intellisense, Code Actions, Snippets, Debugging, Hints, Code Objects, Pin Headers, Display Statuses, Token Tree, Fuzzy Picker
- Surround, Autotag, Improved Floating UIs, Inline Diagnostics, Toggle Term, Inline Eval, Statusbar, Multifiles Jumper, Refactoring, Clues
- Smart Folds, Autolint, Indentation Guides, Smart Help, Undo Tree, Git Integration, SQL/NoSQL Client, File Explorer, Cellular Automaton
- Optimized Keymaps, Schemas Store, Highlight Patterns, Pre-setup 3 themes - `Gruvbox`, `Tokyo Night`, `Pine Rose`

### Key Bindings

- Key clue support, just hit any key and a popup will appear to guide you
- Or via Telescope `<leader>vk`, in this case, hit space and pressing `vk`
- In Neovim Normal Mode, hit `:nmap` to see the list of all bindings
- Check `~/.config/nvim/lua/config/remap.lua` for detailed information

### Plugins List

<details>
	<summary>Loaded (55)</summary>

- cellular-automaton.nvim 0.26ms  start
- cmp-buffer 0.11ms  nvim-cmp
- cmp-nvim-lsp 0.13ms  nvim-cmp
- cmp-nvim-lsp-signature-help 0.1ms  nvim-cmp
- cmp-path 0.11ms  nvim-cmp
- cmp_luasnip 0.09ms  nvim-cmp
- dressing.nvim 0.91ms  start
- fidget.nvim 1.6ms  lsp-zero.nvim
- gitsigns.nvim 0.08ms  start
- gruvbox.nvim 3.17ms  start
- harpoon 7.64ms  start
- indent-blankline.nvim 1.14ms  start
- lazy.nvim 5.39ms  init.lua
- lsp-zero.nvim 85.19ms  start
- lspkind.nvim 0.1ms  nvim-cmp
- lualine.nvim 3.96ms  start
- LuaSnip 4.12ms  nvim-cmp
- mason-lspconfig.nvim 0.07ms  lsp-zero.nvim
- mason-null-ls.nvim 0.14ms  lsp-zero.nvim
- mason-nvim-dap.nvim 0.15ms  lsp-zero.nvim
- mason-tool-installer.nvim 2.12ms  lsp-zero.nvim
- mason.nvim 1.26ms  lsp-zero.nvim
- mini.nvim 2.66ms  start
- neodev.nvim 2.48ms  lsp-zero.nvim
- none-ls.nvim 0.14ms  lsp-zero.nvim
- nvim-cmp 5.98ms  start
- nvim-dap 0.29ms  lsp-zero.nvim
- nvim-dap-go 0.15ms  lsp-zero.nvim
- nvim-dap-ui 0.19ms  lsp-zero.nvim
- nvim-dap-virtual-text 0.33ms  lsp-zero.nvim
- nvim-lspconfig 1.59ms  lsp-zero.nvim
- nvim-nio 0.31ms  lsp-zero.nvim
- nvim-treesitter 7.02ms  render-markdown
- nvim-treesitter-context 0.68ms  start
- nvim-ts-autotag 2.04ms  nvim-treesitter
- nvim-ufo 16.01ms  start
- nvim-web-devicons 0.26ms  oil.nvim
- oil.nvim 1.73ms  start
- playground 1.72ms  start
- plenary.nvim 0.25ms  harpoon
- promise-async 0.3ms  nvim-ufo
- refactoring.nvim 4.58ms  start
- render-markdown 13.86ms  start
- SchemaStore.nvim 0.06ms  lsp-zero.nvim
- smart-open.nvim 11.81ms  start
- sqlite.lua 0.34ms  smart-open.nvim
- telescope-fzf-native.nvim 0.27ms  smart-open.nvim
- telescope-fzy-native.nvim 0.28ms  smart-open.nvim
- telescope.nvim 0.45ms  harpoon
- trouble.nvim 1.59ms  start
- undotree 0.36ms  start
- vim-dadbod 0.26ms  start
- vim-dadbod-completion 0.15ms  start
- vim-dadbod-ui 0.27ms  start
- vimtex 0.42ms  start

</details>

### Languages Packages List

<details>
	<summary>Installed (69)</summary>

```lua
-- lua
"lua_ls",
"stylua",
"luacheck",

-- go
"gopls",
"gotests",
"impl",
"gomodifytags",
"goimports-reviser",
"staticcheck",
"semgrep",
"golangci_lint_ls",
"golangci_lint",
"delve",
"go-debug-adapter",

-- javascript/typescript & vue
"tsserver",
"eslint",
"volar",
"prettier",
"js-debug-adapter",
"firefox-debug-adapter",

-- html/htmx & css/tailwind
"html",
"emmet_language_server",
"htmx",
"cssls",
"tailwindcss",

-- python
"pyright",
"blue",
"flake8",
"debugpy",

-- c/cpp
"clangd",
"clang-format",
"cpptools",

-- rust
"rust_analyzer",
"codelldb",

-- java
"jdtls",
"java-test",
"google-java-format",
"java-debug-adapter",

-- assembly
"asm-lsp",
"asmfmt",

-- markdown
"marksman",
"cbfmt",

-- latex & typos
"texlab",
"typos_lsp",

-- bash
"bashls",
"shellcheck",
"shfmt",
"bash-debug-adapter",

-- make & cmake
"checkmake",
"neocmake",
"cmakelint",

-- json
jsonls = {
    settings = {
        json = {
            schemas = require("schemastore").json.schemas(),
            validate = { enable = true },
        },
    },
},

-- yaml
yamlls = {
    settings = {
        yaml = {
            schemaStore = {
                enable = false,
                url = "",
            },
            schemas = require("schemastore").yaml.schemas(),
        },
    },
},
"yamlfmt",
"yamllint",

-- toml
"taplo",

-- sql
"sqlls",
"sqlfluff",
"sql-formatter",

-- protobuf
"bufls",
"buf",
"protolint",

-- graphql
"graphql",

-- docker/compose
"dockerls",
"docker_compose_language_service",

-- ci/cd
"actionlint",

-- kubernetes/helm
"helm_ls",

-- ansible
"ansiblels",
"ansible-lint",

-- opentofu
"terraformls",
"tflint",
```

</details>

### References

<details>
  <summary>expand</summary>

- 0 to LSP: <https://youtu.be/w7i4amO_zaE>
- Zero to IDE: <https://youtu.be/N93cTbtLCIM>
- Effective Neovim: Instant IDE: <https://youtu.be/stqUbv-5u2s>
- The Only Video You Need to Get Started with Neovim: <https://youtu.be/m8C0Cq9Uv9o>
- Kickstart.nvim: <https://github.com/nvim-lua/kickstart.nvim>
- ThePrimeagen/init.lua: <https://github.com/ThePrimeagen/init.lua>
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
ffmpeg -i "<interrupted mkv>" -c copy "fixed.mkv"
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
```

</details>
