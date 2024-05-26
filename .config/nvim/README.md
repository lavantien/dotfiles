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
  - remove `make install_jsregexp` from `luasnip` build config
- Run `nvim` the first time and wait for it to auto initialize plugins, then press `S` to sync packages
- Run `:MasonUpdate` to install all registries, then `:Mason` and press `U` if there's any update
- All language `servers`, `linters`, and `treesitters` are pre-installed when you first initialize Neovim
- Make sure to run `$ nvim +che` to ensure all related dependencies are installed

## Features

- Fully support lua, go, javascript/typescript & vue, html/htmx & css/tailwind, python, c/cpp, rust, java, markdown, latex & typos, bash, make & cmake, json, yaml, toml, sql, protobuf, graphql, docker, kubernetes, ansible, opentofu
- Intellisense, Code Actions, Snippets, Debugging, Code Objects, Pin Headers, Display Statuses, Token Tree, Fuzzy Picker
- Surround, Autotag, Improved Floating UIs, Inline Diagnostics, Cute Statusbar, Multifiles Jumper, Refactoring
- Smart Folds, Autolint, Indentation Guides, Smart Help, Undo Tree, Git Integration, SQL/NoSQL Client, File Explorer
- Schemas Store, Pre-setup 3 themes - `Gruvbox`, `Tokyo Night`, `Pine Rose` - you can just uncomment any one of them

## Key Bindings

- In Neovim Normal Mode, hit `:nmap` to see the list of all bindings
- Or via Telescope `<leader>vk`, in this case, hit space and pressing `vk`
- Which-key support, just hit any key and a popup will appear to guide you
- Check `~/.config/nvim/lua/config/remap.lua` for detailed information

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
	<summary>Installed (55)</summary>

```lua
-- lua
"lua_ls",
"stylua",

-- go
"gopls",
"gotests",
"impl",
"gomodifytags",
"goimports-reviser",
"staticcheck",
"golangci_lint_ls",
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

-- c/cpp
"clangd",
"clang-format",

-- rust
"rust_analyzer",
"codelldb",

-- java
"jdtls",
"java-test",
"google-java-format",
"java-debug-adapter",

-- markdown
"marksman",
"cbfmt",

-- latex & typos
"ltex",
"typos_lsp",

-- bash
"bashls",

-- make & cmake
"neocmake",
"checkmake",

-- json
"jsonls", -- with schemastore

-- yaml
"yamlls", -- with schemastore
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

-- graphql
"graphql",

-- docker
"dockerls",
"docker_compose_language_service",

-- kubernetes
"helm_ls",

-- ansible
"ansiblels",

-- opentofu
"terraformls",
"tflint",
```

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
