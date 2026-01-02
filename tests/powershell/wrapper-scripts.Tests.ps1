# Unit tests for PowerShell wrapper scripts
# Tests that wrapper scripts properly invoke bash scripts

BeforeAll {
    $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $Script:BackupPs1 = Join-Path $RepoRoot "backup.ps1"
    $Script:DeployPs1 = Join-Path $RepoRoot "deploy.ps1"
    $Script:RestorePs1 = Join-Path $RepoRoot "restore.ps1"
    $Script:UninstallPs1 = Join-Path $RepoRoot "uninstall.ps1"
    $Script:HealthcheckPs1 = Join-Path $RepoRoot "healthcheck.ps1"
}

Describe "backup.ps1 wrapper script" {

    It "Script file exists" {
        Test-Path $Script:BackupPs1 | Should -Be $true
    }

    It "Maps -DryRun to --dry-run" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BackupPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "-DryRun"
        $ast.Extent.Text | Should -Match "--dry-run"
    }

    It "Maps -Keep to --keep" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BackupPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "-Keep"
        $ast.Extent.Text | Should -Match "--keep"
    }

    It "Maps -BackupDir to --backup-dir" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BackupPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "-BackupDir"
        $ast.Extent.Text | Should -Match "--backup-dir"
    }

    It "Checks for bash availability" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BackupPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "Get-Command bash"
    }

    It "Changes to script directory before invoking bash" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BackupPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "Set-Location"
    }

    It "Invokes backup.sh script" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BackupPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "\./backup\.sh"
    }

    It "Returns bash exit code" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:BackupPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "exit.*LASTEXITCODE"
    }
}

Describe "deploy.ps1 wrapper script" {

    It "Script file exists" {
        Test-Path $Script:DeployPs1 | Should -Be $true
    }

    It "Checks for bash availability" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:DeployPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "Get-Command bash"
    }

    It "Invokes deploy.sh script" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:DeployPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "\./deploy\.sh"
    }

    It "Returns bash exit code" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:DeployPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "exit.*LASTEXITCODE"
    }
}

Describe "restore.ps1 wrapper script" {

    It "Script file exists" {
        Test-Path $Script:RestorePs1 | Should -Be $true
    }

    It "Maps -BackupDir to --backup-dir" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:RestorePs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "-BackupDir"
        $ast.Extent.Text | Should -Match "--backup-dir"
    }

    It "Maps -List to --list" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:RestorePs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "-List"
        $ast.Extent.Text | Should -Match "--list"
    }

    It "Maps -DryRun to --dry-run" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:RestorePs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "-DryRun"
        $ast.Extent.Text | Should -Match "--dry-run"
    }

    It "Maps -Force to --force" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:RestorePs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "-Force"
        $ast.Extent.Text | Should -Match "--force"
    }

    It "Checks for bash availability" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:RestorePs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "Get-Command bash"
    }

    It "Invokes restore.sh script" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:RestorePs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "\./restore\.sh"
    }

    It "Returns bash exit code" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:RestorePs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "exit.*LASTEXITCODE"
    }
}

Describe "uninstall.ps1 wrapper script" {

    It "Script file exists" {
        Test-Path $Script:UninstallPs1 | Should -Be $true
    }

    It "Maps -DryRun to --dry-run" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:UninstallPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "-DryRun"
        $ast.Extent.Text | Should -Match "--dry-run"
    }

    It "Maps -KeepBackups to --keep-backups" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:UninstallPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "-KeepBackups"
        $ast.Extent.Text | Should -Match "--keep-backups"
    }

    It "Maps -VerifyOnly to --verify-only" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:UninstallPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "-VerifyOnly"
        $ast.Extent.Text | Should -Match "--verify-only"
    }

    It "Checks for bash availability" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:UninstallPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "Get-Command bash"
    }

    It "Invokes uninstall.sh script" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:UninstallPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "\./uninstall\.sh"
    }

    It "Returns bash exit code" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:UninstallPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "exit.*LASTEXITCODE"
    }
}

Describe "healthcheck.ps1 wrapper script" {

    It "Script file exists" {
        Test-Path $Script:HealthcheckPs1 | Should -Be $true
    }

    It "Maps -Verbose to --verbose" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:HealthcheckPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "-Verbose"
        $ast.Extent.Text | Should -Match "--verbose"
    }

    It "Maps -Format to --format" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:HealthcheckPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "-Format"
        $ast.Extent.Text | Should -Match "--format"
    }

    It "Checks for bash availability" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:HealthcheckPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "Get-Command bash"
    }

    It "Invokes healthcheck.sh script" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:HealthcheckPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "\./healthcheck\.sh"
    }

    It "Returns bash exit code" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:HealthcheckPs1, [ref]$null, [ref]$null)
        $ast.Extent.Text | Should -Match "exit.*LASTEXITCODE"
    }
}

Describe "Common wrapper script patterns" {

    It "All wrappers use ErrorActionPreference Stop" {
        $scripts = @($Script:BackupPs1, $Script:DeployPs1, $Script:RestorePs1, $Script:UninstallPs1, $Script:HealthcheckPs1)
        foreach ($script in $scripts) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "ErrorActionPreference.*Stop"
        }
    }

    It "All wrappers use try/finally for location restoration" {
        $scripts = @($Script:BackupPs1, $Script:DeployPs1, $Script:RestorePs1, $Script:UninstallPs1, $Script:HealthcheckPs1)
        foreach ($script in $scripts) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "try"
            $ast.Extent.Text | Should -Match "finally"
        }
    }

    It "All wrappers invoke bash with login shell (-l)" {
        $scripts = @($Script:BackupPs1, $Script:DeployPs1, $Script:RestorePs1, $Script:UninstallPs1, $Script:HealthcheckPs1)
        foreach ($script in $scripts) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$null, [ref]$null)
            $ast.Extent.Text | Should -Match "-l.*-c"
        }
    }
}
