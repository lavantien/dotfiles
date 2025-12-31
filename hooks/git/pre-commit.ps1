# Universal git pre-commit hook - PowerShell version for Windows native
# Auto-detects project type and runs appropriate checks
# Supported: Go, Rust, C/C++, JavaScript/TypeScript, Python, C#, Java, Scala, PHP

$ErrorActionPreference = 'Continue'

$projectRoot = git rev-parse --show-toplevel 2>$null
if (!$projectRoot) {
    $projectRoot = Get-Location
}

Set-Location $projectRoot

# Colors
$E = [char]27
$R = "$E[0m"
$GREEN = "$E[32m"
$YELLOW = "$E[33m"
$BLUE = "$E[34m"
$CYAN = "$E[36m"
$RED = "$E[31m"

Write-Host "${BLUE}Pre-commit checks...${R}"

$failed = $false

# ============================================================================
# PROJECT TYPE DETECTION
# ============================================================================
function Get-ProjectTypes {
    $types = @()
    Push-Location $projectRoot

    # Check from root
    if (Test-Path "go.mod") { $types += "go" }
    if (Test-Path "Cargo.toml") { $types += "rust" }
    if (Test-Path "package.json") { $types += "node" }
    if (Test-Path "pyproject.toml") { $types += "python" }
    if (Test-Path "requirements.txt") { $types += "python" }
    if (Test-Path "setup.py") { $types += "python" }
    if (Test-Path "poetry.lock") { $types += "python" }

    $csFiles = Get-ChildItem -Filter "*.cs" -Recurse -Depth 3 -ErrorAction SilentlyContinue | Measure-Object
    if ($csFiles.Count -gt 0) { $types += "csharp" }

    if (Test-Path "pom.xml") { $types += "java" }
    if (Test-Path "build.gradle") { $types += "java" }
    if (Test-Path "build.gradle.kts") { $types += "java" }
    if (Test-Path "build.sbt") { $types += "scala" }
    if (Test-Path "composer.json") { $types += "php" }

    # Check common subdirectories
    if ((Test-Path "frontend") -and (Test-Path "frontend\package.json")) { $types += "node-frontend" }
    if ((Test-Path "backend") -and ((Get-ChildItem -Path "backend" -Filter "*.cs" -Recurse -Depth 3 -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0)) { $types += "csharp-backend" }

    Pop-Location
    return $types
}

$projects = Get-ProjectTypes
if ($projects.Count -eq 0) {
    Write-Host "${YELLOW}No recognized project type found.${R}"
    exit 0
}

# ============================================================================
# LANGUAGE-SPECIFIC CHECKS
# ============================================================================

# === GO ===
function Invoke-GoChecks {
    Write-Host "`n${YELLOW}=== Go ===${R}"
    $staged = git diff --cached --name-only --diff-filter=ACM | Select-String '\.go$' || return
    if (!$staged) { return }

    # Format: gofmt
    if (Get-Command goimports -ErrorAction SilentlyContinue) {
        Write-Host "Running goimports..."
        $staged | ForEach-Object { goimports -w $_ 2>$null }
    } else {
        Write-Host "Running go fmt..."
        go fmt ./...
    }
    git add $staged 2>$null

    # Lint: golangci-lint
    if (Get-Command golangci-lint -ErrorAction SilentlyContinue) {
        Write-Host "Running golangci-lint..."
        golangci-lint run --no-config ./... 2>$null
    }

    # Type check: go vet
    Write-Host "Running go vet..."
    go vet ./... 2>$null
}

# === RUST ===
function Invoke-RustChecks {
    Write-Host "`n${YELLOW}=== Rust ===${R}"
    $staged = git diff --cached --name-only --diff-filter=ACM | Select-String '\.rs$' | Select-Object -First 20
    if (!$staged) { return }

    # Format: cargo fmt
    Write-Host "Running cargo fmt..."
    if (!(cargo fmt --check 2>$null)) {
        cargo fmt 2>$null
        git add $staged 2>$null
        Write-Host "${YELLOW}Files formatted. Please review.${R}"
    }

    # Lint: cargo clippy
    Write-Host "Running cargo clippy..."
    cargo clippy --quiet -- -D warnings 2>$null

    # Type check: cargo check
    cargo check 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "${RED}Cargo check failed.${R}"
        $script:failed = $true
    }
}

