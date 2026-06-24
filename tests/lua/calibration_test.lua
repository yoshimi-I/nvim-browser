local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local browser = require("nvim-browser")
local terminal = require("nvim-browser.terminal")

local function command_option(command, option)
  for index, value in ipairs(command) do
    if value == option then
      return command[index + 1]
    end
  end
  return nil
end

local opened_target = nil
local original_open = browser.open
browser.open = function(target)
  opened_target = target
  return true
end

local report = browser.calibrate(9, 18)

assert(type(report) == "table", "calibrate should return a report table")
assert(opened_target ~= nil and opened_target:match("data/html/calibrate%.html$"), "calibrate should open the bundled calibration fixture")
assert(
  vim.tbl_contains(report.lines, "calibration: pending runtime metadata; run :NBrowserDoctor after the calibration frame renders"),
  "calibrate should not report stale runtime alignment before the calibration frame renders"
)
assert(browser.config.viewport.cell_width_px == 9, "calibrate should update configured cell width")
assert(browser.config.viewport.cell_height_px == 18, "calibrate should update configured cell height")

terminal._test.set_test_window(vim.api.nvim_get_current_win())
terminal._test.set_mode("serve")
local command = terminal._test.command_for_window({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com" })
assert(command_option(command, "--width") ~= nil, "serve commands should include calibrated viewport width")
assert(command_option(command, "--height") ~= nil, "serve commands should include calibrated viewport height")
assert(tonumber(command_option(command, "--width")) % 9 == 0, "serve viewport width should use calibrated cell width")
assert(tonumber(command_option(command, "--height")) % 18 == 0, "serve viewport height should use calibrated cell height")

local calibration_dir = vim.fn.tempname()
vim.fn.mkdir(calibration_dir, "p")
local calibration_path = calibration_dir .. "/calibration.json"
browser.setup({
  session = { persist = false },
  calibration = { persist = true, path = calibration_path },
})
browser.calibrate(11, 22)
local saved_calibration = vim.fn.json_decode(table.concat(vim.fn.readfile(calibration_path), "\n"))
assert(saved_calibration.cell_width_px == 11, "calibrate should persist calibrated cell width")
assert(saved_calibration.cell_height_px == 22, "calibrate should persist calibrated cell height")

browser.setup({
  session = { persist = false },
  calibration = { persist = true, path = calibration_path },
})
assert(browser.config.viewport.cell_width_px == 11, "setup should load persisted calibration width when viewport is not explicit")
assert(browser.config.viewport.cell_height_px == 22, "setup should load persisted calibration height when viewport is not explicit")
assert(browser.config.viewport_source == "persisted", "setup should mark persisted viewport calibration source")

local malformed_path = calibration_dir .. "/malformed.json"
vim.fn.writefile({ vim.fn.json_encode({ cell_width_px = 0, cell_height_px = "bad" }) }, malformed_path)
local original_echo = vim.api.nvim_echo
local calibration_warnings = {}
vim.api.nvim_echo = function(chunks)
  if chunks[1][2] == "WarningMsg" then
    table.insert(calibration_warnings, chunks[1][1])
  end
end
browser.setup({
  session = { persist = false },
  calibration = { persist = true, path = malformed_path },
})
vim.api.nvim_echo = original_echo
assert(browser.config.viewport.cell_width_px == 10, "malformed persisted calibration should keep default width")
assert(browser.config.viewport.cell_height_px == 20, "malformed persisted calibration should keep default height")
assert(browser.config.viewport_source == "default", "malformed persisted calibration should keep default source")
assert(
  calibration_warnings[1] == "nvim-browser: ignored malformed calibration state",
  "malformed persisted calibration should warn once"
)

browser.setup({
  session = { persist = false },
  calibration = { persist = true, path = calibration_path },
  viewport = { cell_width_px = 13, cell_height_px = 26 },
})
assert(browser.config.viewport.cell_width_px == 13, "explicit viewport width should override persisted calibration")
assert(browser.config.viewport.cell_height_px == 26, "explicit viewport height should override persisted calibration")
assert(browser.config.viewport_source == "config", "explicit viewport settings should mark config calibration source")

browser.setup({
  session = { persist = false },
  calibration = { persist = true, path = calibration_path },
})
assert(browser.config.viewport.cell_width_px == 13, "later setup without viewport should preserve previously explicit width")
assert(browser.config.viewport.cell_height_px == 26, "later setup without viewport should preserve previously explicit height")
assert(browser.config.viewport_source == "config", "later setup without viewport should preserve config calibration source")

browser.setup({
  session = { persist = false },
  calibration = { persist = true, path = calibration_path },
  viewport = { cell_width_px = 14 },
})
assert(browser.config.viewport.cell_width_px == 14, "partial explicit viewport should apply configured width")
assert(browser.config.viewport.cell_height_px == 20, "partial explicit viewport should use default height rather than persisted height")
assert(browser.config.viewport_source == "config", "partial explicit viewport should mark config calibration source")

local unwritable_path = calibration_dir .. "/unwritable/calibration.json"
local write_warnings = {}
local original_writefile = vim.fn.writefile
vim.fn.writefile = function(lines, path, ...)
  if path == unwritable_path then
    error("permission denied")
  end
  return original_writefile(lines, path, ...)
end
vim.api.nvim_echo = function(chunks)
  if chunks[1][2] == "WarningMsg" then
    table.insert(write_warnings, chunks[1][1])
  end
end
browser.setup({
  session = { persist = false },
  calibration = { persist = true, path = unwritable_path },
  viewport = { cell_width_px = 10, cell_height_px = 20 },
})
assert(browser.calibrate(15, 30) ~= false, "calibration write failures should not block calibration")
vim.fn.writefile = original_writefile
vim.api.nvim_echo = original_echo
assert(write_warnings[1] == "nvim-browser: failed to write calibration state", "calibration write failures should warn")

local ok, err = browser.calibrate("bad", 18)
assert(ok == false, "invalid calibration values should fail")
assert(err == "viewport cell pixels must be positive numbers", "invalid calibration should explain expected values")
assert(browser.config.viewport.cell_width_px == 15, "invalid calibration should not mutate existing cell width")
assert(browser.config.viewport.cell_height_px == 30, "invalid calibration should not mutate existing cell height")

ok, err = browser.calibrate(9.5, 18)
assert(ok == false, "fractional calibration values should fail")
assert(err == "viewport cell pixels must be positive integers", "fractional calibration should explain integer-only values")
assert(browser.config.viewport.cell_width_px == 15, "fractional calibration should not mutate existing cell width")
assert(browser.config.viewport.cell_height_px == 30, "fractional calibration should not mutate existing cell height")

browser.open = original_open
