local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local browser = require("nvim-browser")
local keymaps = require("nvim-browser.keymaps")
local terminal = require("nvim-browser.terminal")

browser.setup({ session = { persist = false } })

assert(type(browser.click_point) == "function", "click_point API should exist")
assert(type(browser.click_hint) == "function", "click_hint API should exist")
assert(type(browser.right_click_point) == "function", "right_click_point API should exist")
assert(type(browser.right_click_here) == "function", "right_click_here API should exist")
assert(type(browser.double_click_here) == "function", "double_click_here API should exist")
assert(type(browser.double_click_mouse) == "function", "double_click_mouse API should exist")
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
assert(type(browser.jump_hint) == "function", "jump_hint API should exist")
assert(type(browser.jump_hint_mode) == "function", "jump_hint_mode API should exist")
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
assert(type(browser.yank_point_url_here) == "function", "cursor URL yank API should exist")
assert(type(browser.follow_point_url_here) == "function", "cursor link follow API should exist")
assert(type(browser.point_info_here) == "function", "cursor point info API should exist")
assert(type(browser.yank_page_text) == "function", "page text yank API should exist")
assert(type(browser.screenshot) == "function", "active browser screenshot API should exist")
assert(type(browser.downloads) == "function", "download history API should exist")
assert(type(browser.open_download) == "function", "open download API should exist")
assert(type(browser.dialogs) == "function", "dialog history API should exist")
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
assert(type(browser.smoke) == "function", "smoke API should exist")
assert(type(browser.calibrate) == "function", "calibrate API should exist")
assert(type(browser.calibrate_here) == "function", "guided calibration API should exist")
assert(type(browser.page_metrics) == "function", "page_metrics API should exist")
assert(type(browser.page_scroll) == "function", "page_scroll API should exist")
assert(type(browser.page_down) == "function", "page_down API should exist")
assert(type(browser.page_up) == "function", "page_up API should exist")
assert(type(browser.scroll_top) == "function", "scroll_top API should exist")
assert(type(browser.scroll_bottom) == "function", "scroll_bottom API should exist")
assert(type(browser.half_page_down) == "function", "half_page_down API should exist")
assert(type(browser.half_page_up) == "function", "half_page_up API should exist")
assert(type(browser.zoom_in) == "function", "zoom_in API should exist")
assert(type(browser.zoom) == "function", "zoom API should exist")
assert(type(browser.zoom_out) == "function", "zoom_out API should exist")
assert(type(browser.zoom_reset) == "function", "zoom_reset API should exist")
assert(type(browser.zoom_scale) == "function", "zoom_scale API should exist")
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
_G.nvim_browser_cursor_target_image = _G.nvim_browser_cursor_target_dir .. "/pixel.png"
vim.fn.writefile({ "not really a png" }, _G.nvim_browser_cursor_target_image)
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
  "Image " .. _G.nvim_browser_cursor_target_image,
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
vim.api.nvim_win_set_cursor(0, { 9, 8 })
assert(browser.resolve_cursor_target() == _G.nvim_browser_cursor_target_image, "cursor resolver should read local raster image paths")
vim.api.nvim_win_set_cursor(0, { 10, 1 })
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
_G.nvim_browser_opened_under_cursor = nil
_G.nvim_browser_navigated_under_cursor = nil
vim.api.nvim_win_set_cursor(0, { 9, 8 })
assert(browser.open_under_cursor() == true, "open_under_cursor should open active-session raster images through the preview wrapper")
assert(_G.nvim_browser_opened_under_cursor == _G.nvim_browser_cursor_target_image, "open_under_cursor should route active raster images through open")
assert(_G.nvim_browser_navigated_under_cursor == nil, "open_under_cursor should not direct-navigate active raster images")
browser.open = _G.nvim_browser_original_open_under_cursor_open
browser.navigate = _G.nvim_browser_original_open_under_cursor_navigate
terminal.state = _G.nvim_browser_original_terminal_state_for_cursor

_G.nvim_browser_original_terminal_yank_page_text = terminal.yank_page_text
_G.nvim_browser_yanked_page_text_register = nil
terminal.yank_page_text = function(register)
  _G.nvim_browser_yanked_page_text_register = register
  return register ~= "!"
end
assert(browser.yank_page_text() == true, "page text yank API should delegate with the unnamed register by default")
assert(_G.nvim_browser_yanked_page_text_register == '"', "page text yank API should default to the unnamed register")
assert(browser.yank_page_text("+") == true, "page text yank API should pass explicit registers")
assert(_G.nvim_browser_yanked_page_text_register == "+", "page text yank API should preserve explicit registers")
assert(browser.yank_page_text("!") == false, "page text yank API should propagate terminal failures")
terminal.yank_page_text = _G.nvim_browser_original_terminal_yank_page_text

assert(type(browser.record_history) == "function", "history recorder API should exist")
assert(type(browser.history) == "function", "history API should exist")
assert(type(browser.history_urls) == "function", "history URL API should exist")
assert(type(browser.pick_history) == "function", "history picker API should exist")
assert(type(browser.bookmark_current) == "function", "bookmark API should exist")
assert(type(browser.bookmarks) == "function", "bookmarks API should exist")
assert(type(browser.pick_bookmark) == "function", "bookmark picker API should exist")
assert(type(browser.clear_bookmarks) == "function", "bookmark clear API should exist")
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

