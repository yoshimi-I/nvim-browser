package.path = "lua/?.lua;lua/?/init.lua;" .. package.path

local config = require("nvim-browser.config")

local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/target/release", "p")
vim.fn.mkdir(root .. "/target/debug", "p")
vim.fn.writefile({ "#!/bin/sh" }, root .. "/target/release/nvbrowser")
vim.fn.writefile({ "#!/bin/sh" }, root .. "/target/debug/nvbrowser")
vim.fn.setfperm(root .. "/target/release/nvbrowser", "rwxr-xr-x")
vim.fn.setfperm(root .. "/target/debug/nvbrowser", "rwxr-xr-x")

assert(
  config._test.default_binary_for_root(root) == root .. "/target/release/nvbrowser",
  "default binary should prefer release builds from plugin installs"
)

vim.fn.delete(root .. "/target/release/nvbrowser")
assert(
  config._test.default_binary_for_root(root) == root .. "/target/debug/nvbrowser",
  "default binary should fall back to debug builds in development checkouts"
)

vim.fn.delete(root .. "/target/debug/nvbrowser")
assert(
  config._test.default_binary_for_root(root) == "nvbrowser",
  "default binary should fall back to nvbrowser on PATH"
)

local original_options = vim.deepcopy(config.options)
local configured = config.setup({ binary = "/opt/nvbrowser/bin/nvbrowser" })
assert(
  configured.binary == "/opt/nvbrowser/bin/nvbrowser",
  "setup should preserve a custom backend binary path"
)
assert(configured.user_data_dir == nil, "persistent Chromium profile directory should default to nil")
assert(configured.download_dir == nil, "download directory should default to nil")
assert(configured.navigation_timeout_ms == 20000, "navigation timeout should default to 20 seconds")
assert(configured.allow_unsafe_multiplexer_graphics == false, "unsafe multiplexer graphics should default to disabled")
assert(configured.session.persist == true, "session recents should persist by default")
assert(configured.session.history_limit == 50, "session recents should default to the existing history limit")
assert(
  configured.session.path == vim.fn.stdpath("state") .. "/nvim-browser/session.json",
  "session persistence path should default to the plugin state path"
)
assert(configured.calibration.persist == true, "viewport calibration persistence should default to enabled")
assert(
  configured.calibration.path == vim.fn.stdpath("state") .. "/nvim-browser/calibration.json",
  "viewport calibration path should default to the plugin state path"
)
assert(configured.reader.auto_open_on_ansi_fallback == true, "reader should auto-open for ANSI fallback by default")
assert(configured.preview_keymaps.enabled == true, "preview-local keymaps should be enabled by default")
assert(configured.preview_keymaps.mappings.close == "q", "preview-local keymaps should include a close mapping")
assert(
  configured.preview_keymaps.mappings.left_click == "<LeftMouse>",
  "preview-local keymaps should include a left-click mouse mapping"
)
assert(
  configured.preview_keymaps.mappings.double_click == "<2-LeftMouse>",
  "preview-local keymaps should include a double-click mouse mapping"
)
assert(
  configured.preview_keymaps.mappings.wheel_down == "<ScrollWheelDown>",
  "preview-local keymaps should include a wheel-down mouse mapping"
)

