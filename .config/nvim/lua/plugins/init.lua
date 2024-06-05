return {
	{ -- Intellisense, Debugging, Autolint, Snippets, and Status Spinner
		"VonHeikemen/lsp-zero.nvim",
		branch = "v3.x",
		dependencies = {
			{ "neovim/nvim-lspconfig" },
			{
				"williamboman/mason.nvim",
				config = true,
				build = function()
					pcall(vim.cmd, "MasonUpdate")
				end,
			},
			{ "williamboman/mason-lspconfig.nvim" },
			{
				"hrsh7th/nvim-cmp",
				lazy = false,
				priority = 100,
				dependencies = {
					"onsails/lspkind.nvim",
					"hrsh7th/cmp-nvim-lsp",
					"hrsh7th/cmp-path",
					"hrsh7th/cmp-buffer",
					"hrsh7th/cmp-cmdline",
					"hrsh7th/cmp-nvim-lsp-signature-help",
					{
						"L3MON4D3/LuaSnip",
						dependencies = { "rafamadriz/friendly-snippets" },
						build = "make install_jsregexp",
					},
					"saadparwaiz1/cmp_luasnip",
				},
			},
			{ "jay-babu/mason-null-ls.nvim" },
			{ "nvimtools/none-ls.nvim" },
			{ "mfussenegger/nvim-dap" },
			{ "jay-babu/mason-nvim-dap.nvim" },
			{ "leoluz/nvim-dap-go" },
			{ "rcarriga/nvim-dap-ui" },
			{ "theHamsta/nvim-dap-virtual-text" },
			{ "nvim-neotest/nvim-nio" },
			{ "WhoIsSethDaniel/mason-tool-installer.nvim" },
			{ "j-hui/fidget.nvim", opts = {} },
			{ "b0o/SchemaStore.nvim" },
		},
		config = function()
			local lsp_zero = require("lsp-zero")

			lsp_zero.on_attach(function(client, bufnr)
				lsp_zero.default_keymaps({
					buffer = bufnr,
					preserve_mappings = false,
				})
				-- lsp_zero.buffer_autoformat()
				-- only enable the above if you have exactly one active server attach to the buffer per filetype
			end)

			--[[
			lsp_zero.format_on_save({
				format_opts = {
					async = false,
					timeout_ms = 10000,
				},
				servers = {
					['tsserver'] = { 'javascript', 'typescript' },
					['rust_analyzer'] = { 'rust' },
				}
			})
			]]

			require("mason").setup()
			require("mason-tool-installer").setup({
				ensure_installed = {
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
					"typos_lsp",

					-- bash
					"bashls",
					"shellcheck",
					"shfmt",
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
				},
				auto_update = true,
				integrations = {
					["mason-lspconfig"] = true,
					["mason-null-ls"] = true,
					["mason-nvim-dap"] = true,
				},
			})
			--[[
			local capabilities = nil
			if pcall(require, "cmp_nvim_lsp") then
				capabilities = require("cmp_nvim_lsp").default_capabilities()
			end
            ]]
			--[[
			local capabilities = vim.lsp.protocol.make_client_capabilities()
			capabilities = vim.tbl_deep_extend("force", capabilities, require("cmp_nvim_lsp").default_capabilities())
            ]]
			require("mason-lspconfig").setup({
				automatic_installation = false,
				handlers = {
					lsp_zero.default_setup,
					--[[
					function(server_name)
						local server = servers[server_name] or {}
						server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})
						require("lspconfig")[server_name].setup(server)
					end,
                    ]]
				},
			})
			require("mason-nvim-dap").setup({
				automatic_installation = false,
				handlers = {},
			})
			require("mason-null-ls").setup({
				automatic_installation = false,
				handlers = {},
			})
			require("null-ls").setup({
				sources = {},
			})

			local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
			local lsp_format_on_save = function(bufnr)
				vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
				vim.api.nvim_create_autocmd("BufWritePre", {
					group = augroup,
					buffer = bufnr,
					callback = function()
						vim.lsp.buf.format()
					end,
				})
			end
			lsp_zero.on_attach(function(client, bufnr)
				vim.keymap.set("n", "K", function()
					vim.lsp.buf.hover()
				end, { buffer = bufnr, remap = false, desc = "LSP display symbol information" })
				vim.keymap.set("n", "gd", function()
					vim.lsp.buf.definition()
				end, { buffer = bufnr, remap = false, desc = "LSP go to definition" })
				vim.keymap.set("n", "gD", function()
					vim.lsp.buf.declaration()
				end, { buffer = bufnr, remap = false, desc = "LSP go to declaration" })
				vim.keymap.set("n", "gi", function()
					vim.lsp.buf.implementation()
				end, { buffer = bufnr, remap = false, desc = "LSP go to implementation" })
				vim.keymap.set("n", "go", function()
					vim.lsp.buf.type_definition()
				end, { buffer = bufnr, remap = false, desc = "LSP go to type definition" })
				vim.keymap.set("n", "gr", function()
					vim.lsp.buf.references()
				end, { buffer = bufnr, remap = false, desc = "LSP go to references" })
				vim.keymap.set("n", "gs", function()
					vim.lsp.buf.signature_help()
				end, { buffer = bufnr, remap = false, desc = "LSP display signature help" })
				vim.keymap.set("n", "<F2>", function()
					vim.lsp.buf.rename()
				end, { buffer = bufnr, remap = false, desc = "LSP rename symbol" })
				vim.keymap.set({ "n", "x" }, "<F3>", function()
					vim.lsp.buf.format({ async = true })
				end, { buffer = bufnr, remap = false, desc = "LSP format file" })
				vim.keymap.set("n", "<F4>", function()
					vim.lsp.buf.code_action()
				end, { buffer = bufnr, remap = false, desc = "LSP browse code actions" })
				vim.keymap.set("n", "gl", function()
					vim.diagnostic.open_float()
				end, { buffer = bufnr, remap = false, desc = "LSP browse diagnostic in float" })
				vim.keymap.set("n", "[d", function()
					vim.diagnostic.goto_prev()
				end, { buffer = bufnr, remap = false, desc = "LSP jump to previous diagnostic" })
				vim.keymap.set("n", "]d", function()
					vim.diagnostic.goto_next()
				end, { buffer = bufnr, remap = false, desc = "LSP jump to next diagnostic" })
				vim.keymap.set("i", "<C-z>", function()
					vim.lsp.buf.signature_help()
				end, { buffer = bufnr, remap = false, desc = "LSP display signature help" })
				vim.keymap.set("n", "<C-A-Q>", function()
					vim.lsp.buf.workspace_symbol()
				end, { buffer = bufnr, remap = false, desc = "LSP query workspace symbol" })

				lsp_format_on_save(bufnr)
			end)
			lsp_zero.setup()

			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
				callback = function(event)
					local client = vim.lsp.get_client_by_id(event.data.client_id)
					local map = function(keys, func, desc)
						vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
					end
					if client and client.server_capabilities.documentHighlightProvider then
						local highlight_augroup = vim.api.nvim_create_augroup("lsp-highlight", { clear = false })
						vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
							buffer = event.buf,
							group = highlight_augroup,
							callback = vim.lsp.buf.document_highlight,
						})
						vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
							buffer = event.buf,
							group = highlight_augroup,
							callback = vim.lsp.buf.clear_references,
						})
						vim.api.nvim_create_autocmd("LspDetach", {
							group = vim.api.nvim_create_augroup("lsp-detach", { clear = true }),
							callback = function(event2)
								vim.lsp.buf.clear_references()
								vim.api.nvim_clear_autocmds({ group = "lsp-highlight", buffer = event2.buf })
							end,
						})
					end
					if client and client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
						map("<leader>th", function()
							vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
						end, "[T]oggle Inlay [H]ints")
					end
				end,
			})

			require("dapui").setup()
			require("nvim-dap-virtual-text").setup()
			require("dap-go").setup()
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
			]]

			require("lspkind").init()
			local cmp = require("cmp")
			local cmp_action = require("lsp-zero").cmp_action()
			-- local cmp_format = require("lsp-zero").cmp_format({ details = true })
			require("luasnip.loaders.from_vscode").lazy_load()
			cmp.setup({
				sources = {
					{ name = "nvim_lsp" },
					{ name = "nvim_lsp_signature_help" },
					{ name = "buffer" },
					{ name = "path" },
					{ name = "cmdline" },
					{ name = "luasnip" },
				},
				mapping = cmp.mapping.preset.insert({
					["<C-p>"] = cmp.mapping(function()
						if cmp.visible() then
							cmp.select_prev_item({ behavior = "insert" })
						else
							cmp.complete()
						end
					end),
					["<C-n>"] = cmp.mapping(function()
						if cmp.visible() then
							cmp.select_next_item({ behavior = "insert" })
						else
							cmp.complete()
						end
					end),
					["<C-y>"] = cmp.mapping(
						cmp.mapping.confirm({
							behavior = cmp.ConfirmBehavior.Insert,
							select = true,
						}),
						{ "i", "c" }
					),
					-- ["<C-Space>"] = cmp.mapping.complete(),
					["<C-u>"] = cmp.mapping.scroll_docs(-4),
					["<C-d>"] = cmp.mapping.scroll_docs(4),
					["<C-f>"] = cmp_action.luasnip_jump_forward(),
					["<C-b>"] = cmp_action.luasnip_jump_backward(),
				}),
				snippet = {
					expand = function(args)
						vim.snippet.expand(args.body)
					end,
				},
				-- formatting = cmp_format,
				formatting = {
					fields = { "abbr", "kind", "menu" },
					format = require("lspkind").cmp_format({
						mode = "symbol",
						maxwidth = 50,
						ellipsis_char = "...",
					}),
					details = true,
				},
				preselect = "item",
				completion = {
					-- autocomplete = true,
					completeopt = "menu,menuone,noinsert",
				},
				window = {
					completion = cmp.config.window.bordered(),
					documentation = cmp.config.window.bordered(),
				},
			})
			cmp.setup.filetype({ "sql" }, {
				sources = {
					{ name = "vim-dadbod-completion" },
					{ name = "buffer" },
				},
			})
			local ls = require("luasnip")
			ls.config.set_config({
				history = false,
				updateevents = "TextChanged,TextChangedI",
			})
			for _, ft_path in ipairs(vim.api.nvim_get_runtime_file("lua/snippets/*.lua", true)) do
				loadfile(ft_path)()
			end
			vim.keymap.set({ "i", "s" }, "<c-k>", function()
				if ls.expand_or_jumpable() then
					ls.expand_or_jump()
				end
			end, { silent = true })
			vim.keymap.set({ "i", "s" }, "<c-j>", function()
				if ls.jumpable(-1) then
					ls.jump(-1)
				end
			end, { silent = true })
			vim.diagnostic.config({
				virtual_text = true,
			})
		end,
	},

	{ -- Testing Integration
		"nvim-neotest/neotest",
		dependencies = {
			"nvim-neotest/nvim-nio",
			"nvim-lua/plenary.nvim",
			"antoinemadec/FixCursorHold.nvim",
			"nvim-treesitter/nvim-treesitter",
			"nvim-neotest/neotest-python",
			"nvim-neotest/neotest-plenary",
			"nvim-neotest/neotest-go",
			"rouge8/neotest-rust",
			"rcasia/neotest-bash",
			"alfaix/neotest-gtest",
			"nvim-neotest/neotest-jest",
			"marilari88/neotest-vitest",
			"stevanmilic/neotest-scala",
		},
		config = function()
			local neotest_ns = vim.api.nvim_create_namespace("neotest")
			vim.diagnostic.config({
				virtual_text = {
					format = function(diagnostic)
						local message =
							diagnostic.message:gsub("\n", " "):gsub("\t", " "):gsub("%s+", " "):gsub("^%s+", "")
						return message
					end,
				},
			}, neotest_ns)
			require("neotest").setup({
				adapters = {
					require("neotest-go")({
						experimental = {
							test_table = true,
						},
						args = {
							"-count=1",
							"-timeout=60s",
							"-race",
							"-v",
							"-cover",
							"-covermode=count" --[[set to `atomic` if run parallel]],
						},
						recursive_run = true,
					}),
					require("neotest-rust")({
						args = { "--no-capture" },
						dap_adapter = "lldb",
					}),
					require("neotest-jest")({
						jestCommand = "npm test --",
						-- jestCommand = require("neotest-jest.jest-util").getJestCommand(vim.fn.expand("%:p:h"))
						-- 	.. " --watch",
						jestConfigFile = "custom.jest.config.ts",
						env = { CI = true },
						cwd = function(path)
							return vim.fn.getcwd()
						end,
					}),
					require("neotest-vitest")({
						filter_dir = function(name, rel_path, root)
							return name ~= "node_modules"
						end,
					}),
					require("neotest-scala")({
						runner = "sbt",
						framework = "scalatest",
					}),
					require("neotest-gtest").setup({}),
					require("neotest-python")({
						dap = { justMyCode = false },
					}),
					require("neotest-plenary"),
					require("neotest-bash"),
				},
			})
		end,
	},

	{
		"scalameta/nvim-metals",
		dependencies = {
			"nvim-lua/plenary.nvim",
			{
				"mfussenegger/nvim-dap",
				config = function(self, opts)
					local dap = require("dap")
					dap.configurations.scala = {
						{
							type = "scala",
							request = "launch",
							name = "RunOrTest",
							metals = {
								runType = "runOrTestFile",
								--args = { "firstArg", "secondArg", "thirdArg" }, -- here just as an example
							},
						},
						{
							type = "scala",
							request = "launch",
							name = "Test Target",
							metals = {
								runType = "testTarget",
							},
						},
					}
				end,
			},
		},
		ft = {
			"scala",
			"sbt",
			-- "java", -- use LSP's for now
		},
		opts = function()
			local metals_config = require("metals").bare_config()
			metals_config.settings = {
				showImplicitArguments = true,
				excludedPackages = { "akka.actor.typed.javadsl", "com.github.swagger.akka.javadsl" },
			}
			metals_config.init_options.statusBarProvider = "off" -- use fidget
			metals_config.capabilities = require("cmp_nvim_lsp").default_capabilities()
			metals_config.on_attach = function(client, bufnr)
				require("metals").setup_dap()
			end
			return metals_config
		end,
		config = function(self, metals_config)
			local nvim_metals_group = vim.api.nvim_create_augroup("nvim-metals", { clear = true })
			vim.api.nvim_create_autocmd("FileType", {
				pattern = self.ft,
				callback = function()
					require("metals").initialize_or_attach(metals_config)
				end,
				group = nvim_metals_group,
			})
			require("telescope").load_extension("metals")
		end,
	},

	{ -- Code Objects
		"nvim-treesitter/nvim-treesitter",
		dependencies = { "windwp/nvim-ts-autotag" },
		build = ":TSUpdate",
		config = function()
			require("nvim-treesitter.install").compilers = { "clang" }
			require("nvim-treesitter.configs").setup({
				ensure_installed = {
					"bash",
					"c",
					"cmake",
					"cpp",
					"css",
					"csv",
					"dart",
					"dockerfile",
					"git_config",
					"git_rebase",
					"gitattributes",
					"gitcommit",
					"gitignore",
					"glsl",
					"go",
					"gomod",
					"gosum",
					"gowork",
					"graphql",
					"helm",
					"html",
					"http",
					"java",
					"javascript",
					"json",
					"lua",
					"make",
					"markdown",
					"markdown_inline",
					"proto",
					"python",
					"query",
					"rust",
					"scala",
					"scss",
					"sql",
					"toml",
					"typescript",
					"vim",
					"vimdoc",
					"xml",
					"yaml",
				},
				sync_install = false,
				auto_install = true,
				highlight = {
					enable = true,
					additional_vim_regex_highlighting = false,
				},
				autotag = {
					enable = true,
				},
			})
		end,
	},

	{ -- Neovim Dev
		{
			"folke/lazydev.nvim",
			ft = "lua",
			opts = {
				library = {
					"LazyVim",
					"/luvit-meta/library",
					"nvim-dap-ui",
					"neotest",
				},
			},
		},
		{ "Bilal2453/luvit-meta", lazy = true },
		{ -- optional completion source for require statements and module annotations
			"hrsh7th/nvim-cmp",
			opts = function(_, opts)
				opts.sources = opts.sources or {}
				table.insert(opts.sources, {
					name = "lazydev",
					group_index = 0, -- set group index to 0 to skip loading LuaLS completions
				})
			end,
		},
	},

	{ -- Pin Headers
		"nvim-treesitter/nvim-treesitter-context",
	},

	{ -- Disect Token Tree
		"nvim-treesitter/playground",
	},

	{ -- Fuzzy Picker
		"nvim-telescope/telescope.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {},
	},

	{ -- Smart Open
		"danielfalk/smart-open.nvim",
		branch = "0.2.x",
		config = function()
			require("telescope").load_extension("smart_open")
		end,
		dependencies = {
			"kkharji/sqlite.lua",
			-- Only required if using match_algorithm fzf
			{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
			-- Optional.  If installed, native fzy will be used when match_algorithm is fzy
			{ "nvim-telescope/telescope-fzy-native.nvim" },
		},
	},

	{ -- Folding
		"kevinhwang91/nvim-ufo",
		dependencies = { "kevinhwang91/promise-async" },
		config = function()
			local capabilities = vim.lsp.protocol.make_client_capabilities()
			capabilities.textDocument.foldingRange = {
				dynamicRegistration = false,
				lineFoldingOnly = true,
			}
			local language_servers = require("lspconfig").util.available_servers()
			for _, ls in ipairs(language_servers) do
				require("lspconfig")[ls].setup({
					capabilities = capabilities,
				})
			end
			local handler = function(virtText, lnum, endLnum, width, truncate)
				local newVirtText = {}
				local suffix = (" 󰁂 %d "):format(endLnum - lnum)
				local sufWidth = vim.fn.strdisplaywidth(suffix)
				local targetWidth = width - sufWidth
				local curWidth = 0
				for _, chunk in ipairs(virtText) do
					local chunkText = chunk[1]
					local chunkWidth = vim.fn.strdisplaywidth(chunkText)
					if targetWidth > curWidth + chunkWidth then
						table.insert(newVirtText, chunk)
					else
						chunkText = truncate(chunkText, targetWidth - curWidth)
						local hlGroup = chunk[2]
						table.insert(newVirtText, { chunkText, hlGroup })
						chunkWidth = vim.fn.strdisplaywidth(chunkText)
						-- str width returned from truncate() may less than 2nd argument, need padding
						if curWidth + chunkWidth < targetWidth then
							suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
						end
						break
					end
					curWidth = curWidth + chunkWidth
				end
				table.insert(newVirtText, { suffix, "MoreMsg" })
				return newVirtText
			end
			require("ufo").setup({
				fold_virt_text_handler = handler,
			})
			-- require("ufo").setup({
			-- 	provider_selector = function(bufnr, filetype, buftype)
			-- 		return { "treesitter", "indent" }
			-- 	end,
			-- })
		end,
	},

	{ -- Surround Motions and Clues
		"echasnovski/mini.nvim",
		version = "*",
		config = function()
			require("mini.ai").setup({ n_lines = 500 })
			require("mini.surround").setup()
			require("mini.pairs").setup()
			require("mini.operators").setup({
				evaluate = {
					prefix = "g=",
					func = nil,
				},
				exchange = {
					prefix = "<leader>xx",
					reindent_linewise = true,
				},
				multiply = {
					prefix = "gm",
					func = nil,
				},
				replace = {
					prefix = "<leader>xr",
					reindent_linewise = true,
				},
				sort = {
					prefix = "<leader>xs",
					func = nil,
				},
			})
			local miniclue = require("mini.clue")
			miniclue.setup({
				triggers = {
					-- Leader triggers
					{ mode = "n", keys = "<Leader>" },
					{ mode = "x", keys = "<Leader>" },
					-- Built-in completion
					{ mode = "i", keys = "<C-x>" },
					-- `g` key
					{ mode = "n", keys = "g" },
					{ mode = "x", keys = "g" },
					-- Marks
					{ mode = "n", keys = "'" },
					{ mode = "n", keys = "`" },
					{ mode = "x", keys = "'" },
					{ mode = "x", keys = "`" },
					-- Registers
					{ mode = "n", keys = '"' },
					{ mode = "x", keys = '"' },
					{ mode = "i", keys = "<C-r>" },
					{ mode = "c", keys = "<C-r>" },
					-- Window commands
					{ mode = "n", keys = "<C-w>" },
					-- `z` key
					{ mode = "n", keys = "z" },
					{ mode = "x", keys = "z" },
				},
				clues = {
					miniclue.gen_clues.builtin_completion(),
					miniclue.gen_clues.g(),
					miniclue.gen_clues.marks(),
					miniclue.gen_clues.registers(),
					miniclue.gen_clues.windows(),
					miniclue.gen_clues.z(),
				},
				window = {
					config = {
						width = "auto",
					},
					delay = 1000,
					scroll_down = "<C-d>",
					scroll_up = "<C-u>",
				},
			})
			local hipatterns = require("mini.hipatterns")
			hipatterns.setup({
				highlighters = {
					-- Highlight standalone 'FIXME', 'HACK', 'TODO', 'NOTE'
					fixme = { pattern = "%f[%w]()FIXME()%f[%W]", group = "MiniHipatternsFixme" },
					hack = { pattern = "%f[%w]()HACK()%f[%W]", group = "MiniHipatternsHack" },
					todo = { pattern = "%f[%w]()TODO()%f[%W]", group = "MiniHipatternsTodo" },
					note = { pattern = "%f[%w]()NOTE()%f[%W]", group = "MiniHipatternsNote" },
					-- Highlight hex color strings (`#rrggbb`) using that color
					hex_color = hipatterns.gen_highlighter.hex_color(),
				},
			})
			--[[
			local statusline = require 'mini.statusline'
			statusline.setup { use_icons = vim.g.have_nerd_font }
			---@diagnostic disable-next-line: duplicate-set-field
			statusline.section_location = function()
				return '%2l:%-2v'
			end
			]]
		end,
	},

	{ -- Indentation Guides
		"lukas-reineke/indent-blankline.nvim",
		main = "ibl",
		opts = {
			indent = {
				char = "┊",
				priority = 2,
				-- highlight = { "Function", "Label" },
			},
			scope = {
				enabled = true,
				priority = 500,
			},
		},
	},

	{ -- Improved Floating UIs
		"stevearc/dressing.nvim",
		opts = {},
	},

	--[[
	{ -- Theme Tokyo Night
		"folke/tokyonight.nvim",
		lazy = false,
		priority = 1000,
		opts = {},
		config = function()
			require("tokyonight").setup({
				-- rose-pine
				disable_background = true,
				disable_float_background = true,
				-- tokyonight
				transparent = true,
				on_highlights = function(hl, c)
					local textColor = c.fg_dark
					hl.TelescopeNormal = {
						-- bg = c.bg_dark,
						bg = 'none',
						fg = textColor,
					}
					hl.TelescopeBorder = {
						-- bg = c.bg_dark,
						bg = 'none',
						fg = textColor,
					}
					hl.TelescopePromptNormal = {
						-- bg = prompt,
						bg = 'none',
						fg = textColor,
					}
					hl.TelescopePromptBorder = {
						-- bg = prompt,
						bg = 'none',
						fg = textColor,
					}
					hl.TelescopePromptTitle = {
						-- bg = prompt,
						bg = 'none',
						fg = textColor,
					}
					hl.TelescopePreviewTitle = {
						-- bg = c.bg_dark,
						bg = 'none',
						fg = textColor,
					}
					hl.TelescopeResultsTitle = {
						-- bg = c.bg_dark,
						bg = 'none',
						fg = textColor,
					}
				end,
			})
			function ColorMyPencils(color)
				color = color or "tokyonight"
				vim.cmd.colorscheme(color)
				vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
				vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
			end
	
			ColorMyPencils()
		end,
	},
	]]

	--[[
	{ -- Theme Gruvbox
		"ellisonleao/gruvbox.nvim",
		priority = 1000,
		config = function()
			require("gruvbox").setup({
				transparent_mode = true,
			})
			vim.cmd.colorscheme("gruvbox")
		end,
		opts = ...,
	},
    ]]

	{ -- Theme Rose Pine
		"rose-pine/neovim",
		name = "rose-pine",
		lazy = false,
		priority = 1000,
		opts = {},
		config = function()
			require("rose-pine").setup({
				variant = "main",
				dark_variant = "main",
				enable = {
					legacy_highlights = false,
				},
				styles = {
					transparency = true,
				},
				-- disable_background = true,
				-- disable_float_background = true,
			})
			vim.cmd.colorscheme("rose-pine")
			-- function ColorMyPencils(color)
			-- 	color = color or "rose-pine"
			-- 	vim.cmd.colorscheme(color)
			-- 	vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
			-- 	vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
			-- end
			-- ColorMyPencils()
		end,
	},

	{ -- Inline Diagnostics
		"folke/trouble.nvim",
		dependencies = "nvim-tree/nvim-web-devicons",
		keys = {
			{
				"<leader>cc",
				"<cmd>Trouble diagnostics toggle focus=false filter.buf=0<cr>",
				desc = "Buffer Diagnostics (Trouble)",
			},
			{
				"<leader>cs",
				"<cmd>Trouble symbols toggle focus=false<cr>",
				desc = "Symbols (Trouble)",
			},
			{
				"<leader>cd",
				"<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
				desc = "LSP Definitions / references / ... (Trouble)",
			},
			{
				"<leader>ce",
				"<cmd>Trouble loclist toggle<cr>",
				desc = "Location List (Trouble)",
			},
			{
				"<leader>ca",
				"<cmd>Trouble qflist toggle<cr>",
				desc = "Quickfix List (Trouble)",
			},
		},
		opts = {},
	},

	{ -- Git Integration
		"sindrets/diffview.nvim",
		"lewis6991/gitsigns.nvim",
		"tpope/vim-fugitive",
		config = function()
			local Fugitive = vim.api.nvim_create_augroup("Fugitive", {})
			local autocmd = vim.api.nvim_create_autocmd
			autocmd("BufWinEnter", {
				group = Fugitive,
				pattern = "*",
				callback = function()
					if vim.bo.ft ~= "fugitive" then
						return
					end
					local bufnr = vim.api.nvim_get_current_buf()
					local opts = { buffer = bufnr, remap = false }
					vim.keymap.set("n", "<leader>p", function()
						vim.cmd.Git("push")
					end, opts)
					vim.keymap.set("n", "<leader>P", function()
						vim.cmd.Git({ "pull", "--rebase" })
					end, opts)
					vim.keymap.set("n", "<leader>t", ":Git push -u origin ", opts)
				end,
			})
		end,
	},

	{ -- Statusbar
		"nvim-lualine/lualine.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		opts = {
			options = {
				--theme = 'tokyonight',
				theme = "auto",
				section_separators = { left = "", right = "" },
				component_separators = { left = "", right = "" },
			},
			extensions = {
				"lazy",
				"fugitive",
				"mason",
				"nvim-dap-ui",
				"oil",
				"quickfix",
				"trouble",
			},
		},
	},

	{ -- Multifiles Jumper
		"ThePrimeagen/harpoon",
		branch = "harpoon2",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope.nvim",
		},
		opts = function()
			local harpoon = require("harpoon")
			harpoon:setup({})
			local conf = require("telescope.config").values
			local function toggle_telescope(harpoon_files)
				local file_paths = {}
				for _, item in ipairs(harpoon_files.items) do
					table.insert(file_paths, item.value)
				end
				require("telescope.pickers")
					.new({}, {
						prompt_title = "Harpoon",
						finder = require("telescope.finders").new_table({
							results = file_paths,
						}),
						previewer = conf.file_previewer({}),
						sorter = conf.generic_sorter({}),
					})
					:find()
			end
			vim.keymap.set("n", "<C-A-Z>", function()
				toggle_telescope(harpoon:list())
			end, { desc = "Open harpoon window" })
		end,
	},

	{ -- Refactoring
		"ThePrimeagen/refactoring.nvim",
		config = function()
			require("telescope").load_extension("refactoring")
		end,
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-treesitter/nvim-treesitter",
		},
		opts = {
			prompt_func_return_type = {
				go = true,
				java = true,
				cpp = true,
				c = true,
				h = true,
				hpp = true,
				cxx = true,
			},
			prompt_func_param_type = {
				go = true,
				java = true,
				cpp = true,
				c = true,
				h = true,
				hpp = true,
				cxx = true,
			},
			printf_statements = {},
			print_var_statements = {},
			show_success_message = true,
		},
	},

	{ -- Disect Undo Tree
		"mbbill/undotree",
	},

	{ -- LaTeX
		"lervag/vimtex",
	},

	{ -- Markdown
		"MeanderingProgrammer/markdown.nvim",
		name = "render-markdown",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		config = function()
			require("render-markdown").setup({
				start_enabled = true,
				max_file_size = 4.0,
			})
		end,
	},

	{ -- SQL/NoSQL Client
		"tpope/vim-dadbod",
		"kristijanhusak/vim-dadbod-completion",
		"kristijanhusak/vim-dadbod-ui",
	},

	{ -- File Manager
		"stevearc/oil.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("oil").setup({
				columns = { "icon" },
				keymaps = {},
				view_options = {
					show_hidden = true,
				},
			})
		end,
	},

	{
		"eandrju/cellular-automaton.nvim",
		config = function()
			-- local config = {
			-- 	fps = 50,
			-- 	name = "slide",
			-- }
			-- config.init = function(grid) end
			-- config.update = function(grid)
			-- 	for i = 1, #grid do
			-- 		local prev = grid[i][#grid[i]]
			-- 		for j = 1, #grid[i] do
			-- 			grid[i][j], prev = prev, grid[i][j]
			-- 		end
			-- 	end
			-- 	return true
			-- end
			-- require("cellular-automaton").register_animation(config)
		end,
	},
}
