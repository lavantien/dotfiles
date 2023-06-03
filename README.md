# My Linux Dotfiles - New Linux Environment Setup

## Requirements

- chrome (deb), xclip (apt), git (apt), curl (apt), zsh (apt), ohmyzsh (script)
- brew (script), gcc (brew), flathub (apt & script)
- wezterm (brew), vim (apt), neovim (brew), shortcut wmclass
- zsh-autosuggests (git), fzf (brew), ripgrep (brew), bat (brew)
- go (brew), lazygit (brew)
- iosevka nf (nerd-fonts), noto sans sc (google), deng xian (fontke)
- joplin (script), clone all (gh & script)
- docker compose (ppa), kubectl (ppa), minikube (deb), python2 (source)
- rust (script), openjdk (brew), ruby (brew), lua (brew), maven (brew), node (brew), gopls (brew), rust-analyzer (brew), jdtls (brew), lua-language-server (brew), vscode-langservers-extracted (brew)
- yaml-language-server (brew), bash-language-server (brew), terraform (brew), terraform-ls (brew), prettier (brew), nvim +che deps
- nvidia vulkan (ppa & apt), wine (ppa), lutris (deb), mangohud (source), mpv (apt)
- battlenet (lutris), diablo-2-resurrected (battlenet)
- steam (apt), obs (ppa), blender (snap), gimp (flatpak), inkscape (snap)

## Neovim Deps (fresh 100% OK)

```bash
npm i -g neovim
cpan App::cpanminus
cpanm Neovim::Ext
pip3 install neovim
sudo apt install ubuntu-dev-tools
brew install gcc@11
gem install neovim
```

## Google Cloud CLI (broken python2 dep)

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
```
