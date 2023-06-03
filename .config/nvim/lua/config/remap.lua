vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

vim.keymap.set("n", "J", "mzJ`z")
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

vim.keymap.set("x", "<leader>p", [["_dP]])
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])
vim.keymap.set({ "n", "v" }, "<leader>d", [["_d]])

vim.keymap.set("i", "<C-c>", "<Esc>")
vim.keymap.set("n", "Q", "<nop>")

--vim.keymap.set("n", "<C-f>", "<cmd>silent !tmux neww tmux-sessionizer<CR>")
vim.keymap.set("n", "<leader>f", vim.lsp.buf.format)

vim.keymap.set("n", "<C-k>", "<cmd>cnext<CR>zz")
vim.keymap.set("n", "<C-j>", "<cmd>cprev<CR>zz")
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz")
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz")

vim.keymap.set("t", "<Esc>", "<C-\\><C-n>")
vim.keymap.set("t", "<A-j>", "<C-\\><C-n><C-w>j")
vim.keymap.set("t", "<A-k>", "<C-\\><C-n><C-w>k")
vim.keymap.set("t", "<A-h>", "<C-\\><C-n><C-w>h")
vim.keymap.set("t", "<A-l>", "<C-\\><C-n><C-w>l")
vim.keymap.set("i", "<A-j>", "<C-\\><C-n><C-w>j")
vim.keymap.set("i", "<A-k>", "<C-\\><C-n><C-w>k")
vim.keymap.set("i", "<A-h>", "<C-\\><C-n><C-w>h")
vim.keymap.set("i", "<A-l>", "<C-\\><C-n><C-w>l")
vim.keymap.set("n", "<A-j>", "<C-w>j")
vim.keymap.set("n", "<A-k>", "<C-w>k")
vim.keymap.set("n", "<A-h>", "<C-w>h")
vim.keymap.set("n", "<A-l>", "<C-w>l")
vim.keymap.set("n", "<A-t>", "<C-w>t") -- and then use 'gt' to switch tabs

vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true })

vim.keymap.set("n", "<leader>vc", "<cmd>e ~/.config/nvim/lua/plugins/init.lua<CR>")

--[=====[
vim.keymap.set("n", "<leader><leader>", function()
    vim.cmd("so")
end)
--]=====]

-- codeium
vim.keymap.set("i", "<C-'>", function()
	return vim.fn["codeium#Accept"]()
end, { expr = true })
vim.keymap.set("i", "<C-.>", function()
	return vim.fn["codeium#CycleCompletions"](1)
end, { expr = true })
vim.keymap.set("i", "<C-,>", function()
	return vim.fn["codeium#CycleCompletions"](-1)
end, { expr = true })
vim.keymap.set("i", "<C-/>", function()
	return vim.fn["codeium#Clear"]()
end, { expr = true })
vim.keymap.set("i", "<C-]>", function()
	return vim.fn["codeium#Complete"]()
end, { expr = true })

-- dap
vim.keymap.set('n', '<F5>', require 'dap'.continue)
vim.keymap.set('n', '<F6>', require 'dap'.step_over)
vim.keymap.set('n', '<F7>', require 'dap'.step_into)
vim.keymap.set('n', '<F8>', require 'dap'.step_out)
vim.keymap.set('n', '<F9>',
	function()
		require 'dap'.disconnect({ terminateDebuggee = true })
		require 'dap'.close()
	end)
vim.keymap.set('n', '<leader>b', require 'dap'.toggle_breakpoint)
vim.keymap.set('n', '<leader>B',
	function()
		require 'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))
	end)
vim.keymap.set('n', '<leader>lp',
	function()
		require 'dap'.set_breakpoint(nil, nil, vim.fn.input('Log point message: '))
	end)
vim.keymap.set('n', '<leader>E', require 'dap'.repl.open)
vim.keymap.set('n', '<leader>e', require 'dap-go'.debug_test)

-- fugitive
vim.keymap.set("n", "<leader>gs", vim.cmd.Git)

-- refactoring
vim.api.nvim_set_keymap(
	"v",
	"<leader>re",
	[[ <Esc><Cmd>lua require('refactoring').refactor('Extract Function')<CR>]],
	{ noremap = true, silent = true, expr = false }
)
vim.api.nvim_set_keymap(
	"v",
	"<leader>rf",
	[[ <Esc><Cmd>lua require('refactoring').refactor('Extract Function To File')<CR>]],
	{ noremap = true, silent = true, expr = false }
)
vim.api.nvim_set_keymap(
	"v",
	"<leader>rv",
	[[ <Esc><Cmd>lua require('refactoring').refactor('Extract Variable')<CR>]],
	{ noremap = true, silent = true, expr = false }
)
vim.api.nvim_set_keymap(
	"v",
	"<leader>ri",
	[[ <Esc><Cmd>lua require('refactoring').refactor('Inline Variable')<CR>]],
	{ noremap = true, silent = true, expr = false }
)
vim.api.nvim_set_keymap(
	"n",
	"<leader>rb",
	[[ <Cmd>lua require('refactoring').refactor('Extract Block')<CR>]],
	{ noremap = true, silent = true, expr = false }
)
vim.api.nvim_set_keymap(
	"n",
	"<leader>rbf",
	[[ <Cmd>lua require('refactoring').refactor('Extract Block To File')<CR>]],
	{ noremap = true, silent = true, expr = false }
)
vim.api.nvim_set_keymap(
	"n",
	"<leader>ri",
	[[ <Cmd>lua require('refactoring').refactor('Inline Variable')<CR>]],
	{ noremap = true, silent = true, expr = false }
)
vim.api.nvim_set_keymap(
	"v",
	"<leader>ri",
	[[ <Esc><Cmd>lua require('refactoring').refactor('Inline Variable')<CR>]],
	{ noremap = true, silent = true, expr = false }
)

-- telescope
local builtin = require("telescope.builtin")
vim.api.nvim_set_hl(0, "TelescopeNormal", { bg = "none" })
vim.keymap.set("n", "<leader>pf", builtin.find_files, {})
vim.keymap.set("n", "<C-p>", builtin.git_files, {})
vim.keymap.set("n", "<leader>ps", function()
	builtin.grep_string({ search = vim.fn.input("Grep > ") })
end)
vim.keymap.set("n", "<leader>vh", builtin.help_tags, {})
vim.keymap.set("n", "<leader>vp", builtin.commands, {})
vim.keymap.set("n", "<leader>vk", builtin.keymaps, {})
vim.keymap.set("n", "<leader>vq", builtin.quickfix, {})
vim.keymap.set("n", "<leader>vj", builtin.jumplist, {})
vim.keymap.set("n", "<leader>vf", builtin.current_buffer_fuzzy_find, {})
vim.keymap.set("n", "<leader>lc", builtin.diagnostics, {})
vim.keymap.set("n", "<leader>lr", builtin.lsp_references, {})
vim.keymap.set("n", "<leader>ls", builtin.lsp_document_symbols, {})
vim.keymap.set("n", "<leader>lw", builtin.lsp_dynamic_workspace_symbols, {})
vim.keymap.set("n", "<leader>li", builtin.lsp_implementations, {})
vim.keymap.set("n", "<leader>ld", builtin.lsp_definitions, {})
vim.keymap.set("n", "<leader>lt", builtin.lsp_type_definitions, {})

-- trouble
vim.keymap.set("n", "<leader>xq", "<cmd>TroubleToggle quickfix<cr>", { silent = true, noremap = true })

-- undotree
vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle)

-- harpoon
--[[
local mark = require("harpoon.mark")
local ui = require("harpoon.ui")
vim.keymap.set("n", "<leader>va", mark.add_file)
vim.keymap.set("n", "<C-e>", ui.toggle_quick_menu)
vim.keymap.set("n", "<C-h>", function()
	ui.nav_file(1)
end)
vim.keymap.set("n", "<C-t>", function()
	ui.nav_file(2)
end)
vim.keymap.set("n", "<C-n>", function()
	ui.nav_file(3)
end)
vim.keymap.set("n", "<C-s>", function()
	ui.nav_file(4)
end)
--]]
