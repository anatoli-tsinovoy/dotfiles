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
          -- LIGHT (higher contrast)
          c.bg = "#F3F0DF" -- base bg (unchanged)
          c.bg_dark = "#E1DAC0" -- darker than before for floats/pmenus
          c.fg = "#0B0026" -- DARKER fg for contrast (was #110034)
          c.red = "#B22F27" -- slightly deeper hues for syntax punch
          c.green = "#00836C"
          c.yellow = "#A67611"
          c.blue = "#2A0A6B"
          c.magenta = "#C77796"
          c.cyan = "#008E7A"
          c.orange = "#C39216"
        else
          -- DARK (unchanged)
          c.bg = "#110034"
          c.bg_dark = "#0B0026"
          c.fg = "#F3F0DF"
          c.red = "#FF4F44"
          c.green = "#00C8AB"
          c.yellow = "#FFD44F"
          c.blue = "#8217FF"
          c.magenta = "#FFC9D7"
          c.cyan = "#00E6BB"
          c.orange = "#FFD44F"
        end
      end,

      on_highlights = function(h, c)
        local is_light = (vim.o.background == "light")
        if is_light then
          -- Core UI
          -- h.Normal = { fg = "", bg = "#F3F0DF" }
          h.Normal = { fg = "#0B0026" }
          -- h.NormalNC = { fg = "#0B0026", bg = "#F3F0DF" }
          -- h.NormalFloat = { fg = "#0B0026", bg = "#E1DAC0" }
          -- h.FloatBorder = { fg = "#2A0A6B", bg = "#E1DAC0" }
          h.WinSeparator = { fg = "#C4B893" }
          h.CursorLine = { bg = "#E9E4CE" }
          h.LineNr = { fg = "#5B4F85" } -- darker
          h.CursorLineNr = { fg = "#A67611", bold = true }

          -- Selection / Search
          h.Visual = { bg = "#B39AFF" } -- still readable on light bg
          h.Search = { bg = "#FFD44F", fg = "#0B0026" }
          h.IncSearch = { bg = "#FFD44F", fg = "#0B0026" }

          -- Comments & nontext (increase legibility)
          h.Comment = { fg = "#5A5680", italic = true }
          h.NonText = { fg = "#8E86B6" }
          h.Whitespace = { fg = "#C4B893" }

          -- Headline-ish groups (more “ink”)
          h.Identifier = { fg = "#2A0A6B" }
          h.Function = { fg = "#2A0A6B", bold = true }
          h.Keyword = { fg = "#B22F27", bold = true }
          h.Statement = { fg = "#A67611" }
          h.Type = { fg = "#00836C", bold = true }
          h.Constant = { fg = "#C77796" }
          h.String = { fg = "#008E7A" }
          h.Number = { fg = "#B22F27" }

          -- Diagnostics (crisper)
          h.DiagnosticError = { fg = "#B22F27" }
          h.DiagnosticWarn = { fg = "#A67611" }
          h.DiagnosticInfo = { fg = "#2A0A6B" }
          h.DiagnosticHint = { fg = "#00836C" }

          -- Underlines/links
          h.Underlined = { fg = "#2A0A6B", underline = true }
        else
          -- DARK (keep your previous feel)
          h.Visual = { bg = "#330D81" }
          h.Cursor = { fg = "#110034", bg = "#8217FF" }
          h.NormalFloat = { bg = "#0B0026", fg = "#F3F0DF" }
          h.IncSearch = { bg = "#FFD44F", fg = "#110034" }
          h.Search = { bg = "#FFD44F", fg = "#110034" }
          h.Underlined = { fg = "#9A67FF", underline = true }
          h.LineNr = { fg = "#6F66A0" }
          h.CursorLineNr = { fg = "#FFE680", bold = true }
        end
      end,
    },
  },
}
