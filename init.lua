vim.opt.clipboard:append({ "unnamed", "unnamedplus" })
vim.opt.winborder = 'rounded'
vim.opt.inccommand = 'split'
vim.opt.signcolumn = 'yes'
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.showcmd = true
vim.opt.undofile = true
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.cursorcolumn = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.expandtab = true
vim.opt.breakindent = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.softtabstop = 4

vim.g.mapleader = " "
vim.g.loaded_netrw = 0
vim.g.loaded_netrwPlugin = 0
vim.g.have_nerd_font = true

vim.pack.add({
    { src = 'https://github.com/ellisonleao/gruvbox.nvim' },
    { src = 'https://github.com/nvim-treesitter/nvim-treesitter' }, -- wrappers for built-in
    { src = 'https://github.com/neovim/nvim-lspconfig' },           -- wrappers for built-in
    { src = 'https://github.com/stevearc/oil.nvim' },
    { src = 'https://github.com/nvim-tree/nvim-web-devicons' },     -- fzf-lua dep
    { src = 'https://github.com/ibhagwan/fzf-lua' },
    { src = 'https://github.com/j-hui/fidget.nvim' },
    { src = 'https://github.com/chomosuke/typst-preview.nvim' },  -- typst live preview
    { src = 'https://github.com/brianhuster/live-preview.nvim' }, -- markdown, html, csv live preview
})

vim.opt.background = 'light'
vim.cmd.colorscheme('gruvbox')
vim.cmd(':hi statusline guibg=NONE')

require('fzf-lua').setup({
    'fzf-native',
    winopts = {
        preview = {
            default = 'bat',
        },
    },
    previewers = {
        bat = {
            cmd = "bat",
            args = "--theme=gruvbox-light --color=always --style=numbers,changes",
        },
    },
})

vim.lsp.enable({
    'lua_ls',
    'clangd',
    'gopls',
    'rust_analyzer',
    'pyright',
    'ts_ls',
    'html',
    'cssls',
    'svelte',
    'bashls',
    'powershell_es',
    'metals',
    'jdtls',
    'csharp_ls',
    'dartls',
    'tinymist',
    'docker_language_server',
    'docker_compose_language_service',
    'yamlls',
    'tombi',
    'intelephense',
    'codebook'
})

vim.lsp.config('lua_ls', {
    settings = {
        Lua = {
            workspace = {
                library = vim.api.nvim_get_runtime_file('', true),
            },
        },
    },
})

vim.lsp.config('*', {
    capabilities = {
        textDocument = {
            semanticTokens = {
                multilineTokenSupport = true,
            }
        },
        workspace = {
            didChangeWatchedFiles = {
                dynamicRegistration = true,
            },
        },
    },
    root_markers = { '.git' },
})

vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_completion) then
            vim.opt.completeopt = { 'menu', 'menuone', 'noinsert', 'fuzzy', 'popup' }
            vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
        end
    end,
})
vim.cmd("set completeopt+=noselect")

vim.diagnostic.config({
    virtual_lines = { current_line = true },
})

-- autosave on leaving insert mode
vim.o.autowriteall = true
vim.api.nvim_create_autocmd({ 'InsertLeavePre', 'TextChanged', 'TextChangedP' }, {
    pattern = '*',
    callback = function()
        vim.cmd('silent! write')
    end,
})

require('nvim-treesitter.configs').setup({
    auto_install = true,
    highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
    },
})

require('oil').setup()
require('nvim-web-devicons').setup()
require('fidget').setup({})
require('typst-preview').setup()
require('livepreview').setup()

vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Open parent directory' })
vim.keymap.set('n', '<leader>q', ':quit<CR>')
vim.keymap.set('n', '<leader>x', ':w<CR>:so<CR>')
vim.keymap.set('n', '<leader>\'', ':sf #<CR>')
vim.keymap.set('n', '<leader>pt', ':TypstPreviewToggle<CR>')
vim.keymap.set('n', '<leader>ps', ':LivePreview start .<CR>')
vim.keymap.set('n', '<leader>pc', ':LivePreview close<CR>')
vim.keymap.set('n', '<leader>;', ':LivePreview pick<CR>')
vim.keymap.set('n', '<leader>b', vim.lsp.buf.format)
vim.keymap.set('n', '<leader>u', vim.pack.update)
vim.keymap.set('n', '<leader>e', FzfLua.global)
vim.keymap.set('n', '<leader>n', FzfLua.combine)
vim.keymap.set('n', '<leader>/', FzfLua.grep_curbuf)
vim.keymap.set('n', '<leader>z', FzfLua.live_grep_native)
vim.keymap.set('n', '<leader>f', FzfLua.files)
vim.keymap.set('n', '<leader>h', FzfLua.helptags)
vim.keymap.set('n', '<leader>k', FzfLua.keymaps)
vim.keymap.set('n', '<leader>l', FzfLua.loclist)
vim.keymap.set('n', '<leader>m', FzfLua.marks)
vim.keymap.set('n', '<leader>t', FzfLua.quickfix)
vim.keymap.set('n', '<leader>gf', FzfLua.git_files)
vim.keymap.set('n', '<leader>gs', FzfLua.git_status)
vim.keymap.set('n', '<leader>gd', FzfLua.git_diff)
vim.keymap.set('n', '<leader>gh', FzfLua.git_hunks)
vim.keymap.set('n', '<leader>gc', FzfLua.git_commits)
vim.keymap.set('n', '<leader>gl', FzfLua.git_blame)
vim.keymap.set('n', '<leader>gb', FzfLua.git_branches)
vim.keymap.set('n', '<leader>gt', FzfLua.git_tags)
vim.keymap.set('n', '<leader>gk', FzfLua.git_stash)
vim.keymap.set('n', '<leader>\\', FzfLua.lsp_finder)
vim.keymap.set('n', '<leader>dd', FzfLua.lsp_document_diagnostics)
vim.keymap.set('n', '<leader>dw', FzfLua.lsp_workspace_diagnostics)
vim.keymap.set('n', '<leader>,', FzfLua.lsp_incoming_calls)
vim.keymap.set('n', '<leader>.', FzfLua.lsp_outgoing_calls)
vim.keymap.set('n', '<leader>a', FzfLua.lsp_code_actions)
vim.keymap.set('n', '<leader>s', FzfLua.lsp_document_symbols)
vim.keymap.set('n', '<leader>w', FzfLua.lsp_live_workspace_symbols)
vim.keymap.set('n', '<leader>r', FzfLua.lsp_references)
vim.keymap.set('n', '<leader>i', FzfLua.lsp_implementations)
vim.keymap.set('n', '<leader>o', FzfLua.lsp_typedefs)
vim.keymap.set('n', '<leader>j', FzfLua.lsp_definitions)
vim.keymap.set('n', '<leader>v', FzfLua.lsp_declarations)
