# Unit tests for lib/config.ps1
# Tests PowerShell configuration parser and getters

BeforeAll {
    $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $Script:ConfigPs1 = Join-Path $RepoRoot "lib\config.ps1"

    # Source the config library
    . $Script:ConfigPs1

    # Reset config variables
    $script:CONFIG_EDITOR = ""
    $script:CONFIG_TERMINAL = ""
    $script:CONFIG_THEME = ""
    $script:CONFIG_CATEGORIES = "full"
    $script:CONFIG_AUTO_UPDATE_REPOS = "false"
    $script:CONFIG_BACKUP_BEFORE_DEPLOY = "false"
    $script:CONFIG_SIGN_COMMITS = "false"
    $script:CONFIG_DEFAULT_BRANCH = "main"
    $script:CONFIG_GITHUB_USERNAME = ""
    $script:CONFIG_BASE_DIR = ""
    $script:CONFIG_AUTO_COMMIT = "false"
    $script:CONFIG_SKIP_PACKAGES = @()
    $script:CONFIG_LINUX_PACKAGE_MANAGER = ""
    $script:CONFIG_LINUX_DISPLAY_SERVER = ""
    $script:CONFIG_WINDOWS_PACKAGE_MANAGER = ""
    $script:CONFIG_MACOS_PACKAGE_MANAGER = ""
}

Describe "PowerShell Config Library - Load Functions" {

    BeforeEach {
        # Reset config variables before each test
        $script:CONFIG_EDITOR = ""
        $script:CONFIG_TERMINAL = ""
        $script:CONFIG_THEME = ""
        $script:CONFIG_CATEGORIES = "full"
        $script:CONFIG_AUTO_UPDATE_REPOS = "false"
        $script:CONFIG_BACKUP_BEFORE_DEPLOY = "false"
        $script:CONFIG_SIGN_COMMITS = "false"
        $script:CONFIG_DEFAULT_BRANCH = "main"
        $script:CONFIG_GITHUB_USERNAME = ""
        $script:CONFIG_BASE_DIR = ""
        $script:CONFIG_AUTO_COMMIT = "false"
        $script:CONFIG_SKIP_PACKAGES = @()
    }

    It "Load-DotfilesConfig function exists" {
        { Get-Command Load-DotfilesConfig -ErrorAction Stop } | Should -Not -Throw
    }

    It "Load-DotfilesConfig returns without error for non-existent file" {
        $nonExistentFile = Join-Path $env:TEMP "nonexistent-config-$(New-Guid).yaml"
        { Load-DotfilesConfig -ConfigFile $nonExistentFile } | Should -Not -Throw
    }

    It "Load-DotfilesConfig preserves defaults when file doesn't exist" {
        $nonExistentFile = Join-Path $env:TEMP "nonexistent-config-$(New-Guid).yaml"
        Load-DotfilesConfig -ConfigFile $nonExistentFile
        $script:CONFIG_CATEGORIES | Should -Be "full"
    }
}

