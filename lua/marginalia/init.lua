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

local _gitignore_checked = false

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

function M._auto_save()
    local review_file = require("marginalia.review_file")
    local comments = require("marginalia.comments")

    local repo_root = review_file.get_repo_root()
    if not repo_root then return end

    for bufnr, file in pairs(comments._buf_file) do
        if vim.api.nvim_buf_is_valid(bufnr) then
            comments.sync_positions(bufnr, file)
        end
    end

    local all = comments.get_all()
    if #all == 0 then
        local path = review_file.review_path(repo_root, M.config.review_file)
        if vim.fn.filereadable(path) == 1 then
            vim.fn.delete(path)
        end
        return
    end

    if not _gitignore_checked then
        _gitignore_checked = true
        review_file.ensure_gitignore(M.config.review_file)
    end

    review_file.serialize(all, repo_root, M.config.review_file)
end

function M.open(source)
    local engine = require("marginalia.engine.diffview")
    local comments = require("marginalia.comments")
    local review_file = require("marginalia.review_file")

    -- Load existing REVIEW.md if store is empty
    if #comments.get_all() == 0 then
        local repo_root = review_file.get_repo_root()
        if repo_root then
            local path = review_file.review_path(repo_root, M.config.review_file)
            if vim.fn.filereadable(path) == 1 then
                local entries, err = review_file.parse(path)
                if entries and #entries > 0 then
                    for _, e in ipairs(entries) do
                        comments.add(e)
                    end
                    vim.notify(
                        "marginalia: loaded " .. #entries .. " comment(s) from " .. M.config.review_file,
                        vim.log.levels.INFO
                    )
                elseif err then
                    vim.notify("marginalia: " .. err, vim.log.levels.ERROR)
                end
            end
        end
    end

    engine.on_buffer_ready(function(bufnr, side)
        if side ~= "after" then return end
        local file = engine.current_file()
        if not file then return end

        comments.register_buf(bufnr, file)
        comments.refresh_extmarks(bufnr, file)
        M._set_keymaps(bufnr, file)
    end)

    engine.on_close(function()
        for bufnr, file in pairs(comments._buf_file) do
            if vim.api.nvim_buf_is_valid(bufnr) then
                comments.snapshot_positions(bufnr, file)
            end
        end
        comments._buf_file = {}
        M._auto_save()
    end)

    -- VimLeavePre safety net
    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = vim.api.nvim_create_augroup("MarginaliaVimLeave", { clear = true }),
        callback = function()
            for bufnr, file in pairs(comments._buf_file) do
                if vim.api.nvim_buf_is_valid(bufnr) then
                    comments.snapshot_positions(bufnr, file)
                end
            end
            comments._buf_file = {}
            M._auto_save()
        end,
    })

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
    M._auto_save()

    engine.close()
end

function M.save()
    M._auto_save()
    vim.notify("marginalia: saved to " .. M.config.review_file, vim.log.levels.INFO)
end

function M.clear()
    local review_file = require("marginalia.review_file")
    local comments = require("marginalia.comments")

    local repo_root = review_file.get_repo_root()
    if repo_root then
        local path = review_file.review_path(repo_root, M.config.review_file)
        if vim.fn.filereadable(path) == 1 then
            vim.fn.delete(path)
        end
    end

    -- Clear extmarks from any open buffers
    for bufnr, _ in pairs(comments._buf_file) do
        if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_clear_namespace(bufnr, comments._ns, 0, -1)
        end
    end

    comments.clear()
    vim.notify("marginalia: review cleared", vim.log.levels.INFO)
end

function M._set_keymaps(bufnr, file)
    local comments = require("marginalia.comments")
    local ui = require("marginalia.ui")
    local km = M.config.keymaps

    vim.keymap.set("n", km.create, function()
        local line = vim.api.nvim_win_get_cursor(0)[1]
        ui.open_input({
            on_submit = function(body)
                comments.add({ file = file, line = line, body = body })
                comments.refresh_extmarks(bufnr, file)
                M._auto_save()
            end,
        })
    end, { buffer = bufnr, desc = "marginalia: add comment" })

    vim.keymap.set("v", km.create, function()
        local start_line = vim.fn.line("v")
        local end_line = vim.fn.line(".")
        if start_line > end_line then
            start_line, end_line = end_line, start_line
        end
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
        ui.open_input({
            on_submit = function(body)
                comments.add({ file = file, line = start_line, line_end = end_line, body = body })
                comments.refresh_extmarks(bufnr, file)
                M._auto_save()
            end,
        })
    end, { buffer = bufnr, desc = "marginalia: add range comment" })

    vim.keymap.set("n", km.view, function()
        comments.sync_positions(bufnr, file)
        local line = vim.api.nvim_win_get_cursor(0)[1]
        local at_line = comments.get_at_line(file, line)
        ui.open_view(at_line)
    end, { buffer = bufnr, desc = "marginalia: view comments" })

    vim.keymap.set("n", km.edit, function()
        comments.sync_positions(bufnr, file)
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
                    return c.body:sub(1, 60) .. (#c.body > 60 and "..." or "")
                end,
            }, function(choice)
                if not choice then return end
                ui.open_input({
                    initial = choice.body,
                    on_submit = function(body)
                        comments.update(choice.id, { body = body })
                        comments.refresh_extmarks(bufnr, file)
                        M._auto_save()
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
                M._auto_save()
            end,
        })
    end, { buffer = bufnr, desc = "marginalia: edit comment" })

    vim.keymap.set("n", km.delete, function()
        comments.sync_positions(bufnr, file)
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
                    return c.body:sub(1, 60) .. (#c.body > 60 and "..." or "")
                end,
            }, function(choice)
                if not choice then return end
                comments.delete(choice.id)
                comments.refresh_extmarks(bufnr, file)
                M._auto_save()
            end)
            return
        end
        comments.delete(at_line[1].id)
        comments.refresh_extmarks(bufnr, file)
        M._auto_save()
    end, { buffer = bufnr, desc = "marginalia: delete comment" })

    vim.keymap.set("n", km.next, function()
        comments.sync_positions(bufnr, file)
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

    vim.keymap.set("n", km.prev, function()
        comments.sync_positions(bufnr, file)
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
