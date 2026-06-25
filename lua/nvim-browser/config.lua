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

local function default_session_path()
  return vim.fn.stdpath("state") .. "/nvim-browser/session.json"
end

local function default_calibration_path()
  return vim.fn.stdpath("state") .. "/nvim-browser/calibration.json"
end

local function normalize_history_limit(value, fallback)
  value = tonumber(value)
  if value == nil then
    return fallback
  end
  value = math.floor(value)
  if value < 0 then
    return 0
  end
  return value
end

M.options = {
  binary = default_binary(),
  graphics = "auto",
  allow_unsafe_multiplexer_graphics = false,
  image_fit = "original",
  user_data_dir = nil,
  download_dir = nil,
  navigation_timeout_ms = 20000,
  viewport = {
    cell_width_px = 10,
    cell_height_px = 20,
  },
  search_url = "https://www.google.com/search?q=%s",
  session = {
    persist = true,
    history_limit = 50,
    path = default_session_path(),
  },
  calibration = {
    persist = true,
    path = default_calibration_path(),
  },
  reader = {
    auto_open_on_ansi_fallback = true,
  },
  live_refresh = {
    enabled = true,
    interval_ms = 1500,
  },
  auto_refresh_on_write = true,
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
      open_under_cursor = "g",
      find = "/",
      hints = "f",
      type_hint_mode = "t",
      submit_hint_mode = "s",
      select_hint_mode = "o",
      toggle_hint_mode = "c",
      jump_hint_mode = "gj",
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
      actions = "?",
      find = "/",
      find_next = "n",
      find_previous = "N",
      hints = "f",
      click_here = "gc",
      double_click_here = "gd",
      right_click_here = "gr",
      hover_here = "gh",
      follow_point_url_here = "gf",
      point_info_here = "gi",
      type_here = "gI",
      submit_here = "gS",
      select_here = "gO",
      type_hint_mode = "t",
      submit_hint_mode = "s",
      submit_focused = "gs",
      select_hint_mode = "o",
      toggle_hint_mode = "c",
      jump_hint_mode = "gj",
      input_text_mode = "i",
      paste_register = "p",
      yank_selection = "y",
      yank_current_url = "Y",
      yank_point_url_here = "gY",
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
      double_click = "<2-LeftMouse>",
      right_click_mouse = "<RightMouse>",
      wheel_down = "<ScrollWheelDown>",
      wheel_up = "<ScrollWheelUp>",
      close = "q",
    },
  },
}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})
  M.options.session = M.options.session or {}
  M.options.session.history_limit = normalize_history_limit(M.options.session.history_limit, 50)
  M.options.session.path = M.options.session.path or default_session_path()
  if M.options.session.persist == nil then
    M.options.session.persist = true
  end
  M.options.calibration = M.options.calibration or {}
  M.options.calibration.path = M.options.calibration.path or default_calibration_path()
  if M.options.calibration.persist == nil then
    M.options.calibration.persist = true
  end
  M.options.reader = M.options.reader or {}
  if M.options.reader.auto_open_on_ansi_fallback == nil then
    M.options.reader.auto_open_on_ansi_fallback = true
  end
  return M.options
end

M._test = {
  default_binary_for_root = default_binary_for_root,
  default_session_path = default_session_path,
  default_calibration_path = default_calibration_path,
  normalize_history_limit = normalize_history_limit,
}

return M
