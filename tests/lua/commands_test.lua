local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local commands = require("nvim-browser.commands")

local clicked = nil
local followed = nil
local prompted = nil
local warnings = {}
local addressed = nil
local found = nil
local typed_hint = nil
local submitted_hint = nil
local browser = {
  hints = function()
    return {
      { id = 1, hint_label = "a", kind = "link", label = "Docs", href = "https://example.com/docs", x = 10, y = 20 },
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
  address = function(input)
    addressed = input("nvim-browser address: ")
    return true
  end,
  find_text = function(query)
    found = query
    return true
  end,
  type_hint = function(label, text, opts)
    if opts ~= nil and opts.submit then
      submitted_hint = label .. ":" .. text
    else
      typed_hint = label .. ":" .. text
    end
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

assert(echoed:match("^a%s+1%s+link%s+Docs%s+%->%s+https://example%.com/docs%s+@%s+10,20"), "NBrowserHints should show keyboard label before numeric id and href")
assert(echoed:match("https://example%.com/docs"), "NBrowserHints should show structured link hrefs")
assert(echoed:match("\ns%s+2%s+input%s+Search%s+@%s+30,40"), "NBrowserHints should show all keyboard labels")

vim.cmd("NBrowserAddress")
assert(addressed == "s", "NBrowserAddress should pass the injected input function to browser.address")

vim.cmd("NBrowserFind needle")
assert(found == "needle", "NBrowserFind should pass an argument to browser.find_text")

found = nil
vim.cmd("NBrowserFind")
assert(prompted == "nvim-browser find: ", "NBrowserFind should prompt without an argument")
assert(found == "s", "NBrowserFind should find the entered text")

vim.cmd("NBrowserTypeHint s hello world")
assert(typed_hint == "s:hello world", "NBrowserTypeHint should pass the label and text to browser.type_hint")

vim.cmd("NBrowserSubmitHint s hello world")
assert(submitted_hint == "s:hello world", "NBrowserSubmitHint should request submit mode")

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
  address = function()
    return false
  end,
  find_text = function()
    return false
  end,
  type_hint = function()
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

vim.cmd("NBrowserAddress")
assert(warnings[#warnings] == "nvim-browser: address was empty or could not be opened", "NBrowserAddress should warn when address fails")

vim.cmd("NBrowserFind missing")
assert(warnings[#warnings] == "nvim-browser: text was not found or browser session is inactive", "NBrowserFind should warn when find fails")

vim.cmd("NBrowserTypeHint s missing")
assert(warnings[#warnings] == "nvim-browser: hint input failed, stale, or browser session is inactive", "NBrowserTypeHint should warn when type_hint fails")

local warning_count = #warnings
commands.register(failed_browser, {
  input = function()
    return ""
  end,
})
vim.cmd("NBrowserAddress")
assert(#warnings == warning_count, "NBrowserAddress should silently cancel on empty input")

vim.cmd("NBrowserFind")
assert(#warnings == warning_count, "NBrowserFind should silently cancel on empty input")

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
