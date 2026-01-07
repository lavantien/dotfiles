# PowerShell Git commit-msg hook - Enforces Conventional Commits specification
# Validates: type(scope): subject format with 72-char subject limit

param(
    [Parameter(Mandatory=$true)]
    [string]$CommitMsgFile
)

$ErrorActionPreference = "Stop"

$commitMsg = Get-Content $CommitMsgFile -Raw

# Skip validation for merge commits
if ($commitMsg -match "^Merge branch|^Merge remote-tracking") {
    exit 0
}

# Skip validation for revert commits (they follow their own convention)
if ($commitMsg -match "^Revert ") {
    exit 0
}

# Get the first line (subject)
$lines = $commitMsg -split "`n"
$subject = $lines[0].Trim()

# Check for empty commit message
if ([string]::IsNullOrWhiteSpace($subject)) {
    Write-Error "ERROR: Commit message cannot be empty."
    Write-Host "Expected format: type(scope): description"
    Write-Host "Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert"
    exit 1
}

# Conventional Commits pattern: type(scope): description
# Type is required, scope is optional
$conventionalPattern = "^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?: .{1,72}`$"

if ($subject -notmatch $conventionalPattern) {
    Write-Error "ERROR: Commit message does not follow Conventional Commits format."
    Write-Host ""
    Write-Host "Expected format: type(scope): description"
    Write-Host ""
    Write-Host "Type (required): feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert"
    Write-Host "Scope (optional): component or module in parentheses"
    Write-Host "Description: brief description (max 72 characters)"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  feat(api): add user authentication endpoint"
    Write-Host "  fix(auth): resolve token expiration issue"
    Write-Host "  docs: update installation instructions"
    Write-Host "  test(auth): add unit tests for login flow"
    Write-Host ""
    Write-Host "Your subject: $subject"
    Write-Host "Subject length: $($subject.Length) characters (max 72)"
    exit 1
}

# Check for blank line after subject
if ($lines.Count -gt 1 -and -not [string]::IsNullOrWhiteSpace($lines[1])) {
    Write-Error "ERROR: Commit message must have a blank line between subject and body."
    Write-Host ""
    Write-Host "Subject: $subject"
    Write-Host "Second line: $($lines[1])"
    Write-Host ""
    Write-Host "Please add a blank line after the subject line."
    exit 1
}

exit 0
