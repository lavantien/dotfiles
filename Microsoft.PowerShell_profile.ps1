# Universal PowerShell Profile - Windows 10/11
# Works with PowerShell 5+ and PowerShell 7+
# Auto-detects available tools and falls back gracefully

# ============================================================================
# SHELL INTEGRATION
# ============================================================================

# oh-my-posh (prompt theme) - MUST come before zoxide so zoxide can wrap the prompt
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    # Try common theme locations
    $themePaths = @(
        "$env:USERPROFILE\scoop\apps\oh-my-posh\current\themes\catppuccin_mocha.omp.json",
        "$env:LOCALAPPDATA\Programs\oh-my-posh\themes\catppuccin_mocha.omp.json",
        "catppuccin_mocha"
    )

    foreach ($path in $themePaths) {
        if (Test-Path $path) {
            oh-my-posh init pwsh --config $path | Invoke-Expression
            break
        }
    }
}

# zoxide (z - smarter cd command) - MUST come after oh-my-posh to wrap the prompt
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    # Initialize zoxide without cmd (we'll define our own)
    Invoke-Expression (& { (zoxide init powershell --cmd z | Out-String) })

    # Enhanced zi (zoxide interactive) with fzf
    if (Get-Command fzf -ErrorAction SilentlyContinue) {
        # Remove zoxide's zi alias if it exists, then define our function
        if (Test-Path Alias:zi) { Remove-Item Alias:zi -Force -ErrorAction SilentlyContinue }
        function global:zi {
            $path = zoxide query -l | fzf --height 50% --layout reverse --border --prompt="Directory> " --preview="eza -la --color=always {} 2>/dev/null 3>$null || Get-ChildItem {}"
            if (-not [string]::IsNullOrEmpty($path)) {
                Set-Location $path
            }
        }

        # zd - jump to directory with partial match
        function global:zd {
            $query = $args[0]
            if ([string]::IsNullOrEmpty($query)) {
                $path = zoxide query -l | fzf --height 50% --layout reverse --border --prompt="Directory> " --preview="eza -la --color=always {} 2>/dev/null 3>$null || Get-ChildItem {}"
            } else {
                $path = zoxide query -l | fzf --height 50% --layout reverse --border --filter="$query" --preview="eza -la --color=always {} 2>/dev/null 3>$null || Get-ChildItem {}"
            }
            if (-not [string]::IsNullOrEmpty($path)) {
                Set-Location $path
            }
        }
    }
}

# ============================================================================

# ============================================================================
# PSREADLINE CONFIGURATION
# ============================================================================
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Emacs

Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# ALIASES - FILE OPERATIONS
# ============================================================================

# fzf with bat preview
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    $null = New-Item -Path Function:\ -Name "Invoke-Fzf" -Value {
        & fzf @args
    } -Force
    Set-Alias -Name f -Value Invoke-Fzf -Description "fzf fuzzy finder"

    if (Get-Command bat -ErrorAction SilentlyContinue) {
        $null = New-Item -Path Function:\ -Name "Invoke-Fzf" -Value {
            & fzf --preview 'bat --color=always --style=numbers --line-range=:1000 {}' @args
        } -Force
    }
}

# Media and tools
if (Get-Command mpv -ErrorAction SilentlyContinue) {
    Set-Alias -Name m -Value mpv -Description "Media player"
}
if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
    Set-Alias -Name ff -Value ffmpeg -Description "FFmpeg"
}
if (Get-Command difft -ErrorAction SilentlyContinue) {
    Set-Alias -Name df -Value difft -Description "Difftastic diff tool"
}
if (Get-Command lazygit -ErrorAction SilentlyContinue) {
    Set-Alias -Name lg -Value lazygit -Description "Lazy Git UI"
}
if (Get-Command nvim -ErrorAction SilentlyContinue) {
    Set-Alias -Name n -Value nvim -Description "Neovim"
} elseif (Get-Command vim -ErrorAction SilentlyContinue) {
    Set-Alias -Name n -Value vim -Description "Vim"
}
if (Get-Command bat -ErrorAction SilentlyContinue) {
    Set-Alias -Name b -Value bat -Description "Bat cat alternative"
} elseif (Get-Command cat -ErrorAction SilentlyContinue) {
    Set-Alias -Name b -Value cat -Description "Cat"
}
if (Get-Command tokei -ErrorAction SilentlyContinue) {
    Set-Alias -Name t -Value tokei -Description "Code statistics"
}

