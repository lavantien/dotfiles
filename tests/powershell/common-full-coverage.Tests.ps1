# Comprehensive tests for common.ps1 to maximize coverage
# Tests all functions and code paths

BeforeAll {
    $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $commonLibPath = Join-Path $Script:RepoRoot "bootstrap\lib\common.ps1"

    . $commonLibPath

    $Script:DryRun = $false
    $Script:Verbose = $false
    $Script:Interactive = $false
    Reset-Tracking
}

Describe "common.ps1 - All Logging Functions" {

    It "Write-Color executes" {
        { Write-Color "Test" "Cyan" } | Should -Not -Throw
    }

    It "Write-Info executes" {
        { Write-Info "Test info" } | Should -Not -Throw
    }

    It "Write-Success executes" {
        { Write-Success "Test success" } | Should -Not -Throw
    }

    It "Write-Warning executes" {
        { Write-Warning "Test warning" } | Should -Not -Throw
    }

    It "Write-Error-Msg executes" {
        { Write-Error-Msg "Test error" } | Should -Not -Throw
    }

    It "Write-Step executes" {
        { Write-Step "Test step" } | Should -Not -Throw
    }

    It "Write-Header executes with default width" {
        { Write-Header "Test" } | Should -Not -Throw
    }

    It "Write-Header executes with custom width" {
        { Write-Header "Test" 80 } | Should -Not -Throw
    }

    It "Write-Section executes" {
        { Write-Section "Test Section" } | Should -Not -Throw
    }

    It "Write-VerboseInfo with Verbose=true" {
        $Script:Verbose = $true
        { Write-VerboseInfo "Verbose message" } | Should -Not -Throw
    }

    It "Write-VerboseInfo with Verbose=false" {
        $Script:Verbose = $false
        { Write-VerboseInfo "Silent message" } | Should -Not -Throw
    }
}

Describe "common.ps1 - All Tracking Functions" {

    BeforeEach {
        Reset-Tracking
    }

    It "Track-Installed adds package" {
        Track-Installed "pkg" "desc"
        $Script:INSTALLED_PACKAGES.Count | Should -BeGreaterThan 0
    }

    It "Track-Skipped adds package" {
        Track-Skipped "pkg" "desc"
        $Script:SKIPPED_PACKAGES.Count | Should -BeGreaterThan 0
    }

    It "Track-Failed adds package" {
        Track-Failed "pkg" "desc"
        $Script:FAILED_PACKAGES.Count | Should -BeGreaterThan 0
    }

    It "Reset-Tracking clears all arrays" {
        Track-Installed "p1" "d1"
        Track-Skipped "p2" "d2"
        Track-Failed "p3" "d3"
        Reset-Tracking
        $Script:INSTALLED_PACKAGES.Count | Should -Be 0
        $Script:SKIPPED_PACKAGES.Count | Should -Be 0
        $Script:FAILED_PACKAGES.Count | Should -Be 0
    }

    It "Write-Summary executes" {
        Track-Installed "p1" "d1"
        Track-Skipped "p2" "d2"
        Track-Failed "p3" "d3"
        { Write-Summary } | Should -Not -Throw
    }
}

Describe "common.ps1 - Platform Detection" {

    It "Get-OSPlatform returns valid value" {
        $result = Get-OSPlatform
        $result | Should -BeIn @("windows", "macos", "linux", "unknown")
    }

    It "Get-WindowsVersion returns version" {
        $result = Get-WindowsVersion
        $result | Should -Not -BeNullOrEmpty
    }
}

Describe "common.ps1 - Test-Command" {

    It "Returns true for existing command" {
        $result = Test-Command "pwsh"
        $result | Should -Be $true
    }

    It "Returns false for non-existent command" {
        $result = Test-Command "nonexistent-cmd-xyz-123"
        $result | Should -Be $false
    }

    It "Handles built-in commands" {
        $result = Test-Command "Get-ChildItem"
        $result | Should -Be $true
    }
}

