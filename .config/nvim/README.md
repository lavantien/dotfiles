This project is now moved to the [dotfiles](https://github.com/lavantien/dotfiles), all my configs will be maintained there instead

# Neovim Config

## Usage

- Install `linuxbrew` and then `$ brew install neovim`
- Make sure to run `$ nvim +checkhealth` to ensure all dependencies are
  installed
- `$ nvim +PackerSync` to sync plugins to local machine

## References

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

## Key Bindings

- In Neovim Normal Mode, hit `:nmap` to see the list of all bindings
- To see bindings of a certain key, hit `:nmap <leader>`
- Or you can just use Telescope to do the deed `<leader>vk`, in this case, holding the space bar and pressing `vk`