# Directory listing - eza or fallback
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function Show-FileList { & eza -a --group-directories-last @args }
    Set-Alias -Name e -Value Show-FileList

    function Show-DetailedFileList { & eza -la --group-directories-last @args }
    Set-Alias -Name ls -Value Show-DetailedFileList
} elseif (Get-Command exa -ErrorAction SilentlyContinue) {
    function Show-FileList { & exa -a --group-directories-last @args }
    Set-Alias -Name e -Value Show-FileList

    function Show-DetailedFileList { & exa -la --group-directories-last @args }
    Set-Alias -Name ls -Value Show-DetailedFileList
}

# ============================================================================
# GIT ALIASES
# ============================================================================
function Git-Status { & git status @args }
Set-Alias -Name gs -Value Git-Status

function Git-Log { & git log @args }
Set-Alias -Name gl -Value Git-Log -Force

function Get-GitLogGraph { & git log --graph @args }
Set-Alias -Name glg -Value Get-GitLogGraph

function Get-GitLogFollow { & git log --follow @args }
Set-Alias -Name glf -Value Get-GitLogFollow

function Git-Branch { & git branch @args }
Set-Alias -Name gb -Value Git-Branch

function Git-Bisect { & git bisect @args }
Set-Alias -Name gbi -Value Git-Bisect

function Git-Diff { & git diff @args }
Set-Alias -Name gd -Value Git-Diff

function Git-Add { & git add @args }
Set-Alias -Name ga -Value Git-Add

function Add-GitAll { & git add . }
Set-Alias -Name gaa -Value Add-GitAll

function Git-CommitMessage { & git commit -m @args }
Set-Alias -Name gcm -Value Git-CommitMessage -Force

function Git-Push { & git push @args }
Set-Alias -Name gp -Value Git-Push -Force

function Git-Fetch { & git fetch @args }
Set-Alias -Name gf -Value Git-Fetch

function Git-Merge { & git merge @args }
Set-Alias -Name gitm -Value Git-Merge

function Git-MergeTool { & git mergetool @args }
Set-Alias -Name gmt -Value Git-MergeTool

function Git-Rebase { & git rebase @args }
Set-Alias -Name gr -Value Git-Rebase

function Git-Checkout { & git checkout @args }
Set-Alias -Name gitco -Value Git-Checkout

function New-GitBranch { & git checkout -b @args }
Set-Alias -Name gcb -Value New-GitBranch

function Git-CherryPick { & git cherry-pick @args }
Set-Alias -Name gcp -Value Git-CherryPick

function Git-Tag { & git tag @args }
Set-Alias -Name gt -Value Git-Tag

function Git-Worktree { & git worktree @args }
Set-Alias -Name gw -Value Git-Worktree

function Add-GitWorktree { & git worktree add @args }
Set-Alias -Name gwa -Value Add-GitWorktree

function Remove-GitWorktree { & git worktree delete @args }
Set-Alias -Name gwd -Value Remove-GitWorktree

function Git-WorktreeStatus { & git worktree status @args }
Set-Alias -Name gws -Value Git-WorktreeStatus

function Git-WorktreeClean { & git worktree clean @args }
Set-Alias -Name gwc -Value Git-WorktreeClean

function Update-GitSubmodules { & git submodule update --init --recursive @args }
Set-Alias -Name gsuir -Value Update-GitSubmodules

function Reset-GitRepository {
    & git checkout -- .
    & git submodule foreach --recursive git checkout -- .
}
Set-Alias -Name gnuke -Value Reset-GitRepository

