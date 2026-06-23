local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local commands = require("nvim-browser.commands")

local clicked = nil
local followed = nil
local prompted = nil
local warnings = {}
local browser = {
  hints = function()
    return {
      { id = 1, hint_label = "a", kind = "link", label = "Docs", x = 10, y = 20 },
      { id = 2, hint_label = "s", kind = "input", label = "Search", x = 30, y = 40 },
    }
  end,
  click_hint = function(identifier)
    clicked = identifier
    return true
  end,
  follow_hint = function(identifier)
    followed = identifier
    return true
  end,
}

local echoed = nil
local original_echo = vim.api.nvim_echo
vim.api.nvim_echo = function(chunks)
  echoed = chunks[1][1]
  if chunks[1][2] == "WarningMsg" then
    table.insert(warnings, chunks[1][1])
  end
end

commands.register(browser, {
  input = function(prompt)
    prompted = prompt
    return "s"
  end,
})
vim.cmd("NBrowserHints")

assert(echoed:match("^a%s+1%s+link%s+Docs%s+@%s+10,20"), "NBrowserHints should show keyboard label before numeric id")
assert(echoed:match("\ns%s+2%s+input%s+Search%s+@%s+30,40"), "NBrowserHints should show all keyboard labels")

vim.cmd("NBrowserFollowHint a")
assert(followed == "a", "NBrowserFollowHint should pass the label to follow_hint")
assert(clicked == nil, "NBrowserFollowHint should not call click_hint when follow_hint exists")

followed = nil
vim.cmd("NBrowserHintMode")
assert(prompted == "nvim-browser hint: ", "NBrowserHintMode should prompt for a hint label")
assert(followed == "s", "NBrowserHintMode should follow the entered label")

followed = nil
commands.register(browser, {
  input = function()
    return ""
  end,
})
vim.cmd("NBrowserHintMode")
assert(followed == nil, "NBrowserHintMode should silently cancel on empty input")

local failed_browser = {
  hints = browser.hints,
  follow_hint = function()
    return false
  end,
}
commands.register(failed_browser, {
  input = function()
    return "missing"
  end,
})
vim.cmd("NBrowserHintMode")
assert(
  warnings[#warnings] == "nvim-browser: hint not found, stale, or browser session is inactive",
  "NBrowserHintMode should warn when following a label fails"
)

local empty_browser = {
  hints = function()
    return {}
  end,
  click_hint = function()
    error("click_hint should not be called without hints")
  end,
}
commands.register(empty_browser, {
  input = function()
    error("input should not be called without hints")
  end,
})
vim.cmd("NBrowserHintMode")
assert(warnings[#warnings] == "nvim-browser: no browser hints available", "NBrowserHintMode should warn when no hints exist")

vim.api.nvim_echo = original_echo
