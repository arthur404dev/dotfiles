return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      qmlls = {
        cmd = { "qmlls", "-E" },
      },
    },
  },
}
