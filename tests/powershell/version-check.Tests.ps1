# Unit tests for version-check.ps1
# Tests version extraction, comparison, and installation checking

BeforeAll {
    # Setup test environment
    $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $commonLibPath = Join-Path $RepoRoot "bootstrap\lib\common.ps1"
    $versionCheckPath = Join-Path $RepoRoot "bootstrap\lib\version-check.ps1"

    # Source the libraries
    . $commonLibPath
    . $versionCheckPath
}

Describe "Version Pattern Definitions" {

    It "Has version patterns for common tools" {
        $Script:VersionPatterns.ContainsKey("node") | Should -Be $true
        $Script:VersionPatterns.ContainsKey("python") | Should -Be $true
        $Script:VersionPatterns.ContainsKey("go") | Should -Be $true
        $Script:VersionPatterns.ContainsKey("rustc") | Should -Be $true
        $Script:VersionPatterns.ContainsKey("npm") | Should -Be $true
    }

    It "Has version flags for special tools" {
        $Script:VersionFlags.ContainsKey("go") | Should -Be $true
        $Script:VersionFlags.ContainsKey("cargo") | Should -Be $true
        $Script:VersionFlags.ContainsKey("scoop") | Should -Be $true
    }
}

Describe "Get-ToolVersion" {

    Context "With mocked tool outputs" {

        It "Extracts Node.js version from 'v20.10.0' output" {
            Mock node { return "v20.10.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "node"
            $result | Should -Be "20.10.0"
        }

        It "Extracts Node.js version from plain version output" {
            Mock node { return "20.10.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "node"
            $result | Should -Be "20.10.0"
        }

        It "Extracts Python version from 'Python 3.12.0' output" {
            Mock python { return "Python 3.12.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "python"
            $result | Should -Be "3.12.0"
        }

        It "Extracts Go version from 'go version go1.22.0' output" {
            Mock go { return "go version go1.22.0 windows/amd64" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "go"
            $result | Should -Be "1.22.0"
        }

        It "Extracts Go version from 'go version go1.21' output (two parts)" {
            Mock go { return "go version go1.21 linux/amd64" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "go"
            $result | Should -Be "1.21"
        }

        It "Extracts rustc version" {
            Mock rustc { return "rustc 1.75.0 (stdin)" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "rustc"
            $result | Should -Be "1.75.0"
        }

        It "Extracts npm version" {
            Mock npm { return "v10.2.4" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "npm"
            $result | Should -Be "10.2.4"
        }

        It "Extracts cargo version" {
            Mock cargo { return "cargo 1.75.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "cargo"
            $result | Should -Be "1.75.0"
        }

        It "Extracts ruby version" {
            Mock ruby { return "ruby 3.2.0 (stdin)" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "ruby"
            $result | Should -Be "3.2.0"
        }

        It "Extracts PHP version" {
            Mock php { return "PHP 8.2.10 (cli)" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "php"
            $result | Should -Be "8.2.10"
        }

        It "Extracts dotnet version" {
            Mock dotnet { return "8.0.100" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "dotnet"
            $result | Should -Be "8.0.100"
        }

        It "Extracts brew version" {
            Mock brew { return "Homebrew 4.2.10" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "brew"
            $result | Should -Be "4.2.10"
        }

        It "Extracts scoop version" {
            Mock scoop { return "Current scoop version: v0.4.1" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "scoop"
            $result | Should -Be "0.4.1"
        }

        It "Extracts winget version" {
            Mock winget { return "v1.7.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "winget"
            $result | Should -Be "1.7.0"
        }

        It "Extracts fzf version" {
            Mock fzf { return "0.45.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "fzf"
            $result | Should -Be "0.45.0"
        }

        It "Extracts bat version" {
            Mock bat { return "bat 0.24.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "bat"
            $result | Should -Be "0.24.0"
        }

        It "Extracts eza version" {
            Mock eza { return "eza 0.18.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "eza"
            $result | Should -Be "0.18.0"
        }

        It "Extracts lazygit version" {
            Mock lazygit { return "version=0.40.2" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "lazygit"
            $result | Should -Be "0.40.2"
        }

        It "Extracts gh version" {
            Mock gh { return "gh version 2.40.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "gh"
            $result | Should -Be "2.40.0"
        }

        It "Extracts tokei version" {
            Mock tokei { return "tokei 12.1.2" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "tokei"
            $result | Should -Be "12.1.2"
        }

        It "Extracts zoxide version" {
            Mock zoxide { return "zoxide v0.9.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "zoxide"
            $result | Should -Be "0.9.0"
        }

        It "Extracts ripgrep/rg version" {
            Mock rg { return "ripgrep 14.0.3" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "rg"
            $result | Should -Be "14.0.3"
        }

        It "Extracts fd version" {
            Mock fd { return "fd 9.0.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "fd"
            $result | Should -Be "9.0.0"
        }

        It "Extracts difft version" {
            Mock difft { return "difft 0.54.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "difft"
            $result | Should -Be "0.54.0"
        }

        It "Extracts gopls version" {
            Mock gopls { return "golang.org/x/tools/gopls v0.16.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "gopls"
            $result | Should -Be "0.16.0"
        }

        It "Extracts rust-analyzer version" {
            Mock rust-analyzer { return "rust-analyzer 1.76.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "rust-analyzer"
            $result | Should -Be "1.76.0"
        }

        It "Extracts pyright version" {
            Mock pyright { return "Pyright 1.1.350" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "pyright"
            $result | Should -Be "1.1.350"
        }

        It "Extracts typescript-language-server version" {
            Mock typescript-language-server { return "typescript-language-server version 4.3.3" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "typescript-language-server"
            $result | Should -Be "4.3.3"
        }

        It "Extracts clangd version" {
            Mock clangd { return "clangd version 18.1.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "clangd"
            $result | Should -Be "18.1.0"
        }

        It "Extracts lua-language-server version" {
            Mock lua-language-server { return "Lua Language Server 3.10.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "lua-language-server"
            $result | Should -Be "3.10.0"
        }

        It "Extracts jdtls version" {
            Mock jdtls { return "jdtls 1.9.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "jdtls"
            $result | Should -Be "1.9.0"
        }

        It "Extracts yaml-language-server version" {
            Mock yaml-language-server { return "yaml-language-server version 1.14.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "yaml-language-server"
            $result | Should -Be "1.14.0"
        }

        It "Extracts prettier version" {
            Mock prettier { return "3.2.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "prettier"
            $result | Should -Be "3.2.0"
        }

        It "Extracts eslint version" {
            Mock eslint { return "v8.56.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "eslint"
            $result | Should -Be "8.56.0"
        }

        It "Extracts ruff version" {
            Mock ruff { return "ruff 0.1.9" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "ruff"
            $result | Should -Be "0.1.9"
        }

        It "Extracts black version" {
            Mock black { return "black, 24.1.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "black"
            $result | Should -Be "24.1.0"
        }

        It "Extracts mypy version" {
            Mock mypy { return "mypy 1.8.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "mypy"
            $result | Should -Be "1.8.0"
        }

        It "Extracts goimports version" {
            Mock goimports { return "goimports v0.12.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "goimports"
            $result | Should -Be "0.12.0"
        }

        It "Extracts golangci-lint version" {
            Mock golangci-lint { return "golangci-lint 1.55.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "golangci-lint"
            $result | Should -Be "1.55.0"
        }

        It "Extracts clang-format version" {
            Mock clang-format { return "clang-format version 18.1.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "clang-format"
            $result | Should -Be "18.1.0"
        }

        It "Extracts scalafmt version" {
            Mock scalafmt { return "scalafmt 3.8.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "scalafmt"
            $result | Should -Be "3.8.0"
        }
    }

    Context "Error handling" {

        It "Returns null when tool does not exist" {
            Mock Test-Command { return $false }

            $result = Get-ToolVersion "nonexistent-tool"
            $result | Should -Be $null
        }

        It "Returns null when tool command fails" {
            Mock badtool { throw "command failed" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "badtool"
            $result | Should -Be $null
        }

        It "Uses fallback pattern when no specific pattern exists" {
            Mock unknowntool { return "version 1.2.3" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "unknowntool"
            $result | Should -Be "1.2.3"
        }

        It "Returns null when output has no version-like string" {
            Mock noversiontool { return "some random output" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "noversiontool"
            $result | Should -Be $null
        }
    }

    Context "Custom version flags" {

        It "Uses custom version flag when provided" {
            Mock customtool { return "custom output 1.0.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "customtool" -VersionFlag "--version"
            $result | Should -Be "1.0.0"
        }

        It "Uses 'version' flag for go" {
            Mock go { return "go version go1.22.0" }
            Mock Test-Command { return $true }

            $result = Get-ToolVersion "go"
            $result | Should -Be "1.22.0"
        }
    }
}

Describe "Compare-Versions" {

    Context "Equal versions" {

        It "Returns true for equal versions" {
            $result = Compare-Versions "1.0.0" "1.0.0"
            $result | Should -Be $true
        }

        It "Returns true for equal versions with 'v' prefix" {
            $result = Compare-Versions "v1.0.0" "v1.0.0"
            $result | Should -Be $true
        }

        It "Returns true for equal versions with mixed prefixes" {
            $result = Compare-Versions "v1.0.0" "1.0.0"
            $result | Should -Be $true
        }
    }

    Context "Greater versions" {

        It "Returns true when installed is greater (major)" {
            $result = Compare-Versions "2.0.0" "1.0.0"
            $result | Should -Be $true
        }

        It "Returns true when installed is greater (minor)" {
            $result = Compare-Versions "1.5.0" "1.0.0"
            $result | Should -Be $true
        }

        It "Returns true when installed is greater (patch)" {
            $result = Compare-Versions "1.0.5" "1.0.0"
            $result | Should -Be $true
        }

        It "Returns true when installed is greater with 'v' prefix" {
            $result = Compare-Versions "v2.0.0" "v1.0.0"
            $result | Should -Be $true
        }
    }

    Context "Lesser versions" {

        It "Returns false when installed is less (major)" {
            $result = Compare-Versions "1.0.0" "2.0.0"
            $result | Should -Be $false
        }

        It "Returns false when installed is less (minor)" {
            $result = Compare-Versions "1.0.0" "1.5.0"
            $result | Should -Be $false
        }

        It "Returns false when installed is less (patch)" {
            $result = Compare-Versions "1.0.0" "1.0.5"
            $result | Should -Be $false
        }
    }

    Context "Edge cases" {

        It "Handles versions with different lengths (3 parts vs 2 parts)" {
            $result = Compare-Versions "1.0.0" "1.0"
            $result | Should -Be $true
        }

        It "Handles versions with different lengths (2 parts vs 3 parts)" {
            $result = Compare-Versions "1.0" "1.0.1"
            $result | Should -Be $false
        }

        It "Handles pre-release suffixes" {
            $result = Compare-Versions "1.0.0-alpha" "1.0.0"
            $result | Should -Be $true  # Alpha version treated as >= after suffix removal
        }

        It "Handles versions with non-numeric characters" {
            $result = Compare-Versions "1.0.0-beta" "1.0.0-alpha"
            $result | Should -Be $true
        }

        It "Handles date-based versions" {
            $result = Compare-Versions "2023-12-01" "2023-01-01"
            $result | Should -Be $true
        }

        It "Handles date-based versions when installed is older" {
            $result = Compare-Versions "2023-01-01" "2023-12-01"
            $result | Should -Be $false
        }

        It "Handles empty version strings" {
            $result = Compare-Versions "" "1.0.0"
            $result | Should -Be $false
        }

        It "Handles version with only major.minor (no patch)" {
            $result = Compare-Versions "1.5" "1.4.0"
            $result | Should -Be $true
        }

        It "Handles version comparison with leading zeros" {
            $result = Compare-Versions "1.05.0" "1.04.0"
            $result | Should -Be $true
        }
    }
}

Describe "Test-NeedsInstall" {

    Context "Tool not installed" {

        It "Returns true when tool does not exist" {
            Mock Test-Command { return $false }

            $result = Test-NeedsInstall "nonexistent-tool"
            $result | Should -Be $true
        }
    }

    Context "Tool installed" {

        It "Returns false when tool exists" {
            Mock Test-Command { return $true }

            $result = Test-NeedsInstall "git"
            $result | Should -Be $false
        }

        It "Returns false when tool exists regardless of version" {
            Mock Test-Command { return $true }

            $result = Test-NeedsInstall "node" -MinVersion "20.0.0"
            $result | Should -Be $false
        }
    }
}

Describe "needs_install (Bash alias)" {

    It "Is aliased to Test-NeedsInstall" {
        Mock Test-Command { return $true }

        $result = needs_install "git"
        $result | Should -Be $false
    }
}

Describe "Show-VersionStatus" {

    BeforeEach {
        # Reset tracking
        Reset-Tracking
    }

    Context "Tool not installed" {

        It "Returns true and shows not installed message" {
            Mock Test-Command { return $false }

            $result = Show-VersionStatus "nonexistent-tool" -DisplayName "NonExistent Tool"
            $result | Should -Be $true
        }
    }

    Context "Tool installed without extractable version" {

        It "Returns false and shows installed message" {
            Mock Test-Command { return $true }
            Mock Get-ToolVersion { return $null }

            $result = Show-VersionStatus "sometool" -DisplayName "Some Tool"
            $result | Should -Be $false
        }
    }

    Context "Tool installed with extractable version" {

        It "Returns false and shows version" {
            Mock Test-Command { return $true }
            Mock Get-ToolVersion { return "1.2.3" }

            $result = Show-VersionStatus "sometool" -DisplayName "Some Tool"
            $result | Should -Be $false
        }

        It "Uses tool name as display name when not provided" {
            Mock Test-Command { return $true }
            Mock Get-ToolVersion { return "1.2.3" }

            $result = Show-VersionStatus "git"
            $result | Should -Be $false
        }
    }
}

Describe "check_and_report_version (Bash alias)" {

    It "Is aliased to Show-VersionStatus" {
        Mock Test-Command { return $true }
        Mock Get-ToolVersion { return "1.2.3" }

        $result = check_and_report_version "git" -DisplayName "Git"
        $result | Should -Be $false
    }
}
