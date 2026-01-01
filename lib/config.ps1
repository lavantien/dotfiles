# Configuration parser for dotfiles
# Supports simple YAML key-value pairs
# For complex YAML, install powershell-yaml: Install-Module powershell-yaml

# ============================================================================
# LOAD CONFIG FILE
# ============================================================================

# Global config variables (will be populated from config file)
$script:CONFIG_EDITOR = ""
$script:CONFIG_TERMINAL = ""
$script:CONFIG_THEME = ""
$script:CONFIG_CATEGORIES = "full"
$script:CONFIG_AUTO_UPDATE_REPOS = "false"
$script:CONFIG_BACKUP_BEFORE_DEPLOY = "false"
$script:CONFIG_SIGN_COMMITS = "false"
$script:CONFIG_DEFAULT_BRANCH = "main"
$script:CONFIG_GITHUB_USERNAME = ""
$script:CONFIG_BASE_DIR = ""
$script:CONFIG_AUTO_COMMIT = "false"
$script:CONFIG_SKIP_PACKAGES = @()

# Platform-specific
$script:CONFIG_LINUX_PACKAGE_MANAGER = ""
$script:CONFIG_LINUX_DISPLAY_SERVER = ""
$script:CONFIG_WINDOWS_PACKAGE_MANAGER = ""
$script:CONFIG_MACOS_PACKAGE_MANAGER = ""

# Load config from file if it exists
# Usage: Load-DotfilesConfig [-ConfigFile] "path"
function Load-DotfilesConfig {
    param(
        [string]$ConfigFile = "$env:USERPROFILE\.dotfiles.config.yaml"
    )

    # If config file doesn't exist, use defaults
    if (-not (Test-Path $ConfigFile)) {
        return
    }

    # Try to use powershell-yaml if available
    if (Get-Module -ListAvailable -Name powershell-yaml) {
        Import-Module powershell-yaml
        _ParseConfigWithModule $ConfigFile
    } else {
        # Fallback to simple parsing
        _ParseConfigSimple $ConfigFile
    }
}

# Parse config using powershell-yaml (recommended)
function _ParseConfigWithModule {
    param([string]$ConfigFile)

    $config = Get-Content $ConfigFile -Raw | ConvertFrom-Yaml

    $script:CONFIG_EDITOR = if ($config.editor) { $config.editor } else { "" }
    $script:CONFIG_TERMINAL = if ($config.terminal) { $config.terminal } else { "" }
    $script:CONFIG_THEME = if ($config.theme) { $config.theme } else { "" }
    $script:CONFIG_CATEGORIES = if ($config.categories) { $config.categories } else { "full" }
    $script:CONFIG_AUTO_UPDATE_REPOS = if ($config.auto_update_repos) { $config.auto_update_repos.ToString() } else { "false" }
    $script:CONFIG_BACKUP_BEFORE_DEPLOY = if ($config.backup_before_deploy) { $config.backup_before_deploy.ToString() } else { "false" }
    $script:CONFIG_SIGN_COMMITS = if ($config.sign_commits) { $config.sign_commits.ToString() } else { "false" }
    $script:CONFIG_DEFAULT_BRANCH = if ($config.default_branch) { $config.default_branch } else { "main" }
    $script:CONFIG_GITHUB_USERNAME = if ($config.github_username) { $config.github_username } else { "" }
    $script:CONFIG_BASE_DIR = if ($config.base_dir) { $config.base_dir } else { "" }
    $script:CONFIG_AUTO_COMMIT = if ($config.auto_commit_changes) { $config.auto_commit_changes.ToString() } else { "false" }

    if ($config.skip_packages) {
        $script:CONFIG_SKIP_PACKAGES = $config.skip_packages
    }

    # Platform-specific settings
    if ($config.linux) {
        $script:CONFIG_LINUX_PACKAGE_MANAGER = if ($config.linux.package_manager) { $config.linux.package_manager } else { "" }
        $script:CONFIG_LINUX_DISPLAY_SERVER = if ($config.linux.display_server) { $config.linux.display_server } else { "" }
    }

    if ($config.windows) {
        $script:CONFIG_WINDOWS_PACKAGE_MANAGER = if ($config.windows.package_manager) { $config.windows.package_manager } else { "scoop" }
    }

    if ($config.macos) {
        $script:CONFIG_MACOS_PACKAGE_MANAGER = if ($config.macos.package_manager) { $config.macos.package_manager } else { "brew" }
    }
}

