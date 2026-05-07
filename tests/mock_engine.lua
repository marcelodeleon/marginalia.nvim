local M = {}

M._active = false
M._file = "test_file.lua"
M._after_buf = nil
M._before_buf = nil
M._on_close_cb = nil

function M.open(_source)
    M._active = true
    M._before_buf = vim.api.nvim_create_buf(false, true)
    M._after_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(M._after_buf, 0, -1, false, {
        "line 1", "line 2", "line 3", "line 4", "line 5",
        "line 6", "line 7", "line 8", "line 9", "line 10",
    })
    vim.api.nvim_set_current_buf(M._after_buf)
end

function M.close()
    M._active = false
    if M._on_close_cb then M._on_close_cb() end
    if M._before_buf and vim.api.nvim_buf_is_valid(M._before_buf) then
        vim.api.nvim_buf_delete(M._before_buf, { force = true })
    end
    if M._after_buf and vim.api.nvim_buf_is_valid(M._after_buf) then
        vim.api.nvim_buf_delete(M._after_buf, { force = true })
    end
    M._before_buf = nil
    M._after_buf = nil
end

function M.current_file()
    return M._file
end

function M.side_of(bufnr)
    if bufnr == M._after_buf then return "after" end
    if bufnr == M._before_buf then return "before" end
    return nil
end

function M.on_buffer_ready(cb)
    if M._after_buf then
        cb(M._after_buf, "after")
    end
end

function M.on_close(cb)
    M._on_close_cb = cb
end

function M.is_active()
    return M._active
end

function M.get_buffer_pair()
    return { before = M._before_buf, after = M._after_buf }
end

function M.reset()
    if M._active then M.close() end
    M._file = "test_file.lua"
    M._on_close_cb = nil
end

return M
