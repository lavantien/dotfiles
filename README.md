## Restore Neovim original state

```bash
rm -rf ~/.config/nvim && rm -rf ~/.local/share/nvim && rm -rf ~/.cache/nvim
```

## Install Neovim

```bash
sudo add-apt-repository ppa:neovim-ppa/unstable
sudo apt update && sudo apt install neovim
nvim +checkhealth
```

## Install Vim Plug

<https://github.com/junegunn/vim-plug>

## Load init.vim into ~/.config/nvim/; source $MYVIMRC; run :PlugInstall