# Simple YAML parser fallback (handles basic key: value pairs)
function _ParseConfigSimple {
    param([string]$ConfigFile)

    $currentSection = ""

    Get-Content $ConfigFile | ForEach-Object {
        $line = $_.Trim()

        # Skip comments and empty lines
        if ($line.StartsWith('#') -or [string]::IsNullOrEmpty($line)) {
            return
        }

        # Detect sections (keys with colons and no value on same line)
        if ($line -match '^[a-z_]+:$') {
            $currentSection = $line.Trim(':')
            return
        }

        # Parse key: value pairs
        if ($line -match '^([a-z_]+):\s*(.+)$') {
            $key = $matches[1]
            $value = $matches[2].Trim()

            # Remove quotes and comments from value
            $value = $value -replace '["'']', ''
            $value = $value -split '#' | Select-Object -First 1
            $value = $value.Trim()

            # Remove array brackets for skip_packages
            if ($value -match '^\[(.+)\]$') {
                $value = $matches[1].Trim() -split ',' | ForEach-Object { $_.Trim() }
            }

            # Assign to appropriate config variable
            switch ($key) {
                'editor' { $script:CONFIG_EDITOR = $value }
                'terminal' { $script:CONFIG_TERMINAL = $value }
                'theme' { $script:CONFIG_THEME = $value }
                'categories' { $script:CONFIG_CATEGORIES = $value }
                'auto_update_repos' { $script:CONFIG_AUTO_UPDATE_REPOS = $value }
                'backup_before_deploy' { $script:CONFIG_BACKUP_BEFORE_DEPLOY = $value }
                'sign_commits' { $script:CONFIG_SIGN_COMMITS = $value }
                'default_branch' { $script:CONFIG_DEFAULT_BRANCH = $value }
                'github_username' { $script:CONFIG_GITHUB_USERNAME = $value }
                'base_dir' { $script:CONFIG_BASE_DIR = $value }
                'auto_commit_changes' { $script:CONFIG_AUTO_COMMIT = $value }
                'skip_packages' { $script:CONFIG_SKIP_PACKAGES = if ($value -is [array]) { $value } else { @() } }
                'package_manager' {
                    switch ($currentSection) {
                        'linux' { $script:CONFIG_LINUX_PACKAGE_MANAGER = $value }
                        'windows' { $script:CONFIG_WINDOWS_PACKAGE_MANAGER = $value }
                        'macos' { $script:CONFIG_MACOS_PACKAGE_MANAGER = $value }
                    }
                }
                'display_server' { $script:CONFIG_LINUX_DISPLAY_SERVER = $value }
            }
        }
    }
}

# ============================================================================
# CONFIG GETTERS
# ============================================================================

# Get config value with default fallback
# Usage: Get-ConfigValue [-Key] "name" [-Default] "default_value"
function Get-ConfigValue {
    param(
        [string]$Key,
        [string]$Default = ""
    )

    $value = switch ($Key) {
        'editor' { $script:CONFIG_EDITOR }
        'terminal' { $script:CONFIG_TERMINAL }
        'theme' { $script:CONFIG_THEME }
        'categories' { $script:CONFIG_CATEGORIES }
        'auto_update_repos' { $script:CONFIG_AUTO_UPDATE_REPOS }
        'backup_before_deploy' { $script:CONFIG_BACKUP_BEFORE_DEPLOY }
        'sign_commits' { $script:CONFIG_SIGN_COMMITS }
        'default_branch' { $script:CONFIG_DEFAULT_BRANCH }
        'github_username' { $script:CONFIG_GITHUB_USERNAME }
        'base_dir' { $script:CONFIG_BASE_DIR }
        'auto_commit_changes' { $script:CONFIG_AUTO_COMMIT }
        'linux_package_manager' { $script:CONFIG_LINUX_PACKAGE_MANAGER }
        'windows_package_manager' { $script:CONFIG_WINDOWS_PACKAGE_MANAGER }
        'macos_package_manager' { $script:CONFIG_MACOS_PACKAGE_MANAGER }
        default { $null }
    }

    if ($value) {
        return $value
    }
    return $Default
}

# Check if a package should be skipped
# Usage: Test-SkipPackage [-Package] "package_name"
function Test-SkipPackage {
    param([string]$Package)

    if (-not $script:CONFIG_SKIP_PACKAGES) {
        return $false
    }

    return $script:CONFIG_SKIP_PACKAGES -contains $Package
}

# Export functions
Export-ModuleMember -Function Load-DotfilesConfig, Get-ConfigValue, Test-SkipPackage
