# Neovim Cross-Platform Full IDE Minimal Setup From Scratch

## Install

- Git, GH CLI, Neovim, GCC/LLVM-Clang, Go, NodeJS, Python3, Rust, Lua, Java, SQLite, Docker, K8s, OpenTf
- Neovim Deps:

```bash
cargo install coreutils && npm i -g neovim && mkdir -p ~/notes
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
- Intellisense, Code Actions, Debugging, Testing, Diff View, Snippets, Hints, Code Objects, Pin Headers, Display Statuses, Token Tree, Fuzzy Picker
- Surround, Autotag, Improved Floating UIs, Toggle Term, Inline Diagnostics, Inline Eval, Statusbar, Multifiles Jumper, Refactoring, Clues
- Smart Folds, Autolint, Notes Taking, Indentation Guides, Smart Help, Undo Tree, Git Integration, SQL/NoSQL Client, File Explorer, Cellular Automaton
- Optimized Keymaps, Schemas Store, Highlight Patterns, Pre-setup 3 themes - `Gruvbox`, `Tokyo Night`, `Pine Rose`

## Key Bindings

- Key clue support, just hit any key and a popup will appear to guide you
- Or via Telescope `<leader>vk`, in this case, hit space and pressing `vk`
- In Neovim Normal Mode, hit `:nmap` to see the list of all bindings
- Check `~/.config/nvim/lua/config/remap.lua` for detailed information

## Plugins List

<details>
	<summary>Loaded (70)</summary>

    - cellular-automaton.nvim 0.18ms  start
    - cmp-buffer 0.12ms  nvim-cmp
    - cmp-cmdline 0.13ms  nvim-cmp
    - cmp-nvim-lsp 0.08ms  nvim-cmp
    - cmp-nvim-lsp-signature-help 0.13ms  nvim-cmp
    - cmp-path 0.16ms  nvim-cmp
    - cmp_luasnip 0.05ms  nvim-cmp
    - diffview.nvim 1.32ms  start
    - dressing.nvim 0.81ms  start
    - fidget.nvim 2.34ms  lsp-zero.nvim
    - FixCursorHold.nvim 0.29ms  neotest
    - friendly-snippets 0.11ms  LuaSnip
    - gitsigns.nvim 0.08ms  start
    - gruvbox.nvim 4.03ms  start
    - harpoon 10.91ms  start
    - indent-blankline.nvim 1.08ms  start
    - lazy.nvim 8.63ms  init.lua
    - lazydev.nvim 1.1ms  lua
    - lsp-zero.nvim 94.99ms  start
    - lspkind.nvim 0.13ms  nvim-cmp
    - lualine.nvim 4.85ms  start
    - LuaSnip 4.3ms  nvim-cmp
    - mason-lspconfig.nvim 0.1ms  lsp-zero.nvim
    - mason-null-ls.nvim 0.18ms  lsp-zero.nvim
    - mason-nvim-dap.nvim 0.18ms  lsp-zero.nvim
    - mason-tool-installer.nvim 1ms  lsp-zero.nvim
    - mason.nvim 1.11ms  lsp-zero.nvim
    - mini.nvim 3.59ms  start
    - neotest 22.88ms  start
    - neotest-bash 0.24ms  neotest
    - neotest-go 0.25ms  neotest
    - neotest-gtest 0.23ms  neotest
    - neotest-jest 0.28ms  neotest
    - neotest-plenary 0.25ms  neotest
    - neotest-python 0.25ms  neotest
    - neotest-rust 0.26ms  neotest
    - neotest-vitest 0.24ms  neotest
    - none-ls.nvim 0.19ms  lsp-zero.nvim
    - nvim-cmp 8.43ms  start
    - nvim-dap 0.75ms  lsp-zero.nvim
    - nvim-dap-go 0.16ms  lsp-zero.nvim
    - nvim-dap-ui 0.15ms  lsp-zero.nvim
    - nvim-dap-virtual-text 0.18ms  lsp-zero.nvim
    - nvim-lspconfig 2.58ms  lsp-zero.nvim
    - nvim-nio 0.17ms  lsp-zero.nvim
    - nvim-treesitter 13ms  render-markdown
    - nvim-treesitter-context 0.84ms  start
    - nvim-ts-autotag 7.41ms  nvim-treesitter
    - nvim-ufo 11.41ms  start
    - nvim-web-devicons 0.34ms  oil.nvim
    - oil.nvim 2.23ms  start
    - playground 0.87ms  start
    - plenary.nvim 0.27ms  harpoon
    - promise-async 0.22ms  nvim-ufo
    - refactoring.nvim 2.71ms  start
    - render-markdown 19.94ms  start
    - SchemaStore.nvim 0.07ms  lsp-zero.nvim
    - smart-open.nvim 9.13ms  start
    - sqlite.lua 0.36ms  smart-open.nvim
    - telescope-fzf-native.nvim 0.33ms  smart-open.nvim
    - telescope-fzy-native.nvim 0.34ms  smart-open.nvim
    - telescope.nvim 5.08ms  harpoon
    - undotree 0.54ms  start
    - vim-dadbod 0.3ms  start
    - vim-dadbod-completion 0.38ms  start
    - vim-dadbod-ui 0.37ms  start
    - vim-fugitive 0.9ms  start
    - vimtex 0.33ms  start
    - luvit-meta
    - trouble.nvim  <leader>cc  <leader>cs  <leader>cd  <leader>ce  <leader>ca

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
