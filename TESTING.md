# Testing & Coverage

Comprehensive test suite ensuring reliability across all platforms and components.

## Test Coverage

| Suite | Tests | Description |
|-------|-------|-------------|
| PowerShell | 1,200+ | Wrapper validation, bootstrap, config, git hooks, E2E, regression, integration, hook integrity |
| Bash | 970+ | Unit tests for deploy, backup, restore, healthcheck, uninstall, sync, git-update, hook integrity |
| **Total** | **2,200+** | Cross-platform test coverage |

## Test Areas

- **Bootstrap Process**: Platform detection, package installation, idempotency, correct platform bootstrap invocation
- **Configuration System**: YAML parsing, defaults, platform-specific settings
- **Deployment**: File copying, backup behavior, OneDrive handling
- **Git Hooks**: Commit message validation (Conventional Commits), pre-commit formatting/linting
- **Update Scripts**: Package manager detection, timeout handling, safety features
- **Edge Cases**: Error handling, missing dependencies, graceful failures
- **Regression Tests**: Pattern-based tests to prevent known bugs from returning
- **Integration Tests**: Isolated mock environments to verify actual runtime behavior

## Running Tests

```bash
# PowerShell tests - all suites
cd tests/powershell
pwsh -NoProfile -File run-tests.ps1

# Run specific test suite
pwsh -NoProfile -File wrapper.Tests.ps1
pwsh -NoProfile -File bootstrap-integration.Tests.ps1

# Bash tests (requires bats)
cd tests/bash
bats bootstrap_test.bats
bats git-hooks_test.bats
```

## Code Coverage

Universal coverage measurement using **kcov** for bash scripts and **Pester** for PowerShell scripts.

| Platform | Bash | PowerShell |
|----------|------|------------|
| Windows | kcov (via Docker) | Pester |
| Linux | kcov (native) | Pester |
| macOS | kcov (native) | Pester |

### Running Coverage

```bash
# Universal script (all platforms)
./tests/coverage.sh

# Bash-only coverage via Docker (all platforms)
./tests/coverage-docker.sh

# Bash-only coverage native (Linux/macOS)
./tests/coverage-bash.sh

# PowerShell-only coverage
pwsh -NoProfile -File tests/powershell/coverage.ps1

# Windows - full report with README update
.\tests\coverage-report.ps1 -UpdateReadme
```

### Coverage Output

- `coverage.json` - Combined coverage data for CI/CD
- `coverage-badge.svg` - Dynamic badge for README
- `coverage/kcov/index.html` - Detailed HTML report

### Badge Color Scale

| Coverage | Color |
|----------|-------|
| >= 89% | violet |
| >= 74% | indigo |
| >= 59% | blue |
| >= 44% | green |
| >= 29% | yellow |
| >= 15% | orange |
| < 15% | red |

## Test Philosophy

- Unit tests verify individual functions and components
- E2E tests validate real-world workflows in isolated environments
- Regression tests use pattern matching to prevent known bugs from returning
- Integration tests use mocked environments to verify runtime behavior without side effects
- Tests are self-contained and clean up after themselves
- All tests are deterministic and can run in any order
