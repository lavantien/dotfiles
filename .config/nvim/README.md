# Neovim Cross-Platform Full IDE Minimal Setup From Scratch

## Install

- Git, GH CLI, Neovim, GCC/LLVM-Clang, Go, NodeJS, Python3, Rust, Lua, Android/React Native, Java, Coursier/Scala, SQLite, Docker, K8s, OpenTf
- Neovim Deps; then [integrate ripgrep-all and fzf](https://github.com/phiresky/ripgrep-all/wiki/fzf-Integration), put the file in `~/.local/bin` and add the folder to `PATH`

```bash
cargo install sccache && cargo install coreutils && npm i -g neovim \
&& mkdir -p ~/notes
```

<details>
    <summary>If you're on Windows you need to (expand)</summary>

- remove `make install_jsregexp` from `luasnip` build config
- remove `checkmake`, `luacheck`, `semgrep`, `ansible-lint`, or other packages that don't support Windows from `mason-tools-installer` list
- set the `HOME` environment variable to `C:\Users\<name>`; create `notes` folder in home
- copy `.config/nvim/` directory to `C:\Users\<name>\AppData\Local\`
- copy from `[init] to [pull]` inside `.gitconfig` to your config file location (`git config --list --show-origin --show-scope`)
- copy `./typos.toml` file to `~/`
- add to `PATH` this value `C:\Users\<name>\AppData\Local\nvim-data\mason\bin`
- set the `RUSTC_WRAPPER` env var to `C:\Users\<name>\.cargo\bin\sccache.exe`
- install [sqlite3](https://gist.github.com/zeljic/d8b542788b225b1bcb5fce169ee28c55), rename `sqlite3.dll` to `libsqlite3.dll` and `sqlite3.lib` to `libsqlite3.lib`, and add its location to`PATH`
- Install `Android Studio`, [Android SDK](https://reactnative.dev/docs/set-up-your-environment), and [coursier/scala](https://www.scala-lang.org/download/)
- Install all packages via [winget](https://winget.run/) if possible, then use `scoop install`, `cargo install`, `go install`, and `choco install` (requires admin shell) in this order
  - `winget source reset --force` in admin shell
  - `winget upgrade --all --unknown-sources` and `choco upgrade all -y` to mass update all packages
  - `winget install gsudo TheDocumentFoundation.LibreOffice Git.Git GitHub.cli Docker.DockerDesktop GoLang.Go OpenJS.NodeJS Amazon.Corretto Rustlang.Rustup ajeetdsouza.zoxide wez.wezterm JesseDuffield.lazygit JesseDuffield.Lazydocker`
  - `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` and `Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression`
  - `scoop install btop-lhm`
  - `choco install vifm`
  - `cargo install cargo-update`, `go install github.com/Gelio/go-global-update@latest`
- Install additional packages yourself if there are something missing, be mindful of adding the `env vars`
- Create `~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1` (`$profile`) and add these lines to it, then install [ohmyposh](https://ohmyposh.dev/docs/installation/windows):

```powershell
Invoke-Expression (& { (zoxide init powershell | Out-String) })
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\half-life.omp.json" | Invoke-Expression

# aliases
Set-Alias -Name n -Value nvim
Set-Alias -Name vi -Value vim
Set-Alias -Name g -Value git
Set-Alias -Name d -Value docker
Set-Alias -Name lg -Value lazygit
Set-Alias -Name ld -Value lazydocker
Set-Alias -Name df -Value difft
Set-Alias -Name e -Value eza
Set-Alias -Name v -Value vifm
Set-Alias -Name f -Value fzf
Set-Alias -Name r -Value rg
Set-Alias -Name ff -Value ffmpeg
Set-Alias -Name b -Value bat
Set-Alias -Name t -Value tokei
Set-Alias -Name r -Value rg
Set-Alias -Name rs -Value rsync
Set-Alias -Name cu -Value coreutils
Set-Alias -Name j -Value just
Set-Alias -Name h -Value hyperfine
```

```powershell
cargo install-update -a && npm -g update && go-global-update && winget upgrade --all -u && scoop update
```

- `choco upgrade all -y` (in admin shell) to mass update all packages

</details>

- Run `nvim` the first time and wait for it to auto initialize plugins, then press `S` to sync packages
- Run `:MasonUpdate` to install all registries, then `:Mason` and press `U` if there's any update
- All language `servers`, `linters`, and `treesitters` are pre-installed when you first initialize Neovim
- Make sure to run `$ nvim +che` to ensure all related dependencies are installed

## Features

- Fully support lua, go, javascript/typescript & vue, html/htmx & css/tailwind, python, c/cpp, rust, java, scala, assembly, markdown, latex & typos, bash, make & cmake, json, yaml, toml, sql, protobuf, graphql, docker/compose, ci/cd, kubernetes/helm, ansible, opentofu
- Intellisense, Code Actions, Debugging, Testing, Diff View, Snippets, Hints, Code Objects, Pin Headers, Display Statuses, Token Tree, Fuzzy Picker
- Surround, Autotag, Improved Floating UIs, Toggle Term, Notifications, Inline Diagnostics, Inline Eval, Statusbar, Multifiles Jumper, Refactoring, Clues
- Smart Folds, Autolint, Notes Taking, Indentation Guides, Smart Help, Undo Tree, Git Integration, SQL/NoSQL Client, File Explorer, Cellular Automaton
- Optimized Keymaps, Schemas Store, Highlight Patterns, Pre-setup 3 themes - `Gruvbox`, `Tokyo Night`, `Pine Rose`

## Key Bindings

- Key clue support, just hit any key and a popup will appear to guide you
- Or via Telescope `<leader>vk`; the `<leader>i` group is for quick notes and mini games
- In Neovim Normal Mode, hit `:nmap` to see the list of all bindings
- Check `~/.config/nvim/lua/config/remap.lua` for detailed information

<details>
    <summary>remap.lua</summary>

```lua
--[[ free keybinds: <leader>/, <leader>p, <leader>y, g% ]]

-- global
-- vim.keymap.set("n", "<leader>pv", vim.cmd.Ex, { desc = "Open Netrw file explorer" })
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move text down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move text up" })
vim.keymap.set("n", "J", "mzJ`z", { desc = "Remove newline underneath" })
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Jump down half page and centering" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Jump up half page and centering" })
vim.keymap.set("n", "n", "nzzzv", { desc = "Go to next match and centering" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Go to previous match and centering" })
vim.keymap.set("x", "<A-p>", [["_dP]], { desc = "Paste overwrite without yanking" })
vim.keymap.set({ "n", "v" }, "<A-y>", [["+y]], { desc = "Yank selected to system clipboard" })
vim.keymap.set("n", "<A-S-y>", [["+Y]], { desc = "Yank line to system clipboard" })
vim.keymap.set({ "n", "v" }, "<A-d>", [["_d]], { desc = "Delete selected and yank to system clipboard" })
vim.keymap.set("i", "<C-c>", "<Esc>", { desc = "Escape" })
vim.keymap.set("n", "Q", "<cmd>q<CR>", { desc = "Quit" })
vim.keymap.set("n", "A-S-q", "<cmd>tabclose<CR>", { desc = "Close tab" })
vim.keymap.set("t", "<C-]>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
vim.keymap.set("n", "<leader>gt", "<cmd>split <bar> term<CR>", { desc = "Toggle Terminal" })
vim.keymap.set("n", "<leader>g=", vim.lsp.buf.format, { desc = "Format current file" })
vim.keymap.set("n", "<C-q>", "<cmd>cclose<CR>", { desc = "Close quickfix window" })
vim.keymap.set("n", "<C-k>", "<cmd>cnext<CR>zz", { desc = "Next quickfix item" })
vim.keymap.set("n", "<C-j>", "<cmd>cprev<CR>zz", { desc = "Previous quickfix item" })
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz", { desc = "Next POI location" })
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz", { desc = "Previous POI location" })
vim.keymap.set("t", "<C-q>", "<C-\\><C-n>", { desc = "Escape terminal mode" })
vim.keymap.set("t", "<A-j>", "<C-\\><C-n><C-w>j", { desc = "Jump to bottom pane" })
vim.keymap.set("t", "<A-k>", "<C-\\><C-n><C-w>k", { desc = "Jump to top pane" })
vim.keymap.set("t", "<A-h>", "<C-\\><C-n><C-w>h", { desc = "Jump to left pane" })
vim.keymap.set("t", "<A-l>", "<C-\\><C-n><C-w>l", { desc = "Jump to right pane" })
vim.keymap.set("i", "<A-j>", "<C-\\><C-n><C-w>j", { desc = "Jump to bottom pane" })
vim.keymap.set("i", "<A-k>", "<C-\\><C-n><C-w>k", { desc = "Jump to top pane" })
vim.keymap.set("i", "<A-h>", "<C-\\><C-n><C-w>h", { desc = "Jump to left pane" })
vim.keymap.set("i", "<A-l>", "<C-\\><C-n><C-w>l", { desc = "Jump to right pane" })
vim.keymap.set("n", "<A-j>", "<C-w>j", { desc = "Jump to bottom pane" })
vim.keymap.set("n", "<A-k>", "<C-w>k", { desc = "Jump to top pane" })
vim.keymap.set("n", "<A-h>", "<C-w>h", { desc = "Jump to right pane" })
vim.keymap.set("n", "<A-l>", "<C-w>l", { desc = "Jump to right pane" })
vim.keymap.set("n", "<A-t>", "<C-w>t", { desc = "Jump to top left pane" }) -- and then use 'gt' to switch tabs
vim.keymap.set(
	"n",
	"<leader>s",
	[[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
	{ desc = "Concurrently replace all matching words" }
)
-- vim.keymap.set("n", "<leader>ex", "<cmd>!chmod +x %<CR>", { silent = true })

-- knowledgebase
vim.keymap.set(
	"n",
	"<leader>ii",
	"<cmd>e ~/.config/nvim/lua/plugins/init.lua<CR>",
	{ desc = "Go to plugins init file" }
)
vim.keymap.set("n", "<leader>iq", "<cmd>e ~/notes/quick.md<CR>", { desc = "Go to personal quick note file" })
vim.keymap.set("n", "<leader>ic", "<cmd>e ~/notes/checklist.md<CR>", { desc = "Go personal checklist file" })
vim.keymap.set("n", "<leader>it", "<cmd>e ~/notes/temp.md<CR>", { desc = "Go personal temp text file" })
vim.keymap.set("n", "<leader>ij", "<cmd>e ~/notes/journal.md<CR>", { desc = "Go personal journal file" })
vim.keymap.set("n", "<leader>iw", "<cmd>e ~/notes/wiki.md<CR>", { desc = "Go personal wiki file" })

-- cellularautomaton
vim.keymap.set("n", "<leader>ir", "<cmd>CellularAutomaton make_it_rain<CR>", { desc = "Run Make It Rain" })
vim.keymap.set("n", "<leader>il", "<cmd>CellularAutomaton game_of_life<CR>", { desc = "Run Game of Life" })

-- lsp
--[[
K: Displays hover information about the symbol under the cursor in a floating window. See :help vim.lsp.buf.hover().
gd: Jumps to the definition of the symbol under the cursor. See :help vim.lsp.buf.definition().
gD: Jumps to the declaration of the symbol under the cursor. Some servers don't implement this feature. See :help vim.lsp.buf.declaration().
gi: Lists all the implementations for the symbol under the cursor in the quickfix window. See :help vim.lsp.buf.implementation().
go: Jumps to the definition of the type of the symbol under the cursor. See :help vim.lsp.buf.type_definition().
gr: Lists all the references to the symbol under the cursor in the quickfix window. See :help vim.lsp.buf.references().
gs: Displays signature information about the symbol under the cursor in a floating window. See :help vim.lsp.buf.signature_help(). If a mapping already exists for this key this function is not bound.
<F2>: Renames all references to the symbol under the cursor. See :help vim.lsp.buf.rename().
<F3>: Format code in current buffer. See :help vim.lsp.buf.format().
<F4>: Selects a code action available at the current cursor position. See :help vim.lsp.buf.code_action().
gl: Show diagnostics in a floating window. See :help vim.diagnostic.open_float().
[d: Move to the previous diagnostic in the current buffer. See :help vim.diagnostic.goto_prev().
]d: Move to the next diagnostic. See :help vim.diagnostic.goto_next().
C-g: Workspace Symbol.
C-g: Signature Help in INSERT mode.
<leader>th: Toggle Inline Hints.
C-j: Previous snippet in INSERT mode.
C-k: Next snippet or expand in INSERT mode.
]]

-- telescope
local builtin = require("telescope.builtin")
vim.api.nvim_set_hl(0, "TelescopeNormal", { bg = "none" })
vim.keymap.set("n", "<C-/>", function()
	builtin.grep_string({ search = vim.fn.input("Grep > ") })
end, { desc = "Grep string global via Telescope" })
vim.keymap.set("n", "<C-p>", builtin.find_files, { desc = "Browse files global via Telescope" })
vim.keymap.set("n", "<leader>f", builtin.current_buffer_fuzzy_find, { desc = "Find string local via Telescope" })
vim.keymap.set("n", "<leader>vf", builtin.git_files, { desc = "Find git files global via Telescope" })
vim.keymap.set("n", "<leader>vh", builtin.help_tags, { desc = "Browse help tags via Telescope" })
vim.keymap.set("n", "<leader>vp", builtin.commands, { desc = "Browse commands via Telescope" })
vim.keymap.set("n", "<leader>vk", builtin.keymaps, { desc = "Browse keymaps via Telescope" })
vim.keymap.set("n", "<leader>vq", builtin.quickfix, { desc = "Browse quickfix items local via Telescope" })
vim.keymap.set("n", "<leader>vj", builtin.jumplist, { desc = "Browse jumplist global via Telescope" })
vim.keymap.set("n", "<leader>vm", function()
	require("telescope").extensions.metals.commands()
end, { desc = "Browse Metals LSP commands" })
vim.keymap.set("n", "<leader>ac", builtin.diagnostics, { desc = "Browse diagnostics items local via Telescope" })
vim.keymap.set("n", "<leader>ar", builtin.lsp_references, { desc = "Browse LSP References via Telescope" })
vim.keymap.set("n", "<leader>as", builtin.lsp_document_symbols, { desc = "Browse LSP Document Symbols via Telescope" })
vim.keymap.set(
	"n",
	"<leader>aw",
	builtin.lsp_dynamic_workspace_symbols,
	{ desc = "Browse LSP Dynamic Workspace Symbols global via Telescope" }
)
vim.keymap.set("n", "<leader>ai", builtin.lsp_implementations, { desc = "Browse LSP Implementations via Telescope" })
vim.keymap.set("n", "<leader>ad", builtin.lsp_definitions, { desc = "Browse LSP Definitions via Telescope" })
vim.keymap.set("n", "<leader>at", builtin.lsp_type_definitions, { desc = "Browse LSP Type Definitions via Telescope" })

-- trouble
--[[
<leader>cc: Buffer Diagnostics (Trouble)
<leader>cs: Symbols (Trouble)
<leader>cd: LSP Definitions / references / ... (Trouble)
<leader>ce: Location List (Trouble)
<leader>ca: Quickfix List (Trouble)
]]

-- smartopen
vim.keymap.set("n", "<C-x>", function()
	require("telescope").extensions.smart_open.smart_open({
		cwd_only = true,
	})
end, { noremap = true, silent = true, desc = "Open smart file picker in Telescope" })

-- neotest
local neotest = require("neotest")
vim.keymap.set("n", "<leader>tf", function()
	neotest.run.run()
end, { desc = "Test single function" })
vim.keymap.set("n", "<leader>ts", function()
	neotest.run.stop()
end, { desc = "Test stop" })
vim.keymap.set("n", "<leader>tb", function()
	neotest.run.run(vim.fn.expand("%"))
end, { desc = "Test single file" })
vim.keymap.set("n", "<leader>td", function()
	neotest.run.run(".")
end, { desc = "Test all from current directory" })
vim.keymap.set("n", "<leader>ta", function()
	neotest.run.run(vim.fn.getcwd())
end, { desc = "Test whole suite from root dir" })
vim.keymap.set("n", "<leader>tm", function()
	neotest.summary.toggle()
end, { desc = "Test summary toggle" })
vim.keymap.set("n", "<leader>tn", function()
	neotest.run.run({ strategy = "dap" })
end, { desc = "Debug nearest test" })
vim.keymap.set("n", "<leader>tm", "<cmd>ConfigureGtest<cr>", { desc = "Test configure C++ google test" })
vim.keymap.set("n", "<leader>tww", function()
	neotest.watch.toggle(vim.fn.expand("%"))
end, { desc = "Test watch toggle current file" })
vim.keymap.set("n", "<leader>tws", function()
	neotest.watch.stop("")
end, { desc = "Test watch stop all position" })
vim.keymap.set("n", "<leader>to", function()
	neotest.output.open({ enter = true })
end, { desc = "Test output open" })
vim.keymap.set("n", "<leader>tp", function()
	neotest.output_panel.toggle()
end, { desc = "Test output toggle panel" })
vim.keymap.set("n", "<leader>tc", function()
	neotest.output_panel.clear()
end, { desc = "Test output clear panel" })
vim.keymap.set("n", "<leader>twj", function()
	neotest.run.run({ jestCommand = "jest --watch " })
end, { desc = "Test Jest watch mode" })
vim.keymap.set("n", "<leader>twv", function()
	neotest.run.run({ vitestCommand = "vitest --watch" })
end, { desc = "Run Watch" })
vim.keymap.set("n", "<leader>twf", function()
	neotest.run.run({ vim.fn.expand(" % "), vitestCommand = "vitest --watch" })
end, { desc = "Run Watch File" })

-- dap
local dap = require("dap")
vim.keymap.set("n", "<F5>", dap.continue, { desc = "Debug continue" })
vim.keymap.set("n", "<F6>", dap.step_over, { desc = "Debug step over" })
vim.keymap.set("n", "<F7>", dap.step_into, { desc = "Debug step into" })
vim.keymap.set("n", "<F8>", dap.step_out, { desc = "Debug step out" })
vim.keymap.set("n", "<F9>", function()
	dap.disconnect({ terminateDebuggee = true })
	dap.close()
end, { desc = "Debug stop" })
vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint, { desc = "Debug toggle point" })
vim.keymap.set("n", "<leader>B", function()
	dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
end, { desc = "Debug set breakpoint condition" })
vim.keymap.set("n", "<leader>ap", function()
	dap.set_breakpoint(nil, nil, vim.fn.input("Log point message: "))
end, { desc = "Debug set log point message" })
vim.keymap.set("n", "<leader>el", dap.run_last, { desc = "Debug run the last session again" })
vim.keymap.set("n", "<leader>er", dap.repl.open, { desc = "Debug open REPL" })
vim.keymap.set("n", "<leader>et", require("dap-go").debug_test, { desc = "Debug golang test" })
vim.keymap.set("n", "<leader>ee", function()
	require("dapui").eval(nil, { enter = true })
end, { desc = "Debug evaluate expression" })

-- harpoon
local harpoon = require("harpoon")
harpoon:setup()
-- C-q: Open Harpoon Telescope window
vim.keymap.set("n", "<leader>h", function()
	harpoon:list():add()
end, { desc = "Add current location to Harpoon list" })
vim.keymap.set("n", "<C-z>", function()
	harpoon.ui:toggle_quick_menu(harpoon:list())
end, { desc = "Toggle Harpoon interactive list" })
vim.keymap.set("n", "<C-a>", function()
	harpoon:list():select(1)
end, { desc = "Go to 1st Harpoon location" })
vim.keymap.set("n", "<C-s>", function()
	harpoon:list():select(2)
end, { desc = "Go to 2nd Harpoon location" })
vim.keymap.set("n", "<C-n>", function()
	harpoon:list():select(3)
end, { desc = "Go to 3rd Harpoon location" })
vim.keymap.set("n", "<C-m>", function()
	harpoon:list():select(4)
end, { desc = "Go to 4th Harpoon location" })
vim.keymap.set("n", "<C-A-P>", function()
	harpoon:list():prev()
end, { desc = "Go to next Harpoon location" })
vim.keymap.set("n", "<C-A-N>", function()
	harpoon:list():next()
end, { desc = "Go to previous Harpoon location" })

-- refactoring
local refactoring = require("refactoring")
vim.keymap.set("x", "<leader>re", function()
	refactoring.refactor("Extract Function")
end, { desc = "Refactor extract function" })
vim.keymap.set("x", "<leader>rf", function()
	refactoring.refactor("Extract Function To File")
end, { desc = "Refactor extract function to file" })
vim.keymap.set("x", "<leader>rv", function()
	refactoring.refactor("Extract Variable")
end, { desc = "Refactor extract variable" })
vim.keymap.set("n", "<leader>rI", function()
	refactoring.refactor("Inline Function")
end, { desc = "Refactor inline function" })
vim.keymap.set({ "n", "x" }, "<leader>ri", function()
	refactoring.refactor("Inline Variable")
end, { desc = "Refactor inline variable" })
vim.keymap.set("n", "<leader>rb", function()
	refactoring.refactor("Extract Block")
end, { desc = "Refactor extract block" })
vim.keymap.set("n", "<leader>rB", function()
	refactoring.refactor("Extract Block To File")
end, { desc = "Refactor extract block to file" })
vim.keymap.set({ "x", "n" }, "<leader>rd", function()
	refactoring.debug.print_var()
end, { desc = "Refactor debug print var" })
vim.keymap.set("n", "<leader>rD", function()
	refactoring.debug.printf({ below = false })
end, { desc = "Refactor debug printf" })
vim.keymap.set("n", "<leader>rc", function()
	refactoring.debug.cleanup({})
end, { desc = "Refactor debug cleanup" })
vim.keymap.set({ "n", "x" }, "<leader>rt", function()
	refactoring.select_refactor()
end, { desc = "Refactor select native thing" })
vim.keymap.set({ "n", "x" }, "<leader>rr", function()
	require("telescope").extensions.refactoring.refactors()
end, { desc = "Refactor select operations via Telescope" })

-- undotree
vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle, { desc = "Toggle undo tree" })

-- fugitive
vim.keymap.set("n", "<leader>gs", vim.cmd.Git, { desc = "Open git fugitive" })

-- diffview
-- [c and ]c to jump between hunks
vim.keymap.set("n", "<leader>gh", "<cmd>DiffviewFileHistory<cr>", { desc = "Open history current branch" })
vim.keymap.set("n", "<leader>gf", "<cmd>DiffviewFileHistory %<cr>", { desc = "Open history current file" })
vim.keymap.set("n", "<leader>gd", "<cmd>DiffviewOpen<cr>", { desc = "Open diff current index" })
vim.keymap.set("n", "<leader>gm", "<cmd>DiffviewOpen origin/main...HEAD<cr>", { desc = "Open diff main" })
vim.keymap.set("n", "<leader>gc", "<cmd>DiffviewClose<cr>", { desc = "Close diff view" })

-- ufo
vim.keymap.set("n", "zR", require("ufo").openAllFolds, { desc = "Open all folds" })
vim.keymap.set("n", "zM", require("ufo").closeAllFolds, { desc = "Close all folds" })

-- file manager
vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
vim.keymap.set("n", "<space>-", require("oil").toggle_float, { desc = "Open parent directory in floating window" })
--[[
keymaps = {
    ["g?"] = "actions.show_help",
    ["<CR>"] = "actions.select",
    ["<C-s>"] = "actions.select_vsplit",
    ["<C-h>"] = "actions.select_split",
    ["<C-t>"] = "actions.select_tab",
    ["<C-p>"] = "actions.preview",
    ["<C-c>"] = "actions.close",
    ["<C-l>"] = "actions.refresh",
    ["-"] = "actions.parent",
    ["_"] = "actions.open_cwd",
    ["`"] = "actions.cd",
    ["~"] = "actions.tcd",
    ["gs"] = "actions.change_sort",
    ["gx"] = "actions.open_external",
    ["g."] = "actions.toggle_hidden",
    ["g\\"] = "actions.toggle_trash",
},
]]

-- rendermarkdown
vim.keymap.set("n", "<leader>tr", require("render-markdown").toggle, { desc = "Toggle Render Markdown" })

-- noice
local noice = require("noice")
vim.keymap.set("n", "<leader>nh", function()
	noice.cmd("history")
end, { desc = "Noice history" })
vim.keymap.set("n", "<leader>nl", function()
	noice.cmd("last")
end, { desc = "Noice last" })
vim.keymap.set("n", "<leader>nd", function()
	noice.cmd("dismiss")
end, { desc = "Noice dismiss" })
vim.keymap.set("n", "<leader>ne", function()
	noice.cmd("errors")
end, { desc = "Noice errors" })
vim.keymap.set("n", "<leader>nq", function()
	noice.cmd("disable")
end, { desc = "Noice disable" })
vim.keymap.set("n", "<leader>nb", function()
	noice.cmd("enable")
end, { desc = "Noice enable" })
vim.keymap.set("n", "<leader>ns", function()
	noice.cmd("stats")
end, { desc = "Noice debugging stats" })
vim.keymap.set("n", "<leader>nt", function()
	noice.cmd("telescope")
end, { desc = "Noice open messages in Telescope" })
vim.keymap.set("c", "<S-Enter>", function()
	noice.redirect(vim.fn.getcmdline())
end, { desc = "Redirect Cmdline" })
vim.keymap.set({ "n", "i", "s" }, "<c-f>", function()
	if not require("noice.lsp").scroll(4) then
		return "<c-f>"
	end
end, { silent = true, expr = true, desc = "LSP hover doc scroll up" })
vim.keymap.set({ "n", "i", "s" }, "<c-b>", function()
	if not require("noice.lsp").scroll(-4) then
		return "<c-b>"
	end
end, { silent = true, expr = true, desc = "LSP hover doc scroll down" })
```

</details>

## Plugins List

<details>
	<summary>Loaded (75)</summary>

- cellular-automaton.nvim 0.36ms  start
- cmp-buffer 0.4ms  nvim-cmp
- cmp-cmdline 0.43ms  nvim-cmp
- cmp-nvim-lsp 0.31ms  nvim-cmp
- cmp-nvim-lsp-signature-help 0.54ms  nvim-cmp
- cmp-path 0.42ms  nvim-cmp
- cmp_luasnip 0.14ms  nvim-cmp
- diffview.nvim 1.99ms  start
- dressing.nvim 2.22ms  start
- fidget.nvim 4.05ms  lsp-zero.nvim
- FixCursorHold.nvim 2.01ms  neotest
- friendly-snippets 0.59ms  LuaSnip
- gitsigns.nvim 3.68ms  start
- harpoon 4.83ms  start
- indent-blankline.nvim 5.07ms  start
- lazy.nvim 4.36ms  init.lua
- lsp-zero.nvim 149.49ms  start
- lspkind.nvim 0.32ms  nvim-cmp
- lualine.nvim 11.01ms  start
- LuaSnip 6.59ms  nvim-cmp
- mason-lspconfig.nvim 0.12ms  lsp-zero.nvim
- mason-null-ls.nvim 1.28ms  lsp-zero.nvim
- mason-nvim-dap.nvim 0.24ms  lsp-zero.nvim
- mason-tool-installer.nvim 5.26ms  lsp-zero.nvim
- mason.nvim 4.23ms  lsp-zero.nvim
- mini.nvim 4.23ms  start
- neotest 43.79ms  start
- neotest-bash 1.76ms  neotest
- neotest-go 1.72ms  neotest
- neotest-gtest 1.99ms  neotest
- neotest-jest 1.91ms  neotest
- neotest-plenary 1.7ms  neotest
- neotest-python 1.69ms  neotest
- neotest-rust 1.74ms  neotest
- neotest-scala 1.98ms  neotest
- neotest-vitest 1.88ms  neotest
- noice.nvim 7.96ms 󰢱 noice  config.remap
- none-ls.nvim 1.26ms  lsp-zero.nvim
- nui.nvim 2.27ms  noice.nvim
- nvim-cmp 14.6ms  start
- nvim-dap 3.97ms  lsp-zero.nvim
- nvim-dap-go 1.35ms  lsp-zero.nvim
- nvim-dap-ui 1.29ms  lsp-zero.nvim
- nvim-dap-virtual-text 1.32ms  lsp-zero.nvim
- nvim-lspconfig 0.46ms 󰢱 lspconfig  nvim-ufo
- nvim-nio 1.34ms  lsp-zero.nvim
- nvim-notify 2.03ms  noice.nvim
- nvim-treesitter 19.61ms  render-markdown
- nvim-treesitter-context 1.9ms  start
- nvim-ts-autotag 4.87ms  nvim-treesitter
- nvim-ufo 7.26ms  start
- nvim-web-devicons 1.18ms  lualine.nvim
- oil.nvim 2.67ms  start
- playground 3.53ms  start
- plenary.nvim 0.96ms  refactoring.nvim
- promise-async 1.09ms  nvim-ufo
- refactoring.nvim 11.49ms  start
- render-markdown 25.1ms  start
- rose-pine 3.91ms  start
- SchemaStore.nvim 0.12ms  lsp-zero.nvim
- smart-open.nvim 15.67ms  start
- sqlite.lua 1.56ms  smart-open.nvim
- telescope-fzf-native.nvim 1.69ms  smart-open.nvim
- telescope-fzy-native.nvim 1.72ms  smart-open.nvim
- telescope.nvim 4.42ms 󰢱 telescope  refactoring.nvim
- undotree 1.19ms  start
- vim-dadbod 0.46ms  start
- vim-dadbod-completion 1.21ms  start
- vim-dadbod-ui 2.05ms  start
- vim-fugitive 2.34ms  start
- vimtex 0.56ms  start
- lazydev.nvim  lua
- luvit-meta
- nvim-metals  scala  sbt
- trouble.nvim  <leader>ca  <leader>cc  <leader>cs  <leader>cd  <leader>ce

</details>

## Languages Packages List

<details>
	<summary>Installed (71)</summary>

```lua
-- lua
"lua_ls",
"stylua",
"luacheck",

-- go
"gopls",
"gotests",
"impl",
"gomodifytags",
"goimports-reviser",
"staticcheck",
"semgrep",
"golangci_lint_ls",
"golangci_lint",
"delve",
"go-debug-adapter",

-- javascript/typescript & vue
"tsserver",
"eslint",
"volar",
"prettier",
"js-debug-adapter",
"firefox-debug-adapter",

-- html/htmx & css/tailwind
"html",
"emmet_language_server",
"htmx",
"cssls",
"tailwindcss",

-- python
"pyright",
"blue",
"flake8",
"debugpy",

-- c/cpp
"clangd",
"clang-format",
"cpptools",

-- rust
"rust_analyzer",
"codelldb",

-- java
"jdtls",
"java-test",
"google-java-format",
"java-debug-adapter",

-- assembly
"asm-lsp",
"asmfmt",

-- markdown
"marksman",
"cbfmt",

-- latex & typos
"texlab",
typos_lsp = {
    init_options = {
        config = "~/typos.toml",
    },
},

-- shell
"bashls",
"powershell_es",
"shellcheck",
"shfmt",
"beautysh",
"bash-debug-adapter",

-- make & cmake
"checkmake",
"neocmake",
"cmakelint",

-- json
jsonls = {
    settings = {
        json = {
            schemas = require("schemastore").json.schemas(),
            validate = { enable = true },
        },
    },
},

-- yaml
yamlls = {
    settings = {
        yaml = {
            schemaStore = {
                enable = false,
                url = "",
            },
            schemas = require("schemastore").yaml.schemas(),
        },
    },
},
"yamlfmt",
"yamllint",

-- toml
"taplo",

-- sql
"sqlls",
"sqlfluff",
"sql-formatter",

-- protobuf
"bufls",
"buf",
"protolint",

-- graphql
"graphql",

-- docker/compose
"dockerls",
"docker_compose_language_service",

-- ci/cd
"actionlint",

-- kubernetes/helm
"helm_ls",

-- ansible
"ansiblels",
"ansible-lint",

-- opentofu
"terraformls",
"tflint",
```

</details>

## References

<details>
  <summary>expand</summary>

- 0 to LSP: <https://youtu.be/w7i4amO_zaE>
- Zero to IDE: <https://youtu.be/N93cTbtLCIM>
- Effective Neovim: Instant IDE: <https://youtu.be/stqUbv-5u2s>
- The Only Video You Need to Get Started with Neovim: <https://youtu.be/m8C0Cq9Uv9o>
- Kickstart.nvim: <https://github.com/nvim-lua/kickstart.nvim>
- ThePrimeagen/init.lua: <https://github.com/ThePrimeagen/init.lua>
- TJDevries/config.nvim: <https://github.com/tjdevries/config.nvim>
- Debugging in Neovim: <https://youtu.be/0moS8UHupGc>
- Simple neovim debugging setup: <https://youtu.be/lyNfnI-B640>
- My neovim autocomplete setup: explained: <https://youtu.be/22mrSjknDHI>
- Oil.nvim - My Favorite Addition to my Neovim Config: <https://youtu.be/218PFRsvu2o>
- Vim Dadbod - My Favorite SQL Plugin: <https://youtu.be/ALGBuFLzDSA>

</details>

![neovim-demo](https://github.com/lavantien/dotfiles/blob/main/assets/neovim-demo.png)
