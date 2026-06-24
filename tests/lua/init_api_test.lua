local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local browser = require("nvim-browser")
local keymaps = require("nvim-browser.keymaps")
local terminal = require("nvim-browser.terminal")

browser.setup({ session = { persist = false } })

assert(type(browser.click_hint) == "function", "click_hint API should exist")
assert(type(browser.right_click_point) == "function", "right_click_point API should exist")
assert(type(browser.right_click_here) == "function", "right_click_here API should exist")
assert(type(browser.right_click_mouse) == "function", "right_click_mouse API should exist")
assert(type(browser.right_click_hint) == "function", "right_click_hint API should exist")
assert(type(browser.follow_hint) == "function", "follow_hint API should exist")
assert(type(browser.pick_hint) == "function", "pick_hint API should exist")
assert(type(browser.hint_mode) == "function", "hint_mode API should exist")
assert(type(browser.transient_hint_mode) == "function", "transient_hint_mode API should exist")
assert(type(browser.hover_point) == "function", "hover_point API should exist")
assert(type(browser.hover_here) == "function", "hover_here API should exist")
assert(type(browser.hover_hint) == "function", "hover_hint API should exist")
assert(type(browser.focus_hint) == "function", "focus_hint API should exist")
assert(type(browser.focus_hint_mode) == "function", "focus_hint_mode API should exist")
assert(type(browser.wheel_point) == "function", "wheel_point API should exist")
assert(type(browser.wheel_mouse) == "function", "wheel_mouse API should exist")
assert(type(browser.type_point) == "function", "type_point API should exist")
assert(type(browser.type_here) == "function", "type_here API should exist")
assert(type(browser.type_hint) == "function", "type_hint API should exist")
assert(type(browser.type_hint_mode) == "function", "type_hint_mode API should exist")
assert(type(browser.select_hint) == "function", "select_hint API should exist")
assert(type(browser.select_hint_mode) == "function", "select_hint_mode API should exist")
assert(type(browser.upload_hint) == "function", "upload_hint API should exist")
assert(type(browser.upload_hint_mode) == "function", "upload_hint_mode API should exist")
assert(type(browser.toggle_hint) == "function", "toggle_hint API should exist")
assert(type(browser.toggle_hint_mode) == "function", "toggle_hint_mode API should exist")
assert(type(browser.input_text_mode) == "function", "focused input text mode API should exist")
assert(type(browser.paste_register) == "function", "register paste API should exist")
assert(type(browser.select_region) == "function", "browser region selection API should exist")
assert(type(browser.yank_selection) == "function", "browser selection yank API should exist")
assert(type(browser.yank_region) == "function", "browser region yank API should exist")
assert(type(browser.yank_current_url) == "function", "current URL yank API should exist")
assert(type(browser.yank_hint_url) == "function", "hint URL yank API should exist")
assert(type(browser.screenshot) == "function", "active browser screenshot API should exist")
assert(type(browser.start_text_mode) == "function", "interactive browser text mode API should exist")
assert(type(browser.address) == "function", "address API should exist")
assert(type(browser.resolve_address_target) == "function", "address target resolver should exist")
assert(type(browser.find_text) == "function", "find_text API should exist")
assert(type(browser.find_next) == "function", "find_next API should exist")
assert(type(browser.find_previous) == "function", "find_previous API should exist")
assert(type(browser.last_find_found) == "function", "last_find_found API should exist")
assert(type(browser.last_find_match_count) == "function", "last_find_match_count API should exist")
terminal._test.handle_find_text_response({ status = "ok", found = true, match_count = 4 })
assert(browser.last_find_found() == true, "last_find_found should expose terminal find state")
assert(browser.last_find_match_count() == 4, "last_find_match_count should expose terminal find match count")
assert(type(browser.doctor) == "function", "doctor API should exist")
assert(type(browser.calibrate) == "function", "calibrate API should exist")
assert(type(browser.page_metrics) == "function", "page_metrics API should exist")
assert(type(browser.page_scroll) == "function", "page_scroll API should exist")
assert(type(browser.page_down) == "function", "page_down API should exist")
assert(type(browser.page_up) == "function", "page_up API should exist")
assert(type(browser.scroll_top) == "function", "scroll_top API should exist")
assert(type(browser.scroll_bottom) == "function", "scroll_bottom API should exist")
assert(type(browser.half_page_down) == "function", "half_page_down API should exist")
assert(type(browser.half_page_up) == "function", "half_page_up API should exist")
assert(type(browser.zoom_in) == "function", "zoom_in API should exist")
assert(type(browser.zoom_out) == "function", "zoom_out API should exist")
assert(type(browser.zoom_reset) == "function", "zoom_reset API should exist")
assert(type(browser.hint_error) == "function", "hint_error API should exist")
assert(type(browser.reader) == "function", "reader API should exist")
assert(type(browser.reader_follow) == "function", "reader_follow API should exist")
assert(type(browser.click_mouse) == "function", "click_mouse API should exist")
assert(type(browser.stop) == "function", "stop API should exist")
assert(type(browser.actions) == "function", "actions picker API should exist")
assert(type(browser.open_under_cursor) == "function", "open-under-cursor API should exist")
assert(type(browser.resolve_cursor_target) == "function", "cursor target resolver API should exist")

assert(browser.resolve_address_target("https://example.com") == "https://example.com", "address resolver should preserve explicit URLs")
assert(browser.resolve_address_target("example.com") == "https://example.com", "address resolver should add https to host-like inputs")
assert(browser.resolve_address_target("localhost:3000") == "http://localhost:3000", "address resolver should add http to localhost")
assert(browser.resolve_address_target("localhosting") == "https://www.google.com/search?q=localhosting", "address resolver should not treat localhost prefixes as localhost")
assert(browser.resolve_address_target("127.0.0.1abc") == "https://www.google.com/search?q=127.0.0.1abc", "address resolver should not treat partial IP prefixes as URLs")
assert(browser.resolve_address_target("hello world") == "https://www.google.com/search?q=hello%20world", "address resolver should search plain words")
assert(browser.resolve_address_target("  docs  ") == "https://www.google.com/search?q=docs", "address resolver should trim input")
assert(browser.resolve_address_target("") == nil, "address resolver should reject empty input")

_G.nvim_browser_cursor_target_dir = vim.fn.tempname()
vim.fn.mkdir(_G.nvim_browser_cursor_target_dir, "p")
_G.nvim_browser_cursor_target_file = _G.nvim_browser_cursor_target_dir .. "/guide.md"
vim.fn.writefile({ "# Guide" }, _G.nvim_browser_cursor_target_file)
_G.nvim_browser_cursor_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(_G.nvim_browser_cursor_buf)
vim.api.nvim_buf_set_lines(_G.nvim_browser_cursor_buf, 0, -1, false, {
  "Open [docs](https://example.com/docs) from markdown",
  "Raw URL https://example.com/raw?x=1.",
  "File " .. _G.nvim_browser_cursor_target_file,
  "Host example.org/path",
  "Search words with spaces",
  "Parens [wiki](https://en.wikipedia.org/wiki/Foo_(bar))",
  "File URL file:///tmp/example.html",
  "Escaped [docs\\]](https://example.com/a\\)b)",
  "   ",
})
vim.api.nvim_win_set_cursor(0, { 1, 9 })
assert(browser.resolve_cursor_target() == "https://example.com/docs", "cursor resolver should prefer markdown link targets")
vim.api.nvim_win_set_cursor(0, { 2, 18 })
assert(browser.resolve_cursor_target() == "https://example.com/raw?x=1", "cursor resolver should trim URL punctuation")
vim.api.nvim_win_set_cursor(0, { 3, 8 })
assert(browser.resolve_cursor_target() == _G.nvim_browser_cursor_target_file, "cursor resolver should open readable local files from cfile")
vim.api.nvim_win_set_cursor(0, { 4, 8 })
assert(browser.resolve_cursor_target() == "example.org/path", "cursor resolver should return host-like cfile text")
vim.api.nvim_win_set_cursor(0, { 5, 4 })
assert(browser.resolve_cursor_target() == "Search words with spaces", "cursor resolver should fall back to trimmed line text for search")
vim.api.nvim_win_set_cursor(0, { 6, 12 })
assert(browser.resolve_cursor_target() == "https://en.wikipedia.org/wiki/Foo_(bar)", "cursor resolver should keep balanced parentheses in markdown link targets")
vim.api.nvim_win_set_cursor(0, { 7, 12 })
assert(browser.resolve_cursor_target() == "file:///tmp/example.html", "cursor resolver should preserve raw file URLs")
vim.api.nvim_win_set_cursor(0, { 8, 12 })
assert(browser.resolve_cursor_target() == "https://example.com/a)b", "cursor resolver should unescape escaped markdown link targets")
vim.api.nvim_win_set_cursor(0, { 9, 1 })
assert(browser.resolve_cursor_target() == nil, "cursor resolver should reject empty cursor context")

_G.nvim_browser_opened_under_cursor = nil
_G.nvim_browser_navigated_under_cursor = nil
_G.nvim_browser_original_open_under_cursor_open = browser.open
_G.nvim_browser_original_open_under_cursor_navigate = browser.navigate
_G.nvim_browser_original_terminal_state_for_cursor = terminal.state
browser.open = function(target)
  _G.nvim_browser_opened_under_cursor = target
  return true
end
browser.navigate = function(target)
  _G.nvim_browser_navigated_under_cursor = target
  return true
end
terminal.state = function()
  return { mode = nil, job_id = nil, has_buffer = false }
end
vim.api.nvim_win_set_cursor(0, { 4, 8 })
assert(browser.open_under_cursor() == true, "open_under_cursor should open a new preview without an active session")
assert(_G.nvim_browser_opened_under_cursor == "https://example.org/path", "open_under_cursor should normalize host-like targets through address resolver")
assert(_G.nvim_browser_navigated_under_cursor == nil, "open_under_cursor should not navigate without an active session")
_G.nvim_browser_opened_under_cursor = nil
terminal.state = function()
  return { mode = "serve", job_id = 11, has_buffer = true }
