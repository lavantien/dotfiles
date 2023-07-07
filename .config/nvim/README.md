This project is now moved to the [dotfiles](https://github.com/lavantien/dotfiles), all my configs will be maintained there instead

# Neovim Setup From Scratch

## Install

- Installed Neovim related packages as instructed in the Healthcheck section above
- Run `nvim` the first time to initialize plugins, then press `S` to sync packages
- Enter the `WakaTime Auth Key` in the Settings panel in the browser
- Enter the `Codeium Auth Key` provided by `:Codeium Auth`
- Run `:MasonUpdate` to install all registries
- Make sure to run `$ nvim +che` to ensure all dependencies are installed

## Key Bindings

- In Neovim Normal Mode, hit `:nmap` to see the list of all bindings
- To see bindings of a certain key, hit `:nmap <leader>`
- Or you can just use Telescope to do the deed `<leader>vk`, in this case, holding space and pressing `vk`

## Mason Built-in Packages to `:MasonInstall `

- All language `servers` and `treesitters` are pre-installed when you first initialize Neovim
- Some tools such as `prettier` are handled by the configured `null-ls` already
- see `.config/nvim/lua/plugins/init.lua`, `null-ls` section
- All 50 Packages:

```text
gopls delve staticcheck gotests golangci-lint golangci-lint-langserver go-debug-adapter gomodifytags impl rust-analyzer codelldb lua-language-server stylua luacheck clangd clang-format jdtls java-test java-debug-adapter google-java-format typescript-language-server js-debug-adapter chrome-debug-adapter html-lsp css-lsp tailwindcss-language-server pyright debugpy flake8 blue dart-debug-adapter csharp-language-server csharpier yaml-language-server yamllint yamlfmt buf-language-server buf terraform-ls sqlls sqlfluff sql-formatter tflint tfsec marksman ltex-ls vale proselint markdown-toc cbfmt
```

- Specific Languages:

<details>
	<summary>expand</summary>

- Go:

```text
gopls delve staticcheck gotests golangci-lint golangci-lint-langserver go-debug-adapter gomodifytags impl
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
typescript-language-server js-debug-adapter chrome-debug-adapter
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

- DotNet:

```text
csharp-language-server csharpier
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

</details>

## References

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

## Neovim Deps (after setup 100% OK)

<details>
  <summary>`n +che` result</summary>

```checkhealth
==============================================================================
lazy: require("lazy.health").check()

lazy.nvim ~

- OK Git installed
- OK no existing packages found by other package managers
- OK packer_compiled.lua not found

==============================================================================
mason: require("mason.health").check()

mason.nvim ~

- OK mason.nvim version v1.4.0
- OK PATH: prepend
- OK Providers:
  mason.providers.registry-api
  mason.providers.client
- OK neovim version >= 0.7.0

mason.nvim [Registries] ~

- OK Registry `github.com/mason-org/mason-registry version: 2023-06-26-toxic-dirt` is installed.
- OK Registry `github.com/mason-org/mason-registry version: 2023-06-26-toxic-dirt` is installed.

mason.nvim [Core utils] ~

- OK unzip: `UnZip 6.00 of 20 April 2009, by Debian. Original by Info-ZIP.`
- OK wget: `GNU Wget 1.21.2 built on linux-gnu.`
- OK curl: `curl 8.1.2 (x86_64-pc-linux-gnu) libcurl/8.1.2 OpenSSL/3.1.1 zlib/1.2.13 brotli/1.0.9 zstd/1.5.5 libidn2/2.3.4 libssh2/1.11.0 nghttp2/1.54.0 librtmp/2.3`
- OK gzip: `gzip 1.10`
- OK tar: `tar (GNU tar) 1.34`
- OK bash: `GNU bash, version 5.1.16(1)-release (x86_64-pc-linux-gnu)`
- OK sh: `Ok`

mason.nvim [Languages] ~

- OK Ruby: `ruby 3.2.2 (2023-03-30 revision e51014f9c0) [x86_64-linux]`
- OK luarocks: `/home/linuxbrew/.linuxbrew/bin/luarocks 3.9.2`
- OK cargo: `cargo 1.70.0 (ec8a8a0ca 2023-04-25)`
- OK Go: `go version go1.20.5 linux/amd64`
- OK PHP: `PHP 8.2.7 (cli) (built: Jun  6 2023 21:28:56) (NTS)`
- OK node: `v20.3.1`
- OK RubyGem: `3.4.13`
- OK Composer: `Composer version 2.5.8 2023-06-09 17:13:21`
- OK python: `Python 3.11.4`
- OK julia: `julia version 1.9.1`
- OK java: `openjdk version "20.0.1" 2023-04-18`
- OK javac: `javac 20.0.1`
- OK npm: `9.6.7`
- OK pip: `pip 23.0.1 from /home/linuxbrew/.linuxbrew/Cellar/python@3.11/3.11.4_1/lib/python3.11/site-packages/pip (python 3.11)`
- OK python venv: `Ok`

mason.nvim [GitHub] ~

- OK GitHub API rate limit. Used: 1. Remaining: 4999. Limit: 5000. Reset: Tue Jun 27 13:23:50 2023.

==============================================================================
null-ls: require("null-ls.health").check()

- OK dart_format: the command "dart" is executable.
- OK prettier: the command "prettier" is executable.
- OK checkmake: the command "checkmake" is executable.
- OK clang_check: the command "clang-check" is executable.
- refactoring: cannot verify if the command is an executable.
- OK gitsigns: the source "gitsigns" can be ran.

==============================================================================
nvim: require("nvim.health").check()

Configuration ~

- OK no issues found

Runtime ~

- OK $VIMRUNTIME: /home/linuxbrew/.linuxbrew/Cellar/neovim/0.9.1/share/nvim/runtime

Performance ~

- OK Build type: Release

Remote Plugins ~

- OK Up to date

terminal ~

- key_backspace (kbs) terminfo entry: `key_backspace=^H`
- key_dc (kdch1) terminfo entry: `key_dc=\E[3~`
- $TERM_PROGRAM="WezTerm"
- $COLORTERM="truecolor"

==============================================================================
nvim-treesitter: require("nvim-treesitter.health").check()

Installation ~

- OK `tree-sitter` found 0.20.8 (parser generator, only needed for :TSInstallFromGrammar)
- OK `node` found v20.3.1 (only needed for :TSInstallFromGrammar)
- OK `git` executable found.
- OK `cc` executable found. Selected from { vim.NIL, "cc", "gcc", "clang", "cl", "zig" }
  Version: cc (Ubuntu 11.3.0-1ubuntu1~22.04.1) 11.3.0
- OK Neovim was compiled with tree-sitter runtime ABI version 14 (required >=13). Parsers must be compatible with runtime ABI.

OS Info:
{
machine = "x86_64",
release = "5.15.90.1-microsoft-standard-WSL2",
sysname = "Linux",
version = "#1 SMP Fri Jan 27 02:56:13 UTC 2023"
} ~

Parser/Features H L F I J

- bash ✓ ✓ ✓ . ✓
- c ✓ ✓ ✓ ✓ ✓
- c_sharp ✓ ✓ ✓ . ✓
- cpp ✓ ✓ ✓ ✓ ✓
- css ✓ . ✓ ✓ ✓
- dart ✓ ✓ ✓ ✓ ✓
- dockerfile ✓ . . . ✓
- git_config ✓ . . . .
- gitattributes ✓ . . . ✓
- gitignore ✓ . . . .
- go ✓ ✓ ✓ ✓ ✓
- gomod ✓ . . . ✓
- gosum ✓ . . . .
- gowork ✓ . . . ✓
- html ✓ ✓ ✓ ✓ ✓
- java ✓ ✓ ✓ ✓ ✓
- javascript ✓ ✓ ✓ ✓ ✓
- json ✓ ✓ ✓ ✓ .
- lua ✓ ✓ ✓ ✓ ✓
- make ✓ . ✓ . ✓
- markdown ✓ . ✓ ✓ ✓
- proto ✓ . ✓ . .
- python ✓ ✓ ✓ ✓ ✓
- query ✓ ✓ ✓ ✓ ✓
- rust ✓ ✓ ✓ ✓ ✓
- scss ✓ . ✓ ✓ .
- sql ✓ . . ✓ ✓
- toml ✓ ✓ ✓ ✓ ✓
- typescript ✓ ✓ ✓ ✓ ✓
- vim ✓ ✓ ✓ . ✓
- vimdoc ✓ . . . ✓
- yaml ✓ ✓ ✓ ✓ ✓

Legend: H[ighlight], L[ocals], F[olds], I[ndents], In[j]ections
+) multiple parsers found, only one will be used
x) errors found in the query, try to run :TSUpdate {lang} ~

==============================================================================
provider: health#provider#check

Clipboard (optional) ~

- OK Clipboard tool found: xclip

Python 3 provider (optional) ~

- `g:python3_host_prog` is not set. Searching for python3 in the environment.
- Multiple python3 executables found. Set `g:python3_host_prog` to avoid surprises.
- Executable: /home/linuxbrew/.linuxbrew/bin/python3
- Other python executable: /usr/bin/python3
- Other python executable: /bin/python3
- Python version: 3.11.4
- pynvim version: 0.4.3
- OK Latest pynvim is installed.

Python virtualenv ~

- OK no $VIRTUAL_ENV

Ruby provider (optional) ~

- Ruby: ruby 3.2.2 (2023-03-30 revision e51014f9c0) [x86_64-linux]
- Host: /home/linuxbrew/.linuxbrew/lib/ruby/gems/3.2.0/bin/neovim-ruby-host
- OK Latest "neovim" gem is installed: 0.9.0

Node.js provider (optional) ~

- Node.js: v20.3.1
- Nvim node.js host: /home/linuxbrew/.linuxbrew/lib/node_modules/neovim/bin/cli.js
- OK Latest "neovim" npm/yarn/pnpm package is installed: 4.10.1

Perl provider (optional) ~

- Disabled (g:loaded_perl_provider=0).

==============================================================================
telescope: require("telescope.health").check()

Checking for required plugins ~

- OK plenary installed.
- OK nvim-treesitter installed.

Checking external dependencies ~

- OK rg: found ripgrep 13.0.0
- OK fd: found fd 8.7.0

===== Installed extensions ===== ~

==============================================================================
vim.lsp: require("vim.lsp.health").check()

- LSP log level : WARN
- Log path: /home/lavantien/.local/state/nvim/lsp.log
- Log size: 5617 KB

vim.lsp: Active Clients ~

- No active clients

==============================================================================
vim.treesitter: require("vim.treesitter.health").check()

- Nvim runtime ABI version: 14
- OK Parser: bash ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/bash.so
- OK Parser: c ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/c.so
- OK Parser: c_sharp ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/c_sharp.so
- OK Parser: cpp ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/cpp.so
- OK Parser: css ABI: 13, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/css.so
- OK Parser: dart ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/dart.so
- OK Parser: dockerfile ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/dockerfile.so
- OK Parser: git_config ABI: 13, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/git_config.so
- OK Parser: gitattributes ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/gitattributes.so
- OK Parser: gitignore ABI: 13, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/gitignore.so
- OK Parser: go ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/go.so
- OK Parser: gomod ABI: 13, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/gomod.so
- OK Parser: gosum ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/gosum.so
- OK Parser: gowork ABI: 13, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/gowork.so
- OK Parser: html ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/html.so
- OK Parser: java ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/java.so
- OK Parser: javascript ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/javascript.so
- OK Parser: json ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/json.so
- OK Parser: lua ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/lua.so
- OK Parser: make ABI: 13, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/make.so
- OK Parser: markdown ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/markdown.so
- OK Parser: proto ABI: 13, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/proto.so
- OK Parser: python ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/python.so
- OK Parser: query ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/query.so
- OK Parser: rust ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/rust.so
- OK Parser: scss ABI: 13, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/scss.so
- OK Parser: sql ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/sql.so
- OK Parser: toml ABI: 13, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/toml.so
- OK Parser: typescript ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/typescript.so
- OK Parser: vim ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/vim.so
- OK Parser: vimdoc ABI: 14, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/vimdoc.so
- OK Parser: yaml ABI: 13, path: /home/lavantien/.local/share/nvim/lazy/nvim-treesitter/parser/yaml.so
- OK Parser: c ABI: 14, path: /home/linuxbrew/.linuxbrew/Cellar/neovim/0.9.1/lib/nvim/parser/c.so
- OK Parser: lua ABI: 14, path: /home/linuxbrew/.linuxbrew/Cellar/neovim/0.9.1/lib/nvim/parser/lua.so
- OK Parser: query ABI: 14, path: /home/linuxbrew/.linuxbrew/Cellar/neovim/0.9.1/lib/nvim/parser/query.so
- OK Parser: vim ABI: 14, path: /home/linuxbrew/.linuxbrew/Cellar/neovim/0.9.1/lib/nvim/parser/vim.so
- OK Parser: vimdoc ABI: 14, path: /home/linuxbrew/.linuxbrew/Cellar/neovim/0.9.1/lib/nvim/parser/vimdoc.so

```

</details>
