# Neovim IDE Setup 🚀✨

Welcome to the **Neovim IDE Setup** repository! Transform your Neovim into a powerful, cross-platform IDE with a sleek configuration and an inspiring
development experience. Enjoy enhanced multi-language support, smart tools, and a streamlined workflow.

## Overview 📖

This setup converts Neovim into a full-featured IDE for languages like Lua, Go, JavaScript/TypeScript, Python, C/C++, Rust, Java, and more. With integrated
LSP, debugging, testing, and rich customization options, you can boost your productivity effortlessly.

## Installation 🔧

### Prerequisites

- **Neovim Nightly/Prerelease (v0.11+).**
- Essential tools: Git, GH CLI, GCC/LLVM, Go, NodeJS, Python3, Rust, Lua, etc.
- System tweaks: Increase file watchers and open file limits.

### Linux Setup

1.  **System Setup:**
    - **WiFi Power Save:**
      ```bash
      sudo vi /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf
      ```
      Set:
      ```
      [connection]
      wifi.powersave = 2
      ```
    - **Restart NetworkManager:**
      ```bash
      sudo systemctl restart NetworkManager
      ```
    - **File Limits & Inotify Watches:**
      Edit `/etc/systemd/system.conf` to set:
      ```
      DefaultLimitNOFILE=4096:2097152
      ```
      Then run:
      ```bash
      sudo sysctl fs.inotify.max_user_watches=2097152 && sudo systemctl daemon-reexec
      ```
2.  **File Setup:**
    - Copy your configuration files (e.g. `.bashrc`, `.bash_aliases`, `.gitconfig`) to your home directory.
    - Place the `assets` folder and set up `wezterm.lua` in `~/.config/wezterm/`.
    - Run `git-clone-all.sh` in your development folder.
    - Configure API keys in `.aider.conf.yml` and `.aider.model.metadata.json`.
3.  **Finalize:**
    - **Reboot** your system.
    - Open Neovim (`nvim`) and allow plugins to auto-install.

### Windows Setup

Follow the original Windows instructions for environment adjustments, package installations, and file configurations.

## Features 💡

- **Multi-Language Support:** Lua, Go, JS/TS, Python, C/C++, Rust, Java, and more.
- **Integrated IDE Tools:** Virtual LSP, debugging, testing frameworks, code actions, and snippet management.
- **Streamlined Workflow:** Custom keybindings, Git integration, and an intuitive UI.
- **Customization:** Pre-configured themes (Gruvbox, Tokyo Night, Pine Rose) with flexible plugin management.

## Key Bindings ⌨️

Key mappings (defined in `lua/config/remap.lua`) include:

- `<leader>vk`: Open keymap overview via Telescope.
- `<A-y>`: Yank selection to the system clipboard.
- `<leader>gt`: Toggle the integrated terminal.
- Additional bindings for LSP, debugging, and testing features.

## Plugins & Tools 🔌

The configuration integrates over 80 plugins, such as:

- **LSP & Coding:** `lsp-zero.nvim`, `nvim-lspconfig`
- **Navigation:** `telescope.nvim`, `oil.nvim`, `harpoon`
- **Debugging & Testing:** `nvim-dap`, `neotest`
- **UI Enhancements:** `noice.nvim`, `lualine.nvim`

## Resources & References 📚

- **Video Tutorials:**
  - [0 to LSP](https://youtu.be/w7i4amo_zae) 🎥
  - [Zero to IDE](https://youtu.be/n93ctbtlcim) 🎥
- **Guides & Repositories:**
  - [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim)
  - [ThePrimeagen's init.lua](https://github.com/theprimeagen/init.lua)
  - [tjdevries/config.nvim](https://github.com/tjdevries/config.nvim)

## License 📄

See the [LICENSE](LICENSE) file for details.
