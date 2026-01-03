return {
  {
    "cbochs/grapple.nvim",
    dependencies = {
      { "nvim-tree/nvim-web-devicons", lazy = true },
    },
    opts = {
      scope = "git", -- also try out "git_branch"
    },
    event = { "BufReadPost", "BufNewFile" },
    cmd = "Grapple",
    keys = {
      { "<leader>ma", "<cmd>Grapple toggle<cr>", desc = "Grapple toggle tag" },
      { "<leader>mm", "<cmd>Grapple toggle_tags<cr>", desc = "Grapple open tags window" },
      { "<leader>mr", "<cmd>Grapple reset<cr>", desc = "Grapple reset tags" },

      { "<leader>[", "<cmd>Grapple cycle_tags next<cr>", desc = "Grapple cycle next tag" },
      { "<leader>]", "<cmd>Grapple cycle_tags prev<cr>", desc = "Grapple cycle previous tag" },

      { "<leader>1", "<cmd>Grapple select index=1<cr>", desc = "Select first tag" },
      { "<leader>2", "<cmd>Grapple select index=2<cr>", desc = "Select second tag" },
      { "<leader>3", "<cmd>Grapple select index=3<cr>", desc = "Select third tag" },
      { "<leader>4", "<cmd>Grapple select index=4<cr>", desc = "Select fourth tag" },
      { "<leader>5", "<cmd>Grapple select index=5<cr>", desc = "Select fifth tag" },
    },
  },
}
