return {
	{
		"VonHeikemen/lsp-zero.nvim",
		branch = "v2.x",
		dependencies = {
			{ "neovim/nvim-lspconfig" },
			{
				"williamboman/mason.nvim",
				build = function() pcall(vim.cmd, "MasonUpdate") end,
			},
			{ "williamboman/mason-lspconfig.nvim" },
			{ "hrsh7th/nvim-cmp" },
			{ "hrsh7th/cmp-nvim-lsp" },
			{ "L3MON4D3/LuaSnip" },
		},
		config = function()
			local lsp = require("lsp-zero")
			lsp.preset("recommended")
			lsp.extend_cmp()
			lsp.on_attach(function(client, bufnr)
				lsp.default_keymaps({
					buffer = bufnr,
					preserve_mapping = false,
				})
				local opts = { buffer = bufnr }
				vim.keymap.set("n", "<leader>ws", function()
					vim.lsp.buf.workspace_symbol()
				end, opts)
				vim.keymap.set("n", "<leader>a", function()
					vim.lsp.buf.code_action()
				end, opts)
				lsp.buffer_autoformat()
			end)
			--[[
			require('lspconfig').jdtls.setup({
			  on_attach = function(client, bufnr)
				lsp.default_keymaps({buffer = bufnr})
				lsp.buffer_autoformat()
			  end
			})
			lsp.set_server_config({
				single_file_support = false,
				capabilities = {
					textDocument = {
						foldingRange = {
							dynamicRegistration = false,
							lineFoldingOnly = true,
						},
						completion = {
							completionItem = {
								snippetSupport = true,
								resolveSupport = {
									properties = {
										"documentation",
										"detail",
										"additionalTextEdits",
									},
								},
							},
						},
					},
				},
			})
			--]]
			lsp.setup()
			local cmp = require("cmp")
			local cmp_action = require('lsp-zero').cmp_action()
			cmp.setup({
				mapping = {
					["<CR>"] = cmp.mapping.confirm({ select = false }),
					["<C-Space>"] = cmp.mapping.complete(),
					['<C-f>'] = cmp_action.luasnip_jump_forward(),
					['<C-b>'] = cmp_action.luasnip_jump_backward(),
				},
			})
			vim.diagnostic.config({
				virtual_text = true,
			})
			require("mason").setup()
			require("mason-lspconfig").setup({
				ensure_installed = {
					"ltex",
					"jdtls",
					"marksman",
					"tflint",
					"terraformls",
					"yamlls",
					"bufls",
					"csharp_ls",
					"ocamllsp",
					"tailwindcss",
					"clangd",
					"pyright",
					"cssls",
					"html",
					"tsserver",
					"lua_ls",
					"rust_analyzer",
					"golangci_lint_ls",
					"gopls",
					"sqlls",
				},
			})

			require("mason-nvim-dap").setup({
				ensure_installed = {},
				automatic_installation = true,
				handlers = {}
			})
		end,
	},
	{
		"mfussenegger/nvim-dap",
		"jay-babu/mason-nvim-dap.nvim",
		'leoluz/nvim-dap-go',
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			require('dap-go').setup()
			local dap, dapui = require("dap"), require("dapui")
			dap.listeners.after.event_initialized["dapui_config"] = function()
				dapui.open()
			end
			dap.listeners.before.event_terminated["dapui_config"] = function()
				dapui.close()
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				dapui.close()
			end
		end,
	},
	{
		"rcarriga/nvim-dap-ui",
		'folke/neodev.nvim',
		'theHamsta/nvim-dap-virtual-text',
		dependencies = { "mfussenegger/nvim-dap" },
		config = function()
			require("dapui").setup()
			require("neodev").setup({
				library = { plugins = { "nvim-dap-ui" }, types = true },
			})
			require("nvim-dap-virtual-text").setup()
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		config = function()
			require 'nvim-treesitter.install'.compilers = { "clang" }
			require("nvim-treesitter.configs").setup({
				ensure_installed = { 'bash', 'c', 'c_sharp', 'cpp', 'css', 'dart', 'dockerfile', 'git_config',
					'gitattributes',
					'gitignore', 'go', 'gomod', 'gosum', 'gowork', 'html', 'java', 'javascript', 'json', 'lua', 'make',
					'markdown', 'proto', 'python', 'query', 'rust', 'scss', 'sql', 'toml', 'typescript', 'vim', 'vimdoc',
					'yaml' },
				sync_install = false,
				auto_install = true,
				highlight = {
					enable = true,
					additional_vim_regex_highlighting = false,
				},
			})
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter-context",
	},
	-- {
	-- 	"jose-elias-alvarez/null-ls.nvim",
	-- 	config = function()
	-- 		local null_ls = require("null-ls")
	-- 		local formatting = null_ls.builtins.formatting
	-- 		local diagnostics = null_ls.builtins.diagnostics
	-- 		local actions = null_ls.builtins.code_actions
	-- 		local sources = {
	-- 			formatting.dart_format,
	-- 			--formatting.zigfmt,
	-- 			--formatting.nimpretty, -- not supported by the LS
	-- 			--formatting.nixfmt,
	-- 			--formatting.nginx_beautifier,
	-- 			--formatting.clang_format, -- shadowing jdtls
	-- 			formatting.prettier,
	-- 			--diagnostics.dotenv_linter,
	-- 			formatting.goimports_reviser,
	-- 			diagnostics.checkmake,
	-- 			diagnostics.clang_check,
	-- 			actions.refactoring,
	-- 			actions.gitsigns,
	-- 			actions.gomodifytags,
	-- 			actions.impl,
	-- 		}
	-- 		--local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
	-- 		null_ls.setup({
	-- 			sources = sources,
	-- 			--[==[
	-- 			on_attach = function(client, bufnr)
	-- 				if client.supports_method("textDocument/formatting") then
	-- 					vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
	-- 					vim.api.nvim_create_autocmd("BufWritePre", {
	-- 						group = augroup,
	-- 						buffer = bufnr,
	-- 						callback = function()
	-- 							vim.lsp.buf.format({
	-- 								bufnr = bufnr,
	-- 								filter = function(client)
	-- 									return client.name == "null-ls"
	-- 								end,
	-- 							})
	-- 						end,
	-- 						--[[
	-- 						callback = function()
	-- 							vim.lsp.buf.format({ bufnr = bufnr })
	-- 						end,
	-- 					    --]]
	-- 					})
	-- 				end
	-- 			end,
	-- 			--]==]
	-- 		})
	-- 	end,
	-- },
	{
		"j-hui/fidget.nvim",
		config = function() require("fidget").setup() end,
	},
	"nvim-treesitter/playground",
	{
		"nvim-telescope/telescope.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
	},
	{
		"kylechui/nvim-surround",
		config = function() require("nvim-surround").setup() end,
	},
	{
		'numToStr/Comment.nvim',
		config = function() require('Comment').setup() end,
	},
	{
		'stevearc/dressing.nvim',
		opts = {},
	},

	-- {
	-- 	"folke/tokyonight.nvim",
	-- 	lazy = false,
	-- 	priority = 1000,
	-- 	opts = {},
	-- 	config = function()
	-- 		require("tokyonight").setup({
	-- 			-- rose-pine
	-- 			disable_background = true,
	-- 			disable_float_background = true,
	-- 			-- tokyonight
	-- 			transparent = true,
	-- 			on_highlights = function(hl, c)
	-- 				local textColor = c.fg_dark
	-- 				hl.TelescopeNormal = {
	-- 					-- bg = c.bg_dark,
	-- 					bg = 'none',
	-- 					fg = textColor,
	-- 				}
	-- 				hl.TelescopeBorder = {
	-- 					-- bg = c.bg_dark,
	-- 					bg = 'none',
	-- 					fg = textColor,
	-- 				}
	-- 				hl.TelescopePromptNormal = {
	-- 					-- bg = prompt,
	-- 					bg = 'none',
	-- 					fg = textColor,
	-- 				}
	-- 				hl.TelescopePromptBorder = {
	-- 					-- bg = prompt,
	-- 					bg = 'none',
	-- 					fg = textColor,
	-- 				}
	-- 				hl.TelescopePromptTitle = {
	-- 					-- bg = prompt,
	-- 					bg = 'none',
	-- 					fg = textColor,
	-- 				}
	-- 				hl.TelescopePreviewTitle = {
	-- 					-- bg = c.bg_dark,
	-- 					bg = 'none',
	-- 					fg = textColor,
	-- 				}
	-- 				hl.TelescopeResultsTitle = {
	-- 					-- bg = c.bg_dark,
	-- 					bg = 'none',
	-- 					fg = textColor,
	-- 				}
	-- 			end,
	-- 		})
	-- 		function ColorMyPencils(color)
	-- 			color = color or "tokyonight"
	-- 			vim.cmd.colorscheme(color)
	-- 			vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
	-- 			vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
	-- 		end
	--
	-- 		ColorMyPencils()
	-- 	end,
	-- },
	{
		"ellisonleao/gruvbox.nvim",
		priority = 1000,
		config = function()
			require("gruvbox").setup({
				transparent_mode = true,
			})
			vim.cmd.colorscheme("gruvbox")
		end,
		opts = ...
	},
	-- {
	-- 	"rose-pine/neovim",
	-- 	name = "rose-pine",
	-- 	lazy = false,
	-- 	priority = 1000,
	-- 	opts = {},
	-- 	config = function()
	-- 		require("rose-pine").setup({
	-- 			disable_background = true,
	-- 			disable_float_background = true,
	-- 		})
	-- 		function ColorMyPencils(color)
	-- 			color = color or "rose-pine"
	-- 			vim.cmd.colorscheme(color)
	-- 			vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
	-- 			vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
	-- 		end
	--
	-- 		ColorMyPencils()
	-- 	end,
	-- },
	{
		"folke/trouble.nvim",
		dependencies = "nvim-tree/nvim-web-devicons",
		config = function() require("trouble").setup({}) end,
	},
	{
		"nvim-lualine/lualine.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			--[[
			local custom_auto = require("lualine.themes.auto")
			custom_auto.normal.c.bg = nil
			custom_auto.insert.c.bg = nil
			custom_auto.visual.c.bg = nil
			custom_auto.replace.c.bg = nil
			custom_auto.command.c.bg = nil
			--]]
			require("lualine").setup({
				options = {
					--theme = 'tokyonight',
					theme = 'auto',
					section_separators = { left = "", right = "" },
					component_separators = { left = "", right = "" },
				},
			})
		end,
	},

	{
		'nmac427/guess-indent.nvim',
		config = function()
			require('guess-indent').setup {
				auto_cmd = true,
				override_editorconfig = false,
				filetype_exclude = {
					"netrw",
					"tutor",
				},
				buftype_exclude = {
					"help",
					"nofile",
					"terminal",
					"prompt",
				},
			}
		end,
	},

	--[[
    {
    	"theprimeagen/harpoon",
    	config = function() end,
    }
    --]]
	{
		"theprimeagen/refactoring.nvim",
		config = function() require("refactoring").setup() end
	},
	{
		"mbbill/undotree",
	},
	{
		"tpope/vim-fugitive",
	},
	{
		"lewis6991/gitsigns.nvim",
	},

	{
		"Exafunction/codeium.vim",
	},
	{
		"wakatime/vim-wakatime",
	},

	{
		"lervag/vimtex",
	},
}