Describe "PowerShell Config Library - Simple Parser" {

    BeforeEach {
        # Reset config variables
        $script:CONFIG_EDITOR = ""
        $script:CONFIG_TERMINAL = ""
        $script:CONFIG_THEME = ""
        $script:CONFIG_CATEGORIES = "full"
        $script:CONFIG_AUTO_UPDATE_REPOS = "false"
        $script:CONFIG_BACKUP_BEFORE_DEPLOY = "false"
        $script:CONFIG_SIGN_COMMITS = "false"
        $script:CONFIG_DEFAULT_BRANCH = "main"
        $script:CONFIG_GITHUB_USERNAME = ""
        $script:CONFIG_BASE_DIR = ""
        $script:CONFIG_AUTO_COMMIT = "false"
        $script:CONFIG_SKIP_PACKAGES = @()
    }

    It "_ParseConfigSimple parses key-value pairs" {
        $configFile = Join-Path $env:TEMP "test-config-$(New-Guid).yaml"
        "editor: nvim" | Out-File $configFile

        _ParseConfigSimple $configFile
        $script:CONFIG_EDITOR | Should -Be "nvim"

        Remove-Item $configFile -ErrorAction SilentlyContinue
    }

    It "_ParseConfigSimple handles comments" {
        $configFile = Join-Path $env:TEMP "test-config-$(New-Guid).yaml"
        @"
# This is a comment
editor: nvim
terminal: wezterm
# Another comment
theme: dark
"@ | Out-File $configFile

        _ParseConfigSimple $configFile
        $script:CONFIG_EDITOR | Should -Be "nvim"
        $script:CONFIG_TERMINAL | Should -Be "wezterm"
        $script:CONFIG_THEME | Should -Be "dark"

        Remove-Item $configFile -ErrorAction SilentlyContinue
    }

    It "_ParseConfigSimple handles quoted values" {
        $configFile = Join-Path $env:TEMP "test-config-$(New-Guid).yaml"
        'editor: "nvim"' | Out-File $configFile

        _ParseConfigSimple $configFile
        $script:CONFIG_EDITOR | Should -Be "nvim"

        Remove-Item $configFile -ErrorAction SilentlyContinue
    }

    It "_ParseConfigSimple handles array values" {
        $configFile = Join-Path $env:TEMP "test-config-$(New-Guid).yaml"
        "skip_packages: [npm, yarn, pnpm]" | Out-File $configFile

        _ParseConfigSimple $configFile
        $script:CONFIG_SKIP_PACKAGES.Count | Should -Be 3
        $script:CONFIG_SKIP_PACKAGES | Should -Contain "npm"
        $script:CONFIG_SKIP_PACKAGES | Should -Contain "yarn"
        $script:CONFIG_SKIP_PACKAGES | Should -Contain "pnpm"

        Remove-Item $configFile -ErrorAction SilentlyContinue
    }

    It "_ParseConfigSimple handles inline comments" {
        $configFile = Join-Path $env:TEMP "test-config-$(New-Guid).yaml"
        "editor: nvim # my favorite editor" | Out-File $configFile

        _ParseConfigSimple $configFile
        $script:CONFIG_EDITOR | Should -Be "nvim"

        Remove-Item $configFile -ErrorAction SilentlyContinue
    }

    It "_ParseConfigSimple handles platform sections" {
        $configFile = Join-Path $env:TEMP "test-config-$(New-Guid).yaml"
        @"
windows:
  package_manager: scoop
linux:
  package_manager: apt
macos:
  package_manager: brew
"@ | Out-File $configFile

        _ParseConfigSimple $configFile
        $script:CONFIG_WINDOWS_PACKAGE_MANAGER | Should -Be "scoop"
        $script:CONFIG_LINUX_PACKAGE_MANAGER | Should -Be "apt"
        $script:CONFIG_MACOS_PACKAGE_MANAGER | Should -Be "brew"

        Remove-Item $configFile -ErrorAction SilentlyContinue
    }
}

Describe "PowerShell Config Library - Getters" {

    BeforeEach {
        # Reset config variables
        $script:CONFIG_EDITOR = ""
        $script:CONFIG_TERMINAL = ""
        $script:CONFIG_THEME = ""
        $script:CONFIG_CATEGORIES = "full"
        $script:CONFIG_AUTO_UPDATE_REPOS = "false"
        $script:CONFIG_BACKUP_BEFORE_DEPLOY = "false"
        $script:CONFIG_SIGN_COMMITS = "false"
        $script:CONFIG_DEFAULT_BRANCH = "main"
        $script:CONFIG_GITHUB_USERNAME = ""
        $script:CONFIG_BASE_DIR = ""
        $script:CONFIG_AUTO_COMMIT = "false"
        $script:CONFIG_SKIP_PACKAGES = @()
    }

    It "Get-ConfigValue function exists" {
        { Get-Command Get-ConfigValue -ErrorAction Stop } | Should -Not -Throw
    }

    It "Get-ConfigValue returns default for missing key" {
        $result = Get-ConfigValue -Key "nonexistent" -Default "default_value"
        $result | Should -Be "default_value"
    }

    It "Get-ConfigValue returns configured value" {
        $script:CONFIG_EDITOR = "nvim"
        $result = Get-ConfigValue -Key "editor" -Default "vi"
        $result | Should -Be "nvim"
    }

    It "Get-ConfigValue returns empty string for unset value without default" {
        $result = Get-ConfigValue -Key "editor"
        $result | Should -Be ""
    }

    It "Get-ConfigValue handles all known keys" {
        $script:CONFIG_EDITOR = "nvim"
        $script:CONFIG_TERMINAL = "wezterm"
        $script:CONFIG_THEME = "dark"
        $script:CONFIG_CATEGORIES = "minimal"
        $script:CONFIG_AUTO_UPDATE_REPOS = "true"
        $script:CONFIG_BACKUP_BEFORE_DEPLOY = "true"
        $script:CONFIG_SIGN_COMMITS = "true"
        $script:CONFIG_DEFAULT_BRANCH = "develop"
        $script:CONFIG_GITHUB_USERNAME = "testuser"
        $script:CONFIG_BASE_DIR = "/tmp/test"

        Get-ConfigValue -Key "editor" | Should -Be "nvim"
        Get-ConfigValue -Key "terminal" | Should -Be "wezterm"
        Get-ConfigValue -Key "theme" | Should -Be "dark"
        Get-ConfigValue -Key "categories" | Should -Be "minimal"
        Get-ConfigValue -Key "auto_update_repos" | Should -Be "true"
        Get-ConfigValue -Key "backup_before_deploy" | Should -Be "true"
        Get-ConfigValue -Key "sign_commits" | Should -Be "true"
        Get-ConfigValue -Key "default_branch" | Should -Be "develop"
        Get-ConfigValue -Key "github_username" | Should -Be "testuser"
        Get-ConfigValue -Key "base_dir" | Should -Be "/tmp/test"
    }
}

