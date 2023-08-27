if exists('g:loaded_lgh') | finish | endif " prevent loading file twice

let s:save_cpo = &cpo " save user coptions
set cpo&vim " reset them to defaults

" Autocommand for all files
augroup lgh.nvim
	autocmd!
	autocmd BufWritePost * lua require('lgh').backup_file(vim.fn.expand("%:p:h"), vim.fn.expand("%:t"))
augroup END

com! LGHFix lua require('lgh').fix_dangling()
com! LGHistory lua require('lgh').show_history(vim.fn.expand("%:p:h"), vim.fn.expand("%:t"))

let &cpo = s:save_cpo " and restore after
unlet s:save_cpo

let g:loaded_lgh = 1
