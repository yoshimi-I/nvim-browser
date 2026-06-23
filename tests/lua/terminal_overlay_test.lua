local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local terminal = require("nvim-browser.terminal")

local original_nvim_chan_send = vim.api.nvim_chan_send
vim.api.nvim_chan_send = function(channel, payload)
  if channel == vim.v.stderr then
    return 0
  end
  return original_nvim_chan_send(channel, payload)
end

local cleanup_escape = terminal._test.kitty_cleanup_escape()
assert(cleanup_escape:find("\27_Ga=d,d=i,i=1\27\\", 1, true), "cleanup should delete monolithic image id 1")
assert(cleanup_escape:find("\27_Ga=d,d=i,i=2\27\\", 1, true), "cleanup should delete first tile image id")
assert(cleanup_escape:find("\27_Ga=d,d=i,i=257\27\\", 1, true), "cleanup should delete the max stable tile image id")

local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { string.rep(" ", 12), string.rep(" ", 12), string.rep(" ", 12) })

terminal._test.apply_hint_overlay(bufnr, {
  { id = 1, hint_label = "a", x = 50, y = 10, label = "Search" },
  { id = 2, hint_label = "s", x = 95, y = 55, label = "Docs" },
}, {
  columns = 10,
  rows = 3,
  width = 100,
  height = 60,
})

local namespace = terminal._test.hint_namespace()
local marks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })

