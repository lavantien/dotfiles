# Neovim Cross-Platform Full IDE Minimal Setup From Scratch

## Install

- Git, GH CLI, Neovim, GCC/LLVM-Clang, Go, NodeJS, Python3, Rust, Lua, Java, SQLite, Docker, K8s, OpenTf
- Neovim Deps:

```bash
npm i -g neovim && pip3 install neovim
```

- If you're on Windows you need to
  - remove `make install_jsregexp` from `luasnip` build config
  - remove `checkmake`, `luacheck`, `semgrep`, `ansible-lint`, or other packages that don't support Windows from `mason-tools-installer` list
  - set the `HOME` environment variable to `C:\Users\<name>`
  - copy `.config/nvim` directory to `C:\Users\<name>\AppData\Local\`
  - add to `PATH` this value `C:\Users\<name>\AppData\Local\nvim-data\mason\bin`
  - install [sqlite3](https://gist.github.com/zeljic/d8b542788b225b1bcb5fce169ee28c55), rename `sqlite3.dll` to `libsqlite3.dll` and `sqlite3.lib` to `libsqlite3.lib`, and add its location to`PATH`
- Run `nvim` the first time and wait for it to auto initialize plugins, then press `S` to sync packages
- Run `:MasonUpdate` to install all registries, then `:Mason` and press `U` if there's any update
- All language `servers`, `linters`, and `treesitters` are pre-installed when you first initialize Neovim
- Make sure to run `$ nvim +che` to ensure all related dependencies are installed

## Features

- Fully support lua, go, javascript/typescript & vue, html/htmx & css/tailwind, python, c/cpp, rust, java, assembly, markdown, latex & typos, bash, make & cmake, json, yaml, toml, sql, protobuf, graphql, docker/compose, ci/cd, kubernetes/helm, ansible, opentofu
- Intellisense, Code Actions, Snippets, Debugging, Hints, Code Objects, Pin Headers, Display Statuses, Token Tree, Fuzzy Picker
- Surround, Autotag, Improved Floating UIs, Inline Diagnostics, Inline Eval, Statusbar, Multifiles Jumper, Refactoring, Clues
- Smart Folds, Autolint, Indentation Guides, Smart Help, Undo Tree, Git Integration, SQL/NoSQL Client, File Explorer, Cellular Automaton
- Schemas Store, Pre-setup 3 themes - `Gruvbox`, `Tokyo Night`, `Pine Rose`

## Key Bindings

- In Neovim Normal Mode, hit `:nmap` to see the list of all bindings
- Or via Telescope `<leader>vk`, in this case, hit space and pressing `vk`
- Key clue support, just hit any key and a popup will appear to guide you
- Check `~/.config/nvim/lua/config/remap.lua` for detailed information

## Plugins List

<details>
	<summary>Loaded (55)</summary>

- cellular-automaton.nvim 0.26ms  start
- cmp-buffer 0.11ms  nvim-cmp
- cmp-nvim-lsp 0.13ms  nvim-cmp
- cmp-nvim-lsp-signature-help 0.1ms  nvim-cmp
- cmp-path 0.11ms  nvim-cmp
- cmp_luasnip 0.09ms  nvim-cmp
- dressing.nvim 0.91ms  start
- fidget.nvim 1.6ms  lsp-zero.nvim
- gitsigns.nvim 0.08ms  start
- gruvbox.nvim 3.17ms  start
- harpoon 7.64ms  start
- indent-blankline.nvim 1.14ms  start
- lazy.nvim 5.39ms  init.lua
- lsp-zero.nvim 85.19ms  start
- lspkind.nvim 0.1ms  nvim-cmp
- lualine.nvim 3.96ms  start
- LuaSnip 4.12ms  nvim-cmp
- mason-lspconfig.nvim 0.07ms  lsp-zero.nvim
- mason-null-ls.nvim 0.14ms  lsp-zero.nvim
- mason-nvim-dap.nvim 0.15ms  lsp-zero.nvim
- mason-tool-installer.nvim 2.12ms  lsp-zero.nvim
- mason.nvim 1.26ms  lsp-zero.nvim
- mini.nvim 2.66ms  start
- neodev.nvim 2.48ms  lsp-zero.nvim
- none-ls.nvim 0.14ms  lsp-zero.nvim
- nvim-cmp 5.98ms  start
- nvim-dap 0.29ms  lsp-zero.nvim
- nvim-dap-go 0.15ms  lsp-zero.nvim
- nvim-dap-ui 0.19ms  lsp-zero.nvim
- nvim-dap-virtual-text 0.33ms  lsp-zero.nvim
- nvim-lspconfig 1.59ms  lsp-zero.nvim
- nvim-nio 0.31ms  lsp-zero.nvim
- nvim-treesitter 7.02ms  render-markdown
- nvim-treesitter-context 0.68ms  start
- nvim-ts-autotag 2.04ms  nvim-treesitter
- nvim-ufo 16.01ms  start
- nvim-web-devicons 0.26ms  oil.nvim
- oil.nvim 1.73ms  start
- playground 1.72ms  start
- plenary.nvim 0.25ms  harpoon
- promise-async 0.3ms  nvim-ufo
- refactoring.nvim 4.58ms  start
- render-markdown 13.86ms  start
- SchemaStore.nvim 0.06ms  lsp-zero.nvim
- smart-open.nvim 11.81ms  start
- sqlite.lua 0.34ms  smart-open.nvim
- telescope-fzf-native.nvim 0.27ms  smart-open.nvim
- telescope-fzy-native.nvim 0.28ms  smart-open.nvim
- telescope.nvim 0.45ms  harpoon
- trouble.nvim 1.59ms  start
- undotree 0.36ms  start
- vim-dadbod 0.26ms  start
- vim-dadbod-completion 0.15ms  start
- vim-dadbod-ui 0.27ms  start
- vimtex 0.42ms  start

</details>

## Languages Packages List

<details>
	<summary>Installed (69)</summary>

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
"clang-format",
"cpptools",

-- rust
"rust_analyzer",
"codelldb",

-- java
"jdtls",
"java-test",
"google-java-format",
"java-debug-adapter",

-- assembly
"asm-lsp",
"asmfmt",

-- markdown
"marksman",
"cbfmt",

-- latex & typos
"texlab",
"typos_lsp",

-- bash
"bashls",
"shellcheck",
"shfmt",
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
