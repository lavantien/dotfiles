# Unit tests for bootstrap.ps1 wrapper script
# Tests that the wrapper properly delegates to the appropriate bootstrap

BeforeAll {
    $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $Script:BootstrapPs1 = Join-Path $RepoRoot "bootstrap.ps1"
    $Script:WindowsBootstrap = Join-Path $RepoRoot "bootstrap\bootstrap.ps1"
}

Describe "bootstrap.ps1 wrapper script" {

    It "Script file exists" {
        Test-Path $Script:BootstrapPs1 | Should -Be $true
    }

    It "Contains ErrorActionPreference Stop" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "ErrorActionPreference.*Stop"
    }

    It "References Windows bootstrap path" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "bootstrap\\bootstrap\.ps1"
    }
}

Describe "Parameter mapping for Windows bootstrap" {

    It "Maps -y to Y parameter" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match '(?s)-y.*-Y.*--yes'
    }

    It "Maps -DryRun to DryRun parameter" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "(?s)-DryRun.*DryRun"
    }

    It "Maps -Categories to Categories parameter" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "(?s)-Categories.*Categories"
    }

    It "Maps -SkipUpdate to SkipUpdate parameter" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "(?s)-SkipUpdate.*SkipUpdate"
    }

    It "Handles -h/--help for showing help" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "Get-Help"
    }
}

Describe "Parameter mapping for bash bootstrap" {

    It "Maps -y to --yes for bash" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "--yes"
    }

    It "Maps -DryRun to --dry-run for bash" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "--dry-run"
    }

    It "Maps -Categories to --categories for bash" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "--categories"
    }

    It "Maps -SkipUpdate to --skip-update for bash" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "--skip-update"
    }
}

Describe "Fallback to bash script" {

    It "Checks for bash availability" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "Get-Command bash"
    }

    It "Shows error message if bash not found" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "Git Bash.*not found"
    }

    It "References bootstrap.sh" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "\./bootstrap\.sh"
    }

    It "Uses login shell (-l) for bash" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "-l.*-c"
    }
}

Describe "Location management" {

    It "Uses try/finally for location restoration" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "try"
        $ast.Extent.Text | Should -Match "finally"
    }

    It "Changes to script directory before invoking bootstrap" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "Set-Location"
    }
}

Describe "Exit code handling" {

    It "Returns LASTEXITCODE from Windows bootstrap" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "exit.*LASTEXITCODE"
    }

    It "Returns exit code from bash script" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BootstrapPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match '\$exitCode.*=.*\$LASTEXITCODE'
    }
}
