local keymap = vim.keymap
-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
-- vim.keymap.del("n", "<leader>w|")
-- vim.keymap.del("n", "<leader>|")
keymap.set("n", "<leader>za", "gg0VG", { desc = "Select all", remap = true })
keymap.set("n", "gh", "K", { desc = "Show Hover", remap = true })

keymap.del("n", "<leader>K")
keymap.del("n", "<leader>-")
keymap.del("n", "<leader>|")
keymap.del("n", "<leader>`")
