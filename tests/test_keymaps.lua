local MiniTest = require('mini.test')
local new_set = MiniTest.new_set

local T = new_set()

local comments
local mock_engine
local marginalia

local function setup_session()
    -- rtp set by minimal_init.lua
    -- force reload
    package.loaded['marginalia'] = nil
    package.loaded['marginalia.comments'] = nil
    package.loaded['marginalia.ui'] = nil
    package.loaded['tests.mock_engine'] = nil

    comments = require('marginalia.comments')
    comments.clear()
    mock_engine = require('tests.mock_engine')
    mock_engine.reset()

    -- Patch marginalia to use mock engine
    marginalia = require('marginalia')
    marginalia.setup()

    -- Open the mock engine and wire keymaps manually (simulating what init.lua does)
    mock_engine.open()
    local bufnr = mock_engine._after_buf
    local file = mock_engine.current_file()
    comments.register_buf(bufnr, file)
    marginalia._set_keymaps(bufnr, file)
    vim.api.nvim_set_current_buf(bufnr)
    return bufnr, file
end

T['keymaps'] = new_set({
    hooks = {
        pre_case = function()
            setup_session()
        end,
        post_case = function()
            -- cleanup floating windows and marginalia buffers
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
            mock_engine.reset()
        end,
    },
})

T['keymaps']['after-buffer has <leader>rc mapped'] = function()
    local bufnr = mock_engine._after_buf
    local maps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
    local found = false
    for _, m in ipairs(maps) do
        if m.lhs == " rc" or m.lhs == "<Space>rc" or m.lhs:match("rc$") then
            found = true
            break
        end
    end
    MiniTest.expect.equality(found, true)
end

T['keymaps']['before-buffer does NOT have <leader>rc mapped'] = function()
    local before_buf = mock_engine._before_buf
    local maps = vim.api.nvim_buf_get_keymap(before_buf, 'n')
    local found = false
    for _, m in ipairs(maps) do
        if m.lhs == " rc" or m.lhs == "<Space>rc" or m.lhs:match("rc$") then
            found = true
            break
        end
    end
    MiniTest.expect.equality(found, false)
end

T['keymaps']['<leader>rc at line N opens floating input'] = function()
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>rc", true, false, true), "x", false)
    -- should have a floating window open
    local floating = 0
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local cfg = vim.api.nvim_win_get_config(win)
        if cfg.relative and cfg.relative ~= "" then floating = floating + 1 end
    end
    MiniTest.expect.equality(floating >= 1, true)
end

