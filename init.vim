if exists('g:vscode')
    " VSCode extension
    nnoremap z= <Cmd>call VSCodeNotify('keyboard-quickfix.openQuickFix')<CR>
else
    " ordinary neovim
endif

