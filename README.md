# A robust Dotfiles - Scientific, Optimize, and Minimal

Quality Assurance by myself: **90%**

## Step by Step for a Fresh Ubuntu 23.04+

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
sudo systemctl daemon-reexec
```

`reboot`

### 1. Install all necessary `APT` packages

```bash
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt install apt-transport-https ubuntu-dev-tools glibc-source gcc xclip git curl zsh htop neofetch vim mpv libutf8proc2 libutf8proc-dev libfuse2 cpu-checker screenkey -y
```

### 2. Install `Oh-my-zsh` and `Chrome`, then `reboot`

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

```bash
cd ~Downloads && wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && sudo dpkg -i google-chrome-stable_current_amd64.deb && rm google-chrome-stable_current_amd64.deb && cd ~
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
git clone https://github.com/lavantien/dotfiles.git ~/temp && mv -v {~/temp/*,~/temp/.*} ~/ && cd ~/temp/.config && mv -v * ~/.config/ && cd ~ && cd ~/temp/.local/share/applications && mv * ~/.local/share/applications && cd ~ && source ~/.zshrc
```

### 6. Install `rust` and its toolchains, then `reboot`

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### 7. Install `gcc`, `gh`, `neovim`, and other necessary `Brew` packages

```bash
brew install gcc@11 gcc gh go lazygit fzf fd ripgrep bat neovim hyperfine openjdk ruby lua maven node gopls rust-analyzer jdtls lua-language-server yaml-language-server bash-language-server terraform terraform-ls prettier delve vscode-langservers-extracted loc llvm dotenv-linter checkmake luarocks php composer
```

```bash
sudo snap install julia --classic
```

Currently, `julia` build is failed on `brew`, use `snap` instead

### 8. Install `Joplin (snap)`, sync your notes, and setup your `Git` environment:

For a smooth `Git` experience, you should make a `.netrc` file in your home directory and add auth token:  
`machine github.com login lavantien password ghp_klsdfjalsdkfjdsjfalsdkldasfjkasldfjalsdfjalsdjfk`  
For `gh`, run `gh auth login` and follow instruction to setup `GitHub CLI`

### 9. Run `./git-clone-all your-github-username` on `~/dev/personal` for cloning all of your repos

```bash
mkdir -p ~/dev/personal && cp ~/git-clone-all.sh ~/dev/personal/ && cd ~/dev/personal && ./git-clone-all.sh your-github-username && cd ~
```

### 10. Install `Iosevka Nerd Font` (replace version `v3.0.1` with whatever latest)

```bash
cd ~/Downloads && wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.1/Iosevka.zip && mkdir Iosevka && unzip Iosevka.zip -d Iosevka && cd Iosevka && sudo mkdir -p /usr/share/fonts/truetype/iosevka-nerd-font && sudo cp *.ttf /usr/share/fonts/truetype/iosevka-nerd-font/ && cd .. && rm -r Iosevka Iosevka.zip && cd ~ && sudo fc-cache -f -v
```

### 11. Install `wezterm`

```bash
brew tap wez/wezterm-linuxbrew
```

```bash
brew install wezterm
```

### 12. Install `GRPC`, `GRPC-Web`, and `protoc-gen`

```bash
brew install grpc protoc-gen-grpc-web
```

```bash
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
```

```bash
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
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

### 15. Install `Qemu KVM`

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo && kvm-ok
```

```bash
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
```

### 16. Install `Android Studio`, `Android SDK`, and `Flutter`

```bash
sudo snap install android-studio --classic
```

Run `Android Studio` and install default configuration, then click `More Actions` -> `SDK Manager` -> `SDK Tools` -> tick `Android SDK Build-Tools` and `Android SDK Command-line Tools` -> `Apply` and `OK`

```bash
sudo snap install flutter --classic
```

```bash
flutter doctor && flutter doctor --android-licenses
```

### 17. Install `Kreya` and `DBbGate`

```bash
sudo snap install kreya dbgate
```

### 18. Install `Docker Compose`, `FlatHub`, and `Vulkan`, then `reboot`

### 19. Install `kubectl`, and `minikube`

### 20. Install `Wine`, `Lutris`, and `MangoHUD`

### 21. Install `OBS`, `Gimp`, `Inkscape`, `LibreOffice`, `Blender`

### 22. Install `Steam`, `Battlenet`, and `Diablo 2 Resurrected`

## Healthcheck

### Flutter Doctor

```bash
flutter doctor
```

<details>
  <summary>expand result</summary>

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

</details>

### MiniKube

```bash
minikube start
```

<details>
  <summary>expand result</summary>

```bash

```

</details>

```bash
minikube stop
```

### Neovim Deps (fresh 100% OK)

```bash
npm i -g neovim
```

```bash
cpan App::cpanminus
```

```bash
pip3 install neovim
```

```bash
sudo apt install ubuntu-dev-tools
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

````

</details>

## Neovim Setup From Scratch

### Usage

- Installed Neovim related package as instructed in the Checkhealth section above
- Run `nvim` the first time to initialize plugins, then press `S` to sync packages
- Enter the `WakaTime Auth Key` in the Settings panel in the browser
- Enter the `Codeium Auth Key` provided by `:Codeium Auth`
- Run `:MasonUpdate` to install all registries
- Make sure to run `$ nvim +che` to ensure all dependencies are installed

### Key Bindings

- In Neovim Normal Mode, hit `:nmap` to see the list of all bindings
- To see bindings of a certain key, hit `:nmap <leader>`
- Or you can just use Telescope to do the deed `<leader>vk`, in this case, holding the space bar and pressing `vk`

### References

<details>
  <summary>expand</summary>

- 0 to LSP: <https://youtu.be/w7i4amO_zaE>
- Zero to IDE: <https://youtu.be/N93cTbtLCIM>
- Effective Neovim: Instant IDE: <https://youtu.be/stqUbv-5u2s>
- Kickstart.nvim: <https://github.com/nvim-lua/kickstart.nvim>
- Neovim Null-LS - Hooks For LSP | Format Code On Save:
  <https://youtu.be/ryxRpKpM9B4>
- Null-LS built-in:
  <https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTINS.md>
- Debugging in Neovim: <https://youtu.be/0moS8UHupGc>
- How to Debug like a Pro: <https://miguelcrespo.co/how-to-debug-like-a-pro-using-neovim>
- Nvim DAP getting started: <https://davelage.com/posts/nvim-dap-getting-started/>

</details>

## Fix Google Cloud CLI (broken installation & missing python2 dep)

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
