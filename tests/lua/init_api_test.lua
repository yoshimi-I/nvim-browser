local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local browser = require("nvim-browser")
local keymaps = require("nvim-browser.keymaps")
local terminal = require("nvim-browser.terminal")

assert(type(browser.click_hint) == "function", "click_hint API should exist")
assert(type(browser.follow_hint) == "function", "follow_hint API should exist")
assert(type(browser.hint_mode) == "function", "hint_mode API should exist")
assert(type(browser.type_hint) == "function", "type_hint API should exist")
assert(type(browser.type_hint_mode) == "function", "type_hint_mode API should exist")
assert(type(browser.address) == "function", "address API should exist")
assert(type(browser.resolve_address_target) == "function", "address target resolver should exist")
assert(type(browser.find_text) == "function", "find_text API should exist")
assert(type(browser.last_find_found) == "function", "last_find_found API should exist")
assert(type(browser.doctor) == "function", "doctor API should exist")
assert(type(browser.page_metrics) == "function", "page_metrics API should exist")
assert(type(browser.reader) == "function", "reader API should exist")
assert(type(browser.reader_follow) == "function", "reader_follow API should exist")

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
local original_terminal_follow_hint = terminal.follow_hint
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

local followed_terminal_hint = nil
terminal.follow_hint = function(label)
  followed_terminal_hint = label
  return "followed"
end
assert(browser.follow_hint("a") == "followed", "follow_hint should delegate to terminal follow semantics")
assert(followed_terminal_hint == "a", "follow_hint should pass the hint label to terminal")

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

browser.hints = function()
  return { { id = 2, hint_label = "s" } }
end
typed_hint = nil
local prompts = {}
local responses = { "s", "hello world" }
terminal.type_hint = function(label, text, opts)
  typed_hint = {
    label = label,
    text = text,
    submit = opts ~= nil and opts.submit == true,
  }
  return true
end
assert(browser.type_hint_mode(function(prompt)
  table.insert(prompts, prompt)
  return table.remove(responses, 1)
end) == true, "type_hint_mode should type into the prompted hint")
assert(
  table.concat(prompts, "|") == "nvim-browser hint: |nvim-browser text: ",
  "type_hint_mode should prompt for hint then text"
)
assert(typed_hint.label == "s", "type_hint_mode should pass the prompted hint label")
assert(typed_hint.text == "hello world", "type_hint_mode should pass the prompted text")
assert(typed_hint.submit == false, "type_hint_mode should not submit by default")

responses = { "s", "search" }
assert(browser.type_hint_mode(function()
  return table.remove(responses, 1)
end, { submit = true }) == true, "type_hint_mode should support submit mode")
assert(typed_hint.submit == true, "submit mode should reach terminal.type_hint")

browser.hints = function()
  return {}
end
assert(browser.type_hint_mode(function()
  error("input should not be called without hints")
end) == false, "type_hint_mode should return false without active hints")

browser.hints = function()
  return { { id = 2, hint_label = "s" } }
end
assert(browser.type_hint_mode(function()
  return ""
end) == false, "type_hint_mode should cancel on empty hint label")

local empty_text_responses = { "s", "" }
assert(browser.type_hint_mode(function()
  return table.remove(empty_text_responses, 1)
end) == false, "type_hint_mode should cancel on empty text")

terminal.type_hint = function()
  return false
end
assert(browser.type_hint("s", "hello") == false, "type_hint should propagate terminal failure")

browser.click_hint = original_click_hint
browser.follow_hint = original_follow_hint
browser.input_text = original_input_text
browser.press_key = original_press_key
terminal.follow_hint = original_terminal_follow_hint
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

opened = nil
navigated = nil
assert(browser.address("example.org", { is_active = false }) == true, "address should accept direct string input")
assert(opened == "https://example.org", "direct address input should open normalized host input")
assert(navigated == nil, "direct inactive address input should not navigate")

opened = nil
navigated = nil
assert(browser.address("search terms", { is_active = true }) == true, "direct active address input should navigate")
assert(
  navigated == "https://www.google.com/search?q=search%20terms",
  "direct address input should use configured search URL"
)

local prompt_seen = nil
local default_seen = nil
browser.current_url = function()
  return "https://current.example/path"
end
assert(browser.address(function(prompt, default)
  prompt_seen = prompt
  default_seen = default
  return ""
end, { is_active = true }) == false, "empty prompted address should still be a no-op")
assert(prompt_seen == "nvim-browser address: ", "address prompt should keep the same label")
assert(default_seen == "https://current.example/path", "address prompt should default to the current URL")

browser.current_url = function()
  return nil
end
assert(browser.address(function(_, default)
  default_seen = default
  return ""
end, { is_active = true }) == false, "empty prompted address should be a no-op with last target default")
assert(default_seen == "https://www.google.com/search?q=search%20terms", "address prompt should fall back to last target")

local original_terminal_reader_follow = terminal.reader_follow
terminal.reader_follow = function()
  return "https://example.com/from-reader"
end
assert(browser.reader_follow() == true, "reader_follow should delegate to the terminal reader follow")
assert(browser.last_target() == "https://example.com/from-reader", "reader_follow should update the public last target")
terminal.reader_follow = function()
  return false
end
assert(browser.reader_follow() == false, "reader_follow should propagate terminal failure")
assert(
  browser.last_target() == "https://example.com/from-reader",
  "failed reader_follow should not replace the public last target"
)
terminal.reader_follow = original_terminal_reader_follow

browser.open = original_open
browser.navigate = original_navigate

local original_jobstart = vim.fn.jobstart
local original_jobstop = vim.fn.jobstop
local original_chansend = vim.fn.chansend
local original_nvim_chan_send = vim.api.nvim_chan_send
vim.fn.jobstart = function()
  return 2468
end
vim.fn.jobstop = function()
  return 1
end
vim.fn.chansend = function()
  return 1
end
vim.api.nvim_chan_send = function(channel, payload)
  if channel == vim.v.stderr then
    return 0
  end
  return original_nvim_chan_send(channel, payload)
end

browser.setup({
  graphics = "ansi",
  preview_keymaps = {
    enabled = true,
    scroll_pixels = 77,
  },
})
browser.open("https://example.com")
local preview_bufnr = terminal.state().bufnr
local preview_reload_mapping = vim.api.nvim_buf_call(preview_bufnr, function()
  return vim.fn.maparg("r", "n", false, true)
end)
assert(
  preview_reload_mapping.lhs == "r" and preview_reload_mapping.buffer == 1,
  "open should install preview-local browser controls on the preview buffer"
)
assert(keymaps._test.tracked_buffer_count() == 1, "open should track one preview-local mapping owner")
browser.close()
assert(keymaps._test.tracked_buffer_count() == 0, "close should clear preview-local mapping ownership")

browser.inspect("https://example.com")
local inspect_bufnr = terminal.state().bufnr
local inspect_close_mapping = vim.api.nvim_buf_call(inspect_bufnr, function()
  return vim.fn.maparg("q", "n", false, true)
end)
assert(
  inspect_close_mapping.lhs == "q" and inspect_close_mapping.buffer == 1,
  "inspect should install preview-local browser controls on the preview buffer"
)
browser.close()

vim.fn.jobstart = original_jobstart
vim.fn.jobstop = original_jobstop
vim.fn.chansend = original_chansend
vim.api.nvim_chan_send = original_nvim_chan_send
