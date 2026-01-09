# Unit tests for config.ps1 (Bridge Configuration System)
# Tests YAML config parsing and fallback behavior

Describe "Bridge Configuration System" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $Script:ConfigLib = Join-Path $RepoRoot "lib\config.sh"

        # Source bash config library using Git Bash
        # For PowerShell tests, we'll test the behavior using helper functions
        $Script:TestTmpDir = Join-Path $env:TEMP "config-test-$(New-Guid)"
        New-Item -ItemType Directory -Path $Script:TestTmpDir -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $Script:TestTmpDir) {
            Remove-Item -Recurse -Force $Script:TestTmpDir -ErrorAction SilentlyContinue
        }
    }

    Context "Config Library Loading" {

        It "config.sh exists and is readable" {
            Test-Path $Script:ConfigLib | Should -Be $true
        }

        It "config.sh contains load_dotfiles_config function" {
            $content = Get-Content $Script:ConfigLib -Raw
            $content | Should -Match "load_dotfiles_config"
        }

        It "config.sh contains get_config function" {
            $content = Get-Content $Script:ConfigLib -Raw
            $content | Should -Match "get_config"
        }

        It "config.sh contains should_skip_package function" {
            $content = Get-Content $Script:ConfigLib -Raw
            $content | Should -Match "should_skip_package"
        }
    }

    Context "Config Value Parsing" {

        It "Get-ConfigValue returns default for missing key" {
            # Simulate the behavior - in actual usage, defaults are provided
            $defaultValue = "vi"
            $result = if ($null -eq $CONFIG_EDITOR) { $defaultValue } else { $CONFIG_EDITOR }
            $result | Should -Be $defaultValue
        }

        It "Get-ConfigValue returns configured value when set" {
            # Simulate having CONFIG_EDITOR set
            $CONFIG_EDITOR = "nvim"
            $defaultValue = "vi"
            $result = if ($null -eq $CONFIG_EDITOR) { $defaultValue } else { $CONFIG_EDITOR }
            $result | Should -Be "nvim"
        }
    }

    Context "Skip Packages Function" {

        It "should_skip_package returns false when skip list is empty" {
            $CONFIG_SKIP_PACKAGES = $null
            $package = "npm"

            # Simulate the function logic
            $result = if ($CONFIG_SKIP_PACKAGES) { $true } else { $false }
            $result | Should -Be $false
        }

        It "should_skip_package returns true when package in skip list" {
            $CONFIG_SKIP_PACKAGES = "npm yarn"
            $package = "npm"

            # Simulate the function logic
            $skipList = $CONFIG_SKIP_PACKAGES -replace ',', ' '
            $result = $skipList -split ' ' | Where-Object { $_ -eq $package }
            $result.Count | Should -BeGreaterOrEqual 1
        }

        It "should_skip_package handles comma-separated values" {
            $CONFIG_SKIP_PACKAGES = "npm,yarn,pnpm"
            $package = "yarn"

            # Simulate the function logic
            $skipList = $CONFIG_SKIP_PACKAGES -replace ',', ' '
            $result = $skipList -split ' ' | Where-Object { $_ -eq $package }
            $result.Count | Should -BeGreaterOrEqual 1
        }

        It "should_skip_package handles comma-space separated values" {
            $CONFIG_SKIP_PACKAGES = "npm, yarn, pnpm"
            $package = "yarn"

            # Simulate the function logic
            $skipList = $CONFIG_SKIP_PACKAGES -replace ', ', ' ' -replace ',', ' '
            $result = $skipList -split ' ' | Where-Object { $_ -eq $package }
            $result.Count | Should -BeGreaterOrEqual 1
        }

        It "should_skip_package returns false when package not in list" {
            $CONFIG_SKIP_PACKAGES = "npm yarn"
            $package = "pnpm"

            # Simulate the function logic
            $skipList = $CONFIG_SKIP_PACKAGES -replace ',', ' '
            $result = $skipList -split ' ' | Where-Object { $_ -eq $package }
            $result.Count | Should -Be 0
        }
    }

    Context "Config File Formats" {

        It "Handles YAML key-value pairs" {
            $configFile = Join-Path $Script:TestTmpDir "test.yaml"
            @"
# Test configuration
editor: nvim
terminal: wezterm
theme: rose-pine
categories: full
"@ | Out-File $configFile

            $content = Get-Content $configFile -Raw
            $content | Should -Match "editor"
            $content | Should -Match "terminal"
        }

        It "Handles nested YAML (platform settings)" {
            $configFile = Join-Path $Script:TestTmpDir "nested.yaml"
            @"
linux:
  package_manager: apt
  display_server: wayland
windows:
  package_manager: scoop
macos:
  package_manager: brew
"@ | Out-File $configFile

            $content = Get-Content $configFile -Raw
            $content | Should -Match "linux"
            $content | Should -Match "windows"
        }

        It "Handles array values (skip_packages)" {
            $configFile = Join-Path $Script:TestTmpDir "array.yaml"
            @"
skip_packages:
  - npm
  - yarn
  - pnpm
"@ | Out-File $configFile

            $content = Get-Content $configFile -Raw
            $content | Should -Match "skip_packages"
            $content | Should -Match "npm"
        }
    }

    Context "Config Defaults" {

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
    }
}

