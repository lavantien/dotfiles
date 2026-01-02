# Unit tests for Microsoft.PowerShell_profile.ps1
# Tests PowerShell profile functions and aliases

BeforeAll {
    $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $Script:ProfilePs1 = Join-Path $RepoRoot "Microsoft.PowerShell_profile.ps1"

    # Source the profile to get functions (avoiding aliases that may conflict)
    $Script:ProfileContent = Get-Content $Script:ProfilePs1 -Raw
}

Describe "Microsoft.PowerShell_profile.ps1 - File Structure" {

    It "Profile file exists" {
        Test-Path $Script:ProfilePs1 | Should -Be $true
    }

    It "Contains oh-my-posh initialization" {
        $Script:ProfileContent | Should -Match "oh-my-posh"
    }

    It "Contains zoxide initialization" {
        $Script:ProfileContent | Should -Match "zoxide"
    }

    It "Contains PSReadLine configuration" {
        $Script:ProfileContent | Should -Match "Set-PSReadLineOption"
    }

    It "Contains git aliases" {
        $Script:ProfileContent | Should -Match "Git-Status"
        $Script:ProfileContent | Should -Match "Set-Alias.*gs"
    }
}

Describe "Microsoft.PowerShell_profile.ps1 - Git Aliases" {

    It "Defines gs alias for Git-Status" {
        $Script:ProfileContent | Should -Match "function Git-Status"
        $Script:ProfileContent | Should -Match "Set-Alias.*-Name.*gs.*Git-Status"
    }

    It "Defines gl alias for Git-Log" {
        $Script:ProfileContent | Should -Match "function Git-Log"
        $Script:ProfileContent | Should -Match "Set-Alias.*-Name.*gl.*Git-Log"
    }

    It "Defines glg alias for Get-GitLogGraph" {
        $Script:ProfileContent | Should -Match "function Get-GitLogGraph"
        $Script:ProfileContent | Should -Match "Set-Alias.*-Name.*glg.*Get-GitLogGraph"
    }

    It "Defines gb alias for Git-Branch" {
        $Script:ProfileContent | Should -Match "function Git-Branch"
        $Script:ProfileContent | Should -Match "Set-Alias.*-Name.*gb.*Git-Branch"
    }

    It "Defines gd alias for Git-Diff" {
        $Script:ProfileContent | Should -Match "function Git-Diff"
        $Script:ProfileContent | Should -Match "Set-Alias.*-Name.*gd.*Git-Diff"
    }

    It "Defines ga alias for Git-Add" {
        $Script:ProfileContent | Should -Match "function Git-Add"
        $Script:ProfileContent | Should -Match "Set-Alias.*-Name.*ga.*Git-Add"
    }

    It "Defines gaa alias for Add-GitAll" {
        $Script:ProfileContent | Should -Match "function Add-GitAll"
        $Script:ProfileContent | Should -Match "Set-Alias.*-Name.*gaa.*Add-GitAll"
    }

    It "Defines gcm alias for Git-CommitMessage" {
        $Script:ProfileContent | Should -Match "function Git-CommitMessage"
        $Script:ProfileContent | Should -Match "Set-Alias.*-Name.*gcm.*Git-CommitMessage"
    }

    It "Defines gp alias for Git-Push" {
        $Script:ProfileContent | Should -Match "function Git-Push"
        $Script:ProfileContent | Should -Match "Set-Alias.*-Name.*gp.*Git-Push"
    }

    It "Defines gcb alias for New-GitBranch" {
        $Script:ProfileContent | Should -Match "function New-GitBranch"
        $Script:ProfileContent | Should -Match "Set-Alias.*-Name.*gcb.*New-GitBranch"
    }
}

Describe "Microsoft.PowerShell_profile.ps1 - Docker Aliases" {

    It "Contains Docker section check" {
        $Script:ProfileContent | Should -Match "if.*Get-Command docker"
    }

    It "Defines d alias for docker" {
        $Script:ProfileContent | Should -Match "Set-Alias.*-Name.*d.*docker"
    }

    It "Defines ds alias for Docker-Start" {
        $Script:ProfileContent | Should -Match "function Docker-Start"
        $Script:ProfileContent | Should -Match "Set-Alias.*-Name.*ds.*Docker-Start"
    }

    It "Defines dx alias for Docker-Stop" {
        $Script:ProfileContent | Should -Match "function Docker-Stop"
        $Script:ProfileContent | Should -Match "Set-Alias.*-Name.*dx.*Docker-Stop"
    }

    It "Defines dc alias for Docker-Compose" {
        $Script:ProfileContent | Should -Match "function Docker-Compose"
        $Script:ProfileContent | Should -Match "Set-Alias.*-Name.*dc.*Docker-Compose"
    }
}

