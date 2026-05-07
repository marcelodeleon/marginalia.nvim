local MiniTest = require('mini.test')
local new_set = MiniTest.new_set

local T = new_set()

local comments

T['setup'] = new_set({
    hooks = {
        pre_case = function()
            -- rtp set by minimal_init.lua
            package.loaded['marginalia.comments'] = nil
            comments = require('marginalia.comments')
            comments.clear()
        end,
    },
})

T['setup']['add returns entry with auto-incremented id and status open'] = function()
    local c = comments.add({ file = "a.lua", line = 1, body = "fix this" })
    MiniTest.expect.equality(c.id, 1)
    MiniTest.expect.equality(c.status, "open")
    MiniTest.expect.equality(c.file, "a.lua")
    MiniTest.expect.equality(c.line, 1)
    MiniTest.expect.equality(c.body, "fix this")
end

T['setup']['add multiple entries increments ids sequentially'] = function()
    local c1 = comments.add({ file = "a.lua", line = 1, body = "first" })
    local c2 = comments.add({ file = "a.lua", line = 2, body = "second" })
    local c3 = comments.add({ file = "b.lua", line = 1, body = "third" })
    MiniTest.expect.equality(c1.id, 1)
    MiniTest.expect.equality(c2.id, 2)
    MiniTest.expect.equality(c3.id, 3)
end

T['setup']['get returns correct entry'] = function()
    comments.add({ file = "a.lua", line = 1, body = "first" })
    comments.add({ file = "a.lua", line = 2, body = "second" })
    local c = comments.get(2)
    MiniTest.expect.equality(c.body, "second")
    MiniTest.expect.equality(c.id, 2)
end

T['setup']['get missing id returns nil'] = function()
    comments.add({ file = "a.lua", line = 1, body = "first" })
    MiniTest.expect.equality(comments.get(99), nil)
end

T['setup']['get_all returns full store'] = function()
    comments.add({ file = "a.lua", line = 1, body = "first" })
    comments.add({ file = "b.lua", line = 2, body = "second" })
    MiniTest.expect.equality(#comments.get_all(), 2)
end

T['setup']['get_for_file filters by file'] = function()
    comments.add({ file = "a.lua", line = 1, body = "a1" })
    comments.add({ file = "b.lua", line = 1, body = "b1" })
    comments.add({ file = "a.lua", line = 2, body = "a2" })
    local results = comments.get_for_file("a.lua")
    MiniTest.expect.equality(#results, 2)
    MiniTest.expect.equality(results[1].body, "a1")
    MiniTest.expect.equality(results[2].body, "a2")
end

T['setup']['get_at_line filters by file and line'] = function()
    comments.add({ file = "a.lua", line = 1, body = "a1" })
    comments.add({ file = "a.lua", line = 2, body = "a2" })
    comments.add({ file = "b.lua", line = 1, body = "b1" })
    local results = comments.get_at_line("a.lua", 1)
    MiniTest.expect.equality(#results, 1)
    MiniTest.expect.equality(results[1].body, "a1")
end

T['setup']['get_at_line returns multiple comments on same line'] = function()
    comments.add({ file = "a.lua", line = 5, body = "first" })
    comments.add({ file = "a.lua", line = 5, body = "second" })
    local results = comments.get_at_line("a.lua", 5)
    MiniTest.expect.equality(#results, 2)
end

T['setup']['update modifies specified fields'] = function()
    comments.add({ file = "a.lua", line = 1, body = "original" })
    local updated = comments.update(1, { body = "changed", status = "resolved" })
    MiniTest.expect.equality(updated.body, "changed")
    MiniTest.expect.equality(updated.status, "resolved")
    MiniTest.expect.equality(updated.file, "a.lua")
    MiniTest.expect.equality(updated.line, 1)
end

T['setup']['update nonexistent id returns nil'] = function()
    MiniTest.expect.equality(comments.update(99, { body = "x" }), nil)
end

T['setup']['delete removes entry and returns it'] = function()
    comments.add({ file = "a.lua", line = 1, body = "doomed" })
    local deleted = comments.delete(1)
    MiniTest.expect.equality(deleted.body, "doomed")
    MiniTest.expect.equality(#comments.get_all(), 0)
end

T['setup']['delete nonexistent id returns nil'] = function()
    MiniTest.expect.equality(comments.delete(99), nil)
end

T['setup']['clear empties store and resets id counter'] = function()
    comments.add({ file = "a.lua", line = 1, body = "one" })
    comments.add({ file = "a.lua", line = 2, body = "two" })
    comments.clear()
    MiniTest.expect.equality(#comments.get_all(), 0)
    local c = comments.add({ file = "a.lua", line = 1, body = "fresh" })
    MiniTest.expect.equality(c.id, 1)
end

return T
