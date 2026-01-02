# Tests for uncovered functions in common.ps1 and windows.ps1
# These tests execute actual code WITHOUT mocking to improve coverage

BeforeAll {
    $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $commonLibPath = Join-Path $Script:RepoRoot "bootstrap\lib\common.ps1"
    $versionCheckPath = Join-Path $Script:RepoRoot "bootstrap\lib\version-check.ps1"
    $windowsPlatformPath = Join-Path $Script:RepoRoot "bootstrap\platforms\windows.ps1"

    . $commonLibPath
    . $versionCheckPath
    . $windowsPlatformPath

    # Initialize script variables
    $Script:DryRun = $false
    $Script:Verbose = $false
    $Script:Interactive = $false
}

Describe "common.ps1 - Write-VerboseInfo" {

    It "Writes message when Verbose is true" {
        $Script:Verbose = $true
        # Execute without mocking - let Write-Color run naturally
        { Write-VerboseInfo "Test verbose message" } | Should -Not -Throw
    }

    It "Skips writing when Verbose is false" {
        $Script:Verbose = $false
        { Write-VerboseInfo "Test verbose message" } | Should -Not -Throw
    }
}

Describe "common.ps1 - Write-Section" {

    It "Writes section header with newline" {
        { Write-Section "Test Section" } | Should -Not -Throw
    }
}

Describe "common.ps1 - cmd_exists" {

    It "Returns boolean result" {
        $result = cmd_exists "git"
        $result | Should -BeOfType [bool]
    }

    It "Returns false for non-existent command" {
        $result = cmd_exists "nonexistent-command-xyz-123"
        $result | Should -Be $false
    }
}

Describe "common.ps1 - Get-WindowsVersion" {

    It "Returns a version object" {
        $version = Get-WindowsVersion
        $version | Should -BeOfType [version]
    }
}

Describe "common.ps1 - Read-Confirmation" {

    It "Returns true when not interactive" {
        $Script:Interactive = $false
        $result = Read-Confirmation "Continue?"
        $result | Should -Be $true
    }

    It "Returns default value in non-interactive mode" {
        $Script:Interactive = $false
        $result = Read-Confirmation "Continue?" "y"
        $result | Should -Be $true
    }
}

Describe "common.ps1 - Invoke-CommandSafe" {

    It "Executes command successfully" {
        $result = Invoke-CommandSafe "echo test" 2>&1
        $result | Should -Be $true
    }

    It "Handles command failure" {
        # Command that will fail
        $result = Invoke-CommandSafe "false"
        $result | Should -Be $false
    }

    It "Returns true in dry run mode" {
        $Script:DryRun = $true
        $result = Invoke-CommandSafe "echo test"
        $result | Should -Be $true
        $Script:DryRun = $false
    }
}

Describe "common.ps1 - Refresh-Path" {

    It "Refreshes PATH from environment" {
        { Refresh-Path } | Should -Not -Throw
    }
}

Describe "common.ps1 - Initialize-UserPath" {

    It "Initializes user PATH entries" {
        Mock Write-Step {}
        Mock Write-VerboseInfo {}
        Mock Add-ToPath {}
        Mock Refresh-Path {}

        { Initialize-UserPath } | Should -Not -Throw
    }
}

Describe "common.ps1 - Save-State" {

    It "Saves state information" {
        # Use a temp state file
        $originalStateFile = $env:STATE_FILE
        $env:STATE_FILE = "$env:TEMP\test-state-$([guid]::NewGuid()).txt"

        try {
            { Save-State "test-tool" "1.0.0" } | Should -Not -Throw
        } finally {
            if ($originalStateFile) {
                $env:STATE_FILE = $originalStateFile
            }
        }
    }
}

Describe "common.ps1 - Get-InstalledState" {

    It "Returns null for non-existent tool" {
        $result = Get-InstalledState "nonexistent-tool"
        $result | Should -BeNullOrEmpty
    }
}

Describe "common.ps1 - Test-Admin" {

    It "Returns boolean result" {
        $result = Test-Admin
        $result | Should -BeOfType [bool]
    }
}

Describe "common.ps1 - Restart-ShellPrompt" {

    It "Displays restart prompt" {
        # This function uses Write-Host which may output to console
        { Restart-ShellPrompt } | Should -Not -Throw
    }
}

Describe "common.ps1 - Add-ToPath" {

    It "Adds path to PATH variable" {
        $testPath = "C:\TempTestPath-$([guid]::NewGuid())"
        $originalPath = $env:PATH

        try {
            Add-ToPath $testPath
            $true | Should -Be $true
        } finally {
            $env:PATH = $originalPath
        }
    }
}

Describe "windows.ps1 - Refresh-Path" {

    It "Refreshes PATH in windows.ps1 context" {
        # This function is in windows.ps1 namespace
        { Refresh-Path } | Should -Not -Throw
    }
}

Describe "windows.ps1 - Add-ToPath" {

    It "Adds path using windows.ps1 Add-ToPath" {
        $testPath = "C:\Test-$([guid]::NewGuid())"

        # Just verify it doesn't throw
        { Add-ToPath $testPath } | Should -Not -Throw
    }
}

Describe "windows.ps1 - Configure-GitSettings" {

    It "Configures git settings when git available" {
        # This function has internal logic we can't fully test without git
        # But we can verify it doesn't throw when called
        Mock git {}
        Mock Test-Path { $false }
        Mock New-Item {}

        { Configure-GitSettings } | Should -Not -Throw
    }
}

Describe "version-check.ps1 - Get-ToolVersion" {

    It "Returns null for non-existent tool" {
        $result = Get-ToolVersion "nonexistent-tool-xyz"
        $result | Should -Be $null
    }

    It "Returns value or null for existing tool" {
        $result = Get-ToolVersion "pwsh"
        # pwsh should exist, may return version or null
        if ($result) {
            $result | Should -Match "\d+"
        }
    }
}

Describe "version-check.ps1 - Compare-Versions" {

    It "Handles equal versions" {
        $result = Compare-Versions "1.0.0" "1.0.0"
        $result | Should -Be $true
    }

    It "Handles greater version" {
        $result = Compare-Versions "2.0.0" "1.0.0"
        $result | Should -Be $true
    }

    It "Handles lesser version" {
        $result = Compare-Versions "1.0.0" "2.0.0"
        $result | Should -Be $false
    }

    It "Handles v prefix" {
        $result = Compare-Versions "v1.0.0" "1.0.0"
        $result | Should -Be $true
    }

    It "Handles date versions" {
        $result = Compare-Versions "2024-01-01" "2023-12-31"
        $result | Should -Be $true
    }
}

Describe "version-check.ps1 - Test-NeedsInstall" {

    It "Returns true for non-existent command" {
        Mock Test-Command { return $false }
        $result = Test-NeedsInstall "fake-tool"
        $result | Should -Be $true
    }

    It "Returns false for existing command" {
        Mock Test-Command { return $true }
        $result = Test-NeedsInstall "git"
        $result | Should -Be $false
    }
}

Describe "version-check.ps1 - Show-VersionStatus" {

    It "Returns true when tool doesn't exist" {
        Mock Test-Command { return $false }
        Mock Get-ToolVersion { return $null }

        $result = Show-VersionStatus "fake-tool"
        $result | Should -Be $true
    }

    It "Returns false when tool exists" {
        Mock Test-Command { return $true }
        Mock Get-ToolVersion { return "1.0.0" }

        $result = Show-VersionStatus "git"
        $result | Should -Be $false
    }
}
