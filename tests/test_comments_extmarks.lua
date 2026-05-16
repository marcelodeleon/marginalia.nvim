local MiniTest = require('mini.test')
local new_set = MiniTest.new_set

local T = new_set()

local comments
local ns
local bufnr

T['extmarks'] = new_set({
    hooks = {
        pre_case = function()
            -- rtp set by minimal_init.lua
            package.loaded['marginalia.comments'] = nil
            comments = require('marginalia.comments')
            comments.clear()
            ns = comments._ns
            bufnr = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
                "line 1", "line 2", "line 3", "line 4", "line 5",
                "line 6", "line 7", "line 8", "line 9", "line 10",
            })
        end,
        post_case = function()
            if vim.api.nvim_buf_is_valid(bufnr) then
                vim.api.nvim_buf_delete(bufnr, { force = true })
            end
        end,
    },
})

T['extmarks']['place_extmark creates mark at correct 0-indexed line'] = function()
    local c = comments.add({ file = "f.lua", line = 3, body = "test" })
    comments.place_extmark(bufnr, c)
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
    MiniTest.expect.equality(#marks, 1)
    MiniTest.expect.equality(marks[1][2], 2) -- 0-indexed line
end

T['extmarks']['place_extmark has sign_text and virt_text'] = function()
    local c = comments.add({ file = "f.lua", line = 1, body = "test" })
    comments.place_extmark(bufnr, c)
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
    local details = marks[1][4]
    MiniTest.expect.equality(details.sign_text, "● ")
    MiniTest.expect.equality(details.virt_text[1][1], "💬")
end

T['extmarks']['multiple comments on same line shows count'] = function()
    local c1 = comments.add({ file = "f.lua", line = 5, body = "first" })
    comments.add({ file = "f.lua", line = 5, body = "second" })
    -- place_extmark for c1 should now show count since get_at_line returns 2
    comments.place_extmark(bufnr, c1)
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
    MiniTest.expect.equality(marks[1][4].virt_text[1][1], "💬 ×2")
end

T['extmarks']['refresh_extmarks clears and re-places all'] = function()
    comments.add({ file = "f.lua", line = 1, body = "one" })
    comments.add({ file = "f.lua", line = 3, body = "three" })
    comments.refresh_extmarks(bufnr, "f.lua")
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
    MiniTest.expect.equality(#marks, 2)
end

T['extmarks']['refresh_extmarks after delete removes mark'] = function()
    comments.add({ file = "f.lua", line = 1, body = "one" })
    local c2 = comments.add({ file = "f.lua", line = 3, body = "three" })
    comments.refresh_extmarks(bufnr, "f.lua")
    comments.delete(c2.id)
    comments.refresh_extmarks(bufnr, "f.lua")
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
    MiniTest.expect.equality(#marks, 1)
    MiniTest.expect.equality(marks[1][2], 0) -- only line 1 remains
end

T['extmarks']['extmark survives line insertion above'] = function()
    local c = comments.add({ file = "f.lua", line = 5, body = "test" })
    comments.place_extmark(bufnr, c)
    -- insert a line above line 5 (0-indexed: before index 4)
    vim.api.nvim_buf_set_lines(bufnr, 3, 3, false, { "inserted" })
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
    -- extmark should have drifted to 0-indexed line 5 (was 4)
    MiniTest.expect.equality(marks[1][2], 5)
end

T['extmarks']['snapshot_positions reads drifted position back'] = function()
    local c = comments.add({ file = "f.lua", line = 5, body = "test" })
    comments.place_extmark(bufnr, c)
    vim.api.nvim_buf_set_lines(bufnr, 3, 3, false, { "inserted" })
    comments.snapshot_positions(bufnr, "f.lua")
    MiniTest.expect.equality(c.line, 6) -- 5 (0-indexed) + 1
end

T['extmarks']['snapshot_positions nils out extmark_id'] = function()
    local c = comments.add({ file = "f.lua", line = 3, body = "test" })
    comments.place_extmark(bufnr, c)
    MiniTest.expect.no_equality(c.extmark_id, nil)
    comments.snapshot_positions(bufnr, "f.lua")
    MiniTest.expect.equality(c.extmark_id, nil)
end

T['extmarks']['snapshot_positions on invalid buffer is no-op'] = function()
    local c = comments.add({ file = "f.lua", line = 3, body = "test" })
    comments.place_extmark(bufnr, c)
    local invalid_buf = 99999
    comments.snapshot_positions(invalid_buf, "f.lua")
    -- extmark_id should remain since we used invalid buffer
    MiniTest.expect.no_equality(c.extmark_id, nil)
end

T['extmarks']['sync_positions updates c.line from drifted extmark'] = function()
    local c = comments.add({ file = "f.lua", line = 5, body = "test" })
    comments.refresh_extmarks(bufnr, "f.lua")
    -- insert a line at the top, pushing extmark from 0-indexed 4 → 5
    vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, { "new top line" })
    MiniTest.expect.equality(c.line, 5) -- stale — not yet synced
    comments.sync_positions(bufnr, "f.lua")
    MiniTest.expect.equality(c.line, 6) -- synced from extmark
    -- get_at_line should find it at the new position, not the old
    MiniTest.expect.equality(#comments.get_at_line("f.lua", 6), 1)
    MiniTest.expect.equality(#comments.get_at_line("f.lua", 5), 0)
end

T['extmarks']['sync_positions preserves extmark_id'] = function()
    local c = comments.add({ file = "f.lua", line = 3, body = "test" })
    comments.refresh_extmarks(bufnr, "f.lua")
    vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, { "inserted" })
    comments.sync_positions(bufnr, "f.lua")
    MiniTest.expect.no_equality(c.extmark_id, nil)
end

T['extmarks']['register_buf / find_buf / unregister_buf lifecycle'] = function()
    comments.register_buf(bufnr, "test.lua")
    MiniTest.expect.equality(comments.find_buf("test.lua"), bufnr)
    MiniTest.expect.equality(comments.find_buf("other.lua"), nil)
    comments.unregister_buf(bufnr)
    MiniTest.expect.equality(comments.find_buf("test.lua"), nil)
end

return T
