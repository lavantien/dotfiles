" GENERAL CONFIGS --------------------------------------------------------- {{{
set number
set relativenumber
set cursorline
set cursorcolumn
set shiftwidth=4
set tabstop=4
set nobackup
set scrolloff=10
set nowrap
set incsearch
set ignorecase
set smartcase
set showcmd
set showmode
set showmatch
set hlsearch
set history=1000
set wildmode=list:longest
set wildignore=*.docx,*.jpg,*.png,*.gif,*.pdf,*.exe,*.xlsx,*pptx
set termguicolors
" }}}

" PLUGINS ----------------------------------------------------------------- {{{
call plug#begin('~/.vim/plugged')
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'folke/tokyonight.nvim', { 'branch': 'main' }

Plug 'ryanoasis/vim-devicons'
Plug 'kyazdani42/nvim-web-devicons'

Plug 'nvim-lua/plenary.nvim'
Plug 'lewis6991/gitsigns.nvim'
Plug 'feline-nvim/feline.nvim'

Plug 'neovim/nvim-lspconfig'
Plug 'mfussenegger/nvim-dap'
Plug 'rcarriga/nvim-dap-ui'
Plug 'theHamsta/nvim-dap-virtual-text'
Plug 'ray-x/guihua.lua'
Plug 'ray-x/go.nvim'

Plug 'williamboman/nvim-lsp-installer'
call plug#end()
" }}}

" MAPPINGS ---------------------------------------------------------------- {{{
let mapleader = " "

colorscheme tokyonight
" }}}

" SCRIPTS ----------------------------------------------------------------- {{{
lua require('gitsigns').setup()
lua require('feline').setup()

" nvim-lsp-installer default
lua <<EOF
local lsp_installer = require("nvim-lsp-installer")
lsp_installer.on_server_ready(function(server)
	local opts = {}
	server:setup(opts)
end)

EOF

" go.nvim default + integrate with lsp-installer
lua <<EOF
require 'go'.setup({
	goimport = 'gopls', -- if set to 'gopls' will use golsp format
	gofmt = 'gopls', -- if set to gopls will use golsp format
	max_line_len = 120,
	tag_transform = false,
	test_dir = '',
	comment_placeholder = '   ',
	lsp_cfg = true, -- false: use your own lspconfig
	lsp_gofumpt = true, -- true: set default gofmt in gopls format to gofumpt
	lsp_on_attach = true, -- use on_attach from go.nvim
	dap_debug = true,
})

local protocol = require'vim.lsp.protocol'

-- integrate with lsp-installer (failed!)
local path = require 'nvim-lsp-installer.path'
local install_root_dir = path.concat {vim.fn.stdpath 'data', 'lsp_servers'}

require('go').setup({
	gopls_cmd = {install_root_dir .. '/go/gopls'},
	filstruct = 'gopls',
	dap_debug = true,
	dap_debug_gui = true
})

local lsp_installer_servers = require'nvim-lsp-installer.servers'

local server_available, requested_server = lsp_installer_servers.get_server("gopls")
if server_available then
	requested_server:on_ready(function ()
		local opts = require'go.lsp'.config() -- config() return the go.nvim gopls setup
		requested_server:setup(opts)
	end)
	if not requested_server:is_installed() then
		-- Queue the server to be installed
		requested_server:install()
	end
end

EOF

" Enable the marker method of folding.
augroup filetype_vim
	autocmd!
	autocmd FileType vim setlocal foldmethod=marker
augroup END

" If Vim version is equal to or greater than 7.3 enable undofile.
if version >= 703
	set undodir=~/.vim/backup
	set undofile
	set undoreload=10000
endif

" Display cursorline and cursorcolumn ONLY in active window.
augroup cursor_off
	autocmd!
	autocmd WinLeave * set nocursorline nocursorcolumn
	autocmd WinEnter * set cursorline cursorcolumn
augroup END
" }}}