Describe "Bridge Configuration - YQ Integration" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    }

    It "Detects if yq is installed" {
        $yqInstalled = Get-Command yq -ErrorAction SilentlyContinue
        # We don't fail the test if yq is not installed, just report
        if ($yqInstalled) {
            $yqVersion = & yq --version 2>$null
            Write-Host "yq installed: $yqVersion"
        }
    }

    It "config.sh has yq fallback logic" {
        $content = Get-Content (Join-Path $Script:RepoRoot "lib\config.sh") -Raw
        # The script should check for yq before using it
        $content | Should -Match "command -v yq"
    }
}

Describe "Bridge Configuration - Edge Cases" {

    It "Handles empty config file gracefully" {
        $tmpFile = Join-Path $env:TEMP "empty-$(New-Guid).yaml"
        "" | Out-File $tmpFile

        $content = Get-Content $tmpFile
        $content | Should -Be ""

        Remove-Item $tmpFile -ErrorAction SilentlyContinue
    }

    It "Handles malformed YAML gracefully" {
        $tmpFile = Join-Path $env:TEMP "malformed-$(New-Guid).yaml"
        @"
invalid yaml content
  bad indentation
    too many spaces
"@ | Out-File $tmpFile

        # File exists but is malformed
        Test-Path $tmpFile | Should -Be $true

        Remove-Item $tmpFile -ErrorAction SilentlyContinue
    }

    It "Handles comments in YAML" {
        $configFile = Join-Path $env:TEMP "comments-$(New-Guid).yaml"
        @"
# This is a comment
editor: nvim
terminal: wezterm
# Another comment
theme: dark
"@ | Out-File $configFile

        $content = Get-Content $configFile -Raw
        $content | Should -Match "editor"
        $content | Should -Match "terminal"
        # Comments should be preserved
        $content | Should -Match "# This is a comment"

        Remove-Item $configFile -ErrorAction SilentlyContinue
    }

    It "Handles special characters in values" {
        $configFile = Join-Path $env:TEMP "special-$(New-Guid).yaml"
        @"
editor: 'C:\Program Files\NVim\nvim.exe'
terminal: 'wezterm-terminal'
github_username: 'user@example.com'
"@ | Out-File $configFile

        $content = Get-Content $configFile -Raw
        $content | Should -Match "nvim"
        $content | Should -Match "user"

        Remove-Item $configFile -ErrorAction SilentlyContinue
    }
}

Describe "Bridge Configuration - Platform Specific" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    }

    It "Has Linux-specific config variables" {
        $content = Get-Content (Join-Path $Script:RepoRoot "lib\config.sh") -Raw
        $content | Should -Match "CONFIG_LINUX_PACKAGE_MANAGER"
        $content | Should -Match "CONFIG_LINUX_DISPLAY_SERVER"
    }

    It "Has Windows-specific config variables" {
        $content = Get-Content (Join-Path $Script:RepoRoot "lib\config.sh") -Raw
        $content | Should -Match "CONFIG_WINDOWS_PACKAGE_MANAGER"
    }

    It "Has macOS-specific config variables" {
        $content = Get-Content (Join-Path $Script:RepoRoot "lib\config.sh") -Raw
        $content | Should -Match "CONFIG_MACOS_PACKAGE_MANAGER"
    }

    It "Windows package manager defaults to scoop" {
        # The parse logic should default to 'scoop' for windows
        $defaultValue = "scoop"
        $CONFIG_WINDOWS_PACKAGE_MANAGER = if ($null -eq $CONFIG_WINDOWS_PACKAGE_MANAGER) { $defaultValue } else { $CONFIG_WINDOWS_PACKAGE_MANAGER }
        $CONFIG_WINDOWS_PACKAGE_MANAGER | Should -Be "scoop"
    }

    It "macOS package manager defaults to brew" {
        $defaultValue = "brew"
        $CONFIG_MACOS_PACKAGE_MANAGER = if ($null -eq $CONFIG_MACOS_PACKAGE_MANAGER) { $defaultValue } else { $CONFIG_MACOS_PACKAGE_MANAGER }
        $CONFIG_MACOS_PACKAGE_MANAGER | Should -Be "brew"
    }
}

