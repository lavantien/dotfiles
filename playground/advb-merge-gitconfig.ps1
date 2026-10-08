$ErrorActionPreference = 'Stop'

$Repo = Split-Path -Parent $PSScriptRoot
$Src = Join-Path $Repo 'home\.gitconfig'

$Ast = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $Repo 'scripts\deploy.ps1'), [ref]$null, [ref]$null)
$Func = $Ast.FindAll({
    param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $n.Name -eq 'Merge-Gitconfig'
}, $true)[0]
. ([scriptblock]::Create($Func.Extent.Text))

$Work = Join-Path $Env:TEMP ("advb-" + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $Work | Out-Null

$ScoopGh = '!' + (($Env:USERPROFILE -replace '\\', '/')) + '/scoop/shims/gh.exe auth git-credential'

function Run-Case {
    param([string]$Name, [scriptblock]$Setup, [string[]]$ProbeKeys = @('user.name','user.email'))
    $Dst = Join-Path $Work ($Name -replace '[^a-z0-9]', '-')
    & $Setup $Dst
    $Snap = @{ existed = (Test-Path $Dst) }
    $Err = $null
    try {
        Merge-Gitconfig -Src $Src -Dst $Dst
        $Code = 0
    }
    catch {
        $Code = 1
        $Err = $_.Exception.Message
    }
    $Leftover = Test-Path "$Dst.dotfiles-new"
    $Identity = @()
    foreach ($k in $ProbeKeys) {
        $v = git config --file $Dst $k 2>$null
        if ($LASTEXITCODE -eq 0) { $Identity += "$k=[$v]" } else { $Identity += "$k=<absent>" }
    }
    $Helpers = (git config --file $Dst --get-all 'credential.https://github.com.helper' 2>$null) -join ' | '
    $Bytes = [System.IO.File]::ReadAllBytes($Dst)
    $Tail = if ($Bytes.Length -gt 0) { ($Bytes[-1]) } else { -1 }
    "{0}: rc={1} leftover={2} {3} tailByte={4}" -f $Name, $Code, $Leftover, ($Identity -join ' '), $Tail
    if ($Err) { "    THREW: $Err" }
    "    helpers: $Helpers"
}

Run-Case 'A-no-live-file' { param($d) }
Run-Case 'B-empty-live' { param($d) Set-Content -Path $d -Value '' -NoNewline }
Run-Case 'C-identity-only' { param($d)
    Set-Content -Path $d -Value "[user]`n`tname = Live Name`n`temail = live@example.com`n" }
Run-Case 'D-linuxbrew-helper' { param($d)
    Set-Content -Path $d -Value @"
[user]
	name = Live Name
	email = live@example.com
[credential "https://github.com"]
	helper = !/home/linuxbrew/.bin/gh auth git-credential
"@ }
Run-Case 'E-ghexe-spaces-unquoted' { param($d)
    Set-Content -Path $d -Value @"
[user]
	name = Live Name
	email = live@example.com
[credential "https://github.com"]
	helper = !C:/Program Files/GitHub CLI/gh.exe auth git-credential
"@ }
Run-Case 'F-ghexe-spaces-quoted' { param($d)
    Set-Content -Path $d -Value @"
[user]
	name = Live Name
	email = live@example.com
[credential "https://github.com"]
	helper = !"C:\Program Files\GitHub CLI\gh.exe" auth git-credential
"@ }
Run-Case 'G-scoop-shim-ghexe' { param($d)
    Set-Content -Path $d -Value @"
[user]
	name = Live Name
	email = live@example.com
[credential "https://github.com"]
	helper = $ScoopGh
"@ }
Run-Case 'H-canonical-twice' { param($d)
    Set-Content -Path $d -Value @"
[user]
	name = Live Name
	email = live@example.com
[credential "https://github.com"]
	helper =
	helper = !gh auth git-credential
"@
    Merge-Gitconfig -Src $Src -Dst $d
}
Run-Case 'I-unicode-identity' { param($d)
    [System.IO.File]::WriteAllText($d, "[user]`n`tname = Zoe Mueller-Ae`n`temail = zoe@example.com`n", [System.Text.UTF8Encoding]::new($false)) }
Run-Case 'J-bom-crlf-unrelated' { param($d)
    $content = "[user]`r`n`tname = Live Name`r`n`temail = live@example.com`r`n[core]`r`n`thooksPath = C:/custom/hooks`r`n[credential `"https://github.com`"]`r`n`thelper = !/opt/homebrew/bin/gh auth git-credential`r`n"
    [System.IO.File]::WriteAllText($d, $content, [System.Text.UTF8Encoding]::new($true)) }
Run-Case 'K-name-only' { param($d)
    Set-Content -Path $d -Value "[user]`n`tname = Only Name`n" }
Run-Case 'L-email-only' { param($d)
    Set-Content -Path $d -Value "[user]`n`temail = only@example.com`n" }

"---- E result helper lines ----"
Select-String -Path (Join-Path $Work 'E-ghexe-spaces-unquoted') -Pattern 'helper' | ForEach-Object { "E: $($_.Line)" }
Select-String -Path (Join-Path $Work 'F-ghexe-spaces-quoted') -Pattern 'helper' | ForEach-Object { "F: $($_.Line)" }
Select-String -Path (Join-Path $Work 'J-bom-crlf-unrelated') -Pattern 'helper|hooksPath' | ForEach-Object { "J: $($_.Line)" }
$jb = [System.IO.File]::ReadAllBytes((Join-Path $Work 'J-bom-crlf-unrelated'))
"J first bytes: $($jb[0..2] -join ',')"
"H result tail:"
Get-Content (Join-Path $Work 'H-canonical-twice') -Raw | ForEach-Object { $_ -replace "`n", '<LF>' } | Select-Object -First 1

"WORKDIR=$Work"
