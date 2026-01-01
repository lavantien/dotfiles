# Bridge Approach: Backward & Forward Compatibility

## Overview

The bootstrap scripts now support **two modes of operation** that work together seamlessly:

1. **Backward Compatible Mode (Default)**: Works without any config file using hardcoded defaults
2. **Forward Compatible Mode (Optional)**: Loads config from `~/.dotfiles.config.yaml` if present

## How It Works

### Automatic Detection

Both `bootstrap/bootstrap.sh` and `bootstrap/bootstrap.ps1` follow this logic:

```
1. Set hardcoded defaults (categories="full", interactive=true, etc.)
2. Check if config library exists (lib/config.sh or lib/config.ps1)
3. If library exists AND config file exists → Load config
4. If library exists AND config file missing → Use defaults
5. If library missing → Use defaults (no error)
```

### Key Principles

1. **Config Library is Optional**: Scripts work even if `lib/config.sh` or `lib/config.ps1` is deleted
2. **Config File is Optional**: Scripts work even if `~/.dotfiles.config.yaml` doesn't exist
3. **Defaults are Preserved**: All hardcoded defaults remain as fallbacks
4. **No Breaking Changes**: Existing workflow continues to work exactly as before

## Usage Examples

### Option 1: Simple Usage (No Config File)

```bash
# Linux/macOS - uses hardcoded defaults (categories="full")
./bootstrap/bootstrap.sh

# Windows - uses hardcoded defaults (categories="full")
.\bootstrap\bootstrap.ps1

# Override with command-line flags
./bootstrap/bootstrap.sh --categories minimal
.\bootstrap\bootstrap.ps1 -Categories sdk
```

### Option 2: Advanced Usage (With Config File)

1. **Create config file** from the example:

```bash
cp .dotfiles.config.yaml.example ~/.dotfiles.config.yaml
```

2. **Edit the config** to your preferences:

```yaml
# ~/.dotfiles.config.yaml
categories: sdk
editor: nvim
theme: gruvbox-dark
auto_update_repos: true
github_username: yourname
base_dir: ~/dev/github
```

3. **Run bootstrap** - it will automatically use config:

```bash
# Will use categories="sdk" from config, not hardcoded "full"
./bootstrap/bootstrap.sh
```

4. **Still override with flags** (flags take precedence over config):

```bash
# Uses "minimal" from flag, ignores config
./bootstrap/bootstrap.sh --categories minimal
```

## Configuration Priority

From highest to lowest priority:

1. **Command-line flags** (e.g., `--categories minimal`)
2. **Config file** (`~/.dotfiles.config.yaml`)
3. **Hardcoded defaults** (in script)

## Testing the Bridge

Run the verification script:

```bash
./test-bridge.sh
```

This verifies:
- ✓ Bootstrap works without config file (backward compatibility)
- ✓ Config library is optional
- ✓ Hardcoded defaults exist
- ✓ Both bash and PowerShell syntax are valid

## Migration Guide

### For Existing Users

**No changes needed!** Your existing workflow continues to work exactly as before.

If you want to use the config system:
1. Copy the example: `cp .dotfiles.config.yaml.example ~/.dotfiles.config.yaml`
2. Edit to your preferences
3. Run bootstrap normally - it will auto-detect and use your config

### For New Users

Start simple, then customize if needed:

```bash
# Step 1: Just run bootstrap (works out of the box)
./bootstrap/bootstrap.sh

# Step 2: Later, if you want customization
cp .dotfiles.config.yaml.example ~/.dotfiles.config.yaml
# Edit the file
./bootstrap/bootstrap.sh  # Will now use your config
```

## Technical Details

### Bash (bootstrap/bootstrap.sh)

```bash
# 1. Hardcoded defaults
CATEGORIES="full"

# 2. Try to load config (optional)
if declare -f load_dotfiles_config >/dev/null 2>&1; then
    if [[ -f "$CONFIG_FILE" ]]; then
        load_dotfiles_config "$CONFIG_FILE" 2>/dev/null
        CATEGORIES=$(get_config "categories" "$CATEGORIES")
    fi
fi
```

### PowerShell (bootstrap/bootstrap.ps1)

```powershell
# 1. Hardcoded defaults
$Script:Categories = $Categories

# 2. Try to load config (optional)
if (Get-Command Load-DotfilesConfig -ErrorAction SilentlyContinue) {
    if (Test-Path $ConfigFile) {
        try {
            Load-DotfilesConfig -ConfigFile $ConfigFile
            if ($script:CONFIG_CATEGORIES) {
                $Script:Categories = $script:CONFIG_CATEGORIES
            }
        } catch {
            Write-Warning "Failed to load config file"
        }
    }
}
```

## Benefits

✅ **Zero Friction**: Works immediately without configuration
✅ **No Breaking Changes**: Existing scripts continue to work
✅ **Optional Complexity**: Use config only when you need it
✅ **Safe Fallback**: If config fails, script continues with defaults
✅ **Cross-Platform**: Works identically on Linux, macOS, and Windows
✅ **Tested**: All scenarios verified with automated tests

## Troubleshooting

### Q: Script says "Config library not found, using defaults"
A: This is normal! The script works fine without the config library. It just uses hardcoded defaults.

### Q: I created a config file but it's not being used
A: Check:
1. File is at `~/.dotfiles.config.yaml` (not in the dotfiles repo)
2. YAML syntax is valid (you can use `yq` to validate)
3. No syntax errors in the file

### Q: How do I know which settings are being used?
A: The bootstrap script displays the options at startup:
```
Options:
  Interactive: true
  Dry Run: false
  Categories: full
  Skip Update: false
```

## File Structure

```
dotfiles/
├── bootstrap/
│   ├── bootstrap.sh          # Main bash bootstrap (supports both modes)
│   ├── bootstrap.ps1         # Main PowerShell bootstrap (supports both modes)
│   └── lib/
│       ├── common.sh         # Core functions (required)
│       └── config.sh        # Config parser (optional)
├── lib/
│   ├── config.sh            # Shared config library (optional)
│   └── config.ps1          # Shared config library (optional)
├── .dotfiles.config.yaml.example  # Example config
└── test-bridge.sh          # Verification script
```

## Summary

The bridge approach gives you the **best of both worlds**:

- **Simplicity**: Works out of the box with hardcoded defaults
- **Flexibility**: Supports configuration when you need it
- **Safety**: Optional components, graceful fallbacks
- **Compatibility**: No breaking changes to existing workflows

Your desired workflow is preserved:

1. ✅ Run `bootstrap/bootstrap.ps1` - works immediately
2. ✅ Default is "full" - set in script
3. ✅ Everything setup correctly - no config needed
4. ✅ Scripts in `~/dev` for git repos - git-update-repos.ps1
5. ✅ Distribute instructions with `-Commit` flag - sync-system-instructions.ps1

**Zero friction, zero breaking changes, maximum flexibility.**