Describe "Microsoft.PowerShell_profile.ps1 - Tool Aliases" {

    It "Checks for nvim before setting n alias" {
        $Script:ProfileContent | Should -Match "if.*Get-Command nvim"
    }

    It "Defines n alias for nvim or vim" {
        $Script:ProfileContent | Should -Match "Set-Alias.*-Name.*n.*(nvim|vim)"
    }

    It "Checks for bat before setting b alias" {
        $Script:ProfileContent | Should -Match "if.*Get-Command bat"
    }

    It "Defines b alias for bat or cat" {
        $Script:ProfileContent | Should -Match "Set-Alias.*-Name.*b.*(bat|cat)"
    }

    It "Checks for eza before setting e alias" {
        $Script:ProfileContent | Should -Match "if.*Get-Command eza"
    }

    It "Defines e alias for Show-FileList" {
        $Script:ProfileContent | Should -Match "function Show-FileList"
    }
}

Describe "Microsoft.PowerShell_profile.ps1 - Helper Functions" {

    It "Defines Edit-Profile function" {
        $Script:ProfileContent | Should -Match "function Edit-Profile"
    }

    It "Defines ep alias for Edit-Profile" {
        $Script:ProfileContent | Should -Match "Set-Alias.*ep.*Edit-Profile"
    }

    It "Defines Reload-Profile function" {
        $Script:ProfileContent | Should -Match "function Reload-Profile"
    }

    It "Defines rprof alias for Reload-Profile" {
        $Script:ProfileContent | Should -Match "Set-Alias.*rprof.*Reload-Profile"
    }

    It "Defines Get-CommandPath function" {
        $Script:ProfileContent | Should -Match "function Get-CommandPath"
    }

    It "Defines which alias for Get-CommandPath" {
        $Script:ProfileContent | Should -Match "Set-Alias.*which.*Get-CommandPath"
    }
}

Describe "Microsoft.PowerShell_profile.ps1 - Environment Variables" {

    It "Sets EDITOR environment variable" {
        $Script:ProfileContent | Should -Match '\$env:EDITOR'
    }

    It "Checks for go command before modifying PATH" {
        $Script:ProfileContent | Should -Match "if.*Get-Command go"
    }

    It "Checks for nodejs-lts scoop path" {
        $Script:ProfileContent | Should -Match "scoop.*nodejs-lts"
    }

    It "Checks for cargo bin directory" {
        $Script:ProfileContent | Should -Match "\.cargo.*bin"
    }

    It "Checks for Python scoop path" {
        $Script:ProfileContent | Should -Match "scoop.*python"
    }
}

Describe "Microsoft.PowerShell_profile.ps1 - Update Aliases" {

    It "Defines up alias for Update-AllPackages" {
        $Script:ProfileContent | Should -Match "function Update-AllPackages"
        $Script:ProfileContent | Should -Match "Set-Alias.*up.*Update-AllPackages"
    }

    It "Defines update alias for Update-AllPackages" {
        $Script:ProfileContent | Should -Match "Set-Alias.*update.*Update-AllPackages"
    }
}

Describe "Microsoft.PowerShell_profile.ps1 - Fzf Integration" {

    It "Checks for fzf command" {
        $Script:ProfileContent | Should -Match "if.*Get-Command fzf"
    }

    It "Creates f alias for fzf" {
        $Script:ProfileContent | Should -Match "Set-Alias.*f.*Invoke-Fzf"
    }
}

