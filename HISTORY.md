# Legacy Museum

Files and directories kept in the repository for historical reference but no longer actively used. They represent earlier approaches and tools that have been superseded by better alternatives or are now obsolete.

**Note**: These files remain in the repository but are not deployed or used by current scripts. They are preserved for reference purposes only.

This repository has a **rich 3-year history** spanning from June 2023 to January 2026, evolving through multiple major iterations and architectural changes.

## Legacy Files

| File/Directory | First Commit | Last Commit | Era | Why Deprecated |
|----------------|--------------|-------------|-----|----------------|
| **git-clone-all.sh** | `7a17cb5` (2023-06-03) | `749d333` (2023-06-04) | **2023** | Superseded by `git-update-repos.sh` which handles both cloning and updating |
| **assets/** | `3435adb` (2023-06-17) | `5206cde` (2024-07-29) | **2023-2024** | Embedded wallpapers moved to Wezterm config; cheatsheets now maintained separately |
| **typos.toml** | `6bb44e6` (2024-06-10) | `ef8f83d` (2025-02-23) | **2024-2025** | Typos integration removed; spell checking now handled by LSPs |
| **update.sh** | `e06937e` (2025-02-26) | `dca651f` (2025-02-28) | **2025** | Superseded by modular `update-all.sh` supporting 20+ package managers |
| **.aider.conf.yml.example** | `eb3108b` (2025-03-01) | `2899ff7` (2025-03-01) | **2025** | Aider config now managed per-project; example no longer needed globally |
| **.aider.model.settings.yml** | `e06937e` (2025-02-26) | `db0afd9` (2025-03-02) | **2025** | Model settings now project-specific; global config deprecated |

## Notes on Legacy Files

### git-clone-all.sh (2.5 years old)
- Based on a gist by Dave Gallant
- Used `gh repo list` and `gh repo clone` to mirror organizations
- Last update: `749d333` on June 4, 2023
- `git-update-repos.sh` provides better functionality with idempotent updates

### assets/ (3.5 MB, 1.5 years old)
- `Buddha-and-animals.png` - Wezterm background (added `5206cde`, July 29, 2024)
- `fantasy-forest-wallpaper.jpg` - Alternative background
- `tokyo-sunset.jpeg` - Alternative background (added `eae3d48`, July 29, 2024)
- First wallpapers embedded: `3435adb` on June 17, 2023
- These were embedded directly in the repo before Wezterm switched to system paths

### typos.toml (8 months old)
- Custom words: "noice" (Neovim plugin), "nd" (common typo)
- Created: `6bb44e6` on June 10, 2024
- Last update: `ef8f83d` on Feb 23, 2025 (Ubuntu 24.10 refactor)

### update.sh (10 months old)
- Early update script for system packages
- Created: `e06937e` on Feb 26, 2025
- Last commit: `dca651f` on Feb 28, 2025
- Superseded by modular `update-all.sh` supporting 20+ package managers

### Aider Configuration (10 months old)
- Aider is an AI pair programming tool that edits local repos
- `.aider.conf.yml.example`: Created `eb3108b`, last updated `2899ff7` (March 1, 2025)
- `.aider.model.settings.yml`: Created `e06937e`, last updated `db0afd9` (March 2, 2025)
- The example config showed how to use o3-mini and Claude 3.7 Sonnet
- Project-specific configuration is now preferred over global settings
