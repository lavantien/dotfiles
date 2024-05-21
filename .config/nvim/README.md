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
	<summary>Loaded (44)</summary>

1. cmp-nvim-lsp 0.17ms  lsp-zero.nvim
2. dressing.nvim 17.06ms  start
3. fidget.nvim 118.89ms  lsp-zero.nvim
4. gitsigns.nvim 0.11ms  start
5. gruvbox.nvim 161.28ms  start
6. harpoon 153.73ms  start
7. indent-blankline.nvim 54.39ms  start
8. lazy.nvim 12562.18ms  init.lua
9. lsp-zero.nvim 2070.3ms  start
10. lspkind.nvim 0.16ms  lsp-zero.nvim
11. lualine.nvim 106.7ms  start
12. LuaSnip 147.14ms  lsp-zero.nvim
13. mason-lspconfig.nvim 1.13ms  lsp-zero.nvim
14. mason-null-ls.nvim 1.44ms  lsp-zero.nvim
15. mason-nvim-dap.nvim 1.79ms  lsp-zero.nvim
16. mason-tool-installer.nvim 16.63ms  lsp-zero.nvim
17. mason.nvim 56.47ms ✔ build
18. mini.nvim 272.08ms  start
19. neodev.nvim 39.81ms  lsp-zero.nvim
20. none-ls.nvim 1.4ms  lsp-zero.nvim
21. nvim-cmp 42.43ms  lsp-zero.nvim
22. nvim-dap 6.75ms  lsp-zero.nvim
23. nvim-dap-go 1.73ms  lsp-zero.nvim
24. nvim-dap-ui 1.64ms  lsp-zero.nvim
25. nvim-dap-virtual-text 0.2ms  lsp-zero.nvim
26. nvim-lspconfig 6.99ms  lsp-zero.nvim
27. nvim-nio 1.61ms  lsp-zero.nvim
28. nvim-treesitter 571.7ms ✔ build
29. nvim-treesitter-context 29.32ms  start
30. nvim-ts-autotag 89.84ms  nvim-treesitter
31. nvim-web-devicons 12.91ms  oil.nvim
32. oil.nvim 250.59ms  start
33. playground 12.05ms  start
34. plenary.nvim 4.39ms  harpoon
35. refactoring.nvim 300.19ms  start
36. render-markdown 53.32ms  start
37. telescope.nvim 6.31ms  harpoon
38. trouble.nvim 57.26ms  start
39. undotree 7.72ms  start
40. vim-dadbod 5.96ms  start
41. vim-dadbod-completion 5.45ms  start
42. vim-dadbod-ui 153.69ms  start
43. vimtex 17.99ms  start
44. which-key.nvim 74.55ms  VimEnter

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
44. proselint
45. pyright
46. rust-analyzer rust_analyzer
47. snyk-ls snyk_ls
48. sql-formatter
49. sqlfluff
50. sqlls
51. staticcheck
52. stylua
53. tailwindcss-language-server tailwindcss
54. taplo
55. terraform-ls terraformls
56. tflint
57. tfsec
58. typescript-language-server tsserver
59. typos-lsp typos_lsp
60. vale
61. vue-language-server volar
62. yaml-language-server yamlls
63. yamlfmt
64. yamllint

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
