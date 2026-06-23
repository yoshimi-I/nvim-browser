local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local browser = require("nvim-browser")

assert(type(browser.click_hint) == "function", "click_hint API should exist")
assert(type(browser.follow_hint) == "function", "follow_hint API should exist")

