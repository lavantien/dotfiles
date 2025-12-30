# Universal git commit-msg hook - PowerShell version for Windows native
# Enforces conventional commits

$commitMsgFile = $args[0]
$commitMsg = Get-Content $commitMsgFile -Raw

# Skip if merge commit or revert
if ($commitMsg -match "^(Merge|Revert)") {
    exit 0
}

# Pattern: type(scope)!: description or type(scope): description or type: description
$pattern = "^(feat|fix|chore|docs|style|refactor|perf|test|build|ci|break|bump)(\(.+\))?!?: .{1,72}"

if ($commitMsg -notmatch $pattern) {
    Write-Host ""
    Write-Host "Commit message does not follow Conventional Commits format."
    Write-Host ""
    Write-Host "Expected format: <type>(<scope>): <description>"
    Write-Host ""
    Write-Host "Types: feat, fix, chore, docs, style, refactor, perf, test, build, ci"
    Write-Host "Example: feat(auth): add OAuth2 login support"
    Write-Host ""
    Write-Host "To bypass this check, use: git commit --no-verify"
    Write-Host ""
    exit 1
}

# Check subject line length (max 72 chars for first line)
$firstLine = ($commitMsg -split "`n")[0]
if ($firstLine.Length -gt 72) {
    Write-Host "Subject line should be 72 characters or less."
    Write-Host "Current length: $($firstLine.Length)"
    exit 1
}

# Check for empty line after subject
$lines = $commitMsg -split "`n"
if ($lines.Count -gt 1 -and $lines[1].Trim() -ne "") {
    Write-Host "Please add a blank line between subject and body."
    exit 1
}

exit 0
