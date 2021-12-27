return require('packer').startup(function()
  use 'wbthomason/packer.nvim'
  vim.cmd([[
    augroup packer_user_config
      autocmd!
      autocmd BufWritePost plugins.lua source <afile> | PackerCompile
    augroup end
  ]])
end)


