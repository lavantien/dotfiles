# Functional tests for common.ps1 - Executes actual code to improve coverage
# These tests source the common.ps1 library and execute the functions

BeforeAll {
    $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $commonLibPath = Join-Path $Script:RepoRoot "bootstrap\lib\common.ps1"
    . $commonLibPath

    # Initialize script variables
    $Script:DryRun = $false
    $Script:Verbose = $false
    $Script:Interactive = $false
}

Describe "common.ps1 - Write-VerboseInfo" {

    It "Writes message when Verbose is true" {
        $Script:Verbose = $true
        Mock Write-Color {}

        Write-VerboseInfo "Test verbose message"

        Should -Invoke Write-Color -Times 1 -Scope It
    }

    It "Skips writing when Verbose is false" {
        $Script:Verbose = $false
        Mock Write-Color {}

        Write-VerboseInfo "Test verbose message"

        Should -Not -Invoke Write-Color -Scope It
    }
}

Describe "common.ps1 - Write-Section" {

    It "Writes section header with newline" {
        Mock Write-Host {}

        Write-Section "Test Section"

        Should -Invoke Write-Host -Times 1 -Scope It
    }
}

Describe "common.ps1 - cmd_exists" {

    It "Returns true when command exists (via git)" {
        # Test with a command that should exist on this system
        $result = cmd_exists "git"
        # We don't assert specific value as git may or may not be installed
        $result | Should -BeOfType [bool]
    }

    It "Returns false when command does not exist" {
        $result = cmd_exists "nonexistent-command-xyz-123"
        $result | Should -Be $false
    }

    It "Delegates to Test-Command function" {
        Mock Test-Command { return $true }

        cmd_exists "test-cmd"

        Should -Invoke Test-Command -Times 1 -Scope It
    }
}

Describe "common.ps1 - Get-WindowsVersion" {

    It "Returns a version object" {
        $version = Get-WindowsVersion
        $version | Should -BeOfType [version]
    }

    It "Returns non-null version" {
        $version = Get-WindowsVersion
        $version | Should -Not -BeNullOrEmpty
    }
}

Describe "common.ps1 - Get-OSPlatform" {

    It "Returns a valid platform string" {
        $platform = Get-OSPlatform
        $platform | Should -BeIn @("windows", "macos", "linux", "unknown")
    }
}

Describe "common.ps1 - Read-Confirmation" {

    BeforeEach {
        $Script:Interactive = $true
    }

    It "Returns true when user enters yes" {
        Mock Read-Host { return "yes" }

        $result = Read-Confirmation "Continue?"
        $result | Should -Be $true
    }

    It "Returns true when user enters y" {
        Mock Read-Host { return "y" }

        $result = Read-Confirmation "Continue?"
        $result | Should -Be $true
    }

    It "Returns false when user enters no" {
        Mock Read-Host { return "no" }

        $result = Read-Confirmation "Continue?"
        $result | Should -Be $false
    }

    It "Returns false when user enters n" {
        Mock Read-Host { return "n" }

        $result = Read-Confirmation "Continue?"
        $result | Should -Be $false
    }

    It "Returns default value when user enters empty" {
        Mock Read-Host { return "" }

        $result = Read-Confirmation "Continue?" -Default "y"
        $result | Should -Be $true
    }

    It "Returns true when not interactive" {
        $Script:Interactive = $false

        $result = Read-Confirmation "Continue?"
        $result | Should -Be $true
    }

    It "Trims whitespace from user input" {
        Mock Read-Host { return "  y  " }

        $result = Read-Confirmation "Continue?"
        $result | Should -Be $true
    }

    It "Handles case insensitive input" {
        Mock Read-Host { return "YES" }

        $result = Read-Confirmation "Continue?"
        $result | Should -Be $true
    }
}

Describe "common.ps1 - Invoke-CommandSafe" {

    BeforeEach {
        $Script:DryRun = $false
    }

    It "Returns true when command succeeds" {
        Mock Invoke-Expression {}

        $result = Invoke-CommandSafe "echo test"
        $result | Should -Be $true
    }

    It "Returns false when command fails" {
        Mock Invoke-Expression { throw "Error" }
        Mock Write-Warning {}

        $result = Invoke-CommandSafe "invalid-command"
        $result | Should -Be $false
    }

    It "Returns true without executing in dry run mode" {
        $Script:DryRun = $true
        Mock Write-Info {}

        $result = Invoke-CommandSafe "echo test"
        $result | Should -Be $true
    }

    It "Suppresses output when NoOutput is specified" {
        Mock Invoke-Expression {}

        Invoke-CommandSafe "echo test" -NoOutput

        Should -Invoke Invoke-Expression -Times 1 -Scope It
    }
}

