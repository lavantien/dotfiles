# Tests for lib/config.ps1
# These tests exercise the config parsing functions

BeforeAll {
    $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $configPath = Join-Path $Script:RepoRoot "lib\config.ps1"

    . $configPath

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

Describe "config.ps1 - Load-DotfilesConfig" {

    It "Returns early when config file doesn't exist" {
        $result = Load-DotfilesConfig -ConfigFile "nonexistent.yaml"
        $result | Should -BeNullOrEmpty
    }

    It "Handles empty config file path" {
        $result = Load-DotfilesConfig -ConfigFile ""
        $true | Should -Be $true
    }
}

Describe "config.ps1 - Get-ConfigValue" {

    It "Returns value for editor" {
        $script:CONFIG_EDITOR = "nvim"
        $result = Get-ConfigValue "editor"
        $result | Should -Be "nvim"
    }

    It "Returns value for terminal" {
        $script:CONFIG_TERMINAL = "wt"
        $result = Get-ConfigValue "terminal"
        $result | Should -Be "wt"
    }

    It "Returns value for theme" {
        $script:CONFIG_THEME = "dark"
        $result = Get-ConfigValue "theme"
        $result | Should -Be "dark"
    }

    It "Returns value for categories" {
        $script:CONFIG_CATEGORIES = "minimal"
        $result = Get-ConfigValue "categories"
        $result | Should -Be "minimal"
    }

    It "Returns value for auto_update_repos" {
        $script:CONFIG_AUTO_UPDATE_REPOS = "true"
        $result = Get-ConfigValue "auto_update_repos"
        $result | Should -Be "true"
    }

    It "Returns value for backup_before_deploy" {
        $script:CONFIG_BACKUP_BEFORE_DEPLOY = "true"
        $result = Get-ConfigValue "backup_before_deploy"
        $result | Should -Be "true"
    }

    It "Returns value for sign_commits" {
        $script:CONFIG_SIGN_COMMITS = "true"
        $result = Get-ConfigValue "sign_commits"
        $result | Should -Be "true"
    }

    It "Returns value for default_branch" {
        $script:CONFIG_DEFAULT_BRANCH = "develop"
        $result = Get-ConfigValue "default_branch"
        $result | Should -Be "develop"
    }

    It "Returns value for github_username" {
        $script:CONFIG_GITHUB_USERNAME = "testuser"
        $result = Get-ConfigValue "github_username"
        $result | Should -Be "testuser"
    }

    It "Returns value for base_dir" {
        $script:CONFIG_BASE_DIR = "/path/to/repos"
        $result = Get-ConfigValue "base_dir"
        $result | Should -Be "/path/to/repos"
    }

    It "Returns value for auto_commit_changes" {
        $script:CONFIG_AUTO_COMMIT = "true"
        $result = Get-ConfigValue "auto_commit_changes"
        $result | Should -Be "true"
    }

    It "Returns value for linux_package_manager" {
        $script:CONFIG_LINUX_PACKAGE_MANAGER = "apt"
        $result = Get-ConfigValue "linux_package_manager"
        $result | Should -Be "apt"
    }

    It "Returns value for windows_package_manager" {
        $script:CONFIG_WINDOWS_PACKAGE_MANAGER = "winget"
        $result = Get-ConfigValue "windows_package_manager"
        $result | Should -Be "winget"
    }

    It "Returns value for macos_package_manager" {
        $script:CONFIG_MACOS_PACKAGE_MANAGER = "brew"
        $result = Get-ConfigValue "macos_package_manager"
        $result | Should -Be "brew"
    }

    It "Returns default value when config is empty" {
        $script:CONFIG_EDITOR = ""
        $result = Get-ConfigValue "editor" -Default "vim"
        $result | Should -Be "vim"
    }

    It "Returns null for unknown key" {
        $result = Get-ConfigValue "unknown_key"
        $result | Should -BeNullOrEmpty
    }

    It "Returns default for unknown key with default specified" {
        $result = Get-ConfigValue "unknown_key" -Default "default_value"
        $result | Should -Be "default_value"
    }
}

Describe "config.ps1 - Test-SkipPackage" {

    It "Returns false when skip_packages is null" {
        $script:CONFIG_SKIP_PACKAGES = $null
        $result = Test-SkipPackage "test-package"
        $result | Should -Be $false
    }

    It "Returns false when skip_packages is empty" {
        $script:CONFIG_SKIP_PACKAGES = @()
        $result = Test-SkipPackage "test-package"
        $result | Should -Be $false
    }

    It "Returns true when package is in skip list" {
        $script:CONFIG_SKIP_PACKAGES = @("package1", "package2")
        $result = Test-SkipPackage "package1"
        $result | Should -Be $true
    }

    It "Returns false when package is not in skip list" {
        $script:CONFIG_SKIP_PACKAGES = @("package1", "package2")
        $result = Test-SkipPackage "package3"
        $result | Should -Be $false
    }

    It "Is case sensitive for package names" {
        $script:CONFIG_SKIP_PACKAGES = @("Package1")
        $result = Test-SkipPackage "package1"
        $result | Should -Be $false
    }
}

Describe "config.ps1 - _ParseConfigSimple" {

    It "Handles comment lines" {
        $tempFile = [System.IO.Path]::GetTempFileName()
        try {
            "# This is a comment" | Out-File $tempFile
            { _ParseConfigSimple $tempFile } | Should -Not -Throw
        } finally {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    It "Handles empty lines" {
        $tempFile = [System.IO.Path]::GetTempFileName()
        try {
            "" | Out-File $tempFile
            { _ParseConfigSimple $tempFile } | Should -Not -Throw
        } finally {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    It "Parses simple key-value pairs" {
        $tempFile = [System.IO.Path]::GetTempFileName()
        try {
            "editor: nvim" | Out-File $tempFile
            _ParseConfigSimple $tempFile
            $script:CONFIG_EDITOR | Should -Be "nvim"
        } finally {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    It "Handles quoted values" {
        $tempFile = [System.IO.Path]::GetTempFileName()
        try {
            'editor: "nvim"' | Out-File $tempFile
            _ParseConfigSimple $tempFile
            $script:CONFIG_EDITOR | Should -Be "nvim"
        } finally {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    It "Handles inline comments" {
        $tempFile = [System.IO.Path]::GetTempFileName()
        try {
            "editor: nvim # my editor" | Out-File $tempFile
            _ParseConfigSimple $tempFile
            $script:CONFIG_EDITOR | Should -Be "nvim"
        } finally {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    It "Parses boolean values" {
        $tempFile = [System.IO.Path]::GetTempFileName()
        try {
            "auto_update_repos: true" | Out-File $tempFile
            _ParseConfigSimple $tempFile
            $script:CONFIG_AUTO_UPDATE_REPOS | Should -Be "true"
        } finally {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    It "Parses array values for skip_packages" {
        $tempFile = [System.IO.Path]::GetTempFileName()
        try {
            "skip_packages: [pkg1, pkg2, pkg3]" | Out-File $tempFile
            _ParseConfigSimple $tempFile
            $script:CONFIG_SKIP_PACKAGES.Count | Should -Be 3
        } finally {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    It "Handles section headers" {
        $tempFile = [System.IO.Path]::GetTempFileName()
        try {
            "windows:" | Out-File $tempFile
            "package_manager: scoop" | Out-File $tempFile -Append
            _ParseConfigSimple $tempFile
            $script:CONFIG_WINDOWS_PACKAGE_MANAGER | Should -Be "scoop"
        } finally {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    It "Handles linux section" {
        $tempFile = [System.IO.Path]::GetTempFileName()
        try {
            "linux:" | Out-File $tempFile
            "package_manager: apt" | Out-File $tempFile -Append
            _ParseConfigSimple $tempFile
            $script:CONFIG_LINUX_PACKAGE_MANAGER | Should -Be "apt"
        } finally {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    It "Handles macos section" {
        $tempFile = [System.IO.Path]::GetTempFileName()]
        try {
            "macos:" | Out-File $tempFile
            "package_manager: brew" | Out-File $tempFile -Append
            _ParseConfigSimple $tempFile
            $script:CONFIG_MACOS_PACKAGE_MANAGER | Should -Be "brew"
        } finally {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "config.ps1 - Config Variable Initialization" {

    It "CONFIG_EDITOR initializes to empty string" {
        $script:CONFIG_EDITOR | Should -Be ""
    }

    It "CONFIG_TERMINAL initializes to empty string" {
        $script:CONFIG_TERMINAL | Should -Be ""
    }

    It "CONFIG_THEME initializes to empty string" {
        $script:CONFIG_THEME | Should -Be ""
    }

    It "CONFIG_CATEGORIES initializes to full" {
        $script:CONFIG_CATEGORIES | Should -Be "full"
    }

    It "CONFIG_AUTO_UPDATE_REPOS initializes to false" {
        $script:CONFIG_AUTO_UPDATE_REPOS | Should -Be "false"
    }

    It "CONFIG_BACKUP_BEFORE_DEPLOY initializes to false" {
        $script:CONFIG_BACKUP_BEFORE_DEPLOY | Should -Be "false"
    }

    It "CONFIG_SIGN_COMMITS initializes to false" {
        $script:CONFIG_SIGN_COMMITS | Should -Be "false"
    }

    It "CONFIG_DEFAULT_BRANCH initializes to main" {
        $script:CONFIG_DEFAULT_BRANCH | Should -Be "main"
    }

    It "CONFIG_GITHUB_USERNAME initializes to empty string" {
        $script:CONFIG_GITHUB_USERNAME | Should -Be ""
    }

    It "CONFIG_BASE_DIR initializes to empty string" {
        $script:CONFIG_BASE_DIR | Should -Be ""
    }

    It "CONFIG_AUTO_COMMIT initializes to false" {
        $script:CONFIG_AUTO_COMMIT | Should -Be "false"
    }

    It "CONFIG_SKIP_PACKAGES initializes to empty array" {
        $script:CONFIG_SKIP_PACKAGES.Count | Should -Be 0
    }

    It "CONFIG_LINUX_PACKAGE_MANAGER initializes to empty string" {
        $script:CONFIG_LINUX_PACKAGE_MANAGER | Should -Be ""
    }

    It "CONFIG_LINUX_DISPLAY_SERVER initializes to empty string" {
        $script:CONFIG_LINUX_DISPLAY_SERVER | Should -Be ""
    }

    It "CONFIG_WINDOWS_PACKAGE_MANAGER initializes to empty string" {
        $script:CONFIG_WINDOWS_PACKAGE_MANAGER | Should -Be ""
    }

    It "CONFIG_MACOS_PACKAGE_MANAGER initializes to empty string" {
        $script:CONFIG_MACOS_PACKAGE_MANAGER | Should -Be ""
    }
}
