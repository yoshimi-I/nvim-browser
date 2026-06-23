local M = {}

local function default_binary_for_root(root)
  for _, profile in ipairs({ "release", "debug" }) do
    local candidate = root .. "/target/" .. profile .. "/nvbrowser"
    if vim.fn.executable(candidate) == 1 then
      return candidate
    end
  end
  return "nvbrowser"
end

local function default_binary()
  local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
  return default_binary_for_root(root)
end

M.options = {
  binary = default_binary(),
  graphics = "auto",
  image_fit = "original",
  search_url = "https://www.google.com/search?q=%s",
  live_refresh = {
    enabled = true,
    interval_ms = 1500,
  },
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
      type_hint_mode = "t",
      submit_hint_mode = "s",
    },
  },
  preview_keymaps = {
    enabled = true,
    scroll_pixels = 400,
    mappings = {
      reload = "r",
      back = "H",
      forward = "L",
      scroll_down = "j",
      scroll_up = "k",
      address = "a",
      find = "/",
      hints = "f",
      type_hint_mode = "t",
      submit_hint_mode = "s",
      input_text_mode = "i",
      key_enter = "<CR>",
      key_tab = "<Tab>",
      key_shift_tab = "<S-Tab>",
      key_backspace = "<BS>",
      key_up = "<Up>",
      key_down = "<Down>",
      key_left = "<Left>",
      key_right = "<Right>",
      stop = "<Esc>",
      left_click = "<LeftMouse>",
      wheel_down = "<ScrollWheelDown>",
      wheel_up = "<ScrollWheelUp>",
      close = "q",
    },
  },
}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})
  return M.options
end

M._test = {
  default_binary_for_root = default_binary_for_root,
}

return M
