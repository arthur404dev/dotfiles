local heimdall_ok, heimdall = pcall(require, "user.heimdall")
local colors = heimdall_ok and heimdall.colors or {}

return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function()
      local lualine = require("lualine")

      local conditions = {
        buffer_not_empty = function()
          return vim.fn.empty(vim.fn.expand("%:t")) ~= 1
        end,
        hide_in_width = function()
          return vim.fn.winwidth(0) > 80
        end,
        check_git_workspace = function()
          local filepath = vim.fn.expand("%:p:h")
          local gitdir = vim.fn.finddir(".git", filepath .. ";")
          return gitdir and #gitdir > 0 and #gitdir < #filepath
        end,
      }

      -- Config
      local config = {
        options = {
          -- Disable sections and component separators
          component_separators = "",
          section_separators = "",
          theme = {
            -- We are going to use lualine_c an lualine_x as left and
            -- right section. Both are highlighted by c theme .  So we
            -- are just setting default looks o statusline
            normal = { c = { fg = colors.text, bg = colors.base } },
            inactive = { c = { fg = colors.text, bg = colors.base } },
          },
        },
        sections = {
          -- these are to remove the defaults
          lualine_a = {},
          lualine_b = {},
          lualine_y = {},
          lualine_z = {},
          -- These will be filled later
          lualine_c = {},
          lualine_x = {},
        },
        inactive_sections = {
          -- these are to remove the defaults
          lualine_a = {},
          lualine_b = {},
          lualine_y = {},
          lualine_z = {},
          lualine_c = {},
          lualine_x = {},
        },
      }

      -- Inserts a component in lualine_c at left section
      local function ins_left(component)
        table.insert(config.sections.lualine_c, component)
      end

      -- Inserts a component in lualine_x at right section
      local function ins_right(component)
        table.insert(config.sections.lualine_x, component)
      end

      -- ins_left({
      --   function()
      --     return "▊"
      --   end,
      --   color = { fg = colors.blue }, -- Sets highlighting of component
      --   padding = { left = 0, right = 1 }, -- We don't need space before this
      -- })

      ins_left({
        -- mode component
        function()
          return ""
        end,
        color = function()
          -- auto change color according to neovims mode
          local mode_color = {
            n = colors.blue,
            i = colors.mauve,
            v = colors.pink,
            [""] = colors.pink,
            V = colors.pink,
            c = colors.green,
            no = colors.blue,
            s = colors.peach,
            S = colors.peach,
            [""] = colors.peach,
            ic = colors.red,
            R = colors.lavender,
            RR = colors.lavender,
            cv = colors.blue,
            ce = colors.blue,
            r = colors.teal,
            rm = colors.teal,
            ["r?"] = colors.teal,
            ["!"] = colors.blue,
            t = colors.blue,
          }
          return { fg = mode_color[vim.fn.mode()] }
        end,
      })

      -- ins_left({
      --   -- filesize component
      --   "filesize",
      --   cond = conditions.buffer_not_empty,
      -- })
      ins_left({
        function()
          return ""
        end,
        color = function()
          -- auto change color according to neovims mode
          local mode_color = {
            n = colors.blue,
            i = colors.mauve,
            v = colors.pink,
            [""] = colors.pink,
            V = colors.pink,
            c = colors.green,
            no = colors.blue,
            s = colors.peach,
            S = colors.peach,
            [""] = colors.peach,
            ic = colors.red,
            R = colors.lavender,
            RR = colors.lavender,
            cv = colors.blue,
            ce = colors.blue,
            r = colors.teal,
            rm = colors.teal,
            ["r?"] = colors.teal,
            ["!"] = colors.blue,
            t = colors.blue,
          }
          return { fg = mode_color[vim.fn.mode()] }
        end,
      })

      ins_left({
        "filename",
        cond = conditions.buffer_not_empty,
        color = { fg = colors.lavender, gui = "bold" },
      })

      ins_left({
        function()
          return "|"
        end,
        color = { fg = colors.surface0 },
      })

      ins_left({ "location", color = { fg = colors.overlay0 } })

      ins_left({ "progress", color = { fg = colors.overlay0, gui = "bold" } })

      ins_left({
        "diagnostics",
        sources = { "nvim_diagnostic" },
        symbols = { error = " ", warn = " ", info = " " },
        diagnostics_color = {
          color_error = { fg = colors.red },
          color_warn = { fg = colors.yellow },
          color_info = { fg = colors.teal },
        },
      })

      -- Insert mid section. You can make any number of sections in neovim :)
      -- for lualine it's any number greater then 2
      ins_left({
        function()
          return "%="
        end,
      })

      ins_left({
        "buffers",
        hide_filename_extension = true,
        mode = 1,
        max_length = vim.o.columns * 0.25,
        buffers_color = {
          active = { fg = colors.mauve },
          inactive = { fg = colors.surface0 },
        },
      })

      ins_right({
        "branch",
        icon = "  ",
        color = { fg = colors.lavender, gui = "bold" },
      })

      ins_right({
        -- Lsp server name .
        function()
          local msg = "no lsp"
          local buf_ft = vim.api.nvim_get_option_value("filetype", { buf = 0 })
          local clients = vim.lsp.get_clients()
          if next(clients) == nil then
            return msg
          end
          for _, client in ipairs(clients) do
            local filetypes = client.config.filetypes
            if filetypes and vim.fn.index(filetypes, buf_ft) ~= -1 then
              return client.name
            end
          end
          return msg
        end,
        icon = "  ",
        color = { fg = colors.lavender, gui = "bold" },
      })

      ins_right({
        function()
          return "|"
        end,
        color = { fg = colors.surface0 },
      })

      ins_right({
        "o:encoding",
        cond = conditions.hide_in_width,
        color = { fg = colors.blue, gui = "bold" },
      })

      ins_right({
        function()
          return ""
        end,
        color = { fg = colors.blue },
      })

      ins_right({
        "fileformat",
        icons_enabled = true,
        color = { fg = colors.blue, gui = "bold" },
      })

      -- ins_right({
      --   function()
      --     return "▊"
      --   end,
      --   color = { fg = colors.blue },
      --   padding = { left = 1 },
      -- })

      lualine.setup(config)
      return config
    end,
  },
}
