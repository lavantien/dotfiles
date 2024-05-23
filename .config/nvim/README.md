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
- Intellisense, Snippets, Debugging, Code Objects, Pin Headers, Display Statuses, Disect Token Tree, Fuzzy Picker
- Surround, Autotag, Improved Floating UIs, Inline Diagnostics, Cute Statusbar, Multifiles Jumper, Refactoring
- Autolint, Indentation Guides, Smart Help, Disect Undo Tree, Git Integration, SQL/NoSQL Client, File Explorer
- Schemas Store, Pre-setup 3 themes - `Gruvbox`, `Tokyo Night`, `Pine Rose` - you can just uncomment any one of them

## Key Bindings

- In Neovim Normal Mode, hit `:nmap` to see the list of all bindings
- To see bindings of a certain key, hit `:nmap <leader>`
- Or you can just use Telescope to do the deed `<leader>vk`, in this case, holding space and pressing `vk`

## Plugins List

<details>
	<summary>Loaded (45)</summary>

- cmp-nvim-lsp 0.15ms  lsp-zero.nvim
- dressing.nvim 0.99ms  start
- fidget.nvim 1.69ms  lsp-zero.nvim
- gitsigns.nvim 0.07ms  start
- gruvbox.nvim 3.63ms  start
- harpoon 7.42ms  start
- indent-blankline.nvim 1.61ms  start
- lazy.nvim 2.04ms  init.lua
- lsp-zero.nvim 83.79ms  start
- lspkind.nvim 0.04ms  lsp-zero.nvim
- lualine.nvim 6.1ms  start
- LuaSnip 2.19ms  lsp-zero.nvim
- mason-lspconfig.nvim 0.1ms  lsp-zero.nvim
- mason-null-ls.nvim 0.21ms  lsp-zero.nvim
- mason-nvim-dap.nvim 0.19ms  lsp-zero.nvim
- mason-tool-installer.nvim 0.87ms  lsp-zero.nvim
- mason.nvim 1.53ms  lsp-zero.nvim
- mini.nvim 3.5ms  start
- neodev.nvim 1.46ms  lsp-zero.nvim
- none-ls.nvim 0.23ms  lsp-zero.nvim
- nvim-cmp 3.39ms  lsp-zero.nvim
- nvim-dap 0.34ms  lsp-zero.nvim
- nvim-dap-go 0.17ms  lsp-zero.nvim
- nvim-dap-ui 0.24ms  lsp-zero.nvim
- nvim-dap-virtual-text 0.06ms  lsp-zero.nvim
- nvim-lspconfig 0.37ms  lsp-zero.nvim
- nvim-nio 0.21ms  lsp-zero.nvim
- nvim-treesitter 6.87ms  start
- nvim-treesitter-context 0.71ms  start
- nvim-ts-autotag 3.52ms  nvim-treesitter
- nvim-web-devicons 0.23ms  oil.nvim
- oil.nvim 2.32ms  start
- playground 0.9ms  start
- plenary.nvim 0.25ms  telescope.nvim
- refactoring.nvim 4.18ms  start
- render-markdown 8.03ms  start
- SchemaStore.nvim 0.09ms  lsp-zero.nvim
- telescope.nvim 0.5ms  start
- trouble.nvim 2.07ms  start
- undotree 0.57ms  start
- vim-dadbod 0.2ms  start
- vim-dadbod-completion 0.3ms  start
- vim-dadbod-ui 0.46ms  start
- vimtex 0.46ms  start
- which-key.nvim 10.87ms  VimEnter

</details>

## Languages Packages List

<details>
	<summary>Installed (64)</summary>

1. ansible-language-server ansiblels
2. bash-language-server bashls
3. blue
4. buf
5. buf-language-server bufls
6. cbfmt
7. chrome-debug-adapter
8. clang-format
9. clangd
10. codelldb
11. css-lsp cssls
12. debugpy
13. delve
14. docker-compose-language-service docker_compose_language_service
15. dockerfile-language-server dockerls
16. emmet-language-server emmet_language_server
17. eslint-lsp eslint
18. firefox-debug-adapter
19. flake8
20. go-debug-adapter
21. goimports-reviser
22. golangci-lint-langserver golangci_lint_ls
23. gomodifytags
24. google-java-format
25. gopls
26. gotests
27. graphql-language-service-cli graphql
28. helm-ls helm_ls
29. html-lsp html
30. htmx-lsp htmx
31. impl
32. java-debug-adapter
33. java-test
34. jdtls
35. js-debug-adapter
36. json-lsp jsonls
37. ltex-ls ltex
38. lua-language-server lua_ls
39. markdown-toc
40. marksman
41. neocmakelsp neocmake
42. powershell-editor-services powershell_es
43. prettier
44. pyright
45. rust-analyzer rust_analyzer
46. snyk-ls snyk_ls
47. sql-formatter
48. sqlfluff
49. sqlls
50. staticcheck
51. stylua
52. tailwindcss-language-server tailwindcss
53. taplo
54. terraform-ls terraformls
55. tflint
56. tfsec
57. typescript-language-server tsserver
58. typos-lsp typos_lsp
59. vue-language-server volar
60. yaml-language-server yamlls
61. yamlfmt
62. yamllint

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
