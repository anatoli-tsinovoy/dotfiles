-- Vendored from goldos24/rainbow-variables-nvim (MIT license)
-- Modified: configurable token_types filter, removed WIP scope shadowing code
local M = {}

local color_usage_count = {}
local ids_by_variable = {}

local function hash_name(varname, color_count, reduce_collisions)
  if ids_by_variable[varname] then
    return ids_by_variable[varname]
  end

  local ret = 0
  for i = 1, #varname do
    ret = ((ret * 27) + string.byte(varname, i)) % color_count
  end

  if reduce_collisions then
    local min = color_usage_count[ret + 1]
    local min_index = ret + 1
    for i = ret + 1, ret + 19, 3 do
      local index = (i - 1) % color_count + 1
      if color_usage_count[index] < min then
        min = color_usage_count[index]
        min_index = index
      end
    end
    ret = min_index - 1
  end

  ids_by_variable[varname] = ret
  color_usage_count[ret + 1] = color_usage_count[ret + 1] + 1
  return ret
end

function M.setup(config)
  config = config or {}
  vim.o.termguicolors = true

  local palette = config.palette or {
    "#cca650", "#50a6fe", "#ffa6fe", "#ffc66b", "#c600ff", "#aaffaa", "#bbbbbb", "#00ff44",
    "#009900", "#995500", "#3355aa", "#009977", "#bbbb00", "#66ffff", "#ff9999", "#ffff66",
  }

  local color_count = #palette
  for i, color in ipairs(palette) do
    vim.api.nvim_set_hl(0, "VarName" .. (i - 1), { fg = color })
  end

  for i = 1, color_count do
    color_usage_count[i] = 0
  end

  local reduce_collisions = config.reduce_color_collisions or false

  local token_types = config.token_types or { variable = true, parameter = true, property = true }

  if config.semantic_background_colors then
    vim.api.nvim_set_hl(0, "@lsp.type.parameter", { bg = "#002222" })
    vim.api.nvim_set_hl(0, "@lsp.type.property", { bg = "#000000" })
    vim.api.nvim_set_hl(0, "@lsp.type.variable", { bg = "#000030" })
  end

  vim.api.nvim_create_autocmd("LspTokenUpdate", {
    group = vim.api.nvim_create_augroup("RainbowVariables", { clear = true }),
    callback = function(args)
      local token = args.data.token
      if not token_types[token.type] then
        return
      end
      local line = vim.api.nvim_buf_get_lines(args.buf, token.line, token.line + 1, true)[1]
      local varname = string.sub(line, token.start_col + 1, token.end_col)
      vim.lsp.semantic_tokens.highlight_token(
        token,
        args.buf,
        args.data.client_id,
        "VarName" .. hash_name(varname, color_count, reduce_collisions)
      )
    end,
  })
end

return M