local profile_config = config.setup({ user_data_dir = "/tmp/nvbrowser-profile" })
assert(
  profile_config.user_data_dir == "/tmp/nvbrowser-profile",
  "setup should preserve a persistent Chromium profile directory"
)
local download_config = config.setup({ download_dir = "/tmp/nvbrowser-downloads" })
assert(download_config.download_dir == "/tmp/nvbrowser-downloads", "setup should preserve a download directory")
local timeout_config = config.setup({ navigation_timeout_ms = 1234 })
assert(timeout_config.navigation_timeout_ms == 1234, "setup should preserve custom navigation timeouts")
local unsafe_graphics_config = config.setup({ allow_unsafe_multiplexer_graphics = true })
assert(unsafe_graphics_config.allow_unsafe_multiplexer_graphics == true, "setup should preserve unsafe multiplexer graphics opt-in")
local reader_config = config.setup({ reader = { auto_open_on_ansi_fallback = false } })
assert(reader_config.reader.auto_open_on_ansi_fallback == false, "setup should allow disabling ANSI fallback reader auto-open")
assert(
  configured.preview_keymaps.mappings.wheel_up == "<ScrollWheelUp>",
  "preview-local keymaps should include a wheel-up mouse mapping"
)
assert(configured.live_refresh.enabled == true, "live refresh should be enabled by default")
assert(configured.live_refresh.interval_ms == 1500, "live refresh should default to a conservative interval")
assert(configured.viewport.cell_width_px == 10, "viewport cell width should default to the existing 10px geometry")
assert(configured.viewport.cell_height_px == 20, "viewport cell height should default to the existing 20px geometry")
assert(configured.preview_keymaps.mappings.stop == "<Esc>", "preview-local keymaps should include a stop mapping")
assert(configured.preview_keymaps.mappings.input_text_mode == "i", "preview-local keymaps should include focused input mode")
assert(configured.preview_keymaps.mappings.paste_register == "p", "preview-local keymaps should include register paste")
assert(configured.preview_keymaps.mappings.yank_selection == "y", "preview-local keymaps should include browser selection yank")
assert(configured.preview_keymaps.mappings.yank_current_url == "Y", "preview-local keymaps should include current URL yank")
assert(configured.preview_keymaps.mappings.yank_point_url_here == "gY", "preview-local keymaps should include cursor link URL yank")
assert(configured.preview_keymaps.mappings.key_enter == "<CR>", "preview-local keymaps should include Enter forwarding")
assert(configured.preview_keymaps.mappings.key_tab == "<Tab>", "preview-local keymaps should include Tab forwarding")
assert(configured.preview_keymaps.mappings.key_shift_tab == "<S-Tab>", "preview-local keymaps should include Shift-Tab forwarding")
assert(configured.preview_keymaps.mappings.key_backspace == "<BS>", "preview-local keymaps should include Backspace forwarding")
assert(configured.preview_keymaps.mappings.key_delete == "x", "preview-local keymaps should include Delete forwarding")
assert(configured.preview_keymaps.mappings.key_escape == "ge", "preview-local keymaps should include browser Escape forwarding")
assert(configured.preview_keymaps.mappings.key_select_all == "A", "preview-local keymaps should include select-all forwarding")
assert(configured.preview_keymaps.mappings.key_focus_location == "gl", "preview-local keymaps should include address prompt shortcut")
assert(configured.preview_keymaps.mappings.key_up == "<Up>", "preview-local keymaps should include ArrowUp forwarding")
assert(configured.preview_keymaps.mappings.key_down == "<Down>", "preview-local keymaps should include ArrowDown forwarding")
assert(configured.preview_keymaps.mappings.key_left == "<Left>", "preview-local keymaps should include ArrowLeft forwarding")
assert(configured.preview_keymaps.mappings.key_right == "<Right>", "preview-local keymaps should include ArrowRight forwarding")
assert(configured.preview_keymaps.mappings.page_down == "<PageDown>", "preview-local keymaps should include page-down")
assert(configured.preview_keymaps.mappings.page_up == "<PageUp>", "preview-local keymaps should include page-up")
assert(configured.preview_keymaps.mappings.scroll_top == "gg", "preview-local keymaps should include scroll-to-top")
assert(configured.preview_keymaps.mappings.scroll_bottom == "G", "preview-local keymaps should include scroll-to-bottom")
assert(configured.preview_keymaps.mappings.half_page_down == "<C-d>", "preview-local keymaps should include half-page down")
assert(configured.preview_keymaps.mappings.half_page_up == "<C-u>", "preview-local keymaps should include half-page up")
assert(configured.preview_keymaps.mappings.zoom_in == "+", "preview-local keymaps should include zoom in")
assert(configured.preview_keymaps.mappings.zoom_out == "-", "preview-local keymaps should include zoom out")
assert(configured.preview_keymaps.mappings.zoom_reset == "=", "preview-local keymaps should include zoom reset")
assert(configured.preview_keymaps.mappings.actions == "?", "preview-local keymaps should include actions picker")
assert(configured.preview_keymaps.mappings.click_here == "gc", "preview-local keymaps should include cursor click")
assert(configured.preview_keymaps.mappings.right_click_here == "gr", "preview-local keymaps should include cursor right click")
assert(configured.preview_keymaps.mappings.right_click_mouse == "<RightMouse>", "preview-local keymaps should include mouse right click")
assert(configured.preview_keymaps.mappings.hover_here == "gh", "preview-local keymaps should include cursor hover")
assert(configured.preview_keymaps.mappings.follow_point_url_here == "gf", "preview-local keymaps should include cursor link follow")
assert(configured.preview_keymaps.mappings.point_info_here == "gi", "preview-local keymaps should include cursor point inspection")
assert(configured.preview_keymaps.mappings.type_here == "gI", "preview-local keymaps should include cursor text input")
assert(configured.preview_keymaps.mappings.submit_here == "gS", "preview-local keymaps should include cursor text submit")
assert(configured.preview_keymaps.mappings.find_next == "n", "preview-local keymaps should include find-next")
assert(configured.preview_keymaps.mappings.find_previous == "N", "preview-local keymaps should include find-previous")
assert(
  configured.keymaps.mappings.type_hint_mode == "t",
  "global keymaps should include a hinted input mapping"
)
assert(
  configured.keymaps.mappings.submit_hint_mode == "s",
  "global keymaps should include a hinted submit mapping"
)
assert(
  configured.keymaps.mappings.select_hint_mode == "o",
  "global keymaps should include a hinted select mapping"
)
assert(
  configured.keymaps.mappings.toggle_hint_mode == "c",
  "global keymaps should include a hinted checkbox/radio toggle mapping"
)
assert(
  configured.keymaps.mappings.jump_hint_mode == "gj",
  "global keymaps should include a hinted cursor jump mapping"
)
assert(
  configured.preview_keymaps.mappings.type_hint_mode == "t",
  "preview-local keymaps should include a hinted input mapping"
)
assert(
  configured.preview_keymaps.mappings.submit_hint_mode == "s",
  "preview-local keymaps should include a hinted submit mapping"
)
assert(
  configured.preview_keymaps.mappings.select_hint_mode == "o",
  "preview-local keymaps should include a hinted select mapping"
)
assert(
  configured.preview_keymaps.mappings.toggle_hint_mode == "c",
  "preview-local keymaps should include a hinted checkbox/radio toggle mapping"
)
assert(
  configured.preview_keymaps.mappings.jump_hint_mode == "gj",
  "preview-local keymaps should include a hinted cursor jump mapping"
)
assert(
  configured.preview_keymaps.mappings.submit_focused == "gs",
  "preview-local keymaps should include a focused form submit mapping"
)
local remapped = config.setup({
  session = {
    path = "/tmp/nvim-browser-session.json",
  },
  live_refresh = {
    enabled = false,
  },
  preview_keymaps = {
    mappings = {
      scroll_down = "<C-d>",
    },
  },
})
assert(remapped.live_refresh.enabled == false, "live refresh should allow disabling automatic capture")
assert(remapped.live_refresh.interval_ms == 1500, "live refresh partial config should retain the default interval")
assert(remapped.session.persist == true, "session partial config should retain persistence default")
assert(remapped.session.history_limit == 50, "session partial config should retain the default history limit")
assert(remapped.session.path == "/tmp/nvim-browser-session.json", "session persistence path should be configurable")
local negative_history_limit = config.setup({
  session = {
    history_limit = -1,
  },
})
assert(negative_history_limit.session.history_limit == 0, "session history limit should clamp negative values")
local calibration_config = config.setup({
  calibration = {
    persist = false,
    path = "/tmp/nvim-browser-calibration.json",
  },
})
assert(calibration_config.calibration.persist == false, "calibration persistence should allow disabling")
assert(calibration_config.calibration.path == "/tmp/nvim-browser-calibration.json", "calibration path should be configurable")
assert(remapped.viewport.cell_width_px == 10, "partial config should retain default viewport cell width")
assert(remapped.viewport.cell_height_px == 20, "partial config should retain default viewport cell height")
assert(remapped.preview_keymaps.mappings.scroll_down == "<C-d>", "preview-local keymaps should allow partial remaps")
assert(remapped.preview_keymaps.mappings.close == "q", "preview-local partial remaps should retain defaults")
assert(
  remapped.preview_keymaps.mappings.left_click == "<LeftMouse>",
  "preview-local partial remaps should retain mouse defaults"
)
assert(
  remapped.preview_keymaps.mappings.double_click == "<2-LeftMouse>",
  "preview-local partial remaps should retain double-click mouse defaults"
)
assert(
  remapped.preview_keymaps.mappings.type_hint_mode == "t",
  "preview-local partial remaps should retain hinted input mapping"
)
assert(
  remapped.preview_keymaps.mappings.hover_here == "gh",
  "preview-local partial remaps should retain cursor hover"
)
assert(
  remapped.preview_keymaps.mappings.follow_point_url_here == "gf",
  "preview-local partial remaps should retain cursor link follow"
)
assert(
  remapped.preview_keymaps.mappings.point_info_here == "gi",
  "preview-local partial remaps should retain cursor point inspection"
)
assert(
  remapped.preview_keymaps.mappings.type_here == "gI",
  "preview-local partial remaps should retain cursor text input"
)
assert(
  remapped.preview_keymaps.mappings.submit_here == "gS",
  "preview-local partial remaps should retain cursor text submit"
)
assert(
  remapped.preview_keymaps.mappings.yank_point_url_here == "gY",
  "preview-local partial remaps should retain cursor link URL yank"
)
assert(
  remapped.preview_keymaps.mappings.click_here == "gc",
  "preview-local partial remaps should retain cursor click"
)
assert(
  remapped.preview_keymaps.mappings.find_next == "n",
  "preview-local partial remaps should retain find-next"
)
assert(
  remapped.preview_keymaps.mappings.actions == "?",
  "preview-local partial remaps should retain actions picker"
)
assert(
  remapped.preview_keymaps.mappings.find_previous == "N",
  "preview-local partial remaps should retain find-previous"
)
assert(
  remapped.preview_keymaps.mappings.select_hint_mode == "o",
  "preview-local partial remaps should retain hinted select mapping"
)
assert(
  remapped.preview_keymaps.mappings.toggle_hint_mode == "c",
  "preview-local partial remaps should retain hinted checkbox/radio toggle mapping"
)
assert(
  remapped.preview_keymaps.mappings.stop == "<Esc>",
  "preview-local partial remaps should retain the stop mapping"
)
assert(
  remapped.preview_keymaps.mappings.input_text_mode == "i",
  "preview-local partial remaps should retain focused input mode"
)
assert(
  remapped.preview_keymaps.mappings.paste_register == "p",
  "preview-local partial remaps should retain register paste"
)
assert(
  remapped.preview_keymaps.mappings.yank_selection == "y",
  "preview-local partial remaps should retain browser selection yank"
)
assert(
  remapped.preview_keymaps.mappings.key_enter == "<CR>",
  "preview-local partial remaps should retain browser key mappings"
)
assert(
  remapped.preview_keymaps.mappings.page_down == "<PageDown>",
  "preview-local partial remaps should retain page scroll mappings"
)
assert(
  remapped.preview_keymaps.mappings.scroll_top == "gg",
  "preview-local partial remaps should retain browser-like scroll mappings"
)
assert(
  remapped.preview_keymaps.mappings.zoom_in == "+",
  "preview-local partial remaps should retain browser zoom mappings"
)

local resized_viewport = config.setup({
  viewport = {
    cell_width_px = 9,
  },
})
assert(resized_viewport.viewport.cell_width_px == 9, "viewport cell width should be configurable")
assert(resized_viewport.viewport.cell_height_px == 20, "partial viewport config should retain default cell height")
config.options = original_options
