local M = {}

local function set_default_hl(name, link)
    if vim.fn.hlexists(name) == 0 or vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = name })) then
        vim.api.nvim_set_hl(0, name, { link = link })
    end
end

set_default_hl("MarginaliaBorder", "FloatBorder")
set_default_hl("MarginaliaTitle", "FloatBorder")

local _input_id = 0

-- Open a floating input buffer for writing a comment.
-- opts.on_submit(body: string) called with buffer contents on save.
-- opts.on_cancel() called when user quits without saving.
-- opts.initial (optional) string to pre-fill the buffer with (for editing).
function M.open_input(opts)
    opts = opts or {}
    local width = math.min(80, math.floor(vim.o.columns * 0.6))
    local height = math.min(10, math.floor(vim.o.lines * 0.3))

    _input_id = _input_id + 1
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = "acwrite"
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_buf_set_name(buf, "marginalia://comment/" .. _input_id)

    if opts.initial then
        local lines = vim.split(opts.initial, "\n", { plain = true })
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    end

    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        row = row,
        col = col,
        width = width,
        height = height,
        style = "minimal",
        border = "rounded",
        title = " Comment ",
        title_pos = "center",
    })
    vim.wo[win].winhighlight = "Normal:Normal,FloatBorder:MarginaliaBorder,FloatTitle:MarginaliaTitle"

    vim.cmd("startinsert")

    local submitted = false

    local function close_float()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end

    vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = buf,
        callback = function()
            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            local body = vim.fn.trim(table.concat(lines, "\n"))
            if body == "" then
                vim.notify("marginalia: empty comment, discarding", vim.log.levels.WARN)
            else
                submitted = true
                if opts.on_submit then opts.on_submit(body) end
            end
            vim.schedule(close_float)
        end,
    })

    vim.api.nvim_create_autocmd("BufUnload", {
        buffer = buf,
        callback = function()
            if not submitted then
                if opts.on_cancel then opts.on_cancel() end
            end
        end,
    })

    -- q in normal mode cancels
    vim.keymap.set("n", "q", function()
        close_float()
    end, { buffer = buf, nowait = true })
end

-- Open a read-only floating window showing comment(s).
-- comments: list of {body, line, line_end?, status}
function M.open_view(comments)
    if #comments == 0 then
        vim.notify("marginalia: no comments on this line", vim.log.levels.INFO)
        return
    end

    local lines = {}
    for i, c in ipairs(comments) do
        if i > 1 then
            table.insert(lines, "---")
        end
        local header = c.line_end
            and string.format("Lines %d–%d [%s]", c.line, c.line_end, c.status)
            or string.format("Line %d [%s]", c.line, c.status)
        table.insert(lines, header)
        for _, l in ipairs(vim.split(c.body, "\n", { plain = true })) do
            table.insert(lines, l)
        end
    end

    local width = math.min(80, math.floor(vim.o.columns * 0.6))
    local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.4))

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        row = row,
        col = col,
        width = width,
        height = height,
        style = "minimal",
        border = "rounded",
        title = " Review Comments ",
        title_pos = "center",
    })
    vim.wo[win].winhighlight = "Normal:Normal,FloatBorder:MarginaliaBorder,FloatTitle:MarginaliaTitle"

    vim.keymap.set("n", "q", function()
        vim.api.nvim_win_close(win, true)
        vim.api.nvim_buf_delete(buf, { force = true })
    end, { buffer = buf, nowait = true })

    vim.keymap.set("n", "<Esc>", function()
        vim.api.nvim_win_close(win, true)
        vim.api.nvim_buf_delete(buf, { force = true })
    end, { buffer = buf, nowait = true })
end

return M