# ============================================================================
# DOCKER ALIASES
# ============================================================================
if (Get-Command docker -ErrorAction SilentlyContinue) {
    function Docker-Command { & docker @args }
    Set-Alias -Name d -Value docker

    function Docker-Start { & docker start @args }
    Set-Alias -Name ds -Value Docker-Start

    function Docker-Stop { & docker stop @args }
    Set-Alias -Name dx -Value Docker-Stop

    function Docker-PS { & docker ps @args }
    Set-Alias -Name dp -Value Docker-PS

    function Get-DockerAllContainers { & docker ps -a @args }
    Set-Alias -Name dpa -Value Get-DockerAllContainers

    function Docker-Images { & docker images @args }
    Set-Alias -Name di -Value Docker-Images

    function Docker-Logs { & docker logs @args }
    Set-Alias -Name dl -Value Docker-Logs

    function Watch-DockerLogs { & docker logs -f @args }
    Set-Alias -Name dlf -Value Watch-DockerLogs

    function Docker-Compose { & docker compose @args }
    Set-Alias -Name dc -Value Docker-Compose

    function Docker-ComposePS { & docker compose ps @args }
    Set-Alias -Name dcp -Value Docker-ComposePS

    function Get-DockerComposeAllContainers { & docker compose ps -a @args }
    Set-Alias -Name dcpa -Value Get-DockerComposeAllContainers

    function Docker-ComposeUp { & docker compose up @args }
    Set-Alias -Name dcu -Value Docker-ComposeUp

    function Start-DockerComposeWithBuild { & docker compose up --build @args }
    Set-Alias -Name dcub -Value Start-DockerComposeWithBuild

    function Docker-ComposeDown { & docker compose down @args }
    Set-Alias -Name dcd -Value Docker-ComposeDown

    function Docker-ComposeLogs { & docker compose logs @args }
    Set-Alias -Name dcl -Value Docker-ComposeLogs

    function Watch-DockerComposeLogs { & docker compose logs -f @args }
    Set-Alias -Name dclf -Value Watch-DockerComposeLogs

    function Enter-DockerContainer { & docker exec -it @args }
    Set-Alias -Name de -Value Enter-DockerContainer
}

# ============================================================================
# ENVIRONMENT VARIABLES
# ============================================================================

# Editor
$env:EDITOR = if (Get-Command nvim -ErrorAction SilentlyContinue) { "nvim" } else { "vim" }

# Go
if (Get-Command go -ErrorAction SilentlyContinue) {
    $env:PATH += ";$(go env GOPATH)\bin"
}

# Node.js, Python (scoop manages these via shims - no manual PATH needed)

# Rust (not managed by scoop)
if (Test-Path "$env:USERPROFILE\.cargo\bin") {
    $env:PATH += ";$env:USERPROFILE\.cargo\bin"
}

# Yazi terminal file manager - needs Git's file command for preview
$gitFile = Join-Path $env:ProgramFiles "Git\usr\bin\file.exe"
if (Test-Path $gitFile) {
    $env:YAZI_FILE_ONE = $gitFile
}
# Fallback for Scoop-installed Git
$scoopGitFile = Join-Path $env:USERPROFILE "scoop\apps\git\current\usr\bin\file.exe"
if (Test-Path $scoopGitFile) {
    $env:YAZI_FILE_ONE = $scoopGitFile
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# yazi - terminal file manager with cd on exit
function y {
    $tmp = (New-TemporaryFile).FullName
    yazi.exe $args --cwd-file="$tmp"
    $cwd = Get-Content -Path $tmp -Encoding UTF8
    if ($cwd -ne $PWD.Path -and (Test-Path -LiteralPath $cwd -PathType Container)) {
        Set-Location -LiteralPath (Resolve-Path -LiteralPath $cwd).Path
    }
    Remove-Item -Path $tmp
}

# Edit profile
function Edit-Profile {
    $profilePath = $PROFILE.CurrentUserCurrentHost
    & $env:EDITOR $profilePath
}
Set-Alias -Name ep -Value Edit-Profile

# Reload profile
function Reload-Profile {
    . $PROFILE.CurrentUserCurrentHost
}
Set-Alias -Name rprof -Value Reload-Profile -Force

# Which command (like Unix)
function Get-CommandPath {
    Get-Command @args | Select-Object -ExpandProperty Source
}
Set-Alias -Name which -Value Get-CommandPath

# Update all packages alias
function Update-AllPackages { & "$env:USERPROFILE/dev/update-all.ps1" }
Set-Alias -Name up -Value Update-AllPackages
# Note: 'update' alias removed to avoid conflict with Scoop's internal update function
