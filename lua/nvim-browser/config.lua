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
  user_data_dir = nil,
  viewport = {
    cell_width_px = 10,
    cell_height_px = 20,
  },
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
      select_hint_mode = "o",
      toggle_hint_mode = "c",
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
      page_down = "<PageDown>",
      page_up = "<PageUp>",
      scroll_top = "gg",
      scroll_bottom = "G",
      half_page_down = "<C-d>",
      half_page_up = "<C-u>",
      zoom_in = "+",
      zoom_out = "-",
      zoom_reset = "=",
      address = "a",
      find = "/",
      find_next = "n",
      find_previous = "N",
      hints = "f",
      click_here = "gc",
      hover_here = "gh",
      type_hint_mode = "t",
      submit_hint_mode = "s",
      select_hint_mode = "o",
      toggle_hint_mode = "c",
      input_text_mode = "i",
      paste_register = "p",
      yank_selection = "y",
      key_enter = "<CR>",
      key_tab = "<Tab>",
      key_shift_tab = "<S-Tab>",
      key_backspace = "<BS>",
      key_delete = "x",
      key_escape = "ge",
      key_select_all = "A",
      key_focus_location = "gl",
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