# === C/C++ ===
function Invoke-CChecks {
    Write-Host "`n${YELLOW}=== C/C++ ===${R}"
    $staged = git diff --cached --name-only --diff-filter=ACM | Select-String '\.(c|h|cpp|hpp|cc|cxx)$'
    if (!$staged) { return }

    # Format: clang-format
    if (Get-Command clang-format -ErrorAction SilentlyContinue) {
        Write-Host "Running clang-format..."
        $staged | ForEach-Object {
            if (Test-Path $_) {
                clang-format -i $_ 2>$null
                git add $_ 2>$null
            }
        }
    }

    # Lint: clang-tidy
    if ((Get-Command clang-tidy -ErrorAction SilentlyContinue) -and (Test-Path "compile_commands.json")) {
        Write-Host "Running clang-tidy..."
        $staged | ForEach-Object {
            if (Test-Path $_) { clang-tidy $_ 2>$null }
        }
    }

    # Lint: cppcheck
    if (Get-Command cppcheck -ErrorAction SilentlyContinue) {
        Write-Host "Running cppcheck..."
        cppcheck --enable=all --error-exitcode=1 $staged 2>$null
    }
}

# === JAVASCRIPT/TYPESCRIPT ===
function Invoke-NodeChecks {
    Write-Host "`n${YELLOW}=== JavaScript/TypeScript ===${R}"

    # Check if node_modules exists
    if (!(Test-Path "node_modules")) { return }

    # Format: Prettier
    if ((Get-Command npx -ErrorAction SilentlyContinue) -or (Test-Path "node_modules\.bin\prettier.cmd")) {
        Write-Host "Running Prettier..."
        # Only use svelte plugin if actually installed
        $prettierArgs = ""
        if ((Test-Path "node_modules\prettier-plugin-svelte\index.js") -or (Test-Path "node_modules\prettier-plugin-svelte\dist\index.js")) {
            $prettierArgs = "--plugin=prettier-plugin-svelte"
        }
        $null = npx prettier --check . $prettierArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            npx prettier --write . $prettierArgs 2>&1 | Select-Object -First 5
            git add . 2>$null
            Write-Host "${YELLOW}Files formatted with Prettier.${R}"
        }
    }

    # Lint: ESLint
    if ((Get-Command npx -ErrorAction SilentlyContinue) -or (Test-Path "node_modules\.bin\eslint.cmd")) {
        Write-Host "Running ESLint..."
        npx eslint . 2>&1 | Select-Object -First 20
        if ($LASTEXITCODE -gt 0) {
            Write-Host "${RED}ESLint errors found.${R}"
            $script:failed = $true
        }
    }

    # Type check: tsc / svelte-check
    $packageJson = Get-Content "package.json" -Raw
    if ($packageJson -match '"check"') {
        Write-Host "Running type check..."
        $checkResult = npm run check --silent 2>&1
        if ($checkResult -match "\berror\b") {
            Write-Host "${RED}Type check failed.${R}"
            $script:failed = $true
        }
    } elseif ((Test-Path "tsconfig.json") -and (Get-Command npx -ErrorAction SilentlyContinue)) {
        Write-Host "Running tsc..."
        npx tsc --noEmit 2>$null
    }
}

# === PYTHON ===
function Invoke-PythonChecks {
    Write-Host "`n${YELLOW}=== Python ===${R}"
    $staged = git diff --cached --name-only --diff-filter=ACM | Select-String '\.py$|pyproject\.toml'
    if (!$staged) { return }

    # Format/Lint: ruff
    if (Get-Command ruff -ErrorAction SilentlyContinue) {
        Write-Host "Running ruff format..."
        ruff format --check . 2>$null
        if ($LASTEXITCODE -ne 0) {
            ruff format . 2>$null
            git add $staged 2>$null
        }

        Write-Host "Running ruff check..."
        ruff check . 2>$null
        if ($LASTEXITCODE -ne 0) {
            ruff check --fix . 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "${YELLOW}Ruff found issues.${R}"
            }
        }
    }

    # Format: black (fallback)
    if (!(Get-Command ruff -ErrorAction SilentlyContinue)) {
        if (Get-Command black -ErrorAction SilentlyContinue) {
            Write-Host "Running black..."
            black --check $staged 2>$null
            if ($LASTEXITCODE -ne 0) {
                black $staged 2>$null
                git add $staged 2>$null
            }
        }

        # Import sort: isort
        if (Get-Command isort -ErrorAction SilentlyContinue) {
            Write-Host "Running isort..."
            isort --check-only $staged 2>$null
            if ($LASTEXITCODE -ne 0) {
                isort $staged 2>$null
                git add $staged 2>$null
            }
        }
    }

    # Type check: mypy
    if (Get-Command mypy -ErrorAction SilentlyContinue) {
        Write-Host "Running mypy..."
        mypy $staged 2>$null
    }
}

