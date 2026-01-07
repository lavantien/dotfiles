# Unit tests for new tools being added to bootstrap.ps1
# Tests that installation code exists for each new tool

BeforeAll {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $BootstrapPs1 = Join-Path $RepoRoot "bootstrap\bootstrap.ps1"
}

Describe "Bootstrap.ps1 New Tools" {

    It "bootstrap.ps1 contains scalafix installation" {
        $content = Get-Content $BootstrapPs1 -Raw
        $content | Should -Match "scalafix"
    }
}

    It "bootstrap.ps1 contains stylua installation" {
        $content = Get-Content $BootstrapPs1 -Raw
        $content | Should -Match "stylua"
    }

    It "bootstrap.ps1 contains selene installation" {
        $content = Get-Content $BootstrapPs1 -Raw
        $content | Should -Match "selene"
    }

    It "bootstrap.ps1 contains checkstyle installation" {
        $content = Get-Content $BootstrapPs1 -Raw
        $content | Should -Match "checkstyle"
    }
