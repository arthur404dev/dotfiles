return {
  "saghen/blink.cmp",
  enabled = true,

  dependencies = {
    "moyiz/blink-emoji.nvim",
    "Kaiser-Yang/blink-cmp-dictionary",
  },
  opts = function(_, opts)
    opts.enabled = function()
      -- Get the current buffer's filetype
      local filetype = vim.bo[0].filetype

      -- Disable for Telescope buffers
      if
          filetype == "TelescopePrompt"
          or filetype == "minifiles"
          or filetype == "neo-tree"
          or filetype == "neo-tree-popup"
          or filetype == "snacks_picker_input"
          or filetype == "snacks_input"
      then
        return false
      end
      return true
    end

    opts.appearance = {
      nerd_font_variant = "normal"
    }

    opts.sources = vim.tbl_deep_extend("force", opts.sources or {}, {
      default = { "lsp", "path", "snippets", "buffer", "dadbod", "emoji" },
      compat = { "avante_commands", "avante_mentions", "avante_files" },
      providers = {
        lsp = {
          name = "lsp",
          enabled = true,
          module = "blink.cmp.sources.lsp",
          score_offset = 90, -- the higher the number, the higher the priority
        },
        path = {
          name = "Path",
          module = "blink.cmp.sources.path",
          score_offset = 25,
          fallbacks = { "snippets", "buffer" },
          opts = {
            trailing_slash = false,
            label_trailing_slash = true,
            get_cwd = function(context)
              return vim.fn.expand(("#%d:p:h"):format(context.bufnr))
            end,
            show_hidden_files_by_default = true,
          },
        },
        buffer = {
          name = "Buffer",
          enabled = true,
          max_items = 3,
          module = "blink.cmp.sources.buffer",
          min_keyword_length = 4,
          score_offset = 15, -- the higher the number, the higher the priority
        },
        emoji = {
          module = "blink-emoji",
          name = "Emoji",
          score_offset = 15,        -- the higher the number, the higher the priority
          opts = { insert = true }, -- Insert emoji (default) or complete its name
        },
      },
    })

    -- opts.keymap = {
    --   preset = "default",
    --   ["<Tab>"] = { "snippet_forward", "fallback" },
    --   ["<S-Tab>"] = { "snippet_backward", "fallback" },
    --
    --   ["<Up>"] = { "select_prev", "fallback" },
    --   ["<Down>"] = { "select_next", "fallback" },
    --   ["<C-p>"] = { "select_prev", "fallback" },
    --   ["<C-n>"] = { "select_next", "fallback" },
    --
    --   ["<S-k>"] = { "scroll_documentation_up", "fallback" },
    --   ["<S-j>"] = { "scroll_documentation_down", "fallback" },
    --
    --   ["<C-e>"] = { "show", "show_documentation", "hide_documentation" },
    --   -- ["<C-e>"] = { "hide", "fallback" },
    -- }

    return opts
  end,
}
