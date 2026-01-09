# Architecture

Technical architecture of the dotfiles system.

## Core Principle

**.sh scripts are the single source of truth.** All core logic lives in bash scripts (*.sh).

**.ps1 scripts are thin compatibility wrappers.** On Windows, PowerShell scripts invoke their .sh counterparts via Git Bash, providing a native Windows experience while maintaining a single implementation.

**Exception:** `bootstrap.ps1` has a Windows-native bootstrap (`bootstrap/bootstrap.ps1`) invoked first on Windows for better platform integration.

## System Architecture

```mermaid
graph TB
    subgraph "Windows 11"
        PS[PowerShell 7+]
        PS1[script.ps1<br/>Wrapper]
        GB[Git Bash]
        SH[script.sh<br/>Core Logic]

        PS -->|invokes| PS1
        PS1 -->|calls via| GB
        GB -->|executes| SH

        PS1 -.->|parameter mapping| GB
        SH -.->|output| PS1
    end

    subgraph "Linux / macOS"
        BS[Bash / Zsh]
        SH2[./script.sh<br/>Core Logic]

        BS -->|direct execution| SH2
    end

    SH <===>|single implementation| SH2

    style SH fill:#90EE90
    style SH2 fill:#90EE90
    style PS1 fill:#FFD700
    style GB fill:#87CEEB
```

## Bootstrap Flow

```mermaid
flowchart TD
    START([User runs bootstrap]) --> DETECT{Detect Platform}

    DETECT -->|Windows| WIN{Git installed?}
    DETECT -->|Linux| LINUX[bootstrap/bootstrap.sh]
    DETECT -->|macOS| MACOS[bootstrap/bootstrap.sh]

    WIN -->|No| INSTALL[Install Git via winget]
    WIN -->|Yes| CHECK{Windows-native<br/>bootstrap available?}
    INSTALL --> CHECK

    CHECK -->|Yes| NATIVE[bootstrap/bootstrap.ps1<br/>Windows-native]
    CHECK -->|No| FALLBACK[bootstrap/bootstrap.sh<br/>via Git Bash]

    NATIVE --> PHASES[Phase 1-7:<br/>Foundation -> SDKs -> LSPs<br/>-> Linters -> CLI Tools<br/>-> MCP Servers -> Deploy]
    FALLBACK --> PHASES
    LINUX --> PHASES
    MACOS --> PHASES

    PHASES --> DEPLOY[Run deploy.sh]
    DEPLOY --> UPDATE[Run update-all.sh]
    UPDATE --> DONE([Deployment Complete])

    style NATIVE fill:#87CEEB
    style FALLBACK fill:#FFD700
    style PHASES fill:#90EE90
    style DONE fill:#98FB98
```

## Configuration Priority

```mermaid
graph TD
    INPUT([User runs script]) --> FLAGS{Command-line<br/>flags present?}

    FLAGS -->|Yes| USE_FLAGS[Use command-line values]
    FLAGS -->|No| CONFIG{Config file<br/>exists?}

    CONFIG -->|Yes| USE_CONFIG[Use ~/.dotfiles.config.yaml]
    CONFIG -->|No| DEFAULTS[Use hardcoded defaults]

    USE_FLAGS --> EXECUTE
    USE_CONFIG --> EXECUTE
    DEFAULTS --> EXECUTE

    EXECUTE([Execute with settings])

    style USE_FLAGS fill:#90EE90
    style USE_CONFIG fill:#87CEEB
    style DEFAULTS fill:#FFD700
```

## Platform-Specific Deployment

```mermaid
graph TB
    subgraph "Windows"
        PWSH[PowerShell Profile]
        ONE{OneDrive<br/>Documents?}
        DOCS[Documents/PowerShell]
        ONE -->|Yes| ONE_DOCS[OneDrive/Documents/PowerShell]
        ONE -->|No| DOCS
    end

    subgraph "Linux"
        ZSH[Zshrc]
    end

    subgraph "macOS"
        ZSH2[Zshrc]
        BREW[Homebrew packages]
    end

    subgraph "All Platforms"
        BASH[.bash_aliases]
        GITCONFIG[.gitconfig]
        NVIM[Neovim config]
        HOOKS[Git hooks]
        CLAUDE[Claude Code hooks]
    end

    style BASH fill:#87CEEB
    style GITCONFIG fill:#87CEEB
    style NVIM fill:#87CEEB
    style HOOKS fill:#FFD700
    style CLAUDE fill:#FFD700
```

## Script Execution Flow (Windows)

```mermaid
sequenceDiagram
    participant User
    participant PS as PowerShell
    participant Wrapper as script.ps1
    participant GB as Git Bash
    participant Core as script.sh

    User->>PS: .\script.ps1 -Params
    PS->>Wrapper: Invoke with parameters

    Note over Wrapper: Convert parameters to bash format
    Wrapper->>Wrapper: Convert Windows paths to Git Bash format

    Wrapper->>GB: bash script.sh --converted-params
    GB->>Core: Execute core logic

    Core-->>GB: Exit code & output
    GB-->>Wrapper: Return results
    Wrapper-->>PS: Convert output for PowerShell
    PS-->>User: Display results
```

## Benefits

- Single implementation to maintain and test
- .sh scripts work natively on Linux/macOS and via Git Bash on Windows
- .ps1 wrappers provide Windows convenience with familiar parameter names
- All features develop in .sh first, then automatically available on Windows
- Windows-native bootstrap provides better platform integration

## Line Endings

The repository uses `.gitattributes` to enforce LF line endings for shell scripts and CRLF for PowerShell scripts. Git is configured during bootstrap to maintain these conventions.

## Git Installation (Windows)

On Windows, Git (including Git Bash) is automatically installed via winget during bootstrap. No manual installation required.