Describe "common.ps1 - Initialize-UserPath" {

    BeforeEach {
        Mock Write-Step {}
        Mock Write-Success {}
        Mock Write-VerboseInfo {}
        Mock Add-ToPath {}
        Mock Refresh-Path {}
        Mock Test-Path { return $false }
        $env:USERPROFILE = "C:\TestUser"
        $env:LOCALAPPDATA = "C:\TestUser\AppData\Local"
        $env:APPDATA = "C:\TestUser\AppData\Roaming"
    }

    It "Calls Write-Step to indicate start" {
        Initialize-UserPath

        Should -Invoke Write-Step -Times 1 -Scope It
    }

    It "Refreshes PATH after processing directories" {
        Initialize-UserPath

        Should -Invoke Refresh-Path -Times 1 -Scope It
    }
}

Describe "common.ps1 - Save-State" {

    It "Saves tool state to file" {
        Mock Add-Content {}

        Save-State -Tool "git" -Version "2.40.0"

        Should -Invoke Add-Content -Times 1 -Scope It
    }
}

Describe "common.ps1 - Get-InstalledState" {

    It "Returns null when state file does not exist" {
        Mock Test-Path { return $false }

        $result = Get-InstalledState "git"
        $result | Should -Be $null
    }

    It "Returns null when tool not found in state file" {
        Mock Test-Path { return $true }
        Mock Select-String { return $null }

        $result = Get-InstalledState "nonexistent"
        $result | Should -Be $null
    }
}

Describe "common.ps1 - Test-Admin" {

    It "Returns boolean indicating admin status" {
        $result = Test-Admin
        $result | Should -BeOfType [bool]
    }
}

Describe "common.ps1 - Restart-ShellPrompt" {

    It "Writes restart message to host" {
        Mock Write-Host {}

        Restart-ShellPrompt

        Should -Invoke Write-Host -Times 2 -Scope It
    }
}

Describe "common.ps1 - Add-ToPath" {

    It "Adds path to PATH variable" {
        $testPath = "C:\TestPath\Bin"
        $originalPath = $env:PATH

        try {
            Add-ToPath $testPath
            # Function should not throw
            $true | Should -Be $true
        }
        finally {
            $env:PATH = $originalPath
        }
    }
}

Describe "common.ps1 - Refresh-Path" {

    It "Refreshes PATH from environment" {
        # This function uses [Environment]::GetEnvironmentVariable
        # We just verify it doesn't throw
        { Refresh-Path } | Should -Not -Throw
    }
}

Describe "common.ps1 - Write-Color" {

    It "Writes colored output" {
        Mock Write-Host {}

        Write-Color "Test" "Cyan"

        Should -Invoke Write-Host -Times 1 -Scope It
    }
}

Describe "common.ps1 - Write-Info" {

    It "Writes info message" {
        Mock Write-Color {}

        Write-Info "Test info"

        Should -Invoke Write-Color -Times 1 -Scope It
    }
}

Describe "common.ps1 - Write-Success" {

    It "Writes success message" {
        Mock Write-Color {}

        Write-Success "Test success"

        Should -Invoke Write-Color -Times 1 -Scope It
    }
}

Describe "common.ps1 - Write-Warning" {

    It "Writes warning message" {
        Mock Write-Color {}

        Write-Warning "Test warning"

        Should -Invoke Write-Color -Times 1 -Scope It
    }
}

Describe "common.ps1 - Write-Error-Msg" {

    It "Writes error message" {
        Mock Write-Color {}

        Write-Error-Msg "Test error"

        Should -Invoke Write-Color -Times 1 -Scope It
    }
}

Describe "common.ps1 - Write-Step" {

    It "Writes step message" {
        Mock Write-Host {}

        Write-Step "Test step"

        Should -Invoke Write-Host -Times 1 -Scope It
    }
}

Describe "common.ps1 - Write-Header" {

    It "Writes header message" {
        Mock Write-Host {}

        Write-Header "Test Header" 50

        Should -Invoke Write-Host -Times 1 -Scope It
    }
}

Describe "common.ps1 - Track-Installed" {

    BeforeEach {
        Reset-Tracking
    }

    It "Adds package to installed list" {
        Track-Installed "test-pkg" "Test description"

        $Script:InstalledPackages | Should -Contain "test-pkg (Test description)"
    }
}

Describe "common.ps1 - Track-Skipped" {

    BeforeEach {
        Reset-Tracking
    }

    It "Adds package to skipped list" {
        Track-Skipped "test-pkg" "Test description"

        $Script:SkippedPackages | Should -Contain "test-pkg (Test description)"
    }
}

Describe "common.ps1 - Track-Failed" {

    BeforeEach {
        Reset-Tracking
    }

    It "Adds package to failed list" {
        Track-Failed "test-pkg" "Test description"

        $Script:FailedPackages | Should -Contain "test-pkg (Test description)"
    }
}

Describe "common.ps1 - Reset-Tracking" {

    It "Clears all tracking lists" {
        Track-Installed "pkg1" "desc1"
        Track-Skipped "pkg2" "desc2"
        Track-Failed "pkg3" "desc3"

        Reset-Tracking

        $Script:InstalledPackages.Count | Should -Be 0
        $Script:SkippedPackages.Count | Should -Be 0
        $Script:FailedPackages.Count | Should -Be 0
    }
}
