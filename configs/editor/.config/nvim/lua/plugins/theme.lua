-- Load heimdall colors at startup (before any plugin setup)
local heimdall_ok, heimdall_module = pcall(require, "user.heimdall")
local colors = {}
local color_overrides = {}

if heimdall_ok and type(heimdall_module) == "table" then
  colors = heimdall_module.colors or {}
  color_overrides = heimdall_module.color_overrides or {}
end

-- Global colors reference that gets updated on hot-reload
local global_colors = colors

-- Global mode colors table that gets updated on hot-reload
local global_mode_colors = {}

-- Initialize global_mode_colors with default colors if available
if next(colors) ~= nil then
  global_mode_colors = {
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
end

local function setup_catppuccin(new_colors, new_color_overrides)
  new_colors = new_colors or colors
  new_color_overrides = new_color_overrides or color_overrides
  require("catppuccin").setup({
    float = { transparent = false, solid = false },
    transparent_background = true,
    term_colors = false,
    color_overrides = new_color_overrides,
    integrations = {
      blink_cmp = true,
      neotree = true,
    },
  })
end

-- Helper to update global mode colors without recreating lualine
local function update_mode_colors(new_colors)
  global_mode_colors.n = new_colors.blue
  global_mode_colors.i = new_colors.mauve
  global_mode_colors.v = new_colors.pink
  global_mode_colors[""] = new_colors.pink
  global_mode_colors.V = new_colors.pink
  global_mode_colors.c = new_colors.green
  global_mode_colors.no = new_colors.blue
  global_mode_colors.s = new_colors.peach
  global_mode_colors.S = new_colors.peach
  global_mode_colors[""] = new_colors.peach
  global_mode_colors.ic = new_colors.red
  global_mode_colors.R = new_colors.lavender
  global_mode_colors.RR = new_colors.lavender
  global_mode_colors.cv = new_colors.blue
  global_mode_colors.ce = new_colors.blue
  global_mode_colors.r = new_colors.teal
  global_mode_colors.rm = new_colors.teal
  global_mode_colors["r?"] = new_colors.teal
  global_mode_colors["!"] = new_colors.blue
  global_mode_colors.t = new_colors.blue
end

local function setup_lualine(new_colors)
  new_colors = new_colors or colors
  local lualine = require("lualine")

  -- Update global colors reference
  global_colors = new_colors
  -- Update the global mode colors
  update_mode_colors(new_colors)

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

  local config = {
    options = {
      component_separators = "",
      section_separators = "",
      theme = {
        normal = { c = { fg = global_colors.text, bg = global_colors.base } },
        inactive = { c = { fg = global_colors.text, bg = global_colors.base } },
      },
    },
    sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_y = {},
      lualine_z = {},
      lualine_c = {},
      lualine_x = {},
    },
    inactive_sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_y = {},
      lualine_z = {},
      lualine_c = {},
      lualine_x = {},
    },
  }

  local function ins_left(component)
    table.insert(config.sections.lualine_c, component)
  end

  local function ins_right(component)
    table.insert(config.sections.lualine_x, component)
  end

  ins_left({
    function()
      return ""
    end,
    color = function()
      local mode = vim.fn.mode()
      return { fg = global_mode_colors[mode] or global_colors.text }
    end,
  })

  ins_left({
    function()
      return ""
    end,
    color = function()
      local mode = vim.fn.mode()
      return { fg = global_mode_colors[mode] or global_colors.text }
    end,
  })

  ins_left({
    "filename",
    cond = conditions.buffer_not_empty,
    color = function()
      return { fg = global_colors.lavender, gui = "bold" }
    end,
  })

  ins_left({
    function()
      return "|"
    end,
    color = function()
      return { fg = global_colors.surface0 }
    end,
  })

  ins_left({
    "location",
    color = function()
      return { fg = global_colors.overlay0 }
    end,
  })

  ins_left({
    "progress",
    color = function()
      return { fg = global_colors.overlay0, gui = "bold" }
    end,
  })

  ins_left({
    "diagnostics",
    sources = { "nvim_diagnostic" },
    symbols = { error = " ", warn = " ", info = " " },
    diagnostics_color = {
      color_error = function()
        return { fg = global_colors.red }
      end,
      color_warn = function()
        return { fg = global_colors.yellow }
      end,
      color_info = function()
        return { fg = global_colors.teal }
      end,
    },
  })

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
      active = function()
        return { fg = global_colors.mauve }
      end,
      inactive = function()
        return { fg = global_colors.surface0 }
      end,
    },
  })

  ins_right({
    "branch",
    icon = "  ",
    color = function()
      return { fg = global_colors.lavender, gui = "bold" }
    end,
  })

  ins_right({
    function()
      return "|"
    end,
    color = function()
      return { fg = global_colors.surface0 }
    end,
  })

  ins_right({
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
    color = { fg = global_colors.lavender, gui = "bold" },
  })

  lualine.setup(config)
  return config
end

