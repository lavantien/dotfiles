## Necessary Programs

1. ubuntu23.04, chrome (deb), xclip (apt), git (apt), curl (apt), zsh (apt), ohmyzsh (script)
2. htop (apt), neofetch (apt), brew (script), gcc@11 (brew), gcc (brew), flathub (apt & script)
3. wezterm (brew), vim (apt), neovim (brew), shortcut wmclass
4. zsh-autosuggestions (git), fzf (brew), ripgrep (brew), bat (brew)
5. go (brew), lazygit (brew), hyperfine (brew), screenkey (brew)
6. iosevka nf (nerd-fonts), noto sans sc (google), deng xian (fontke)
7. joplin (script), clone all (gh & script)
8. docker compose (ppa), kubectl (ppa), minikube (deb), python2 (source)
9. rust (script), openjdk (brew), ruby (brew), lua (brew), maven (brew), node (brew)
10. gopls (brew), rust-analyzer (brew), jdtls (brew), lua-language-server (brew)
11. yaml-language-server (brew), bash-language-server (brew), terraform (brew), terraform-ls (brew)
12. prettier (brew), delve (brew), vscode-langservers-extracted (brew), nvim +che deps
13. nvidia vulkan (ppa & apt), wine (ppa), lutris (deb), mangohud (source), mpv (apt), loc (brew)
14. llvm (brew), vscode (dep), codelldb (vscode), flutter (snap), android-studio (snap)
15. helix (brew), hx --health, kreya (snap), dbgate (snap), dotenv-linter (brew), checkmake (brew)
16. battlenet (lutris), diablo-2-resurrected (battlenet)
17. steam (apt), obs (ppa), blender (snap), gimp (flatpak), inkscape (snap)

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

## Neovim Setup From Scratch

### Usage

- Install `linuxbrew` and then `$ brew install neovim`
- Make sure to run `$ nvim +che` to ensure all dependencies are
  installed

### References

- 0 to LSP: <https://youtu.be/w7i4amO_zaE>
- ThePrimeagen's Neovim Config: <https://github.com/ThePrimeagen/init.lua>
- Effective Neovim: Instant IDE: <https://youtu.be/stqUbv-5u2s>
- TJ DeVries's Kickstart.nvim: <https://github.com/nvim-lua/kickstart.nvim>
- Neovim Null-LS - Hooks For LSP | Format Code On Save:
  <https://youtu.be/ryxRpKpM9B4>
- Null-LS built-in:
  <https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTINS.md>
- Debugging in Neovim: <https://youtu.be/0moS8UHupGc>
- How to Debug like a Pro: <https://miguelcrespo.co/how-to-debug-like-a-pro-using-neovim>
- Nvim DAP getting started: <https://davelage.com/posts/nvim-dap-getting-started/>
- Structuring your plugins: <https://github.com/folke/lazy.nvim#-structuring-your-plugins>

### Key Bindings

- In Neovim Normal Mode, hit `:nmap` to see the list of all bindings
- To see bindings of a certain key, hit `:nmap <leader>`
- Or you can just use Telescope to do the deed `<leader>vk`, in this case, holding the space bar and pressing `vk`

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
`
```
