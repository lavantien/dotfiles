Invoke-Expression (& { (zoxide init powershell | Out-String) })
oh-my-posh init pwsh --config 'C:\Users\savaka\scoop\apps\oh-my-posh\current\themes\robbyrussell.omp.json' | Invoke-Expression

# Basic command aliases
Set-Alias -Name f -Value "Invoke-Fzf" -Description "fzf with bat preview"
function Invoke-Fzf { fzf --preview 'bat --color=always --style=numbers --line-range=:1000 {}' }

Set-Alias -Name m -Value mpv
Set-Alias -Name rs -Value rsync
Set-Alias -Name ff -Value ffmpeg
Set-Alias -Name df -Value difft
Set-Alias -Name lg -Value lazygit
Set-Alias -Name n -Value nvim
Set-Alias -Name b -Value bat
Set-Alias -Name t -Value tokei

# Directory listing aliases
function Show-FileList { eza -a --group-directories-last }
Set-Alias -Name e -Value Show-FileList

function Show-DetailedFileList { eza -la --group-directories-last }
Set-Alias -Name ls -Value Show-DetailedFileList

# Git aliases - avoiding conflicts with built-in PowerShell aliases
Set-Alias -Name gs -Value "git status"

# For gl (conflicts with Get-Location alias)
function Git-Log { git log }
Set-Alias -Name gitl -Value Git-Log

function Get-GitLogGraph { git log --graph }
Set-Alias -Name glg -Value Get-GitLogGraph

function Get-GitLogFollow { git log --follow }
Set-Alias -Name glf -Value Get-GitLogFollow

Set-Alias -Name gb -Value "git branch"
Set-Alias -Name gbi -Value "git bisect"
Set-Alias -Name gd -Value "git diff"
Set-Alias -Name ga -Value "git add"

function Add-GitAll { git add . }
Set-Alias -Name gaa -Value Add-GitAll

# For gcm (conflicts with Get-Command alias)
function Git-CommitMessage([string]$message) { git commit -m $message }
Set-Alias -Name gitcm -Value Git-CommitMessage

# For gp (conflicts with Get-ItemProperty alias)
function Git-Push { git push }
Set-Alias -Name gitp -Value Git-Push

Set-Alias -Name gf -Value "git fetch"

# For gm (conflicts with Get-Member alias)
function Git-Merge { git merge }
Set-Alias -Name gitm -Value Git-Merge

Set-Alias -Name gmt -Value "git mergetool"
Set-Alias -Name gr -Value "git rebase"

# For gc (conflicts with Get-Content alias)
function Git-Checkout([string]$branch) { git checkout $branch }
Set-Alias -Name gitco -Value Git-Checkout

function New-GitBranch([string]$branchName) { git checkout -b $branchName }
Set-Alias -Name gcb -Value New-GitBranch

Set-Alias -Name gcp -Value "git cherry-pick"
Set-Alias -Name gt -Value "git tag"
Set-Alias -Name gw -Value "git worktree"

function Add-GitWorktree([string]$path) { git worktree add $path }
Set-Alias -Name gwa -Value Add-GitWorktree

function Remove-GitWorktree([string]$path) { git worktree delete $path }
Set-Alias -Name gwd -Value Remove-GitWorktree

Set-Alias -Name gws -Value "git worktree status"
Set-Alias -Name gwc -Value "git worktree clean"

function Update-GitSubmodules { git submodule update --init --recursive }
Set-Alias -Name gsuir -Value Update-GitSubmodules

function Reset-GitRepository { 
    git checkout -- .
    git submodule foreach --recursive git checkout -- .
}
Set-Alias -Name gnuke -Value Reset-GitRepository

# Docker aliases
Set-Alias -Name d -Value docker
Set-Alias -Name ds -Value "docker start"
Set-Alias -Name dx -Value "docker stop"
Set-Alias -Name dp -Value "docker ps"

function Get-DockerAllContainers { docker ps -a }
Set-Alias -Name dpa -Value Get-DockerAllContainers

Set-Alias -Name di -Value "docker images"
Set-Alias -Name dl -Value "docker logs"

function Watch-DockerLogs([string]$container) { docker logs -f $container }
Set-Alias -Name dlf -Value Watch-DockerLogs

Set-Alias -Name dc -Value "docker compose"
Set-Alias -Name dcp -Value "docker compose ps"

function Get-DockerComposeAllContainers { docker compose ps -a }
Set-Alias -Name dcpa -Value Get-DockerComposeAllContainers

Set-Alias -Name dcu -Value "docker compose up"

function Start-DockerComposeWithBuild { docker compose up --build }
Set-Alias -Name dcub -Value Start-DockerComposeWithBuild

Set-Alias -Name dcd -Value "docker compose down"
Set-Alias -Name dcl -Value "docker compose logs"

function Watch-DockerComposeLogs { docker compose logs -f }
Set-Alias -Name dclf -Value Watch-DockerComposeLogs

function Enter-DockerContainer([string]$container) { docker exec -it $container }
Set-Alias -Name de -Value Enter-DockerContainer

# Alternatively, you can forcibly remove the built-in aliases first, but this is less recommended
# Remove-Item alias:gl -Force
# Remove-Item alias:gcm -Force
# Remove-Item alias:gp -Force
# Remove-Item alias:gm -Force
# Remove-Item alias:gc -Force
