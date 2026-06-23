local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local doctor = require("nvim-browser.doctor")

local original_zellij = vim.env.ZELLIJ
local original_term = vim.env.TERM
local original_tmux = vim.env.TMUX
local original_term_program = vim.env.TERM_PROGRAM
local original_ghostty = vim.env.GHOSTTY_RESOURCES_DIR

local function contains_line(report, pattern)
  for _, line in ipairs(report.lines) do
    if line:find(pattern, 1, true) then
      return true
    end
  end
  return false
end

local function count_lines(report, pattern)
  local count = 0
  for _, line in ipairs(report.lines) do
    if line:find(pattern, 1, true) then
      count = count + 1
    end
  end
  return count
end

vim.env.ZELLIJ = "1"
vim.env.TMUX = nil
vim.env.TERM = "xterm-256color"
vim.env.TERM_PROGRAM = nil
vim.env.GHOSTTY_RESOURCES_DIR = nil
local zellij_auto = doctor.run({
  binary = "definitely-missing-nvbrowser",
  graphics = "auto",
  image_fit = "original",
}, {})
assert(contains_line(zellij_auto, "browser output: ansi"), "auto graphics under Zellij should choose ANSI browser output")
assert(contains_line(zellij_auto, "image output: ansi"), "auto graphics under Zellij should choose ANSI image output")
assert(contains_line(zellij_auto, "terminal: unknown"), "doctor should report detected terminal")
assert(contains_line(zellij_auto, "multiplexer: zellij"), "doctor should report detected multiplexer")
assert(contains_line(zellij_auto, "graphics reason: Zellij"), "doctor should explain auto graphics selection")
assert(contains_line(zellij_auto, "warning: ZELLIJ detected"), "auto graphics under Zellij should explain ANSI fallback")
assert(contains_line(zellij_auto, "warning: binary is not executable"), "missing binary should warn")

vim.env.ZELLIJ = nil
vim.env.TMUX = nil
vim.env.TERM_PROGRAM = "ghostty"
vim.env.TERM = "xterm-ghostty"
local outside_zellij = doctor.run({
  binary = "nvim",
  graphics = "auto",
  image_fit = "original",
  viewport = {
    cell_width_px = 9,
    cell_height_px = 15,
  },
}, {})
assert(contains_line(outside_zellij, "browser output: kitty-unicode"), "auto graphics outside Zellij should choose Kitty Unicode")
assert(contains_line(outside_zellij, "image output: kitty"), "auto graphics in Ghostty should choose Kitty image output")
assert(contains_line(outside_zellij, "terminal: ghostty"), "doctor should report Ghostty detection")
assert(contains_line(outside_zellij, "graphics reason: Ghostty"), "doctor should explain Ghostty graphics support")
assert(contains_line(outside_zellij, "viewport cell px: 9x15"), "doctor should report configured viewport cell pixel size")

vim.env.TERM_PROGRAM = nil
vim.env.TERM = "xterm-256color"
local normalized_viewport = doctor.run({
  binary = "nvim",
  graphics = "auto",
  image_fit = "original",
  viewport = {
    cell_width_px = 0,
    cell_height_px = "bad",
  },
}, {})
assert(contains_line(normalized_viewport, "viewport cell px: 1x20"), "doctor should report effective normalized viewport cell pixel size")
assert(contains_line(normalized_viewport, "browser output: ansi"), "unknown terminals should use ANSI fallback")

vim.env.ZELLIJ = "1"
local explicit_kitty = doctor.run({
  binary = "nvim",
  graphics = "kitty-unicode",
  image_fit = "original",
}, {})
assert(contains_line(explicit_kitty, "warning: ZELLIJ detected with explicit Kitty graphics"), "explicit Kitty under Zellij should warn")
assert(count_lines(explicit_kitty, "warning: ZELLIJ detected with explicit Kitty graphics") == 1, "explicit Kitty under Zellij should warn only once")

vim.env.ZELLIJ = nil
vim.env.TMUX = "/tmp/tmux-501/default,123,0"
vim.env.TERM_PROGRAM = "ghostty"
vim.env.TERM = "tmux-256color"
local tmux_auto = doctor.run({
  binary = "nvim",
  graphics = "auto",
  image_fit = "original",
}, {})
assert(contains_line(tmux_auto, "multiplexer: tmux"), "doctor should report tmux detection")
assert(contains_line(tmux_auto, "browser output: kitty-unicode"), "tmux auto should preserve Kitty Unicode output")
assert(contains_line(tmux_auto, "graphics reason: tmux"), "doctor should explain tmux passthrough selection")
assert(contains_line(tmux_auto, "warning: tmux detected"), "doctor should warn that tmux passthrough must be enabled")

vim.env.TMUX = nil
vim.env.TERM_PROGRAM = "ghostty"
vim.env.TERM = "xterm-ghostty"
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
vim.env.TMUX = original_tmux
vim.env.TERM_PROGRAM = original_term_program
vim.env.GHOSTTY_RESOURCES_DIR = original_ghostty