end
vim.api.nvim_win_set_cursor(0, { 1, 9 })
assert(browser.open_under_cursor() == true, "open_under_cursor should navigate when a browser session is active")
assert(_G.nvim_browser_navigated_under_cursor == "https://example.com/docs", "open_under_cursor should navigate the active session to resolved targets")
assert(_G.nvim_browser_opened_under_cursor == nil, "open_under_cursor should not open a replacement preview for active sessions")
_G.nvim_browser_navigated_under_cursor = nil
vim.api.nvim_win_set_cursor(0, { 3, 8 })
assert(browser.open_under_cursor() == true, "open_under_cursor should navigate active sessions to readable local files")
assert(
  _G.nvim_browser_navigated_under_cursor == vim.uri_from_fname(_G.nvim_browser_cursor_target_file),
  "open_under_cursor should convert readable local files to file URLs before active-session navigation"
)
browser.open = _G.nvim_browser_original_open_under_cursor_open
browser.navigate = _G.nvim_browser_original_open_under_cursor_navigate
terminal.state = _G.nvim_browser_original_terminal_state_for_cursor

assert(type(browser.record_history) == "function", "history recorder API should exist")
assert(type(browser.history) == "function", "history API should exist")
assert(type(browser.history_urls) == "function", "history URL API should exist")
assert(type(browser.pick_history) == "function", "history picker API should exist")
assert(type(browser.resume) == "function", "resume API should exist")

