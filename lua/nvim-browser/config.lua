local M = {}

local function default_binary()
  local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
  local candidate = root .. "/target/debug/nvbrowser"
  if vim.fn.executable(candidate) == 1 then
    return candidate
  end
  return "nvbrowser"
end

M.options = {
  binary = default_binary(),
  graphics = "auto",
  image_fit = "original",
  search_url = "https://www.google.com/search?q=%s",
  keymaps = {
    enabled = false,
    prefix = "<leader>b",
    scroll_pixels = 400,
    mappings = {
      reload = "r",
      back = "h",
      forward = "l",
      scroll_down = "j",
      scroll_up = "k",
      address = "a",
      find = "/",
      hints = "f",
    },
  },
}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})
  return M.options
end

return M
