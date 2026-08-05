vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")
vim.cmd("set nu")
vim.cmd("set nocompatible")
vim.cmd("set showmatch")
vim.cmd("set ignorecase")
vim.cmd("set mouse=v")
vim.cmd("set hlsearch")
vim.cmd("set incsearch")
vim.cmd("set expandtab")
vim.cmd("set wildmode=longest,list")
vim.cmd("set cc=80")
-- remap leaders
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("config.lazy")