browser.clear_history()
browser.record_history("https://example.com/docs", "Docs")
browser.record_history("https://example.com/blog", "Blog")
browser.record_history("https://example.com/docs", "Docs Updated")
local history = browser.history()
assert(#history == 2, "history should de-duplicate URLs")
assert(history[1].url == "https://example.com/docs", "history should move repeated URLs to the front")
assert(history[1].title == "Docs Updated", "history should update repeated URL titles")
assert(history[2].url == "https://example.com/blog", "history should keep older URLs after newer entries")
local history_urls = browser.history_urls()
assert(history_urls[1] == "https://example.com/docs", "history_urls should return URLs in recent order")
assert(history_urls[2] == "https://example.com/blog", "history_urls should include older URLs")
history[1].url = "mutated"
assert(browser.history()[1].url == "https://example.com/docs", "history should return a copy")

local picked_history_items = nil
local picked_history_prompt = nil
local picked_history_label = nil
local addressed_history = nil
local original_address = browser.address
browser.address = function(target)
  addressed_history = target
  return true
end
assert(browser.pick_history({
  select = function(items, opts, on_choice)
    picked_history_items = items
    picked_history_prompt = opts.prompt
    picked_history_label = opts.format_item(items[1])
    on_choice(items[1])
  end,
}) == true, "history picker should open when history exists")
assert(#picked_history_items == 2, "history picker should offer recent pages")
assert(picked_history_prompt == "nvim-browser history: ", "history picker should use a history prompt")
assert(picked_history_label:find("Docs Updated", 1, true), "history picker should format page titles")
assert(picked_history_label:find("https://example.com/docs", 1, true), "history picker should format page URLs")
assert(addressed_history == "https://example.com/docs", "history picker should navigate to the selected URL")

addressed_history = nil
assert(browser.pick_history({
  select = function(_, _, on_choice)
    on_choice(nil)
  end,
}) == false, "history picker should return false when canceled")
assert(addressed_history == nil, "history picker should not navigate when canceled")
browser.address = original_address
browser.clear_history()
assert(browser.pick_history({
  select = function()
    error("history picker should not open without entries")
  end,
}) == false, "history picker should return false without entries")
for index = 1, 55 do
  browser.record_history("https://example.com/page-" .. index, "Page " .. index)
end
local limited_history = browser.history()
assert(#limited_history == 50, "history should keep a bounded number of recent pages")
assert(limited_history[1].url == "https://example.com/page-55", "history limit should keep the newest page first")
assert(limited_history[#limited_history].url == "https://example.com/page-6", "history limit should drop the oldest pages")
browser.clear_history()

local session_dir = vim.fn.tempname()
vim.fn.mkdir(session_dir, "p")
local session_path = session_dir .. "/session.json"
vim.fn.writefile({
  vim.fn.json_encode({
    version = 1,
    last_target = "https://persisted.example/last",
    history = {
      { url = "https://persisted.example/older", title = "Older Updated" },
      { url = "https://persisted.example/latest", title = "Latest" },
      { url = "https://persisted.example/older", title = "Older" },
      { url = "file:///tmp/loaded-local.html", title = "Loaded Local" },
      { url = "about:blank", title = "Blank" },
      { url = "" },
      { title = "missing url" },
    },
  }),
}, session_path)
browser.setup({ session = { persist = true, path = session_path, history_limit = 2 } })
local persisted_history = browser.history()
assert(browser.last_target() == "https://persisted.example/last", "setup should load persisted last target")
assert(#persisted_history == 2, "setup should load and cap persisted history")
assert(persisted_history[1].url == "https://persisted.example/older", "loaded history should de-duplicate newest occurrences")
assert(persisted_history[1].title == "Older Updated", "loaded history should keep the newest duplicate title")
assert(persisted_history[2].url == "https://persisted.example/latest", "loaded history should keep older unique entries")
persisted_history[1].url = "mutated"
assert(browser.history()[1].url == "https://persisted.example/older", "loaded history should still return defensive copies")

browser.record_history("https://persisted.example/new", "New")
local saved_session = vim.fn.json_decode(table.concat(vim.fn.readfile(session_path), "\n"))
assert(saved_session.version == 1, "record_history should save a versioned session file")
assert(saved_session.last_target == "https://persisted.example/new", "record_history should save the newest URL as last target")
assert(#saved_session.history == 2, "record_history should save capped history")
assert(saved_session.history[1].url == "https://persisted.example/new", "record_history should save newest entries")

browser.record_history("https://persisted.example/from-metadata", "Metadata")
saved_session = vim.fn.json_decode(table.concat(vim.fn.readfile(session_path), "\n"))
assert(
  saved_session.last_target == "https://persisted.example/from-metadata",
  "record_history should persist metadata-driven URLs as the resume target"
)

browser.record_history("file:///tmp/from-metadata.html", "Metadata File")
saved_session = vim.fn.json_decode(table.concat(vim.fn.readfile(session_path), "\n"))
assert(saved_session.last_target == "file:///tmp/from-metadata.html", "record_history should persist non-web metadata URLs as last target")
assert(
  saved_session.history[1].url == "https://persisted.example/from-metadata",
  "record_history should not add non-web URLs to URL history"
)

local original_terminal_open_for_session = terminal.open
terminal.open = function() end
browser.open("/tmp/persisted-local.md")
terminal.open = original_terminal_open_for_session
saved_session = vim.fn.json_decode(table.concat(vim.fn.readfile(session_path), "\n"))
assert(saved_session.last_target == "/tmp/persisted-local.md", "open should persist local file targets as last target")
assert(
  saved_session.history[1].url == "https://persisted.example/from-metadata",
  "open should not add local file targets to URL history"
)

terminal.open = function() end
browser.open("file:///tmp/persisted-local.html")
terminal.open = original_terminal_open_for_session
saved_session = vim.fn.json_decode(table.concat(vim.fn.readfile(session_path), "\n"))
assert(saved_session.last_target == "file:///tmp/persisted-local.html", "open should persist file URLs as last target")
assert(
  saved_session.history[1].url == "https://persisted.example/from-metadata",
  "open should not add file URLs to URL history"
)

browser.clear_history()
saved_session = vim.fn.json_decode(table.concat(vim.fn.readfile(session_path), "\n"))
assert(#saved_session.history == 0, "clear_history should save an empty history")

local function run_session_edge_tests()
  local delayed_session_path = session_dir .. "/delayed-session.json"
  browser.setup({ session = { persist = true, path = delayed_session_path, history_limit = 3 } })
  assert(browser.resume() == false, "missing session file should not create a resume target")
  vim.fn.writefile({
    vim.fn.json_encode({
      version = 1,
      last_target = "https://persisted.example/delayed",
      history = {
        { url = "https://persisted.example/delayed-history", title = "Delayed History" },
      },
    }),
  }, delayed_session_path)
  browser.setup({ session = { persist = true, path = delayed_session_path, history_limit = 3 } })
  assert(browser.last_target() == "https://persisted.example/delayed", "setup should reload a session file that appears later")
  vim.fn.delete(delayed_session_path)
  browser.setup({ session = { persist = true, path = delayed_session_path, history_limit = 3 } })
  assert(browser.last_target() == nil, "setup should clear stale session state when a loaded file disappears")
  assert(#browser.history() == 0, "setup should clear stale history when a loaded file disappears")
  vim.fn.writefile({ "{ not json" }, delayed_session_path)
  local original_echo_for_edge_session = vim.api.nvim_echo
  local edge_session_warnings = {}
  vim.api.nvim_echo = function(chunks)
    if chunks[1][2] == "WarningMsg" then
      table.insert(edge_session_warnings, chunks[1][1])
    end
  end
  browser.setup({ session = { persist = true, path = delayed_session_path, history_limit = 3 } })
  vim.api.nvim_echo = original_echo_for_edge_session
  assert(browser.last_target() == nil, "setup should keep stale last target cleared when a session file becomes malformed")
  assert(#browser.history() == 0, "setup should keep stale history cleared when a session file becomes malformed")
  assert(edge_session_warnings[1] == "nvim-browser: ignored malformed session state", "malformed session replacement should warn")

  local write_count_path = session_dir .. "/write-count.json"
  local write_count = 0
  local original_writefile_for_count = vim.fn.writefile
  local original_terminal_open_for_count = terminal.open
  vim.fn.writefile = function(lines, path, ...)
    if path == write_count_path then
      write_count = write_count + 1
    end
    return original_writefile_for_count(lines, path, ...)
  end
  terminal.open = function() end
  browser.setup({ session = { persist = true, path = write_count_path, history_limit = 3 } })
  browser.open("https://persisted.example/write-count")
  terminal.open = original_terminal_open_for_count
  vim.fn.writefile = original_writefile_for_count
  assert(write_count == 1, "open should save a direct URL session once")

  local address_write_count_path = session_dir .. "/address-write-count.json"
  write_count = 0
  vim.fn.writefile = function(lines, path, ...)
    if path == address_write_count_path then
      write_count = write_count + 1
    end
    return original_writefile_for_count(lines, path, ...)
  end
  terminal.open = function() end
  browser.setup({ session = { persist = true, path = address_write_count_path, history_limit = 3 } })
  assert(browser.address("https://persisted.example/address-count", { is_active = false }) == true, "address should open inactive targets")
  terminal.open = original_terminal_open_for_count
  vim.fn.writefile = original_writefile_for_count
  assert(write_count == 1, "address should save a direct URL session once")

  local active_address_write_count_path = session_dir .. "/active-address-write-count.json"
  write_count = 0
  local original_terminal_navigate_for_count = terminal.navigate
  vim.fn.writefile = function(lines, path, ...)
    if path == active_address_write_count_path then
      write_count = write_count + 1
    end
    return original_writefile_for_count(lines, path, ...)
  end
  terminal.navigate = function()
    return true
  end
  browser.setup({ session = { persist = true, path = active_address_write_count_path, history_limit = 3 } })
  assert(browser.address("https://persisted.example/active-address-count", { is_active = true }) == true, "address should navigate active targets")
  terminal.navigate = original_terminal_navigate_for_count
  vim.fn.writefile = original_writefile_for_count
  assert(write_count == 1, "active address should save a direct URL session once")
end

run_session_edge_tests()

local malformed_path = session_dir .. "/malformed.json"
vim.fn.writefile({ "{ not json" }, malformed_path)
local original_echo_for_session = vim.api.nvim_echo
local session_warnings = {}
vim.api.nvim_echo = function(chunks)
  if chunks[1][2] == "WarningMsg" then
    table.insert(session_warnings, chunks[1][1])
  end
end
local malformed_ok = pcall(function()
  browser.setup({ session = { persist = true, path = malformed_path, history_limit = 3 } })
end)
vim.api.nvim_echo = original_echo_for_session
assert(malformed_ok == true, "setup should ignore malformed persisted session JSON without throwing")
if #session_warnings > 0 then
  assert(session_warnings[1] == "nvim-browser: ignored malformed session state", "malformed session JSON should warn once")
end
assert(#session_warnings <= 1, "malformed session JSON should not warn more than once")
assert(#browser.history() == 0, "malformed persisted session JSON should not keep stale history")

local unwritable_path = session_dir .. "/unwritable/session.json"
local original_writefile = vim.fn.writefile
local unwritable_warnings = {}
vim.fn.writefile = function(...)
  local path = select(2, ...)
  if path == unwritable_path then
    error("permission denied")
  end
  return original_writefile(...)
end
vim.api.nvim_echo = function(chunks)
  if chunks[1][2] == "WarningMsg" then
    table.insert(unwritable_warnings, chunks[1][1])
  end
end
local unwritable_ok = pcall(function()
  browser.setup({ session = { persist = true, path = unwritable_path, history_limit = 3 } })
  browser.record_history("https://persisted.example/write-failure", "Write Failure")
  browser.record_history("https://persisted.example/write-failure-2", "Write Failure 2")
end)
vim.fn.writefile = original_writefile
vim.api.nvim_echo = original_echo_for_session
assert(unwritable_ok == true, "session write failures should never block browsing")
assert(unwritable_warnings[1] == "nvim-browser: failed to write session state", "session write failures should warn")
assert(#unwritable_warnings == 1, "session write failures should warn at most once")

local original_open_for_resume = browser.open
local resumed_target = nil
browser.open = function(target)
  resumed_target = target
  return true
end
local resume_path = session_dir .. "/resume.json"
vim.fn.writefile({
  vim.fn.json_encode({
    version = 1,
    last_target = "https://persisted.example/last",
    history = {
      { url = "https://persisted.example/fallback", title = "Fallback" },
    },
  }),
}, resume_path)
browser.setup({ session = { persist = true, path = resume_path, history_limit = 3 } })
assert(browser.resume() == true, "resume should open a persisted last target")
assert(resumed_target == "https://persisted.example/last", "resume should prefer persisted last target")

local fallback_path = session_dir .. "/fallback.json"
vim.fn.writefile({
  vim.fn.json_encode({
    version = 1,
    history = {
      { url = "https://persisted.example/history", title = "History" },
    },
  }),
}, fallback_path)
resumed_target = nil
browser.setup({ session = { persist = true, path = fallback_path, history_limit = 3 } })
assert(browser.resume() == true, "resume should fall back to newest persisted history")
assert(resumed_target == "https://persisted.example/history", "resume should open newest history when no last target exists")
browser.open = original_open_for_resume
browser.setup({ session = { persist = false, history_limit = 50 } })
browser.clear_history()

local action_calls = {}
local function with_action_stubs(fn)
  local originals = {
    address = browser.address,
    reload = browser.reload,
    back = browser.back,
    forward = browser.forward,
    find_text = browser.find_text,
    pick_hint = browser.pick_hint,
    start_text_mode = browser.start_text_mode,
    screenshot = browser.screenshot,
    reader = browser.reader,
    status = browser.status,
    page_metrics = browser.page_metrics,
    focused_element = browser.focused_element,
    runtime_metadata = browser.runtime_metadata,
    current_url = browser.current_url,
    current_title = browser.current_title,
    status_error = browser.status_error,
    doctor = browser.doctor,
    close = browser.close,
  }
  browser.address = function()
    table.insert(action_calls, "address")
    return true
  end
  browser.reload = function()
    table.insert(action_calls, "reload")
    return true
  end
  browser.back = function()
    table.insert(action_calls, "back")
    return true
  end
  browser.forward = function()
    table.insert(action_calls, "forward")
    return true
  end
  browser.find_text = function(query)
    table.insert(action_calls, "find:" .. tostring(query))
    return true
  end
  browser.pick_hint = function()
    table.insert(action_calls, "hints")
    return true
  end
  browser.start_text_mode = function()
    table.insert(action_calls, "text_mode")
    return true
  end
  browser.screenshot = function(path)
    table.insert(action_calls, "screenshot:" .. tostring(path))
    return true, "/tmp/action.png"
  end
  browser.reader = function()
    table.insert(action_calls, "reader")
    return true
  end
  browser.status = function()
    table.insert(action_calls, "status")
    return "ok"
  end
  browser.page_metrics = function()
    return { scroll_y = 50, viewport_height = 100, document_height = 300 }
  end
  browser.focused_element = function()
    return { kind = "input", label = "Search box" }
  end
  browser.runtime_metadata = function()
    return {
      output = "kitty",
      viewport = { width = 960, height = 720 },
      cells = { columns = 120, rows = 40 },
      renderer = "chromium",
    }
  end
  browser.current_url = function()
    return "https://example.com"
  end
  browser.current_title = function()
    return "Example"
  end
  browser.status_error = function()
    return "last error"
  end
  browser.doctor = function()
    table.insert(action_calls, "doctor")
    return { lines = { "nvim-browser doctor" } }
  end
  browser.close = function()
    table.insert(action_calls, "close")
    return true
  end
  fn()
  for name, value in pairs(originals) do
    browser[name] = value
  end
end

with_action_stubs(function()
  local action_items = nil
  local action_prompt = nil
  local first_label = nil
  assert(browser.actions({
    select = function(items, opts, on_choice)
      action_items = items
      action_prompt = opts.prompt
      first_label = opts.format_item(items[1])
      on_choice(items[1])
    end,
    input = function()
      return "needle"
    end,
  }) == true, "actions should open the operation picker")
  assert(#action_items >= 12, "actions should offer the core browser operations")
  assert(action_prompt == "nvim-browser action: ", "actions should use an action picker prompt")
  assert(first_label == "Address", "actions should format action labels")
  local labels = {}
  for _, item in ipairs(action_items) do
    labels[item.label] = true
  end
  for _, label in ipairs({ "Address", "Reload", "Back", "Forward", "Find", "Hints", "Text mode", "Screenshot", "Reader", "Status", "Doctor", "Close" }) do
    assert(labels[label] == true, "actions should include " .. label)
  end
  assert(action_calls[#action_calls] == "address", "actions should run the selected action")

  action_calls = {}
  local address_warning = nil
  assert(browser.actions({
    select = function(items, _, on_choice)
      on_choice(items[1])
    end,
    input = function(prompt)
      assert(prompt == "nvim-browser address: ", "Address action should prompt for an address")
      return ""
    end,
    on_error = function(reason)
      address_warning = reason
    end,
  }) == true, "Address action should treat an empty nested prompt as a no-op")
  assert(address_warning == nil, "Address action should not warn on empty nested prompt")
  assert(#action_calls == 0, "Address action should not navigate on empty nested prompt")

  action_calls = {}
  assert(browser.actions({
    select = function(items, _, on_choice)
      for _, item in ipairs(items) do
        if item.label == "Find" then
          on_choice(item)
          return
        end
      end
    end,
    input = function(prompt)
      assert(prompt == "nvim-browser find: ", "Find action should prompt for search text")
      return "needle"
    end,
  }) == true, "Find action should run")
  assert(action_calls[#action_calls] == "find:needle", "Find action should call find_text")

  action_calls = {}
  local status_message = nil
  assert(browser.actions({
    select = function(items, _, on_choice)
      for _, item in ipairs(items) do
        if item.label == "Status" then
          on_choice(item)
          return
        end
      end
    end,
    on_status = function(message)
      status_message = message
    end,
  }) == true, "Status action should run")
  assert(action_calls[#action_calls] == "status", "Status action should call status")
  assert(status_message:find("Example", 1, true), "Status action should include the title")
  assert(status_message:find("scroll 25%%"), "Status action should include scroll metrics")
  assert(status_message:find("focus=input Search box", 1, true), "Status action should include focused element")
  assert(status_message:find("output=kitty", 1, true), "Status action should include runtime output")
  assert(status_message:find("viewport=960x720", 1, true), "Status action should include runtime viewport")
  assert(status_message:find("cells=120x40", 1, true), "Status action should include runtime cells")
  assert(status_message:find("renderer=chromium", 1, true), "Status action should include runtime renderer")
  assert(status_message:find("https://example.com", 1, true), "Status action should include the current URL")
  assert(status_message:find("last error", 1, true), "Status action should include the status error")

  action_calls = {}
  assert(browser.actions({
    select = function(_, _, on_choice)
      on_choice(nil)
    end,
  }) == true, "actions should treat picker cancel as a no-op")
  assert(#action_calls == 0, "canceled actions should not run anything")
end)

with_action_stubs(function()
  browser.reload = function()
    return false
  end
  local failed_reason = nil
  assert(browser.actions({
    select = function(items, _, on_choice)
      for _, item in ipairs(items) do
        if item.label == "Reload" then
          on_choice(item)
          return
        end
      end
    end,
    on_error = function(reason)
      failed_reason = reason
    end,
  }) == false, "failed actions should return false")
  assert(failed_reason == "action_failed", "failed actions should report action_failed")
end)

with_action_stubs(function()
  browser.reload = function()
    return false
  end
  local original_echo = vim.api.nvim_echo
  local action_warning = nil
  local action_warning_group = nil
  vim.api.nvim_echo = function(chunks)
    action_warning = chunks[1][1]
    action_warning_group = chunks[1][2]
  end
  assert(browser.actions({
    select = function(items, _, on_choice)
      for _, item in ipairs(items) do
        if item.label == "Reload" then
          on_choice(item)
          return
        end
      end
    end,
  }) == false, "failed actions without on_error should return false")
  vim.api.nvim_echo = original_echo
  assert(
    action_warning == "nvim-browser: selected browser action failed or browser session is inactive",
    "failed actions without on_error should show the default warning"
  )
  assert(action_warning_group == "WarningMsg", "failed actions without on_error should use WarningMsg")
end)

with_action_stubs(function()
  browser.start_text_mode = function()
    vim.api.nvim_echo({ { "nvim-browser: text mode requires an active cursor-addressable browser preview", "WarningMsg" } }, false, {})
    return false
  end
  local original_echo = vim.api.nvim_echo
  local action_warning_count = 0
  vim.api.nvim_echo = function(chunks)
    if chunks[1][2] == "WarningMsg" then
      action_warning_count = action_warning_count + 1
    end
  end
  assert(browser.actions({
    select = function(items, _, on_choice)
      for _, item in ipairs(items) do
        if item.label == "Text mode" then
          on_choice(item)
          return
        end
      end
    end,
  }) == false, "Text mode action should fail when text mode is unavailable")
  vim.api.nvim_echo = original_echo
  assert(action_warning_count == 1, "Text mode action should not add a duplicate generic warning")
end)

with_action_stubs(function()
  local forwarded_on_error = nil
  browser.pick_hint = function(opts)
    forwarded_on_error = opts.on_error
    return true
  end
  assert(browser.actions({
    select = function(items, _, on_choice)
      for _, item in ipairs(items) do
        if item.label == "Hints" then
          on_choice(item)
          return
        end
      end
    end,
    on_error = function() end,
  }) == true, "Hints action should open hint picker")
  assert(type(forwarded_on_error) == "function", "Hints action should forward async picker errors")
end)

with_action_stubs(function()
  browser.pick_hint = function(opts)
    opts.on_cancel()
    return false
  end
  local failed_reason = nil
  assert(browser.actions({
    select = function(items, _, on_choice)
      for _, item in ipairs(items) do
        if item.label == "Hints" then
          on_choice(item)
          return
        end
      end
    end,
    on_error = function(reason)
      failed_reason = reason
    end,
  }) == true, "Hints action should treat nested picker cancel as a no-op")
  assert(failed_reason == nil, "Hints action cancel should not report an error")
end)

with_action_stubs(function()
  browser.pick_hint = function()
    return false
  end
  local failed_reason = nil
  assert(browser.actions({
    select = function(items, _, on_choice)
      for _, item in ipairs(items) do
        if item.label == "Hints" then
          on_choice(item)
          return
        end
      end
    end,
    on_error = function(reason)
      failed_reason = reason
    end,
  }) == false, "Hints action should fail when hints are unavailable before picker selection")
  assert(failed_reason == "action_failed", "Hints action should report pre-picker failures")
end)

with_action_stubs(function()
  local forwarded_on_error = nil
  browser.pick_hint = function(opts)
    forwarded_on_error = opts.on_error
    return true
  end
  local original_echo = vim.api.nvim_echo
  local action_warning = nil
  local action_warning_group = nil
  vim.api.nvim_echo = function(chunks)
    action_warning = chunks[1][1]
    action_warning_group = chunks[1][2]
  end
  assert(browser.actions({
    select = function(items, _, on_choice)
      for _, item in ipairs(items) do
        if item.label == "Hints" then
          on_choice(item)
          return
        end
      end
    end,
  }) == true, "Hints action should support async picker errors without explicit on_error")
  forwarded_on_error("action_failed")
  vim.api.nvim_echo = original_echo
  assert(
    action_warning == "nvim-browser: selected browser action failed or browser session is inactive",
    "Hints action async failures should show the default warning"
  )
  assert(action_warning_group == "WarningMsg", "Hints action async failures should use WarningMsg")
end)

with_action_stubs(function()
  browser.screenshot = function(_, opts)
    local ok, path = true, "/tmp/action.png"
    opts.on_response({ status = "ok" })
    return ok, path
  end
  local original_echo = vim.api.nvim_echo
  local screenshot_message = nil
  vim.api.nvim_echo = function(chunks)
    screenshot_message = chunks[1][1]
  end
  assert(browser.actions({
    select = function(items, _, on_choice)
      for _, item in ipairs(items) do
        if item.label == "Screenshot" then
          on_choice(item)
          return
        end
      end
    end,
  }) == true, "Screenshot action should run")
  vim.api.nvim_echo = original_echo
  assert(
    screenshot_message == "nvim-browser: screenshot saved: /tmp/action.png",
    "Screenshot action should echo the saved path"
  )
end)

with_action_stubs(function()
  browser.pick_hint = function(opts)
    opts.on_error("action_failed")
    return false
  end
  local original_echo = vim.api.nvim_echo
  local action_warning_count = 0
  vim.api.nvim_echo = function(chunks)
    if chunks[1][2] == "WarningMsg" then
      action_warning_count = action_warning_count + 1
    end
  end
  assert(browser.actions({
    select = function(items, _, on_choice)
      for _, item in ipairs(items) do
        if item.label == "Hints" then
          on_choice(item)
          return
        end
      end
    end,
  }) == false, "Hints action synchronous failures should fail")
  vim.api.nvim_echo = original_echo
  assert(action_warning_count == 1, "Hints action synchronous failures should warn once")
end)

local original_hints = browser.hints
local original_click_hint = browser.click_hint
local original_type_hint = browser.type_hint
local original_select_hint = browser.select_hint
local original_upload_hint = browser.upload_hint
local original_yank_hint_url = browser.yank_hint_url
local original_terminal_right_click_point = terminal.right_click_point
local original_terminal_right_click_here = terminal.right_click_here
local original_terminal_right_click_mouse = terminal.right_click_mouse
local original_terminal_right_click_hint = terminal.right_click_hint
local original_terminal_screenshot = terminal.screenshot
local original_follow_hint = browser.follow_hint
local original_focus_hint = browser.focus_hint
local original_hover_hint = browser.hover_hint
local original_input_text = browser.input_text
local original_press_key = browser.press_key
local original_terminal_follow_hint = terminal.follow_hint
local original_terminal_click_mouse = terminal.click_mouse
local original_terminal_wheel_point = terminal.wheel_point
local original_terminal_wheel_mouse = terminal.wheel_mouse
local original_terminal_type_hint = terminal.type_hint
local original_terminal_select_hint = terminal.select_hint
local original_terminal_upload_hint = terminal.upload_hint
local original_terminal_toggle_hint = terminal.toggle_hint
local original_terminal_hover_point = terminal.hover_point
local original_terminal_hover_here = terminal.hover_here
local original_terminal_hover_hint = terminal.hover_hint
local original_terminal_focus_hint = terminal.focus_hint
local original_terminal_type_point = terminal.type_point
local original_terminal_type_here = terminal.type_here
local original_terminal_stop = terminal.stop
local original_terminal_input_text = terminal.input_text
local original_terminal_press_key = terminal.press_key
local original_terminal_submit_focused = terminal.submit_focused
local original_terminal_start_text_mode = terminal.start_text_mode
local original_terminal_page_scroll = terminal.page_scroll
local original_terminal_select_region = terminal.select_region
local original_terminal_yank_selection = terminal.yank_selection
local original_terminal_yank_region = terminal.yank_region
local original_terminal_yank_current_url = terminal.yank_current_url
local original_terminal_yank_hint_url = terminal.yank_hint_url
local original_terminal_find_text = terminal.find_text
local original_terminal_find_next = terminal.find_next
local original_terminal_find_previous = terminal.find_previous
local original_terminal_zoom_in = terminal.zoom_in
local original_terminal_zoom_out = terminal.zoom_out
local original_terminal_zoom_reset = terminal.zoom_reset
local original_terminal_navigate = terminal.navigate

browser.clear_history()
terminal.navigate = function()
  return true
end
assert(browser.navigate("https://queued.example.com") == true, "navigate should report queued active-session navigation")
assert(#browser.history() == 0, "navigate should wait for serve metadata before recording active-session history")
terminal.navigate = original_terminal_navigate

local original_terminal_open = terminal.open
local opened_command = nil
terminal.open = function(command)
  opened_command = command
end
browser.clear_history()
browser.open("/tmp/local page.md")
assert(opened_command ~= nil, "open should still start a browser preview for local paths")
assert(#browser.history() == 0, "open should wait for serve metadata before recording local path history")
browser.open("https://example.com/direct-open")
assert(browser.history()[1].url == "https://example.com/direct-open", "open should record direct URL targets immediately")
terminal.open = original_terminal_open

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

local picked_follow = nil
browser.hints = function()
  return {
    { id = 1, hint_label = "a", kind = "link", label = "Docs", href = "https://example.com/docs" },
    { id = 2, hint_label = "s", kind = "input", label = "Search" },
    {
      id = 3,
      hint_label = "o",
      kind = "select",
      label = "Country",
      options = {
        { value = "jp", label = "Japan", selected = false, disabled = false },
        { value = "xx", label = "Disabled", selected = false, disabled = true },
      },
    },
    { id = 4, hint_label = "u", kind = "file", label = "Avatar" },
  }
end
browser.follow_hint = function(label)
  picked_follow = label
  return true
end
local select_prompt = nil
local select_format = nil
assert(browser.pick_hint(function(items, opts, on_choice)
  select_prompt = opts.prompt
  select_format = opts.format_item(items[1])
  on_choice(items[1])
end) == true, "pick_hint should follow the selected hint by default")
assert(picked_follow == "a", "pick_hint should pass the selected hint label to follow_hint")
assert(select_prompt == "nvim-browser hint: ", "pick_hint should use a hint picker prompt")
assert(select_format:find("a link Docs", 1, true), "pick_hint should format hint label, kind, and text")

local picked_focus = nil
browser.focus_hint = function(label)
  picked_focus = label
  return true
end
assert(browser.pick_hint(function(items, _, on_choice)
  on_choice(items[2])
end, { action = "focus" }) == true, "pick_hint should support focus action")
assert(picked_focus == "s", "pick_hint should pass selected label to focus_hint")

local picked_hover = nil
browser.hover_hint = function(label)
  picked_hover = label
  return true
end
assert(browser.pick_hint({
  action = "hover",
  select = function(items, _, on_choice)
    on_choice(items[1])
  end,
}) == true, "pick_hint should support opts.select injection")
assert(picked_hover == "a", "pick_hint should pass selected label to hover_hint")

local typed_from_picker = nil
browser.type_hint = function(label, text, opts)
  typed_from_picker = { label = label, text = text, submit = opts ~= nil and opts.submit == true }
  return true
end
local picked_type_items = nil
assert(browser.pick_hint({
  action = "type",
  select = function(items, _, on_choice)
    picked_type_items = items
    on_choice(items[1])
  end,
  input = function(prompt)
    assert(prompt == "nvim-browser text: ", "type picker should prompt for text")
    return "typed via picker"
  end,
}) == true, "pick_hint should support picker-based text input")
assert(#picked_type_items == 1, "type picker should only include input-like hints")
assert(picked_type_items[1].hint_label == "s", "type picker should include the input hint")
assert(typed_from_picker.label == "s", "type picker should type into the selected hint")
assert(typed_from_picker.text == "typed via picker", "type picker should pass prompted text")
assert(typed_from_picker.submit == false, "type picker should not submit by default")

typed_from_picker = nil
assert(browser.pick_hint({
  action = "submit",
  select = function(items, _, on_choice)
    on_choice(items[1])
  end,
  input = function()
    return "submitted via picker"
  end,
}) == true, "pick_hint should support picker-based submit input")
assert(typed_from_picker.label == "s", "submit picker should type into the selected hint")
assert(typed_from_picker.text == "submitted via picker", "submit picker should pass prompted text")
assert(typed_from_picker.submit == true, "submit picker should request submit mode")

typed_from_picker = nil
assert(browser.pick_hint({
  action = "type",
  select = function(items, _, on_choice)
    on_choice(items[1])
  end,
  input = function()
    return ""
  end,
}) == true, "type picker should no-op on empty text")
assert(typed_from_picker == nil, "type picker should not call type_hint on empty text")

browser.hints = function()
  return {
    { id = 1, hint_label = "a", kind = "link", label = "Docs", href = "https://example.com/docs" },
  }
end
assert(browser.pick_hint({
  action = "type",
  select = function()
    error("select should not be called without input-like hints")
  end,
}) == false, "type picker should return false when no input-like hints are available")
browser.type_hint = original_type_hint

local async_error = nil
local async_on_choice = nil
browser.follow_hint = function()
  return false
end
assert(browser.pick_hint({
  select = function(_, _, on_choice)
    async_on_choice = on_choice
  end,
  on_error = function(reason)
    async_error = reason
  end,
}) == true, "pick_hint should return true after launching an async picker")
async_on_choice({ id = 3, hint_label = "z", kind = "button", label = "Missing" })
assert(async_error == "action_failed", "pick_hint should report async action failures through on_error")

assert(browser.pick_hint({
  action = "bogus",
  select = function()
    error("select should not be called for invalid picker actions")
  end,
}) == false, "pick_hint should reject invalid actions before launching the picker")
assert(browser.pick_hint_action_available("bogus") == false, "invalid picker actions should be detectable")
assert(browser.pick_hint_action_available("toggle") == true, "valid picker actions should be detectable")
assert(browser.pick_hint_action_available("right-click") == true, "right-click picker action should be detectable")
assert(browser.pick_hint_action_available("type") == true, "type picker action should be detectable")
assert(browser.pick_hint_action_available("submit") == true, "submit picker action should be detectable")
assert(browser.pick_hint_action_available("select") == true, "select picker action should be detectable")
assert(browser.pick_hint_action_available("upload") == true, "upload picker action should be detectable")
assert(browser.pick_hint_action_available("yank-url") == true, "yank-url picker action should be detectable")

browser.hints = function()
  return {
    { id = 1, hint_label = "a", kind = "link", label = "Docs", href = "https://example.com/docs" },
    { id = 2, hint_label = "s", kind = "input", label = "Search" },
    {
      id = 3,
      hint_label = "o",
      kind = "select",
      label = "Country",
      options = {
        { value = "jp", label = "Japan", selected = false, disabled = false },
        { value = "xx", label = "Disabled", selected = false, disabled = true },
      },
    },
    { id = 4, hint_label = "u", kind = "file", label = "Avatar" },
  }
end

local selected_from_picker = nil
browser.select_hint = function(label, choice)
  selected_from_picker = { label = label, choice = choice }
  return true
end
local select_picker_prompts = {}
local select_hint_count = nil
local select_option_count = nil
assert(browser.pick_hint({
  action = "select",
  select = function(items, opts, on_choice)
    table.insert(select_picker_prompts, opts.prompt)
    if opts.prompt == "nvim-browser hint: " then
      select_hint_count = #items
      on_choice(items[1])
    else
      select_option_count = #items
      on_choice(items[1])
    end
  end,
}) == true, "pick_hint select should open hinted select and option pickers")
assert(select_hint_count == 1, "pick_hint select should only include hints with enabled select options")
assert(select_option_count == 1, "pick_hint select should only include enabled options")
assert(selected_from_picker.label == "o", "pick_hint select should pass selected hint label")
assert(selected_from_picker.choice == "jp", "pick_hint select should pass option value")
assert(
  table.concat(select_picker_prompts, "|") == "nvim-browser hint: |nvim-browser option: ",
  "pick_hint select should prompt for hint then option"
)

local select_error_count = 0
browser.select_hint = function()
  return false
end
assert(browser.pick_hint({
  action = "select",
  select = function(items, _, on_choice)
    on_choice(items[1])
  end,
  on_error = function(reason)
    select_error_count = select_error_count + 1
    assert(reason == "action_failed", "pick_hint select should report failed select_hint actions")
  end,
}) == false, "pick_hint select should return false when select_hint fails synchronously")
assert(select_error_count == 1, "pick_hint select should report a failed action once")

local uploaded_from_picker = nil
browser.upload_hint = function(label, paths)
  uploaded_from_picker = { label = label, paths = paths }
  return true
end
local upload_hint_count = nil
assert(browser.pick_hint({
  action = "upload",
  select = function(items, _, on_choice)
    upload_hint_count = #items
    on_choice(items[1])
  end,
  input = function(prompt)
    assert(prompt == "nvim-browser file: ", "pick_hint upload should prompt for a file path")
    return "/tmp/avatar.png"
  end,
}) == true, "pick_hint upload should upload into a selected file hint")
assert(upload_hint_count == 1, "pick_hint upload should only include file hints")
assert(uploaded_from_picker.label == "u", "pick_hint upload should pass selected hint label")
assert(uploaded_from_picker.paths[1] == "/tmp/avatar.png", "pick_hint upload should pass prompted file path")

uploaded_from_picker = nil
assert(browser.pick_hint({
  action = "upload",
  select = function(items, _, on_choice)
    on_choice(items[1])
  end,
  input = function()
    return ""
  end,
}) == true, "pick_hint upload should no-op on empty file path")
assert(uploaded_from_picker == nil, "pick_hint upload should not call upload_hint on empty file path")

local upload_error_count = 0
browser.upload_hint = function()
  return false
end
assert(browser.pick_hint({
  action = "upload",
  select = function(items, _, on_choice)
    on_choice(items[1])
  end,
  input = function()
    return "/tmp/avatar.png"
  end,
  on_error = function(reason)
    upload_error_count = upload_error_count + 1
    assert(reason == "action_failed", "pick_hint upload should report failed upload actions")
  end,
}) == false, "pick_hint upload should return false when upload_hint fails synchronously")
assert(upload_error_count == 1, "pick_hint upload should report a failed action once")

local yanked_from_picker = nil
browser.yank_hint_url = function(label, register)
  yanked_from_picker = { label = label, register = register }
  return true
end
local yank_hint_count = nil
assert(browser.pick_hint({
  action = "yank-url",
  select = function(items, _, on_choice)
    yank_hint_count = #items
    on_choice(items[1])
  end,
}) == true, "pick_hint yank-url should yank the selected link hint URL")
assert(yank_hint_count == 1, "pick_hint yank-url should only include hints with href")
assert(yanked_from_picker.label == "a", "pick_hint yank-url should pass selected hint label")
assert(yanked_from_picker.register == '"', "pick_hint yank-url should use the unnamed register by default")

local yank_error_count = 0
browser.yank_hint_url = function()
  return false
end
assert(browser.pick_hint({
  action = "yank-url",
  select = function(items, _, on_choice)
    on_choice(items[1])
  end,
  on_error = function(reason)
    yank_error_count = yank_error_count + 1
    assert(reason == "action_failed", "pick_hint yank-url should report failed yank actions")
  end,
}) == false, "pick_hint yank-url should return false when yank_hint_url fails synchronously")
assert(yank_error_count == 1, "pick_hint yank-url should report a failed action once")

browser.hints = function()
  return {
    { id = 2, hint_label = "s", kind = "input", label = "Search" },
  }
end
assert(browser.pick_hint({
  action = "select",
  select = function()
    error("select picker should not open without selectable hints")
  end,
}) == false, "pick_hint select should return false when no select hints are available")
assert(browser.pick_hint({
  action = "upload",
  select = function()
    error("upload picker should not open without file hints")
  end,
}) == false, "pick_hint upload should return false when no file hints are available")
assert(browser.pick_hint({
  action = "yank-url",
  select = function()
    error("yank-url picker should not open without link hints")
  end,
}) == false, "pick_hint yank-url should return false when no link hints are available")

assert(browser.pick_hint(function(_, _, on_choice)
  on_choice(nil)
end) == false, "pick_hint should cancel when no hint is selected")

browser.hints = function()
  return {}
end
assert(browser.pick_hint(function()
  error("select should not be called without hints")
end) == false, "pick_hint should return false without active hints")

browser.hints = original_hints
browser.follow_hint = original_follow_hint
browser.focus_hint = original_focus_hint
browser.hover_hint = original_hover_hint
browser.select_hint = original_select_hint
browser.upload_hint = original_upload_hint
browser.yank_hint_url = original_yank_hint_url

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

local yanked_current_register = nil
terminal.yank_current_url = function(register)
  yanked_current_register = register
  return "current-yanked"
end
assert(browser.yank_current_url("+") == "current-yanked", "yank_current_url should delegate to terminal")
assert(yanked_current_register == "+", "yank_current_url should pass explicit registers to terminal")

local yanked_hint_url = nil
terminal.yank_hint_url = function(identifier, register)
  yanked_hint_url = { identifier = identifier, register = register }
  return "hint-yanked"
end
assert(browser.yank_hint_url("a", "*") == "hint-yanked", "yank_hint_url should delegate to terminal")
assert(yanked_hint_url.identifier == "a", "yank_hint_url should pass hint identifiers to terminal")
assert(yanked_hint_url.register == "*", "yank_hint_url should pass explicit registers to terminal")

local clicked_mouse = nil
terminal.click_mouse = function(mousepos)
  clicked_mouse = mousepos
  return "clicked"
end
local mousepos = { winid = 10, line = 3, column = 8 }
assert(browser.click_mouse(mousepos) == "clicked", "click_mouse should delegate to terminal mouse click semantics")
assert(clicked_mouse == mousepos, "click_mouse should pass explicit mouse position to terminal")

local right_clicked_point = nil
terminal.right_click_point = function(x, y)
  right_clicked_point = { x = x, y = y }
  return "right-point"
end
assert(browser.right_click_point(12, 24) == "right-point", "right_click_point should delegate to terminal")
assert(right_clicked_point.x == 12, "right_click_point should pass the x coordinate")
assert(right_clicked_point.y == 24, "right_click_point should pass the y coordinate")

terminal.right_click_here = function()
  return "right-here"
end
assert(browser.right_click_here() == "right-here", "right_click_here should delegate to terminal")

local right_clicked_mouse = nil
terminal.right_click_mouse = function(explicit_mousepos)
  right_clicked_mouse = explicit_mousepos
  return "right-mouse"
end
assert(browser.right_click_mouse(mousepos) == "right-mouse", "right_click_mouse should delegate to terminal")
assert(right_clicked_mouse == mousepos, "right_click_mouse should pass explicit mouse position to terminal")

local right_clicked_hint = nil
terminal.right_click_hint = function(identifier)
  right_clicked_hint = identifier
  return "right-hint"
end
assert(browser.right_click_hint("s") == "right-hint", "right_click_hint should delegate to terminal")
assert(right_clicked_hint == "s", "right_click_hint should pass hint identifiers to terminal")

local wheeled_mouse = nil
terminal.wheel_mouse = function(delta_y, delta_x, explicit_mousepos)
  wheeled_mouse = { delta_y = delta_y, delta_x = delta_x, mousepos = explicit_mousepos }
  return "wheeled"
end
assert(browser.wheel_mouse(120, 0, mousepos) == "wheeled", "wheel_mouse should delegate to terminal mouse wheel semantics")
assert(wheeled_mouse.delta_y == 120, "wheel_mouse should pass vertical wheel delta to terminal")
assert(wheeled_mouse.delta_x == 0, "wheel_mouse should pass horizontal wheel delta to terminal")
assert(wheeled_mouse.mousepos == mousepos, "wheel_mouse should pass explicit mouse position to terminal")

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

local selected_hint = nil
terminal.select_hint = function(label, choice)
  selected_hint = {
    label = label,
    choice = choice,
  }
  return true
end
assert(browser.select_hint("s", "Canada") == true, "select_hint should delegate to terminal")
assert(selected_hint.label == "s", "select_hint should pass hint label to terminal")
assert(selected_hint.choice == "Canada", "select_hint should pass option choice to terminal")

local uploaded_hint = nil
terminal.upload_hint = function(label, paths)
  uploaded_hint = {
    label = label,
    paths = paths,
  }
  return true
end
assert(browser.upload_hint("u", { "/tmp/example.txt" }) == true, "upload_hint should delegate to terminal")
assert(uploaded_hint.label == "u", "upload_hint should pass hint label to terminal")
assert(uploaded_hint.paths[1] == "/tmp/example.txt", "upload_hint should pass file paths to terminal")

local toggled_hint = nil
terminal.toggle_hint = function(label)
  toggled_hint = label
  return true
end
assert(browser.toggle_hint("c") == true, "toggle_hint should delegate to terminal")
assert(toggled_hint == "c", "toggle_hint should pass hint label to terminal")

local focused_hint = nil
terminal.focus_hint = function(label)
  focused_hint = label
  return true
end
assert(browser.focus_hint("i") == true, "focus_hint should delegate to terminal")
assert(focused_hint == "i", "focus_hint should pass hint label to terminal")

local hovered_point = nil
terminal.hover_point = function(x, y)
  hovered_point = { x = x, y = y }
  return true
end
assert(browser.hover_point(12.5, 24.25) == true, "hover_point should delegate to terminal point hover")
assert(hovered_point.x == 12.5, "hover_point should pass x coordinate to terminal")
assert(hovered_point.y == 24.25, "hover_point should pass y coordinate to terminal")

local wheeled_point = nil
terminal.wheel_point = function(x, y, delta_y, delta_x)
  wheeled_point = { x = x, y = y, delta_y = delta_y, delta_x = delta_x }
  return true
end
assert(browser.wheel_point(12.5, 24.25, 120, 0) == true, "wheel_point should delegate to terminal point wheel")
assert(wheeled_point.x == 12.5, "wheel_point should pass x coordinate to terminal")
assert(wheeled_point.y == 24.25, "wheel_point should pass y coordinate to terminal")
assert(wheeled_point.delta_y == 120, "wheel_point should pass vertical wheel delta to terminal")
assert(wheeled_point.delta_x == 0, "wheel_point should pass horizontal wheel delta to terminal")

local found_point = nil
terminal.find_text = function(query, opts)
  found_point = { query = query, backwards = opts ~= nil and opts.backwards == true }
  return true
end
assert(browser.find_text("needle") == true, "find_text should delegate to terminal find")
assert(found_point.query == "needle", "find_text should pass query to terminal")
assert(found_point.backwards == false, "find_text should default to forward search")
assert(browser.find_text("needle", { backwards = true }) == true, "find_text should support backwards search")
assert(found_point.backwards == true, "find_text should pass backwards option to terminal")

local find_next_called = false
terminal.find_next = function()
  find_next_called = true
  return "next"
end
assert(browser.find_next() == "next", "find_next should delegate to terminal")
assert(find_next_called == true, "find_next should call terminal.find_next")

local find_previous_called = false
terminal.find_previous = function()
  find_previous_called = true
  return "previous"
end
assert(browser.find_previous() == "previous", "find_previous should delegate to terminal")
assert(find_previous_called == true, "find_previous should call terminal.find_previous")

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

local typed_point = nil
terminal.type_point = function(x, y, text, opts)
  typed_point = { x = x, y = y, text = text, submit = opts ~= nil and opts.submit == true }
  return true
end
assert(browser.type_point(12.5, 24.25, "point text", { submit = true }) == true, "type_point should delegate to terminal point typing")
assert(typed_point.x == 12.5, "type_point should pass x coordinate to terminal")
assert(typed_point.y == 24.25, "type_point should pass y coordinate to terminal")
assert(typed_point.text == "point text", "type_point should pass text to terminal")
assert(typed_point.submit == true, "type_point should pass submit option to terminal")

local typed_here = nil
terminal.type_here = function(text, opts)
  typed_here = { text = text, submit = opts ~= nil and opts.submit == true }
  return "typed-here"
end
assert(browser.type_here("cursor text", { submit = true }) == "typed-here", "type_here should delegate to terminal cursor typing")
assert(typed_here.text == "cursor text", "type_here should pass text to terminal")
assert(typed_here.submit == true, "type_here should pass submit option to terminal")

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

local unnamed_register = vim.fn.getreg('"')
local plus_register = vim.fn.getreg("+")
vim.fn.setreg('"', "hello from unnamed\nregister")
vim.fn.setreg("+", "hello from clipboard")

focused_input = nil
assert(browser.paste_register() == true, "paste_register should paste the unnamed register by default")
assert(focused_input == "hello from unnamed\nregister", "paste_register should pass unnamed register text to terminal")

focused_input = nil
assert(browser.paste_register("+") == true, "paste_register should paste an explicit register")
assert(focused_input == "hello from clipboard", "paste_register should pass explicit register text to terminal")

focused_input = nil
vim.fn.setreg("a", "should not paste")
assert(browser.paste_register("ab") == false, "paste_register should reject multi-character register names")
assert(focused_input == nil, "invalid register names should not be passed to terminal")

vim.fn.setreg('"', "")
assert(browser.paste_register() == false, "paste_register should reject empty register contents")

vim.fn.setreg('"', unnamed_register)
vim.fn.setreg("+", plus_register)

local yanked_register = nil
terminal.yank_selection = function(register)
  yanked_register = register or '"'
  return true
end
assert(browser.yank_selection() == true, "yank_selection should yank into the unnamed register by default")
assert(yanked_register == '"', "yank_selection should pass unnamed register to terminal")
yanked_register = nil
assert(browser.yank_selection("+") == true, "yank_selection should yank into an explicit register")
assert(yanked_register == "+", "yank_selection should pass explicit register to terminal")

local selected_region = nil
terminal.select_region = function(start_row, start_col, end_row, end_col)
  selected_region = { start_row, start_col, end_row, end_col }
  return true
end
assert(browser.select_region(2, 3, 4, 25) == true, "select_region should delegate to terminal")
assert(
  table.concat(selected_region, ",") == "2,3,4,25",
  "select_region should pass preview-cell coordinates to terminal"
)

local yanked_region = nil
terminal.yank_region = function(register, start_row, start_col, end_row, end_col)
  yanked_region = { register, start_row, start_col, end_row, end_col }
  return true
end
assert(browser.yank_region(nil, 2, 3, 4, 25) == true, "yank_region should yank into the unnamed register by default")
assert(
  table.concat(yanked_region, ",") == '",2,3,4,25',
  "yank_region should pass unnamed register and preview-cell coordinates to terminal"
)
yanked_region = nil
assert(browser.yank_region("+", 5, 6, 7, 8) == true, "yank_region should yank into an explicit register")
assert(
  table.concat(yanked_region, ",") == "+,5,6,7,8",
  "yank_region should pass explicit register and preview-cell coordinates to terminal"
)

local screenshot_path = nil
terminal.screenshot = function(path)
  screenshot_path = path
  return true
end
local explicit_screenshot_ok, explicit_screenshot_path = browser.screenshot("/tmp/page.png")
assert(explicit_screenshot_ok == true, "screenshot should delegate to terminal")
assert(explicit_screenshot_path == "/tmp/page.png", "screenshot should return the explicit target path")
assert(screenshot_path == "/tmp/page.png", "screenshot should pass the target path")
local empty_screenshot_ok = browser.screenshot("")
assert(empty_screenshot_ok == false, "screenshot should reject an empty path")

local original_current_title = browser.current_title
local original_current_url = browser.current_url
browser.current_title = function()
  return "Example: Docs/Guide"
end
browser.current_url = function()
  return "https://example.com/docs"
end
screenshot_path = nil
local mkdir_calls = {}
local generated_screenshot_ok, generated_screenshot_path = browser.screenshot(nil, {
  stdpath = function(kind)
    assert(kind == "cache", "screenshot should use stdpath('cache')")
    return "/tmp/nvim-cache"
  end,
  mkdir = function(path, mode)
    table.insert(mkdir_calls, { path = path, mode = mode })
    return 1
  end,
  timestamp = function()
    return "20260624-120000"
  end,
})
assert(generated_screenshot_ok == true, "screenshot should save to a generated path when no path is provided")
assert(
  generated_screenshot_path == "/tmp/nvim-cache/nvim-browser/screenshots/Example-Docs-Guide-20260624-120000.png",
  "generated screenshot path should include sanitized page title and timestamp"
)
assert(screenshot_path == generated_screenshot_path, "generated screenshot path should be sent to terminal")
assert(mkdir_calls[1].path == "/tmp/nvim-cache/nvim-browser/screenshots", "screenshot should create the screenshot directory")
assert(mkdir_calls[1].mode == "p", "screenshot should create parent directories")

local _, second_generated_screenshot_path = browser.screenshot(nil, {
  stdpath = function()
    return "/tmp/nvim-cache"
  end,
  mkdir = function()
    return 1
  end,
  timestamp = function()
    return "20260624-120000"
  end,
})
assert(
  second_generated_screenshot_path == "/tmp/nvim-cache/nvim-browser/screenshots/Example-Docs-Guide-20260624-120000-2.png",
  "generated screenshot paths should avoid overwriting another screenshot from the same page and second"
)

browser.current_title = function()
  return "Other Page"
end
local _, other_generated_screenshot_path = browser.screenshot(nil, {
  stdpath = function()
    return "/tmp/nvim-cache"
  end,
  mkdir = function()
    return 1
  end,
  timestamp = function()
    return "20260624-120000"
  end,
})
assert(
  other_generated_screenshot_path == "/tmp/nvim-cache/nvim-browser/screenshots/Other-Page-20260624-120000.png",
  "generated screenshot paths should not share sequence counters across pages"
)
browser.current_title = function()
  return "Example: Docs/Guide"
end
local _, third_generated_screenshot_path = browser.screenshot(nil, {
  stdpath = function()
    return "/tmp/nvim-cache"
  end,
  mkdir = function()
    return 1
  end,
  timestamp = function()
    return "20260624-120000"
  end,
})
assert(
  third_generated_screenshot_path == "/tmp/nvim-cache/nvim-browser/screenshots/Example-Docs-Guide-20260624-120000-3.png",
  "generated screenshot paths should avoid overwriting non-consecutive captures from the same page and second"
)

browser.current_title = function()
  return ""
end
browser.current_url = function()
  return "https://example.com/docs/intro?q=1"
end
screenshot_path = nil
local url_named_screenshot_ok, url_named_screenshot_path = browser.screenshot(nil, {
  stdpath = function()
    return "/tmp/nvim-cache"
  end,
  mkdir = function()
    return 1
  end,
  timestamp = function()
    return "20260624-120002"
  end,
})
assert(url_named_screenshot_ok == true, "screenshot should fall back to the URL when the title is empty")
assert(
  url_named_screenshot_path == "/tmp/nvim-cache/nvim-browser/screenshots/https-example.com-docs-intro-q-1-20260624-120002.png",
  "generated screenshot path should include sanitized URL when title is empty"
)

terminal.screenshot = function()
  return false
end
local failed_generated_screenshot_ok, failed_generated_screenshot_path = browser.screenshot(nil, {
  stdpath = function()
    return "/tmp/nvim-cache"
  end,
  mkdir = function()
    return 1
  end,
  timestamp = function()
    return "20260624-120001"
  end,
})
assert(failed_generated_screenshot_ok == false, "screenshot should report terminal failures")
assert(failed_generated_screenshot_path:match("%.png$"), "failed generated screenshots should still return the attempted path")
browser.current_title = original_current_title
browser.current_url = original_current_url

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

local submitted_focused = false
terminal.submit_focused = function()
  submitted_focused = true
  return true
end
assert(browser.submit_focused() == true, "submit_focused should delegate to terminal")
assert(submitted_focused == true, "submit_focused should call terminal.submit_focused")

local page_scroll_direction = nil
local page_scroll_fraction = nil
terminal.page_scroll = function(direction, opts)
  page_scroll_direction = direction
  page_scroll_fraction = opts and opts.fraction or nil
  return true
end
assert(browser.page_scroll(1) == true, "page_scroll should delegate to terminal")
assert(page_scroll_direction == 1, "page_scroll should pass an explicit direction")
assert(browser.page_down() == true, "page_down should delegate to terminal page scroll")
assert(page_scroll_direction == 1, "page_down should request forward page scroll")
assert(browser.page_up() == true, "page_up should delegate to terminal page scroll")
assert(page_scroll_direction == -1, "page_up should request backward page scroll")
assert(browser.half_page_down() == true, "half_page_down should delegate to terminal page scroll")
assert(page_scroll_direction == 1, "half_page_down should request forward scroll")
assert(page_scroll_fraction == 0.5, "half_page_down should request half viewport")
assert(browser.half_page_up() == true, "half_page_up should delegate to terminal page scroll")
assert(page_scroll_direction == -1, "half_page_up should request backward scroll")
assert(page_scroll_fraction == 0.5, "half_page_up should request half viewport")

local scroll_top_called = false
terminal.scroll_top = function()
  scroll_top_called = true
  return "top"
end
assert(browser.scroll_top() == "top", "scroll_top should delegate to terminal")
assert(scroll_top_called == true, "scroll_top should call terminal.scroll_top")

local scroll_bottom_called = false
terminal.scroll_bottom = function()
  scroll_bottom_called = true
  return "bottom"
end
assert(browser.scroll_bottom() == "bottom", "scroll_bottom should delegate to terminal")
assert(scroll_bottom_called == true, "scroll_bottom should call terminal.scroll_bottom")

local zoom_calls = {}
terminal.zoom_in = function()
  table.insert(zoom_calls, "in")
  return "zoom-in"
end
terminal.zoom_out = function()
  table.insert(zoom_calls, "out")
  return "zoom-out"
end
terminal.zoom_reset = function()
  table.insert(zoom_calls, "reset")
  return "zoom-reset"
end
assert(browser.zoom_in() == "zoom-in", "zoom_in should delegate to terminal")
assert(browser.zoom_out() == "zoom-out", "zoom_out should delegate to terminal")
assert(browser.zoom_reset() == "zoom-reset", "zoom_reset should delegate to terminal")
assert(table.concat(zoom_calls, ",") == "in,out,reset", "zoom APIs should call terminal zoom methods")
terminal.zoom_in = original_terminal_zoom_in
terminal.zoom_out = original_terminal_zoom_out
terminal.zoom_reset = original_terminal_zoom_reset

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
  return { { id = 2, hint_label = "s" } }
end
selected_hint = nil
local select_prompts = {}
local select_responses = { "s", "Canada" }
terminal.select_hint = function(label, choice)
  selected_hint = {
    label = label,
    choice = choice,
  }
  return true
end
assert(browser.select_hint_mode(function(prompt)
  table.insert(select_prompts, prompt)
  return table.remove(select_responses, 1)
end) == true, "select_hint_mode should select the prompted option")
assert(
  table.concat(select_prompts, "|") == "nvim-browser hint: |nvim-browser option: ",
  "select_hint_mode should prompt for hint then option"
)
assert(selected_hint.label == "s", "select_hint_mode should pass the prompted hint label")
assert(selected_hint.choice == "Canada", "select_hint_mode should pass the prompted option choice")

browser.hints = function()
  return { { id = 9, hint_label = "u", kind = "file" } }
end
uploaded_hint = nil
local upload_prompts = {}
local upload_responses = { "u", "/tmp/example.txt" }
terminal.upload_hint = function(label, paths)
  uploaded_hint = {
    label = label,
    paths = paths,
  }
  return true
end
assert(browser.upload_hint_mode(function(prompt)
  table.insert(upload_prompts, prompt)
  return table.remove(upload_responses, 1)
end) == true, "upload_hint_mode should upload the prompted file")
assert(
  table.concat(upload_prompts, "|") == "nvim-browser hint: |nvim-browser file: ",
  "upload_hint_mode should prompt for hint then file path"
)
assert(uploaded_hint.label == "u", "upload_hint_mode should pass the prompted hint label")
assert(uploaded_hint.paths[1] == "/tmp/example.txt", "upload_hint_mode should pass the prompted file path")

browser.hints = function()
  return {
    {
      id = 8,
      hint_label = "s",
      kind = "select",
      label = "Country",
      options = {
        { value = "jp", label = "Japan", disabled = false, selected = false },
        { value = "ca", label = "Canada", disabled = false, selected = true },
        { value = "xx", label = "Disabled", disabled = true, selected = false },
      },
    },
  }
end
selected_hint = nil
local picker_prompts = {}
local picker_items = {}
assert(browser.select_hint_mode({
  select = function(items, opts, on_choice)
    table.insert(picker_prompts, opts.prompt)
    table.insert(picker_items, items)
    if opts.prompt == "nvim-browser hint: " then
      on_choice(items[1])
    else
      on_choice(items[2])
    end
  end,
}) == true, "select_hint_mode should use option pickers when select metadata exists")
assert(table.concat(picker_prompts, "|") == "nvim-browser hint: |nvim-browser option: ", "select_hint_mode should picker-select hint then option")
assert(#picker_items[2] == 2, "select_hint_mode should omit disabled options from the option picker")
assert(selected_hint.label == "s", "select_hint_mode should select the chosen hint label")
assert(selected_hint.choice == "ca", "select_hint_mode should submit the chosen option value")

selected_hint = nil
assert(browser.select_hint_mode({
  select = function(_, opts, on_choice)
    if opts.prompt == "nvim-browser hint: " then
      on_choice(nil)
    end
  end,
}) == false, "select_hint_mode should cancel when the hint picker is cancelled")
assert(selected_hint == nil, "select_hint_mode hint cancellation should not send a backend request")

assert(browser.select_hint_mode({
  select = function(items, opts, on_choice)
    if opts.prompt == "nvim-browser hint: " then
      on_choice(items[1])
    else
      on_choice(nil)
    end
  end,
}) == false, "select_hint_mode should cancel when the option picker is cancelled")
assert(selected_hint == nil, "select_hint_mode option cancellation should not send a backend request")

browser.hints = function()
  return { { id = 3, hint_label = "c" } }
end
toggled_hint = nil
local toggle_prompts = {}
local toggle_responses = { "c" }
terminal.toggle_hint = function(label)
  toggled_hint = label
  return true
end
assert(browser.toggle_hint_mode(function(prompt)
  table.insert(toggle_prompts, prompt)
  return table.remove(toggle_responses, 1)
end) == true, "toggle_hint_mode should toggle the prompted checkbox/radio")
assert(table.concat(toggle_prompts, "|") == "nvim-browser hint: ", "toggle_hint_mode should prompt for hint")
assert(toggled_hint == "c", "toggle_hint_mode should pass the prompted hint label")

browser.hints = function()
  return { { id = 4, hint_label = "i" } }
end
focused_hint = nil
local focus_prompts = {}
local focus_responses = { "i" }
terminal.focus_hint = function(label)
  focused_hint = label
  return true
end
assert(browser.focus_hint_mode(function(prompt)
  table.insert(focus_prompts, prompt)
  return table.remove(focus_responses, 1)
end) == true, "focus_hint_mode should focus the prompted hint")
assert(table.concat(focus_prompts, "|") == "nvim-browser hint: ", "focus_hint_mode should prompt for hint")
assert(focused_hint == "i", "focus_hint_mode should pass the prompted hint label")

browser.hints = function()
  return {}
end
assert(browser.type_hint_mode(function()
  error("input should not be called without hints")
end) == false, "type_hint_mode should return false without active hints")
assert(browser.select_hint_mode(function()
  error("input should not be called without hints")
end) == false, "select_hint_mode should return false without active hints")
assert(browser.upload_hint_mode(function()
  error("input should not be called without hints")
end) == false, "upload_hint_mode should return false without active hints")
assert(browser.toggle_hint_mode(function()
  error("input should not be called without hints")
end) == false, "toggle_hint_mode should return false without active hints")
assert(browser.focus_hint_mode(function()
  error("input should not be called without hints")
end) == false, "focus_hint_mode should return false without active hints")

browser.hints = function()
  return { { id = 2, hint_label = "s" } }
end
assert(browser.type_hint_mode(function()
  return ""
end) == false, "type_hint_mode should cancel on empty hint label")
assert(browser.select_hint_mode(function()
  return ""
end) == false, "select_hint_mode should cancel on empty hint label")
assert(browser.upload_hint_mode(function()
  return ""
end) == false, "upload_hint_mode should cancel on empty hint label")
assert(browser.toggle_hint_mode(function()
  return ""
end) == false, "toggle_hint_mode should cancel on empty hint label")
assert(browser.focus_hint_mode(function()
  return ""
end) == false, "focus_hint_mode should cancel on empty hint label")

local empty_text_responses = { "s", "" }
assert(browser.type_hint_mode(function()
  return table.remove(empty_text_responses, 1)
end) == false, "type_hint_mode should cancel on empty text")

local empty_choice_responses = { "s", "" }
assert(browser.select_hint_mode(function()
  return table.remove(empty_choice_responses, 1)
end) == false, "select_hint_mode should cancel on empty option choice")

local empty_path_responses = { "u", "" }
assert(browser.upload_hint_mode(function()
  return table.remove(empty_path_responses, 1)
end) == false, "upload_hint_mode should cancel on empty file path")

terminal.type_hint = function()
  return false
end
assert(browser.type_hint("s", "hello") == false, "type_hint should propagate terminal failure")
terminal.select_hint = function()
  return false
end
browser.hints = function()
  return { { id = 2, hint_label = "s" } }
end
local select_fallback_errors = {}
local failed_choice_responses = { "s", "Canada" }
assert(browser.select_hint_mode(function()
  return table.remove(failed_choice_responses, 1)
end, {
  on_error = function(kind)
    table.insert(select_fallback_errors, kind)
  end,
}) == false, "select_hint_mode typed fallback should propagate terminal failure")
assert(select_fallback_errors[1] == "action_failed", "select_hint_mode typed fallback failures should call on_error")
assert(browser.select_hint("s", "Canada") == false, "select_hint should propagate terminal failure")
terminal.upload_hint = function()
  return false
end
assert(browser.upload_hint("u", { "/tmp/example.txt" }) == false, "upload_hint should propagate terminal failure")
terminal.toggle_hint = function()
  return false
end
assert(browser.toggle_hint("c") == false, "toggle_hint should propagate terminal failure")
terminal.focus_hint = function()
  return false
end
assert(browser.focus_hint("i") == false, "focus_hint should propagate terminal failure")

browser.click_hint = original_click_hint
terminal.right_click_point = original_terminal_right_click_point
terminal.right_click_here = original_terminal_right_click_here
terminal.right_click_mouse = original_terminal_right_click_mouse
terminal.right_click_hint = original_terminal_right_click_hint
browser.follow_hint = original_follow_hint
browser.input_text = original_input_text
browser.press_key = original_press_key
terminal.follow_hint = original_terminal_follow_hint
terminal.click_mouse = original_terminal_click_mouse
terminal.wheel_point = original_terminal_wheel_point
terminal.wheel_mouse = original_terminal_wheel_mouse
terminal.type_hint = original_terminal_type_hint
terminal.select_hint = original_terminal_select_hint
terminal.upload_hint = original_terminal_upload_hint
terminal.toggle_hint = original_terminal_toggle_hint
terminal.hover_point = original_terminal_hover_point
terminal.hover_here = original_terminal_hover_here
terminal.hover_hint = original_terminal_hover_hint
terminal.focus_hint = original_terminal_focus_hint
terminal.type_point = original_terminal_type_point
terminal.type_here = original_terminal_type_here
terminal.stop = original_terminal_stop
terminal.input_text = original_terminal_input_text
terminal.press_key = original_terminal_press_key
terminal.submit_focused = original_terminal_submit_focused
terminal.start_text_mode = original_terminal_start_text_mode
terminal.page_scroll = original_terminal_page_scroll
terminal.select_region = original_terminal_select_region
terminal.yank_selection = original_terminal_yank_selection
terminal.yank_region = original_terminal_yank_region
terminal.screenshot = original_terminal_screenshot
terminal.yank_current_url = original_terminal_yank_current_url
terminal.yank_hint_url = original_terminal_yank_hint_url
terminal.find_text = original_terminal_find_text
terminal.find_next = original_terminal_find_next
terminal.find_previous = original_terminal_find_previous

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
  browser.record_history(target)
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
