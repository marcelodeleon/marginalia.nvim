local MiniTest = require('mini.test')
local new_set = MiniTest.new_set

local T = new_set()

local ui

T['ui'] = new_set({
    hooks = {
        pre_case = function()
            ui = require('marginalia.ui')
            -- create a base buffer so floating windows have context
            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "base line 1", "base line 2" })
            vim.api.nvim_set_current_buf(buf)
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
        end,
        post_case = function()
            vim.wait(10)
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                local cfg = vim.api.nvim_win_get_config(win)
                if cfg.relative and cfg.relative ~= "" then
                    pcall(vim.api.nvim_win_close, win, true)
                end
            end
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                local name = vim.api.nvim_buf_get_name(buf)
                if name:match("marginalia://") then
                    pcall(vim.api.nvim_buf_delete, buf, { force = true })
                end
            end
        end,
    },
})

T['ui']['open_input creates a floating window'] = function()
    ui.open_input({})
    local wins = vim.api.nvim_list_wins()
    local floating = 0
    for _, win in ipairs(wins) do
        local cfg = vim.api.nvim_win_get_config(win)
        if cfg.relative and cfg.relative ~= "" then floating = floating + 1 end
    end
    MiniTest.expect.equality(floating >= 1, true)
end

T['ui']['input buffer has buftype acwrite and filetype markdown'] = function()
    ui.open_input({})
    local buf = vim.api.nvim_get_current_buf()
    MiniTest.expect.equality(vim.bo[buf].buftype, "acwrite")
    MiniTest.expect.equality(vim.bo[buf].filetype, "markdown")
end

T['ui']['input buffer named marginalia://comment/<id>'] = function()
    ui.open_input({})
    local buf = vim.api.nvim_get_current_buf()
    local name = vim.api.nvim_buf_get_name(buf)
    MiniTest.expect.equality(name:match("marginalia://comment/%d+") ~= nil, true)
end

T['ui']['open_input with initial pre-fills buffer lines'] = function()
    ui.open_input({ initial = "hello\nworld" })
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    MiniTest.expect.equality(lines[1], "hello")
    MiniTest.expect.equality(lines[2], "world")
end

T['ui']['write in input buffer calls on_submit with trimmed body'] = function()
    local submitted = nil
    ui.open_input({
        on_submit = function(body) submitted = body end,
    })
    local buf = vim.api.nvim_get_current_buf()
    vim.cmd("stopinsert")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "  my comment  ", "" })
    vim.cmd("write")
    MiniTest.expect.equality(submitted, "my comment")
end

T['ui']['write closes window and deletes buffer'] = function()
    ui.open_input({
        on_submit = function() end,
    })
    local buf = vim.api.nvim_get_current_buf()
    vim.cmd("stopinsert")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "content" })
    vim.cmd("write")
    vim.wait(50)
    MiniTest.expect.equality(vim.api.nvim_buf_is_valid(buf), false)
end

T['ui']['empty body on write does not call on_submit'] = function()
    local submitted = false
    ui.open_input({
        on_submit = function() submitted = true end,
    })
    local buf = vim.api.nvim_get_current_buf()
    vim.cmd("stopinsert")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "", "  ", "" })
    vim.cmd("write")
    MiniTest.expect.equality(submitted, false)
end

T['ui']['q in normal mode closes without calling on_submit'] = function()
    local submitted = false
    ui.open_input({
        on_submit = function() submitted = true end,
    })
    vim.cmd("stopinsert")
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("q", true, false, true), "x", false)
    MiniTest.expect.equality(submitted, false)
end

T['ui']['q triggers on_cancel'] = function()
    local cancelled = false
    ui.open_input({
        on_cancel = function() cancelled = true end,
    })
    vim.cmd("stopinsert")
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("q", true, false, true), "x", false)
    MiniTest.expect.equality(cancelled, true)
end

T['ui']['open_view with comments shows formatted content'] = function()
    ui.open_view({
        { line = 5, body = "needs refactor", status = "open" },
    })
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    MiniTest.expect.equality(lines[1], "Line 5 [open]")
    MiniTest.expect.equality(lines[2], "needs refactor")
end

T['ui']['open_view buffer is not modifiable'] = function()
    ui.open_view({
        { line = 1, body = "test", status = "open" },
    })
    local buf = vim.api.nvim_get_current_buf()
    MiniTest.expect.equality(vim.bo[buf].modifiable, false)
end

T['ui']['open_view with empty list does not open window'] = function()
    local win_count_before = #vim.api.nvim_list_wins()
    ui.open_view({})
    local win_count_after = #vim.api.nvim_list_wins()
    MiniTest.expect.equality(win_count_after, win_count_before)
end

T['ui']['open_view close via q'] = function()
    ui.open_view({
        { line = 1, body = "test", status = "open" },
    })
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("q", true, false, true), "x", false)
    MiniTest.expect.equality(vim.api.nvim_buf_is_valid(buf), false)
end

return T
