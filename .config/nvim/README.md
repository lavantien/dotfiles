# Neovim Cross-Platform Full IDE Minimal Setup From Scratch

## Install

- Git, GH CLI, Neovim, GCC/LLVM-Clang, Go, NodeJS, Python3, Rust, Lua, Java, Coursier/Scala, SQLite, Docker, K8s, OpenTf
- Neovim Deps; then [integrate the two](https://github.com/phiresky/ripgrep-all/wiki/fzf-Integration), put the file in `~/.local/bin` and add the folder to `PATH`

```bash
cargo install coreutils && npm i -g neovim && mkdir -p ~/notes
```

```bash
go install github.com/theredditbandit/pman@latest && pman completion zsh
```

- If you're on `Windows` you need to
  - remove `make install_jsregexp` from `luasnip` build config
  - remove `checkmake`, `luacheck`, `semgrep`, `ansible-lint`, or other packages that don't support Windows from `mason-tools-installer` list
  - set the `HOME` environment variable to `C:\Users\<name>`
  - copy `.config/nvim` directory to `C:\Users\<name>\AppData\Local\`
  - add to `PATH` this value `C:\Users\<name>\AppData\Local\nvim-data\mason\bin`
  - install [sqlite3](https://gist.github.com/zeljic/d8b542788b225b1bcb5fce169ee28c55), rename `sqlite3.dll` to `libsqlite3.dll` and `sqlite3.lib` to `libsqlite3.lib`, and add its location to`PATH`
  - Install [coursier/scala](https://www.scala-lang.org/download/)
  - `rustup toolchain install nightly-x86_64-pc-windows-msvc`, `cargo install eza just broot`, `cargo +nightly install dua-cli`; `choco install ripgrep fzf rsync`, `pman completion powershell`, all these for cli navigation and projects management
  - Install additional packages yourself if there are something missing, Windows is a hot mess, that's all
- Run `nvim` the first time and wait for it to auto initialize plugins, then press `S` to sync packages
- Run `:MasonUpdate` to install all registries, then `:Mason` and press `U` if there's any update
- All language `servers`, `linters`, and `treesitters` are pre-installed when you first initialize Neovim
- Make sure to run `$ nvim +che` to ensure all related dependencies are installed

## Features

- Fully support lua, go, javascript/typescript & vue, html/htmx & css/tailwind, python, c/cpp, rust, java, scala, assembly, markdown, latex & typos, bash, make & cmake, json, yaml, toml, sql, protobuf, graphql, docker/compose, ci/cd, kubernetes/helm, ansible, opentofu
- Intellisense, Code Actions, Debugging, Testing, Diff View, Snippets, Hints, Code Objects, Pin Headers, Display Statuses, Token Tree, Fuzzy Picker
- Surround, Autotag, Improved Floating UIs, Toggle Term, Notifications, Inline Diagnostics, Inline Eval, Statusbar, Multifiles Jumper, Refactoring, Clues
- Smart Folds, Autolint, Notes Taking, Indentation Guides, Smart Help, Undo Tree, Git Integration, SQL/NoSQL Client, File Explorer, Cellular Automaton
- Optimized Keymaps, Schemas Store, Highlight Patterns, Pre-setup 3 themes - `Gruvbox`, `Tokyo Night`, `Pine Rose`

## Key Bindings

- Key clue support, just hit any key and a popup will appear to guide you
- Or via Telescope `<leader>vk`, in this case, hit space and pressing `vk`
- In Neovim Normal Mode, hit `:nmap` to see the list of all bindings
- Check `~/.config/nvim/lua/config/remap.lua` for detailed information

## Plugins List

<details>
	<summary>Loaded (75)</summary>

- cellular-automaton.nvim 0.36ms  start
- cmp-buffer 0.4ms  nvim-cmp
- cmp-cmdline 0.43ms  nvim-cmp
- cmp-nvim-lsp 0.31ms  nvim-cmp
- cmp-nvim-lsp-signature-help 0.54ms  nvim-cmp
- cmp-path 0.42ms  nvim-cmp
- cmp_luasnip 0.14ms  nvim-cmp
- diffview.nvim 1.99ms  start
- dressing.nvim 2.22ms  start
- fidget.nvim 4.05ms  lsp-zero.nvim
- FixCursorHold.nvim 2.01ms  neotest
- friendly-snippets 0.59ms  LuaSnip
- gitsigns.nvim 3.68ms  start
- harpoon 4.83ms  start
- indent-blankline.nvim 5.07ms  start
- lazy.nvim 4.36ms  init.lua
- lsp-zero.nvim 149.49ms  start
- lspkind.nvim 0.32ms  nvim-cmp
- lualine.nvim 11.01ms  start
- LuaSnip 6.59ms  nvim-cmp
- mason-lspconfig.nvim 0.12ms  lsp-zero.nvim
- mason-null-ls.nvim 1.28ms  lsp-zero.nvim
- mason-nvim-dap.nvim 0.24ms  lsp-zero.nvim
- mason-tool-installer.nvim 5.26ms  lsp-zero.nvim
- mason.nvim 4.23ms  lsp-zero.nvim
- mini.nvim 4.23ms  start
- neotest 43.79ms  start
- neotest-bash 1.76ms  neotest
- neotest-go 1.72ms  neotest
- neotest-gtest 1.99ms  neotest
- neotest-jest 1.91ms  neotest
- neotest-plenary 1.7ms  neotest
- neotest-python 1.69ms  neotest
- neotest-rust 1.74ms  neotest
- neotest-scala 1.98ms  neotest
- neotest-vitest 1.88ms  neotest
- noice.nvim 7.96ms 󰢱 noice  config.remap
- none-ls.nvim 1.26ms  lsp-zero.nvim
- nui.nvim 2.27ms  noice.nvim
- nvim-cmp 14.6ms  start
- nvim-dap 3.97ms  lsp-zero.nvim
- nvim-dap-go 1.35ms  lsp-zero.nvim
- nvim-dap-ui 1.29ms  lsp-zero.nvim
- nvim-dap-virtual-text 1.32ms  lsp-zero.nvim
- nvim-lspconfig 0.46ms 󰢱 lspconfig  nvim-ufo
- nvim-nio 1.34ms  lsp-zero.nvim
- nvim-notify 2.03ms  noice.nvim
- nvim-treesitter 19.61ms  render-markdown
- nvim-treesitter-context 1.9ms  start
- nvim-ts-autotag 4.87ms  nvim-treesitter
- nvim-ufo 7.26ms  start
- nvim-web-devicons 1.18ms  lualine.nvim
- oil.nvim 2.67ms  start
- playground 3.53ms  start
- plenary.nvim 0.96ms  refactoring.nvim
- promise-async 1.09ms  nvim-ufo
- refactoring.nvim 11.49ms  start
- render-markdown 25.1ms  start
- rose-pine 3.91ms  start
- SchemaStore.nvim 0.12ms  lsp-zero.nvim
- smart-open.nvim 15.67ms  start
- sqlite.lua 1.56ms  smart-open.nvim
- telescope-fzf-native.nvim 1.69ms  smart-open.nvim
- telescope-fzy-native.nvim 1.72ms  smart-open.nvim
- telescope.nvim 4.42ms 󰢱 telescope  refactoring.nvim
- undotree 1.19ms  start
- vim-dadbod 0.46ms  start
- vim-dadbod-completion 1.21ms  start
- vim-dadbod-ui 2.05ms  start
- vim-fugitive 2.34ms  start
- vimtex 0.56ms  start
- lazydev.nvim  lua
- luvit-meta
- nvim-metals  scala  sbt
- trouble.nvim  <leader>ca  <leader>cc  <leader>cs  <leader>cd  <leader>ce

</details>

## Languages Packages List

<details>
	<summary>Installed (71)</summary>

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
typos_lsp = {
    init_options = {
        config = "~/typos.toml",
    },
},

-- shell
"bashls",
"powershell_es",
"shellcheck",
"shfmt",
"beautysh",
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
