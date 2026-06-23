local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local commands = require("nvim-browser.commands")

local clicked = nil
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
}

local echoed = nil
local original_echo = vim.api.nvim_echo
vim.api.nvim_echo = function(chunks)
  echoed = chunks[1][1]
end

commands.register(browser)
vim.cmd("NBrowserHints")

assert(echoed:match("^a%s+1%s+link%s+Docs%s+@%s+10,20"), "NBrowserHints should show keyboard label before numeric id")
assert(echoed:match("\ns%s+2%s+input%s+Search%s+@%s+30,40"), "NBrowserHints should show all keyboard labels")

vim.cmd("NBrowserFollowHint a")
assert(clicked == "a", "NBrowserFollowHint should pass the label to click_hint")

vim.api.nvim_echo = original_echo

