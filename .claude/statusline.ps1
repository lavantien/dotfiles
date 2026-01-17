# Claude Code StatusLine for Windows PowerShell 7
# Displays: dir branch git-status model tokens/max (pct%) cost style vim-mode

param()

# Set PowerShell output encoding to UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ANSI color codes
$ESC = [char]27
$GREEN = "$ESC[32m"
$BLUE = "$ESC[34m"
$YELLOW = "$ESC[33m"
$CYAN = "$ESC[36m"
$MAGENTA = "$ESC[35m"
$RED = "$ESC[31m"
$WHITE = "$ESC[37m"
$GRAY = "$ESC[90m"
$BOLD = "$ESC[1m"
$DIM = "$ESC[2m"
$RESET = "$ESC[0m"

# Read JSON input from stdin using StreamReader (Windows-compatible method)
$jsonInput = ""
try {
    $inputStream = [System.IO.StreamReader]::new([System.Console]::OpenStandardInput())
    $jsonInput = $inputStream.ReadToEnd()
    $inputStream.Close()
}
catch {
    # Fallback for empty input
    $jsonInput = '{"model":{"display_name":"Claude"},"workspace":{"current_dir":"."}}'
}

try {
    # Parse JSON
    $data = $jsonInput | ConvertFrom-Json

    # Extract fields with fallbacks
    $modelDisplay = if ($data.model.display_name) { $data.model.display_name } else { "Claude" }
    $currentDir = if ($data.workspace.current_dir) { $data.workspace.current_dir } else { "." }
    $projectDir = if ($data.workspace.project_dir) { $data.workspace.project_dir } else { "" }
    $outputStyle = if ($data.output_style.name) { $data.output_style.name } else { "" }
    $vimMode = if ($data.vim.mode) { $data.vim.mode } else { "" }

    # Get git branch and status
    $gitBranch = ""
    $gitStatus = ""
    if ($currentDir -and (Test-Path $currentDir)) {
        $null = git -C $currentDir rev-parse --git-dir 2>$null
        if ($LASTEXITCODE -eq 0) {
            $branch = git -C $currentDir branch --show-current 2>$null
            if ($branch) {
                $gitBranch = " ${CYAN}${branch}${RESET}"
            }

            $status = git -C $currentDir status --porcelain 2>$null
            if ($status) {
                $staged = ($status | Where-Object { $_ -match '^[MADRC]' }).Count
                $unstaged = ($status | Where-Object { $_ -match '^.M' -or $_ -match '^.D' }).Count
                $untracked = ($status | Where-Object { $_ -match '^\?\?' }).Count

                $statusParts = @()
                if ($staged -gt 0) { $statusParts += "${GREEN}S${staged}${RESET}" }
                if ($unstaged -gt 0) { $statusParts += "${YELLOW}M${unstaged}${RESET}" }
                if ($untracked -gt 0) { $statusParts += "${GRAY}U${untracked}${RESET}" }

                if ($statusParts.Count -gt 0) {
                    $gitStatus = " [$($statusParts -join '')]"
                }
            }
        }
    }

    # Context window info - use remaining_percentage from 2.1.6+
    $contextInfo = ""
    if ($data.context_window) {
        $contextSize = if ($data.context_window.context_window_size) { [int]$data.context_window.context_window_size } else { 0 }

        # Try 2.1.6+ fields first
        $remainingPct = if ($data.context_window.remaining_percentage) { [double]$data.context_window.remaining_percentage } else { 0 }
        $usedPct = if ($data.context_window.used_percentage) { [double]$data.context_window.used_percentage } else { 0 }

        # If percentages not available, calculate from current_usage
        if ($remainingPct -eq 0 -and $usedPct -eq 0 -and $data.context_window.current_usage) {
            $currentUsage = $data.context_window.current_usage
            $inputTokens = if ($currentUsage.input_tokens) { $currentUsage.input_tokens } else { 0 }
            $outputTokens = if ($currentUsage.output_tokens) { $currentUsage.output_tokens } else { 0 }
            $cacheCreation = if ($currentUsage.cache_creation_input_tokens) { $currentUsage.cache_creation_input_tokens } else { 0 }
            $cacheRead = if ($currentUsage.cache_read_input_tokens) { $currentUsage.cache_read_input_tokens } else { 0 }

            $totalUsed = $inputTokens + $outputTokens + $cacheCreation + $cacheRead
            $usedPct = if ($contextSize -gt 0) { ($totalUsed / $contextSize) * 100 } else { 0 }
            $remainingPct = 100 - $usedPct

            $usedK = [math]::Round($totalUsed / 1000, 0)
        } else {
            # Calculate used tokens from percentage
            $usedTokens = [math]::Round(($usedPct / 100) * $contextSize)
            $usedK = [math]::Round($usedTokens / 1000, 0)
        }

        $maxK = [math]::Round($contextSize / 1000, 0)

        # Determine color based on remaining percentage
        $pctColor = if ($remainingPct -le 20) { $RED } elseif ($remainingPct -le 50) { $YELLOW } else { $GREEN }

        if ($remainingPct -gt 0) {
            $pctStr = [math]::Round($remainingPct, 0)
            $contextInfo = " ${pctColor}${usedK}K/${maxK}K${RESET} ${DIM}(${pctStr}% remaining)${RESET}"
        } elseif ($usedPct -gt 0) {
            $pctStr = [math]::Round($usedPct, 0)
            $contextInfo = " ${pctColor}${usedK}K/${maxK}K${RESET} ${DIM}(${pctStr}% used)${RESET}"
        } else {
            $contextInfo = " ${pctColor}${usedK}K/${maxK}K${RESET}"
        }
    }

    # Cost info
    $costInfo = ""
    if ($data.cost -and $data.cost.total_cost_usd) {
        $cost = $data.cost.total_cost_usd
        if ($cost -ge 0.01) {
            $costStr = "{0:N2}" -f $cost
            $costInfo = " " + $GRAY + "$" + $costStr + $RESET
        }
    }

    # Directory display
    $dirDisplay = Split-Path -Leaf $currentDir
    if ($currentDir -ne $projectDir -and $projectDir -and $currentDir.StartsWith($projectDir)) {
        $relPath = $currentDir.Substring($projectDir.Length + 1)
        $projectName = Split-Path -Leaf $projectDir
        $dirDisplay = "${projectName}/${relPath}"
    }

    # Build output
    $output = ""

    # Directory
    $output += "${BLUE}${dirDisplay}${RESET}"

    # Git branch
    if ($gitBranch) {
        $output += $gitBranch
    }

    # Git status
    if ($gitStatus) {
        $output += $gitStatus
    }

    # Model name
    $modelShort = $modelDisplay -replace "Claude ", ""
    $output += " ${BOLD}${MAGENTA}${modelShort}${RESET}"

    # Context window
    if ($contextInfo) {
        $output += $contextInfo
    }

    # Cost
    if ($costInfo) {
        $output += $costInfo
    }

    # Output style
    if ($outputStyle -and $outputStyle -ne "default") {
        $output += " ${YELLOW}${outputStyle}${RESET}"
    }

    # Vim mode
    if ($vimMode) {
        $output += " ${RED}[${vimMode}]${RESET}"
    }

    # Write to stdout and flush
    [System.Console]::Write($output)
    [System.Console]::Out.Flush()

}
catch {
    # Fallback on error
    [System.Console]::Write("${BLUE}Claude${RESET}")
    [System.Console]::Out.Flush()
}

exit 0
