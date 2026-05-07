local M = {}

local ns = vim.api.nvim_create_namespace("marginalia")
M._ns = ns

M._store = {}
M._next_id = 1

-- bufnr → file mapping, set when keymaps are bound on after-side buffers
M._buf_file = {}

function M.add(entry)
    local comment = {
        id = M._next_id,
        file = entry.file,
        line = entry.line,
        line_end = entry.line_end,
        body = entry.body,
        status = "open",
        extmark_id = nil,
    }
    M._next_id = M._next_id + 1
    table.insert(M._store, comment)
    return comment
end

function M.get(id)
    for _, c in ipairs(M._store) do
        if c.id == id then return c end
    end
    return nil
end

function M.get_all()
    return M._store
end

function M.get_for_file(file)
    local results = {}
    for _, c in ipairs(M._store) do
        if c.file == file then
            table.insert(results, c)
        end
    end
    return results
end

function M.get_at_line(file, line)
    local results = {}
    for _, c in ipairs(M._store) do
        if c.file == file and c.line == line then
            table.insert(results, c)
        end
    end
    return results
end

function M.update(id, fields)
    for _, c in ipairs(M._store) do
        if c.id == id then
            for k, v in pairs(fields) do
                c[k] = v
            end
            return c
        end
    end
    return nil
end

function M.delete(id)
    for i, c in ipairs(M._store) do
        if c.id == id then
            table.remove(M._store, i)
            return c
        end
    end
    return nil
end

function M.clear()
    M._store = {}
    M._next_id = 1
    M._buf_file = {}
end

-- Extmark management

function M.place_extmark(bufnr, comment)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    local line_idx = comment.line - 1
    local count = #M.get_at_line(comment.file, comment.line)
    local virt_text = count > 1 and string.format("💬 ×%d", count) or "💬"

    local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, 0, {
        sign_text = "●",
        sign_hl_group = "DiagnosticInfo",
        virt_text = { { virt_text, "Comment" } },
        virt_text_pos = "eol",
    })
    comment.extmark_id = extmark_id
    return extmark_id
end

function M.refresh_extmarks(bufnr, file)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    local comments = M.get_for_file(file)

    -- group by line to get correct counts before placing
    local by_line = {}
    for _, c in ipairs(comments) do
        by_line[c.line] = by_line[c.line] or {}
        table.insert(by_line[c.line], c)
    end

    for line, group in pairs(by_line) do
        local line_idx = line - 1
        local count = #group
        local virt_text = count > 1 and string.format("💬 ×%d", count) or "💬"
        local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, 0, {
            sign_text = "●",
            sign_hl_group = "DiagnosticInfo",
            virt_text = { { virt_text, "Comment" } },
            virt_text_pos = "eol",
        })
        -- assign to first comment in group; others share the visual
        group[1].extmark_id = extmark_id
        for i = 2, #group do
            group[i].extmark_id = nil
        end
    end
end

-- Snapshot extmark positions back to store (call before buffer is wiped)
function M.snapshot_positions(bufnr, file)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    local comments = M.get_for_file(file)
    for _, c in ipairs(comments) do
        if c.extmark_id then
            local pos = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns, c.extmark_id, {})
            if pos and pos[1] then
                c.line = pos[1] + 1
            end
            c.extmark_id = nil
        end
    end
end

-- Find bufnr for a given file (from registered after-side buffers)
function M.find_buf(file)
    for bufnr, f in pairs(M._buf_file) do
        if f == file and vim.api.nvim_buf_is_valid(bufnr) then
            return bufnr
        end
    end
    return nil
end

function M.register_buf(bufnr, file)
    M._buf_file[bufnr] = file
end

function M.unregister_buf(bufnr)
    M._buf_file[bufnr] = nil
end

return M
