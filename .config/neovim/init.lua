vim.cmd([[
    let nu = "true"
    let relativenumber = "true"
    let tabstop = 4
    let softtabstop = 4
    let shiftwidth = 4
    let expandtab = "true"
    let smartindent = "true"
    let wrap = "false"
    let swapfile = "false"
    let backup = "false"
    let undofile = "true"
    let hlsearch = "false"
    let incsearch = "true"
    let termguicolors = "true"
    let scrolloff = 4
    let signcolumn = "yes"
    let updatetime = 50
    let colorcolumn = ""
    let mapleader = " "

    nnoremap <C-d> <C-d>zz
    nnoremap <C-u> <C-u>zz
    nnoremap <C-b> <C-b>zz
    nnoremap <C-f> <C-f>zz
    vnoremap J :m '>+1<CR>gv=gv
    vnoremap K :m '<-2<CR>gv=gv
    nnoremap J mzJ`z
    nnoremap <C-d> <C-d>zz
    nnoremap <C-u> <C-u>zz
    nnoremap n nzzzv
    nnoremap N Nzzzv
    xnoremap <leader>p :"_dP
    noremap <leader>y :"+y
    nnoremap <leader>Y :"+Y
    noremap <leader>d :"_d
    inoremap <C-c> <Esc>
    nnoremap Q <nop>
    nnoremap <leader>f =
    nnoremap <C-k> <cmd>cnext<CR>zz
    nnoremap <C-j> <cmd>cprev<CR>zz
    nnoremap <leader>k <cmd>lnext<CR>zz
    nnoremap <leader>j <cmd>lprev<CR>zz
    tnoremap <Esc> <C-\\><C-n>
    tnoremap <A-j> <C-\\><C-n><C-w>j
    tnoremap <A-k> <C-\\><C-n><C-w>k
    tnoremap <A-h> <C-\\><C-n><C-w>h
    tnoremap <A-l> <C-\\><C-n><C-w>l
    inoremap <A-j> <C-\\><C-n><C-w>j
    inoremap <A-k> <C-\\><C-n><C-w>k
    inoremap <A-h> <C-\\><C-n><C-w>h
    inoremap <A-l> <C-\\><C-n><C-w>l
    nnoremap <A-j> <C-w>j
    nnoremap <A-k> <C-w>k
    nnoremap <A-h> <C-w>h
    nnoremap <A-l> <C-w>l
    nnoremap <A-t> <C-w>t
]])
