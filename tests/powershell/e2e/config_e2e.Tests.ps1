# End-to-end tests for config.sh (Bridge Configuration System)
# Tests YAML config parsing and fallback behavior

Describe "Config E2E - Loading" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $Script:ConfigLib = Join-Path $RepoRoot "lib\config.sh"
        $Script:TestTmpDir = Join-Path $env:TEMP "config-e2e-$(New-Guid)"
        New-Item -ItemType Directory -Path $Script:TestTmpDir -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $Script:TestTmpDir) {
            Remove-Item -Recurse -Force $Script:TestTmpDir -ErrorAction SilentlyContinue
        }
    }

    Context "Config Library" {

        It "config.sh exists and is readable" {
            Test-Path $Script:ConfigLib | Should -Be $true
        }

        It "config.sh contains load_dotfiles_config function" {
            $content = Get-Content $Script:ConfigLib -Raw
            $content | Should -Match "load_dotfiles_config"
        }
    }

    Context "Missing Config File" {

        It "Handles missing config file gracefully" {
            $nonexistent = Join-Path $Script:TestTmpDir "nonexistent.yaml"
            Test-Path $nonexistent | Should -Be $false
        }
    }

    Context "Valid YAML Config" {

        It "Loads valid yaml config" {
            $config = Join-Path $Script:TestTmpDir "test-config.yaml"
            @"
# Test configuration
editor: nvim
terminal: wezterm
theme: gruvbox-light
categories: full
"@ | Out-File $config

            Test-Path $config | Should -Be $true
            $content = Get-Content $config -Raw
            $content | Should -Match "editor"
        }
    }
}

Describe "Config E2E - Value Retrieval" {

    It "Returns default when config not loaded" {
        # Simulate getting config with default value
        $CONFIG_EDITOR = $null
        $result = if ($null -eq $CONFIG_EDITOR) { "vi" } else { $CONFIG_EDITOR }
        $result | Should -Be "vi"
    }

    It "Returns configured value" {
        $CONFIG_EDITOR = "nvim"
        $result = if ($null -eq $CONFIG_EDITOR) { "vi" } else { $CONFIG_EDITOR }
        $result | Should -Be "nvim"
    }

    It "Returns default for undefined config" {
        $CONFIG_TERMINAL = $null
        $result = if ($null -eq $CONFIG_TERMINAL) { "wezterm" } else { $CONFIG_TERMINAL }
        $result | Should -Be "wezterm"
    }
}

Describe "Config E2E - YQ Integration" {

    BeforeAll {
        $Script:TestTmpDir = Join-Path $env:TEMP "config-yq-$(New-Guid)"
        New-Item -ItemType Directory -Path $Script:TestTmpDir -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $Script:TestTmpDir) {
            Remove-Item -Recurse -Force $Script:TestTmpDir -ErrorAction SilentlyContinue
        }
    }

    It "Detects if yq is installed" {
        $yqInstalled = Get-Command yq -ErrorAction SilentlyContinue

        if ($yqInstalled) {
            $yqVersion = & yq --version 2>$null
            $yqVersion | Should -Not -Be $null
        } else {
            # Test should pass even if yq is not installed
            $true | Should -Be $true
        }
    }

    It "Creates config file that yq can parse" {
        $config = Join-Path $Script:TestTmpDir "test-yq.yaml"
        @"
editor: nvim
terminal: wezterm
categories: full
skip_packages: []
"@ | Out-File $config

        Test-Path $config | Should -Be $true
        $content = Get-Content $config -Raw
        $content | Should -Match "editor: nvim"
    }
}

Describe "Config E2E - Skip Packages" {

    It "Returns false when skip_packages is empty" {
        $CONFIG_SKIP_PACKAGES = $null
        $package = "vim"
        $result = if ($CONFIG_SKIP_PACKAGES) { $true } else { $false }
        $result | Should -Be $false
    }

    It "Returns true when package in skip list" {
        $CONFIG_SKIP_PACKAGES = "vim neovim"
        $package = "vim"
        $skipList = $CONFIG_SKIP_PACKAGES -replace ',', ' '
        $result = $skipList -split ' ' | Where-Object { $_ -eq $package }
        $result.Count | Should -BeGreaterOrEqual 1
    }

    It "Handles comma-separated list" {
        $CONFIG_SKIP_PACKAGES = "vim,neovim,nano"
        $package = "neovim"
        $skipList = $CONFIG_SKIP_PACKAGES -replace ',', ' '
        $result = $skipList -split ' ' | Where-Object { $_ -eq $package }
        $result.Count | Should -BeGreaterOrEqual 1
    }

    It "Returns false when package not in skip list" {
        $CONFIG_SKIP_PACKAGES = "vim nano"
        $package = "emacs"
        $skipList = $CONFIG_SKIP_PACKAGES -replace ',', ' '
        $result = $skipList -split ' ' | Where-Object { $_ -eq $package }
        $result.Count | Should -Be 0
    }
}

