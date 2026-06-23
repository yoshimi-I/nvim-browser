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
  preview_keymaps = {
    mappings = {
      scroll_down = "<C-d>",
    },
  },
})
assert(remapped.preview_keymaps.mappings.scroll_down == "<C-d>", "preview-local keymaps should allow partial remaps")
assert(remapped.preview_keymaps.mappings.close == "q", "preview-local partial remaps should retain defaults")
assert(
  remapped.preview_keymaps.mappings.type_hint_mode == "t",
  "preview-local partial remaps should retain hinted input mapping"
)
config.options = original_options
