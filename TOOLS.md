# Tools Reference

Complete breakdown of all tools installed by the bootstrap script, organized by language and category.

## Language Servers (19 total)

| LSP | Language | Notes |
|-----|----------|-------|
| bashls | Bash/Shell | - |
| clangd | C/C++ | - |
| csharp-ls | C# | - |
| docker-language-server | Dockerfile + Docker Compose | Covers both Dockerfile and docker-compose |
| gopls | Go | - |
| helm_ls | Helm | - |
| html | HTML | - |
| cssls | CSS/SCSS/SASS | - |
| intelephense | PHP | - |
| jdtls | Java | Eclipse JDT.LS (not JDK) |
| lua-language-server | Lua | - |
| metals | Scala | - |
| powershell_es | PowerShell | - |
| pyright | Python | - |
| rust-analyzer | Rust | - |
| svelte | Svelte | - |
| tinymist | Typst | - |
| tombi | TOML | - |
| ts_ls | JavaScript/TypeScript | - |
| yaml-language-server | YAML/K8s | Kubernetes schema support |

**Optional LSPs** (not included in count above):
| LSP | Language | Notes |
|-----|----------|-------|
| dartls | Dart | Optional (requires Dart SDK) |

## Complete Language Tool Matrix

| Language | LSP | Tester | Formatter | Linter | Type Check |
|----------|-----|--------|-----------|--------|------------|
| **Bash** | bashls | bats | shfmt | shellcheck | - |
| **PowerShell** | powershell_es | Pester | Invoke-Formatter | PSScriptAnalyzer | PSScriptAnalyzer |
| **Go** | gopls | go test | gofmt, goimports | golangci-lint | go vet |
| **Rust** | rust-analyzer | cargo test | rustfmt | clippy | cargo check |
| **Python** | pyright | pytest | ruff, black | ruff | mypy |
| **JavaScript/TypeScript** | ts_ls | jest | prettier | eslint | tsc |
| **HTML** | html | - | prettier | - | - |
| **CSS/SCSS/SASS** | cssls | - | prettier | stylelint | - |
| **Svelte** | svelte | - | prettier | - | svelte-check |
| **C/C++** | clangd | Catch2 | clang-format | clang-tidy, cppcheck | compiler |
| **C#** | csharp_ls | dotnet test | dotnet format | Roslyn analyzers | dotnet build |
| **Java** | jdtls | JUnit | checkstyle | checkstyle | javac |
| **PHP** | intelephense | php, PHPUnit | pint | PHPStan, Psalm | - |
| **Scala** | metals | ScalaTest | scalafmt | scalafix | scalac |
| **Lua** | lua_ls | busted | stylua | selene | - |
| **Typst** | tinymist | built-in | tinymist | tinymist | - |
| **Dockerfile** | docker_ls | - | - | hadolint | - |
| **Docker Compose** | docker-compose-language-server | - | prettier | - | - |
| **Helm** | helm_ls | - | prettier | - | - |
| **Kubernetes YAML** | yamlls | kubectl | prettier | yamllint | - |
| **YAML** | yamlls | - | prettier | yamllint | - |
| **TOML** | tombi | - | taplo | - | - |

## Linters & Formatters

| Category | Tools |
|----------|-------|
| **Web** | prettier, eslint, stylelint, tsc |
| **Python** | ruff (format + lint), black, isort, mypy, pytest |
| **Go** | goimports, go fmt, golangci-lint, go vet |
| **Rust** | cargo fmt, clippy, cargo check |
| **C/C++** | clang-format, clang-tidy, cppcheck |
| **C#** | dotnet format, dotnet build |
| **Java** | checkstyle |
| **Bash** | shellcheck, shfmt |
| **PowerShell** | Invoke-Formatter, PSScriptAnalyzer |
| **PHP** | pint, PHPStan, Psalm |
| **Scala** | scalafmt, scalafix |
| **Lua** | stylua, selene |
| **Svelte** | prettier, svelte-check |
| **Docker** | hadolint |
| **Helm/K8s** | prettier, yamllint |
| **YAML/JSON/Markdown** | prettier, yamllint, markdownlint |

## Essential CLI Tools

| Tool | Purpose |
|------|---------|
| fzf | Fuzzy finder |
| zoxide | Smart cd navigation |
| bat | Better cat |
| eza | Better ls |
| lazygit | Terminal Git UI |
| gh | GitHub CLI |
| ripgrep (rg) | Fast grep |
| fd | Fast find |
| tokei | Code stats |
| btop | System monitor |
| repomix | Pack repositories for AI exploration |
| docker-compose | Docker Compose CLI |
| helm | Kubernetes package manager |
| kubectl | Kubernetes CLI |

## Testing & Coverage

| Tool | Language | Purpose |
|------|----------|---------|
| bats | Bash | Testing |
| busted | Lua | Testing |
| pytest | Python | Testing |
| Pester | PowerShell | Testing with coverage |
| kcov | Bash | Coverage reports (universal) |

## MCP Servers (Claude Code)

| MCP | Purpose |
|-----|---------|
| context7 | Up-to-date library documentation and code examples |
| playwright | Browser automation and E2E testing |
| repomix | Pack repositories for full-context AI exploration |
