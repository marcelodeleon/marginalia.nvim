local M = {}

M.config = {
    keymaps = {
        create = "<leader>rc",
        view = "<leader>rv",
        edit = "<leader>re",
        delete = "<leader>rd",
        next = "]r",
        prev = "[r",
    },
    review_file = "REVIEW.md",
}

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

function M.open(source)
    local engine = require("marginalia.engine.diffview")
    local comments = require("marginalia.comments")

    engine.on_buffer_ready(function(bufnr, side)
        if side ~= "after" then return end
        local file = engine.current_file()
        if not file then return end

        comments.register_buf(bufnr, file)

        -- Place extmarks for any existing comments on this file
        comments.refresh_extmarks(bufnr, file)

        -- Set buffer-local keymaps
        M._set_keymaps(bufnr, file)
    end)

    engine.on_close(function()
        -- Snapshot extmark positions before buffers die
        for bufnr, file in pairs(comments._buf_file) do
            if vim.api.nvim_buf_is_valid(bufnr) then
                comments.snapshot_positions(bufnr, file)
            end
        end
        comments._buf_file = {}
    end)

    engine.open(source or { kind = "worktree_vs_head" })
end

function M.close()
    local engine = require("marginalia.engine.diffview")
    local comments = require("marginalia.comments")

    for bufnr, file in pairs(comments._buf_file) do
        if vim.api.nvim_buf_is_valid(bufnr) then
            comments.snapshot_positions(bufnr, file)
        end
    end
    comments._buf_file = {}

    engine.close()
end

function M._set_keymaps(bufnr, file)
    local comments = require("marginalia.comments")
    local ui = require("marginalia.ui")
    local km = M.config.keymaps

    -- Create comment (normal mode — single line)
    vim.keymap.set("n", km.create, function()
        local line = vim.api.nvim_win_get_cursor(0)[1]
        ui.open_input({
            on_submit = function(body)
                comments.add({ file = file, line = line, body = body })
                comments.refresh_extmarks(bufnr, file)
            end,
        })
    end, { buffer = bufnr, desc = "marginalia: add comment" })

    -- Create comment (visual mode — line range)
    vim.keymap.set("v", km.create, function()
        local start_line = vim.fn.line("v")
        local end_line = vim.fn.line(".")
        if start_line > end_line then
            start_line, end_line = end_line, start_line
        end
        -- Exit visual mode
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
        ui.open_input({
            on_submit = function(body)
                comments.add({ file = file, line = start_line, line_end = end_line, body = body })
                comments.refresh_extmarks(bufnr, file)
            end,
        })
    end, { buffer = bufnr, desc = "marginalia: add range comment" })

    -- View comments on current line
    vim.keymap.set("n", km.view, function()
        local line = vim.api.nvim_win_get_cursor(0)[1]
        local at_line = comments.get_at_line(file, line)
        ui.open_view(at_line)
    end, { buffer = bufnr, desc = "marginalia: view comments" })

    -- Edit comment on current line
    vim.keymap.set("n", km.edit, function()
        local line = vim.api.nvim_win_get_cursor(0)[1]
        local at_line = comments.get_at_line(file, line)
        if #at_line == 0 then
            vim.notify("marginalia: no comments on this line", vim.log.levels.INFO)
            return
        end
        local target = at_line[1]
        if #at_line > 1 then
            vim.ui.select(at_line, {
                prompt = "Edit which comment?",
                format_item = function(c)
                    return c.body:sub(1, 60) .. (#c.body > 60 and "…" or "")
                end,
            }, function(choice)
                if not choice then return end
                ui.open_input({
                    initial = choice.body,
                    on_submit = function(body)
                        comments.update(choice.id, { body = body })
                        comments.refresh_extmarks(bufnr, file)
                    end,
                })
            end)
            return
        end
        ui.open_input({
            initial = target.body,
            on_submit = function(body)
                comments.update(target.id, { body = body })
                comments.refresh_extmarks(bufnr, file)
            end,
        })
    end, { buffer = bufnr, desc = "marginalia: edit comment" })

    -- Delete comment on current line
    vim.keymap.set("n", km.delete, function()
        local line = vim.api.nvim_win_get_cursor(0)[1]
        local at_line = comments.get_at_line(file, line)
        if #at_line == 0 then
            vim.notify("marginalia: no comments on this line", vim.log.levels.INFO)
            return
        end
        if #at_line > 1 then
            vim.ui.select(at_line, {
                prompt = "Delete which comment?",
                format_item = function(c)
                    return c.body:sub(1, 60) .. (#c.body > 60 and "…" or "")
                end,
            }, function(choice)
                if not choice then return end
                comments.delete(choice.id)
                comments.refresh_extmarks(bufnr, file)
            end)
            return
        end
        comments.delete(at_line[1].id)
        comments.refresh_extmarks(bufnr, file)
    end, { buffer = bufnr, desc = "marginalia: delete comment" })

    -- Navigate to next comment
    vim.keymap.set("n", km.next, function()
        local line = vim.api.nvim_win_get_cursor(0)[1]
        local file_comments = comments.get_for_file(file)
        local next_line = nil
        for _, c in ipairs(file_comments) do
            if c.line > line then
                if not next_line or c.line < next_line then
                    next_line = c.line
                end
            end
        end
        if next_line then
            vim.api.nvim_win_set_cursor(0, { next_line, 0 })
        else
            vim.notify("marginalia: no next comment", vim.log.levels.INFO)
        end
    end, { buffer = bufnr, desc = "marginalia: next comment" })

    -- Navigate to previous comment
    vim.keymap.set("n", km.prev, function()
        local line = vim.api.nvim_win_get_cursor(0)[1]
        local file_comments = comments.get_for_file(file)
        local prev_line = nil
        for _, c in ipairs(file_comments) do
            if c.line < line then
                if not prev_line or c.line > prev_line then
                    prev_line = c.line
                end
            end
        end
        if prev_line then
            vim.api.nvim_win_set_cursor(0, { prev_line, 0 })
        else
            vim.notify("marginalia: no previous comment", vim.log.levels.INFO)
        end
    end, { buffer = bufnr, desc = "marginalia: previous comment" })
end

return M
