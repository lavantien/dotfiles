# Neovim Cross-Platform Full IDE Minimal Setup From Scratch

## Install

- Git, GH CLI, Neovim, GCC/LLVM-Clang, Go, NodeJS, Bun, Python3, Rust, Lua, Java, SQLite, Docker, K8s, OpenTf
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
- Intellisense, Code Actions, Snippets, Debugging, Code Objects, Pin Headers, Display Statuses, Token Tree, Fuzzy Picker
- Surround, Autotag, Improved Floating UIs, Inline Diagnostics, Cute Statusbar, Multifiles Jumper, Refactoring
- Smart Folds, Autolint, Indentation Guides, Smart Help, Undo Tree, Git Integration, SQL/NoSQL Client, File Explorer
- Schemas Store, Pre-setup 3 themes - `Gruvbox`, `Tokyo Night`, `Pine Rose` - you can just uncomment any one of them

## Key Bindings

- In Neovim Normal Mode, hit `:nmap` to see the list of all bindings
- To see bindings of a certain key, hit `:nmap <leader>`
- Or you can just use Telescope to do the deed `<leader>vk`, in this case, holding space and pressing `vk`

## Plugins List

<details>
	<summary>Loaded (47)</summary>

- cmp-nvim-lsp 0.03ms  lsp-zero.nvim
- dressing.nvim 1.11ms  start
- fidget.nvim 1.47ms  lsp-zero.nvim
- gitsigns.nvim 0.1ms  start
- gruvbox.nvim 3.6ms  start
- harpoon 7.54ms  start
- indent-blankline.nvim 1.33ms  start
- lazy.nvim 7.49ms  init.lua
- lsp-zero.nvim 73.62ms  start
- lspkind.nvim 0.08ms  lsp-zero.nvim
- lualine.nvim 3.14ms  start
- LuaSnip 2.5ms  lsp-zero.nvim
- mason-lspconfig.nvim 0.07ms  lsp-zero.nvim
- mason-null-ls.nvim 0.17ms  lsp-zero.nvim
- mason-nvim-dap.nvim 0.15ms  lsp-zero.nvim
- mason-tool-installer.nvim 2.61ms  lsp-zero.nvim
- mason.nvim 0.9ms  lsp-zero.nvim
- mini.nvim 2.69ms  start
- neodev.nvim 1.52ms  lsp-zero.nvim
- none-ls.nvim 0.15ms  lsp-zero.nvim
- nvim-cmp 1.04ms  lsp-zero.nvim
- nvim-dap 0.32ms  lsp-zero.nvim
- nvim-dap-go 0.16ms  lsp-zero.nvim
- nvim-dap-ui 0.17ms  lsp-zero.nvim
- nvim-dap-virtual-text 0.08ms  lsp-zero.nvim
- nvim-lspconfig 0.31ms  lsp-zero.nvim
- nvim-nio 0.21ms  lsp-zero.nvim
- nvim-treesitter 7.73ms  refactoring.nvim
- nvim-treesitter-context 0.71ms  start
- nvim-ts-autotag 2.32ms  nvim-treesitter
- nvim-ufo 19.47ms  start
- nvim-web-devicons 0.17ms  oil.nvim
- oil.nvim 2.34ms  start
- playground 0.56ms  start
- plenary.nvim 0.21ms  harpoon
- promise-async 0.24ms  nvim-ufo
- refactoring.nvim 10.17ms  start
- render-markdown 6.72ms  start
- SchemaStore.nvim 0.05ms  lsp-zero.nvim
- telescope.nvim 0.32ms  harpoon
- trouble.nvim 2.48ms  start
- undotree 0.28ms  start
- vim-dadbod 0.2ms  start
- vim-dadbod-completion 0.12ms  start
- vim-dadbod-ui 0.23ms  start
- vimtex 0.45ms  start
- which-key.nvim 6.27ms  VimEnter

</details>

## Languages Packages List

<details>
	<summary>Installed (61)</summary>

- ansible-language-server ansiblels
- bash-language-server bashls
- blue
- buf
- buf-language-server bufls
- cbfmt
- clang-format
- clangd
- codelldb
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
- golangci-lint-langserver golangci_lint_ls
- gomodifytags
- google-java-format
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
- json-lsp jsonls
- ltex-ls ltex
- lua-language-server lua_ls
- markdown-toc
- marksman
- neocmakelsp neocmake
- powershell-editor-services powershell_es
- prettier
- pyright
- rust-analyzer rust_analyzer
- snyk-ls snyk_ls
- sql-formatter
- sqlfluff
- sqlls
- staticcheck
- stylua
- tailwindcss-language-server tailwindcss
- taplo
- terraform-ls terraformls
- tflint
- tfsec
- typescript-language-server tsserver
- typos-lsp typos_lsp
- vue-language-server volar
- yaml-language-server yamlls
- yamlfmt
- yamllint

</details>

## References

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

![neovim-demo](https://github.com/lavantien/dotfiles/blob/main/assets/neovim-demo.png)
