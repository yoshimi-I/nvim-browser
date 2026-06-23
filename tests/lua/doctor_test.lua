local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local doctor = require("nvim-browser.doctor")

local original_zellij = vim.env.ZELLIJ
local original_term = vim.env.TERM

local function contains_line(report, pattern)
  for _, line in ipairs(report.lines) do
    if line:find(pattern, 1, true) then
      return true
    end
  end
  return false
end

vim.env.ZELLIJ = "1"
vim.env.TERM = "xterm-256color"
local zellij_auto = doctor.run({
  binary = "definitely-missing-nvbrowser",
  graphics = "auto",
  image_fit = "original",
}, {})
assert(contains_line(zellij_auto, "browser output: ansi"), "auto graphics under Zellij should choose ANSI browser output")
assert(contains_line(zellij_auto, "warning: ZELLIJ detected"), "auto graphics under Zellij should explain ANSI fallback")
assert(contains_line(zellij_auto, "warning: binary is not executable"), "missing binary should warn")

vim.env.ZELLIJ = nil
local outside_zellij = doctor.run({
  binary = "nvim",
  graphics = "auto",
  image_fit = "original",
}, {})
assert(contains_line(outside_zellij, "browser output: kitty-unicode"), "auto graphics outside Zellij should choose Kitty Unicode")

vim.env.ZELLIJ = "1"
local explicit_kitty = doctor.run({
  binary = "nvim",
  graphics = "kitty-unicode",
  image_fit = "original",
}, {})
assert(contains_line(explicit_kitty, "warning: ZELLIJ detected with explicit Kitty graphics"), "explicit Kitty under Zellij should warn")

vim.env.ZELLIJ = nil
local stale_session = doctor.run({
  binary = "nvim",
  graphics = "auto",
  image_fit = "original",
}, {
  mode = "serve",
  serve_output = "ansi",
  has_buffer = true,
  has_window = true,
  status = "ok",
  runtime_metadata = {
    protocol_version = 1,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "ansi",
    cells = { columns = 80, rows = 24 },
    viewport = { width = 800, height = 480, device_scale_factor = 1 },
  },
})
assert(contains_line(stale_session, "active session: serve output=ansi status=ok"), "active serve state should be reported")
assert(
  contains_line(stale_session, "runtime: protocol=1 transport=stdio-jsonl renderer=chromium-cdp output=ansi cells=80x24 viewport=800x480@1"),
  "runtime metadata should be reported"
)
assert(contains_line(stale_session, "warning: active session output differs"), "doctor should warn about stale active output")

vim.env.ZELLIJ = original_zellij
vim.env.TERM = original_term