Describe "PowerShell Config Library - Test-SkipPackage" {

    BeforeEach {
        $script:CONFIG_SKIP_PACKAGES = @()
    }

    It "Test-SkipPackage function exists" {
        { Get-Command Test-SkipPackage -ErrorAction Stop } | Should -Not -Throw
    }

    It "Test-SkipPackage returns false when skip list is empty" {
        $result = Test-SkipPackage "npm"
        $result | Should -Be $false
    }

    It "Test-SkipPackage returns false when skip list is null" {
        $script:CONFIG_SKIP_PACKAGES = $null
        $result = Test-SkipPackage "npm"
        $result | Should -Be $false
    }

    It "Test-SkipPackage returns true when package is in skip list" {
        $script:CONFIG_SKIP_PACKAGES = @("npm", "yarn", "pnpm")
        $result = Test-SkipPackage "npm"
        $result | Should -Be $true
    }

    It "Test-SkipPackage returns false when package not in skip list" {
        $script:CONFIG_SKIP_PACKAGES = @("npm", "yarn")
        $result = Test-SkipPackage "pnpm"
        $result | Should -Be $false
    }

    It "Test-SkipPackage is case-sensitive" {
        $script:CONFIG_SKIP_PACKAGES = @("npm")
        $result = Test-SkipPackage "NPM"
        $result | Should -Be $false
    }
}

Describe "PowerShell Config Library - Config Variables" {

    It "Has all expected config variables" {
        $script:CONFIG_EDITOR | Should -Not -Be $null
        $script:CONFIG_TERMINAL | Should -Not -Be $null
        $script:CONFIG_THEME | Should -Not -Be $null
        $script:CONFIG_CATEGORIES | Should -Not -Be $null
        $script:CONFIG_AUTO_UPDATE_REPOS | Should -Not -Be $null
        $script:CONFIG_BACKUP_BEFORE_DEPLOY | Should -Not -Be $null
        $script:CONFIG_SIGN_COMMITS | Should -Not -Be $null
        $script:CONFIG_DEFAULT_BRANCH | Should -Not -Be $null
        $script:CONFIG_GITHUB_USERNAME | Should -Not -Be $null
        $script:CONFIG_BASE_DIR | Should -Not -Be $null
        $script:CONFIG_AUTO_COMMIT | Should -Not -Be $null
        $script:CONFIG_SKIP_PACKAGES | Should -Not -Be $null
    }

    It "Has platform-specific config variables" {
        $script:CONFIG_LINUX_PACKAGE_MANAGER | Should -Not -Be $null
        $script:CONFIG_LINUX_DISPLAY_SERVER | Should -Not -Be $null
        $script:CONFIG_WINDOWS_PACKAGE_MANAGER | Should -Not -Be $null
        $script:CONFIG_MACOS_PACKAGE_MANAGER | Should -Not -Be $null
    }

    It "CONFIG_CATEGORIES defaults to 'full'" {
        $script:CONFIG_CATEGORIES | Should -Be "full"
    }

    It "CONFIG_AUTO_UPDATE_REPOS defaults to 'false'" {
        $script:CONFIG_AUTO_UPDATE_REPOS | Should -Be "false"
    }

    It "CONFIG_BACKUP_BEFORE_DEPLOY defaults to 'false'" {
        $script:CONFIG_BACKUP_BEFORE_DEPLOY | Should -Be "false"
    }

    It "CONFIG_SIGN_COMMITS defaults to 'false'" {
        $script:CONFIG_SIGN_COMMITS | Should -Be "false"
    }

    It "CONFIG_DEFAULT_BRANCH defaults to 'main'" {
        $script:CONFIG_DEFAULT_BRANCH | Should -Be "main"
    }

    It "CONFIG_AUTO_COMMIT defaults to 'false'" {
        $script:CONFIG_AUTO_COMMIT | Should -Be "false"
    }

    It "CONFIG_SKIP_PACKAGES defaults to empty array" {
        $script:CONFIG_SKIP_PACKAGES.Count | Should -Be 0
    }
}

