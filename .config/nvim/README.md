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
- Pre-setup 3 themes - `Gruvbox`, `Tokyo Night`, `Pine Rose` - you can just uncomment any one of them

## Key Bindings

- In Neovim Normal Mode, hit `:nmap` to see the list of all bindings
- To see bindings of a certain key, hit `:nmap <leader>`
- Or you can just use Telescope to do the deed `<leader>vk`, in this case, holding space and pressing `vk`

## Plugins List

<details>
	<summary>Loaded (44)</summary>

1. cmp-nvim-lsp 0.12ms  lsp-zero.nvim
2. dressing.nvim 2ms  start
3. fidget.nvim 3.47ms  lsp-zero.nvim
4. gitsigns.nvim 0.49ms  start
5. gruvbox.nvim 4.58ms  start
6. harpoon 9.01ms  start
7. indent-blankline.nvim 2.56ms  start
8. lazy.nvim 3198.43ms  init.lua
9. lsp-zero.nvim 128.35ms  start
10. lspkind.nvim 0.08ms  lsp-zero.nvim
11. lualine.nvim 7.9ms  start
12. LuaSnip 6.81ms  lsp-zero.nvim
13. mason-lspconfig.nvim 0.14ms  lsp-zero.nvim
14. mason-null-ls.nvim 0.83ms  lsp-zero.nvim
15. mason-nvim-dap.nvim 0.94ms  lsp-zero.nvim
16. mason-tool-installer.nvim 3.13ms  lsp-zero.nvim
17. mason.nvim 3.27ms  lsp-zero.nvim
18. mini.nvim 2.72ms  start
19. neodev.nvim 3.8ms  lsp-zero.nvim
20. none-ls.nvim 0.88ms  lsp-zero.nvim
21. nvim-cmp 3.12ms  lsp-zero.nvim
22. nvim-dap 1.17ms  lsp-zero.nvim
23. nvim-dap-go 0.93ms  lsp-zero.nvim
24. nvim-dap-ui 0.91ms  lsp-zero.nvim
25. nvim-dap-virtual-text 0.11ms  lsp-zero.nvim
26. nvim-lspconfig 1.07ms  lsp-zero.nvim
27. nvim-nio 1.13ms  lsp-zero.nvim
28. nvim-treesitter 15.35ms  render-markdown
29. nvim-treesitter-context 1.91ms  start
30. nvim-ts-autotag 5.73ms  nvim-treesitter
31. nvim-web-devicons 0.52ms  lualine.nvim
32. oil.nvim 3.07ms  start
33. playground 1.79ms  start
34. plenary.nvim 1.36ms  telescope.nvim
35. refactoring.nvim 8.27ms  start
36. render-markdown 84.7ms  start
37. telescope.nvim 1.89ms  start
38. trouble.nvim 4.81ms  start
39. undotree 0.39ms  start
40. vim-dadbod 1.44ms  start
41. vim-dadbod-completion 0.36ms  start
42. vim-dadbod-ui 1.06ms  start
43. vimtex 0.65ms  start
44. which-key.nvim 11.79ms  VimEnter

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
