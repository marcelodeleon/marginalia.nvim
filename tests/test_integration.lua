local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local T = new_set()

local plugin_root = vim.fn.fnamemodify('.', ':p')
local child = MiniTest.new_child_neovim()

local function setup_repo()
    child.lua([[
        package.loaded['marginalia'] = nil
        package.loaded['marginalia.comments'] = nil
        package.loaded['marginalia.ui'] = nil
        package.loaded['marginalia.engine.diffview'] = nil
        pcall(vim.api.nvim_del_augroup_by_name, 'MarginaliaDiffviewBufReady')
        pcall(vim.api.nvim_del_augroup_by_name, 'MarginaliaDiffviewClose')
        require('marginalia.comments').clear()
        require('marginalia').setup()
        _G._test_tmp = vim.fn.tempname()
        vim.fn.mkdir(_G._test_tmp, 'p')
        vim.fn.system('git -C ' .. _G._test_tmp .. ' init')
        vim.fn.system('git -C ' .. _G._test_tmp .. ' config user.email test@test.com')
        vim.fn.system('git -C ' .. _G._test_tmp .. ' config user.name Test')
        local f = io.open(_G._test_tmp .. '/example.lua', 'w')
        f:write('line 1\nline 2\nline 3\nline 4\nline 5\nline 6\nline 7\nline 8\nline 9\nline 10\n')
        f:close()
        vim.fn.system('git -C ' .. _G._test_tmp .. ' add .')
        vim.fn.system('git -C ' .. _G._test_tmp .. ' commit -m "initial"')
        f = io.open(_G._test_tmp .. '/example.lua', 'w')
        f:write('line 1\nline 2 modified\nline 3\nline 4\nline 5\nline 6 changed\nline 7\nline 8\nline 9\nline 10\n')
        f:close()
        vim.cmd('cd ' .. _G._test_tmp)
    ]])
end

local function open_and_wait()
    child.lua([[
        require('marginalia').open({ kind = 'worktree_vs_head' })
        vim.wait(3000, function()
            return next(require('marginalia.comments')._buf_file) ~= nil
        end, 50)
    ]])
end

T['integration'] = new_set({
    hooks = {
        pre_once = function()
            child.restart({ '-u', 'scripts/minimal_init.lua' })
            child.lua('vim.opt.rtp:append(...)', { plugin_root .. 'deps/diffview.nvim' })
        end,
        pre_case = function()
            setup_repo()
        end,
        post_case = function()
            child.lua([[pcall(function() require('diffview').close() end)]])
            child.lua('vim.cmd("cd " .. ...)', { plugin_root })
            child.lua([[
                if _G._test_tmp then
                    vim.fn.delete(_G._test_tmp, 'rf')
                    _G._test_tmp = nil
                end
            ]])
        end,
        post_once = function() child.stop() end,
    },
})

