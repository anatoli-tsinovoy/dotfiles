return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      transparent = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
      -- Let Tokyonight auto-pick by :set background=dark/light
      style = "night",
      light_style = "day",
      terminal_colors = false, -- we'll set ANSI ourselves

      -- Supply our own colors for both modes
      on_colors = function(c)
        local is_light = (vim.o.background == "light")
        if is_light then
          -- LIGHT UI (from your plist)
          c.bg = "#F3F0DF" -- Background (Light)
          c.bg_dark = "#E7E2C9"
          c.fg = "#110034" -- Foreground (Light)
          c.red = "#CC3E34" -- ANSI 1
          c.green = "#009A81" -- ANSI 2
          c.yellow = "#CD9A1B" -- ANSI 3
          c.blue = "#330D81" -- ANSI 4
          c.magenta = "#E69AB3" -- ANSI 5
          c.cyan = "#00B39A" -- ANSI 6
          c.orange = "#E6B334" -- from Light ansi11
        else
          -- DARK UI (from your plist)
          c.bg = "#110034" -- Background (Dark)
          c.bg_dark = "#0B0026"
          c.fg = "#F3F0DF" -- Foreground (Dark)
          c.red = "#FF4F44" -- ANSI 1
          c.green = "#00C8AB" -- ANSI 2
          c.yellow = "#FFD44F" -- ANSI 3
          c.blue = "#8217FF" -- ANSI 4
          c.magenta = "#FFC9D7" -- ANSI 5
          c.cyan = "#00E6BB" -- ANSI 6
          c.orange = "#FFD44F" -- reuse yellow-ish
        end
      end,

      on_highlights = function(h, c)
        local is_light = (vim.o.background == "light")
        if is_light then
          h.Visual = { bg = "#B39AFF" } -- Selection (Light)
          h.Cursor = { fg = "#F3F0DF", bg = "#8217FF" } -- Cursor (Light)
          h.NormalFloat = { bg = "#E7E2C9", fg = "#110034" }
          h.IncSearch = { bg = "#FFD44F", fg = "#110034" }
          h.Search = { bg = "#FFD44F", fg = "#110034" }
          h.Underlined = { fg = "#8217FF", underline = true } -- Link (Light)
        else
          h.Visual = { bg = "#330D81" } -- Selection (Dark)
          h.Cursor = { fg = "#110034", bg = "#8217FF" } -- Cursor (Dark)
          h.NormalFloat = { bg = "#0B0026", fg = "#F3F0DF" }
          h.IncSearch = { bg = "#FFD44F", fg = "#110034" }
          h.Search = { bg = "#FFD44F", fg = "#110034" }
          h.Underlined = { fg = "#9A67FF", underline = true } -- Link (Dark)
        end
      end,
    },
  },
}
