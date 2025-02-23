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

### Detailed Keymap Overview

| Key Combination      | Mode(s)            | Command/Action                                                       | Description                                      |
|----------------------|--------------------|----------------------------------------------------------------------|--------------------------------------------------|
| `J` (visual)         | Visual             | `:m '>+1<CR>gv=gv`                                                    | Move text down                                   |
| `K` (visual)         | Visual             | `:m '<-2<CR>gv=gv`                                                    | Move text up                                     |
| `<C-d>`              | Normal             | `<C-d>zz`                                                            | Jump down half page and center view              |
| `<C-u>`              | Normal             | `<C-u>zz`                                                            | Jump up half page and center view                |
| `n`                  | Normal             | `nzzzv`                                                              | Go to next match and center view                 |
| `N`                  | Normal             | `Nzzzv`                                                              | Go to previous match and center view             |
| `<A-p>`              | Visual (x)         | `[["_dP]]`                                                          | Paste overwrite without yanking                  |
| `<A-y>`              | Normal/Visual      | `[["+y]]`                                                           | Yank selected text to system clipboard           |
| `<A-S-y>`            | Normal             | `[["+Y]]`                                                           | Yank whole line to system clipboard              |
| `<A-d>`              | Normal/Visual      | `[["_d]]`                                                           | Delete without copying to clipboard              |
| `<C-c>`              | Insert             | `<Esc>`                                                              | Escape/Exit Insert mode                          |
| `Q`                  | Normal             | `<cmd>q<CR>`                                                         | Quit                                             |
| `A-S-q`              | Normal             | `<cmd>tabclose<CR>`                                                  | Close tab                                        |
| `<C-]>`              | Terminal           | `<C-\><C-n>`                                                         | Exit terminal mode                               |
| `<leader>gt`         | Normal             | `<cmd>split <bar> term<CR>`                                           | Toggle terminal                                  |
| `<leader>g=`         | Normal             | `vim.lsp.buf.format`                                                 | Format current file                              |
| `<C-q>`              | Normal             | `<cmd>cclose<CR>`                                                    | Close quickfix window                            |
| `<C-k>`              | Normal             | `<cmd>cnext<CR>zz`                                                    | Next quickfix item                               |
| `<C-j>`              | Normal             | `<cmd>cprev<CR>zz`                                                    | Previous quickfix item                           |
| `<leader>k`          | Normal             | `<cmd>lnext<CR>zz`                                                    | Next POI location                                |
| `<leader>j`          | Normal             | `<cmd>lprev<CR>zz`                                                    | Previous POI location                            |
| `<A-j>`              | Normal/Terminal/Insert | `<C-w>j`                                                          | Jump to bottom pane                              |
| `<A-k>`              | Normal/Terminal/Insert | `<C-w>k`                                                          | Jump to top pane                                 |
| `<A-h>`              | Normal/Terminal/Insert | `<C-w>h`                                                          | Jump to left pane                                |
| `<A-l>`              | Normal/Terminal/Insert | `<C-w>l`                                                          | Jump to right pane                               |
| `<A-t>`              | Normal             | `<C-w>t`                                                            | Jump to top left pane                            |
| `<leader>s`          | Normal             | `:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>`                 | Concurrently replace all matching words          |
| `<leader>ii`         | Normal             | `<cmd>e ~/.config/nvim/lua/plugins/init.lua<CR>`                     | Go to plugins init file                          |
| `<leader>iq`         | Normal             | `<cmd>e ~/notes/quick.md<CR>`                                        | Go to personal quick note file                   |
| `<leader>ic`         | Normal             | `<cmd>e ~/notes/checklist.md<CR>`                                    | Go to personal checklist file                    |
| `<leader>it`         | Normal             | `<cmd>e ~/notes/temp.md<CR>`                                         | Go to personal temp text file                    |
| `<leader>ij`         | Normal             | `<cmd>e ~/notes/journal.md<CR>`                                      | Go to personal journal file                      |
| `<leader>iw`         | Normal             | `<cmd>e ~/notes/wiki.md<CR>`                                         | Go to personal wiki file                         |
| `<leader>ir`         | Normal             | `<cmd>CellularAutomaton make_it_rain<CR>`                            | Run Make It Rain animation                       |
| `<leader>il`         | Normal             | `<cmd>CellularAutomaton game_of_life<CR>`                            | Run Game of Life animation                       |
| `<C-/>`              | Normal             | `builtin.grep_string({ search = vim.fn.input("Grep > ") })`          | Grep string global via Telescope                 |
| `<C-p>`              | Normal             | `builtin.find_files`                                                 | Browse files global via Telescope                |
| `<leader>f`          | Normal             | `builtin.current_buffer_fuzzy_find`                                  | Find string local via Telescope                  |
| `<leader>vf`         | Normal             | `builtin.git_files`                                                  | Find git files global via Telescope              |
| `<leader>vh`         | Normal             | `builtin.help_tags`                                                  | Browse help tags via Telescope                   |
| `<leader>vp`         | Normal             | `builtin.commands`                                                   | Browse commands via Telescope                    |
| `<leader>vk`         | Normal             | `builtin.keymaps`                                                    | Browse keymaps via Telescope                     |
| `<leader>vq`         | Normal             | `builtin.quickfix`                                                   | Browse quickfix items local via Telescope        |
| `<leader>vj`         | Normal             | `builtin.jumplist`                                                   | Browse jumplist global via Telescope             |
| `<leader>vm`         | Normal             | `require("telescope").extensions.metals.commands()`                  | Browse Metals LSP commands                       |
| `<leader>ac`         | Normal             | `builtin.diagnostics`                                                | Browse diagnostics items local via Telescope     |
| `<leader>ar`         | Normal             | `builtin.lsp_references`                                             | Browse LSP References via Telescope              |
| `<leader>as`         | Normal             | `builtin.lsp_document_symbols`                                       | Browse LSP Document Symbols via Telescope        |
| `<leader>aw`         | Normal             | `builtin.lsp_dynamic_workspace_symbols`                              | Browse LSP Dynamic Workspace Symbols global      |
| `<leader>ai`         | Normal             | `builtin.lsp_implementations`                                        | Browse LSP Implementations via Telescope         |
| `<leader>ad`         | Normal             | `builtin.lsp_definitions`                                            | Browse LSP Definitions via Telescope             |
| `<leader>at`         | Normal             | `builtin.lsp_type_definitions`                                       | Browse LSP Type Definitions via Telescope        |
| `<C-x>`              | Normal             | `require("telescope").extensions.smart_open.smart_open()`            | Open smart file picker in Telescope              |
| `<leader>tf`         | Normal             | `neotest.run.run()`                                                  | Test single function                             |
| `<leader>ts`         | Normal             | `neotest.run.stop()`                                                 | Test stop                                        |
| `<leader>tb`         | Normal             | `neotest.run.run(vim.fn.expand("%"))`                                | Test single file                                 |
| `<leader>td`         | Normal             | `neotest.run.run(".")`                                               | Test all from current directory                  |
| `<leader>ta`         | Normal             | `neotest.run.run(vim.fn.getcwd())`                                   | Test whole suite from root dir                   |
| `<leader>tm`         | Normal             | `neotest.summary.toggle()`                                           | Test summary toggle                              |
| `<leader>tn`         | Normal             | `neotest.run.run({ strategy = "dap" })`                              | Debug nearest test                               |
| `<leader>tg`         | Normal             | `<cmd>ConfigureGtest<cr>`                                            | Configure C++ google test                        |
| `<leader>tww`        | Normal             | `neotest.watch.toggle(vim.fn.expand("%"))`                           | Test watch toggle current file                   |
| `<leader>tws`        | Normal             | `neotest.watch.stop("")`                                             | Test watch stop all position                     |
| `<leader>to`         | Normal             | `neotest.output.open({ enter = true })`                              | Test output open                                 |
| `<leader>tp`         | Normal             | `neotest.output_panel.toggle()`                                      | Test output toggle panel                         |
| `<leader>tc`         | Normal             | `neotest.output_panel.clear()`                                       | Test output clear panel                          |
| `<leader>twj`        | Normal             | `neotest.run.run({ jestCommand = "jest --watch " })`                 | Test Jest watch mode                             |
| `<leader>twv`        | Normal             | `neotest.run.run({ vitestCommand = "vitest --watch" })`              | Run Watch                                        |
| `<leader>twf`        | Normal             | `neotest.run.run({ vim.fn.expand(" % "), vitestCommand = "vitest --watch" })` | Run Watch File                                   |
| `<F5>`               | Normal             | `dap.continue`                                                       | Debug: Continue                                  |
| `<F6>`               | Normal             | `dap.step_over`                                                      | Debug: Step over                                 |
| `<F7>`               | Normal             | `dap.step_into`                                                      | Debug: Step into                                 |
| `<F8>`               | Normal             | `dap.step_out`                                                       | Debug: Step out                                  |
| `<F9>`               | Normal             | `function() dap.disconnect({ terminateDebuggee = true }); dap.close() end` | Debug: Stop                                      |
| `<leader>b`          | Normal             | `dap.toggle_breakpoint`                                              | Debug: Toggle breakpoint                         |
| `<leader>B`          | Normal             | `dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))`         | Debug: Set breakpoint condition                  |
| `<leader>ap`         | Normal             | `dap.set_breakpoint(nil, nil, vim.fn.input("Log point message: "))`  | Debug: Set log point message                     |
| `<leader>el`         | Normal             | `dap.run_last`                                                       | Debug: Run last session                          |
| `<leader>er`         | Normal             | `dap.repl.open`                                                      | Debug: Open REPL                                 |
| `<leader>et`         | Normal             | `require("dap-go").debug_test`                                       | Debug golang test                                |
| `<leader>ee`         | Normal             | `require("dapui").eval(nil, { enter = true })`                       | Debug evaluate expression                        |
| `<leader>h`          | Normal             | `harpoon:list():add()`                                               | Add current location to Harpoon list             |
| `<C-z>`              | Normal             | `harpoon.ui:toggle_quick_menu(harpoon:list())`                       | Toggle Harpoon interactive list                  |
| `<C-a>`              | Normal             | `harpoon:list():select(1)`                                           | Go to 1st Harpoon location                       |
| `<C-s>`              | Normal             | `harpoon:list():select(2)`                                           | Go to 2nd Harpoon location                       |
| `<C-n>`              | Normal             | `harpoon:list():select(3)`                                           | Go to 3rd Harpoon location                       |
| `<C-m>`              | Normal             | `harpoon:list():select(4)`                                           | Go to 4th Harpoon location                       |
| `<C-A-P>`            | Normal             | `harpoon:list():prev()`                                              | Go to next Harpoon location                      |
| `<C-A-N>`            | Normal             | `harpoon:list():next()`                                              | Go to previous Harpoon location                  |
| `<leader>re`         | Visual             | `refactoring.refactor("Extract Function")`                           | Refactor extract function                        |
| `<leader>rf`         | Visual             | `refactoring.refactor("Extract Function To File")`                   | Refactor extract function to file                |
| `<leader>rv`         | Visual             | `refactoring.refactor("Extract Variable")`                           | Refactor extract variable                        |
| `<leader>rI`         | Normal             | `refactoring.refactor("Inline Function")`                            | Refactor inline function                         |
| `<leader>ri`         | Normal/Visual      | `refactoring.refactor("Inline Variable")`                            | Refactor inline variable                         |
| `<leader>rb`         | Normal             | `refactoring.refactor("Extract Block")`                              | Refactor extract block                           |
| `<leader>rB`         | Normal             | `refactoring.refactor("Extract Block To File")`                      | Refactor extract block to file                   |
| `<leader>rd`         | Normal/Visual      | `refactoring.debug.print_var()`                                      | Refactor debug print var                         |
| `<leader>rD`         | Normal             | `refactoring.debug.printf({ below = false })`                        | Refactor debug printf                            |
| `<leader>rc`         | Normal             | `refactoring.debug.cleanup({})`                                      | Refactor debug cleanup                           |
| `<leader>rt`         | Normal/Visual      | `refactoring.select_refactor()`                                      | Refactor select native thing                     |
| `<leader>rr`         | Normal/Visual      | `require("telescope").extensions.refactoring.refactors()`            | Refactor select operations via Telescope         |
| `<leader>u`          | Normal             | `vim.cmd.UndotreeToggle`                                             | Toggle undo tree                                 |
| `<leader>gs`         | Normal             | `vim.cmd.Git`                                                        | Open git fugitive                                |
| `<leader>gh`         | Normal             | `<cmd>DiffviewFileHistory<cr>`                                       | Open history current branch                      |
| `<leader>gf`         | Normal             | `<cmd>DiffviewFileHistory %<cr>`                                     | Open history current file                        |
| `<leader>gd`         | Normal             | `<cmd>DiffviewOpen<cr>`                                              | Open diff current index                          |
| `<leader>gm`         | Normal             | `<cmd>DiffviewOpen origin/main...HEAD<cr>`                           | Open diff main                                   |
| `<leader>gc`         | Normal             | `<cmd>DiffviewClose<cr>`                                             | Close diff view                                  |
| `zR`                 | Normal             | `require("ufo").openAllFolds`                                        | Open all folds                                   |
| `zM`                 | Normal             | `require("ufo").closeAllFolds`                                       | Close all folds                                  |
| `-`                  | Normal             | `<CMD>Oil<CR>`                                                       | Open parent directory                            |
| `<space>-`           | Normal             | `require("oil").toggle_float`                                        | Open parent directory in floating window         |
| `<leader>tr`         | Normal             | `<cmd>Markview Toggle<cr>`                                           | Toggle Render Markdown                           |
| `<leader>nh`         | Normal             | `noice.cmd("history")`                                               | Noice history                                    |
| `<leader>nl`         | Normal             | `noice.cmd("last")`                                                  | Noice last                                       |
| `<leader>nd`         | Normal             | `noice.cmd("dismiss")`                                               | Noice dismiss                                    |
| `<leader>ne`         | Normal             | `noice.cmd("errors")`                                                | Noice errors                                     |
| `<leader>nq`         | Normal             | `noice.cmd("disable")`                                               | Noice disable                                    |
| `<leader>nb`         | Normal             | `noice.cmd("enable")`                                                | Noice enable                                     |
| `<leader>ns`         | Normal             | `noice.cmd("stats")`                                                 | Noice debugging stats                            |
| `<leader>nt`         | Normal             | `noice.cmd("telescope")`                                             | Noice open messages in Telescope                 |
| `<S-Enter>`          | Command            | `noice.redirect(vim.fn.getcmdline())`                                | Redirect Cmdline                                 |
| `<c-f>`              | Normal/Insert/Select | `require("noice.lsp").scroll(4)`                                    | LSP hover doc scroll up                          |
| `<c-b>`              | Normal/Insert/Select | `require("noice.lsp").scroll(-4)`                                   | LSP hover doc scroll down                        |

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