T['integration'][':Review opens a diffview tab'] = function()
    child.lua([[
        local before = #vim.api.nvim_list_tabpages()
        require('marginalia').open({ kind = 'worktree_vs_head' })
        vim.wait(3000, function()
            return #vim.api.nvim_list_tabpages() > before
        end, 50)
    ]])
    local tabs = child.lua_get([[#vim.api.nvim_list_tabpages()]])
    expect.equality(tabs > 1, true)
end

T['integration']['after-side buffer is registered'] = function()
    open_and_wait()
    local has_reg = child.lua_get([[next(require('marginalia.comments')._buf_file) ~= nil]])
    expect.equality(has_reg, true)
end

T['integration']['keymaps bound on after buffer'] = function()
    open_and_wait()
    child.lua([[
        local comments = require('marginalia.comments')
        _G._result = false
        for bufnr, _ in pairs(comments._buf_file) do
            local maps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
            for _, m in ipairs(maps) do
                if m.lhs:match('rc$') then _G._result = true end
            end
        end
    ]])
    local has_keymap = child.lua_get([[_G._result]])
    expect.equality(has_keymap, true)
end

T['integration']['create comment, extmark visible, data correct'] = function()
    open_and_wait()
    child.lua([[
        local comments = require('marginalia.comments')
        local after_buf, file
        for bufnr, f in pairs(comments._buf_file) do
            after_buf = bufnr; file = f; break
        end
        comments.add({ file = file, line = 2, body = 'integration comment' })
        comments.refresh_extmarks(after_buf, file)
    ]])

    child.lua([[
        local comments = require('marginalia.comments')
        local after_buf
        for bufnr, _ in pairs(comments._buf_file) do after_buf = bufnr; break end
        _G._mark_count = #vim.api.nvim_buf_get_extmarks(after_buf, comments._ns, 0, -1, {})
    ]])
    local mark_count = child.lua_get([[_G._mark_count]])
    expect.equality(mark_count >= 1, true)

    child.lua([[
        local comments = require('marginalia.comments')
        local file
        for _, f in pairs(comments._buf_file) do file = f; break end
        local at = comments.get_at_line(file, 2)
        _G._body = at[1] and at[1].body or ''
    ]])
    local body = child.lua_get([[_G._body]])
    expect.equality(body, 'integration comment')
end

T['integration']['delete comment removes extmark'] = function()
    open_and_wait()
    child.lua([[
        local comments = require('marginalia.comments')
        local after_buf, file
        for bufnr, f in pairs(comments._buf_file) do
            after_buf = bufnr; file = f; break
        end
        local c = comments.add({ file = file, line = 3, body = 'to delete' })
        comments.refresh_extmarks(after_buf, file)
        comments.delete(c.id)
        comments.refresh_extmarks(after_buf, file)
    ]])

    child.lua([[
        local comments = require('marginalia.comments')
        local after_buf
        for bufnr, _ in pairs(comments._buf_file) do after_buf = bufnr; break end
        _G._mark_count = #vim.api.nvim_buf_get_extmarks(after_buf, comments._ns, 0, -1, {})
    ]])
    local mark_count = child.lua_get([[_G._mark_count]])
    expect.equality(mark_count, 0)
end

T['integration']['navigate with next/prev keymaps'] = function()
    open_and_wait()
    child.lua([[
        local comments = require('marginalia.comments')
        local after_buf, file
        for bufnr, f in pairs(comments._buf_file) do
            after_buf = bufnr; file = f; break
        end
        comments.add({ file = file, line = 2, body = 'c1' })
        comments.add({ file = file, line = 6, body = 'c2' })
        vim.api.nvim_set_current_buf(after_buf)
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
    ]])

    child.type_keys(']r')
    local line1 = child.lua_get([=[vim.api.nvim_win_get_cursor(0)[1]]=])
    expect.equality(line1, 2)

    child.type_keys(']r')
    local line2 = child.lua_get([=[vim.api.nvim_win_get_cursor(0)[1]]=])
    expect.equality(line2, 6)
end

T['integration'][':ReviewClose snapshots positions'] = function()
    open_and_wait()
    child.lua([[
        local comments = require('marginalia.comments')
        local after_buf, file
        for bufnr, f in pairs(comments._buf_file) do
            after_buf = bufnr; file = f; break
        end
        local c = comments.add({ file = file, line = 5, body = 'track me' })
        comments.place_extmark(after_buf, c)
        _G._test_comment_id = c.id
    ]])

    child.lua([[require('marginalia').close()]])

    child.lua([[
        local comments = require('marginalia.comments')
        local c = comments.get(_G._test_comment_id)
        _G._extmark_id = c and c.extmark_id
    ]])
    local extmark_id = child.lua_get([[_G._extmark_id]])
    expect.equality(extmark_id, vim.NIL)
end

T['integration']['comments survive close'] = function()
    open_and_wait()
    child.lua([[
        local comments = require('marginalia.comments')
        local file
        for _, f in pairs(comments._buf_file) do file = f; break end
        comments.add({ file = file, line = 3, body = 'persistent' })
    ]])

    child.lua([[require('marginalia').close()]])

    local count = child.lua_get([[#require('marginalia.comments').get_all()]])
    child.lua([[_G._body = require('marginalia.comments').get_all()[1].body]])
    local body = child.lua_get([[_G._body]])
    expect.equality(count, 1)
    expect.equality(body, 'persistent')
end

T['integration']['line drift updates comment.line on close'] = function()
    open_and_wait()
    child.lua([[
        local comments = require('marginalia.comments')
        local after_buf, file
        for bufnr, f in pairs(comments._buf_file) do
            after_buf = bufnr; file = f; break
        end
        local c = comments.add({ file = file, line = 5, body = 'drift test' })
        comments.place_extmark(after_buf, c)
        _G._test_comment_id = c.id
        vim.api.nvim_buf_set_lines(after_buf, 2, 2, false, { 'inserted line' })
    ]])

    child.lua([[require('marginalia').close()]])

    child.lua([[
        local comments = require('marginalia.comments')
        local c = comments.get(_G._test_comment_id)
        _G._new_line = c and c.line
    ]])
    local new_line = child.lua_get([[_G._new_line]])
    expect.equality(new_line, 6)
end

return T
