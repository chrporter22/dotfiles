vim.g.mapleader = " "

vim.opt.swapfile = false

-- Navigate vim panes better
vim.keymap.set('n', '<c-k>', ':wincmd k<CR>')
vim.keymap.set('n', '<c-j>', ':wincmd j<CR>')
vim.keymap.set('n', '<c-h>', ':wincmd h<CR>')
vim.keymap.set('n', '<c-l>', ':wincmd l<CR>')

vim.keymap.set('n', '<leader>h', ':nohlsearch<CR>')

vim.wo.number = true
vim.wo.relativenumber = true

vim.opt.cursorline = true
vim.cmd("set foldmethod=indent")
vim.opt.backup = false

-- Remap key bindings 
vim.cmd("imap <F5> <Esc>:w<CR>:!clear;python3 %<CR>")
vim.cmd("map <leader>ss :setlocal spell!<cr>")

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.textwidth = 89
vim.opt.foldlevel = 99

vim.cmd("set guicursor=n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50")
