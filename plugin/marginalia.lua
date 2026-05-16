if vim.g.loaded_marginalia then return end
vim.g.loaded_marginalia = 1

vim.api.nvim_create_user_command("Review", function(_)
    require("marginalia").open({ kind = "worktree_vs_head" })
end, { nargs = 0, desc = "Open a marginalia review session (worktree vs HEAD)" })

vim.api.nvim_create_user_command("ReviewClose", function(_)
    require("marginalia").close()
end, { desc = "Close the active marginalia review session" })

vim.api.nvim_create_user_command("ReviewSave", function(_)
    require("marginalia").save()
end, { desc = "Flush comments to REVIEW.md" })

vim.api.nvim_create_user_command("ReviewClear", function(_)
    require("marginalia").clear()
end, { desc = "Delete REVIEW.md and reset all comments" })
