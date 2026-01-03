# Git Bash Finder Module
# Finds Git Bash executable explicitly, avoiding WSL bash from C:\Windows\System32

function Find-GitBash {
    <#
    .SYNOPSIS
        Finds Git Bash executable on Windows.

    .DESCRIPTION
        Searches for Git Bash in common installation locations, explicitly
        avoiding WSL bash from C:\Windows\System32\bash.exe.

    .OUTPUTS
        String path to bash.exe, or throws an error if not found.
    #>
    $gitBashPaths = @(
        "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe",
        "${env:ProgramFiles}\Git\bin\bash.exe",
        "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
        "$env:USERPROFILE\scoop\apps\git\current\usr\bin\bash.exe"
    )

    foreach ($path in $gitBashPaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    throw "Git Bash (bash.exe) not found. Please install Git for Windows from https://git-scm.com/download/win"
}

Export-ModuleMember -Function Find-GitBash