# === C# ===
function Invoke-CSharpChecks {
    Write-Host "`n${YELLOW}=== C# ===${R}"
    $staged = git diff --cached --name-only --diff-filter=ACM | Select-String '\.(cs|csproj)$'
    if (!$staged) { return }

    if (!(Get-Command dotnet -ErrorAction SilentlyContinue)) { return }

    # Find solution or project files
    $sln = Get-ChildItem -Filter "*.sln" -Recurse -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1

    # Format: dotnet format
    Write-Host "Running dotnet format..."
    if ($sln) {
        dotnet format $sln.Name 2>$null
    } else {
        Get-ChildItem -Filter "*.csproj" -Recurse | ForEach-Object { dotnet format $_.Name 2>$null }
    }
    git add backend\, src\, *.csproj 2>$null

    # Type check: dotnet build
    $assetsFile = Get-ChildItem -Recurse -Filter "project.assets.json" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($sln -and $assetsFile) {
        Write-Host "Running dotnet build..."
        $buildResult = dotnet build $sln.Name --no-restore --verbosity quiet 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "${RED}Dotnet build failed.${R}"
            $script:failed = $true
        }
    }
}

# === JAVA ===
function Invoke-JavaChecks {
    Write-Host "`n${YELLOW}=== Java ===${R}"

    # Format: spotless
    if ((Test-Path "pom.xml") -and (Get-Command mvn -ErrorAction SilentlyContinue)) {
        $pomXml = Get-Content "pom.xml" -Raw
        if ($pomXml -match "spotless") {
            Write-Host "Running spotless check..."
            mvn spotless:check 2>$null
            if ($LASTEXITCODE -ne 0) {
                mvn spotless:apply 2>$null
                git add . 2>$null
            }
        }
    }

    # Format: google-java-format
    if (Get-Command google-java-format -ErrorAction SilentlyContinue) {
        Write-Host "Running google-java-format..."
        google-java-format --replace 2>$null
    }

    # Lint: checkstyle
    if ((Test-Path "pom.xml") -and (Get-Command mvn -ErrorAction SilentlyContinue)) {
        Write-Host "Running checkstyle..."
        mvn checkstyle:check 2>$null
    }
}

# === SCALA ===
function Invoke-ScalaChecks {
    Write-Host "`n${YELLOW}=== Scala ===${R}"

    if (Get-Command scalafmt -ErrorAction SilentlyContinue) {
        Write-Host "Running scalafmt..."
        scalafmt --non-interactive 2>$null
    }

    if ((Test-Path "build.sbt") -and (Get-Command sbt -ErrorAction SilentlyContinue)) {
        Write-Host "Running sbt compile..."
        sbt compile 2>$null
    }
}

# === PHP ===
function Invoke-PhpChecks {
    Write-Host "`n${YELLOW}=== PHP ===${R}"
    $staged = git diff --cached --name-only --diff-filter=ACM | Select-String '\.php$'
    if (!$staged) { return }

    # Format: Laravel Pint
    if (Test-Path "vendor\bin\pint") {
        Write-Host "Running Laravel Pint..."
        .\vendor\bin\pint --test 2>$null
        if ($LASTEXITCODE -ne 0) {
            .\vendor\bin\pint 2>$null
            git add $staged 2>$null
        }
    }

    # Format: php-cs-fixer
    if (Test-Path "vendor\bin\php-cs-fixer") {
        Write-Host "Running php-cs-fixer..."
        .\vendor\bin\php-cs-fixer fix --dry-run 2>$null
        if ($LASTEXITCODE -ne 0) {
            .\vendor\bin\php-cs-fixer fix 2>$null
            git add $staged 2>$null
        }
    }

    # Type check: PHPStan
    if (Test-Path "vendor\bin\phpstan") {
        Write-Host "Running PHPStan..."
        .\vendor\bin\phpstan analyse --memory-limit=1G 2>$null
    }

    # Type check: Psalm
    if (Test-Path "vendor\bin\psalm") {
        Write-Host "Running Psalm..."
        .\vendor\bin\psalm --show-info=false 2>$null
    }
}

# ============================================================================
# RUN CHECKS FOR DETECTED PROJECTS
# ============================================================================
foreach ($project in $projects) {
    switch ($project) {
        "go" { Invoke-GoChecks }
        "rust" { Invoke-RustChecks }
        "c" { Invoke-CChecks }
        "cpp" { Invoke-CChecks }
        "node" { Invoke-NodeChecks }
        "node-frontend" {
            Push-Location frontend
            Invoke-NodeChecks
            Pop-Location
        }
        "python" { Invoke-PythonChecks }
        "csharp" { Invoke-CSharpChecks }
        "csharp-backend" {
            Push-Location backend
            Invoke-CSharpChecks
            Pop-Location
        }
        "java" { Invoke-JavaChecks }
        "scala" { Invoke-ScalaChecks }
        "php" { Invoke-PhpChecks }
    }
}

# ============================================================================
# RESULT
# ============================================================================
if ($failed) {
    Write-Host "`n${RED}Pre-commit checks failed. Fix issues or use --no-verify to bypass.${R}"
    exit 1
}

Write-Host "${GREEN}All checks passed!${R}"
exit 0
