local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local browser = require("nvim-browser")
local keymaps = require("nvim-browser.keymaps")
local terminal = require("nvim-browser.terminal")

assert(type(browser.click_hint) == "function", "click_hint API should exist")
assert(type(browser.follow_hint) == "function", "follow_hint API should exist")
assert(type(browser.hint_mode) == "function", "hint_mode API should exist")
assert(type(browser.transient_hint_mode) == "function", "transient_hint_mode API should exist")
assert(type(browser.hover_point) == "function", "hover_point API should exist")
assert(type(browser.hover_here) == "function", "hover_here API should exist")
assert(type(browser.hover_hint) == "function", "hover_hint API should exist")
assert(type(browser.type_hint) == "function", "type_hint API should exist")
assert(type(browser.type_hint_mode) == "function", "type_hint_mode API should exist")
assert(type(browser.input_text_mode) == "function", "focused input text mode API should exist")
assert(type(browser.start_text_mode) == "function", "interactive browser text mode API should exist")
assert(type(browser.address) == "function", "address API should exist")
assert(type(browser.resolve_address_target) == "function", "address target resolver should exist")
assert(type(browser.find_text) == "function", "find_text API should exist")
assert(type(browser.last_find_found) == "function", "last_find_found API should exist")
assert(type(browser.doctor) == "function", "doctor API should exist")
assert(type(browser.page_metrics) == "function", "page_metrics API should exist")
assert(type(browser.page_scroll) == "function", "page_scroll API should exist")
assert(type(browser.page_down) == "function", "page_down API should exist")
assert(type(browser.page_up) == "function", "page_up API should exist")
assert(type(browser.hint_error) == "function", "hint_error API should exist")
assert(type(browser.reader) == "function", "reader API should exist")
assert(type(browser.reader_follow) == "function", "reader_follow API should exist")
assert(type(browser.click_mouse) == "function", "click_mouse API should exist")
assert(type(browser.stop) == "function", "stop API should exist")

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
local original_terminal_click_mouse = terminal.click_mouse
local original_terminal_type_hint = terminal.type_hint
local original_terminal_hover_point = terminal.hover_point
local original_terminal_hover_here = terminal.hover_here
local original_terminal_hover_hint = terminal.hover_hint
local original_terminal_stop = terminal.stop
local original_terminal_input_text = terminal.input_text
local original_terminal_press_key = terminal.press_key
local original_terminal_start_text_mode = terminal.start_text_mode
local original_terminal_page_scroll = terminal.page_scroll

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

local transient_followed = {}
browser.follow_hint = function(label)
  table.insert(transient_followed, label)
  return true
end
browser.hints = function()
  return {}
end
assert(
  browser.transient_hint_mode({
    getcharstr = function()
      error("transient hint mode should not read input without hints")
    end,
  }) == false,
  "transient_hint_mode should refuse to start without active hints"
)

browser.hints = function()
  return {
    { id = 1, hint_label = "a" },
    { id = 2, hint_label = "s" },
  }