Describe "PowerShell Config Library - Module Parser" {

    It "_ParseConfigWithModule function exists" {
        { Get-Command _ParseConfigWithModule -ErrorAction SilentlyContinue } | Should -Not -Throw
    }

    It "Checks for powershell-yaml module" {
        # The function checks Get-Module -ListAvailable for powershell-yaml
        { Get-Module -ListAvailable -Name powershell-yaml -ErrorAction SilentlyContinue } | Should -Not -Throw
    }
}

Describe "PowerShell Config Library - Edge Cases" {

    BeforeEach {
        # Reset config variables
        $script:CONFIG_EDITOR = ""
        $script:CONFIG_TERMINAL = ""
        $script:CONFIG_THEME = ""
        $script:CONFIG_CATEGORIES = "full"
        $script:CONFIG_AUTO_UPDATE_REPOS = "false"
        $script:CONFIG_BACKUP_BEFORE_DEPLOY = "false"
        $script:CONFIG_SIGN_COMMITS = "false"
        $script:CONFIG_DEFAULT_BRANCH = "main"
        $script:CONFIG_GITHUB_USERNAME = ""
        $script:CONFIG_BASE_DIR = ""
        $script:CONFIG_AUTO_COMMIT = "false"
        $script:CONFIG_SKIP_PACKAGES = @()
    }

    It "Handles empty config file" {
        $configFile = Join-Path $env:TEMP "empty-config-$(New-Guid).yaml"
        "" | Out-File $configFile

        { _ParseConfigSimple $configFile } | Should -Not -Throw

        Remove-Item $configFile -ErrorAction SilentlyContinue
    }

    It "Handles config file with only comments" {
        $configFile = Join-Path $env:TEMP "comments-only-$(New-Guid).yaml"
        @"
# Comment 1
# Comment 2
"@ | Out-File $configFile

        { _ParseConfigSimple $configFile } | Should -Not -Throw

        Remove-Item $configFile -ErrorAction SilentlyContinue
    }

    It "Handles malformed key-value pairs gracefully" {
        $configFile = Join-Path $env:TEMP "malformed-$(New-Guid).yaml"
        "invalid line without colon" | Out-File $configFile

        { _ParseConfigSimple $configFile } | Should -Not -Throw

        Remove-Item $configFile -ErrorAction SilentlyContinue
    }

    It "Get-ConfigValue handles null key" {
        $result = Get-ConfigValue -Key $null -Default "default"
        $result | Should -Be "default"
    }

    It "Get-ConfigValue handles empty key" {
        $result = Get-ConfigValue -Key "" -Default "default"
        $result | Should -Be "default"
    }

    It "Test-SkipPackage handles null package name" {
        $script:CONFIG_SKIP_PACKAGES = @("npm", "yarn")
        $result = Test-SkipPackage $null
        $result | Should -Be $false
    }

    It "Test-SkipPackage handles empty package name" {
        $script:CONFIG_SKIP_PACKAGES = @("npm", "yarn")
        $result = Test-SkipPackage ""
        $result | Should -Be $false
    }
}
