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

local ok, err = browser.calibrate("bad", 18)
assert(ok == false, "invalid calibration values should fail")
assert(err == "viewport cell pixels must be positive numbers", "invalid calibration should explain expected values")
assert(browser.config.viewport.cell_width_px == 9, "invalid calibration should not mutate existing cell width")
assert(browser.config.viewport.cell_height_px == 18, "invalid calibration should not mutate existing cell height")

ok, err = browser.calibrate(9.5, 18)
assert(ok == false, "fractional calibration values should fail")
assert(err == "viewport cell pixels must be positive integers", "fractional calibration should explain integer-only values")
assert(browser.config.viewport.cell_width_px == 9, "fractional calibration should not mutate existing cell width")
assert(browser.config.viewport.cell_height_px == 18, "fractional calibration should not mutate existing cell height")

browser.open = original_open
