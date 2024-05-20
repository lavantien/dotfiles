# Neovim Cross-Platform Full IDE Minimal Setup From Scratch

## Install

- Install Git, Neovim, GCC/LLVM-Clang, Go, NodeJS, Python3, Rust, Lua, Java, and SQLite
- Neovim Deps:

```bash
npm i -g neovim && pip3 install neovim
```

- If you're on Windows you need to set the `HOME` environment variable to `C:\Users\<your account name>`
- Run `nvim` the first time and wait for it to auto initialize plugins, then press `S` to sync packages
- Run `:MasonUpdate` to install all registries, then `:Mason` and press `U` if there's any update

## Features

- Fully support Go, Rust, Lua, JavaScript/TypeScript, Python, Java, HTML/CSS, LaTeX, Markdown and DevOps techs
- Intellisense, Snippets, Debugging, Code Objects, Pin Headers, Display Statuses, Disect Token Tree, Fuzzy Picker
- Surround Motions, Improved Floating UIs, Inline Diagnostics, Cute Statusbar, Multifiles Jumper, Refactoring
- Rainbow Indentation Guides, Smart Help, Disect Undo Tree, Git Integration, SQL/NoSQL Client, File Handler
- Pre-setup 3 themes - `Gruvbox`, `Tokyo Night`, `Pine Rose` - you can just uncomment any one of them

## Key Bindings

- In Neovim Normal Mode, hit `:nmap` to see the list of all bindings
- To see bindings of a certain key, hit `:nmap <leader>`
- Or you can just use Telescope to do the deed `<leader>vk`, in this case, holding space and pressing `vk`

## Mason Built-in Packages to `:MasonInstall `

- All language `servers` and `treesitters` are pre-installed when you first initialize Neovim
- All 50 Packages:

```text
gopls delve staticcheck gotests golangci-lint golangci-lint-langserver go-debug-adapter gomodifytags impl goimports-reviser rust-analyzer codelldb lua-language-server stylua luacheck clangd clang-format jdtls java-test java-debug-adapter google-java-format typescript-language-server prettier js-debug-adapter chrome-debug-adapter html-lsp css-lsp tailwindcss-language-server pyright debugpy flake8 blue yaml-language-server yamllint yamlfmt buf-language-server buf terraform-ls sqlls sqlfluff sql-formatter tflint tfsec marksman ltex-ls vale proselint markdown-toc cbfmt nginx-language-server
```

- Specific Languages:

<details>
	<summary>go, rust, lua, c/c++, java, javascript/typescript, html, css, python, yaml, protobuf, sql, terraform, markdown, nginx</summary>

- Go:

```text
gopls delve staticcheck gotests golangci-lint golangci-lint-langserver go-debug-adapter gomodifytags impl goimports-reviser
```

- Rust:

```text
rust-analyzer codelldb
```

- Lua:

```text
lua-language-server stylua luacheck
```

- C/C++:

```text
clangd clang-format
```

- Java:

```text
jdtls java-test java-debug-adapter google-java-format
```

- JavaScript/TypeScript:

```text
typescript-language-server prettier js-debug-adapter chrome-debug-adapter
```

- HTML:

```text
html-lsp
```

- CSS:

```text
css-lsp tailwindcss-language-server
```

- Python:

```text
pyright debugpy flake8 blue
```

- YAML:

```text
yaml-language-server yamllint yamlfmt
```

- Protobuf:

```text
buf-language-server buf
```

- SQL:

```text
sqlls sqlfluff sql-formatter
```

- Terraform:

```text
terraform-ls tflint tfsec
```

- Markdown:

```text
marksman ltex-ls vale proselint markdown-toc cbfmt
```

- Nginx:

```text
nginx-language-server
```

</details>

- Make sure to run `$ nvim +che` to ensure all dependencies are installed

## Plugins List

- nvim-treesitter/nvim-treesitter
- nvim-treesitter/nvim-treesitter-context
- nvim-treesitter/playground
- neovim/nvim-lspconfig
- hrsh7th/nvim-cmp
- hrsh7th/cmp-nvim-lsp
- L3MON4D3/LuaSnip
- onsails/lspkind.nvim
- williamboman/mason.nvim
- williamboman/mason-lspconfig.nvim
- VonHeikemen/lsp-zero.nvim
- mfussenegger/nvim-dap
- jay-babu/mason-nvim-dap.nvim
- leoluz/nvim-dap-go
- rcarriga/nvim-dap-ui
- nvim-neotest/nvim-nio
- folke/neodev.nvim
- theHamsta/nvim-dap-virtual-text
- j-hui/fidget.nvim
- nvim-telescope/telescope.nvim
- kylechui/nvim-surround
- stevearc/dressing.nvim
- ellisonleao/gruvbox.nvim
- (folke/tokyonight.nvim)
- (rose-pine/neovim)
- folke/trouble.nvim
- nvim-lualine/lualine.nvim
- theprimeagen/harpoon
- theprimeagen/refactoring.nvim
- mbbill/undotree
- tpope/vim-fugitive
- lewis6991/gitsigns.nvim
- lervag/vimtex
- MeanderingProgrammer/markdown.nvim
- tpope/vim-dadbod
- stevearc/oil.nvim
- nvim-tree/nvim-web-devicons

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
