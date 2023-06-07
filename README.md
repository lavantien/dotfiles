# A robust Dotfiles for Developer - Battery Included

- Quality Assurance: **100%**; Disk Size: **139GB**; Time Taken: **5h**;
- Supported: **AMD** & **Intel** (Wayland), **NVIDIA** (auto X11)
- Turn off `M$ Secure Boot` in your `BIOS` for a smooth installation process
- Install with `Minimal setup`, check `Additionals Drivers` and `3rd-party` boxes

## Step by Step Setup for a Fresh Ubuntu 23.04

<details>
  <summary>expand</summary>

### 0. Disable Wireless Powersaving and Files Open Limit

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
sudo systemctl daemon-reexec && ulimit -n
```

`reboot`

### 1. Install all necessary `APT` packages

```bash
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt install ubuntu-desktop ca-certificates apt-transport-https ubuntu-dev-tools glibc-source gcc xclip git git-lfs curl zsh htop neofetch vim mpv libutf8proc2 libutf8proc-dev libfuse2 cpu-checker screenkey cmake cmake-format ninja-build libjsoncpp-dev uuid-dev zlib1g-dev libssl-dev postgresql-all libmariadb-dev libsqlite3-dev libhiredis-dev -y
```

### 2. Install `Oh-my-zsh` and `Chrome`, then `reboot`

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

```bash
cd ~/Downloads && wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && sudo dpkg -i google-chrome-stable_current_amd64.deb && rm google-chrome-stable_current_amd64.deb && cd ~
```

- Open `Chrome`, sync your profile, and go to <https://github.com/lavantien/dotfiles/blob/main/README.md> to continue the steps
- Recommended `Chrome Extensions`:

```text
aapbdbdomjkkjkaonfhkkikfgjllcleb : Google Translate
ahfgeienlihckogmohjhadlkjgocpleb : Web Store
ahfhijdlegdabablpippeagghigmibma : Web Vitals
bcjindcccaagfpapjjmafapmmgkkhgoa : JSON Formatter
bkhaagjahfmjljalopjnoealnfndnagc : Octotree - GitHub code tree
cjpalhdlnbpafiamejdnhcphjbkeiagm : uBlock Origin
dbepggeogbaibhgnhhndojpepiihcmeb : Vimium
eimadpbcbfnmbkopoojfekhnkhdbieeh : Dark Reader
ejkiikneibegknkgimmihdpcbcedgmpo : Volume Booster
gebbhagfogifgggkldgodflihgfeippi : Return YouTube Dislike
ghbmnnjooekpmoecnnnilnnbdlolhkhi : Google Docs Offline
gppongmhjkpfnbhagpmjfkannfbllamg : Wappalyzer
hlkenndednhfkekhgcdicdfddnkalmdm : Cookie-Editor
mafpmfcccpbjnhfhjnllmmalhifmlcie : Snowflake
mhjfbmdgcfjbbpaeojofohoefgiehjai : Chrome PDF Viewer
migdhldfbapmodfbmgpofnikfbfpbbon : Highlighty: Search, Find, Multi-Highlight
neajdppkdcdipfabeoofebfddakdcjhd : Google Network Speech
nkeimhogjdpnpccoofpliimaahmaaome : Google Hangouts
nlkaejimjacpillmajjnopmpbkbnocid : YouTube NonStop
nmmhkkegccagdldgiimedpiccmgmieda : Chrome Web Store Payments
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
brew install gcc@11 gcc gh go lazygit fzf fd ripgrep bat neovim hyperfine openjdk ruby lua maven node gopls rust-analyzer jdtls lua-language-server typescript-language-server marksman texlab yaml-language-server bash-language-server terraform terraform-ls sql-language-server sqlfluff prettier delve vscode-langservers-extracted loc llvm dotenv-linter checkmake luarocks php composer
```

```bash
sudo snap install julia --classic && pip3 install cmake-language-server python-lsp-server && npm install --global sql-formatter && sudo apt install python-is-python3 -y && go install github.com/charmbracelet/glow@latest
```

```bash
cd ~/Downloads && wget https://github.com/OmniSharp/omnisharp-vscode/releases/download/v1.25.8/csharp-1.25.8-linux-x64.vsix && code --install-extension csharp-1.25.8-linux-x64.vsix && rm csharp-1.25.8-linux-x64.vsix && cd ~
```

### 8. Install `Joplin (snap)`, sync your notes, and setup your `Git` environment:

```bash
sudo snap install joplin-desktop
```

- For a smooth `Git` experience, you should make a `.netrc` file in your home directory and add auth token

```bash
echo 'machine github.com login lavantien password ghp_klsdfjalsdkfjdsjfalsdkldasfjkasldfjalsdfjalsdjfk' >> .netrc && git lfs install
```

- For `gh`, run `gh auth login` and follow instruction to setup `GitHub CLI`

### 9. Run `./git-clone-all $org_name` on `~/dev/personal` for cloning all of your repos

```bash
org_name=your-github-username && mkdir -p ~/dev/personal && cp ~/git-clone-all.sh ~/dev/personal/ && cd ~/dev/personal && ./git-clone-all.sh $org_name && cd ~
```

```bash
org_name=your-github-username && cp -r ~/dev/personal/$org_name/Documents/{*,.*} ~/Documents/ && cp -r ~/dev/personal/$org_name/Pictures/{*,.*} ~/Pictures/
```

- Rerun the script to sync with remote

### 10. Install `Iosevka Nerd Font` (replace version `v3.0.1` with whatever latest)

```bash
cd ~/Downloads && wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.1/Iosevka.zip && mkdir Iosevka && unzip Iosevka.zip -d Iosevka && cd Iosevka && sudo mkdir -p /usr/share/fonts/truetype/iosevka-nerd-font && sudo cp *.ttf /usr/share/fonts/truetype/iosevka-nerd-font/ && cd .. && rm -r Iosevka Iosevka.zip && cd ~ && sudo fc-cache -f -v
```

### 11. Install `wezterm`

```bash
brew tap wez/wezterm-linuxbrew && brew install wezterm
```

### 12. Install `GRPC`, `GRPC-Web`, and `protoc-gen`

```bash
brew install grpc protoc-gen-grpc-web && go install google.golang.org/protobuf/cmd/protoc-gen-go@latest && go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
```

### 13. Install `VSCode` and `CodeLLDB` (replace version `v1.9.2` with whatever latest)

```bash
cd ~/Downloads && wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg && sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg && sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list' && rm -f packages.microsoft.gpg && cd ~ && sudo apt update && sudo apt install code -y
```

```bash
cd ~/Downloads && wget https://github.com/vadimcn/codelldb/releases/download/v1.9.2/codelldb-x86_64-linux.vsix && code --install-extension codelldb-x86_64-linux.vsix && rm codelldb-x86_64-linux.vsix && cd ~
```

### 14. Install `DotNet SDK`

```bash
cd ~/Downloads && declare repo_version=$(if command -v lsb_release &> /dev/null; then lsb_release -r -s; else grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"'; fi) && wget https://packages.microsoft.com/config/ubuntu/$repo_version/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && sudo dpkg -i packages-microsoft-prod.deb && rm packages-microsoft-prod.deb && cd ~ && sudo apt update && sudo apt install dotnet-sdk-7.0 -y
```

```bash
sudo cp -r /usr/share/dotnet/* /usr/lib/dotnet/ && dotnet --info
```

```bash
dotnet tool install --global csharp-ls && dotnet tool install --global csharpier
```

### 15. Install `Qemu KVM`

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo && kvm-ok
```

```bash
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils -y
```

### 16. Install `Android Studio`, `Android SDK`, and `Flutter`

```bash
sudo snap install android-studio --classic
```

- Run `Android Studio` and install default configuration, then click `More Actions` -> `SDK Manager` -> `SDK Tools` -> tick `Android SDK Build-Tools` and `Android SDK Command-line Tools` -> `Apply` and `OK`

```bash
sudo snap install flutter --classic && flutter doctor && flutter doctor --android-licenses
```

### 17. Install `Kreya` and `DBbGate`

```bash
sudo snap install kreya dbgate
```

### 18. Install `FlatHub`, `Docker Compose`, `Podman Desktop`, then `reboot`

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
docker run hello-world && flatpak install flathub io.podman_desktop.PodmanDesktop -y
```

### 19. Install `kubectl`, and `minikube`

```bash
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg && echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list && sudo apt update && sudo apt install kubectl -y
```

```bash
cd ~/Downloads && curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb && sudo dpkg -i minikube_latest_amd64.deb && rm minikube_latest_amd64.deb && cd ~
```

```bash
minikube config set driver docker && minikube start && minikube addons enable metrics-server
```

```bash
❗  These changes will take effect upon a minikube delete and then a minikube start
😄  minikube v1.30.1 on Ubuntu 23.04
✨  Using the docker driver based on user configuration
📌  Using Docker driver with root privileges
👍  Starting control plane node minikube in cluster minikube
🚜  Pulling base image ...
💾  Downloading Kubernetes v1.26.3 preload ...
    > preloaded-images-k8s-v18-v1...:  397.02 MiB / 397.02 MiB  100.00% 14.17 M
    > gcr.io/k8s-minikube/kicbase...:  373.53 MiB / 373.53 MiB  100.00% 6.42 Mi
🔥  Creating docker container (CPUs=2, Memory=7900MB) ...
🐳  Preparing Kubernetes v1.26.3 on Docker 23.0.2 ...
    ▪ Generating certificates and keys ...
    ▪ Booting up control plane ...
    ▪ Configuring RBAC rules ...
🔗  Configuring bridge CNI (Container Networking Interface) ...
    ▪ Using image gcr.io/k8s-minikube/storage-provisioner:v5
🌟  Enabled addons: storage-provisioner, default-storageclass
🔎  Verifying Kubernetes components...
🏄  Done! kubectl is now configured to use "minikube" cluster and "default" namespace by default
💡  metrics-server is an addon maintained by Kubernetes. For any concerns contact minikube on GitHub.
You can view the list of minikube maintainers at: https://github.com/kubernetes/minikube/blob/master/OWNERS
    ▪ Using image registry.k8s.io/metrics-server/metrics-server:v0.6.3
🌟  The 'metrics-server' addon is enabled
```

```bash
minikube stop
```

### 20. Install `Graphics Drivers` and `Vulkan`, and `Fan Control`

- If you have a `NVIDIA GPU`, replace `535` with whatever is the latest driver version as listed [here](https://launchpad.net/~graphics-drivers/+archive/ubuntu/ppa)

```bash
sudo add-apt-repository ppa:graphics-drivers/ppa -y && sudo dpkg --add-architecture i386 && sudo apt update && sudo apt install nvidia-driver-535 libvulkan1 libvulkan1:i386 libgl-dev libgl-dev:i386 -y
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
curl -1sLf \
  'https://dl.cloudsmith.io/public/coolercontrol/coolercontrol/setup.deb.sh' \
  | sudo -E bash \
&& sudo apt update && sudo apt install lm-sensors libxcb-cursor0 coolercontrol -y && sudo sensors-detect && sudo systemctl enable coolercontrold && sudo systemctl start coolercontrold
```

### 21. Install `Wine`, `Lutris`, and `MangoHud` (always check for the latest version and replace the version string when download from `wget`)

```bash
sudo mkdir -pm755 /etc/apt/keyrings && sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/lunar/winehq-lunar.sources && sudo apt update && sudo apt install --install-recommends winehq-devel -y
```

```bash
sudo apt install cabextract fluid-soundfont-gm fluid-soundfont-gs libmspack0 mesa-utils mesa-utils-bin p7zip python3-bs4 python3-html5lib python3-lxml python3-setproctitle python3-soupsieve python3-webencodings p7zip-full python3-genshi doc-base -y && cd ~/Downloads && wget https://github.com/lutris/lutris/releases/download/v0.5.13/lutris_0.5.13_all.deb && sudo dpkg -i lutris_0.5.13_all.deb && rm lutris_0.5.13_all.deb && cd ~
```

```bash
lutris
```

- Click the `gear button` next to `Wine` -> tick `Advanced` -> `System options` -> `Command prefix` -> `mangohud` -> `Save` -> exit Lutris
- For `Steam` games, set launch options: `mangohud %command%`

```bash
sudo apt install mangohud -y
```

### 22. Install `OBS`, `Gimp`, `Inkscape`, `LibreOffice`, `Blender`

```bash
sudo add-apt-repository ppa:obsproject/obs-studio -y && sudo apt update && sudo apt install ffmpeg obs-studio -y
```

- Then run `OBS`, setup proper resolution, framerate, encoder, and default whole screen scene

```bash
sudo snap install gimp inkscape libreoffice
```

```bash
sudo snap install blender --classic
```

### 23. `Helix`

```bash
brew install helix
```

### 24. Install `Steam` (and optionally `Dota 2`, `Grim Dawn`, `Battlenet`, and `Diablo 2 Resurrected`)

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

- [**Drogon Core - The fastest Web Framework**](https://drogonframework.github.io/drogon-docs/#/?id=document)

```bash
sudo apt install postgresql-all libmariadb-dev libsqlite3-dev libhiredis-dev && docker pull drogonframework/drogon
```

- [**SegmentIO KafkaGo**](https://github.com/segmentio/kafka-go)

```bash
go get -u github.com/segmentio/kafka-go
```

- [**GoKa KafkaGo**](https://github.com/lovoo/goka)

```bash
go get -u github.com/lovoo/goka
```

- [**FranzGo KafkaGo**](https://github.com/twmb/franz-go)

```bash
go get -u github.com/twmb/franz-go
```

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
go install github.com/kyleconroy/sqlc/cmd/sqlc@latest
```

- [**GoMock**](https://github.com/golang/mock):

```bash
go install github.com/golang/mock/mockgen@latest
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

- [**DB Diagram**](https://dbdiagram.io/)

- [**Swagger Editor**](https://editor.swagger.io/)

- [**Coverage Badge**](https://eremeev.ca/posts/golang-test-coverage-github-action/)

</details>

## Healthcheck

```bash
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && rustup update && brew upgrade
```

<details>
  <summary>expand</summary>

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
minikube start && kubectl get po -A && minikube dashboard
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

### Flutter Doctor

```bash
flutter doctor
```

```bash
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.10.3, on Ubuntu 23.04 6.2.0-20-generic, locale en_US.UTF-8)
[✓] Android toolchain - develop for Android devices (Android SDK version 33.0.2)
[✓] Chrome - develop for the web
[✓] Linux toolchain - develop for Linux desktop
[✓] Android Studio (version 2022.2)
[✓] VS Code (version 1.78.2)
[✓] Connected device (2 available)
[✓] Network resources

• No issues found!
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
cd ~
```

### Helix LSP

```bash
hx --health
```

<details>
  <summary>expand result</summary>

```bash
Config file: default
Language file: default
Log file: /home/lavantien/.cache/helix/helix.log
Runtime directories: /home/lavantien/.config/helix/runtime;/home/linuxbrew/.linuxbrew/Cellar/helix/23.05/libexec/runtime;/home/linuxbrew/.linuxbrew/Cellar/helix/23.05/libexec/bin/runtime
Runtime directory does not exist: /home/lavantien/.config/helix/runtime
Runtime directory does not exist: /home/linuxbrew/.linuxbrew/Cellar/helix/23.05/libexec/bin/runtime
Clipboard provider: xclip
System clipboard provider: xclip

Language                                                 LSP                                                      DAP                                                      Highlight                                                Textobject                                               Indent
astro                                                    None                                                     None                                                     ✓                                                        ✘                                                        ✘
awk                                                      ✘ awk-language-server                                    None                                                     ✓                                                        ✓                                                        ✘
bash                                                     ✓ bash-language-server                                   None                                                     ✓                                                        ✘                                                        ✓
bass                                                     ✘ bass                                                   None                                                     ✓                                                        ✘                                                        ✘
beancount                                                None                                                     None                                                     ✓                                                        ✘                                                        ✘
bibtex                                                   ✓ texlab                                                 None                                                     ✓                                                        ✘                                                        ✘
bicep                                                    ✘ bicep-langserver                                       None                                                     ✓                                                        ✘                                                        ✘
c                                                        ✓ clangd                                                 ✓ lldb-vscode                                            ✓                                                        ✓                                                        ✓
c-sharp                                                  ✘ OmniSharp                                              ✘ netcoredbg                                             ✓                                                        ✓                                                        ✘
cabal                                                    None                                                     None                                                     ✘                                                        ✘                                                        ✘
cairo                                                    None                                                     None                                                     ✓                                                        ✘                                                        ✘
capnp                                                    None                                                     None                                                     ✓                                                        ✘                                                        ✓
clojure                                                  ✘ clojure-lsp                                            None                                                     ✓                                                        ✘                                                        ✘
cmake                                                    ✓ cmake-language-server                                  None                                                     ✓                                                        ✓                                                        ✓
comment                                                  None                                                     None                                                     ✓                                                        ✘                                                        ✘
common-lisp                                              ✘ cl-lsp                                                 None                                                     ✓                                                        ✘                                                        ✘
cpon                                                     None                                                     None                                                     ✓                                                        ✘                                                        ✓
cpp                                                      ✓ clangd                                                 ✓ lldb-vscode                                            ✓                                                        ✓                                                        ✓
crystal                                                  ✘ crystalline                                            None                                                     ✓                                                        ✓                                                        ✘
css                                                      ✓ vscode-css-language-server                             None                                                     ✓                                                        ✘                                                        ✘
cue                                                      ✘ cuelsp                                                 None                                                     ✓                                                        ✘                                                        ✘
d                                                        ✘ serve-d                                                None                                                     ✓                                                        ✓                                                        ✓
dart                                                     ✓ dart                                                   None                                                     ✓                                                        ✘                                                        ✓
devicetree                                               None                                                     None                                                     ✓                                                        ✘                                                        ✘
dhall                                                    ✘ dhall-lsp-server                                       None                                                     ✓                                                        ✓                                                        ✘
diff                                                     None                                                     None                                                     ✓                                                        ✘                                                        ✘
dockerfile                                               ✘ docker-langserver                                      None                                                     ✓                                                        ✘                                                        ✘
dot                                                      ✘ dot-language-server                                    None                                                     ✓                                                        ✘                                                        ✘
dtd                                                      None                                                     None                                                     ✓                                                        ✘                                                        ✘
edoc                                                     None                                                     None                                                     ✓                                                        ✘                                                        ✘
eex                                                      None                                                     None                                                     ✓                                                        ✘                                                        ✘
ejs                                                      None                                                     None                                                     ✓                                                        ✘                                                        ✘
elixir                                                   ✘ elixir-ls                                              None                                                     ✓                                                        ✓                                                        ✓
elm                                                      ✘ elm-language-server                                    None                                                     ✓                                                        ✓                                                        ✘
elvish                                                   ✘ elvish                                                 None                                                     ✓                                                        ✘                                                        ✘
env                                                      None                                                     None                                                     ✓                                                        ✘                                                        ✘
erb                                                      None                                                     None                                                     ✓                                                        ✘                                                        ✘
erlang                                                   ✘ erlang_ls                                              None                                                     ✓                                                        ✓                                                        ✘
esdl                                                     None                                                     None                                                     ✓                                                        ✘                                                        ✘
fish                                                     None                                                     None                                                     ✓                                                        ✓                                                        ✓
fortran                                                  ✘ fortls                                                 None                                                     ✓                                                        ✘                                                        ✓
gdscript                                                 None                                                     None                                                     ✓                                                        ✓                                                        ✓
git-attributes                                           None                                                     None                                                     ✓                                                        ✘                                                        ✘
git-commit                                               None                                                     None                                                     ✓                                                        ✓                                                        ✘
git-config                                               None                                                     None                                                     ✓                                                        ✘                                                        ✘
git-ignore                                               None                                                     None                                                     ✓                                                        ✘                                                        ✘
git-rebase                                               None                                                     None                                                     ✓                                                        ✘                                                        ✘
gleam                                                    ✘ gleam                                                  None                                                     ✓                                                        ✓                                                        ✘
glsl                                                     None                                                     None                                                     ✓                                                        ✓                                                        ✓
go                                                       ✓ gopls                                                  ✓ dlv                                                    ✓                                                        ✓                                                        ✓
godot-resource                                           None                                                     None                                                     ✓                                                        ✘                                                        ✘
gomod                                                    ✓ gopls                                                  None                                                     ✓                                                        ✘                                                        ✘
gotmpl                                                   ✓ gopls                                                  None                                                     ✓                                                        ✘                                                        ✘
gowork                                                   ✓ gopls                                                  None                                                     ✓                                                        ✘                                                        ✘
graphql                                                  None                                                     None                                                     ✓                                                        ✘                                                        ✘
hare                                                     None                                                     None                                                     ✓                                                        ✘                                                        ✘
haskell                                                  ✘ haskell-language-server-wrapper                        None                                                     ✓                                                        ✓                                                        ✘
hcl                                                      ✓ terraform-ls                                           None                                                     ✓                                                        ✘                                                        ✓
heex                                                     ✘ elixir-ls                                              None                                                     ✓                                                        ✓                                                        ✘
hosts                                                    None                                                     None                                                     ✓                                                        ✘                                                        ✘
html                                                     ✓ vscode-html-language-server                            None                                                     ✓                                                        ✘                                                        ✘
hurl                                                     None                                                     None                                                     ✓                                                        ✘                                                        ✓
idris                                                    ✘ idris2-lsp                                             None                                                     ✘                                                        ✘                                                        ✘
iex                                                      None                                                     None                                                     ✓                                                        ✘                                                        ✘
ini                                                      None                                                     None                                                     ✓                                                        ✘                                                        ✘
java                                                     ✓ jdtls                                                  None                                                     ✓                                                        ✓                                                        ✘
javascript                                               ✓ typescript-language-server                             ✘                                                        ✓                                                        ✓                                                        ✓
jsdoc                                                    None                                                     None                                                     ✓                                                        ✘                                                        ✘
json                                                     ✓ vscode-json-language-server                            None                                                     ✓                                                        ✘                                                        ✓
jsonnet                                                  ✘ jsonnet-language-server                                None                                                     ✓                                                        ✘                                                        ✘
jsx                                                      ✓ typescript-language-server                             None                                                     ✓                                                        ✓                                                        ✓
julia                                                    ✓ julia                                                  None                                                     ✓                                                        ✓                                                        ✓
just                                                     None                                                     None                                                     ✓                                                        ✓                                                        ✓
kdl                                                      None                                                     None                                                     ✓                                                        ✘                                                        ✘
kotlin                                                   ✘ kotlin-language-server                                 None                                                     ✓                                                        ✘                                                        ✘
latex                                                    ✓ texlab                                                 None                                                     ✓                                                        ✓                                                        ✘
lean                                                     ✘ lean                                                   None                                                     ✓                                                        ✘                                                        ✘
ledger                                                   None                                                     None                                                     ✓                                                        ✘                                                        ✘
llvm                                                     None                                                     None                                                     ✓                                                        ✓                                                        ✓
llvm-mir                                                 None                                                     None                                                     ✓                                                        ✓                                                        ✓
llvm-mir-yaml                                            None                                                     None                                                     ✓                                                        ✘                                                        ✓
lua                                                      ✓ lua-language-server                                    None                                                     ✓                                                        ✓                                                        ✓
make                                                     None                                                     None                                                     ✓                                                        ✘                                                        ✘
markdoc                                                  ✘ markdoc-ls                                             None                                                     ✓                                                        ✘                                                        ✘
markdown                                                 ✓ marksman                                               None                                                     ✓                                                        ✘                                                        ✘
markdown.inline                                          None                                                     None                                                     ✓                                                        ✘                                                        ✘
matlab                                                   None                                                     None                                                     ✓                                                        ✘                                                        ✘
mermaid                                                  None                                                     None                                                     ✓                                                        ✘                                                        ✘
meson                                                    None                                                     None                                                     ✓                                                        ✘                                                        ✓
mint                                                     ✘ mint                                                   None                                                     ✘                                                        ✘                                                        ✘
msbuild                                                  None                                                     None                                                     ✓                                                        ✘                                                        ✓
nasm                                                     None                                                     None                                                     ✓                                                        ✓                                                        ✘
nickel                                                   ✘ nls                                                    None                                                     ✓                                                        ✘                                                        ✓
nim                                                      ✘ nimlangserver                                          None                                                     ✓                                                        ✓                                                        ✓
nix                                                      ✘ nil                                                    None                                                     ✓                                                        ✘                                                        ✘
nu                                                       None                                                     None                                                     ✓                                                        ✘                                                        ✘
ocaml                                                    ✘ ocamllsp                                               None                                                     ✓                                                        ✘                                                        ✓
ocaml-interface                                          ✘ ocamllsp                                               None                                                     ✓                                                        ✘                                                        ✘
odin                                                     ✘ ols                                                    None                                                     ✓                                                        ✘                                                        ✓
opencl                                                   ✓ clangd                                                 None                                                     ✓                                                        ✓                                                        ✓
openscad                                                 ✘ openscad-lsp                                           None                                                     ✓                                                        ✘                                                        ✘
org                                                      None                                                     None                                                     ✓                                                        ✘                                                        ✘
pascal                                                   ✘ pasls                                                  None                                                     ✓                                                        ✓                                                        ✘
passwd                                                   None                                                     None                                                     ✓                                                        ✘                                                        ✘
pem                                                      None                                                     None                                                     ✓                                                        ✘                                                        ✘
perl                                                     ✘ perlnavigator                                          None                                                     ✓                                                        ✓                                                        ✓
php                                                      ✘ intelephense                                           None                                                     ✓                                                        ✓                                                        ✓
po                                                       None                                                     None                                                     ✓                                                        ✓                                                        ✘
ponylang                                                 None                                                     None                                                     ✓                                                        ✓                                                        ✓
prisma                                                   ✘ prisma-language-server                                 None                                                     ✓                                                        ✘                                                        ✘
prolog                                                   ✘ swipl                                                  None                                                     ✘                                                        ✘                                                        ✘
protobuf                                                 None                                                     None                                                     ✓                                                        ✘                                                        ✓
prql                                                     None                                                     None                                                     ✓                                                        ✘                                                        ✘
purescript                                               ✘ purescript-language-server                             None                                                     ✓                                                        ✘                                                        ✘
python                                                   ✓ pylsp                                                  None                                                     ✓                                                        ✓                                                        ✓
qml                                                      ✘ qmlls                                                  None                                                     ✓                                                        ✘                                                        ✓
r                                                        ✘ R                                                      None                                                     ✓                                                        ✘                                                        ✘
racket                                                   ✘ racket                                                 None                                                     ✓                                                        ✘                                                        ✘
regex                                                    None                                                     None                                                     ✓                                                        ✘                                                        ✘
rego                                                     ✘ regols                                                 None                                                     ✓                                                        ✘                                                        ✘
rescript                                                 ✘ rescript-language-server                               None                                                     ✓                                                        ✓                                                        ✘
rmarkdown                                                ✘ R                                                      None                                                     ✓                                                        ✘                                                        ✓
robot                                                    ✘ robotframework_ls                                      None                                                     ✓                                                        ✘                                                        ✘
ron                                                      None                                                     None                                                     ✓                                                        ✘                                                        ✓
rst                                                      None                                                     None                                                     ✓                                                        ✘                                                        ✘
ruby                                                     ✘ solargraph                                             None                                                     ✓                                                        ✓                                                        ✓
rust                                                     ✓ rust-analyzer                                          ✓ lldb-vscode                                            ✓                                                        ✓                                                        ✓
sage                                                     None                                                     None                                                     ✓                                                        ✓                                                        ✘
scala                                                    ✘ metals                                                 None                                                     ✓                                                        ✘                                                        ✓
scheme                                                   None                                                     None                                                     ✓                                                        ✘                                                        ✘
scss                                                     ✓ vscode-css-language-server                             None                                                     ✓                                                        ✘                                                        ✘
slint                                                    ✘ slint-lsp                                              None                                                     ✓                                                        ✘                                                        ✓
smithy                                                   ✘ cs                                                     None                                                     ✓                                                        ✘                                                        ✘
sml                                                      None                                                     None                                                     ✓                                                        ✘                                                        ✘
solidity                                                 ✘ solc                                                   None                                                     ✓                                                        ✘                                                        ✘
sql                                                      None                                                     None                                                     ✓                                                        ✘                                                        ✘
sshclientconfig                                          None                                                     None                                                     ✓                                                        ✘                                                        ✘
starlark                                                 None                                                     None                                                     ✓                                                        ✓                                                        ✘
svelte                                                   ✘ svelteserver                                           None                                                     ✓                                                        ✘                                                        ✘
sway                                                     ✘ forc                                                   None                                                     ✓                                                        ✓                                                        ✓
swift                                                    ✘ sourcekit-lsp                                          None                                                     ✓                                                        ✘                                                        ✘
tablegen                                                 None                                                     None                                                     ✓                                                        ✓                                                        ✓
task                                                     None                                                     None                                                     ✓                                                        ✘                                                        ✘
tfvars                                                   ✓ terraform-ls                                           None                                                     ✓                                                        ✘                                                        ✓
toml                                                     ✘ taplo                                                  None                                                     ✓                                                        ✘                                                        ✘
tsq                                                      None                                                     None                                                     ✓                                                        ✘                                                        ✘
tsx                                                      ✓ typescript-language-server                             None                                                     ✓                                                        ✓                                                        ✓
twig                                                     None                                                     None                                                     ✓                                                        ✘                                                        ✘
typescript                                               ✓ typescript-language-server                             None                                                     ✓                                                        ✓                                                        ✓
ungrammar                                                None                                                     None                                                     ✓                                                        ✘                                                        ✘
uxntal                                                   None                                                     None                                                     ✓                                                        ✘                                                        ✘
v                                                        ✘ v                                                      None                                                     ✓                                                        ✓                                                        ✓
vala                                                     ✘ vala-language-server                                   None                                                     ✓                                                        ✘                                                        ✘
verilog                                                  ✘ svlangserver                                           None                                                     ✓                                                        ✓                                                        ✘
vhdl                                                     ✘ vhdl_ls                                                None                                                     ✓                                                        ✘                                                        ✘
vhs                                                      None                                                     None                                                     ✓                                                        ✘                                                        ✘
vue                                                      ✘ vls                                                    None                                                     ✓                                                        ✘                                                        ✘
wast                                                     None                                                     None                                                     ✓                                                        ✘                                                        ✘
wat                                                      None                                                     None                                                     ✓                                                        ✘                                                        ✘
wgsl                                                     ✘ wgsl_analyzer                                          None                                                     ✓                                                        ✘                                                        ✘
wit                                                      None                                                     None                                                     ✓                                                        ✘                                                        ✓
xit                                                      None                                                     None                                                     ✓                                                        ✘                                                        ✘
xml                                                      None                                                     None                                                     ✓                                                        ✘                                                        ✓
yaml                                                     ✓ yaml-language-server                                   None                                                     ✓                                                        ✘                                                        ✓
yuck                                                     None                                                     None                                                     ✓                                                        ✘                                                        ✘
zig                                                      ✘ zls                                                    ✓ lldb-vscode                                            ✓                                                        ✓                                                        ✓
```

</details>

### Neovim Deps (fresh 100% OK)

```bash
npm i -g neovim
```

```bash
pip3 install neovim
```

```bash
gem install neovim
```

```bash
nvim +che
```

### Neovim Deps (after setup 100% OK)

<details>
  <summary>`n +che` result</summary>
  
```checkhealth
==============================================================================
lazy: require("lazy.health").check()

lazy.nvim ~

- OK Git installed
- OK no existing packages found by other package managers
- OK packer_compiled.lua not found

==============================================================================
mason: require("mason.health").check()

mason.nvim ~

- OK mason.nvim version v1.1.1
- OK PATH: prepend
- OK Providers:
  mason.providers.registry-api
  mason.providers.client
- OK neovim version >= 0.7.0

mason.nvim [Registries] ~

- OK Registry `github.com/mason-org/mason-registry version: 2023-06-05-basic-pound` is installed.
- OK Registry `github.com/mason-org/mason-registry version: 2023-06-05-basic-pound` is installed.

mason.nvim [Core utils] ~

- OK unzip: `UnZip 6.00 of 20 April 2009, by Debian. Original by Info-ZIP.`
- OK wget: `GNU Wget 1.21.3 built on linux-gnu.`
- OK curl: `curl 8.1.2 (x86_64-pc-linux-gnu) libcurl/8.1.2 OpenSSL/1.1.1u zlib/1.2.13 brotli/1.0.9 zstd/1.5.5 libidn2/2.3.4 libssh2/1.11.0 nghttp2/1.53.0 librtmp/2.3`
- OK gzip: `gzip 1.12`
- OK tar: `tar (GNU tar) 1.34`
- OK bash: `GNU bash, version 5.2.15(1)-release (x86_64-pc-linux-gnu)`
- OK sh: `Ok`

mason.nvim [Languages] ~

- OK Go: `go version go1.20.4 linux/amd64`
- OK Ruby: `ruby 3.2.2 (2023-03-30 revision e51014f9c0) [x86_64-linux]`
- OK luarocks: `/home/linuxbrew/.linuxbrew/bin/luarocks 3.9.2`
- OK cargo: `cargo 1.70.0 (ec8a8a0ca 2023-04-25)`
- OK node: `v20.2.0`
- OK PHP: `PHP 8.2.6 (cli) (built: May  9 2023 06:25:31) (NTS)`
- OK java: `openjdk version "20.0.1" 2023-04-18`
- OK Composer: `Composer version 2.5.7 2023-05-24 15:00:39`
- OK python3: `Python 3.11.3`
- OK RubyGem: `3.4.13`
- OK javac: `javac 20.0.1`
- OK npm: `9.6.7`
- OK pip3: `pip 23.1.2 from /home/linuxbrew/.linuxbrew/Cellar/python@3.11/3.11.3/lib/python3.11/site-packages/pip (python 3.11)`
- OK julia: `julia version 1.9.0`

mason.nvim [GitHub] ~

- OK GitHub API rate limit. Used: 1. Remaining: 4999. Limit: 5000. Reset: Tue 06 Jun 2023 07:04:06 PM +07.

==============================================================================
null-ls: require("null-ls.health").check()

- OK dart_format: the command "dart" is executable.
- OK prettier: the command "prettier" is executable.
- OK checkmake: the command "checkmake" is executable.
- OK clang_check: the command "clang-check" is executable.
- refactoring: cannot verify if the command is an executable.
- OK gitsigns: the source "gitsigns" can be ran.

==============================================================================
nvim: require("nvim.health").check()

Configuration ~

- OK no issues found

Runtime ~

- OK $VIMRUNTIME: /home/linuxbrew/.linuxbrew/Cellar/neovim/0.9.1/share/nvim/runtime

Performance ~

- OK Build type: Release

Remote Plugins ~

- OK Up to date

terminal ~

- key_backspace (kbs) terminfo entry: `key_backspace=^H`
- key_dc (kdch1) terminfo entry: `key_dc=\E[3~`
- $TERM_PROGRAM="WezTerm"
- $COLORTERM="truecolor"

==============================================================================
nvim-treesitter: require("nvim-treesitter.health").check()

Installation ~

- OK `tree-sitter` found 0.20.8 (parser generator, only needed for :TSInstallFromGrammar)
- OK `node` found v20.2.0 (only needed for :TSInstallFromGrammar)
- OK `git` executable found.
- OK `cc` executable found. Selected from { vim.NIL, "cc", "gcc", "clang", "cl", "zig" }
  Version: cc (Ubuntu 12.2.0-17ubuntu1) 12.2.0
- OK Neovim was compiled with tree-sitter runtime ABI version 14 (required >=13). Parsers must be compatible with runtime ABI.

OS Info:
{
machine = "x86_64",
release = "6.2.0-20-generic",
sysname = "Linux",
version = "#20-Ubuntu SMP PREEMPT_DYNAMIC Thu Apr 6 07:48:48 UTC 2023"
} ~

Parser/Features H L F I J

- bash ✓ ✓ ✓ . ✓
- c ✓ ✓ ✓ ✓ ✓
- c_sharp ✓ ✓ ✓ . ✓
- cpp ✓ ✓ ✓ ✓ ✓
- css ✓ . ✓ ✓ ✓
- dart ✓ ✓ ✓ ✓ ✓
- dockerfile ✓ . . . ✓
- git_config ✓ . . . .
- gitattributes ✓ . . . ✓
- gitignore ✓ . . . .
- go ✓ ✓ ✓ ✓ ✓
- gomod ✓ . . . ✓
- gosum ✓ . . . .
- gowork ✓ . . . ✓
- html ✓ ✓ ✓ ✓ ✓
- java ✓ ✓ ✓ ✓ ✓
- javascript ✓ ✓ ✓ ✓ ✓
- json ✓ ✓ ✓ ✓ .
- lua ✓ ✓ ✓ ✓ ✓
- make ✓ . ✓ . ✓
- markdown ✓ . ✓ ✓ ✓
- proto ✓ . ✓ . .
- python ✓ ✓ ✓ ✓ ✓
- query ✓ ✓ ✓ ✓ ✓
- rust ✓ ✓ ✓ ✓ ✓
- scss ✓ . ✓ ✓ .
- sql ✓ . . ✓ ✓
- toml ✓ ✓ ✓ ✓ ✓
- typescript ✓ ✓ ✓ ✓ ✓
- vim ✓ ✓ ✓ . ✓
- vimdoc ✓ . . . ✓
- yaml ✓ ✓ ✓ ✓ ✓

Legend: H[ighlight], L[ocals], F[olds], I[ndents], In[j]ections
+) multiple parsers found, only one will be used
x) errors found in the query, try to run :TSUpdate {lang} ~

==============================================================================
provider: health#provider#check

Clipboard (optional) ~

- OK Clipboard tool found: xclip

Python 3 provider (optional) ~

- `g:python3_host_prog` is not set. Searching for python3 in the environment.
- Multiple python3 executables found. Set `g:python3_host_prog` to avoid surprises.
- Executable: /home/linuxbrew/.linuxbrew/bin/python3
- Other python executable: /usr/bin/python3
- Other python executable: /bin/python3
- Python version: 3.11.3
- pynvim version: 0.4.3
- OK Latest pynvim is installed.

Python virtualenv ~

- OK no $VIRTUAL_ENV

Ruby provider (optional) ~

- Ruby: ruby 3.2.2 (2023-03-30 revision e51014f9c0) [x86_64-linux]
- Host: /home/linuxbrew/.linuxbrew/lib/ruby/gems/3.2.0/bin/neovim-ruby-host
- OK Latest "neovim" gem is installed: 0.9.0

Node.js provider (optional) ~

- Node.js: v20.2.0
- Nvim node.js host: /home/linuxbrew/.linuxbrew/lib/node_modules/neovim/bin/cli.js
- OK Latest "neovim" npm/yarn/pnpm package is installed: 4.10.1

Perl provider (optional) ~

- Disabled (g:loaded_perl_provider=0).

==============================================================================
telescope: require("telescope.health").check()

Checking for required plugins ~

- OK plenary installed.
- OK nvim-treesitter installed.

Checking external dependencies ~

- OK rg: found ripgrep 13.0.0
- OK fd: found fd 8.7.0

===== Installed extensions ===== ~

==============================================================================
vim.lsp: require("vim.lsp.health").check()

- LSP log level : WARN
- Log path: /home/lavantien/.local/state/nvim/lsp.log
- Log size: 443 KB

vim.lsp: Active Clients ~

- No active clients

==============================================================================
vim.treesitter: require("vim.treesitter.health").check()

- Nvim runtime ABI version: 14
- OK Parser: bash ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/bash.so
- OK Parser: c ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/c.so
- OK Parser: c_sharp ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/c_sharp.so
- OK Parser: cpp ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/cpp.so
- OK Parser: css ABI: 13, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/css.so
- OK Parser: dart ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/dart.so
- OK Parser: dockerfile ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/dockerfile.so
- OK Parser: git_config ABI: 13, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/git_config.so
- OK Parser: gitattributes ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/gitattributes.so
- OK Parser: gitignore ABI: 13, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/gitignore.so
- OK Parser: go ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/go.so
- OK Parser: gomod ABI: 13, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/gomod.so
- OK Parser: gosum ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/gosum.so
- OK Parser: gowork ABI: 13, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/gowork.so
- OK Parser: html ABI: 13, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/html.so
- OK Parser: java ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/java.so
- OK Parser: javascript ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/javascript.so
- OK Parser: json ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/json.so
- OK Parser: lua ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/lua.so
- OK Parser: make ABI: 13, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/make.so
- OK Parser: markdown ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/markdown.so
- OK Parser: proto ABI: 13, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/proto.so
- OK Parser: python ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/python.so
- OK Parser: query ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/query.so
- OK Parser: rust ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/rust.so
- OK Parser: scss ABI: 13, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/scss.so
- OK Parser: sql ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/sql.so
- OK Parser: toml ABI: 13, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/toml.so
- OK Parser: typescript ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/typescript.so
- OK Parser: vim ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/vim.so
- OK Parser: vimdoc ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/vimdoc.so
- OK Parser: yaml ABI: 13, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/yaml.so
- OK Parser: c ABI: 14, path: /home/linuxbrew/.linuxbrew/Cellar/neovim/0.9.1/lib/nvim/parser/c.so
- OK Parser: lua ABI: 14, path: /home/linuxbrew/.linuxbrew/Cellar/neovim/0.9.1/lib/nvim/parser/lua.so
- OK Parser: query ABI: 14, path: /home/linuxbrew/.linuxbrew/Cellar/neovim/0.9.1/lib/nvim/parser/query.so
- OK Parser: vim ABI: 14, path: /home/linuxbrew/.linuxbrew/Cellar/neovim/0.9.1/lib/nvim/parser/vim.so
- OK Parser: vimdoc ABI: 14, path: /home/linuxbrew/.linuxbrew/Cellar/neovim/0.9.1/lib/nvim/parser/vimdoc.so

````

</details>

</details>

## Neovim Setup From Scratch

### Install

- Installed Neovim related packages as instructed in the Healthcheck section above
- Run `nvim` the first time to initialize plugins, then press `S` to sync packages
- Enter the `WakaTime Auth Key` in the Settings panel in the browser
- Enter the `Codeium Auth Key` provided by `:Codeium Auth`
- Run `:MasonUpdate` to install all registries
- Make sure to run `$ nvim +che` to ensure all dependencies are installed

### Key Bindings

- In Neovim Normal Mode, hit `:nmap` to see the list of all bindings
- To see bindings of a certain key, hit `:nmap <leader>`
- Or you can just use Telescope to do the deed `<leader>vk`, in this case, holding space and pressing `vk`

### Mason Built-in Packages to `:MasonInstall `

- All language `servers` and `treesitters` are pre-installed when you first initialize Neovim
- Some tools such as `prettier` are handled by the configured `null-ls` already
- see `.config/nvim/lua/plugins/init.lua`, `null-ls` section
- All 50 Packages:

```text
gopls delve staticcheck gotests golangci-lint golangci-lint-langserver go-debug-adapter gomodifytags impl rust-analyzer codelldb lua-language-server stylua luacheck clangd clang-format jdtls java-test java-debug-adapter google-java-format typescript-language-server js-debug-adapter chrome-debug-adapter html-lsp css-lsp tailwindcss-language-server pyright debugpy flake8 blue dart-debug-adapter csharp-language-server csharpier yaml-language-server yamllint yamlfmt buf-language-server buf terraform-ls sqlls sqlfluff sql-formatter tflint tfsec marksman ltex-ls vale proselint markdown-toc cbfmt
```

- Specific Languages:

<details>
	<summary>expand</summary>

- Go:

```text
gopls delve staticcheck gotests golangci-lint golangci-lint-langserver go-debug-adapter gomodifytags impl
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

- JavaScript:

```text
typescript-language-server js-debug-adapter chrome-debug-adapter
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

- Dart:

```text
dart-debug-adapter
```

- DotNet:

```text
csharp-language-server csharpier
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

</details>

### References

<details>
  <summary>expand</summary>

- 0 to LSP: <https://youtu.be/w7i4amO_zaE>
- Zero to IDE: <https://youtu.be/N93cTbtLCIM>
- Effective Neovim: Instant IDE: <https://youtu.be/stqUbv-5u2s>
- Kickstart.nvim: <https://github.com/nvim-lua/kickstart.nvim>
- Neovim Null-LS - Hooks For LSP | Format Code On Save: <https://youtu.be/ryxRpKpM9B4>
- Null-LS built-in: <https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTINS.md>
- Debugging in Neovim: <https://youtu.be/0moS8UHupGc>
- How to Debug like a Pro: <https://miguelcrespo.co/how-to-debug-like-a-pro-using-neovim>
- Nvim DAP getting started: <https://davelage.com/posts/nvim-dap-getting-started/>

</details>

## Handle Corrupted Providers

<details>
  <summary>expand</summary>

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

## Tested Machines

<details>
  <summary>expand</summary>

### My desktop:

```bash
            .-/+oossssoo+/-.               lavantien@savaka
        `:+ssssssssssssssssss+:`           ----------------
      -+ssssssssssssssssssyyssss+-         OS: Ubuntu 23.04 x86_64
    .ossssssssssssssssssdMMMNysssso.       Host: MS-7D42 1.0
   /ssssssssssshdmmNNmmyNMMMMhssssss/      Kernel: 6.2.0-20-generic
  +ssssssssshmydMMMMMMMNddddyssssssss+     Uptime: 8 hours, 4 mins
 /sssssssshNMMMyhhyyyyhmNMMMNhssssssss/    Packages: 2530 (dpkg), 162 (brew), 6 (flatpak), 26 (snap)
.ssssssssdMMMNhsssssssssshNMMMdssssssss.   Shell: zsh 5.9
+sssshhhyNMMNyssssssssssssyNMMMysssssss+   Resolution: 3840x2160
ossyNMMMNyMMhsssssssssssssshmmmhssssssso   DE: GNOME 44.0
ossyNMMMNyMMhsssssssssssssshmmmhssssssso   WM: Mutter
+sssshhhyNMMNyssssssssssssyNMMMysssssss+   WM Theme: Adwaita
.ssssssssdMMMNhsssssssssshNMMMdssssssss.   Theme: Yaru-dark [GTK2/3]
 /sssssssshNMMMyhhyyyyhdNMMMNhssssssss/    Icons: Yaru [GTK2/3]
  +sssssssssdmydMMMMMMMMddddyssssssss+     Terminal: WezTerm
   /ssssssssssshdmNNNNmyNMMMMhssssss/      CPU: 12th Gen Intel i7-12700F (20) @ 4.800GHz
    .ossssssssssssssssssdMMMNysssso.       GPU: NVIDIA GeForce RTX 3080 Lite Hash Rate
      -+sssssssssssssssssyyyssss+-         Memory: 6507MiB / 31930MiB
        `:+ssssssssssssssssss+:`
            .-/+oossssoo+/-.

Filesystem      Size  Used Avail Use% Mounted on
tmpfs           3.4G  3.1M  3.4G   1% /run
/dev/nvme0n1p2  983G  139G  794G  15% /
tmpfs            17G  1.2G   16G   7% /dev/shm
tmpfs           5.3M   17k  5.3M   1% /run/lock
/dev/nvme0n1p1  1.2G  6.4M  1.2G   1% /boot/efi
tmpfs            17G     0   17G   0% /run/qemu
tmpfs           3.4G  586k  3.4G   1% /run/user/1000
```

### My laptop:

```bash
            .-/+oossssoo+/-.               lavantien@savaka
        `:+ssssssssssssssssss+:`           ----------------
      -+ssssssssssssssssssyyssss+-         OS: Ubuntu 23.04 x86_64
    .ossssssssssssssssssdMMMNysssso.       Host: HP ProBook 445 G7
   /ssssssssssshdmmNNmmyNMMMMhssssss/      Kernel: 6.2.0-20-generic
  +ssssssssshmydMMMMMMMNddddyssssssss+     Uptime: 1 hour, 9 mins
 /sssssssshNMMMyhhyyyyhmNMMMNhssssssss/    Packages: 2487 (dpkg), 167 (brew), 6 (flatpak), 26 (snap)
.ssssssssdMMMNhsssssssssshNMMMdssssssss.   Shell: zsh 5.9
+sssshhhyNMMNyssssssssssssyNMMMysssssss+   Resolution: 1920x1080
ossyNMMMNyMMhsssssssssssssshmmmhssssssso   DE: GNOME 44.0
ossyNMMMNyMMhsssssssssssssshmmmhssssssso   WM: Mutter
+sssshhhyNMMNyssssssssssssyNMMMysssssss+   WM Theme: Adwaita
.ssssssssdMMMNhsssssssssshNMMMdssssssss.   Theme: Yaru-dark [GTK2/3]
 /sssssssshNMMMyhhyyyyhdNMMMNhssssssss/    Icons: Yaru [GTK2/3]
  +sssssssssdmydMMMMMMMMddddyssssssss+     Terminal: WezTerm
   /ssssssssssshdmNNNNmyNMMMMhssssss/      CPU: AMD Ryzen 7 4700U with Radeon Graphics (8) @ 2.000GHz
    .ossssssssssssssssssdMMMNysssso.       GPU: AMD ATI 05:00.0 Renoir
      -+sssssssssssssssssyyyssss+-         Memory: 4885MiB / 15374MiB
        `:+ssssssssssssssssss+:`
            .-/+oossssoo+/-.

Filesystem      Size  Used Avail Use% Mounted on
tmpfs           1.7G  2.6M  1.7G   1% /run
/dev/nvme0n1p2  502G  134G  344G  28% /
tmpfs           8.1G  155M  8.0G   2% /dev/shm
tmpfs           5.3M   13k  5.3M   1% /run/lock
tmpfs           8.1G     0  8.1G   0% /run/qemu
/dev/nvme0n1p1  1.2G  6.4M  1.2G   1% /boot/efi
tmpfs           1.7G  148k  1.7G   1% /run/user/1000
```

</details>
