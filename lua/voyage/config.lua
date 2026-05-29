local M = {}

M.defaults = {
  depth = 2,
  vo_bin = "vo",
  ui = {
    layout = "horizontal", -- horizontal (left/right) | vertical (top/bottom)
    search_position = "top", -- top | bottom
    border = true,
    show_cycles = true,
    kind_symbols = {
      tag = " ",
      category = "󰠱 ",
    },
  },
  win = {
    width = 0.9,
    height = 0.8,
    preview_width = 0.5,
    preview_height = 0.45,
  },
  preview = {
    max_bytes = 1024 * 1024,
  },
}

local function deep_extend(a, b)
  return vim.tbl_deep_extend("force", a, b or {})
end

function M.build(user)
  return deep_extend(M.defaults, user)
end

return M
