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
assert(configured.preview_keymaps.enabled == true, "preview-local keymaps should be enabled by default")
assert(configured.preview_keymaps.mappings.close == "q", "preview-local keymaps should include a close mapping")
assert(
  configured.preview_keymaps.mappings.left_click == "<LeftMouse>",
  "preview-local keymaps should include a left-click mouse mapping"
)
assert(
  configured.preview_keymaps.mappings.wheel_down == "<ScrollWheelDown>",
  "preview-local keymaps should include a wheel-down mouse mapping"
)
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
assert(configured.preview_keymaps.mappings.key_enter == "<CR>", "preview-local keymaps should include Enter forwarding")
assert(configured.preview_keymaps.mappings.key_tab == "<Tab>", "preview-local keymaps should include Tab forwarding")
assert(configured.preview_keymaps.mappings.key_shift_tab == "<S-Tab>", "preview-local keymaps should include Shift-Tab forwarding")
assert(configured.preview_keymaps.mappings.key_backspace == "<BS>", "preview-local keymaps should include Backspace forwarding")
assert(configured.preview_keymaps.mappings.key_delete == "x", "preview-local keymaps should include Delete forwarding")
assert(configured.preview_keymaps.mappings.key_escape == "ge", "preview-local keymaps should include browser Escape forwarding")
assert(configured.preview_keymaps.mappings.key_select_all == "A", "preview-local keymaps should include select-all forwarding")
assert(configured.preview_keymaps.mappings.key_focus_location == "gl", "preview-local keymaps should include location focus forwarding")
assert(configured.preview_keymaps.mappings.key_up == "<Up>", "preview-local keymaps should include ArrowUp forwarding")
assert(configured.preview_keymaps.mappings.key_down == "<Down>", "preview-local keymaps should include ArrowDown forwarding")
assert(configured.preview_keymaps.mappings.key_left == "<Left>", "preview-local keymaps should include ArrowLeft forwarding")
assert(configured.preview_keymaps.mappings.key_right == "<Right>", "preview-local keymaps should include ArrowRight forwarding")
assert(configured.preview_keymaps.mappings.hover_here == "gh", "preview-local keymaps should include cursor hover")
assert(
  configured.keymaps.mappings.type_hint_mode == "t",
  "global keymaps should include a hinted input mapping"
)
assert(
  configured.keymaps.mappings.submit_hint_mode == "s",
  "global keymaps should include a hinted submit mapping"
)
assert(
  configured.preview_keymaps.mappings.type_hint_mode == "t",
  "preview-local keymaps should include a hinted input mapping"
)
assert(
  configured.preview_keymaps.mappings.submit_hint_mode == "s",
  "preview-local keymaps should include a hinted submit mapping"
)
local remapped = config.setup({
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
assert(remapped.viewport.cell_width_px == 10, "partial config should retain default viewport cell width")
assert(remapped.viewport.cell_height_px == 20, "partial config should retain default viewport cell height")
assert(remapped.preview_keymaps.mappings.scroll_down == "<C-d>", "preview-local keymaps should allow partial remaps")
assert(remapped.preview_keymaps.mappings.close == "q", "preview-local partial remaps should retain defaults")
assert(
  remapped.preview_keymaps.mappings.left_click == "<LeftMouse>",
  "preview-local partial remaps should retain mouse defaults"
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
  remapped.preview_keymaps.mappings.stop == "<Esc>",
  "preview-local partial remaps should retain the stop mapping"
)
assert(
  remapped.preview_keymaps.mappings.input_text_mode == "i",
  "preview-local partial remaps should retain focused input mode"
)
assert(
  remapped.preview_keymaps.mappings.key_enter == "<CR>",
  "preview-local partial remaps should retain browser key mappings"
)

local resized_viewport = config.setup({
  viewport = {
    cell_width_px = 9,
  },
})
assert(resized_viewport.viewport.cell_width_px == 9, "viewport cell width should be configurable")
assert(resized_viewport.viewport.cell_height_px == 20, "partial viewport config should retain default cell height")
config.options = original_options
