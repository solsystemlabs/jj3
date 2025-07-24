" jj.nvim - Neovim plugin for jujutsu integration
" This file provides compatibility with traditional plugin managers

if exists('g:loaded_jj_nvim')
  finish
endif
let g:loaded_jj_nvim = 1

" Initialize the plugin
lua require('jj').setup()