-- Engine adapter for diffview.nvim.
--
-- IMPORT DISCIPLINE: this is the only module in marginalia that may `require("diffview...")`.
-- Every other module calls through the functions exported here. If we later swap engines
-- (e.g. to a native :diffthis implementation) the rewrite is contained to this file.

local M = {}

local function lib()
    local ok, l = pcall(require, "diffview.lib")
    if not ok then return nil end
    return l
end

local function current_view()
    local l = lib()
    if not l then return nil end
    return l.get_current_view()
end

function M.open(source)
    assert(source and source.kind, "marginalia.engine.diffview.open: source.kind is required")
    if source.kind == "worktree_vs_head" then
        require("diffview").open({})
    else
        error("marginalia.engine.diffview: unsupported source kind: " .. tostring(source.kind))
    end
end

function M.close()
    local ok, err = pcall(function() require("diffview").close() end)
    if not ok and not err:match("E445") then
        error(err)
    end
end

-- returns { before = bufnr|nil, after = bufnr|nil } for the focused file, or nil if no view
function M.get_buffer_pair()
    local view = current_view()
    if not view or not view.cur_entry or not view.cur_entry.layout then return nil end
    local layout = view.cur_entry.layout
    return {
        before = layout.a and layout.a.file and layout.a.file.bufnr or nil,
        after = layout.b and layout.b.file and layout.b.file.bufnr or nil,
    }
end

-- TODO: verify empirically whether view.cur_entry.path is repo-relative or absolute
function M.current_file()
    local view = current_view()
    if not view or not view.cur_entry then return nil end
    return view.cur_entry.path
end

-- given a bufnr, returns "before" | "after" | nil based on the focused file's layout
function M.side_of(bufnr)
    local pair = M.get_buffer_pair()
    if not pair then return nil end
    if pair.before == bufnr then return "before" end
    if pair.after == bufnr then return "after" end
    return nil
end

-- cb(bufnr, side) — side may be nil if the buffer belongs to an entry that is not currently
-- focused in the file panel (e.g. during batch load of multiple files). Downstream code must
-- not assume side is always populated; re-derive via side_of() lazily when needed.
-- NOTE: single-subscriber — a second call replaces the previous callback (augroup clear = true).
function M.on_buffer_ready(cb)
    local group = vim.api.nvim_create_augroup("MarginaliaDiffviewBufReady", { clear = true })
    vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "DiffviewDiffBufRead",
        callback = function(ev)
            cb(ev.buf, M.side_of(ev.buf))
        end,
    })
end

-- cb() invoked when the diffview session closes.
-- NOTE: single-subscriber — a second call replaces the previous callback (augroup clear = true).
function M.on_close(cb)
    local group = vim.api.nvim_create_augroup("MarginaliaDiffviewClose", { clear = true })
    vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "DiffviewViewClosed",
        callback = function() cb() end,
    })
end

-- returns true if a diffview session is currently active
function M.is_active()
    return current_view() ~= nil
end

return M