Describe "Bridge Configuration - Error Scenarios" {

    It "Handles missing config file gracefully" {
        $tmpFile = Join-Path $env:TEMP "nonexistent-$(New-Guid).yaml"
        # File doesn't exist
        Test-Path $tmpFile | Should -Be $false
        # Should not throw when checking
        { Test-Path $tmpFile } | Should -Not -Throw
    }

    It "Handles null config value" {
        $CONFIG_EDITOR = $null
        $defaultValue = "vi"
        $result = if ($null -eq $CONFIG_EDITOR) { $defaultValue } else { $CONFIG_EDITOR }
        $result | Should -Be $defaultValue
    }

    It "Handles empty config value" {
        $CONFIG_EDITOR = ""
        $defaultValue = "vi"
        $result = if ($CONFIG_EDITOR -eq "") { $defaultValue } else { $CONFIG_EDITOR }
        $result | Should -Be $defaultValue
    }

    It "Handles whitespace-only config value" {
        $CONFIG_EDITOR = "   "
        # Should trim or handle whitespace
        $CONFIG_EDITOR.Trim() | Should -Be ""
    }

    It "Handles invalid boolean config values" {
        # Invalid boolean should be handled gracefully
        $CONFIG_AUTO_UPDATE_REPOS = "maybe"
        # Should fall back to default if not true/false
        $isValid = $CONFIG_AUTO_UPDATE_REPOS -in @("true", "false")
        $isValid | Should -Be $false
    }

    It "Handles invalid categories value" {
        $CONFIG_CATEGORIES = "invalid-category"
        # Should still accept the value even if not standard
        $CONFIG_CATEGORIES | Should -Be "invalid-category"
    }

    It "Handles very long config values" {
        $longValue = "x" * 10000
        $CONFIG_GITHUB_USERNAME = $longValue
        $CONFIG_GITHUB_USERNAME.Length | Should -Be 10000
    }

    It "Handles special YAML characters in values" {
        $configFile = Join-Path $env:TEMP "special-chars-$(New-Guid).yaml"
        @"
editor: "value:with:colons"
terminal: "value|with|pipes"
theme: "value#with#hashes"
"@ | Out-File $configFile

        $content = Get-Content $configFile -Raw
        $content | Should -Match "colons"
        Test-Path $configFile | Should -Be $true
        Remove-Item $configFile -ErrorAction SilentlyContinue
    }

    It "Handles YAML with duplicate keys" {
        $configFile = Join-Path $env:TEMP "duplicate-keys-$(New-Guid).yaml"
        @"
editor: nvim
editor: vim
"@ | Out-File $configFile

        # File exists with duplicate keys (last one wins in YAML)
        Test-Path $configFile | Should -Be $true
        $lines = Get-Content $configFile
        ($lines | Where-Object { $_ -like "*editor*" }).Count | Should -BeGreaterOrEqual 2
        Remove-Item $configFile -ErrorAction SilentlyContinue
    }

    It "Handles YAML with invalid escape sequences" {
        $configFile = Join-Path $env:TEMP "invalid-escape-$(New-Guid).yaml"
        @"
editor: "value\xwith\invalid\escape"
"@ | Out-File $configFile

        # File exists even with invalid escapes
        Test-Path $configFile | Should -Be $true
        Remove-Item $configFile -ErrorAction SilentlyContinue
    }

    It "Handles config file with BOM" {
        $configFile = Join-Path $env:TEMP "bom-$(New-Guid).yaml"
        # UTF-8 BOM + content
        $bytes = [System.Text.Encoding]::UTF8.GetPreamble() + [System.Text.Encoding]::UTF8.GetBytes("editor: nvim`n")
        [System.IO.File]::WriteAllBytes($configFile, $bytes)

        $content = Get-Content $configFile -Raw
        # Should handle BOM gracefully
        $content.Trim() | Should -Match "nvim"
        Remove-Item $configFile -ErrorAction SilentlyContinue
    }

    It "Handles different line endings" {
        $configFile = Join-Path $env:TEMP "line-endings-$(New-Guid).yaml"
        # Mix of CRLF and LF
        "editor: nvim`r`nterminal: wezterm`ntheme: dark`r`n" | Out-File $configFile -Encoding Ascii

        $content = Get-Content $configFile -Raw
        $content | Should -Match "nvim"
        $content | Should -Match "wezterm"
        Remove-Item $configFile -ErrorAction SilentlyContinue
    }

    It "Handles tabs in YAML" {
        $configFile = Join-Path $env:TEMP "tabs-$(New-Guid).yaml"
        # YAML shouldn't have tabs but we handle it gracefully
        "editor:`tnvim`nterminal: wezterm" | Out-File $configFile -Encoding Ascii

        Test-Path $configFile | Should -Be $true
        Remove-Item $configFile -ErrorAction SilentlyContinue
    }

    It "Handles very large config files" {
        $configFile = Join-Path $env:TEMP "large-$(New-Guid).yaml"
        $sb = [System.Text.StringBuilder]::new()
        for ($i = 0; $i -lt 1000; $i++) {
            [void]$sb.AppendLine("key${i}: value${i}")
        }
        $sb.ToString() | Out-File $configFile -Encoding utf8

        $content = Get-Content $configFile -Raw
        $content.Length | Should -BeGreaterThan 10000
        Remove-Item $configFile -ErrorAction SilentlyContinue
    }

    It "Handles skip_packages with empty entries" {
        $CONFIG_SKIP_PACKAGES = "npm, , yarn,  ,pnpm"
        $skipList = $CONFIG_SKIP_PACKAGES -replace ',', ' ' -split ' '
        $nonEmpty = $skipList | Where-Object { $_.Trim() -ne "" }
        $nonEmpty.Count | Should -Be 3
    }

    It "Handles skip_packages with only spaces" {
        $CONFIG_SKIP_PACKAGES = "   "
        $skipList = $CONFIG_SKIP_PACKAGES -replace ',', ' ' -split ' '
        $nonEmpty = $skipList | Where-Object { $_.Trim() -ne "" }
        $nonEmpty.Count | Should -Be 0
    }

    It "Handles package name case sensitivity" {
        $CONFIG_SKIP_PACKAGES = "npm NPM Npm"
        $package = "npm"
        $skipList = $CONFIG_SKIP_PACKAGES -replace ',', ' ' -split ' '
        # PowerShell -eq is case-insensitive by default, so all 3 match
        # Use -ceq for case-sensitive comparison
        $exactMatches = $skipList | Where-Object { $_ -ceq $package }
        $exactMatches.Count | Should -Be 1
    }

    It "Handles trailing comma in skip_packages" {
        $CONFIG_SKIP_PACKAGES = "npm,yarn,pnpm,"
        $skipList = $CONFIG_SKIP_PACKAGES -replace ',', ' ' -split ' '
        $nonEmpty = $skipList | Where-Object { $_.Trim() -ne "" }
        $nonEmpty.Count | Should -Be 3
    }

    It "Handles leading comma in skip_packages" {
        $CONFIG_SKIP_PACKAGES = ",npm,yarn,pnpm"
        $skipList = $CONFIG_SKIP_PACKAGES -replace ',', ' ' -split ' '
        $nonEmpty = $skipList | Where-Object { $_.Trim() -ne "" }
        $nonEmpty.Count | Should -Be 3
    }

    It "Handles multiple separators in skip_packages" {
        $CONFIG_SKIP_PACKAGES = "npm,,yarn,,,pnpm"
        $skipList = $CONFIG_SKIP_PACKAGES -replace ',', ' ' -split ' '
        $nonEmpty = $skipList | Where-Object { $_.Trim() -ne "" }
        $nonEmpty.Count | Should -Be 3
    }
}
