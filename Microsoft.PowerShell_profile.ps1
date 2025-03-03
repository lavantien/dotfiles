Invoke-Expression (& { (zoxide init powershell | Out-String) })
oh-my-posh init pwsh --config 'C:\Users\savaka\scoop\apps\oh-my-posh\current\themes\robbyrussell.omp.json' | Invoke-Expression

# Basic command aliases
Set-Alias -Name f -Value "Invoke-Fzf" -Description "fzf with bat preview"
function Invoke-Fzf { & fzf --preview 'bat --color=always --style=numbers --line-range=:1000 {}' }

Set-Alias -Name m -Value mpv
Set-Alias -Name ff -Value ffmpeg
Set-Alias -Name df -Value difft
Set-Alias -Name lg -Value lazygit
Set-Alias -Name n -Value nvim
Set-Alias -Name b -Value bat
Set-Alias -Name t -Value tokei

# Directory listing aliases
function Show-FileList { & eza -a --group-directories-last }
Set-Alias -Name e -Value Show-FileList

function Show-DetailedFileList { & eza -la --group-directories-last }
Set-Alias -Name ls -Value Show-DetailedFileList

# Git aliases - with proper command execution
function Git-Status { & git status }
Set-Alias -Name gs -Value Git-Status

function Git-Log { & git log }
Set-Alias -Name gitl -Value Git-Log

function Get-GitLogGraph { & git log --graph }
Set-Alias -Name glg -Value Get-GitLogGraph

function Get-GitLogFollow { & git log --follow }
Set-Alias -Name glf -Value Get-GitLogFollow

function Git-Branch { & git branch }
Set-Alias -Name gb -Value Git-Branch

function Git-Bisect { & git bisect }
Set-Alias -Name gbi -Value Git-Bisect

function Git-Diff { & git diff }
Set-Alias -Name gd -Value Git-Diff

function Git-Add { param([string]$path = "") & git add $path }
Set-Alias -Name ga -Value Git-Add

function Add-GitAll { & git add . }
Set-Alias -Name gaa -Value Add-GitAll

function Git-CommitMessage([string]$message) { & git commit -m $message }
Set-Alias -Name gitcm -Value Git-CommitMessage

function Git-Push { & git push }
Set-Alias -Name gitp -Value Git-Push

function Git-Fetch { & git fetch }
Set-Alias -Name gf -Value Git-Fetch

function Git-Merge { & git merge }
Set-Alias -Name gitm -Value Git-Merge

function Git-MergeTool { & git mergetool }
Set-Alias -Name gmt -Value Git-MergeTool

function Git-Rebase { & git rebase }
Set-Alias -Name gr -Value Git-Rebase

function Git-Checkout([string]$branch) { & git checkout $branch }
Set-Alias -Name gitco -Value Git-Checkout

function New-GitBranch([string]$branchName) { & git checkout -b $branchName }
Set-Alias -Name gcb -Value New-GitBranch

function Git-CherryPick { & git cherry-pick }
Set-Alias -Name gcp -Value Git-CherryPick

function Git-Tag { & git tag }
Set-Alias -Name gt -Value Git-Tag

function Git-Worktree { & git worktree }
Set-Alias -Name gw -Value Git-Worktree

function Add-GitWorktree([string]$path) { & git worktree add $path }
Set-Alias -Name gwa -Value Add-GitWorktree

function Remove-GitWorktree([string]$path) { & git worktree delete $path }
Set-Alias -Name gwd -Value Remove-GitWorktree

function Git-WorktreeStatus { & git worktree status }
Set-Alias -Name gws -Value Git-WorktreeStatus

function Git-WorktreeClean { & git worktree clean }
Set-Alias -Name gwc -Value Git-WorktreeClean

function Update-GitSubmodules { & git submodule update --init --recursive }
Set-Alias -Name gsuir -Value Update-GitSubmodules

function Reset-GitRepository { 
    & git checkout -- .
    & git submodule foreach --recursive git checkout -- .
}
Set-Alias -Name gnuke -Value Reset-GitRepository

# Docker aliases
function Docker-Command { param([string]$cmd) & docker $cmd }
Set-Alias -Name d -Value docker

function Docker-Start([string]$container) { & docker start $container }
Set-Alias -Name ds -Value Docker-Start

function Docker-Stop([string]$container) { & docker stop $container }
Set-Alias -Name dx -Value Docker-Stop

function Docker-PS { & docker ps }
Set-Alias -Name dp -Value Docker-PS

function Get-DockerAllContainers { & docker ps -a }
Set-Alias -Name dpa -Value Get-DockerAllContainers

function Docker-Images { & docker images }
Set-Alias -Name di -Value Docker-Images

function Docker-Logs([string]$container) { & docker logs $container }
Set-Alias -Name dl -Value Docker-Logs

function Watch-DockerLogs([string]$container) { & docker logs -f $container }
Set-Alias -Name dlf -Value Watch-DockerLogs

function Docker-Compose([string]$command) { & docker compose $command }
Set-Alias -Name dc -Value Docker-Compose

function Docker-ComposePS { & docker compose ps }
Set-Alias -Name dcp -Value Docker-ComposePS

function Get-DockerComposeAllContainers { & docker compose ps -a }
Set-Alias -Name dcpa -Value Get-DockerComposeAllContainers

function Docker-ComposeUp { & docker compose up }
Set-Alias -Name dcu -Value Docker-ComposeUp

function Start-DockerComposeWithBuild { & docker compose up --build }
Set-Alias -Name dcub -Value Start-DockerComposeWithBuild

function Docker-ComposeDown { & docker compose down }
Set-Alias -Name dcd -Value Docker-ComposeDown

function Docker-ComposeLogs { & docker compose logs }
Set-Alias -Name dcl -Value Docker-ComposeLogs

function Watch-DockerComposeLogs { & docker compose logs -f }
Set-Alias -Name dclf -Value Watch-DockerComposeLogs

function Enter-DockerContainer([string]$container) { & docker exec -it $container $args }
Set-Alias -Name de -Value Enter-DockerContainer
