# Dotfiles Development Rules

## Overview

This file provides master guidelines for working with this dotfiles repository. It complements detailed instructions in [CLAUDE.md](./CLAUDE.md).

## Core Principles

### 1. Source of Truth
- **This dotfiles repo is the source of truth** for all configurations
- All changes must flow FROM here TO your home directory, not the reverse
- Never modify deployed configs directly - edit in the repo, then re-deploy

### 2. Cross-Platform Consistency
- Scripts must work on: Windows 11, Linux (Ubuntu/Fedora/Arch), and macOS (Intel/Apple Silicon)
- Use platform detection (`detect_os` / `detect_distro`) to handle platform differences
- Test on at least 2 platforms before committing

### 3. Idempotency
- Scripts must be safe to run multiple times
- Check before acting (don't overwrite if already exists)
- Use `cmd_exists` / `Get-Command` before using tools
- Verify installations before re-installing

### 4. Graceful Degradation
- If a tool is missing, skip gracefully with warning
- Never fail silently - always inform the user of what was skipped
- Provide clear error messages with actionable steps

### 5. Non-Destructive by Default
- Require explicit flags (`--force`, `-f`) for destructive operations
- Always create backups before overwriting files
- Default to dry-run mode where safe

### 6. Security
- Never commit secrets, API keys, or credentials
- Use environment variables for sensitive data
- Validate all user inputs
- Never execute arbitrary code from untrusted sources

## Development Workflow

### Adding New Features
1. **Plan in AGENTS.md** before coding
2. Create tests first (TDD when appropriate)
3. Implement feature with error handling
4. Test on all supported platforms
5. Update documentation
6. Commit with conventional commit format

### Adding New Tools
When adding a new tool to bootstrap/update-all:

1. Add to appropriate `lib/common.sh` or `lib/config.ps1` helper functions
2. Add install check to bootstrap scripts (both Unix and Windows)
3. Add update check to update-all scripts
4. Add config option to `.dotfiles.config.yaml.example`
5. Add health check for tool in `healthcheck.sh/ps1`
6. Update documentation (README.md, this file)
7. Add tests for new tool

### Adding New Config Files
1. Add to backup scripts (`backup.sh/ps1`)
2. Add to restore scripts (`restore.sh/ps1`)
3. Add to deploy scripts (`deploy.sh/ps1`)
4. Add to uninstall verification lists
5. Update documentation

### Modifying Git Hooks
1. Keep hooks simple and focused
2. Don't make them block normal workflows
3. Always provide bypass options (git `--no-verify`)
4. Test hooks with various project types
5. Document bypass instructions in README

## Code Quality Standards

### Shell Scripts (Bash/Zsh)

1. Use `set -e` for strict error handling
2. Use functions over one-liners for readability
3. Use descriptive variable names in UPPER_CASE
4. Use `# === Section Name ===` for section headers
5. Use consistent colors for output (defined in common.sh)
6. Quote all variables properly: `"$VAR"`
7. Check command existence before using: `if cmd_exists tool; then`

### PowerShell Scripts

1. Use approved verb-noun for function names
2. Use `param()` blocks for parameters
3. Use `Should -Be*` assertions in Pester tests
4. Use `try { } catch { }` for error handling
5. Use `Write-Host` with colors for output
6. Use `ErrorActionPreference` appropriately
7. Use `Get-Command` with `-ErrorAction SilentlyContinue`

### Configuration Files

1. Use YAML for configs (if applicable)
2. Provide `.example` files with all options
3. Document each option clearly
4. Use sensible defaults
5. Support environment variable overrides

## Testing Standards

### Unit Tests

1. Test each function independently
2. Test error paths (missing tools, invalid input)
3. Test edge cases (empty strings, special characters)
4. Mock external dependencies where possible
5. Use descriptive test names: `test_function_name_situation`

### Integration Tests

1. Test complete workflows (bootstrap → deploy → healthcheck)
2. Test on clean environment (temporary directory)
3. Test error recovery (what happens if install fails?)
4. Test idempotency (run script twice)
5. Test rollback scenarios

### Test Coverage Goals

- Parameter parsing: 100%
- Platform detection: 100%
- Core functions: 80%+
- Error handling paths: 70%+
- Integration workflows: 100%

## Documentation Standards

### README.md

1. Keep installation instructions current
2. Update feature lists when adding/removing
3. Document all environment variables
4. Update "What Gets Installed" table
5. Include troubleshooting section
6. Add examples for common use cases

### Code Comments

1. Comment complex logic (why, not just what)
2. Document non-obvious parameters
3. Reference relevant documentation URLs
4. Keep comments concise and relevant
5. Remove outdated comments

## Error Handling

### Display Format

```
[ERROR] Short, actionable description
[WARN]  Potential issue that needs attention
[INFO]  Informational message
[OK]   Success message
```

### Error Messages

1. Start with what failed: "Failed to install: neovim"
2. Include likely cause: "Scoop is not installed"
3. Provide clear solution: "Run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
4. Never expose stack traces to users unless in debug mode
5. Include relevant file paths for troubleshooting

### Exit Codes

- `0`: Success
- `1`: General error
- `2`: Invalid arguments
- `124`: Timeout
- `126`: Command not found
- `127`: Command not executable

## Platform-Specific Guidelines

### Windows (PowerShell)

1. Use `$env:VARIABLE` for environment variables
2. Use `Join-Path $path "subpath"` for path construction
3. Use `Split-Path $path -Parent` for directory extraction
4. Handle OneDrive Documents folder correctly
5. Use PowerShell 7+ features when available
6. Test in both Windows PowerShell and PowerShell 7

### Linux/macOS (Bash/Zsh)

1. Use `[[ ]]` for string comparisons (POSIX compliant)
2. Use `command -v` instead of `which` (more portable)
3. Handle macOS Homebrew paths correctly (`/opt/homebrew` vs `/usr/local`)
4. Use `$HOME` instead of `~` in scripts (more reliable)
5. Use `chmod +x` for scripts before first use
6. Test on multiple distros if possible

## Alias Guidelines

### Naming Conventions

- Git: `g` + abbreviation (`gs`, `gl`, `gp`, `gcm`)
- Docker: `d` + abbreviation (`ds`, `dx`, `dp`, `dc`)
- File ops: Single letter (`n`, `b`, `f`, `t`)
- Tools: Single letter if common (`m`, `ff`, `df`)

### Cross-Platform Consistency

- Same aliases must work on Bash, Zsh, and PowerShell
- Test alias on all platforms before committing
- Document platform-specific differences in comments
- Handle conflicts with built-in commands appropriately

## Version Management

### Pinning Packages

1. Pin specific versions where stability matters
2. Use minimum version constraints for SDKs
3. Keep version in config file (`.dotfiles.config.yaml`)
4. Document reasons for version pinning

### Updating Dependencies

1. Always run tests after updates
2. Test backward compatibility
3. Provide migration guide if breaking changes
4. Update CHANGELOG or use Git commits for history

## Security Considerations

### Input Validation

1. Validate all file paths
2. Sanitize environment variables
3. Validate configuration values
4. Reject obviously malicious inputs

### Safe Defaults

1. Don't enable auto-update by default
2. Don't expose debug mode to internet
3. Use secure defaults for SSH/Git config
4. Require explicit consent for destructive operations

### Secret Management

1. Never hardcode API keys
2. Use environment variables or secure storage
3. Exclude secrets from git (check `.gitignore`)
4. Provide example configs with placeholders

## Performance

### Parallel Execution

1. Run independent operations in parallel where safe
2. Use appropriate parallelization for each platform:
   - Bash: `&` background jobs, `wait`
   - PowerShell: `Start-Job`, `Wait-Job`
3. Don't exceed system resources
4. Add timeouts to long-running operations

### Caching

1. Cache GitHub API responses in git-update-repos
2. Use local package caches where available
3. Cache tool availability checks
4. Respect cache TTLs and invalidation

## When in Doubt

1. Check existing patterns in the codebase
2. Review AGENTS.md for agent behavior guidelines
3. Ask for clarification if requirements are ambiguous
4. Prefer simpler, boring solutions over clever ones
5. Focus on maintainability over clever optimizations

## Resources

- [CLAUDE.md](./CLAUDE.md) - AI assistant instructions
- [AGENTS.md](./AGENTS.md) - Agent-specific behavior
- [GEMINI.md](./GEMINI.md) - Gemini-specific instructions
- [README.md](./README.md) - Usage documentation
- [tests/README.md](tests/README.md) - Testing guidelines