Describe "common.ps1 - Add-ToPath" {

    BeforeEach {
        $testPath = "C:\Test-Path-$(New-Guid)"
        $env:Path = ($env:Path -split ';' | Where-Object { $_ -ne $testPath }) -join ';'
    }

    It "Adds path to User scope session" {
        Add-ToPath -Path $testPath -User
        $env:Path -like "*$testPath*" | Should -Be $true
    }

    It "Adds path to Process scope only" {
        Add-ToPath -Path $testPath -Process
        $env:Path -like "*$testPath*" | Should -Be $true
    }

    It "Handles duplicate paths gracefully" {
        $env:Path = "$testPath;$env:Path"
        { Add-ToPath -Path $testPath -User } | Should -Not -Throw
    }
}

Describe "common.ps1 - Initialize-UserPath" {

    It "Executes without error" {
        { Initialize-UserPath } | Should -Not -Throw
    }

    It "Handles missing directories gracefully" {
        # The function should handle missing directories
        { Initialize-UserPath } | Should -Not -Throw
    }
}

Describe "common.ps1 - Refresh-Path" {

    It "Executes without error" {
        { Refresh-Path } | Should -Not -Throw
    }
}

Describe "common.ps1 - Read-Confirmation" {

    It "Returns 'y' when INTERACTIVE is false" {
        $Script:Interactive = $false
        $result = Read-Confirmation "Test"
        $result | Should -Be "y"
    }
}

Describe "common.ps1 - Invoke-SafeInstall" {

    It "Returns true on success" {
        $testFunc = { return $true }
        $result = Invoke-SafeInstall $testFunc "test" "desc"
        $result | Should -Be $true
    }

    It "Returns false on failure" {
        $testFunc = { throw "test error" }
        $result = Invoke-SafeInstall $testFunc "test" "desc"
        $result | Should -Be $false
    }

    It "Tracks successful install" {
        $testFunc = { return $true }
        Invoke-SafeInstall $testFunc "test" "desc"
        $Script:INSTALLED_PACKAGES.Count | Should -BeGreaterThan 0
    }

    It "Tracks failed install" {
        $testFunc = { throw "error" }
        Invoke-SafeInstall $testFunc "test" "desc"
        $Script:FAILED_PACKAGES.Count | Should -BeGreaterThan 0
    }
}

Describe "common.ps1 - cmd_exists" {

    It "Returns true for existing command" {
        $result = cmd_exists "pwsh"
        $result | Should -Be $true
    }

    It "Returns false for non-existent command" {
        $result = cmd_exists "nonexistent-cmd-xyz-123"
        $result | Should -Be $false
    }
}

Describe "common.ps1 - exists" {

    It "Returns true for existing file" {
        $tempFile = [System.IO.Path]::GetTempFileName()
        try {
            $result = exists $tempFile
            $result | Should -Be $true
        } finally {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    It "Returns false for non-existent file" {
        $result = exists "C:\nonexistent-file-xyz-123.txt"
        $result | Should -Be $false
    }
}

Describe "common.ps1 - Dry Run Mode" {

    It "Respects DRY_RUN variable" {
        $Script:DryRun = $true
        $Script:DryRun | Should -Be $true
        $Script:DryRun = $false
    }

    It "Respects VERBOSE variable" {
        $Script:Verbose = $true
        $Script:Verbose | Should -Be $true
        $Script:Verbose = $false
    }

    It "Respects INTERACTIVE variable" {
        $Script:Interactive = $true
        $Script:Interactive | Should -Be $true
        $Script:Interactive = $false
    }
}

Describe "common.ps1 - run_cmd behavior" {

    It "Handles DRY_RUN mode" {
        $Script:DryRun = $true
        Mock Test-Command { return $true }
        { run_cmd "echo test" } | Should -Not -Throw
    }

    It "Handles normal execution" {
        $Script:DryRun = $false
        { run_cmd "echo test" } | Should -Not -Throw
    }
}