_G.nvim_browser_run_bookmark_api_tests = function()
  browser.clear_bookmarks()
  _G.nvim_browser_original_current_url_for_bookmarks = browser.current_url
  _G.nvim_browser_original_current_title_for_bookmarks = browser.current_title
  browser.current_url = function()
    return "https://example.com/docs"
  end
  browser.current_title = function()
    return "Docs"
  end
  assert(browser.bookmark_current() == true, "bookmark_current should save the active browser URL")
  browser.current_title = function()
    return "Docs Updated"
  end
  assert(browser.bookmark_current() == true, "bookmark_current should update duplicate bookmark titles")
  browser.current_url = function()
    return "file:///tmp/local-preview.html"
  end
  browser.current_title = function()
    return "Local Preview"
  end
  assert(browser.bookmark_current() == true, "bookmark_current should allow local browser preview URLs")
  local bookmarks = browser.bookmarks()
  assert(#bookmarks == 2, "bookmarks should de-duplicate URLs")
  assert(bookmarks[1].url == "file:///tmp/local-preview.html", "bookmarks should keep newest entries first")
  assert(bookmarks[1].title == "Local Preview", "bookmarks should preserve bookmark titles")
  assert(bookmarks[2].url == "https://example.com/docs", "bookmarks should keep older unique entries")
  assert(bookmarks[2].title == "Docs Updated", "bookmarks should update duplicate URL titles")
  bookmarks[1].url = "mutated"
  assert(browser.bookmarks()[1].url == "file:///tmp/local-preview.html", "bookmarks should return a copy")

  local picked_bookmark_items = nil
  local picked_bookmark_prompt = nil
  local picked_bookmark_label = nil
  local addressed_bookmark = nil
  local original_address_for_bookmarks = browser.address
  browser.address = function(target)
    addressed_bookmark = target
    return true
  end
  assert(browser.pick_bookmark({
    select = function(items, opts, on_choice)
      picked_bookmark_items = items
      picked_bookmark_prompt = opts.prompt
      picked_bookmark_label = opts.format_item(items[1])
      on_choice(items[1])
    end,
  }) == true, "bookmark picker should open when bookmarks exist")
  assert(#picked_bookmark_items == 2, "bookmark picker should offer saved pages")
  assert(picked_bookmark_prompt == "nvim-browser bookmarks: ", "bookmark picker should use a bookmark prompt")
  assert(picked_bookmark_label:find("Local Preview", 1, true), "bookmark picker should format page titles")
  assert(picked_bookmark_label:find("file:///tmp/local-preview.html", 1, true), "bookmark picker should format page URLs")
  assert(addressed_bookmark == "file:///tmp/local-preview.html", "bookmark picker should navigate to the selected URL")

  addressed_bookmark = nil
  assert(browser.pick_bookmark({
    select = function(_, _, on_choice)
      on_choice(nil)
    end,
  }) == false, "bookmark picker should return false when canceled")
  assert(addressed_bookmark == nil, "bookmark picker should not navigate when canceled")
  browser.address = original_address_for_bookmarks
  browser.current_url = function()
    return nil
  end
  assert(browser.bookmark_current() == false, "bookmark_current should reject missing active URLs")
  browser.clear_bookmarks()
  assert(browser.pick_bookmark({
    select = function()
      error("bookmark picker should not open without entries")
    end,
  }) == false, "bookmark picker should return false without entries")
  for index = 1, 55 do
    browser.current_url = function()
      return "https://bookmark.example/page-" .. index
    end
    browser.current_title = function()
      return "Bookmark " .. index
    end
    browser.bookmark_current()
  end
  local limited_bookmarks = browser.bookmarks()
  assert(#limited_bookmarks == 50, "bookmarks should keep a bounded number of recent pages")
  assert(limited_bookmarks[1].url == "https://bookmark.example/page-55", "bookmark limit should keep the newest page first")
  assert(limited_bookmarks[#limited_bookmarks].url == "https://bookmark.example/page-6", "bookmark limit should drop the oldest pages")
  browser.clear_bookmarks()
  browser.current_url = _G.nvim_browser_original_current_url_for_bookmarks
  browser.current_title = _G.nvim_browser_original_current_title_for_bookmarks
end

_G.nvim_browser_run_bookmark_api_tests()

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
    bookmarks = {
      { url = "https://bookmark.example/older", title = "Older Updated" },
      { url = "file:///tmp/bookmark-local.html", title = "Local" },
      { url = "https://bookmark.example/older", title = "Older" },
      { url = "" },
      { title = "missing url" },
    },
  }),
}, session_path)
browser.setup({ session = { persist = true, path = session_path, history_limit = 2 } })
local persisted_history = browser.history()
_G.nvim_browser_persisted_bookmarks = browser.bookmarks()
assert(browser.last_target() == "https://persisted.example/last", "setup should load persisted last target")
assert(#persisted_history == 2, "setup should load and cap persisted history")
assert(persisted_history[1].url == "https://persisted.example/older", "loaded history should de-duplicate newest occurrences")
assert(persisted_history[1].title == "Older Updated", "loaded history should keep the newest duplicate title")
assert(persisted_history[2].url == "https://persisted.example/latest", "loaded history should keep older unique entries")
persisted_history[1].url = "mutated"
assert(browser.history()[1].url == "https://persisted.example/older", "loaded history should still return defensive copies")
assert(#_G.nvim_browser_persisted_bookmarks == 2, "setup should load and cap persisted bookmarks")
assert(_G.nvim_browser_persisted_bookmarks[1].url == "https://bookmark.example/older", "loaded bookmarks should de-duplicate newest occurrences")
assert(_G.nvim_browser_persisted_bookmarks[1].title == "Older Updated", "loaded bookmarks should keep the newest duplicate title")
assert(_G.nvim_browser_persisted_bookmarks[2].url == "file:///tmp/bookmark-local.html", "loaded bookmarks should preserve local preview URLs")
_G.nvim_browser_persisted_bookmarks[1].url = "mutated"
assert(browser.bookmarks()[1].url == "https://bookmark.example/older", "loaded bookmarks should return defensive copies")

browser.record_history("https://persisted.example/new", "New")
local saved_session = vim.fn.json_decode(table.concat(vim.fn.readfile(session_path), "\n"))
assert(saved_session.version == 1, "record_history should save a versioned session file")
assert(saved_session.last_target == "https://persisted.example/new", "record_history should save the newest URL as last target")
assert(#saved_session.history == 2, "record_history should save capped history")
assert(saved_session.history[1].url == "https://persisted.example/new", "record_history should save newest entries")
assert(#saved_session.bookmarks == 2, "record_history should preserve persisted bookmarks in session saves")

browser.current_url = function()
  return "https://bookmark.example/new"
end
browser.current_title = function()
  return "New Bookmark"
end
assert(browser.bookmark_current() == true, "bookmark_current should save into the session file")
saved_session = vim.fn.json_decode(table.concat(vim.fn.readfile(session_path), "\n"))
assert(saved_session.bookmarks[1].url == "https://bookmark.example/new", "bookmark_current should save newest bookmarks")
assert(saved_session.bookmarks[1].title == "New Bookmark", "bookmark_current should save bookmark titles")
browser.current_url = _G.nvim_browser_original_current_url_for_bookmarks
browser.current_title = _G.nvim_browser_original_current_title_for_bookmarks

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

_G.nvim_browser_original_terminal_downloads_for_session = terminal.downloads
terminal.downloads = function()
  return {}
end
_G.nvim_browser_download_session_path = session_dir .. "/downloads-session.json"
vim.fn.writefile({
  vim.fn.json_encode({
    version = 1,
    last_target = "https://persisted.example/downloads",
    history = {
      { url = "https://persisted.example/downloads", title = "Downloads" },
    },
    downloads = {
      {
        path = "/tmp/downloads/old-report.pdf",
        suggested_filename = "old-report.pdf",
        status = "completed",
      },
      {
        path = "/tmp/downloads/dropped-by-limit.pdf",
        suggested_filename = "dropped-by-limit.pdf",
        status = "completed",
      },
      {
        path = "/tmp/downloads/old-report.pdf",
        suggested_filename = "old-report-renamed.pdf",
        status = "completed",
      },
      {
        path = "/tmp/downloads/archive.zip",
        suggested_filename = "archive.zip",
        status = "completed",
      },
      {
        path = "",
        suggested_filename = "missing-path.pdf",
        status = "completed",
      },
      {
        path = "/tmp/downloads/partial.tmp",
        suggested_filename = "partial.tmp",
        status = "in_progress",
      },
      {
        suggested_filename = "malformed.pdf",
        status = "completed",
      },
    },
  }),
}, _G.nvim_browser_download_session_path)
browser.setup({ session = { persist = true, path = _G.nvim_browser_download_session_path, history_limit = 3 } })
_G.nvim_browser_persisted_downloads = browser.downloads()
assert(#_G.nvim_browser_persisted_downloads == 3, "setup should load bounded usable completed downloads")
assert(
  _G.nvim_browser_persisted_downloads[1].path == "/tmp/downloads/dropped-by-limit.pdf",
  "setup should preserve persisted completed download paths"
)
assert(
  _G.nvim_browser_persisted_downloads[2].path == "/tmp/downloads/old-report.pdf"
    and _G.nvim_browser_persisted_downloads[2].suggested_filename == "old-report-renamed.pdf",
  "setup should de-duplicate persisted download paths using the newest metadata"
)
assert(
  _G.nvim_browser_persisted_downloads[3].path == "/tmp/downloads/archive.zip",
  "setup should preserve persisted completed download order"
)
_G.nvim_browser_persisted_downloads[1].path = "/tmp/downloads/mutated.pdf"
assert(
  browser.downloads()[1].path == "/tmp/downloads/dropped-by-limit.pdf",
  "persisted downloads should be returned as defensive copies"
)

terminal._test.apply_serve_response({
  id = 12301,
  status = "ok",
  download = {
    path = "/tmp/downloads/new-report.pdf",
    suggested_filename = "new-report.pdf",
    status = "completed",
  },
})
_G.nvim_browser_saved_download_session = vim.fn.json_decode(table.concat(vim.fn.readfile(_G.nvim_browser_download_session_path), "\n"))
assert(
  #_G.nvim_browser_saved_download_session.downloads == 3,
  "completed browser downloads should be saved into the bounded session file immediately"
)
assert(
  _G.nvim_browser_saved_download_session.downloads[3].path == "/tmp/downloads/new-report.pdf",
  "saved downloads should append newly completed download paths"
)
_G.nvim_browser_merged_downloads = browser.downloads()
assert(#_G.nvim_browser_merged_downloads == 3, "active and persisted downloads should merge without duplicate paths")
assert(_G.nvim_browser_merged_downloads[1].path == "/tmp/downloads/old-report.pdf", "bounded downloads should drop the oldest entry when saving a new one")
assert(_G.nvim_browser_merged_downloads[2].path == "/tmp/downloads/archive.zip", "merged downloads should retain persisted order")
assert(_G.nvim_browser_merged_downloads[3].path == "/tmp/downloads/new-report.pdf", "merged downloads should include active completed downloads once")

terminal.downloads = function()
  return {}
end
assert(#browser.downloads() == 3, "persisted downloads should remain available after volatile terminal history is cleared")

_G.nvim_browser_persist_disabled_path = session_dir .. "/downloads-disabled.json"
vim.fn.writefile({
  vim.fn.json_encode({
    version = 1,
    bookmarks = {
      { url = "https://bookmark-disabled.example", title = "Disabled Bookmark" },
    },
    downloads = {
      {
        path = "/tmp/downloads/persist-disabled.pdf",
        suggested_filename = "persist-disabled.pdf",
        status = "completed",
      },
    },
  }),
}, _G.nvim_browser_persist_disabled_path)
browser.setup({ session = { persist = false, path = _G.nvim_browser_persist_disabled_path, history_limit = 3 } })
assert(#browser.bookmarks() == 0, "session.persist=false should ignore persisted bookmarks")
assert(#browser.downloads() == 0, "session.persist=false should ignore persisted download history")
browser.current_url = function()
  return "https://bookmark-disabled.example/new"
end
browser.current_title = function()
  return "Disabled New Bookmark"
end
assert(browser.bookmark_current() == true, "bookmark_current should still work in memory when session.persist=false")
assert(browser.bookmarks()[1].url == "https://bookmark-disabled.example/new", "session.persist=false should keep new bookmarks in memory")
terminal._test.apply_serve_response({
  id = 12302,
  status = "ok",
  download = {
    path = "/tmp/downloads/not-persisted.pdf",
    suggested_filename = "not-persisted.pdf",
    status = "completed",
  },
})
_G.nvim_browser_disabled_session = vim.fn.json_decode(table.concat(vim.fn.readfile(_G.nvim_browser_persist_disabled_path), "\n"))
assert(#_G.nvim_browser_disabled_session.bookmarks == 1, "session.persist=false should not write bookmarks")
assert(
  _G.nvim_browser_disabled_session.bookmarks[1].url == "https://bookmark-disabled.example",
  "session.persist=false should leave persisted bookmarks unchanged"
)
assert(#_G.nvim_browser_disabled_session.downloads == 1, "session.persist=false should not write completed downloads")
browser.current_url = _G.nvim_browser_original_current_url_for_bookmarks
browser.current_title = _G.nvim_browser_original_current_title_for_bookmarks
terminal.downloads = _G.nvim_browser_original_terminal_downloads_for_session
browser.setup({ session = { persist = true, path = session_path, history_limit = 2 } })

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
    open = browser.open,
    preview = browser.preview,
    inspect = browser.inspect,
    address = browser.address,
    reload = browser.reload,
    resume = browser.resume,
    last_target = browser.last_target,
    history = browser.history,
    bookmarks = browser.bookmarks,
    bookmark_current = browser.bookmark_current,
    pick_bookmark = browser.pick_bookmark,
    back = browser.back,
    forward = browser.forward,
    find_text = browser.find_text,
    pick_hint = browser.pick_hint,
    start_text_mode = browser.start_text_mode,
    open_download = browser.open_download,
    screenshot = browser.screenshot,
    reader = browser.reader,
    status = browser.status,
    page_metrics = browser.page_metrics,
    browser_history = browser.browser_history,
    focused_element = browser.focused_element,
    runtime_metadata = browser.runtime_metadata,
    current_url = browser.current_url,
    current_title = browser.current_title,
    status_error = browser.status_error,
    doctor = browser.doctor,
    close = browser.close,
    zoom_in = browser.zoom_in,
    zoom_out = browser.zoom_out,
    zoom_reset = browser.zoom_reset,
    submit_focused = browser.submit_focused,
    click_here = browser.click_here,
    double_click_here = browser.double_click_here,
    right_click_here = browser.right_click_here,
    hover_here = browser.hover_here,
    follow_point_url_here = browser.follow_point_url_here,
    wheel_here = browser.wheel_here,
    type_here = browser.type_here,
  }
  browser.open = function(target)
    table.insert(action_calls, "open:" .. tostring(target))
    return true
  end
  browser.preview = function()
    table.insert(action_calls, "preview")
    return true
  end
  browser.inspect = function(target)
    table.insert(action_calls, "inspect:" .. tostring(target))
    return true
  end
  browser.address = function()
    table.insert(action_calls, "address")
    return true
  end
  browser.reload = function()
    table.insert(action_calls, "reload")
    return true
  end
  browser.resume = function()
    table.insert(action_calls, "resume")
    return true
  end
  browser.last_target = function()
    return "https://last.example"
  end
  browser.bookmarks = function()
    return { { url = "https://bookmark.example", title = "Bookmark" } }
  end
  browser.bookmark_current = function()
    table.insert(action_calls, "bookmark_current")
    return true
  end
  browser.pick_bookmark = function()
    table.insert(action_calls, "pick_bookmark")
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
  browser.submit_focused = function()
    table.insert(action_calls, "submit_focused")
    return true
  end
  browser.open_download = function(index)
    table.insert(action_calls, "open_download:" .. tostring(index))
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
  browser.browser_history = function()
    return { can_go_back = true, can_go_forward = false }
  end
  browser.zoom_scale = function()
    return 1.25
  end
  browser.focused_element = function()
    return { kind = "input", label = "Search box" }
  end
  browser.latest_dialog = function()
    return { kind = "confirm", message = "continue?", action = "dismissed" }
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
  browser.zoom_in = function()
    table.insert(action_calls, "zoom_in")
    return true
  end
  browser.zoom_out = function()
    table.insert(action_calls, "zoom_out")
    return true
  end
  browser.zoom_reset = function()
    table.insert(action_calls, "zoom_reset")
    return true
  end
  browser.click_here = function()
    table.insert(action_calls, "click_here")
    return true
  end
  browser.double_click_here = function()
    table.insert(action_calls, "double_click_here")
    return true
  end
  browser.right_click_here = function()
    table.insert(action_calls, "right_click_here")
    return true
  end
  browser.hover_here = function()
    table.insert(action_calls, "hover_here")
    return true
  end
  browser.follow_point_url_here = function()
    table.insert(action_calls, "follow_point_url_here")
    return true
  end
  browser.wheel_here = function(delta_y, delta_x)
    table.insert(action_calls, "wheel_here:" .. tostring(delta_y) .. ":" .. tostring(delta_x))
    return true
  end
  browser.type_here = function(text)
    table.insert(action_calls, "type_here:" .. tostring(text))
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
	  assert(#action_items >= 19, "actions should offer the core browser operations")
  assert(action_prompt == "nvim-browser action: ", "actions should use an action picker prompt")
	  assert(first_label == "Open current buffer", "actions should format action labels")
  local labels = {}
  for _, item in ipairs(action_items) do
    labels[item.label] = true
  end
	  for _, label in ipairs({
	    "Open current buffer",
	    "Preview current buffer",
	    "Inspect current buffer",
	    "Resume",
	    "Bookmark page",
	    "Bookmarks",
	    "Address",
	    "Reload",
	    "Back",
	    "Forward",
	    "Find",
	    "Hints",
	    "Text mode",
	    "Click cursor",
	    "Double-click cursor",
	    "Right-click cursor",
	    "Hover cursor",
	    "Follow link at cursor",
	    "Wheel down at cursor",
	    "Wheel up at cursor",
	    "Type at cursor",
	    "Submit focused",
	    "Open download",
	    "Screenshot",
	    "Reader",
	    "Status",
	    "Zoom in",
	    "Zoom out",
	    "Zoom reset",
	    "Doctor",
	    "Close",
	  }) do
	    assert(labels[label] == true, "actions should include " .. label)
	  end
		  assert(action_calls[#action_calls]:match("^open:"), "actions should run the selected action")

	  action_calls = {}
	  local action_history = browser.history
	  browser.last_target = function()
	    return nil
	  end
	  browser.history = function()
	    return {}
	  end
	  assert(browser.actions({
	    select = function(items, _, on_choice)
	      local labels_without_target = {}
	      for _, item in ipairs(items) do
	        labels_without_target[item.label] = true
	      end
	      assert(labels_without_target["Resume"] == nil, "actions should hide Resume without a last target")
	      on_choice(nil)
	    end,
	  }) == true, "actions should still open without a last target")
	  browser.last_target = function()
	    return "https://last.example"
	  end
	  browser.history = action_history

	  action_calls = {}
	  browser.last_target = function()
	    return nil
	  end
	  browser.history = function()
	    return { { url = "https://history.example", title = "History" } }
	  end
	  assert(browser.actions({
	    select = function(items, _, on_choice)
	      local labels_with_history = {}
	      for _, item in ipairs(items) do
	        labels_with_history[item.label] = true
	      end
	      assert(labels_with_history["Resume"] == true, "actions should show Resume when history can be resumed")
	      on_choice(nil)
	    end,
	  }) == true, "actions should expose Resume when history exists")
	  browser.last_target = function()
	    return "https://last.example"
	  end
	  browser.history = action_history

	  action_calls = {}
	  local original_buf_get_name = vim.api.nvim_buf_get_name
	  vim.api.nvim_buf_get_name = function()
	    return "nvim-browser://Example"
	  end
	  local action_current_url = browser.current_url
	  browser.current_url = function()
	    return "https://current.example"
	  end
	  assert(browser.actions({
	    select = function(items, _, on_choice)
	      on_choice(items[1])
	    end,
	  }) == true, "Open current action should run from preview buffers")
	  vim.api.nvim_buf_get_name = original_buf_get_name
	  assert(
	    action_calls[#action_calls] == "open:https://current.example",
	    "Open current action should target the current browser URL from preview buffers"
	  )
	  browser.current_url = action_current_url

	  action_calls = {}
	  assert(browser.actions({
	    select = function(items, _, on_choice)
	      for _, item in ipairs(items) do
	        if item.label == "Preview current buffer" then
	          on_choice(item)
	          return
	        end
	      end
	    end,
	  }) == true, "Preview action should run")
	  assert(action_calls[#action_calls] == "preview", "Preview action should call preview")

	  action_calls = {}
	  assert(browser.actions({
	    select = function(items, _, on_choice)
	      for _, item in ipairs(items) do
	        if item.label == "Inspect current buffer" then
	          on_choice(item)
	          return
	        end
	      end
	    end,
	  }) == true, "Inspect action should run")
	  assert(action_calls[#action_calls]:match("^inspect:"), "Inspect action should call inspect with a target")

	  action_calls = {}
	  assert(browser.actions({
	    select = function(items, _, on_choice)
	      for _, item in ipairs(items) do
	        if item.label == "Submit focused" then
	          on_choice(item)
	          return
	        end
	      end
	    end,
	  }) == true, "Submit focused action should run")
	  assert(action_calls[#action_calls] == "submit_focused", "Submit focused action should call submit_focused")

	  action_calls = {}
	  assert(browser.actions({
	    select = function(items, _, on_choice)
	      for _, item in ipairs(items) do
	        if item.label == "Click cursor" then
	          on_choice(item)
	          return
	        end
	      end
	    end,
	  }) == true, "Click cursor action should run")
	  assert(action_calls[#action_calls] == "click_here", "Click cursor action should call click_here")

	  action_calls = {}
	  assert(browser.actions({
	    select = function(items, _, on_choice)
	      for _, item in ipairs(items) do
	        if item.label == "Double-click cursor" then
	          on_choice(item)
	          return
	        end
	      end
	    end,
	  }) == true, "Double-click cursor action should run")
	  assert(action_calls[#action_calls] == "double_click_here", "Double-click cursor action should call double_click_here")

	  action_calls = {}
	  assert(browser.actions({
	    select = function(items, _, on_choice)
	      for _, item in ipairs(items) do
	        if item.label == "Right-click cursor" then
	          on_choice(item)
	          return
	        end
	      end
	    end,
	  }) == true, "Right-click cursor action should run")
	  assert(action_calls[#action_calls] == "right_click_here", "Right-click cursor action should call right_click_here")

	  action_calls = {}
	  assert(browser.actions({
	    select = function(items, _, on_choice)
	      for _, item in ipairs(items) do
	        if item.label == "Hover cursor" then
	          on_choice(item)
	          return
	        end
	      end
	    end,
	  }) == true, "Hover cursor action should run")
	  assert(action_calls[#action_calls] == "hover_here", "Hover cursor action should call hover_here")

	  action_calls = {}
	  assert(browser.actions({
	    select = function(items, _, on_choice)
	      for _, item in ipairs(items) do
	        if item.label == "Wheel down at cursor" then
	          on_choice(item)
	          return
	        end
	      end
	    end,
	  }) == true, "Wheel down cursor action should run")
	  assert(action_calls[#action_calls] == "wheel_here:120:0", "Wheel down cursor action should call wheel_here with a positive delta")

	  action_calls = {}
	  assert(browser.actions({
	    select = function(items, _, on_choice)
	      for _, item in ipairs(items) do
	        if item.label == "Wheel up at cursor" then
	          on_choice(item)
	          return
	        end
	      end
	    end,
	  }) == true, "Wheel up cursor action should run")
	  assert(action_calls[#action_calls] == "wheel_here:-120:0", "Wheel up cursor action should call wheel_here with a negative delta")

	  action_calls = {}
	  assert(browser.actions({
	    select = function(items, _, on_choice)
	      for _, item in ipairs(items) do
	        if item.label == "Type at cursor" then
	          on_choice(item)
	          return
	        end
	      end
	    end,
	    input = function(prompt)
	      assert(prompt == "nvim-browser type at cursor: ", "Type at cursor action should prompt for text")
	      return "typed text"
	    end,
	  }) == true, "Type at cursor action should run")
	  assert(action_calls[#action_calls] == "type_here:typed text", "Type at cursor action should call type_here")

	  action_calls = {}
	  assert(browser.actions({
	    select = function(items, _, on_choice)
	      for _, item in ipairs(items) do
	        if item.label == "Type at cursor" then
	          on_choice(item)
	          return
	        end
	      end
	    end,
	    input = function()
	      return ""
	    end,
	  }) == true, "Type at cursor action should treat empty input as a no-op")
	  assert(#action_calls == 0, "Type at cursor action should not call type_here on empty input")

	  action_calls = {}
	  assert(browser.actions({
	    select = function(items, _, on_choice)
	      for _, item in ipairs(items) do
	        if item.label == "Type at cursor" then
	          on_choice(item)
	          return
	        end
	      end
	    end,
	    input = function()
	      return nil
	    end,
	  }) == true, "Type at cursor action should treat canceled input as a no-op")
	  assert(#action_calls == 0, "Type at cursor action should not call type_here on canceled input")

	  action_calls = {}
	  assert(browser.actions({
	    select = function(items, _, on_choice)
	      for _, item in ipairs(items) do
	        if item.label == "Resume" then
	          on_choice(item)
	          return
	        end
	      end
	    end,
	  }) == true, "Resume action should run")
	  assert(action_calls[#action_calls] == "resume", "Resume action should call resume")

	  action_calls = {}
	  assert(browser.actions({
	    select = function(items, _, on_choice)
	      for _, item in ipairs(items) do
	        if item.label == "Open download" then
	          on_choice(item)
	          return
	        end
	      end
	    end,
	  }) == true, "Open download action should run")
	  assert(action_calls[#action_calls] == "open_download:nil", "Open download action should call open_download")

	  action_calls = {}
	  assert(browser.actions({
	    select = function(items, _, on_choice)
	      for _, item in ipairs(items) do
	        if item.label == "Zoom in" then
	          on_choice(item)
	          return
	        end
	      end
	    end,
	  }) == true, "Zoom in action should run")
	  assert(action_calls[#action_calls] == "zoom_in", "Zoom in action should call zoom_in")

	  action_calls = {}
	  assert(browser.actions({
	    select = function(items, _, on_choice)
	      for _, item in ipairs(items) do
	        if item.label == "Zoom out" then
	          on_choice(item)
	          return
	        end
	      end
	    end,
	  }) == true, "Zoom out action should run")
	  assert(action_calls[#action_calls] == "zoom_out", "Zoom out action should call zoom_out")

	  action_calls = {}
	  assert(browser.actions({
	    select = function(items, _, on_choice)
	      for _, item in ipairs(items) do
	        if item.label == "Zoom reset" then
	          on_choice(item)
	          return
	        end
	      end
	    end,
	  }) == true, "Zoom reset action should run")
	  assert(action_calls[#action_calls] == "zoom_reset", "Zoom reset action should call zoom_reset")

	  action_calls = {}
	  local address_warning = nil
	  assert(browser.actions({
	    select = function(items, _, on_choice)
	      for _, item in ipairs(items) do
	        if item.label == "Address" then
	          on_choice(item)
	          return
	        end
	      end
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
  assert(status_message:find("history=back", 1, true), "Status action should include browser history availability")
  assert(status_message:find("zoom=125%%"), "Status action should include non-default browser zoom")
  assert(status_message:find("focus=input Search box", 1, true), "Status action should include focused element")
  assert(status_message:find("dialog=confirm dismissed: continue?", 1, true), "Status action should include dialog metadata")
  assert(status_message:find("output=kitty", 1, true), "Status action should include runtime output")
  assert(status_message:find("viewport=960x720", 1, true), "Status action should include runtime viewport")
  assert(status_message:find("cells=120x40", 1, true), "Status action should include runtime cells")
  assert(status_message:find("renderer=chromium", 1, true), "Status action should include runtime renderer")
  assert(status_message:find("https://example.com", 1, true), "Status action should include the current URL")
  assert(status_message:find("last error", 1, true), "Status action should include the status error")

  browser.runtime_metadata = function()
    return {
      output = "ansi",
      output_label = "ANSI fallback",
      viewport = { width = 960, height = 720 },
      cells = { columns = 120, rows = 40 },
      renderer = "chromium",
    }
  end
  action_calls = {}
  status_message = nil
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
  }) == true, "Status action should run with fallback runtime metadata")
  assert(status_message:find("output=ANSI fallback", 1, true), "Status action should include fallback runtime output labels")

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
_G.nvim_browser_original_jump_hint_api = browser.jump_hint
local original_type_hint = browser.type_hint
local original_select_hint = browser.select_hint
local original_upload_hint = browser.upload_hint
local original_yank_hint_url = browser.yank_hint_url
local original_terminal_click_point = terminal.click_point
local original_terminal_right_click_point = terminal.right_click_point
local original_terminal_right_click_here = terminal.right_click_here
_G.nvim_browser_original_terminal_double_click_here = terminal.double_click_here
_G.nvim_browser_original_terminal_double_click_mouse = terminal.double_click_mouse
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
_G.nvim_browser_original_terminal_wheel_here = terminal.wheel_here
local original_terminal_type_hint = terminal.type_hint
_G.nvim_browser_original_terminal_jump_hint = terminal.jump_hint
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
original_terminal_downloads = terminal.downloads
local original_terminal_yank_current_url = terminal.yank_current_url
local original_terminal_yank_hint_url = terminal.yank_hint_url
_G.nvim_browser_original_terminal_yank_point_url_here = terminal.yank_point_url_here
_G.nvim_browser_original_terminal_point_info_here = terminal.point_info_here
local original_terminal_find_text = terminal.find_text
local original_terminal_find_next = terminal.find_next
local original_terminal_find_previous = terminal.find_previous
local original_terminal_zoom_in = terminal.zoom_in
_G.nvim_browser_original_terminal_zoom = terminal.zoom
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

_G.nvim_browser_original_terminal_open_for_smoke = terminal.open
_G.nvim_browser_original_terminal_state_for_smoke = terminal.state
_G.nvim_browser_original_terminal_focus_selector_for_smoke = terminal.focus_selector
_G.nvim_browser_original_terminal_input_text_for_smoke = terminal.input_text
_G.nvim_browser_original_terminal_submit_focused_for_smoke = terminal.submit_focused
_G.nvim_browser_original_terminal_click_hint_for_smoke = terminal.click_hint
_G.nvim_browser_original_terminal_click_here_for_smoke = terminal.click_here
_G.nvim_browser_original_terminal_type_here_for_smoke = terminal.type_here
_G.nvim_browser_original_terminal_type_hint_for_smoke = terminal.type_hint
_G.nvim_browser_original_defer_fn_for_smoke = vim.defer_fn
_G.nvim_browser_smoke_opened_command = nil
_G.nvim_browser_smoke_fixture_url = vim.uri_from_fname(root .. "/data/html/smoke.html")
_G.nvim_browser_smoke_fixture_title = "nvim-browser smoke"
_G.nvim_browser_smoke_interaction_text = "nvim-browser interaction"
_G.nvim_browser_smoke_title = _G.nvim_browser_smoke_fixture_title
_G.nvim_browser_smoke_focused = nil
_G.nvim_browser_smoke_calls = {}
_G.nvim_browser_smoke_reader_bufnr = nil
_G.nvim_browser_smoke_winid = vim.api.nvim_get_current_win()
_G.nvim_browser_smoke_preview_lines = {}
for _ = 1, 25 do
  table.insert(_G.nvim_browser_smoke_preview_lines, string.rep(" ", 100))
end
vim.api.nvim_buf_set_lines(0, 0, -1, false, _G.nvim_browser_smoke_preview_lines)
terminal.open = function(command)
  _G.nvim_browser_smoke_opened_command = command
end
terminal.state = function()
  return {
    mode = "serve",
    job_id = 1,
    has_buffer = true,
    current_url = _G.nvim_browser_smoke_fixture_url,
    current_title = _G.nvim_browser_smoke_title,
    status = "ok",
    serve_output = "ansi",
    serve_output_label = "ANSI fallback",
    runtime_metadata = {
      output = "ansi",
      output_label = "ANSI fallback",
      renderer = "chromium-cdp",
      transport = "stdio-jsonl",
      cells = { columns = 80, rows = 20 },
      viewport = { width = 800, height = 400 },
    },
    rendered_frame_geometry = { columns = 80, rows = 20, width = 800, height = 400 },
    rendered_frame_url = _G.nvim_browser_smoke_fixture_url,
    dom_epoch = 1,
    rendered_frame_dom_epoch = 1,
    frame_health = { stale = false, refresh_pending = false },
    focused_element = _G.nvim_browser_smoke_focused,
    reader_bufnr = _G.nvim_browser_smoke_reader_bufnr,
    winid = _G.nvim_browser_smoke_winid,
    element_hints = {
      { id = 1, kind = "input", label = "Smoke input", hint_label = "i", x = 120, y = 160, width = 240, height = 32 },
      { id = 2, kind = "button", label = "Run smoke", hint_label = "s", x = 120, y = 220, width = 240, height = 32 },
    },
  }
end
terminal.focus_selector = function(selector)
  table.insert(_G.nvim_browser_smoke_calls, "focus:" .. tostring(selector))
  if selector == "#nvim-browser-smoke-input" then
    _G.nvim_browser_smoke_focused = {
      kind = "input",
      label = "Smoke input",
      value = "",
      submittable = true,
    }
    return true
  end
  return false
end
terminal.click_here = function()
  table.insert(_G.nvim_browser_smoke_calls, "click_here")
  _G.nvim_browser_smoke_focused = {
    kind = "input",
    label = "Smoke input",
    value = "",
    submittable = true,
  }
  return true
end
terminal.type_here = function(text, opts)
  table.insert(_G.nvim_browser_smoke_calls, "type_here:" .. tostring(text) .. ":" .. tostring(opts ~= nil and opts.submit == true))
  if text == _G.nvim_browser_smoke_interaction_text and opts ~= nil and opts.submit == true then
    _G.nvim_browser_smoke_focused = {
      kind = "input",
      label = "Smoke input",
      value = text,
      submittable = true,
    }
    _G.nvim_browser_smoke_title = "nvim-browser smoke submitted: " .. text
    return true
  end
  return false
end
terminal.type_hint = function(id, text, opts)
  table.insert(_G.nvim_browser_smoke_calls, "type_hint:" .. tostring(id) .. ":" .. tostring(text) .. ":" .. tostring(opts ~= nil and opts.submit == true))
  if tostring(id) == "i" and text == _G.nvim_browser_smoke_interaction_text and opts ~= nil and opts.submit == true then
    _G.nvim_browser_smoke_focused = {
      kind = "input",
      label = "Smoke input",
      value = text,
      submittable = true,
    }
    _G.nvim_browser_smoke_title = "nvim-browser smoke submitted: " .. text
    return true
  end
  return false
end
terminal.input_text = function(text)
  table.insert(_G.nvim_browser_smoke_calls, "input:" .. tostring(text))
  if _G.nvim_browser_smoke_focused ~= nil and text == _G.nvim_browser_smoke_interaction_text then
    _G.nvim_browser_smoke_focused.value = text
    _G.nvim_browser_smoke_title = "nvim-browser smoke submitted: " .. text
    return true
  end
  return false
end
vim.defer_fn = function(callback)
  callback()
end
browser.clear_history()
_G.nvim_browser_last_target_before_smoke = browser.last_target()
_G.nvim_browser_smoke_report = nil
vim.defer_fn = function(callback)
  if
    _G.nvim_browser_smoke_report == nil
    and _G.nvim_browser_smoke_title == "nvim-browser smoke submitted: " .. _G.nvim_browser_smoke_interaction_text
    and _G.nvim_browser_smoke_reader_bufnr == nil
  then
    _G.nvim_browser_smoke_reader_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(_G.nvim_browser_smoke_reader_bufnr, 0, -1, false, {
      "# nvim-browser smoke",
      "",
      "deterministic local browser runtime fixture",
    })
  end
  callback()
end
assert(browser.smoke({ timeout_ms = 1, interval_ms = 1, on_report = function(report)
  _G.nvim_browser_smoke_report = report
end }) == true, "smoke should start through the browser runtime")
assert(_G.nvim_browser_smoke_opened_command ~= nil, "smoke should open the bundled fixture through terminal.open")
assert(_G.nvim_browser_smoke_opened_command[2] == "serve", "smoke should use the persistent serve runtime")
assert(vim.tbl_contains(_G.nvim_browser_smoke_opened_command, "--url"), "smoke should open the fixture as a browser URL")
assert(
  table.concat(_G.nvim_browser_smoke_opened_command, " "):find(vim.uri_from_fname(root .. "/data/html/smoke.html"), 1, true),
  "smoke should target the bundled smoke fixture"
)
assert(#browser.history() == 0, "smoke should not record the fixture in user history")
assert(browser.last_target() == _G.nvim_browser_last_target_before_smoke, "smoke should not set the fixture as the resume target")
assert(browser.record_history(vim.uri_from_fname(root .. "/data/html/smoke.html"), "nvim-browser smoke") == false, "smoke metadata should not be recorded into session state")
assert(browser.last_target() == _G.nvim_browser_last_target_before_smoke, "smoke metadata should not persist as last target")
assert(_G.nvim_browser_smoke_report ~= nil and _G.nvim_browser_smoke_report.ok == true, "smoke should report a healthy interaction")
assert(vim.deep_equal(_G.nvim_browser_smoke_calls, {
  "click_here",
  "type_hint:i:nvim-browser interaction:true",
}), "smoke should type and submit through the browser hint overlay")
_G.nvim_browser_smoke_report_lines = table.concat(_G.nvim_browser_smoke_report.lines, "\n")
assert(_G.nvim_browser_smoke_report_lines:find("output: ANSI fallback", 1, true), "smoke report should include effective fallback output")
assert(_G.nvim_browser_smoke_report_lines:find("interaction: ok", 1, true), "smoke report should include interaction status")
assert(_G.nvim_browser_smoke_report_lines:find("hints: ok", 1, true), "smoke report should include hint discovery status")
assert(_G.nvim_browser_smoke_report_lines:find("cursor: ok", 1, true), "smoke report should include cursor placement status")
assert(_G.nvim_browser_smoke_report_lines:find("hint input: ok", 1, true), "smoke report should include hint-backed input status")
assert(_G.nvim_browser_smoke_report_lines:find("focus: ok", 1, true), "smoke report should include focus status")
assert(_G.nvim_browser_smoke_report_lines:find("input: ok", 1, true), "smoke report should include input status")
assert(_G.nvim_browser_smoke_report_lines:find("submit: ok", 1, true), "smoke report should include submit status")
assert(_G.nvim_browser_smoke_report_lines:find("frame cells: 80x20", 1, true), "smoke report should include frame cell geometry")
assert(_G.nvim_browser_smoke_report_lines:find("reader: ok", 1, true), "ANSI fallback smoke report should include reader status")
_G.nvim_browser_smoke_cursor = vim.api.nvim_win_get_cursor(_G.nvim_browser_smoke_winid)
assert(_G.nvim_browser_smoke_cursor[1] == 8 and _G.nvim_browser_smoke_cursor[2] == 11, "smoke should place the cursor from hint center coordinates")

_G.nvim_browser_smoke_report = nil
_G.nvim_browser_smoke_title = _G.nvim_browser_smoke_fixture_title
_G.nvim_browser_smoke_focused = nil
_G.nvim_browser_smoke_calls = {}
_G.nvim_browser_smoke_reader_bufnr = nil
terminal.state = function()
  return {
    mode = "serve",
    job_id = 1,
    has_buffer = true,
    current_url = _G.nvim_browser_smoke_fixture_url,
    current_title = _G.nvim_browser_smoke_title,
    status = "ok",
    serve_output = "kitty-unicode",
    terminal_graphics_egress_count = 1,
    last_terminal_graphics_egress_is_kitty_unicode = true,
    runtime_metadata = {
      output = "kitty-unicode",
      renderer = "chromium-cdp",
      transport = "stdio-jsonl",
      cells = { columns = 80, rows = 20 },
      viewport = { width = 800, height = 400 },
    },
    rendered_frame_geometry = { columns = 80, rows = 20, width = 800, height = 400 },
    rendered_frame_url = _G.nvim_browser_smoke_fixture_url,
    dom_epoch = 1,
    rendered_frame_dom_epoch = 1,
    frame_health = { stale = false, refresh_pending = false },
    focused_element = _G.nvim_browser_smoke_focused,
    reader_bufnr = _G.nvim_browser_smoke_reader_bufnr,
    winid = _G.nvim_browser_smoke_winid,
    element_hints = {
      { id = 1, kind = "input", label = "Smoke input", hint_label = "i", x = 120, y = 160, width = 240, height = 32 },
      { id = 2, kind = "button", label = "Run smoke", hint_label = "s", x = 120, y = 220, width = 240, height = 32 },
    },
  }
end
vim.defer_fn = function(callback)
  callback()
end
assert(browser.smoke({ timeout_ms = 1, interval_ms = 1, on_report = function(report)
  _G.nvim_browser_smoke_report = report
end }) == true, "non-fallback smoke should not require a reader buffer")
assert(_G.nvim_browser_smoke_report ~= nil and _G.nvim_browser_smoke_report.ok == true, "non-fallback smoke should still pass without reader")
_G.nvim_browser_non_fallback_smoke_report_lines = table.concat(_G.nvim_browser_smoke_report.lines, "\n")
assert(not _G.nvim_browser_non_fallback_smoke_report_lines:find("reader: ok", 1, true), "non-fallback smoke report should not include reader status")
assert(_G.nvim_browser_non_fallback_smoke_report_lines:find("terminal graphics: ok", 1, true), "kitty-unicode smoke report should include terminal graphics egress status")
assert(
  _G.nvim_browser_non_fallback_smoke_report_lines:find("kitty unicode payload: ok", 1, true),
  "kitty-unicode smoke report should include Kitty Unicode payload classification status"
)

_G.nvim_browser_smoke_report = nil
_G.nvim_browser_smoke_title = _G.nvim_browser_smoke_fixture_title
_G.nvim_browser_smoke_focused = nil
_G.nvim_browser_smoke_calls = {}
terminal.state = function()
  return {
    mode = "serve",
    job_id = 1,
    has_buffer = true,
    current_url = _G.nvim_browser_smoke_fixture_url,
    current_title = _G.nvim_browser_smoke_title,
    status = "ok",
    serve_output = "kitty-unicode",
    terminal_graphics_egress_count = 0,
    runtime_metadata = {
      output = "kitty-unicode",
      renderer = "chromium-cdp",
      transport = "stdio-jsonl",
      cells = { columns = 80, rows = 20 },
      viewport = { width = 800, height = 400 },
    },
    rendered_frame_geometry = { columns = 80, rows = 20, width = 800, height = 400 },
    rendered_frame_url = _G.nvim_browser_smoke_fixture_url,
    dom_epoch = 1,
    rendered_frame_dom_epoch = 1,
    frame_health = { stale = false, refresh_pending = false },
    focused_element = _G.nvim_browser_smoke_focused,
    winid = _G.nvim_browser_smoke_winid,
    element_hints = {
      { id = 1, kind = "input", label = "Smoke input", hint_label = "i", x = 120, y = 160, width = 240, height = 32 },
      { id = 2, kind = "button", label = "Run smoke", hint_label = "s", x = 120, y = 220, width = 240, height = 32 },
    },
  }
end
assert(browser.smoke({ timeout_ms = 1, interval_ms = 1, on_report = function(report)
  _G.nvim_browser_smoke_report = report
end }) == true, "kitty-unicode smoke should still finish when graphics egress has not been observed")
_G.nvim_browser_missing_graphics_smoke_report_lines = table.concat(_G.nvim_browser_smoke_report.lines, "\n")
assert(
  _G.nvim_browser_missing_graphics_smoke_report_lines:find("terminal graphics: none", 1, true),
  "kitty-unicode smoke report should identify missing terminal graphics egress"
)

_G.nvim_browser_smoke_report = nil
_G.nvim_browser_smoke_fake_now = 0
_G.nvim_browser_smoke_title = _G.nvim_browser_smoke_fixture_title
_G.nvim_browser_smoke_focused = nil
_G.nvim_browser_smoke_reader_bufnr = nil
terminal.state = function()
  return {
    mode = "serve",
    job_id = 1,
    has_buffer = true,
    current_url = _G.nvim_browser_smoke_fixture_url,
    current_title = _G.nvim_browser_smoke_title,
    status = "ok",
    serve_output = "ansi",
    serve_output_label = "ANSI fallback",
    runtime_metadata = {
      output = "ansi",
      output_label = "ANSI fallback",
      renderer = "chromium-cdp",
      transport = "stdio-jsonl",
      cells = { columns = 80, rows = 20 },
      viewport = { width = 800, height = 400 },
    },
    rendered_frame_geometry = { columns = 80, rows = 20, width = 800, height = 400 },
    rendered_frame_url = _G.nvim_browser_smoke_fixture_url,
    dom_epoch = 1,
    rendered_frame_dom_epoch = 1,
    frame_health = { stale = false, refresh_pending = false },
    focused_element = _G.nvim_browser_smoke_focused,
    reader_bufnr = _G.nvim_browser_smoke_reader_bufnr,
    winid = _G.nvim_browser_smoke_winid,
    element_hints = {
      { id = 1, kind = "input", label = "Smoke input", hint_label = "i", x = 120, y = 160, width = 240, height = 32 },
      { id = 2, kind = "button", label = "Run smoke", hint_label = "s", x = 120, y = 220, width = 240, height = 32 },
    },
  }
end
assert(browser.smoke({
  timeout_ms = 1,
  interval_ms = 1,
  clock = {
    now = function()
      _G.nvim_browser_smoke_fake_now = _G.nvim_browser_smoke_fake_now + 1
      return _G.nvim_browser_smoke_fake_now
    end,
  },
  on_report = function(report)
    _G.nvim_browser_smoke_report = report
  end,
}) == true, "ANSI fallback smoke should wait for reader health before passing")
assert(_G.nvim_browser_smoke_report ~= nil and _G.nvim_browser_smoke_report.ok == false, "ANSI fallback smoke should fail without reader before timeout")
assert(
  table.concat(_G.nvim_browser_smoke_report.lines, "\n"):find("reason: reader", 1, true),
  "ANSI fallback smoke should identify reader health as the failed stage: "
    .. table.concat(_G.nvim_browser_smoke_report.lines, " | ")
)

_G.nvim_browser_smoke_report = nil
_G.nvim_browser_smoke_fake_now = 0
terminal.state = function()
  return {
    mode = "serve",
    job_id = 1,
    has_buffer = true,
    current_url = "https://previous.example/smoke-title",
    current_title = "nvim-browser smoke",
    status = "ok",
    pending_operation = { label = "loading", target = vim.uri_from_fname(root .. "/data/html/smoke.html") },
    serve_output = "ansi",
    runtime_metadata = {
      output = "ansi",
      renderer = "chromium-cdp",
      cells = { columns = 80, rows = 20 },
      viewport = { width = 800, height = 400 },
    },
    rendered_frame_geometry = { columns = 80, rows = 20, width = 800, height = 400 },
    rendered_frame_url = "https://previous.example/smoke-title",
    frame_health = { stale = false, refresh_pending = false },
  }
end
assert(browser.smoke({
  timeout_ms = 1,
  interval_ms = 1,
  clock = {
    now = function()
      _G.nvim_browser_smoke_fake_now = _G.nvim_browser_smoke_fake_now + 1
      return _G.nvim_browser_smoke_fake_now
    end,
  },
  on_report = function(report)
    _G.nvim_browser_smoke_report = report
  end,
}) == true, "smoke should report previous-page false positives as failures")
assert(_G.nvim_browser_smoke_report ~= nil and _G.nvim_browser_smoke_report.ok == false, "smoke should not pass while the smoke navigation is still pending")
assert(table.concat(_G.nvim_browser_smoke_report.lines, "\n"):find("reason:", 1, true), "failed smoke should explain the failed readiness condition")

_G.nvim_browser_smoke_report = nil
_G.nvim_browser_smoke_fake_now = 0
_G.nvim_browser_smoke_title = _G.nvim_browser_smoke_fixture_title
_G.nvim_browser_smoke_focused = nil
terminal.state = function()
  return {
    mode = "serve",
    job_id = 1,
    has_buffer = true,
    current_url = _G.nvim_browser_smoke_fixture_url,
    current_title = _G.nvim_browser_smoke_title,
    status = "ok",
    serve_output = "ansi",
    runtime_metadata = {
      output = "ansi",
      renderer = "chromium-cdp",
      cells = { columns = 80, rows = 20 },
      viewport = { width = 800, height = 400 },
    },
    rendered_frame_geometry = { columns = 80, rows = 20, width = 800, height = 400 },
    rendered_frame_url = _G.nvim_browser_smoke_fixture_url,
    dom_epoch = 1,
    rendered_frame_dom_epoch = 1,
    frame_health = { stale = false, refresh_pending = false },
    focused_element = _G.nvim_browser_smoke_focused,
    winid = _G.nvim_browser_smoke_winid,
    element_hints = {
      { id = 1, kind = "input", label = "Smoke input", hint_label = "i", x = 120, y = 160, width = 240, height = 32 },
      { id = 2, kind = "button", label = "Run smoke", hint_label = "s", x = 120, y = 220, width = 240, height = 32 },
    },
  }
end
terminal.click_here = function()
  return true
end
terminal.type_hint = function(id, text, opts)
  if tostring(id) == "i" and text == _G.nvim_browser_smoke_interaction_text and opts ~= nil and opts.submit == true then
    _G.nvim_browser_smoke_title = "nvim-browser smoke submitted: " .. text
    return true
  end
  return false
end
assert(browser.smoke({
  timeout_ms = 1,
  interval_ms = 1,
  clock = {
    now = function()
      _G.nvim_browser_smoke_fake_now = _G.nvim_browser_smoke_fake_now + 1
      return _G.nvim_browser_smoke_fake_now
    end,
  },
  on_report = function(report)
    _G.nvim_browser_smoke_report = report
  end,
}) == true, "smoke should not require focus metadata before typing through hints")
assert(_G.nvim_browser_smoke_report ~= nil and _G.nvim_browser_smoke_report.ok == true, "smoke should submit through hints when focus metadata is absent")
assert(table.concat(_G.nvim_browser_smoke_report.lines, "\n"):find("hint input: ok", 1, true), "smoke should report hint-backed input")

_G.nvim_browser_smoke_report = nil
_G.nvim_browser_smoke_fake_now = 0
_G.nvim_browser_smoke_title = _G.nvim_browser_smoke_fixture_title
_G.nvim_browser_smoke_focused = nil
_G.nvim_browser_smoke_stale_hints = {
  { id = 1, kind = "input", label = "Smoke input", hint_label = "i", x = 120, y = 160, width = 240, height = 32 },
  { id = 2, kind = "button", label = "Run smoke", hint_label = "s", x = 120, y = 220, width = 240, height = 32 },
}
terminal.state = function()
  return {
    mode = "serve",
    job_id = 1,
    has_buffer = true,
    current_url = _G.nvim_browser_smoke_fixture_url,
    current_title = _G.nvim_browser_smoke_title,
    status = "ok",
    serve_output = "kitty-unicode",
    runtime_metadata = {
      output = "kitty-unicode",
      renderer = "chromium-cdp",
      cells = { columns = 80, rows = 20 },
      viewport = { width = 800, height = 400 },
    },
    rendered_frame_geometry = { columns = 80, rows = 20, width = 800, height = 400 },
    rendered_frame_url = _G.nvim_browser_smoke_fixture_url,
    dom_epoch = 1,
    rendered_frame_dom_epoch = 1,
    frame_health = { stale = false, refresh_pending = false },
    focused_element = _G.nvim_browser_smoke_focused,
    winid = _G.nvim_browser_smoke_winid,
    element_hints = _G.nvim_browser_smoke_stale_hints,
  }
end
terminal.click_here = function()
  return true
end
terminal.type_hint = function(id, text, opts)
  if tostring(id) == "i" and text == _G.nvim_browser_smoke_interaction_text and opts ~= nil and opts.submit == true then
    _G.nvim_browser_smoke_title = "nvim-browser smoke submitted: " .. text
    return true
  end
  return false
end
assert(browser.smoke({
  timeout_ms = 1,
  interval_ms = 1,
  clock = {
    now = function()
      _G.nvim_browser_smoke_fake_now = _G.nvim_browser_smoke_fake_now + 1
      return _G.nvim_browser_smoke_fake_now
    end,
  },
  on_report = function(report)
    _G.nvim_browser_smoke_report = report
  end,
}) == true, "smoke should reject stale pre-click hints before hint-backed input")
assert(_G.nvim_browser_smoke_report ~= nil and _G.nvim_browser_smoke_report.ok == false, "smoke should fail if click does not refresh hints")
assert(table.concat(_G.nvim_browser_smoke_report.lines, "\n"):find("fresh Smoke input hint", 1, true), "failed smoke should explain stale hints")
terminal.open = _G.nvim_browser_original_terminal_open_for_smoke
terminal.state = _G.nvim_browser_original_terminal_state_for_smoke
terminal.focus_selector = _G.nvim_browser_original_terminal_focus_selector_for_smoke
terminal.input_text = _G.nvim_browser_original_terminal_input_text_for_smoke
terminal.submit_focused = _G.nvim_browser_original_terminal_submit_focused_for_smoke
terminal.click_hint = _G.nvim_browser_original_terminal_click_hint_for_smoke
terminal.click_here = _G.nvim_browser_original_terminal_click_here_for_smoke
terminal.type_here = _G.nvim_browser_original_terminal_type_here_for_smoke
terminal.type_hint = _G.nvim_browser_original_terminal_type_hint_for_smoke
vim.defer_fn = _G.nvim_browser_original_defer_fn_for_smoke

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

_G.nvim_browser_picked_jump = nil
browser.jump_hint = function(label)
  _G.nvim_browser_picked_jump = label
  return true
end
assert(browser.pick_hint(function(items, _, on_choice)
  on_choice(items[2])
end, { action = "jump" }) == true, "pick_hint should support jump action")
assert(_G.nvim_browser_picked_jump == "s", "pick_hint should pass selected label to jump_hint")
browser.jump_hint = _G.nvim_browser_original_jump_hint_api

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
assert(browser.pick_hint_action_available("jump") == true, "jump picker action should be detectable")
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

_G.nvim_browser_yanked_point_url_register = nil
terminal.yank_point_url_here = function(register)
  _G.nvim_browser_yanked_point_url_register = register
  return "point-url-yanked"
end
assert(browser.yank_point_url_here("*") == "point-url-yanked", "yank_point_url_here should delegate to terminal")
assert(_G.nvim_browser_yanked_point_url_register == "*", "yank_point_url_here should pass explicit registers to terminal")

_G.nvim_browser_followed_point_url = false
terminal.follow_point_url_here = function()
  _G.nvim_browser_followed_point_url = true
  return "point-url-followed"
end
assert(browser.follow_point_url_here() == "point-url-followed", "follow_point_url_here should delegate to terminal")
assert(_G.nvim_browser_followed_point_url == true, "follow_point_url_here should invoke terminal cursor follow")

_G.nvim_browser_point_info_callback = nil
terminal.point_info_here = function(callback)
  _G.nvim_browser_point_info_callback = callback
  return "point-info"
end
_G.nvim_browser_point_info_callback_arg = function() end
assert(browser.point_info_here(_G.nvim_browser_point_info_callback_arg) == "point-info", "point_info_here should delegate to terminal")
assert(_G.nvim_browser_point_info_callback == _G.nvim_browser_point_info_callback_arg, "point_info_here should pass callbacks to terminal")

local clicked_mouse = nil
terminal.click_mouse = function(mousepos)
  clicked_mouse = mousepos
  return "clicked"
end
local mousepos = { winid = 10, line = 3, column = 8 }
assert(browser.click_mouse(mousepos) == "clicked", "click_mouse should delegate to terminal mouse click semantics")
assert(clicked_mouse == mousepos, "click_mouse should pass explicit mouse position to terminal")

_G.nvim_browser_clicked_point = nil
terminal.click_point = function(x, y, opts)
  _G.nvim_browser_clicked_point = { x = x, y = y, opts = opts }
  return "point"
end
_G.nvim_browser_click_point_opts = { click_count = 2 }
assert(
  browser.click_point(12, 24, _G.nvim_browser_click_point_opts) == "point",
  "click_point should delegate to terminal"
)
assert(_G.nvim_browser_clicked_point.x == 12, "click_point should pass the x coordinate")
assert(_G.nvim_browser_clicked_point.y == 24, "click_point should pass the y coordinate")
assert(
  _G.nvim_browser_clicked_point.opts == _G.nvim_browser_click_point_opts,
  "click_point should pass options through to terminal"
)

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

terminal.double_click_here = function()
  return "double-here"
end
assert(browser.double_click_here() == "double-here", "double_click_here should delegate to terminal")

_G.nvim_browser_double_clicked_mouse = nil
terminal.double_click_mouse = function(explicit_mousepos)
  _G.nvim_browser_double_clicked_mouse = explicit_mousepos
  return "double-mouse"
end
assert(browser.double_click_mouse(mousepos) == "double-mouse", "double_click_mouse should delegate to terminal")
assert(_G.nvim_browser_double_clicked_mouse == mousepos, "double_click_mouse should pass explicit mouse position to terminal")

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

_G.nvim_browser_jumped_hint = nil
terminal.jump_hint = function(label)
  _G.nvim_browser_jumped_hint = label
  return "jumped"
end
assert(browser.jump_hint("s") == "jumped", "jump_hint should delegate to terminal")
assert(_G.nvim_browser_jumped_hint == "s", "jump_hint should pass hint label to terminal")

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

terminal.wheel_here = function(delta_y, delta_x)
  _G.nvim_browser_wheeled_here = { delta_y = delta_y, delta_x = delta_x }
  return true
end
assert(browser.wheel_here(120, 0) == true, "wheel_here should delegate to terminal cursor wheel")
assert(_G.nvim_browser_wheeled_here.delta_y == 120, "wheel_here should pass vertical wheel delta to terminal")
assert(_G.nvim_browser_wheeled_here.delta_x == 0, "wheel_here should pass horizontal wheel delta to terminal")

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
local a_register = vim.fn.getreg("a")
vim.fn.setreg('"', "hello from unnamed\nregister")
vim.fn.setreg("a", "hello from register a")

focused_input = nil
assert(browser.paste_register() == true, "paste_register should paste the unnamed register by default")
assert(focused_input == "hello from unnamed\nregister", "paste_register should pass unnamed register text to terminal")

focused_input = nil
assert(browser.paste_register("a") == true, "paste_register should paste an explicit register")
assert(focused_input == "hello from register a", "paste_register should pass explicit register text to terminal")

focused_input = nil
vim.fn.setreg("a", "should not paste")
assert(browser.paste_register("ab") == false, "paste_register should reject multi-character register names")
assert(focused_input == nil, "invalid register names should not be passed to terminal")

vim.fn.setreg('"', "")
assert(browser.paste_register() == false, "paste_register should reject empty register contents")

vim.fn.setreg('"', unnamed_register)
vim.fn.setreg("a", a_register)

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

terminal_download_history = {
  { path = "/tmp/downloads/report.pdf", suggested_filename = "report.pdf", status = "completed" },
}
terminal.downloads = function()
  return terminal_download_history
end
downloads = browser.downloads()
assert(#downloads == 1, "downloads should expose terminal download history")
assert(downloads[1].path == "/tmp/downloads/report.pdf", "downloads should include completed download paths")
downloads[1].path = "/tmp/changed.pdf"
assert(
  terminal_download_history[1].path == "/tmp/downloads/report.pdf",
  "downloads should return a defensive copy of terminal metadata"
)

terminal._test.apply_serve_response({
  id = 9101,
  status = "ok",
  dialogs = {
    { kind = "alert", message = "first notice", action = "accepted" },
    { kind = "confirm", message = "continue?", action = "dismissed" },
  },
})
_G.nvim_browser_dialog_history = browser.dialogs()
assert(#_G.nvim_browser_dialog_history == 2, "dialogs should expose recorded browser dialog history")
assert(_G.nvim_browser_dialog_history[1].kind == "alert", "dialogs should preserve recorded order")
assert(_G.nvim_browser_dialog_history[2].message == "continue?", "dialogs should preserve dialog messages")
_G.nvim_browser_dialog_history[1].message = "mutated"
assert(browser.dialogs()[1].message == "first notice", "dialogs should return defensive copies")

opened_download_target = nil
original_browser_open_for_download = browser.open
browser.open = function(target)
  opened_download_target = target
  return true
end
assert(browser.open_download() == true, "open_download should open a single completed download")
assert(opened_download_target == "/tmp/downloads/report.pdf", "open_download should pass the download path through browser.open")

terminal_download_history = {
  { path = "/tmp/downloads/report.pdf", suggested_filename = "report.pdf", status = "completed" },
  { path = "/tmp/downloads/archive.zip", suggested_filename = "archive.zip", status = "completed" },
}
opened_download_target = nil
download_picker_prompt = nil
download_picker_first_label = nil
assert(browser.open_download(nil, {
  select = function(items, opts, on_choice)
    download_picker_prompt = opts.prompt
    download_picker_first_label = opts.format_item(items[1])
    on_choice(items[2])
  end,
}) == true, "open_download should open a picker when multiple downloads exist")
assert(download_picker_prompt == "nvim-browser download: ", "open_download should use a download picker prompt")
assert(
  download_picker_first_label == "1. report.pdf /tmp/downloads/report.pdf",
  "open_download picker should use indexed filename/path labels"
)
assert(opened_download_target == "/tmp/downloads/archive.zip", "open_download picker should open the selected download path")

opened_download_target = nil
download_picker_prompt = nil
assert(browser.open_download(nil, {
  select = function(_, opts, _)
    download_picker_prompt = opts.prompt
  end,
}) == nil, "open_download should return nil while an async picker selection is pending")
assert(download_picker_prompt == "nvim-browser download: ", "open_download should still start the async picker")
assert(opened_download_target == nil, "open_download should not open anything before an async picker selects a download")

opened_download_target = nil
assert(browser.open_download(1) == true, "open_download should accept a 1-based download index")
assert(opened_download_target == "/tmp/downloads/report.pdf", "open_download should open the indexed download path")

opened_download_target = nil
assert(browser.open_download("abc") == false, "open_download should reject a nonnumeric index")
assert(opened_download_target == nil, "open_download should not open anything for a nonnumeric index")

opened_download_target = nil
assert(browser.open_download(9) == false, "open_download should reject an invalid index")
assert(opened_download_target == nil, "open_download should not open anything for an invalid index")

terminal_download_history = {}
assert(browser.open_download() == false, "open_download should reject empty download history")

terminal_download_history = {
  { suggested_filename = "missing-path.bin", status = "completed" },
}
assert(browser.open_download() == false, "open_download should reject downloads without a path")

terminal_download_history = {
  { path = "/tmp/downloads/report.pdf", suggested_filename = "report.pdf", status = "completed" },
  { path = "/tmp/downloads/archive.zip", suggested_filename = "archive.zip", status = "completed" },
}
opened_download_target = nil
assert(browser.open_download(nil, {
  select = function(_, _, on_choice)
    on_choice(nil)
  end,
}) == false, "open_download should treat picker cancellation as a failed open")
assert(opened_download_target == nil, "open_download should not open anything when picker is canceled")
browser.open = original_browser_open_for_download

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
terminal.zoom = function(scale)
  table.insert(zoom_calls, "exact:" .. tostring(scale))
  return "zoom-exact"
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
assert(browser.zoom(1.25) == "zoom-exact", "zoom should delegate exact scales to terminal")
assert(browser.zoom_out() == "zoom-out", "zoom_out should delegate to terminal")
assert(browser.zoom_reset() == "zoom-reset", "zoom_reset should delegate to terminal")
assert(table.concat(zoom_calls, ",") == "in,exact:1.25,out,reset", "zoom APIs should call terminal zoom methods")
terminal.zoom_in = original_terminal_zoom_in
terminal.zoom = _G.nvim_browser_original_terminal_zoom
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
  return { { id = 5, hint_label = "j" } }
end
_G.nvim_browser_jump_prompts = {}
_G.nvim_browser_jumped_hint = nil
terminal.jump_hint = function(label)
  _G.nvim_browser_jumped_hint = label
  return true
end
assert(browser.jump_hint_mode(function(prompt)
  table.insert(_G.nvim_browser_jump_prompts, prompt)
  return "j"
end) == true, "jump_hint_mode should jump to the prompted hint")
assert(table.concat(_G.nvim_browser_jump_prompts, "|") == "nvim-browser hint: ", "jump_hint_mode should prompt for hint")
assert(_G.nvim_browser_jumped_hint == "j", "jump_hint_mode should pass the prompted hint label")

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
assert(browser.jump_hint_mode(function()
  error("input should not be called without hints")
end) == false, "jump_hint_mode should return false without active hints")

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
assert(browser.jump_hint_mode(function()
  return ""
end) == false, "jump_hint_mode should cancel on empty hint label")

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
terminal.click_point = original_terminal_click_point
terminal.right_click_point = original_terminal_right_click_point
terminal.right_click_here = original_terminal_right_click_here
terminal.double_click_here = _G.nvim_browser_original_terminal_double_click_here
terminal.double_click_mouse = _G.nvim_browser_original_terminal_double_click_mouse
terminal.right_click_mouse = original_terminal_right_click_mouse
terminal.right_click_hint = original_terminal_right_click_hint
browser.follow_hint = original_follow_hint
browser.input_text = original_input_text
browser.press_key = original_press_key
terminal.follow_hint = original_terminal_follow_hint
terminal.click_mouse = original_terminal_click_mouse
terminal.wheel_point = original_terminal_wheel_point
terminal.wheel_mouse = original_terminal_wheel_mouse
terminal.wheel_here = _G.nvim_browser_original_terminal_wheel_here
terminal.type_hint = original_terminal_type_hint
terminal.jump_hint = _G.nvim_browser_original_terminal_jump_hint
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
terminal.downloads = original_terminal_downloads
terminal.screenshot = original_terminal_screenshot
terminal.yank_current_url = original_terminal_yank_current_url
terminal.yank_hint_url = original_terminal_yank_hint_url
terminal.yank_point_url_here = _G.nvim_browser_original_terminal_yank_point_url_here
terminal.point_info_here = _G.nvim_browser_original_terminal_point_info_here
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

_G.nvim_browser_original_terminal_state_for_auto_refresh = terminal.state
_G.nvim_browser_original_terminal_refresh_for_auto_refresh = terminal.refresh
_G.nvim_browser_auto_refresh_markdown_path = vim.fn.tempname() .. ".md"
_G.nvim_browser_auto_refresh_image_path = vim.fn.tempname() .. ".png"
_G.nvim_browser_auto_refresh_other_path = vim.fn.tempname() .. ".md"
vim.fn.writefile({ "# Auto refresh" }, _G.nvim_browser_auto_refresh_markdown_path)
vim.fn.writefile({ "image" }, _G.nvim_browser_auto_refresh_image_path)
vim.fn.writefile({ "# Other" }, _G.nvim_browser_auto_refresh_other_path)
_G.nvim_browser_auto_refresh_markdown_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(_G.nvim_browser_auto_refresh_markdown_buf, _G.nvim_browser_auto_refresh_markdown_path)
_G.nvim_browser_auto_refresh_image_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(_G.nvim_browser_auto_refresh_image_buf, _G.nvim_browser_auto_refresh_image_path)
_G.nvim_browser_auto_refresh_other_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(_G.nvim_browser_auto_refresh_other_buf, _G.nvim_browser_auto_refresh_other_path)
_G.nvim_browser_auto_refresh_count = 0
terminal.refresh = function()
  _G.nvim_browser_auto_refresh_count = _G.nvim_browser_auto_refresh_count + 1
  return true
end
browser.setup({ auto_refresh_on_write = true, session = { persist = false } })
terminal.state = function()
  return {
    mode = "serve",
    job_id = 1357,
    has_buffer = true,
    current_url = vim.uri_from_fname(_G.nvim_browser_auto_refresh_markdown_path),
    browser_url = "file:///tmp/nvbrowser-markdown-wrapper.html",
  }
end
vim.api.nvim_exec_autocmds("BufWritePost", { buffer = _G.nvim_browser_auto_refresh_markdown_buf, modeline = false })
assert(_G.nvim_browser_auto_refresh_count == 1, "saving the active Markdown source should refresh the preview")
vim.api.nvim_exec_autocmds("BufWritePost", { buffer = _G.nvim_browser_auto_refresh_other_buf, modeline = false })
assert(_G.nvim_browser_auto_refresh_count == 1, "saving an unrelated buffer should not refresh the preview")
terminal.state = function()
  return {
    mode = "serve",
    job_id = 1357,
    has_buffer = true,
    current_url = vim.uri_from_fname(_G.nvim_browser_auto_refresh_image_path),
    browser_url = "file:///tmp/nvbrowser-image-wrapper.html",
  }
end
vim.api.nvim_exec_autocmds("BufWritePost", { buffer = _G.nvim_browser_auto_refresh_image_buf, modeline = false })
assert(_G.nvim_browser_auto_refresh_count == 2, "saving the active image source should refresh the preview")
terminal.state = function()
  return {
    mode = "serve",
    job_id = 1357,
    has_buffer = true,
    current_url = "https://example.com",
  }
end
vim.api.nvim_exec_autocmds("BufWritePost", { buffer = _G.nvim_browser_auto_refresh_markdown_buf, modeline = false })
assert(_G.nvim_browser_auto_refresh_count == 2, "saving a local file should not refresh direct web pages")
terminal.state = function()
  return {
    mode = "serve",
    job_id = nil,
    has_buffer = false,
    current_url = vim.uri_from_fname(_G.nvim_browser_auto_refresh_markdown_path),
  }
end
vim.api.nvim_exec_autocmds("BufWritePost", { buffer = _G.nvim_browser_auto_refresh_markdown_buf, modeline = false })
assert(_G.nvim_browser_auto_refresh_count == 2, "saving should not refresh when no serve session is active")
browser.setup({ auto_refresh_on_write = false, session = { persist = false } })
terminal.state = function()
  return {
    mode = "serve",
    job_id = 1357,
    has_buffer = true,
    current_url = vim.uri_from_fname(_G.nvim_browser_auto_refresh_markdown_path),
  }
end
vim.api.nvim_exec_autocmds("BufWritePost", { buffer = _G.nvim_browser_auto_refresh_markdown_buf, modeline = false })
assert(_G.nvim_browser_auto_refresh_count == 2, "disabled auto-refresh-on-write should not refresh matching previews")
terminal.state = _G.nvim_browser_original_terminal_state_for_auto_refresh
terminal.refresh = _G.nvim_browser_original_terminal_refresh_for_auto_refresh
browser.setup({ auto_refresh_on_write = true, session = { persist = false } })

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
