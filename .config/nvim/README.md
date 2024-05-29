# Neovim Cross-Platform Full IDE Minimal Setup From Scratch

## Install

- Git, GH CLI, Neovim, GCC/LLVM-Clang, Go, NodeJS, Python3, Rust, Lua, Java, SQLite, Docker, K8s, OpenTf
- Neovim Deps:

```bash
npm i -g neovim && pip3 install neovim
```

- If you're on Windows you need to
  - set the `HOME` environment variable to `C:\Users\<name>`
  - copy `.config/nvim` directory to `C:\Users\<name>\AppData\Local\`
  - add to `PATH` this value `C:\Users\<name>\AppData\Local\nvim-data\mason\bin`
  - remove `make install_jsregexp` from `luasnip` build config
  - remove `checkmake`, `luacheck`, `semgrep`, `ansible-lint`, or other packages that don't support Windows from `mason-tools-installer` list
- Run `nvim` the first time and wait for it to auto initialize plugins, then press `S` to sync packages
- Run `:MasonUpdate` to install all registries, then `:Mason` and press `U` if there's any update
- All language `servers`, `linters`, and `treesitters` are pre-installed when you first initialize Neovim
- Make sure to run `$ nvim +che` to ensure all related dependencies are installed

## Features

- Fully support lua, go, javascript/typescript & vue, html/htmx & css/tailwind, python, c/cpp, rust, java, assembly, markdown, latex & typos, bash, make & cmake, json, yaml, toml, sql, protobuf, graphql, docker/compose, ci/cd, kubernetes/helm, ansible, opentofu
- Intellisense, Code Actions, Snippets, Debugging, Code Objects, Pin Headers, Display Statuses, Token Tree, Fuzzy Picker
- Surround, Autotag, Improved Floating UIs, Inline Diagnostics, Inline Eval, Statusbar, Multifiles Jumper, Refactoring, Clues
- Smart Folds, Autolint, Indentation Guides, Smart Help, Undo Tree, Git Integration, SQL/NoSQL Client, File Explorer
- Schemas Store, Pre-setup 3 themes - `Gruvbox`, `Tokyo Night`, `Pine Rose`

## Key Bindings

- In Neovim Normal Mode, hit `:nmap` to see the list of all bindings
- Or via Telescope `<leader>vk`, in this case, hit space and pressing `vk`
- Key clue support, just hit any key and a popup will appear to guide you
- Check `~/.config/nvim/lua/config/remap.lua` for detailed information

## Plugins List

<details>
	<summary>Loaded (50)</summary>

- cmp-nvim-lsp 0.05ms  lsp-zero.nvim
- dressing.nvim 0.7ms  start
- fidget.nvim 1.99ms  lsp-zero.nvim
- gitsigns.nvim 0.08ms  start
- gruvbox.nvim 3.43ms  start
- harpoon 6.64ms  start
- indent-blankline.nvim 2.53ms  start
- lazy.nvim 6.41ms  init.lua
- lsp-zero.nvim 77.49ms  start
- lspkind.nvim 0.04ms  lsp-zero.nvim
- lualine.nvim 4.97ms  start
- LuaSnip 3.31ms  lsp-zero.nvim
- mason-lspconfig.nvim 0.04ms  lsp-zero.nvim
- mason-null-ls.nvim 0.19ms  lsp-zero.nvim
- mason-nvim-dap.nvim 0.19ms  lsp-zero.nvim
- mason-tool-installer.nvim 1.18ms  lsp-zero.nvim
- mason.nvim 0.95ms  lsp-zero.nvim
- mini.nvim 4.28ms  start
- neodev.nvim 1.23ms  lsp-zero.nvim
- none-ls.nvim 0.17ms  lsp-zero.nvim
- nvim-cmp 0.97ms  lsp-zero.nvim
- nvim-dap 0.31ms  lsp-zero.nvim
- nvim-dap-go 0.19ms  lsp-zero.nvim
- nvim-dap-ui 0.18ms  lsp-zero.nvim
- nvim-dap-virtual-text 0.05ms  lsp-zero.nvim
- nvim-lspconfig 0.18ms 󰢱 lspconfig  nvim-ufo
- nvim-nio 0.23ms  lsp-zero.nvim
- nvim-treesitter 6.28ms  render-markdown
- nvim-treesitter-context 0.58ms  start
- nvim-ts-autotag 3.89ms  nvim-treesitter
- nvim-ufo 3.35ms  start
- nvim-web-devicons 0.24ms  lualine.nvim
- oil.nvim 1.25ms  start
- playground 1.77ms  start
- plenary.nvim 0.29ms  harpoon
- promise-async 0.13ms  nvim-ufo
- refactoring.nvim 5.9ms  start
- render-markdown 12.78ms  start
- SchemaStore.nvim 0.07ms  lsp-zero.nvim
- smart-open.nvim 5.51ms  start
- sqlite.lua 0.26ms  smart-open.nvim
- telescope-fzf-native.nvim 0.25ms  smart-open.nvim
- telescope-fzy-native.nvim 0.26ms  smart-open.nvim
- telescope.nvim 0.36ms  harpoon
- trouble.nvim 4.79ms  start
- undotree 0.21ms  start
- vim-dadbod 0.22ms  start
- vim-dadbod-completion 0.18ms  start
- vim-dadbod-ui 0.44ms  start
- vimtex 0.29ms  start

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