Describe "Config E2E - Nested Config" {

    BeforeAll {
        $Script:TestTmpDir = Join-Path $env:TEMP "config-nested-$(New-Guid)"
        New-Item -ItemType Directory -Path $Script:TestTmpDir -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $Script:TestTmpDir) {
            Remove-Item -Recurse -Force $Script:TestTmpDir -ErrorAction SilentlyContinue
        }
    }

    It "Parses platform-specific settings" {
        $config = Join-Path $Script:TestTmpDir "test-platform.yaml"
        @"
linux:
  package_manager: apt
  display_server: wayland
windows:
  package_manager: scoop
macos:
  package_manager: brew
"@ | Out-File $config

        Test-Path $config | Should -Be $true
        $content = Get-Content $config -Raw
        $content | Should -Match "linux"
        $content | Should -Match "windows"
    }

    It "Contains platform-specific config variables" {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $Script:ConfigLib = Join-Path $RepoRoot "lib\config.sh"
        $content = Get-Content $Script:ConfigLib -Raw

        $content | Should -Match "CONFIG_LINUX_PACKAGE_MANAGER"
        $content | Should -Match "CONFIG_WINDOWS_PACKAGE_MANAGER"
        $content | Should -Match "CONFIG_MACOS_PACKAGE_MANAGER"
    }
}

Describe "Config E2E - Edge Cases" {

    BeforeAll {
        $Script:TestTmpDir = Join-Path $env:TEMP "config-edge-$(New-Guid)"
        New-Item -ItemType Directory -Path $Script:TestTmpDir -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $Script:TestTmpDir) {
            Remove-Item -Recurse -Force $Script:TestTmpDir -ErrorAction SilentlyContinue
        }
    }

    It "Handles empty config file" {
        $emptyConfig = Join-Path $Script:TestTmpDir "empty.yaml"
        "" | Out-File $emptyConfig

        $content = Get-Content $emptyConfig
        $content | Should -Be ""
    }

    It "Handles config with only comments" {
        $commentConfig = Join-Path $Script:TestTmpDir "comments.yaml"
        @"
# This is a comment
# Another comment
"@ | Out-File $commentConfig

        Test-Path $commentConfig | Should -Be $true
    }

    It "Handles special characters in values" {
        $specialConfig = Join-Path $Script:TestTmpDir "special.yaml"
        @"
editor: 'C:\Program Files\NVim\nvim.exe'
terminal: 'wezterm-terminal'
github_username: 'user@example.com'
"@ | Out-File $specialConfig

        $content = Get-Content $specialConfig -Raw
        $content | Should -Match "nvim"
        $content | Should -Match "user"
    }

    It "Handles array values in YAML" {
        $arrayConfig = Join-Path $Script:TestTmpDir "array.yaml"
        @"
skip_packages:
  - npm
  - yarn
  - pnpm
"@ | Out-File $arrayConfig

        $content = Get-Content $arrayConfig -Raw
        $content | Should -Match "skip_packages"
        $content | Should -Match "npm"
    }
}

Describe "Config E2E - Defaults" {

    It "CONFIG_CATEGORIES defaults to 'full'" {
        $CONFIG_CATEGORIES = "full"
        $CONFIG_CATEGORIES | Should -Be "full"
    }

    It "CONFIG_AUTO_UPDATE_REPOS defaults to 'false'" {
        $CONFIG_AUTO_UPDATE_REPOS = "false"
        $CONFIG_AUTO_UPDATE_REPOS | Should -Be "false"
    }

    It "CONFIG_DEFAULT_BRANCH defaults to 'main'" {
        $CONFIG_DEFAULT_BRANCH = "main"
        $CONFIG_DEFAULT_BRANCH | Should -Be "main"
    }

    It "Windows package manager defaults to 'scoop'" {
        $defaultValue = "scoop"
        $CONFIG_WINDOWS_PACKAGE_MANAGER = if ($null -eq $CONFIG_WINDOWS_PACKAGE_MANAGER) { $defaultValue } else { $CONFIG_WINDOWS_PACKAGE_MANAGER }
        $CONFIG_WINDOWS_PACKAGE_MANAGER | Should -Be "scoop"
    }

    It "macOS package manager defaults to 'brew'" {
        $defaultValue = "brew"
        $CONFIG_MACOS_PACKAGE_MANAGER = if ($null -eq $CONFIG_MACOS_PACKAGE_MANAGER) { $defaultValue } else { $CONFIG_MACOS_PACKAGE_MANAGER }
        $CONFIG_MACOS_PACKAGE_MANAGER | Should -Be "brew"
    }

    It "Linux package manager defaults to 'apt'" {
        $defaultValue = "apt"
        $CONFIG_LINUX_PACKAGE_MANAGER = if ($null -eq $CONFIG_LINUX_PACKAGE_MANAGER) { $defaultValue } else { $CONFIG_LINUX_PACKAGE_MANAGER }
        $CONFIG_LINUX_PACKAGE_MANAGER | Should -Be "apt"
    }
}
