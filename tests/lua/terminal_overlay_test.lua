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

terminal.close()
local original_jobstart = vim.fn.jobstart
local original_chansend = vim.fn.chansend
local original_jobstop = vim.fn.jobstop
local original_termopen = vim.fn.termopen
local jobstart_calls = {}
local sent_requests = {}
local jobstop_calls = {}
local termopen_calls = {}
vim.fn.jobstart = function(command)
  table.insert(jobstart_calls, command)
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

jobstart_calls = {}
sent_requests = {}
local served_bufnr = second_state.bufnr
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--markdown", "/tmp/README.md" })
local markdown_state = terminal.state()
assert(#jobstart_calls == 1, "opening Markdown should start a replacement serve job so the backend can render HTML")
assert(markdown_state.bufnr ~= served_bufnr, "Markdown serve replacement should use a fresh preview buffer")

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

local reused_bufnr = second_state.bufnr
terminal.open({ "nvbrowser", "show-image", "/tmp/image.png", "--output", "ansi" })
local replacement_state = terminal.state()
assert(#termopen_calls == 1, "non-serve previews should still replace an active serve session")
assert(replacement_state.bufnr ~= reused_bufnr, "non-serve previews should use a replacement buffer")

vim.fn.jobstart = original_jobstart
vim.fn.chansend = original_chansend
vim.fn.jobstop = original_jobstop
vim.fn.termopen = original_termopen
terminal.close()

vim.api.nvim_chan_send = original_nvim_chan_send
vim.api.nvim_echo = original_echo
