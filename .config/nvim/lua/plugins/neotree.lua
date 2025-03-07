local nonicons_extension = require("nvim-nonicons.extentions.nvim-tree")

return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      renderer = {
        icons = {
          glyphs = nonicons_extension.glyphs,
        },
      },
      window = {
        position = "right",
      },
      filesystem = {
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_by_name = {
            ".git",
            ".DS_Store",
          },
          always_show = {
            ".env",
          },
        },
      },
    },
  },
}
