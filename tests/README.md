# Dotfiles Test Suite

This directory contains unit and integration tests for the dotfiles repository.

## Test Frameworks

- **Bash**: [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core)
- **PowerShell**: [Pester](https://pester.dev/)

## Running Tests

### Bash Tests

```bash
# Run all bash tests
bats tests/bash/

# Run specific test file
bats tests/bash/bootstrap_test.bats

# Run with verbose output
bats -t tests/bash/

# Run with pretty output
bats -p tests/bash/
```

### PowerShell Tests

```powershell
# Run all PowerShell tests
Invoke-Pester tests/powershell/

# Run specific test file
Invoke-Pester tests/powershell/bootstrap.Tests.ps1

# Run with detailed output
Invoke-Pester tests/powershell/ -Verbose

# Run with Passthru
Invoke-Pester tests/powershell/ -PassThru
```

### Integration Tests

```bash
# Run integration tests (bash)
bats tests/integration/

# Integration tests may create temporary files and modify your home directory
# They use --dry-run where possible
```

## Test Coverage

### Unit Tests

- `tests/bash/bootstrap_test.bats`: Bootstrap common functions, platform detection
- `tests/bash/update-all_test.bats`: Update logic, timeout handling
- `tests/bash/git-hooks_test.bats`: Project detection, language checks
- `tests/powershell/bootstrap.Tests.ps1`: PowerShell bootstrap functions
- `tests/powershell/update-all.Tests.ps1`: PowerShell update functions

### Integration Tests

- `tests/integration/e2e_test.bats`: End-to-end workflows
  - Backup & restore
  - Health check
  - Uninstall
  - Update-all
  - Deploy
  - Git update-repos
  - Bootstrap

## Test Structure

### Unit Test Example (BATS)

```bash
@test "test_name_here" {
    # Setup
    run some_function arg1 arg2

    # Assertion
    [ "$status" -eq 0 ]
    [[ "$output" == *"expected substring"* ]]
}
```

### Unit Test Example (Pester)

```powershell
Describe "Feature Name" {

    It "test name here" {
        # Arrange
        $expected = "result"

        # Act
        $actual = Get-Something

        # Assert
        $actual | Should -Be $expected
    }
}
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Tests
on: [push, pull_request]

jobs:
  bash-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install BATS
        run: npm install -g bats
      - name: Run tests
        run: bats tests/bash/

  powershell-tests:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Pester
        run: Install-Module -Name Pester -Force -MinimumVersion 5.0.0
      - name: Run tests
        run: Invoke-Pester tests/powershell/ -PassThru
```

## Test Goals

- **Coverage**: 80%+ for critical functions
- **Unit tests**: 100% for parameter parsing
- **Error handling**: 70% for error paths
- **Integration**: All major workflows tested

## Adding New Tests

1. Create test file in appropriate directory (`tests/bash/` or `tests/powershell/`)
2. Use descriptive test names that explain what is being tested
3. Follow AAA pattern (Arrange, Act, Assert)
4. Clean up resources in `teardown()` function
5. Document edge cases and limitations

## Troubleshooting

### Tests fail with "command not found"

- Ensure required dependencies are installed:
  - BATS: `npm install -g bats`
  - Pester: `Install-Module Pester`

### Integration tests modify actual files

- Use `--dry-run` flag where available
- Run in isolated environment (e.g., Docker container, VM)

### Tests are flaky/unreliable

- Check for timing dependencies
- Add proper cleanup in teardown
- Use mocking/stubbing for external dependencies

## Contributing

When adding new features, include:

1. Unit tests for the feature
2. Integration tests for complete workflows
3. Edge case testing
4. Error path testing
