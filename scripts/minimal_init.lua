local root = vim.fn.fnamemodify('.', ':p')
vim.opt.rtp:prepend(root)
vim.opt.rtp:append(root .. 'deps/mini.nvim')
package.path = root .. '?.lua;' .. root .. '?/init.lua;' .. package.path
require('mini.test').setup()