end
local unique_keys = { "s" }
assert(
  browser.transient_hint_mode({
    getcharstr = function()
      return table.remove(unique_keys, 1)
    end,
  }) == true,
  "transient_hint_mode should follow a unique one-key hint"
)
assert(transient_followed[#transient_followed] == "s", "transient_hint_mode should pass the matched label to follow_hint")

browser.hints = function()
  return {
    { id = 1, hint_label = "a" },
    { id = 2, hint_label = "aa" },
  }
end
local multi_keys = { "a", "a" }
assert(
  browser.transient_hint_mode({
    getcharstr = function()
      return table.remove(multi_keys, 1)
    end,
  }) == true,
  "transient_hint_mode should wait while a label prefix is ambiguous"
)
assert(transient_followed[#transient_followed] == "aa", "transient_hint_mode should support multi-key hint labels")

browser.hints = function()
  return { { id = 1, hint_label = "a" } }
end
local escaped_keys = { vim.keycode("<Esc>") }
assert(
  browser.transient_hint_mode({
    getcharstr = function()
      return table.remove(escaped_keys, 1)
    end,
  }) == false,
  "transient_hint_mode should cancel on Escape"
)
assert(transient_followed[#transient_followed] == "aa", "Escape should not follow a hint")

local invalid_keys = { "z" }
assert(
  browser.transient_hint_mode({
    getcharstr = function()
      return table.remove(invalid_keys, 1)
    end,
  }) == false,
  "transient_hint_mode should exit on an invalid label prefix"
)
assert(transient_followed[#transient_followed] == "aa", "invalid hint input should not follow a hint")

browser.hints = original_hints
browser.follow_hint = original_follow_hint

local followed_terminal_hint = nil
terminal.follow_hint = function(label)
  followed_terminal_hint = label
  return "followed"
end
assert(browser.follow_hint("a") == "followed", "follow_hint should delegate to terminal follow semantics")
assert(followed_terminal_hint == "a", "follow_hint should pass the hint label to terminal")

local clicked_mouse = nil
terminal.click_mouse = function(mousepos)
  clicked_mouse = mousepos
  return "clicked"
end
local mousepos = { winid = 10, line = 3, column = 8 }
assert(browser.click_mouse(mousepos) == "clicked", "click_mouse should delegate to terminal mouse click semantics")
assert(clicked_mouse == mousepos, "click_mouse should pass explicit mouse position to terminal")

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

local hovered_point = nil
terminal.hover_point = function(x, y)
  hovered_point = { x = x, y = y }
  return true
end
assert(browser.hover_point(12.5, 24.25) == true, "hover_point should delegate to terminal point hover")
assert(hovered_point.x == 12.5, "hover_point should pass x coordinate to terminal")
assert(hovered_point.y == 24.25, "hover_point should pass y coordinate to terminal")

local hovered_here = false
terminal.hover_here = function()
  hovered_here = true
  return "hovered"
end
assert(browser.hover_here() == "hovered", "hover_here should delegate to terminal cursor hover")
assert(hovered_here == true, "hover_here should call terminal.hover_here")

local hovered_hint = nil
terminal.hover_hint = function(label)
  hovered_hint = label
  return true
end
assert(browser.hover_hint("m") == true, "hover_hint should delegate to terminal hint hover")
assert(hovered_hint == "m", "hover_hint should pass hint label to terminal")

local focused_input = nil
terminal.input_text = function(text)
  focused_input = text
  return true
end
assert(browser.input_text_mode(function(prompt)
  assert(prompt == "nvim-browser text: ", "input_text_mode should use the expected prompt")
  return "focused text"
end) == true, "input_text_mode should type prompted text into the focused element")
assert(focused_input == "focused text", "input_text_mode should pass prompted text to terminal")
assert(browser.input_text_mode(function()
  return ""
end) == false, "input_text_mode should cancel on empty text")

local text_mode_opts = nil
terminal.start_text_mode = function(opts)
  text_mode_opts = opts
  return true
end
assert(browser.start_text_mode({ source = "test" }) == true, "start_text_mode should delegate to terminal")
assert(text_mode_opts.source == "test", "start_text_mode should pass options to terminal")

local pressed_key = nil
terminal.press_key = function(key, opts)
  pressed_key = { key = key, modifiers = opts and opts.modifiers or {} }
  return true
end
assert(browser.press_key("Tab", { modifiers = { "shift" } }) == true, "press_key should pass modifier options")
assert(pressed_key.key == "Tab", "press_key should pass the key to terminal")
assert(pressed_key.modifiers[1] == "shift", "press_key should pass modifiers to terminal")

local page_scroll_direction = nil
terminal.page_scroll = function(direction)
  page_scroll_direction = direction
  return true
end
assert(browser.page_scroll(1) == true, "page_scroll should delegate to terminal")
assert(page_scroll_direction == 1, "page_scroll should pass an explicit direction")
assert(browser.page_down() == true, "page_down should delegate to terminal page scroll")
assert(page_scroll_direction == 1, "page_down should request forward page scroll")
assert(browser.page_up() == true, "page_up should delegate to terminal page scroll")
assert(page_scroll_direction == -1, "page_up should request backward page scroll")

local stop_called = false
terminal.stop = function()
  stop_called = true
  return "stopped"
end
assert(browser.stop() == "stopped", "stop should delegate to terminal")
assert(stop_called == true, "stop should call terminal.stop")

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
terminal.click_mouse = original_terminal_click_mouse
terminal.type_hint = original_terminal_type_hint
terminal.hover_point = original_terminal_hover_point
terminal.hover_here = original_terminal_hover_here
terminal.hover_hint = original_terminal_hover_hint
terminal.stop = original_terminal_stop
terminal.input_text = original_terminal_input_text
terminal.press_key = original_terminal_press_key
terminal.start_text_mode = original_terminal_start_text_mode
terminal.page_scroll = original_terminal_page_scroll

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
local original_terminal_configure = terminal.configure
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

local configured_terminal_opts = nil
terminal.configure = function(opts)
  configured_terminal_opts = opts
end
browser.setup({
  live_refresh = {
    enabled = false,
    interval_ms = 2500,
  },
})
assert(configured_terminal_opts.live_refresh.enabled == false, "setup should pass live refresh config to terminal")
assert(configured_terminal_opts.live_refresh.interval_ms == 2500, "setup should pass live refresh interval to terminal")
terminal.configure = original_terminal_configure

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
