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
    require("marginalia.engine.diffview").open(source or { kind = "worktree_vs_head" })
end

function M.close()
    require("marginalia.engine.diffview").close()
end

return M
