local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local browser = require("nvim-browser")
local terminal = require("nvim-browser.terminal")

assert(type(browser.click_hint) == "function", "click_hint API should exist")
assert(type(browser.follow_hint) == "function", "follow_hint API should exist")
assert(type(browser.hint_mode) == "function", "hint_mode API should exist")
assert(type(browser.type_hint) == "function", "type_hint API should exist")
assert(type(browser.address) == "function", "address API should exist")
assert(type(browser.resolve_address_target) == "function", "address target resolver should exist")
assert(type(browser.find_text) == "function", "find_text API should exist")
assert(type(browser.last_find_found) == "function", "last_find_found API should exist")

assert(browser.resolve_address_target("https://example.com") == "https://example.com", "address resolver should preserve explicit URLs")
assert(browser.resolve_address_target("example.com") == "https://example.com", "address resolver should add https to host-like inputs")
assert(browser.resolve_address_target("localhost:3000") == "http://localhost:3000", "address resolver should add http to localhost")
assert(browser.resolve_address_target("localhosting") == "https://www.google.com/search?q=localhosting", "address resolver should not treat localhost prefixes as localhost")
assert(browser.resolve_address_target("127.0.0.1abc") == "https://www.google.com/search?q=127.0.0.1abc", "address resolver should not treat partial IP prefixes as URLs")
assert(browser.resolve_address_target("hello world") == "https://www.google.com/search?q=hello%20world", "address resolver should search plain words")
assert(browser.resolve_address_target("  docs  ") == "https://www.google.com/search?q=docs", "address resolver should trim input")
assert(browser.resolve_address_target("") == nil, "address resolver should reject empty input")

local original_hints = browser.hints
local original_click_hint = browser.click_hint
local original_follow_hint = browser.follow_hint
local original_input_text = browser.input_text
local original_press_key = browser.press_key
local original_terminal_type_hint = terminal.type_hint

browser.hints = function()
  return {}
end
assert(browser.hint_mode(function()
  error("input should not be called without hints")
end) == false, "hint_mode should return false without active hints")

browser.hints = function()
  return { { id = 1, hint_label = "a" } }
end
assert(browser.hint_mode(function()
  return ""
end) == false, "hint_mode should return false on empty input")

local followed = nil
browser.follow_hint = function(label)
  followed = label
  return true
end
assert(browser.hint_mode(function(prompt)
  assert(prompt == "nvim-browser hint: ", "hint_mode should use the expected prompt")
  return "a"
end) == true, "hint_mode should return follow_hint result")
assert(followed == "a", "hint_mode should follow the entered label")

browser.follow_hint = function()
  return false
end
assert(browser.hint_mode(function()
  return "missing"
end) == false, "hint_mode should propagate failed follow_hint")

browser.hints = original_hints
browser.follow_hint = original_follow_hint

local typed_hint = nil
terminal.type_hint = function(label, text, opts)
  typed_hint = {
    label = label,
    text = text,
    submit = opts ~= nil and opts.submit == true,
  }
  return true
end
assert(browser.type_hint("s", "hello world", { submit = true }) == true, "type_hint should delegate to terminal")
assert(typed_hint.label == "s", "type_hint should pass hint label to terminal")
assert(typed_hint.text == "hello world", "type_hint should pass text to terminal")
assert(typed_hint.submit == true, "type_hint should pass submit option to terminal")

terminal.type_hint = function()
  return false
end
assert(browser.type_hint("s", "hello") == false, "type_hint should propagate terminal failure")

browser.click_hint = original_click_hint
browser.follow_hint = original_follow_hint
browser.input_text = original_input_text
browser.press_key = original_press_key
terminal.type_hint = original_terminal_type_hint

local original_open = browser.open
local original_navigate = browser.navigate
local opened = nil
local navigated = nil

browser.open = function(target)
  opened = target
  return true
end
browser.navigate = function(target)
  navigated = target
  return true
end
assert(browser.address(function()
  return "example.com"
end, { is_active = false }) == true, "address should open a target when no browser session is active")
assert(opened == "https://example.com", "address should open normalized host input")
assert(navigated == nil, "address should not navigate without an active session")

opened = nil
navigated = nil
assert(browser.address(function()
  return "hello world"
end, { is_active = true }) == true, "address should navigate when a browser session is active")
assert(navigated == "https://www.google.com/search?q=hello%20world", "address should navigate to normalized search URL")
assert(opened == nil, "address should not open a new preview when a session is active")

assert(browser.address(function()
  return ""
end, { is_active = true }) == false, "address should return false for empty input")

browser.open = original_open
browser.navigate = original_navigate
