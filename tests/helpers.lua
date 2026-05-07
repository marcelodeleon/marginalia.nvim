local M = {}
local MiniTest = require('mini.test')

function M.new_child()
    local child = MiniTest.new_child_neovim()
    child.restart({ '-u', 'scripts/minimal_init.lua' })
    child.lua([[vim.opt.rtp:prepend('.')]])
    return child
end

function M.setup_child(child)
    child.lua([[require('marginalia').setup()]])
    return child
end

function M.create_scratch_buffer(child, lines)
    local lua_lines = vim.inspect(lines)
    local bufnr = child.lua_get(string.format([[
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, %s)
        vim.api.nvim_set_current_buf(buf)
        return buf
    ]], lua_lines))
    return bufnr
end

return M
