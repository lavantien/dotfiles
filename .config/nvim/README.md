# Neovim Cross-Platform Full IDE Minimal Setup From Scratch

## Install

- Git, GH CLI, Neovim, GCC/LLVM-Clang, Go, NodeJS, Python3, Rust, Lua, Java, SQLite, Docker, K8s, OpenTofu
- Neovim Deps:

```bash
npm i -g neovim && pip3 install neovim
```

- If you're on Windows you need to
    - set the `HOME` environment variable to `C:\Users\<name>`
    - copy `.config/nvim` directory to `C:\Users\<name>\AppData\Local\`
    - add to `PATH` this value `C:\Users\<name>\AppData\Local\nvim-data\mason\bin`
- Run `nvim` the first time and wait for it to auto initialize plugins, then press `S` to sync packages
- Run `:MasonUpdate` to install all registries, then `:Mason` and press `U` if there's any update
- All language `servers`, `linters`, and `treesitters` are pre-installed when you first initialize Neovim
- Make sure to run `$ nvim +che` to ensure all related dependencies are installed

## Features

- Fully support Go, Rust, Lua, JavaScript/TypeScript, Python, Java, HTML/CSS, LaTeX, Markdown and DevOps techs
- Intellisense, Snippets, Debugging, Code Objects, Pin Headers, Display Statuses, Disect Token Tree, Fuzzy Picker
- Surround, Autotag, Improved Floating UIs, Inline Diagnostics, Cute Statusbar, Multifiles Jumper, Refactoring
- Autolint, Rainbow Indentation, Smart Help, Disect Undo Tree, Git Integration, SQL/NoSQL Client, File Explorer
- Pre-setup 3 themes - `Gruvbox`, `Tokyo Night`, `Pine Rose` - you can just uncomment any one of them

## Key Bindings

- In Neovim Normal Mode, hit `:nmap` to see the list of all bindings
- To see bindings of a certain key, hit `:nmap <leader>`
- Or you can just use Telescope to do the deed `<leader>vk`, in this case, holding space and pressing `vk`

## Plugins List

<details>
	<summary>expand</summary>

  Loaded (44)
    ● cmp-nvim-lsp 0.17ms  lsp-zero.nvim
    ● dressing.nvim 17.06ms  start
    ● fidget.nvim 118.89ms  lsp-zero.nvim
    ● gitsigns.nvim 0.11ms  start
    ● gruvbox.nvim 161.28ms  start
    ● harpoon 153.73ms  start
    ● indent-blankline.nvim 54.39ms  start
    ● lazy.nvim 12562.18ms  init.lua
    ● lsp-zero.nvim 2070.3ms  start
    ● lspkind.nvim 0.16ms  lsp-zero.nvim
    ● lualine.nvim 106.7ms  start
    ● LuaSnip 147.14ms  lsp-zero.nvim
    ● mason-lspconfig.nvim 1.13ms  lsp-zero.nvim
    ● mason-null-ls.nvim 1.44ms  lsp-zero.nvim
    ● mason-nvim-dap.nvim 1.79ms  lsp-zero.nvim
    ● mason-tool-installer.nvim 16.63ms  lsp-zero.nvim
    ● mason.nvim 56.47ms ✔ build
    ● mini.nvim 272.08ms  start
    ● neodev.nvim 39.81ms  lsp-zero.nvim
    ● none-ls.nvim 1.4ms  lsp-zero.nvim
    ● nvim-cmp 42.43ms  lsp-zero.nvim
    ● nvim-dap 6.75ms  lsp-zero.nvim
    ● nvim-dap-go 1.73ms  lsp-zero.nvim
    ● nvim-dap-ui 1.64ms  lsp-zero.nvim
    ● nvim-dap-virtual-text 0.2ms  lsp-zero.nvim
    ● nvim-lspconfig 6.99ms  lsp-zero.nvim
    ● nvim-nio 1.61ms  lsp-zero.nvim
    ● nvim-treesitter 571.7ms ✔ build
    ● nvim-treesitter-context 29.32ms  start
    ● nvim-ts-autotag 89.84ms  nvim-treesitter
    ● nvim-web-devicons 12.91ms  oil.nvim
    ● oil.nvim 250.59ms  start
    ● playground 12.05ms  start
    ● plenary.nvim 4.39ms  harpoon
    ● refactoring.nvim 300.19ms  start
    ● render-markdown 53.32ms  start
    ● telescope.nvim 6.31ms  harpoon
    ● trouble.nvim 57.26ms  start
    ● undotree 7.72ms  start
    ● vim-dadbod 5.96ms  start
    ● vim-dadbod-completion 5.45ms  start
    ● vim-dadbod-ui 153.69ms  start
    ● vimtex 17.99ms  start
    ● which-key.nvim 74.55ms  VimEnter

</details>

## Languages Packages List

<details>
	<summary>expand</summary>

  Installed
    ◍ ansible-language-server ansiblels
    ◍ bash-language-server bashls
    ◍ blue
    ◍ buf
    ◍ buf-language-server bufls
    ◍ cbfmt
    ◍ chrome-debug-adapter
    ◍ clang-format
    ◍ clangd
    ◍ codelldb
    ◍ css-lsp cssls
    ◍ debugpy
    ◍ delve
    ◍ docker-compose-language-service docker_compose_language_service
    ◍ dockerfile-language-server dockerls
    ◍ emmet-language-server emmet_language_server
    ◍ eslint-lsp eslint
    ◍ firefox-debug-adapter
    ◍ flake8
    ◍ go-debug-adapter
    ◍ goimports-reviser
    ◍ golangci-lint-langserver golangci_lint_ls
    ◍ gomodifytags
    ◍ google-java-format
    ◍ gopls
    ◍ gotests
    ◍ graphql-language-service-cli graphql
    ◍ helm-ls helm_ls
    ◍ html-lsp html
    ◍ htmx-lsp htmx
    ◍ impl
    ◍ java-debug-adapter
    ◍ java-test
    ◍ jdtls
    ◍ js-debug-adapter
    ◍ json-lsp jsonls
    ◍ ltex-ls ltex
    ◍ lua-language-server lua_ls
    ◍ markdown-toc
    ◍ marksman
    ◍ neocmakelsp neocmake
    ◍ powershell-editor-services powershell_es
    ◍ prettier
    ◍ proselint
    ◍ pyright
    ◍ rust-analyzer rust_analyzer
    ◍ snyk-ls snyk_ls
    ◍ sql-formatter
    ◍ sqlfluff
    ◍ sqlls
    ◍ staticcheck
    ◍ stylua
    ◍ tailwindcss-language-server tailwindcss
    ◍ taplo
    ◍ terraform-ls terraformls
    ◍ tflint
    ◍ tfsec
    ◍ typescript-language-server tsserver
    ◍ typos-lsp typos_lsp
    ◍ vale
    ◍ vue-language-server volar
    ◍ yaml-language-server yamlls
    ◍ yamlfmt
    ◍ yamllint

</details>

## References

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

![neovim-demo](https://github.com/lavantien/dotfiles/blob/main/assets/neovim-demo.png)
