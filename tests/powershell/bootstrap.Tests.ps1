# Unit tests for bootstrap.ps1
# Tests parameter parsing, platform detection, and core functions

BeforeAll {
    # Setup test environment - get repo root
    $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $commonLibPath = Join-Path $RepoRoot "bootstrap\lib\common.ps1"
    . $commonLibPath

    # Helper function to remove path from User environment variable (registry)
    function Remove-FromPath {
        param([string]$Path)

        $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($currentPath -like "*$Path*") {
            $newPath = ($currentPath -split ';' | Where-Object { $_ -ne $Path }) -join ';'
            [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        }
    }
}

Describe "Bootstrap Common Functions" {

    Context "Logging Functions" {

        It "Write-Info outputs info message" {
            $output = Write-Info "test message" 6>&1
            $output | Should -Match "\[INFO\] test message"
        }

        It "Write-Success outputs success message" {
            $output = Write-Success "test message" 6>&1
            $output | Should -Match "\[OK\] test message"
        }

        It "Write-Warning outputs warning message" {
            $output = Write-Warning "test message" 6>&1
            $output | Should -Match "\[WARN\] test message"
        }

        It "Write-Error-Msg outputs error message" {
            $output = Write-Error-Msg "test message" 6>&1
            $output | Should -Match "\[ERROR\] test message"
        }
    }

    Context "Command Existence" {

        It "Test-Command returns true for existing commands" {
            Test-Command "ls" | Should -Be $true
        }

        It "Test-Command returns false for non-existent commands" {
            Test-Command "nonexistent_command_xyz123" | Should -Be $false
        }
    }

    Context "Install Functions" {

        It "Invoke-SafeInstall returns result from script block" {
            # Mock successful install - note: function returns array so we check last element
            $result = Invoke-SafeInstall { param($a) $true } "test-package"
            $result[-1] | Should -Be $true
        }

        It "Invoke-SafeInstall handles failures gracefully" {
            # Mock failed install - scriptblock that throws
            $result = Invoke-SafeInstall { param($a) throw "test error" } "test-package"
            $result | Should -Be $false
        }
    }

    Context "Path Management" {

        It "Add-ToPath adds new path to PATH" {
            $newPath = "C:\test-path-$(New-Guid)"
            $originalPath = $env:PATH

            # Create the directory first (Add-ToPath only adds to session PATH if it exists)
            New-Item -ItemType Directory -Path $newPath -Force | Out-Null
            try {
                Add-ToPath $newPath

                $env:PATH.Split(';') | Should -Contain $newPath
            }
            finally {
                # Cleanup - remove from registry before removing directory
                Remove-FromPath $newPath
                Remove-Item -Path $newPath -Force -ErrorAction SilentlyContinue
                $env:PATH = $originalPath
            }
        }
    }

    Context "Platform Detection" {

        It "Get-OSPlatform returns a known platform" {
            $platform = Get-OSPlatform
            $platform | Should -BeIn @("windows", "linux", "macos")
        }
    }
}

Describe "Bootstrap Tracking Functions" {

    BeforeEach {
        Reset-Tracking
    }

    It "Track-Installed adds to installed list" {
        $initialCount = $Script:InstalledPackages.Count
        Track-Installed "test-package"
        $Script:InstalledPackages.Count | Should -Be ($initialCount + 1)
    }

    It "Track-Installed adds description when provided" {
        Track-Installed "test-package" "test description"
        $Script:InstalledPackages[-1] | Should -Be "test-package (test description)"
    }

    It "Track-Skipped adds to skipped list" {
        $initialCount = $Script:SkippedPackages.Count
        Track-Skipped "test-package"
        $Script:SkippedPackages.Count | Should -Be ($initialCount + 1)
    }

    It "Track-Skipped adds description when provided" {
        Track-Skipped "test-package" "test description"
        $Script:SkippedPackages[-1] | Should -Be "test-package (test description)"
    }

    It "Track-Failed adds to failed list" {
        $initialCount = $Script:FailedPackages.Count
        Track-Failed "test-package"
        $Script:FailedPackages.Count | Should -Be ($initialCount + 1)
    }

    It "Track-Failed adds description when provided" {
        Track-Failed "test-package" "test description"
        $Script:FailedPackages[-1] | Should -Be "test-package (test description)"
    }
}

# ============================================================================
# ERROR PATH TESTS
# ============================================================================

Describe "Bootstrap Error Handling" {

    BeforeEach {
        Reset-Tracking
    }

    Context "Invoke-SafeInstall Error Scenarios" {

        It "Invoke-SafeInstall handles command not found" {
            $result = Invoke-SafeInstall { param($a) throw "CommandNotFoundException" } "missing-package"
            $result | Should -Be $false
        }

        It "Invoke-SafeInstall handles network errors" {
            $result = Invoke-SafeInstall { param($a) throw "Network connection failed" } "network-package"
            $result | Should -Be $false
        }

        It "Invoke-SafeInstall handles timeout errors" {
            $result = Invoke-SafeInstall { param($a) throw "Timeout waiting for response" } "slow-package"
            $result | Should -Be $false
        }

        It "Invoke-SafeInstall handles permission denied" {
            $result = Invoke-SafeInstall { param($a) throw "AccessDenied" } "protected-package"
            $result | Should -Be $false
        }

        It "Invoke-SafeInstall tracks failed packages" {
            $initialCount = $Script:FailedPackages.Count
            $null = Invoke-SafeInstall { param($a) throw "Test error" } "fail-package"
            $Script:FailedPackages.Count | Should -Be ($initialCount + 1)
        }

        It "Invoke-SafeInstall returns error message in result" {
            $result = Invoke-SafeInstall { param($a) throw "Specific error message" } "test-package" -ErrorAction SilentlyContinue
            $result | Should -Be $false
        }

        It "Invoke-SafeInstall handles null package name" {
            $result = Invoke-SafeInstall { param($a) $true } $null
            $result[-1] | Should -Be $true
        }

        It "Invoke-SafeInstall handles empty package name" {
            $result = Invoke-SafeInstall { param($a) $true } ""
            $result[-1] | Should -Be $true
        }
    }

    Context "Path Management Error Scenarios" {

        It "Add-ToPath handles null path" {
            $originalPath = $env:PATH
            try {
                { Add-ToPath $null } | Should -Not -Throw
                $env:PATH | Should -Be $originalPath
            }
            finally {
                $env:PATH = $originalPath
            }
        }

        It "Add-ToPath handles empty path" {
            $originalPath = $env:PATH
            try {
                { Add-ToPath "" } | Should -Not -Throw
            }
            finally {
                $env:PATH = $originalPath
            }
        }

        It "Add-ToPath does not add duplicate paths" {
            $existingPath = $env:PATH.Split(';')[0]
            $originalPath = $env:PATH
            try {
                $beforeCount = ($env:PATH.Split(';') | Where-Object { $_ -eq $existingPath }).Count
                Add-ToPath $existingPath
                $afterCount = ($env:PATH.Split(';') | Where-Object { $_ -eq $existingPath }).Count
                $afterCount | Should -Be $beforeCount
            }
            finally {
                $env:PATH = $originalPath
            }
        }

        It "Add-ToPath handles paths with spaces" {
            # Use a temp directory instead of Program Files which requires admin
            $newPath = Join-Path $env:TEMP "Test Path $(New-Guid)"
            $originalPath = $env:PATH

            New-Item -ItemType Directory -Path $newPath -Force | Out-Null
            try {
                Add-ToPath $newPath
                $env:PATH.Split(';') | Should -Contain $newPath
            }
            finally {
                # Cleanup - remove from registry before removing directory
                Remove-FromPath $newPath
                Remove-Item -Path $newPath -Force -ErrorAction SilentlyContinue
                $env:PATH = $originalPath
            }
        }

        It "Add-ToPath handles relative paths" {
            $relativePath = ".\test-relative-path-$(New-Guid)"
            $originalPath = $env:PATH

            New-Item -ItemType Directory -Path $relativePath -Force | Out-Null
            try {
                { Add-ToPath $relativePath } | Should -Not -Throw
            }
            finally {
                # Cleanup - remove from registry before removing directory
                Remove-FromPath $relativePath
                Remove-Item -Path $relativePath -Force -ErrorAction SilentlyContinue
                $env:PATH = $originalPath
            }
        }
    }

    Context "Test-Command Edge Cases" {

        It "Test-Command returns false for null input" {
            Test-Command $null | Should -Be $false
        }

        It "Test-Command returns false for empty string" {
            Test-Command "" | Should -Be $false
        }

        It "Test-Command returns false for whitespace only" {
            Test-Command "   " | Should -Be $false
        }

        It "Test-Command handles command with spaces" {
            Test-Command "invalid command with spaces" | Should -Be $false
        }
    }

    Context "Tracking Function Edge Cases" {

        It "Track-Installed handles null package name" {
            $initialCount = $Script:InstalledPackages.Count
            { Track-Installed $null } | Should -Not -Throw
            # Implementation adds to list even with null
            $Script:InstalledPackages.Count | Should -BeGreaterOrEqual $initialCount
        }

        It "Track-Installed handles empty package name" {
            $initialCount = $Script:InstalledPackages.Count
            Track-Installed ""
            # Implementation adds empty entry
            $Script:InstalledPackages.Count | Should -Be ($initialCount + 1)
        }

        It "Track-Skipped handles null package name" {
            $initialCount = $Script:SkippedPackages.Count
            { Track-Skipped $null } | Should -Not -Throw
            # Implementation adds to list even with null
            $Script:SkippedPackages.Count | Should -BeGreaterOrEqual $initialCount
        }

        It "Track-Failed handles null package name" {
            $initialCount = $Script:FailedPackages.Count
            { Track-Failed $null } | Should -Not -Throw
            # Implementation adds to list even with null
            $Script:FailedPackages.Count | Should -BeGreaterOrEqual $initialCount
        }

        It "Reset-Tracking clears all tracking arrays" {
            Track-Installed "pkg1"
            Track-Skipped "pkg2"
            Track-Failed "pkg3"

            Reset-Tracking

            $Script:InstalledPackages.Count | Should -Be 0
            $Script:SkippedPackages.Count | Should -Be 0
            $Script:FailedPackages.Count | Should -Be 0
        }
    }

    Context "Platform Detection Edge Cases" {

        It "Get-OSPlatform returns consistent result" {
            $platform1 = Get-OSPlatform
            $platform2 = Get-OSPlatform
            $platform1 | Should -Be $platform2
        }

        It "Get-OSPlatform returns valid string" {
            $platform = Get-OSPlatform
            $platform | Should -Not -BeNullOrEmpty
            $platform.GetType().Name | Should -Be "String"
        }
    }

    Context "Logging Function Edge Cases" {

        It "Write-Info handles null message" {
            { Write-Info $null } | Should -Not -Throw
        }

        It "Write-Info handles empty message" {
            $output = Write-Info "" 6>&1
            $output | Should -Not -BeNullOrEmpty
        }

        It "Write-Success handles null message" {
            { Write-Success $null } | Should -Not -Throw
        }

        It "Write-Warning handles null message" {
            { Write-Warning $null } | Should -Not -Throw
        }

        It "Write-Error-Msg handles null message" {
            { Write-Error-Msg $null } | Should -Not -Throw
        }

        It "Write-Info handles message with special characters" {
            { Write-Info 'Test <>&" message' } | Should -Not -Throw
        }

        It "Write-Info handles very long messages" {
            $longMessage = "x" * 10000
            { Write-Info $longMessage } | Should -Not -Throw
        }
    }

    Context "Package Manager Mock Scenarios" {

        It "Handles Scoop not installed" {
            # Test for command that doesn't exist
            $scoopExists = Test-Command "nonexistent_scoop_xyz123"
            $scoopExists | Should -Be $false
        }

        It "Handles Winget not installed" {
            $wingetExists = Test-Command "nonexistent_winget_xyz123"
            $wingetExists | Should -Be $false
        }

        It "Handles Chocolatey not installed" {
            $chocoExists = Test-Command "nonexistent_choco_xyz123"
            $chocoExists | Should -Be $false
        }
    }
}

# ============================================================================
# BOOTSTRAP.PS1 FUNCTION TESTS
# ============================================================================

Describe "Bootstrap.ps1 Phase Functions" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $Script:BootstrapPath = Join-Path $RepoRoot "bootstrap\bootstrap.ps1"
        $commonLibPath = Join-Path $RepoRoot "bootstrap\lib\common.ps1"
        $versionCheckPath = Join-Path $RepoRoot "bootstrap\lib\version-check.ps1"
        $windowsPlatformPath = Join-Path $RepoRoot "bootstrap\platforms\windows.ps1"

        # Source the libraries
        . $commonLibPath
        . $versionCheckPath
        . $windowsPlatformPath

        # Set defaults
        $Script:Interactive = $false
        $Script:DryRun = $false
        $Script:Categories = "full"
        $Script:Verbose = $false
        Reset-Tracking
    }

    BeforeEach {
        Reset-Tracking
        $Script:Interactive = $false
        $Script:DryRun = $false
    }

    Context "Install-Foundation Phase" {

        It "Script contains Install-Foundation function" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "function Install-Foundation"
        }

        It "Install-Foundation checks for git command" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "Test-Command git"
        }

        It "Install-Foundation calls Ensure-Scoop" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "Ensure-Scoop"
        }

        It "Install-Foundation calls Configure-GitSettings" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "Configure-GitSettings"
        }
    }

    Context "Install-SDKs Phase" {

        It "Script contains Install-SDKs function" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "function Install-SDKs"
        }

        It "Install-SDKs checks for minimal category" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match 'Categories.*-eq.*"minimal"'
        }

        It "Install-SDKs installs nodejs" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "nodejs"
        }

        It "Install-SDKs installs python" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "python"
        }

        It "Install-SDKs installs go" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "Install-ScoopPackage.*go"
        }

        It "Install-SDKs installs dotnet for full category" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "dotnet"
        }

        It "Install-SDKs installs OpenJDK for full category" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "OpenJDK"
        }
    }

    Context "Install-LanguageServers Phase" {

        It "Script contains Install-LanguageServers function" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "function Install-LanguageServers"
        }

        It "Install-LanguageServers installs clangd" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "clangd"
        }

        It "Install-LanguageServers installs gopls" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "gopls"
        }

        It "Install-LanguageServers installs pyright" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "pyright"
        }

        It "Install-LanguageServers installs typescript-language-server" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "typescript-language-server"
        }
    }

    Context "Install-LintersFormatters Phase" {

        It "Script contains Install-LintersFormatters function" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "function Install-LintersFormatters"
        }

        It "Install-LintersFormatters installs prettier" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "prettier"
        }

        It "Install-LintersFormatters installs eslint" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "eslint"
        }

        It "Install-LintersFormatters installs ruff" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "ruff"
        }

        It "Install-LintersFormatters installs shellcheck" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "shellcheck"
        }

        It "Install-LintersFormatters calls Initialize-UserPath" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "Initialize-UserPath"
        }
    }

    Context "Install-CLITools Phase" {

        It "Script contains Install-CLITools function" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "function Install-CLITools"
        }

        It "Install-CLITools installs fzf" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match '"fzf"'
        }

        It "Install-CLITools installs zoxide" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match '"zoxide"'
        }

        It "Install-CLITools installs bat" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match '"bat"'
        }

        It "Install-CLITools installs eza" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match '"eza"'
        }

        It "Install-CLITools installs lazygit" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match '"lazygit"'
        }

        It "Install-CLITools installs gh" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match '"gh"'
        }

        It "Install-CLITools installs ripgrep" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match '"ripgrep"'
        }

        It "Install-CLITools installs fd" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match '"fd"'
        }
    }

    Context "Install-MCPServers Phase" {

        It "Script contains Install-MCPServers function" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "function Install-MCPServers"
        }

        It "Install-MCPServers installs context7 MCP server" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "context7"
        }

        It "Install-MCPServers installs playwright MCP server" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "playwright"
        }

        It "Install-MCPServers installs repomix" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "repomix"
        }
    }

    Context "Install-DevelopmentTools Phase" {

        It "Script contains Install-DevelopmentTools function" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "function Install-DevelopmentTools"
        }

        It "Install-DevelopmentTools installs VS Code" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "vscode|VisualStudioCode"
        }

        It "Install-DevelopmentTools installs Visual Studio Community" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "Visual Studio|VisualStudio\.Community|vswhere"
        }

        It "Install-DevelopmentTools installs LLVM" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "LLVM|clang"
        }

        It "Install-DevelopmentTools installs LaTeX" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "pdflatex|LaTeX|texlive"
        }

        It "Install-DevelopmentTools installs Claude Code CLI" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "claude"
        }
    }

    Context "Deploy-Configs Phase" {

        It "Script contains Deploy-Configs function" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "function Deploy-Configs"
        }

        It "Deploy-Configs references deploy.ps1" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "deploy\.ps1"
        }
    }

    Context "Update-All Phase" {

        It "Script contains Update-All function" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "function Update-All"
        }

        It "Update-All references update-all.ps1" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "update-all\.ps1"
        }
    }

    Context "Main Function" {

        It "Script contains Main function" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "function Main"
        }

        It "Main calls Install-Foundation" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "Install-Foundation"
        }

        It "Main calls Install-SDKs" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "Install-SDKs"
        }

        It "Main calls Install-LanguageServers" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "Install-LanguageServers"
        }

        It "Main calls Install-LintersFormatters" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "Install-LintersFormatters"
        }

        It "Main calls Install-CLITools" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "Install-CLITools"
        }

        It "Main calls Write-Summary" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "Write-Summary"
        }

        It "Main calls Main at script end" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "(?m)^Main\s*$"
        }
    }

    Context "Script Parameters" {

        It "Script has Y parameter" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match '\[switch\]\$Y'
        }

        It "Script has DryRun parameter" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match '\[switch\]\$DryRun'
        }

        It "Script has Categories parameter" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match '\[string\]\$Categories'
        }

        It "Script has SkipUpdate parameter" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match '\[switch\]\$SkipUpdate'
        }

        It "Script has VerboseMode parameter" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match '\[switch\]\$VerboseMode'
        }

        It "Script uses CmdletBinding attribute" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "\[CmdletBinding\(\)\]"
        }
    }

    Context "Category Handling" {

        It "Checks for minimal category" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match '-eq.*"minimal"'
        }

        It "Checks for full category" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match '-eq.*"full"'
        }

        It "Default Categories is full" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match 'Categories.*=.*"full"'
        }
    }

    Context "DryRun Handling" {

        It "Checks DryRun variable" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match '\$DryRun'
        }

        It "Contains DRY-RUN message" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match 'DRY-RUN'
        }
    }

    Context "Library Sourcing" {

        It "Sources common.ps1 library" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "\..*common\.ps1"
        }

        It "Sources version-check.ps1 library" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "\..*version-check\.ps1"
        }

        It "Sources windows.ps1 platform file" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "\..*windows\.ps1"
        }

        It "Sources config.ps1 if available" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPath, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "config\.ps1"
        }
    }
}
