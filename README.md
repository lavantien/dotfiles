# A robust Dotfiles for Developer - Ubuntu & Neovim - Battery Included

- Quality Assurance: **100%**; Demonstration video: <https://youtu.be/a28SZdUkpKw>
- Fully Supported: **AMD** & **Intel** (Wayland), **NVIDIA** (auto X11), **Windows** (Neovim, Wezterm, Dev Env Setup)
- Turn off `Secure Boot` in your `BIOS` for a smooth installation process
- Install with `Minimal setup` and **LVM full disk encryption** to avoid the feds raiding your machine
- If you're floating on cash make sure to always use Mullvad VPN and Tor Network/Snowflake
- And if you're broke, use the free WARP and practice good OpSec hygiene
- A modern software engineering free quality resources library: [gist](https://gist.github.com/lavantien/dc730dad7d7e8157000ddae845eddfd7)

## Step-by-Step Standardized Setup for a Fresh Ubuntu/Kubuntu 24.04 LTS

<details>
  <summary>expand</summary>

### 0. Install `Firefox`, `Flatpak`, `OBS`; disable Wireless Powersaving and Files Open Limit; increase swap size

```bash
sudo snap remove firefox && sudo apt remove firefox
```

```bash
sudo install -d -m 0755 /etc/apt/keyrings
```

```bash
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
```

```bash
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null
```

```bash
echo '
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000

Package: firefox*
Pin: release o=Ubuntu
Pin-Priority: -1' | sudo tee /etc/apt/preferences.d/mozilla
```

```bash
sudo apt update && sudo apt install firefox
```

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
ulimit -n && mkdir -p ~/.local/bin
```

```bash
sudo swapoff -a && sudo dd if=/dev/zero of=/swapfile bs=1G count=16 && sudo chmod 0600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile && grep Swap /proc/meminfo
```

- Add this line to the end of your `/etc/fstab`:

```bash
/swapfile swap swap sw 0 0
```

- With encrypted ZFS enable you have to use this instead: <https://askubuntu.com/a/1198916>
- And with LVM: <https://askubuntu.com/a/1412400>

- Add this line in `/etc/sysfs.conf`:

```bash
mode class/powercap/intel-rapl:0/energy_uj = 0444
```

- To switch to KDE, run this then reboot:

```bash
sudo apt install kubuntu-desktop
```

### 1. Install all necessary `APT` packages

```bash
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt install ubuntu-desktop ca-certificates apt-transport-https ubuntu-dev-tools glibc-source gcc xclip git curl zsh htop vim mpv libfuse2 cpu-checker cmake cmake-format ninja-build libjsoncpp-dev uuid-dev zlib1g-dev libssl-dev postgresql-all libmariadb-dev libsqlite3-dev libhiredis-dev jq bc xorg-dev libxcursor-dev cloud-init openssh-server ssh-import-id sysfsutils latexmk mupdf python3-pip python-is-python3 -y
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

```bash
rustup toolchain install nightly && cargo +nightly install cargo-update --force --features vendored-libgit2
```

### 7. Install `gcc`, `gh`, `neovim`, and other necessary `Brew` packages

```bash
brew install coreutils gcc gh go lazygit lazydocker fzf fd ripgrep bat tokei glow ripgrep-all dua-cli pandoc texlive poppler ffmpeg eza navi broot just exiftool fdupes procs rsync watchman neovim openjdk ruby coursier lua maven node gopls rust-analyzer jdtls lua-language-server typescript-language-server marksman texlab yaml-language-server bash-language-server opentofu terraform-ls sql-language-server sqlfluff prettier delve vscode-langservers-extracted loc llvm dotenv-linter checkmake luarocks pkg-config macchina cmake-language-server python-lsp-server sql-language-server sql-lint gomodifytags golangci-lint hyperfine zoxide btop sccache vifm difftastic gcc@11 ocaml opam zig zls asdf roswell dotnet
```

```bash
go install github.com/Gelio/go-global-update@latest && sudo apt install openjfx
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

Follow this: <https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-using-native-package-management>

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

### 20. Install `Android Studio SDK`, `LibreOffice`, `Gimp`, `Inkscape`, `Krita`, `Blender`, `Audacity`, `Kdenlive`, and `Avidemux`

- After install `Android Studio`, run it and install the [Android SDK](https://reactnative.dev/docs/set-up-your-environment).

```bash
flatpak install flathub com.google.AndroidStudio
```

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
- Install `Battlenet` by searching for `script` inside `Lutris`, do as instructed, then relaunch `Battlenet`, install `Diablo 2 Resurrected`
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
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y \
&& sudo snap refresh \
&& rustup update && cargo +nightly install-update -a \
&& npm -g update && go-global-update \
&& brew upgrade \
&& flatpak update -y
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

- Git, GH CLI, Neovim, GCC/LLVM-Clang, Go, NodeJS, Python3, Rust, Lua, Android/React Native, Java, Coursier/Scala, Ocaml, Zig, Lisp, C#/Dotnet, SQLite, Docker, K8s, OpenTf
- Neovim Deps (on first run let them install don't close Neovim midway, `:Mason` to see progress); then [integrate ripgrep-all and fzf](https://github.com/phiresky/ripgrep-all/wiki/fzf-Integration), put the file in `~/.local/bin` and add the folder to `PATH`
- Local LLMs via [LM Studio](https://lmstudio.ai/) (16+ gb ram, referably a RTX card).

```bash
mkdir -p ~/notes \
&& cargo install sccache && cargo install coreutils \
&& npm i -g neovim && cargo install tree-sitter-cli \
&& ros install quicklisp && opam init && opam install ocaml-lsp-server odoc ocamlformat utop \
&& dotnet dev-certs https --trust && dotnet tool install --global csharp-ls && dotnet tool install --global csharpier
```

<details>
    <summary>If you're on Windows you need to (expand)</summary>

- remove `make install_jsregexp` from `luasnip` build config
- remove `checkmake`, `luacheck`, `semgrep`, `ansible-lint`, or other packages that don't support Windows from `mason-tools-installer` list
- set the `HOME` environment variable to `C:\Users\<name>`; create `notes` folder in home
- copy `.config/nvim/` directory to `C:\Users\<name>\AppData\Local\`
- copy from `[init] to [pull]` inside `.gitconfig` to your config file location (`git config --list --show-origin --show-scope`)
- copy `./typos.toml` file to `~/`
- add to `PATH` this value `C:\Users\<name>\AppData\Local\nvim-data\mason\bin`
- set the `RUSTC_WRAPPER` env var to `C:\Users\<name>\.cargo\bin\sccache.exe`
- install [sqlite3](https://gist.github.com/zeljic/d8b542788b225b1bcb5fce169ee28c55), rename `sqlite3.dll` to `libsqlite3.dll` and `sqlite3.lib` to `libsqlite3.lib`, and add its location to`PATH`
- Install `Android Studio`, [Android SDK](https://reactnative.dev/docs/set-up-your-environment), and [coursier/scala](https://www.scala-lang.org/download/)
- Install all packages via [winget](https://winget.run/) if possible, then use `scoop install`, `cargo install`, `go install`, and `choco install` (requires admin shell) in this order
  - `winget source reset --force` in admin shell
  - `winget install Microsoft.VisualStudio.2019.BuildTools --override "--wait --passive --installPath C:\VS --addProductLang En-us --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"`
  - `winget install gsudo TheDocumentFoundation.LibreOffice Git.Git GitHub.cli Docker.DockerDesktop GoLang.Go OpenJS.NodeJS Amazon.Corretto Rustlang.Rustup Diskuv.OCaml zig.zig ajeetdsouza.zoxide wez.wezterm JesseDuffield.lazygit JesseDuffield.Lazydocker`
  - `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` and `Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression`
  - `scoop install btop-lhm roswell`, `ros install quicklisp`, `dkml init --system`
  - `choco install vifm vscode-ruby` on admin terminal
  - `cargo install cargo-update`, `go install github.com/Gelio/go-global-update@latest`
  - `winget install --source winget --exact --id JohnMacFarlane.Pandoc` and [TeX Live](https://www.tug.org/texlive/windows.html).
- Install additional packages yourself if there are something missing, be mindful of adding the `env vars`
- add to global `PATH` value `C:\Program Files\LLVM\bin`
- Create `~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1` (`$profile`) and add these lines to it, then install [ohmyposh](https://ohmyposh.dev/docs/installation/windows):

```powershell
Invoke-Expression (& { (zoxide init powershell | Out-String) })
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\half-life.omp.json" | Invoke-Expression

# aliases
Set-Alias -Name n -Value nvim
Set-Alias -Name vi -Value vim
Set-Alias -Name g -Value git
Set-Alias -Name d -Value docker
Set-Alias -Name lg -Value lazygit
Set-Alias -Name ld -Value lazydocker
Set-Alias -Name df -Value difft
Set-Alias -Name e -Value eza
Set-Alias -Name v -Value vifm
Set-Alias -Name f -Value fzf
Set-Alias -Name r -Value rg
Set-Alias -Name ff -Value ffmpeg
Set-Alias -Name b -Value bat
Set-Alias -Name t -Value tokei
Set-Alias -Name r -Value rg
Set-Alias -Name rs -Value rsync
Set-Alias -Name cu -Value coreutils
Set-Alias -Name j -Value just
Set-Alias -Name h -Value hyperfine
```

```powershell
cargo +nightly install-update -a && npm -g update && go-global-update && winget upgrade --all -u && scoop update
```

- `choco upgrade all -y` (in admin shell) to mass update all packages

</details>

- Run `nvim` the first time and wait for it to auto initialize plugins, then press `S` to sync packages
- Run `:MasonUpdate` to install all registries, then `:Mason` and press `U` if there's any update
- All language `servers`, `linters`, and `treesitters` are pre-installed when you first initialize Neovim
- Make sure to run `$ nvim +che` to ensure all related dependencies are installed

### Features

- Fully support lua, go, javascript/typescript & vue, html/htmx & css/tailwind, python, c/cpp, rust, java, scala, ocaml, zig, lisp, csharp/dotnet, assembly, markdown, latex & typos, bash, make & cmake, json, yaml, toml, sql, protobuf, graphql, docker/compose, ci/cd, kubernetes/helm, ansible, opentofu
- Intellisense, Code Actions, Debugging, Testing, Diff View, Snippets, Hints, Code Objects, Pin Headers, Display Statuses, Token Tree, Fuzzy Picker
- Surround, Autotag, Improved Floating UIs, Toggle Term, Notifications, Inline Diagnostics, Inline Eval, Statusbar, Multifiles Jumper, Refactoring, Clues
- Smart Folds, Autolint, Notes Taking, Indentation Guides, Smart Help, Undo Tree, Git Integration, SQL/NoSQL Client, File Explorer, Cellular Automaton
- Optimized Keymaps, Schemas Store, Highlight Patterns, Pre-setup 3 themes - `Gruvbox`, `Tokyo Night`, `Pine Rose`

### Key Bindings

- Key clue support, just hit any key and a popup will appear to guide you
- Or via Telescope `<leader>vk`; the `<leader>i` group is for quick notes and mini games
- In Neovim Normal Mode, hit `:nmap` to see the list of all bindings
- Check `~/.config/nvim/lua/config/remap.lua` for detailed information

<details>
    <summary>remap.lua</summary>

```lua
--[[ free keybinds: <leader>/, <leader>p, <leader>y, g% ]]

-- global
-- vim.keymap.set("n", "<leader>pv", vim.cmd.Ex, { desc = "Open Netrw file explorer" })
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move text down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move text up" })
vim.keymap.set("n", "J", "mzJ`z", { desc = "Remove newline underneath" })
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Jump down half page and centering" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Jump up half page and centering" })
vim.keymap.set("n", "n", "nzzzv", { desc = "Go to next match and centering" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Go to previous match and centering" })
vim.keymap.set("x", "<A-p>", [["_dP]], { desc = "Paste overwrite without yanking" })
vim.keymap.set({ "n", "v" }, "<A-y>", [["+y]], { desc = "Yank selected to system clipboard" })
vim.keymap.set("n", "<A-S-y>", [["+Y]], { desc = "Yank line to system clipboard" })
vim.keymap.set({ "n", "v" }, "<A-d>", [["_d]], { desc = "Delete selected and yank to system clipboard" })
vim.keymap.set("i", "<C-c>", "<Esc>", { desc = "Escape" })
vim.keymap.set("n", "Q", "<cmd>q<CR>", { desc = "Quit" })
vim.keymap.set("n", "A-S-q", "<cmd>tabclose<CR>", { desc = "Close tab" })
vim.keymap.set("t", "<C-]>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
vim.keymap.set("n", "<leader>gt", "<cmd>split <bar> term<CR>", { desc = "Toggle Terminal" })
vim.keymap.set("n", "<leader>g=", vim.lsp.buf.format, { desc = "Format current file" })
vim.keymap.set("n", "<C-q>", "<cmd>cclose<CR>", { desc = "Close quickfix window" })
vim.keymap.set("n", "<C-k>", "<cmd>cnext<CR>zz", { desc = "Next quickfix item" })
vim.keymap.set("n", "<C-j>", "<cmd>cprev<CR>zz", { desc = "Previous quickfix item" })
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz", { desc = "Next POI location" })
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz", { desc = "Previous POI location" })
vim.keymap.set("t", "<C-q>", "<C-\\><C-n>", { desc = "Escape terminal mode" })
vim.keymap.set("t", "<A-j>", "<C-\\><C-n><C-w>j", { desc = "Jump to bottom pane" })
vim.keymap.set("t", "<A-k>", "<C-\\><C-n><C-w>k", { desc = "Jump to top pane" })
vim.keymap.set("t", "<A-h>", "<C-\\><C-n><C-w>h", { desc = "Jump to left pane" })
vim.keymap.set("t", "<A-l>", "<C-\\><C-n><C-w>l", { desc = "Jump to right pane" })
vim.keymap.set("i", "<A-j>", "<C-\\><C-n><C-w>j", { desc = "Jump to bottom pane" })
vim.keymap.set("i", "<A-k>", "<C-\\><C-n><C-w>k", { desc = "Jump to top pane" })
vim.keymap.set("i", "<A-h>", "<C-\\><C-n><C-w>h", { desc = "Jump to left pane" })
vim.keymap.set("i", "<A-l>", "<C-\\><C-n><C-w>l", { desc = "Jump to right pane" })
vim.keymap.set("n", "<A-j>", "<C-w>j", { desc = "Jump to bottom pane" })
vim.keymap.set("n", "<A-k>", "<C-w>k", { desc = "Jump to top pane" })
vim.keymap.set("n", "<A-h>", "<C-w>h", { desc = "Jump to right pane" })
vim.keymap.set("n", "<A-l>", "<C-w>l", { desc = "Jump to right pane" })
vim.keymap.set("n", "<A-t>", "<C-w>t", { desc = "Jump to top left pane" }) -- and then use 'gt' to switch tabs
vim.keymap.set(
	"n",
	"<leader>s",
	[[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
	{ desc = "Concurrently replace all matching words" }
)
-- vim.keymap.set("n", "<leader>ex", "<cmd>!chmod +x %<CR>", { silent = true })

-- knowledgebase
vim.keymap.set(
	"n",
	"<leader>ii",
	"<cmd>e ~/.config/nvim/lua/plugins/init.lua<CR>",
	{ desc = "Go to plugins init file" }
)
vim.keymap.set("n", "<leader>iq", "<cmd>e ~/notes/quick.md<CR>", { desc = "Go to personal quick note file" })
vim.keymap.set("n", "<leader>ic", "<cmd>e ~/notes/checklist.md<CR>", { desc = "Go personal checklist file" })
vim.keymap.set("n", "<leader>it", "<cmd>e ~/notes/temp.md<CR>", { desc = "Go personal temp text file" })
vim.keymap.set("n", "<leader>ij", "<cmd>e ~/notes/journal.md<CR>", { desc = "Go personal journal file" })
vim.keymap.set("n", "<leader>iw", "<cmd>e ~/notes/wiki.md<CR>", { desc = "Go personal wiki file" })

-- cellularautomaton
vim.keymap.set("n", "<leader>ir", "<cmd>CellularAutomaton make_it_rain<CR>", { desc = "Run Make It Rain" })
vim.keymap.set("n", "<leader>il", "<cmd>CellularAutomaton game_of_life<CR>", { desc = "Run Game of Life" })

-- lsp
--[[
K: Displays hover information about the symbol under the cursor in a floating window. See :help vim.lsp.buf.hover().
gd: Jumps to the definition of the symbol under the cursor. See :help vim.lsp.buf.definition().
gD: Jumps to the declaration of the symbol under the cursor. Some servers don't implement this feature. See :help vim.lsp.buf.declaration().
gi: Lists all the implementations for the symbol under the cursor in the quickfix window. See :help vim.lsp.buf.implementation().
go: Jumps to the definition of the type of the symbol under the cursor. See :help vim.lsp.buf.type_definition().
gr: Lists all the references to the symbol under the cursor in the quickfix window. See :help vim.lsp.buf.references().
gs: Displays signature information about the symbol under the cursor in a floating window. See :help vim.lsp.buf.signature_help(). If a mapping already exists for this key this function is not bound.
<F2>: Renames all references to the symbol under the cursor. See :help vim.lsp.buf.rename().
<F3>: Format code in current buffer. See :help vim.lsp.buf.format().
<F4>: Selects a code action available at the current cursor position. See :help vim.lsp.buf.code_action().
gl: Show diagnostics in a floating window. See :help vim.diagnostic.open_float().
[d: Move to the previous diagnostic in the current buffer. See :help vim.diagnostic.goto_prev().
]d: Move to the next diagnostic. See :help vim.diagnostic.goto_next().
C-g: Workspace Symbol.
C-g: Signature Help in INSERT mode.
<leader>th: Toggle Inline Hints.
C-j: Previous snippet in INSERT mode.
C-k: Next snippet or expand in INSERT mode.
]]

-- telescope
local builtin = require("telescope.builtin")
vim.api.nvim_set_hl(0, "TelescopeNormal", { bg = "none" })
vim.keymap.set("n", "<C-/>", function()
	builtin.grep_string({ search = vim.fn.input("Grep > ") })
end, { desc = "Grep string global via Telescope" })
vim.keymap.set("n", "<C-p>", builtin.find_files, { desc = "Browse files global via Telescope" })
vim.keymap.set("n", "<leader>f", builtin.current_buffer_fuzzy_find, { desc = "Find string local via Telescope" })
vim.keymap.set("n", "<leader>vf", builtin.git_files, { desc = "Find git files global via Telescope" })
vim.keymap.set("n", "<leader>vh", builtin.help_tags, { desc = "Browse help tags via Telescope" })
vim.keymap.set("n", "<leader>vp", builtin.commands, { desc = "Browse commands via Telescope" })
vim.keymap.set("n", "<leader>vk", builtin.keymaps, { desc = "Browse keymaps via Telescope" })
vim.keymap.set("n", "<leader>vq", builtin.quickfix, { desc = "Browse quickfix items local via Telescope" })
vim.keymap.set("n", "<leader>vj", builtin.jumplist, { desc = "Browse jumplist global via Telescope" })
vim.keymap.set("n", "<leader>vm", function()
	require("telescope").extensions.metals.commands()
end, { desc = "Browse Metals LSP commands" })
vim.keymap.set("n", "<leader>ac", builtin.diagnostics, { desc = "Browse diagnostics items local via Telescope" })
vim.keymap.set("n", "<leader>ar", builtin.lsp_references, { desc = "Browse LSP References via Telescope" })
vim.keymap.set("n", "<leader>as", builtin.lsp_document_symbols, { desc = "Browse LSP Document Symbols via Telescope" })
vim.keymap.set(
	"n",
	"<leader>aw",
	builtin.lsp_dynamic_workspace_symbols,
	{ desc = "Browse LSP Dynamic Workspace Symbols global via Telescope" }
)
vim.keymap.set("n", "<leader>ai", builtin.lsp_implementations, { desc = "Browse LSP Implementations via Telescope" })
vim.keymap.set("n", "<leader>ad", builtin.lsp_definitions, { desc = "Browse LSP Definitions via Telescope" })
vim.keymap.set("n", "<leader>at", builtin.lsp_type_definitions, { desc = "Browse LSP Type Definitions via Telescope" })

-- trouble
--[[
<leader>cc: Buffer Diagnostics (Trouble)
<leader>cs: Symbols (Trouble)
<leader>cd: LSP Definitions / references / ... (Trouble)
<leader>ce: Location List (Trouble)
<leader>ca: Quickfix List (Trouble)
]]

-- smartopen
vim.keymap.set("n", "<C-x>", function()
	require("telescope").extensions.smart_open.smart_open({
		cwd_only = true,
	})
end, { noremap = true, silent = true, desc = "Open smart file picker in Telescope" })

-- neotest
local neotest = require("neotest")
vim.keymap.set("n", "<leader>tf", function()
	neotest.run.run()
end, { desc = "Test single function" })
vim.keymap.set("n", "<leader>ts", function()
	neotest.run.stop()
end, { desc = "Test stop" })
vim.keymap.set("n", "<leader>tb", function()
	neotest.run.run(vim.fn.expand("%"))
end, { desc = "Test single file" })
vim.keymap.set("n", "<leader>td", function()
	neotest.run.run(".")
end, { desc = "Test all from current directory" })
vim.keymap.set("n", "<leader>ta", function()
	neotest.run.run(vim.fn.getcwd())
end, { desc = "Test whole suite from root dir" })
vim.keymap.set("n", "<leader>tm", function()
	neotest.summary.toggle()
end, { desc = "Test summary toggle" })
vim.keymap.set("n", "<leader>tn", function()
	neotest.run.run({ strategy = "dap" })
end, { desc = "Debug nearest test" })
vim.keymap.set("n", "<leader>tm", "<cmd>ConfigureGtest<cr>", { desc = "Test configure C++ google test" })
vim.keymap.set("n", "<leader>tww", function()
	neotest.watch.toggle(vim.fn.expand("%"))
end, { desc = "Test watch toggle current file" })
vim.keymap.set("n", "<leader>tws", function()
	neotest.watch.stop("")
end, { desc = "Test watch stop all position" })
vim.keymap.set("n", "<leader>to", function()
	neotest.output.open({ enter = true })
end, { desc = "Test output open" })
vim.keymap.set("n", "<leader>tp", function()
	neotest.output_panel.toggle()
end, { desc = "Test output toggle panel" })
vim.keymap.set("n", "<leader>tc", function()
	neotest.output_panel.clear()
end, { desc = "Test output clear panel" })
vim.keymap.set("n", "<leader>twj", function()
	neotest.run.run({ jestCommand = "jest --watch " })
end, { desc = "Test Jest watch mode" })
vim.keymap.set("n", "<leader>twv", function()
	neotest.run.run({ vitestCommand = "vitest --watch" })
end, { desc = "Run Watch" })
vim.keymap.set("n", "<leader>twf", function()
	neotest.run.run({ vim.fn.expand(" % "), vitestCommand = "vitest --watch" })
end, { desc = "Run Watch File" })

-- dap
local dap = require("dap")
vim.keymap.set("n", "<F5>", dap.continue, { desc = "Debug continue" })
vim.keymap.set("n", "<F6>", dap.step_over, { desc = "Debug step over" })
vim.keymap.set("n", "<F7>", dap.step_into, { desc = "Debug step into" })
vim.keymap.set("n", "<F8>", dap.step_out, { desc = "Debug step out" })
vim.keymap.set("n", "<F9>", function()
	dap.disconnect({ terminateDebuggee = true })
	dap.close()
end, { desc = "Debug stop" })
vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint, { desc = "Debug toggle point" })
vim.keymap.set("n", "<leader>B", function()
	dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
end, { desc = "Debug set breakpoint condition" })
vim.keymap.set("n", "<leader>ap", function()
	dap.set_breakpoint(nil, nil, vim.fn.input("Log point message: "))
end, { desc = "Debug set log point message" })
vim.keymap.set("n", "<leader>el", dap.run_last, { desc = "Debug run the last session again" })
vim.keymap.set("n", "<leader>er", dap.repl.open, { desc = "Debug open REPL" })
vim.keymap.set("n", "<leader>et", require("dap-go").debug_test, { desc = "Debug golang test" })
vim.keymap.set("n", "<leader>ee", function()
	require("dapui").eval(nil, { enter = true })
end, { desc = "Debug evaluate expression" })

-- harpoon
local harpoon = require("harpoon")
harpoon:setup()
-- C-q: Open Harpoon Telescope window
vim.keymap.set("n", "<leader>h", function()
	harpoon:list():add()
end, { desc = "Add current location to Harpoon list" })
vim.keymap.set("n", "<C-z>", function()
	harpoon.ui:toggle_quick_menu(harpoon:list())
end, { desc = "Toggle Harpoon interactive list" })
vim.keymap.set("n", "<C-a>", function()
	harpoon:list():select(1)
end, { desc = "Go to 1st Harpoon location" })
vim.keymap.set("n", "<C-s>", function()
	harpoon:list():select(2)
end, { desc = "Go to 2nd Harpoon location" })
vim.keymap.set("n", "<C-n>", function()
	harpoon:list():select(3)
end, { desc = "Go to 3rd Harpoon location" })
vim.keymap.set("n", "<C-m>", function()
	harpoon:list():select(4)
end, { desc = "Go to 4th Harpoon location" })
vim.keymap.set("n", "<C-A-P>", function()
	harpoon:list():prev()
end, { desc = "Go to next Harpoon location" })
vim.keymap.set("n", "<C-A-N>", function()
	harpoon:list():next()
end, { desc = "Go to previous Harpoon location" })

-- refactoring
local refactoring = require("refactoring")
vim.keymap.set("x", "<leader>re", function()
	refactoring.refactor("Extract Function")
end, { desc = "Refactor extract function" })
vim.keymap.set("x", "<leader>rf", function()
	refactoring.refactor("Extract Function To File")
end, { desc = "Refactor extract function to file" })
vim.keymap.set("x", "<leader>rv", function()
	refactoring.refactor("Extract Variable")
end, { desc = "Refactor extract variable" })
vim.keymap.set("n", "<leader>rI", function()
	refactoring.refactor("Inline Function")
end, { desc = "Refactor inline function" })
vim.keymap.set({ "n", "x" }, "<leader>ri", function()
	refactoring.refactor("Inline Variable")
end, { desc = "Refactor inline variable" })
vim.keymap.set("n", "<leader>rb", function()
	refactoring.refactor("Extract Block")
end, { desc = "Refactor extract block" })
vim.keymap.set("n", "<leader>rB", function()
	refactoring.refactor("Extract Block To File")
end, { desc = "Refactor extract block to file" })
vim.keymap.set({ "x", "n" }, "<leader>rd", function()
	refactoring.debug.print_var()
end, { desc = "Refactor debug print var" })
vim.keymap.set("n", "<leader>rD", function()
	refactoring.debug.printf({ below = false })
end, { desc = "Refactor debug printf" })
vim.keymap.set("n", "<leader>rc", function()
	refactoring.debug.cleanup({})
end, { desc = "Refactor debug cleanup" })
vim.keymap.set({ "n", "x" }, "<leader>rt", function()
	refactoring.select_refactor()
end, { desc = "Refactor select native thing" })
vim.keymap.set({ "n", "x" }, "<leader>rr", function()
	require("telescope").extensions.refactoring.refactors()
end, { desc = "Refactor select operations via Telescope" })

-- undotree
vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle, { desc = "Toggle undo tree" })

-- fugitive
vim.keymap.set("n", "<leader>gs", vim.cmd.Git, { desc = "Open git fugitive" })

-- diffview
-- [c and ]c to jump between hunks
vim.keymap.set("n", "<leader>gh", "<cmd>DiffviewFileHistory<cr>", { desc = "Open history current branch" })
vim.keymap.set("n", "<leader>gf", "<cmd>DiffviewFileHistory %<cr>", { desc = "Open history current file" })
vim.keymap.set("n", "<leader>gd", "<cmd>DiffviewOpen<cr>", { desc = "Open diff current index" })
vim.keymap.set("n", "<leader>gm", "<cmd>DiffviewOpen origin/main...HEAD<cr>", { desc = "Open diff main" })
vim.keymap.set("n", "<leader>gc", "<cmd>DiffviewClose<cr>", { desc = "Close diff view" })

-- ufo
vim.keymap.set("n", "zR", require("ufo").openAllFolds, { desc = "Open all folds" })
vim.keymap.set("n", "zM", require("ufo").closeAllFolds, { desc = "Close all folds" })

-- file manager
vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
vim.keymap.set("n", "<space>-", require("oil").toggle_float, { desc = "Open parent directory in floating window" })
--[[
keymaps = {
    ["g?"] = "actions.show_help",
    ["<CR>"] = "actions.select",
    ["<C-s>"] = "actions.select_vsplit",
    ["<C-h>"] = "actions.select_split",
    ["<C-t>"] = "actions.select_tab",
    ["<C-p>"] = "actions.preview",
    ["<C-c>"] = "actions.close",
    ["<C-l>"] = "actions.refresh",
    ["-"] = "actions.parent",
    ["_"] = "actions.open_cwd",
    ["`"] = "actions.cd",
    ["~"] = "actions.tcd",
    ["gs"] = "actions.change_sort",
    ["gx"] = "actions.open_external",
    ["g."] = "actions.toggle_hidden",
    ["g\\"] = "actions.toggle_trash",
},
]]

-- rendermarkdown
vim.keymap.set("n", "<leader>tr", require("render-markdown").toggle, { desc = "Toggle Render Markdown" })

-- noice
local noice = require("noice")
vim.keymap.set("n", "<leader>nh", function()
	noice.cmd("history")
end, { desc = "Noice history" })
vim.keymap.set("n", "<leader>nl", function()
	noice.cmd("last")
end, { desc = "Noice last" })
vim.keymap.set("n", "<leader>nd", function()
	noice.cmd("dismiss")
end, { desc = "Noice dismiss" })
vim.keymap.set("n", "<leader>ne", function()
	noice.cmd("errors")
end, { desc = "Noice errors" })
vim.keymap.set("n", "<leader>nq", function()
	noice.cmd("disable")
end, { desc = "Noice disable" })
vim.keymap.set("n", "<leader>nb", function()
	noice.cmd("enable")
end, { desc = "Noice enable" })
vim.keymap.set("n", "<leader>ns", function()
	noice.cmd("stats")
end, { desc = "Noice debugging stats" })
vim.keymap.set("n", "<leader>nt", function()
	noice.cmd("telescope")
end, { desc = "Noice open messages in Telescope" })
vim.keymap.set("c", "<S-Enter>", function()
	noice.redirect(vim.fn.getcmdline())
end, { desc = "Redirect Cmdline" })
vim.keymap.set({ "n", "i", "s" }, "<c-f>", function()
	if not require("noice.lsp").scroll(4) then
		return "<c-f>"
	end
end, { silent = true, expr = true, desc = "LSP hover doc scroll up" })
vim.keymap.set({ "n", "i", "s" }, "<c-b>", function()
	if not require("noice.lsp").scroll(-4) then
		return "<c-b>"
	end
end, { silent = true, expr = true, desc = "LSP hover doc scroll down" })
```

</details>

### Plugins List

<details>
	<summary>(79)</summary>

● cellular-automaton.nvim 0.11ms  start
● cmp-buffer 0.09ms  nvim-cmp
● cmp-cmdline 0.13ms  nvim-cmp
● cmp-nvim-lsp 0.1ms  nvim-cmp
● cmp-nvim-lsp-signature-help 0.11ms  nvim-cmp
● cmp-path 0.1ms  nvim-cmp
● cmp_luasnip 0.17ms  nvim-cmp
● conform.nvim 0.67ms  lsp-zero.nvim
● diffview.nvim 1.66ms  start
● dressing.nvim 1.54ms  start
● fidget.nvim 1.82ms  lsp-zero.nvim
● FixCursorHold.nvim 0.58ms  neotest
● friendly-snippets 0.12ms  LuaSnip
● gitsigns.nvim 1.3ms  start
● harpoon 4.32ms  start
● indent-blankline.nvim 1.91ms  start
● lazy.nvim 9.11ms  init.lua
● lsp-zero.nvim 111.12ms  start
● lspkind.nvim 0.14ms  nvim-cmp
● lualine.nvim 12.16ms  start
● LuaSnip 5.33ms  nvim-cmp
● mason-lspconfig.nvim 0.07ms  lsp-zero.nvim
● mason-null-ls.nvim 0.37ms  lsp-zero.nvim
● mason-nvim-dap.nvim 0.04ms  lsp-zero.nvim
● mason-tool-installer.nvim 1.67ms  lsp-zero.nvim
● mason.nvim 3.66ms  lsp-zero.nvim
● mini.nvim 3.8ms  start
● neotest 39.13ms  start
● neotest-bash 0.61ms  neotest
● neotest-go 0.19ms  neotest
● neotest-gtest 0.35ms  neotest
● neotest-jest 0.31ms  neotest
● neotest-plenary 0.19ms  neotest
● neotest-python 0.24ms  neotest
● neotest-rust 0.22ms  neotest
● neotest-scala 0.3ms  neotest
● neotest-vitest 0.3ms  neotest
● neotest-zig 0.29ms  neotest
● noice.nvim 7.18ms 󰢱 noice  config.remap
● none-ls-extras.nvim 0.24ms  none-ls.nvim
● none-ls.nvim 0.54ms  lsp-zero.nvim
● nui.nvim 0.43ms  noice.nvim
● nvim-cmp 10.33ms  start
● nvim-dap 1.06ms  lsp-zero.nvim
● nvim-dap-go 0.27ms  lsp-zero.nvim
● nvim-dap-ui 0.28ms  lsp-zero.nvim
● nvim-dap-virtual-text 0.26ms  lsp-zero.nvim
● nvim-lspconfig 3.73ms  lsp-zero.nvim
● nvim-nio 0.27ms  neotest
● nvim-notify 4.14ms  noice.nvim
● nvim-treesitter 10.83ms  refactoring.nvim
● nvim-treesitter-context 0.96ms  start
● nvim-ts-autotag 5.65ms  nvim-treesitter
● nvim-ufo 25.96ms  start
● nvim-web-devicons 0.45ms  lualine.nvim
● oil.nvim 1.76ms  start
● playground 0.56ms  start
● plenary.nvim 0.44ms  refactoring.nvim
● promise-async 0.35ms  nvim-ufo
● refactoring.nvim 19.76ms  start
● render-markdown 5.48ms  start
● rose-pine 3.07ms  start
● SchemaStore.nvim 0.08ms  lsp-zero.nvim
● smart-open.nvim 20.6ms  start
● sqlite.lua 0.39ms  smart-open.nvim
● telescope-fzf-native.nvim 0.35ms  smart-open.nvim
● telescope-fzy-native.nvim 0.34ms  smart-open.nvim
● telescope.nvim 3.56ms 󰢱 telescope  refactoring.nvim
● undotree 0.38ms  start
● vim-dadbod 0.69ms  start
● vim-dadbod-completion 0.48ms  start
● vim-dadbod-ui 0.79ms  start
● vim-fugitive 1.36ms  start
● vimtex 1.42ms  start
● vlime 0.12ms  start
○ lazydev.nvim  lua
○ luvit-meta
○ nvim-metals  sbt  scala
○ trouble.nvim  <leader>cs  <leader>cd  <leader>ce  <leader>ca  <leader>cc

</details>

## Languages Packages List

<details>
	<summary>(75)</summary>

- actionlint
- ansible-language-server ansiblels
- ansible-lint
- asm-lsp asm_lsp
- asmfmt
- bash-debug-adapter
- bash-language-server bashls
- beautysh
- blue
- buf
- buf-language-server bufls
- cbfmt
- checkmake
- clangd
- cmakelint
- codelldb
- cpptools
- csharp-language-server csharp_ls
- csharpier
- css-lsp cssls
- debugpy
- delve
- docker-compose-language-service docker_compose_language_service
- dockerfile-language-server dockerls
- emmet-language-server emmet_language_server
- eslint-lsp eslint
- firefox-debug-adapter
- flake8
- go-debug-adapter
- goimports-reviser
- golangci-lint
- golangci-lint-langserver golangci_lint_ls
- gomodifytags
- gopls
- gotests
- graphql-language-service-cli graphql
- helm-ls helm_ls
- html-lsp html
- htmx-lsp htmx
- impl
- java-debug-adapter
- java-test
- jdtls
- js-debug-adapter
- lua-language-server lua_ls
- luacheck
- marksman
- neocmakelsp neocmake
- ocaml-lsp ocamllsp
- ocamlearlybird
- ocamlformat
- powershell-editor-services powershell_es
- prettier
- protolint
- pyright
- rust-analyzer rust_analyzer
- semgrep
- shellcheck
- shfmt
- sql-formatter
- sqlfluff
- sqlls
- staticcheck
- stylua
- tailwindcss-language-server tailwindcss
- taplo
- terraform-ls terraformls
- texlab
- tflint
- typescript-language-server tsserver
- typos-lsp typos_lsp
- vue-language-server volar
- yamlfmt
- yamllint
- zls

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
"cpptools",

-- rust
"rust_analyzer",
"codelldb",

-- java
"jdtls",
"java-test",
"java-debug-adapter",

-- scala
-- "scalameta/nvim-metals"

-- lisp
-- "vlime/vlime"

-- zig
"zls",

-- ocaml
"ocamllsp",
"ocamlearlybird",
"ocamlformat",

-- csharp
"csharp_ls",
"csharpier",

-- assembly
"asm-lsp",
"asmfmt",

-- markdown
"marksman",
"cbfmt",

-- latex & typos
"texlab",
typos_lsp = {
    init_options = {
        config = "~/typos.toml",
    },
},

-- shell
"bashls",
"powershell_es",
"shellcheck",
"shfmt",
"beautysh",
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