local function setup_incline(new_colors)
  new_colors = new_colors or colors
  require("incline").setup({
    window = {
      padding = 0,
      margin = { horizontal = 0 },
    },
    render = function(props)
      local lazy_icons = LazyVim.config.icons
      local mini_icons = require("mini.icons")

      local function get_filename()
        local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ":t")
        if filename == "" then
          filename = "[No Name]"
        end
        local ft_icon, ft_color = mini_icons.get("file", filename)
        local modified = vim.bo[props.buf].modified
        return {
          " ",
          { filename, gui = modified and "bold,italic" or "bold" },
          " ",
          ft_icon and { ft_icon, " ", guibg = "none", group = ft_color } or "",
        }
      end

      local function get_diagnostics()
        local icons = {
          error = lazy_icons.diagnostics.Error,
          warn = lazy_icons.diagnostics.Warn,
          info = lazy_icons.diagnostics.Info,
          hint = lazy_icons.diagnostics.Hint,
        }
        local labels = {}

        for severity, icon in pairs(icons) do
          local n = #vim.diagnostic.get(props.buf, { severity = vim.diagnostic.severity[string.upper(severity)] })
          if n > 0 then
            table.insert(labels, { " " .. icon .. n, group = "DiagnosticSign" .. severity })
          end
        end
        if #labels > 0 then
          table.insert(labels, { " |" })
        end
        return labels
      end

      local function get_grapple_status()
        local grapple_status
        grapple_status = require("grapple").name_or_index({ buffer = props.buf }) or ""
        if grapple_status ~= "" then
          grapple_status = { { " 󰛢 ", guifg = new_colors.sky }, { grapple_status, guifg = new_colors.sky } }
        end
        return grapple_status
      end

      return {
        { get_diagnostics() },
        { get_grapple_status() },
        { get_filename() },
        guibg = props.focused and new_colors.mantle or new_colors.surface0,
      }
    end,
  })
end

-- Initialize everything with heimdall colors if available
local function initialize_theme()
  if heimdall_ok and next(colors) ~= nil then
    -- Set up catppuccin with heimdall colors
    setup_catppuccin(colors, color_overrides)
    -- Apply the colorscheme immediately
    vim.cmd(":silent! colorscheme catppuccin-mocha")
  end
end

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000, -- Load this before other plugins
    config = function()
      -- Apply heimdall colors if available, otherwise use defaults
      setup_catppuccin(colors, color_overrides)
      if heimdall_ok and next(colors) ~= nil then
        vim.cmd(":silent! colorscheme catppuccin-mocha")
      end
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    config = function()
      setup_lualine(colors)
    end,
  },
  {
    "b0o/incline.nvim",
    name = "incline",
    event = {
      "BufReadPre",
      "BufNewFile",
    },
    dependencies = { "mini.icons" },
    config = function()
      setup_incline(colors)
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        -- Only set colorscheme if heimdall colors are not available
        if not heimdall_ok or next(colors) == nil then
          return "catppuccin-mocha"
        end
        -- Return nil to prevent LazyVim from setting a colorscheme
        return nil
      end,
    },
    init = function()
      local user_dir = vim.fn.stdpath("config") .. "/lua/user/"
      local heimdall_file = user_dir .. "heimdall.lua"

      -- Initialize theme at startup if heimdall is available
      if heimdall_ok and next(colors) ~= nil then
        vim.defer_fn(function()
          initialize_theme()
        end, 1)
      end

      local last_mtime = 0
      local is_reloading = false -- Prevent concurrent reloads

      local function check_and_reload_heimdall()
        -- Skip if already reloading
        if is_reloading then
          return
        end

        if vim.fn.filereadable(heimdall_file) ~= 1 then
          return
        end

        local current_mtime = vim.fn.getftime(heimdall_file)

        if current_mtime == -1 then
          return
        end

        if current_mtime > last_mtime then
          last_mtime = current_mtime
          is_reloading = true

          -- Clear caches
          package.loaded["user.heimdall"] = nil

          vim.defer_fn(function()
            local reloaded_heimdall_ok, reloaded_heimdall_module = pcall(require, "user.heimdall")
            local new_colors = {}
            local new_color_overrides = {}

            if reloaded_heimdall_ok and type(reloaded_heimdall_module) == "table" then
              new_colors = reloaded_heimdall_module.colors or {}
              new_color_overrides = reloaded_heimdall_module.color_overrides or {}

              -- Only reload if colors actually changed
              local colors_changed = false
              for k, v in pairs(new_colors) do
                if colors[k] ~= v then
                  colors_changed = true
                  break
                end
              end

              if colors_changed then
                -- Update global colors
                colors = new_colors
                color_overrides = new_color_overrides
                global_colors = new_colors

                -- Clear plugin caches
                package.loaded["catppuccin"] = nil
                package.loaded["incline"] = nil

                -- Reconfigure catppuccin and incline
                setup_catppuccin(new_colors, new_color_overrides)
                setup_incline(new_colors)

                -- Update mode colors
                update_mode_colors(new_colors)

                vim.cmd(":silent! colorscheme catppuccin-mocha")
                vim.cmd(":silent! doautocmd ColorScheme")

                -- We need to reconfigure lualine to update the theme background
                -- But do it in a deferred way to minimize blinking
                vim.defer_fn(function()
                  package.loaded["lualine"] = nil
                  setup_lualine(new_colors)
                end, 1)

                vim.notify("Theme colors updated successfully", vim.log.levels.INFO, { title = "Heimdall" })
              end
            end

            is_reloading = false
          end, 50) -- Reduced delay from 100ms to 50ms
        end
      end

      local timer = vim.uv.new_timer()
      local timer_interval_ms = 500

      -- Start timer after a small delay to ensure everything is loaded
      vim.defer_fn(function()
        timer:start(timer_interval_ms, timer_interval_ms, vim.schedule_wrap(check_and_reload_heimdall))
      end, 100)

      vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
          timer:stop()
          timer:close()
        end,
      })
    end,
  },
  { "yamatsum/nvim-nonicons" },
}