T['keymaps']['submit comment stores entry at correct line'] = function()
    local file = mock_engine.current_file()
    vim.api.nvim_win_set_cursor(0, { 4, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>rc", true, false, true), "x", false)
    -- write content and save
    local buf = vim.api.nvim_get_current_buf()
    vim.cmd("stopinsert")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "my review note" })
    vim.cmd("write")
    local at_line = comments.get_at_line(file, 4)
    MiniTest.expect.equality(#at_line, 1)
    MiniTest.expect.equality(at_line[1].body, "my review note")
end

T['keymaps']['submit comment places extmark'] = function()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>rc", true, false, true), "x", false)
    local buf = vim.api.nvim_get_current_buf()
    vim.cmd("stopinsert")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "note" })
    vim.cmd("write")
    local marks = vim.api.nvim_buf_get_extmarks(mock_engine._after_buf, comments._ns, 0, -1, {})
    MiniTest.expect.equality(#marks >= 1, true)
    MiniTest.expect.equality(marks[1][2], 1) -- 0-indexed line 1
end

T['keymaps']['<leader>rv on commented line opens view float'] = function()
    local file = mock_engine.current_file()
    comments.add({ file = file, line = 5, body = "existing comment" })
    vim.api.nvim_win_set_cursor(0, { 5, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>rv", true, false, true), "x", false)
    local floating = 0
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local cfg = vim.api.nvim_win_get_config(win)
        if cfg.relative and cfg.relative ~= "" then floating = floating + 1 end
    end
    MiniTest.expect.equality(floating >= 1, true)
end

T['keymaps']['<leader>rv on empty line does not open float'] = function()
    vim.api.nvim_win_set_cursor(0, { 7, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>rv", true, false, true), "x", false)
    local floating = 0
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local cfg = vim.api.nvim_win_get_config(win)
        if cfg.relative and cfg.relative ~= "" then floating = floating + 1 end
    end
    MiniTest.expect.equality(floating, 0)
end

T['keymaps']['<leader>re on commented line opens input with existing body'] = function()
    local file = mock_engine.current_file()
    comments.add({ file = file, line = 3, body = "edit me" })
    vim.api.nvim_set_current_buf(mock_engine._after_buf)
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>re", true, false, true), "x", false)
    local buf = vim.api.nvim_get_current_buf()
    vim.cmd("stopinsert")
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    MiniTest.expect.equality(lines[1], "edit me")
end

T['keymaps']['edit submit updates comment body'] = function()
    local file = mock_engine.current_file()
    local c = comments.add({ file = file, line = 3, body = "original" })
    vim.api.nvim_set_current_buf(mock_engine._after_buf)
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>re", true, false, true), "x", false)
    local buf = vim.api.nvim_get_current_buf()
    vim.cmd("stopinsert")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "updated" })
    vim.cmd("write")
    local updated = comments.get(c.id)
    MiniTest.expect.equality(updated.body, "updated")
end

T['keymaps']['<leader>rd on commented line removes from store'] = function()
    local file = mock_engine.current_file()
    comments.add({ file = file, line = 6, body = "delete me" })
    vim.api.nvim_set_current_buf(mock_engine._after_buf)
    vim.api.nvim_win_set_cursor(0, { 6, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>rd", true, false, true), "x", false)
    MiniTest.expect.equality(#comments.get_at_line(file, 6), 0)
end

T['keymaps']['<leader>rd removes extmark'] = function()
    local file = mock_engine.current_file()
    comments.add({ file = file, line = 6, body = "delete me" })
    comments.refresh_extmarks(mock_engine._after_buf, file)
    vim.api.nvim_set_current_buf(mock_engine._after_buf)
    vim.api.nvim_win_set_cursor(0, { 6, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>rd", true, false, true), "x", false)
    local marks = vim.api.nvim_buf_get_extmarks(mock_engine._after_buf, comments._ns, 0, -1, {})
    MiniTest.expect.equality(#marks, 0)
end

T['keymaps'][']r jumps to next commented line'] = function()
    local file = mock_engine.current_file()
    comments.add({ file = file, line = 3, body = "c1" })
    comments.add({ file = file, line = 7, body = "c2" })
    vim.api.nvim_set_current_buf(mock_engine._after_buf)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("]r", true, false, true), "x", false)
    local cursor = vim.api.nvim_win_get_cursor(0)
    MiniTest.expect.equality(cursor[1], 3)
end

T['keymaps']['[r jumps to previous commented line'] = function()
    local file = mock_engine.current_file()
    comments.add({ file = file, line = 3, body = "c1" })
    comments.add({ file = file, line = 7, body = "c2" })
    vim.api.nvim_set_current_buf(mock_engine._after_buf)
    vim.api.nvim_win_set_cursor(0, { 10, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("[r", true, false, true), "x", false)
    local cursor = vim.api.nvim_win_get_cursor(0)
    MiniTest.expect.equality(cursor[1], 7)
end

T['keymaps'][']r at last comment notifies'] = function()
    local file = mock_engine.current_file()
    comments.add({ file = file, line = 3, body = "only" })
    vim.api.nvim_set_current_buf(mock_engine._after_buf)
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("]r", true, false, true), "x", false)
    -- cursor should not move
    local cursor = vim.api.nvim_win_get_cursor(0)
    MiniTest.expect.equality(cursor[1], 3)
end

T['keymaps']['[r at first comment notifies'] = function()
    local file = mock_engine.current_file()
    comments.add({ file = file, line = 7, body = "only" })
    vim.api.nvim_set_current_buf(mock_engine._after_buf)
    vim.api.nvim_win_set_cursor(0, { 7, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("[r", true, false, true), "x", false)
    local cursor = vim.api.nvim_win_get_cursor(0)
    MiniTest.expect.equality(cursor[1], 7)
end

return T