Describe "Microsoft.PowerShell_profile.ps1 - PSReadLine Configuration" {

    It "Sets PredictionSource to History" {
        $Script:ProfileContent | Should -Match "Set-PSReadLineOption.*PredictionSource.*History"
    }

    It "Sets EditMode to Emacs" {
        $Script:ProfileContent | Should -Match "Set-PSReadLineOption.*EditMode.*Emacs"
    }

    It "Sets UpArrow key handler" {
        $Script:ProfileContent | Should -Match "Set-PSReadLineKeyHandler.*UpArrow.*HistorySearchBackward"
    }

    It "Sets DownArrow key handler" {
        $Script:ProfileContent | Should -Match "Set-PSReadLineKeyHandler.*DownArrow.*HistorySearchForward"
    }

    It "Sets Tab key handler" {
        $Script:ProfileContent | Should -Match "Set-PSReadLineKeyHandler.*Tab.*MenuComplete"
    }
}

Describe "Microsoft.PowerShell_profile.ps1 - Git Worktree Aliases" {

    It "Defines gw alias for Git-Worktree" {
        $Script:ProfileContent | Should -Match "function Git-Worktree"
        $Script:ProfileContent | Should -Match "Set-Alias.*gw.*Git-Worktree"
    }

    It "Defines gwa alias for Add-GitWorktree" {
        $Script:ProfileContent | Should -Match "function Add-GitWorktree"
        $Script:ProfileContent | Should -Match "Set-Alias.*gwa.*Add-GitWorktree"
    }

    It "Defines gwd alias for Remove-GitWorktree" {
        $Script:ProfileContent | Should -Match "function Remove-GitWorktree"
        $Script:ProfileContent | Should -Match "Set-Alias.*gwd.*Remove-GitWorktree"
    }
}

Describe "Microsoft.PowerShell_profile.ps1 - Complex Git Aliases" {

    It "Defines glf for Get-GitLogFollow" {
        $Script:ProfileContent | Should -Match "function Get-GitLogFollow"
        $Script:ProfileContent | Should -Match "Set-Alias.*glf.*Get-GitLogFollow"
    }

    It "Defines gbi for Git-Bisect" {
        $Script:ProfileContent | Should -Match "function Git-Bisect"
        $Script:ProfileContent | Should -Match "Set-Alias.*gbi.*Git-Bisect"
    }

    It "Defines gitm for Git-Merge" {
        $Script:ProfileContent | Should -Match "function Git-Merge"
        $Script:ProfileContent | Should -Match "Set-Alias.*gitm.*Git-Merge"
    }

    It "Defines gmt for Git-MergeTool" {
        $Script:ProfileContent | Should -Match "function Git-MergeTool"
        $Script:ProfileContent | Should -Match "Set-Alias.*gmt.*Git-MergeTool"
    }

    It "Defines gr for Git-Rebase" {
        $Script:ProfileContent | Should -Match "function Git-Rebase"
        $Script:ProfileContent | Should -Match "Set-Alias.*gr.*Git-Rebase"
    }
}

Describe "Microsoft.PowerShell_profile.ps1 - Directory Listing Functions" {

    It "Creates Show-FileList function for eza/exa" {
        $Script:ProfileContent | Should -Match "function Show-FileList.*\&.*eza"
    }

    It "Creates Show-DetailedFileList function" {
        $Script:ProfileContent | Should -Match "function Show-DetailedFileList.*\&.*eza.*-la"
    }

    It "Overrides ls alias when eza is available" {
        $Script:ProfileContent | Should -Match "Set-Alias.*-Name.*ls.*Show-DetailedFileList"
    }
}

Describe "Microsoft.PowerShell_profile.ps1 - Media Aliases" {

    It "Checks for mpv before setting m alias" {
        $Script:ProfileContent | Should -Match "if.*Get-Command mpv"
    }

    It "Checks for ffmpeg before setting ff alias" {
        $Script:ProfileContent | Should -Match "if.*Get-Command ffmpeg"
    }

    It "Checks for difft before setting df alias" {
        $Script:ProfileContent | Should -Match "if.*Get-Command difft"
    }
}

Describe "Microsoft.PowerShell_profile.ps1 - Zoxide Functions" {

    It "Defines zi function for interactive zoxide" {
        $Script:ProfileContent | Should -Match "function global:zi"
    }

    It "Checks for fzf before defining zi" {
        $Script:ProfileContent | Should -Match "if.*Get-Command fzf"
    }

    It "Defines zd function for directory search" {
        $Script:ProfileContent | Should -Match "function global:zd"
    }
}
