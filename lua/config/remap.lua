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
vim.keymap.set("n", "<leader>tg", "<cmd>ConfigureGtest<cr>", { desc = "Test configure C++ google test" })
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

-- markview
vim.keymap.set("n", "<leader>tr", "<cmd>Markview Toggle<cr>", { desc = "Toggle Render Markdown" })

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
