# Quick Reference: Bootstrap Bridge Approach

## Your Workflow (Simple & Reliable)

```
1. Run bootstrap
   ↓
   ├── No config file? → Uses hardcoded defaults (full)
   ├── Config file exists? → Loads config (if valid)
   └── Config invalid? → Uses defaults + warning
   ↓
   Everything installed & configured
   ↓
   2. Update git repos
   ↓
   3. Sync instructions (optional: commit & push)
```

## Quick Commands

### Windows (PowerShell)

```powershell
# Bootstrap - either path works:
.\bootstrap.ps1              # Root-level wrapper (convenience)
.\bootstrap\bootstrap.ps1    # Full implementation in bootstrap/ directory

# With custom category
.\bootstrap\bootstrap.ps1 -Categories sdk

# Update all repos
.\git-update-repos.ps1

# Update with auto-commit
.\git-update-repos.ps1 -Commit

# Sync instructions
.\sync-system-instructions.ps1

# Sync + commit + push
.\sync-system-instructions.ps1 -Commit -Push
```

### Linux / macOS (Bash)

```bash
# Bootstrap - either path works:
./bootstrap.sh              # Root-level wrapper (convenience)
./bootstrap/bootstrap.sh    # Full implementation in bootstrap/ directory

# With custom category
./bootstrap/bootstrap.sh --categories sdk

# Update all repos
./git-update-repos.sh

# Update with auto-commit
./git-update-repos.sh -c

# Sync instructions
./sync-system-instructions.sh

# Sync + commit + push
./sync-system-instructions.sh -c -p
```

## Configuration (Optional)

### Enable Config (Optional)

```bash
# 1. Copy example
cp .dotfiles.config.yaml.example ~/.dotfiles.config.yaml

# 2. Edit your preferences
vim ~/.dotfiles.config.yaml

# 3. Run bootstrap (auto-detects config)
./bootstrap.sh              # or ./bootstrap/bootstrap.sh - both work
```

### Common Config Options

| Setting | Values | Default |
|---------|---------|---------|
| `categories` | minimal, sdk, full | full |
| `editor` | nvim, vim, code, nano | (none) |
| `theme` | rose-pine, rose-pine-dawn, rose-pine-moon | (none) |
| `github_username` | your github username | (none) |
| `base_dir` | path to git repos | ~/dev/github |
| `auto_commit_repos` | true, false | false |

## Troubleshooting

### Issue: Bootstrap says "Config library not found"
**Solution:** This is normal! It's using defaults. No action needed.

### Issue: Config file not being used
**Solution:**
1. Check file is at `~/.dotfiles.config.yaml` (not in dotfiles repo)
2. Validate YAML syntax: `yq eval ~/.dotfiles.config.yaml`
3. Check for syntax errors

### Issue: Command-line flag not working
**Solution:** Flags have highest priority, should override config. Check flag syntax:
- Bash: `--categories minimal`
- PowerShell: `-Categories minimal`

## Verification

### Run Tests

```bash
# Verify bridge approach works
./test-bridge.sh

# Expected: All Tests Passed! ✓
```

### Check Current Settings

```powershell
# Bootstrap shows options at startup
.\bootstrap\bootstrap.ps1

# Output:
# Options:
#   Interactive: true
#   Dry Run: false
#   Categories: full
#   Skip Update: false
```

## Key Principles

✅ **Zero Friction** - Works immediately without setup
✅ **Backward Compatible** - Existing workflows unchanged
✅ **Forward Compatible** - Optional config for customization
✅ **Graceful Fallbacks** - Errors don't break the script
✅ **Cross-Platform** - Same behavior on all platforms
✅ **Tested & Verified** - Automated tests confirm reliability

## File Locations

```
dotfiles/
├── bootstrap.sh            # Root-level wrapper (convenience)
├── bootstrap.ps1           # Root-level wrapper (convenience)
├── bootstrap/
│   ├── bootstrap.sh          # Main bash bootstrap (implementation)
│   ├── bootstrap.ps1         # Main PowerShell bootstrap (implementation)
│   └── lib/                # Bootstrap-specific libraries
├── lib/
│   ├── config.sh            # Shared config (bash)
│   └── config.ps1          # Shared config (PowerShell)
├── .dotfiles.config.yaml.example  # Example config
├── test-bridge.sh          # Verification script
├── BRIDGE.md               # Bridge documentation
└── FIX_SUMMARY.md          # Fix details

~/
└── .dotfiles.config.yaml   # Your config (optional)
```

## Getting Help

### Documentation
- **This file:** Quick reference and common tasks
- **[BRIDGE.md](BRIDGE.md):** Detailed bridge approach documentation
- **[FIX_SUMMARY.md](FIX_SUMMARY.md):** What was fixed and why
- **[README.md](README.md):** Main documentation

### Common Questions

**Q: Do I need a config file?**
A: No! Bootstrap works perfectly with hardcoded defaults.

**Q: Can I use both flags and config?**
A: Yes! Flags override config, config overrides defaults.

**Q: What if I delete my config file?**
A: No problem! Bootstrap will use hardcoded defaults.

**Q: Is config required for git repo scripts?**
A: No! They work with env vars or hardcoded defaults too.

## Summary

**Your workflow is preserved:**
1. ✅ Run `bootstrap.ps1` or `bootstrap/bootstrap.ps1` - both work immediately
2. ✅ Default is "full" - set in script
3. ✅ Everything setup correctly - no config needed
4. ✅ Scripts in `~/dev/github` - git-update-repos.ps1
5. ✅ Distribute instructions - sync-system-instructions.ps1 -Commit

**Plus new capabilities:**
- Optional config for customization
- No breaking changes
- Graceful error handling
- Tested and verified

**Zero friction, zero breaking changes, maximum flexibility.**
