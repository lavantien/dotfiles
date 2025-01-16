param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Organization
)

$ErrorActionPreference = 'Stop'

function Write-Usage
{
    Write-Host "Usage: gh-clone-org <user|org>" -ForegroundColor Red
    exit 1
}

# Validate gh CLI is available
if (-not (Get-Command gh -ErrorAction SilentlyContinue))
{
    Write-Error "GitHub CLI (gh) is not installed or not in PATH"
    exit 1
}

try
{
    # Get all repositories
    $limit = 9999
    $repos = gh repo list $Organization -L $limit | ForEach-Object {
        # Convert output to objects
        $repoInfo = $_ -split "\t"
        [PSCustomObject]@{
            FullName = $repoInfo[0]
            Name = ($repoInfo[0] -split '/')[-1]
        }
    }

    $repoTotal = $repos.Count
    $reposComplete = 0

    foreach ($repo in $repos)
    {
        Write-Progress -Activity "Cloning repositories" `
            -Status "Processing $($repo.FullName)" `
            -PercentComplete (($reposComplete / $repoTotal) * 100)

        if (Test-Path $repo.Name)
        {
            # Repository exists, update it
            Push-Location $repo.Name
            try
            {
                git pull -q
            } finally
            {
                Pop-Location
            }
        } else
        {
            # Clone new repository
            gh repo clone $repo.FullName $repo.Name -- -q
        }

        $reposComplete++
    }

    Write-Progress -Activity "Cloning repositories" -Completed
    Write-Host "Finished cloning all repos in $Organization."
} catch
{
    Write-Error "An error occurred: $_"
    exit 1
}