assert(#marks == 2, "expected two hint overlay marks")
assert(marks[1][2] == 0, "first hint should be on first row")
assert(marks[1][3] == 0, "first hint should use a stable byte column")
assert(marks[1][4].virt_text_win_col == 5, "first hint should be centered in window column 6")
assert(marks[1][4].virt_text[1][1] == "a", "first hint should render its key label")
assert(marks[2][2] == 2, "second hint should be clamped to last row")
assert(marks[2][3] == 0, "second hint should use a stable byte column")
assert(marks[2][4].virt_text_win_col == 9, "second hint should be clamped to last window column")
assert(marks[2][4].virt_text[1][1] == "s", "second hint should render its key label")

terminal._test.clear_hint_overlay(bufnr)
local cleared = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })
assert(#cleared == 0, "clearing overlay should remove hint marks")

local short_bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(short_bufnr, 0, -1, false, { string.rep(" ", 8) })
local ok, err = pcall(terminal._test.apply_hint_overlay, short_bufnr, {
  { id = 9, x = 90, y = 90 },
}, {
  columns = 10,
  rows = 10,
  width = 100,
  height = 100,
})
assert(ok, "overlay should not fail when the buffer has fewer lines than viewport rows: " .. tostring(err))
local short_marks = vim.api.nvim_buf_get_extmarks(short_bufnr, namespace, 0, -1, { details = true })
assert(#short_marks == 1, "short buffer should still receive an overlay mark")
assert(short_marks[1][2] == 0, "short buffer mark should clamp to the last existing line")

local hidden_bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(hidden_bufnr, 0, -1, false, { string.rep(" ", 8) })
terminal._test.apply_hint_overlay(hidden_bufnr, {
  { id = 3, x = 10, y = 10 },
}, nil)
local hidden_marks = vim.api.nvim_buf_get_extmarks(hidden_bufnr, namespace, 0, -1, { details = true })
assert(#hidden_marks == 0, "nil geometry should clear and skip overlay")

local labeled = terminal._test.assign_hint_labels({
  { id = 1, label = "Search", x = 10, y = 10 },
  { id = 2, label = "Docs", x = 20, y = 20 },
  { id = 3, label = "Login", x = 30, y = 30 },
})
assert(labeled[1].hint_label == "a", "first hint should get the first keyboard label")
assert(labeled[2].hint_label == "s", "second hint should get the second keyboard label")
assert(labeled[3].hint_label == "d", "third hint should get the third keyboard label")
assert(labeled[1].id == 1 and labeled[1].label == "Search", "label assignment should preserve original hint fields")

local many_hints = {}
for index = 1, 28 do
  table.insert(many_hints, { id = index, x = index, y = index })
end
local many_labeled = terminal._test.assign_hint_labels(many_hints)
assert(many_labeled[27].hint_label == "aa", "labels should roll over after single-key labels")
assert(many_labeled[28].hint_label == "as", "rolled labels should stay keyboard-oriented")

local target_hints = {
  { id = 1, hint_label = "a", x = 11, y = 12 },
  { id = 2, hint_label = "s", x = 21, y = 22 },
}
assert(terminal._test.find_hint(target_hints, "a") == target_hints[1], "hint lookup should match keyboard labels")
assert(terminal._test.find_hint(target_hints, "s") == target_hints[2], "hint lookup should match later keyboard labels")
assert(terminal._test.find_hint(target_hints, "1") == target_hints[1], "hint lookup should preserve numeric id compatibility")
assert(terminal._test.find_hint(target_hints, 2) == target_hints[2], "hint lookup should preserve numeric id arguments")
assert(terminal._test.find_hint(target_hints, "missing") == nil, "hint lookup should return nil for unknown labels")

assert(
  terminal._test.browser_buffer_name("Example Domain", "https://example.com/path?q=1") == "nvim-browser://Example Domain",
  "buffer name should prefer the current page title"
)
assert(
  terminal._test.browser_buffer_name("", "https://example.com/path?q=1") == "nvim-browser://example.com/path",
  "buffer name should fall back to URL host and path without query"
)
assert(
  terminal._test.browser_buffer_name(vim.NIL, "https://example.com/path#section") == "nvim-browser://example.com/path",
  "buffer name should treat vim.NIL title as absent and strip URL fragments"
)
assert(
  terminal._test.browser_buffer_name("docs/guide: intro", nil) == "nvim-browser://docs-guide- intro",
  "buffer name should sanitize path separators and colons"
)
assert(
  vim.fn.strchars(terminal._test.browser_buffer_name(string.rep("あ", 90), nil):gsub("^nvim%-browser://", "")) == 80,
  "buffer name truncation should be character-aware for non-ASCII titles"
)

local name_bufnr = vim.api.nvim_create_buf(false, true)
local named_ok, named = terminal._test.set_browser_buffer_name(name_bufnr, "Example Domain", "https://example.com")
assert(named_ok, "setting browser buffer name should succeed")
assert(named == "nvim-browser://Example Domain", "setter should return the applied buffer name")
assert(vim.api.nvim_buf_get_name(name_bufnr) == "nvim-browser://Example Domain", "setter should update the buffer name")

local duplicate_bufnr = vim.api.nvim_create_buf(false, true)
local duplicate_ok, duplicate_name = terminal._test.set_browser_buffer_name(duplicate_bufnr, "Example Domain", "https://example.com")
assert(duplicate_ok, "setting a duplicate browser buffer name should fall back instead of failing")
assert(
  duplicate_name == "nvim-browser://Example Domain [" .. duplicate_bufnr .. "]",
  "duplicate names should receive a stable buffer-number suffix"
)

local deleted_bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_delete(deleted_bufnr, { force = true })
assert(terminal._test.set_browser_buffer_name(deleted_bufnr, "Gone", nil) == false, "invalid buffers should be ignored")

terminal._test.set_last_find_found(true)
terminal._test.handle_find_text_response({ status = "error" })
assert(terminal.state().last_find_found == nil, "failed find responses should clear stale find state")

local warnings = {}
local original_echo = vim.api.nvim_echo
vim.api.nvim_echo = function(chunks)
  if chunks[1][2] == "WarningMsg" then
    table.insert(warnings, chunks[1][1])
  end
end

terminal._test.handle_find_text_response({ status = "ok", found = false })
assert(terminal.state().last_find_found == false, "not-found responses should update find state to false")
assert(warnings[#warnings] == "nvim-browser: text was not found", "not-found responses should warn")

terminal._test.handle_find_text_response({ status = "ok", found = true })
assert(terminal.state().last_find_found == true, "found responses should update find state to true")

terminal._test.apply_serve_response({
  id = 99,
  status = "ok",
  url = "https://example.com/long",
  runtime = {
    protocol_version = 1,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "kitty-unicode",
    cells = { columns = 80, rows = 24 },
    viewport = { width = 800, height = 600, device_scale_factor = 1 },
  },
  page = {
    scroll_x = 0,
    scroll_y = 250,
    viewport_width = 800,
    viewport_height = 600,
    document_width = 800,
    document_height = 1600,
  },
})
local page_metrics = terminal.state().page_metrics
assert(page_metrics ~= nil, "serve responses should store page metrics")
assert(page_metrics.scroll_y == 250, "stored page metrics should preserve scroll position")
assert(page_metrics.document_height == 1600, "stored page metrics should preserve document size")
local runtime_info = terminal.state().runtime_metadata
assert(runtime_info ~= nil, "serve responses should store runtime metadata")
assert(runtime_info.protocol_version == 1, "runtime metadata should preserve protocol version")
assert(runtime_info.output == "kitty-unicode", "runtime metadata should preserve output mode")
assert(runtime_info.cells.columns == 80, "runtime metadata should preserve preview columns")
assert(runtime_info.viewport.width == 800, "runtime metadata should preserve viewport width")
terminal.close()
assert(terminal.state().page_metrics == nil, "closing a browser session should clear page metrics")
assert(terminal.state().runtime_metadata == nil, "closing a browser session should clear runtime metadata")
terminal._test.apply_serve_response({ id = 100, status = "error", error = "navigation failed" })
assert(terminal.state().page_metrics == nil, "responses without page metrics should clear stale page metrics")

terminal._test.handle_reader_response({
  status = "ok",
  text = {
    title = "Example",
    url = "https://example.com",
    text = "# Example\n\nBody text\n\n[Docs](https://example.com/docs)",
    truncated = false,
  },
})
local reader_bufnr = terminal.state().reader_bufnr
assert(reader_bufnr ~= nil and vim.api.nvim_buf_is_valid(reader_bufnr), "reader response should create a scratch buffer")
assert(vim.bo[reader_bufnr].filetype == "markdown", "reader buffer should use markdown filetype")
local reader_lines = table.concat(vim.api.nvim_buf_get_lines(reader_bufnr, 0, -1, false), "\n")
assert(reader_lines:match("# Example"), "reader buffer should include page title")
assert(reader_lines:match("https://example%.com"), "reader buffer should include page URL")
assert(reader_lines:match("Body text"), "reader buffer should include page text")
assert(
  vim.api.nvim_buf_call(reader_bufnr, function()
    return vim.fn.maparg("<CR>", "n", false, true).buffer == 1
  end),
  "reader buffer should install a buffer-local follow mapping"
)
assert(
  vim.api.nvim_buf_call(reader_bufnr, function()
    return vim.fn.maparg("gf", "n", false, true).buffer == 1
  end),
  "reader buffer should install a gf follow mapping"
)
assert(terminal._test.reader_url_at_line("[Docs](https://example.com/docs)", 8) == "https://example.com/docs", "reader URL extraction should read markdown links")
assert(
  terminal._test.reader_url_at_line("[Docs\\]](https://example.com/a\\)b)", 7) == "https://example.com/a)b",
  "reader URL extraction should unescape Markdown links emitted by Chromium"
)
assert(terminal._test.reader_url_at_line("<https://example.com/from-angle>", 3) == "https://example.com/from-angle", "reader URL extraction should read angle links")
assert(terminal._test.reader_url_at_line("bare https://example.com/bare link", 10) == "https://example.com/bare", "reader URL extraction should read bare links")

terminal._test.set_mode("serve")
terminal._test.set_job_id(99)
vim.api.nvim_set_current_buf(reader_bufnr)
vim.api.nvim_win_set_cursor(0, { 7, 8 })
local original_chansend_for_reader = vim.fn.chansend
local reader_requests = {}
vim.fn.chansend = function(job_id, payload)
  table.insert(reader_requests, { job_id = job_id, request = vim.json.decode(payload) })
  return 1
end
assert(
  terminal.reader_follow() == "https://example.com/docs",
  "reader follow should return the navigated reader link URL"
)
vim.fn.chansend = original_chansend_for_reader
local followed_request = reader_requests[1]
assert(followed_request ~= nil, "reader follow should send a serve request")
assert(followed_request.request.type == "navigate", "reader follow should reuse the active browser session")
assert(followed_request.request.url == "https://example.com/docs", "reader follow should navigate to the link URL")
assert(terminal.state().last_target == "https://example.com/docs", "reader follow mappings should update terminal last target")

terminal._test.handle_reader_response({
  status = "ok",
  text = {
    title = "Example",
    url = "https://example.com",
    text = "# Example\n\nBody text\n\n[truncated]",
    truncated = true,
  },
})
local truncated_lines = table.concat(vim.api.nvim_buf_get_lines(terminal.state().reader_bufnr, 0, -1, false), "\n")
local _, truncated_count = truncated_lines:gsub("%[truncated%]", "")
assert(truncated_count == 1, "reader buffers should not duplicate truncation markers")

local first_reader_bufnr = terminal.state().reader_bufnr
terminal.close()
assert(not vim.api.nvim_buf_is_valid(first_reader_bufnr), "closing a browser session should delete reader buffers")
terminal._test.handle_reader_response({
  status = "ok",
  text = {
    title = "Example",
    url = "https://example.com",
    text = "# Example\n\nFresh body",
    truncated = false,
  },
})
local second_reader_bufnr = terminal.state().reader_bufnr
assert(second_reader_bufnr ~= nil and vim.api.nvim_buf_is_valid(second_reader_bufnr), "reader should recreate after close")
assert(
  vim.api.nvim_buf_get_name(second_reader_bufnr) == "nvim-browser-reader://Example",
  "reader buffer names should be reusable after close"
)

vim.cmd("vsplit")
local image_win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_width(image_win, 52)
vim.api.nvim_win_set_height(image_win, 14)
terminal._test.set_test_window(image_win)
local image_command = terminal._test.command_for_window({ "nvbrowser", "show-image", "/tmp/image.png", "--fit", "contain" })
assert(vim.tbl_contains(image_command, "--columns"), "show-image should receive preview columns")
assert(vim.tbl_contains(image_command, "--rows"), "show-image should receive preview rows")
assert(vim.tbl_contains(image_command, "--width"), "show-image should receive preview pixel width")
assert(vim.tbl_contains(image_command, "--height"), "show-image should receive preview pixel height")
assert(vim.tbl_contains(image_command, "50"), "show-image columns should come from preview width minus borders")
assert(vim.tbl_contains(image_command, "12"), "show-image rows should come from preview height minus borders")

terminal._test.set_mode("serve")
local serve_command = terminal._test.command_for_window({ "nvbrowser", "serve", "--output", "kitty-unicode", "--url", "https://example.com" })
assert(vim.tbl_contains(serve_command, "--rows"), "serve should receive preview rows")
assert(vim.tbl_contains(serve_command, "11"), "serve rows should reserve one footer row below the rendered page")
local ansi_serve_command = terminal._test.command_for_window({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com" })
assert(vim.tbl_contains(ansi_serve_command, "--rows"), "ansi serve should receive startup preview rows")
assert(vim.tbl_contains(ansi_serve_command, "--width"), "ansi serve should receive startup preview pixel width")
assert(vim.tbl_contains(ansi_serve_command, "--height"), "ansi serve should receive startup preview pixel height")
assert(vim.tbl_contains(ansi_serve_command, "11"), "ansi serve rows should reserve the footer before the first frame")

terminal._test.apply_serve_response({
  id = 101,
  status = "ok",
  url = "https://example.com/long",
  title = "Example Domain",
  runtime = {
    output = "kitty-unicode",
    cells = { columns = 50, rows = 11 },
  },
  page = {
    scroll_y = 250,
    viewport_height = 600,
    document_height = 1600,
  },
})
local footer = terminal._test.preview_footer_line(80)
assert(footer:match("^ok | Example Domain | scroll 25%%"), "footer should expose status, title, and page scroll")
assert(footer:find("kitty%-unicode 50x11"), "footer should expose compact runtime geometry")
assert(terminal._test.preview_footer_line(120):find("https://example%.com/long"), "footer should expose the current URL")
assert(
  vim.fn.strchars(terminal._test.preview_footer_line(24)) <= 24,
  "footer truncation should respect the target column width"
)

terminal._test.set_pending_operation({ id = 202, label = "loading", target = "https://example.com/next" })
local pending_footer = terminal._test.preview_footer_line(120)
assert(pending_footer:match("^loading | https://example%.com/next | Esc stop"), "footer should show pending navigation feedback before a response")
terminal._test.clear_pending_operation(202)

local payload_bufnr = vim.api.nvim_create_buf(false, true)
terminal._test.apply_payload_to_buffer(
  payload_bufnr,
  nil,
  false,
  true,
  serve_command,
  { columns = 50, rows = 11, width = 500, height = 220 }
)
local payload_lines = vim.api.nvim_buf_get_lines(payload_bufnr, 0, -1, false)
assert(#payload_lines == 12, "kitty unicode serve buffers should include render rows plus one footer row")
assert(payload_lines[12] == terminal._test.preview_footer_line(50), "footer should be appended after render rows")

local ansi_bufnr = vim.api.nvim_create_buf(false, true)
terminal._test.apply_payload_to_buffer(
  ansi_bufnr,
  "one\ntwo\nthree",
  false,
  false,
  { "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com" },
  { columns = 20, rows = 2, width = 200, height = 40 }
)
local ansi_lines = vim.api.nvim_buf_get_lines(ansi_bufnr, 0, -1, false)
assert(#ansi_lines == 3, "ansi serve buffers should trim render rows and append one footer row")
assert(ansi_lines[3] == terminal._test.preview_footer_line(20), "ansi footer should be appended after render rows")

terminal._test.set_job_id(99)
terminal._test.set_cursor_addressable_preview(true)
vim.api.nvim_set_current_win(image_win)
vim.api.nvim_win_set_buf(image_win, payload_bufnr)
local footer_click_requests = {}
local original_chansend_for_footer = vim.fn.chansend
vim.fn.chansend = function(job_id, payload)
  table.insert(footer_click_requests, { job_id = job_id, payload = payload })
  return 1
end

local expected_mouse_point = terminal.viewport_point_for_cell(6, 25, { columns = 50, rows = 11, width = 500, height = 220 })
assert(terminal.click_mouse({ winid = image_win, line = 6, column = 25 }) == true, "mouse click should send a browser click")
local mouse_click_seen = false
for _, request in ipairs(footer_click_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "click_point" and decoded.x == expected_mouse_point.x and decoded.y == expected_mouse_point.y then
    mouse_click_seen = true
  end
end
assert(mouse_click_seen, "mouse click should map preview cells to viewport pixels")

footer_click_requests = {}
assert(terminal.click_mouse({ winid = image_win, line = 12, column = 25 }) == false, "mouse click on footer should be ignored")
assert(#footer_click_requests == 0, "footer mouse clicks should not reach the serve backend")

footer_click_requests = {}
assert(terminal.click_mouse({ winid = second_bufnr, line = 6, column = 25 }) == false, "mouse click from another window should be ignored")
assert(#footer_click_requests == 0, "wrong-window mouse clicks should not reach the serve backend")

vim.api.nvim_win_set_cursor(image_win, { 12, 0 })
assert(terminal.click_here() == false, "clicking the footer row should not send a browser click")
assert(#footer_click_requests == 0, "footer clicks should not reach the serve backend")
vim.fn.chansend = original_chansend_for_footer

terminal.close()
local original_jobstart = vim.fn.jobstart
local original_chansend = vim.fn.chansend
local original_jobstop = vim.fn.jobstop
local original_termopen = vim.fn.termopen
local fake_timers = {}
terminal._test.set_timer_factory(function()
  local timer = {
    starts = {},
    stopped = false,
    closed = false,
  }
  function timer:start(timeout, repeat_ms, callback)
    table.insert(self.starts, { timeout = timeout, repeat_ms = repeat_ms })
    self.callback = callback
  end
  function timer:stop()
    self.stopped = true
  end
  function timer:close()
    self.closed = true
  end
  table.insert(fake_timers, timer)
  return timer
end)
local jobstart_calls = {}
local sent_requests = {}
local jobstop_calls = {}
local termopen_calls = {}
local serve_stdout = nil
vim.fn.jobstart = function(command, opts)
  table.insert(jobstart_calls, command)
  serve_stdout = opts and opts.on_stdout or nil
  return 1234
end
vim.fn.chansend = function(job_id, payload)
  table.insert(sent_requests, { job_id = job_id, payload = payload })
  return 1
end
vim.fn.jobstop = function()
  table.insert(jobstop_calls, true)
  return 1
end
vim.fn.termopen = function(command)
  table.insert(termopen_calls, command)
  return 5678
end

terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com" })
local first_state = terminal.state()
assert(#fake_timers == 1, "serve sessions should start a live refresh timer by default")
assert(fake_timers[1].starts[1].timeout == 1500, "live refresh should use the default interval as its initial delay")
assert(fake_timers[1].starts[1].repeat_ms == 1500, "live refresh should repeat at the configured interval")
sent_requests = {}
fake_timers[1].callback()
assert(vim.wait(1000, function()
  for _, request in ipairs(sent_requests) do
    local ok, decoded = pcall(vim.json.decode, request.payload)
    if ok and decoded.type == "capture" then
      return true
    end
  end
  return false
end), "live refresh timer should send capture requests for active serve sessions")
local live_capture_id = terminal.state().live_refresh_request_id
assert(live_capture_id ~= nil, "live refresh should track an in-flight capture request")
assert(terminal._test.response_handler_count() == 1, "live refresh should register one response handler")

sent_requests = {}
assert(terminal.navigate("https://example.com/new") == true, "navigation should be allowed while a live capture is in flight")
serve_stdout(nil, { vim.json.encode({
  id = live_capture_id,
  status = "ok",
  payload = "stale frame",
  url = "https://example.com/stale",
  title = "Stale Capture",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().live_refresh_request_id == nil
end), "late live capture responses should clear in-flight capture state")
assert(
  terminal.state().current_title ~= "Stale Capture",
  "late live capture responses should not overwrite navigation-pending preview metadata"
)
assert(
  terminal.state().pending_operation ~= nil,
  "late live capture responses should not clear navigation pending feedback"
)
assert(terminal._test.response_handler_count() == 0, "stale live capture handling should remove the capture response handler")
terminal._test.clear_pending_operation(terminal.state().pending_operation.id)

sent_requests = {}
terminal.refresh()
local manual_capture_seen = false
local manual_resize_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "capture" then
    manual_capture_seen = true
  end
  if ok and decoded.type == "resize" then
    manual_resize_seen = true
  end
end
assert(manual_capture_seen, "manual refresh should send a capture request for active serve sessions")
assert(not manual_resize_seen, "manual refresh should not send a separate resize capture")
assert(terminal.state().live_refresh_request_id ~= nil, "manual refresh capture should be tracked as in-flight capture")
assert(terminal._test.response_handler_count() == 1, "manual refresh capture should register one response handler")
local manual_capture_count = 0
fake_timers[1].callback()
vim.wait(50)
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "capture" then
    manual_capture_count = manual_capture_count + 1
  end
end
assert(manual_capture_count == 1, "live refresh should not send a second capture while manual refresh is in flight")
sent_requests = {}
assert(terminal.refresh() == false, "manual refresh should not send another request while a capture is already in flight")
assert(#sent_requests == 0, "manual refresh should not send resize while a capture is already in flight")
terminal._test.clear_in_flight_capture()

sent_requests = {}
terminal._test.set_pending_operation({ id = 777, label = "loading", target = "https://example.com/pending" })
fake_timers[1].callback()
vim.wait(50)
local capture_while_pending = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "capture" then
    capture_while_pending = true
  end
end
assert(not capture_while_pending, "live refresh should not send capture while an operation is pending")
terminal._test.clear_pending_operation(777)

terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.org" })
local second_state = terminal.state()

assert(#jobstart_calls == 1, "opening a new URL in an active serve session should reuse the existing job")
assert(#jobstop_calls == 0, "serve URL reuse should not stop the existing backend job")
assert(second_state.bufnr == first_state.bufnr, "serve URL reuse should keep the same preview buffer")
assert(second_state.job_id == first_state.job_id, "serve URL reuse should keep the same backend job")
assert(second_state.last_target == "https://example.org", "serve URL reuse should update the remembered target")
local navigate_seen = false
local quit_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "navigate" and decoded.url == "https://example.org" then
    navigate_seen = true
  end
  if ok and decoded.type == "quit" then
    quit_seen = true
  end
end
assert(navigate_seen, "serve URL reuse should send a navigate request to the active backend")
assert(not quit_seen, "serve URL reuse should not send quit to the active backend")
terminal._test.clear_pending_operation(terminal.state().pending_operation.id)

terminal.configure({ live_refresh = { enabled = false } })
assert(fake_timers[1].stopped == true and fake_timers[1].closed == true, "disabling live refresh should stop the active timer")
sent_requests = {}
fake_timers[1].callback()
vim.wait(50)
assert(#sent_requests == 0, "stopped live refresh timer callbacks should not send capture after disabling")
terminal.configure({ live_refresh = { enabled = true, interval_ms = 25 } })
assert(#fake_timers == 2, "re-enabling live refresh should start a replacement timer for the active serve session")
assert(fake_timers[2].starts[1].timeout == 25, "live refresh reconfiguration should apply the new interval")
sent_requests = {}
fake_timers[1].callback()
vim.wait(50)
assert(#sent_requests == 0, "old live refresh timer callbacks should not send capture after reconfiguration")

sent_requests = {}
fake_timers[2].callback()
local reconfigured_capture_id = nil
assert(vim.wait(1000, function()
  reconfigured_capture_id = terminal.state().live_refresh_request_id
  return reconfigured_capture_id ~= nil
end), "reconfigured live refresh should still track capture requests")
terminal.configure({ live_refresh = { enabled = false } })
assert(
  terminal.state().live_refresh_request_id == reconfigured_capture_id,
  "disabling live refresh should not forget an already in-flight capture"
)
assert(terminal.navigate("https://example.com/after-reconfigure") == true, "navigation should still work after live refresh reconfiguration")
serve_stdout(nil, { vim.json.encode({
  id = reconfigured_capture_id,
  status = "ok",
  payload = "stale after reconfigure",
  url = "https://example.com/stale-after-reconfigure",
  title = "Stale After Reconfigure",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().live_refresh_request_id == nil
end), "stale capture after reconfigure should clear in-flight capture state")
assert(
  terminal.state().current_title ~= "Stale After Reconfigure",
  "stale capture after reconfigure should not overwrite pending navigation metadata"
)
terminal._test.clear_pending_operation(terminal.state().pending_operation.id)
terminal.configure({ live_refresh = { enabled = true, interval_ms = 25 } })

jobstart_calls = {}
sent_requests = {}
local served_bufnr = second_state.bufnr
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--markdown", "/tmp/README.md" })
local markdown_state = terminal.state()
assert(#jobstart_calls == 1, "opening Markdown should start a replacement serve job so the backend can render HTML")
assert(markdown_state.bufnr ~= served_bufnr, "Markdown serve replacement should use a fresh preview buffer")
assert(fake_timers[1].stopped == true and fake_timers[1].closed == true, "serve replacement should stop the previous live refresh timer")

sent_requests = {}
terminal.close()
local closed_timer = fake_timers[#fake_timers]
assert(closed_timer.stopped == true and closed_timer.closed == true, "close should stop the active live refresh timer")
terminal.configure({ live_refresh = { enabled = false, interval_ms = 25 } })
local disabled_timer_count = #fake_timers
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com" })
assert(#fake_timers == disabled_timer_count, "disabled live refresh should not create a new timer")
terminal.configure({ live_refresh = { enabled = true, interval_ms = 25 } })
local hints_response = vim.json.encode({
  id = 1,
  status = "ok",
  payload = "frame",
  url = "https://example.com",
  hints = {
    {
      id = 1,
      hint_label = "a",
      kind = "link",
      label = "Docs",
      href = "https://example.com/docs",
      x = 120,
      y = 240,
      width = 80,
      height = 20,
      clickable = true,
      focusable = false,
    },
    {
      id = 2,
      hint_label = "s",
      kind = "button",
      label = "Search",
      x = 30,
      y = 40,
      width = 60,
      height = 20,
      clickable = true,
      focusable = true,
    },
  },
})
serve_stdout(nil, { hints_response, "" })
assert(vim.wait(1000, function()
  return #terminal.state().element_hints == 2
end), "serve hint response should populate element hints")

sent_requests = {}
assert(terminal.follow_hint("a") == true, "follow_hint should navigate link hints by href")
local link_navigate_seen = false
local link_click_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "navigate" and decoded.url == "https://example.com/docs" then
    link_navigate_seen = true
  end
  if ok and decoded.type == "click_point" then
    link_click_seen = true
  end
end
assert(link_navigate_seen, "link follow should send a navigate request")
assert(not link_click_seen, "link follow should not click coordinates when href is available")
assert(terminal.state().last_target == "https://example.com/docs", "link follow should update the remembered target")
assert(#terminal.state().element_hints == 0, "link follow should clear stale hints before the next frame")
assert(terminal.state().pending_operation ~= nil, "link follow should mark the navigation as pending")
assert(terminal._test.preview_footer_line(120):match("^loading | https://example%.com/docs | Esc stop"), "link follow should refresh the footer with loading feedback")

sent_requests = {}
local pending_request_id = terminal.state().pending_operation.id
assert(terminal.stop() == true, "stop should cancel a pending browser operation")
assert(terminal.state().pending_operation == nil, "stop should clear the pending browser operation")
assert(#jobstop_calls >= 1, "stop should terminate the serve job when a pending operation is stuck")
assert(terminal.state().mode == nil, "stop should mark the serve session inactive after terminating the job")
assert(terminal.state().serve_output == nil, "stop should clear stale serve output metadata")
assert(terminal._test.preview_footer_line(120):match("^stopped | https://example%.com/docs"), "stop should leave a stopped footer message")
local cancelled_response = vim.json.encode({
  id = pending_request_id,
  status = "ok",
  payload = "late frame",
  url = "https://example.com/docs",
  title = "Late Page",
})
serve_stdout(nil, { cancelled_response, "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title ~= "Late Page"
end), "cancelled operation responses should be ignored")

sent_requests = {}
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com" })
serve_stdout(nil, { hints_response, "" })
assert(vim.wait(1000, function()
  return #terminal.state().element_hints == 2
end), "serve hint response should repopulate element hints after navigation clears them")
sent_requests = {}
assert(terminal.follow_hint("s") == true, "follow_hint should fall back to click for non-link hints")
local fallback_click_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "click_point" and decoded.x == 30 and decoded.y == 40 then
    fallback_click_seen = true
  end
end
assert(fallback_click_seen, "non-link follow fallback should send a coordinate click")

sent_requests = {}
vim.cmd("doautocmd VimResized")
local resize_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "resize" then
    resize_seen = true
  end
end
assert(resize_seen, "active serve sessions should resize when Neovim is resized")

sent_requests = {}
vim.cmd("doautocmd WinResized")
local win_resize_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "resize" then
    win_resize_seen = true
  end
end
assert(win_resize_seen, "active serve sessions should resize when the preview window changes size")

sent_requests = {}
assert(terminal.input_text("focused text") == true, "focused text input should reach the active serve backend")
assert(terminal.press_key("Tab", { modifiers = { "shift" } }) == true, "modified key presses should reach the active serve backend")
local text_input_seen = false
local shifted_tab_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "text_input" and decoded.text == "focused text" then
    text_input_seen = true
  end
  if ok and decoded.type == "key_press" and decoded.key == "Tab" and decoded.modifiers[1] == "shift" then
    shifted_tab_seen = true
  end
end
assert(text_input_seen, "focused text input should emit a text_input JSONL request")
assert(shifted_tab_seen, "modified key presses should emit modifiers in the key_press JSONL request")

local reused_bufnr = second_state.bufnr
terminal.open({ "nvbrowser", "show-image", "/tmp/image.png", "--output", "ansi" })
local replacement_state = terminal.state()
assert(#termopen_calls == 1, "non-serve previews should still replace an active serve session")
assert(replacement_state.bufnr ~= reused_bufnr, "non-serve previews should use a replacement buffer")

terminal._test.set_timer_factory(nil)
vim.fn.jobstart = original_jobstart
vim.fn.chansend = original_chansend
vim.fn.jobstop = original_jobstop
vim.fn.termopen = original_termopen
terminal.close()

vim.api.nvim_chan_send = original_nvim_chan_send
vim.api.nvim_echo = original_echo
