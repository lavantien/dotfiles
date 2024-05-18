This project is now moved to the [dotfiles](https://github.com/lavantien/dotfiles), all my configs will be maintained there instead

## Neovim Setup From Scratch

### Install

- Installed Neovim related packages as instructed in the Healthcheck section above
- Run `nvim` the first time to initialize plugins, then press `S` to sync packages
- Enter the `WakaTime Auth Key` provided by `:WakaTimeApiKey` and in the Settings panel in the browser
- Enter the `Codeium Auth Key` provided by `:Codeium Auth`
- Run `:MasonUpdate` to install all registries

### Key Bindings

- In Neovim Normal Mode, hit `:nmap` to see the list of all bindings
- To see bindings of a certain key, hit `:nmap <leader>`
- Or you can just use Telescope to do the deed `<leader>vk`, in this case, holding space and pressing `vk`

### Mason Built-in Packages to `:MasonInstall `

- All language `servers` and `treesitters` are pre-installed when you first initialize Neovim
- All 51 Packages:

```text
gopls delve staticcheck gotests golangci-lint golangci-lint-langserver go-debug-adapter gomodifytags impl goimports-reviser rust-analyzer codelldb lua-language-server stylua luacheck clangd clang-format jdtls java-test java-debug-adapter google-java-format typescript-language-server prettier js-debug-adapter chrome-debug-adapter html-lsp css-lsp tailwindcss-language-server pyright debugpy flake8 blue dart-debug-adapter yaml-language-server yamllint yamlfmt buf-language-server buf terraform-ls sqlls sqlfluff sql-formatter tflint tfsec marksman ltex-ls vale proselint markdown-toc cbfmt nginx-language-server
```

- Specific Languages:

<details>
	<summary>expand</summary>

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

- JavaScript:

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

- Dart:

```text
dart-debug-adapter
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

### References

<details>
  <summary>expand</summary>

- 0 to LSP: <https://youtu.be/w7i4amO_zaE>
- Zero to IDE: <https://youtu.be/N93cTbtLCIM>
- Effective Neovim: Instant IDE: <https://youtu.be/stqUbv-5u2s>
- Kickstart.nvim: <https://github.com/nvim-lua/kickstart.nvim>
- Neovim Null-LS - Hooks For LSP | Format Code On Save: <https://youtu.be/ryxRpKpM9B4>
- Null-LS built-in: <https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTINS.md>
- Debugging in Neovim: <https://youtu.be/0moS8UHupGc>
- How to Debug like a Pro: <https://miguelcrespo.co/how-to-debug-like-a-pro-using-neovim>
- Nvim DAP getting started: <https://davelage.com/posts/nvim-dap-getting-started/>

</details>

