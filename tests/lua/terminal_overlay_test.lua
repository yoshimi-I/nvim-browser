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

_G.nvim_browser_original_tmux_env_for_escape = vim.env.TMUX
vim.env.TMUX = nil
_G.nvim_browser_raw_kitty_payload = "\27_Ga=T,f=100,m=0;abc\27\\"
assert(terminal._test.terminal_escape(_G.nvim_browser_raw_kitty_payload) == _G.nvim_browser_raw_kitty_payload, "terminal escape should leave payloads raw outside tmux")
assert(terminal._test.terminal_escape(nil) == nil, "terminal escape should preserve nil payloads")
assert(terminal._test.terminal_escape("") == "", "terminal escape should preserve empty payloads")
vim.env.TMUX = ""
assert(terminal._test.terminal_escape(_G.nvim_browser_raw_kitty_payload) == _G.nvim_browser_raw_kitty_payload, "terminal escape should treat empty TMUX as outside tmux")
vim.env.TMUX = "/tmp/tmux-501/default,123,0"
_G.nvim_browser_tmux_wrapped_payload = terminal._test.terminal_escape(_G.nvim_browser_raw_kitty_payload)
assert(
  _G.nvim_browser_tmux_wrapped_payload == "\27Ptmux;\27\27_Ga=T,f=100,m=0;abc\27\27\\\27\\",
  "terminal escape should wrap raw Kitty payloads once for tmux passthrough"
)
assert(_G.nvim_browser_tmux_wrapped_payload:find("\27Ptmux;\27Ptmux;", 1, true) == nil, "tmux wrapping should not contain nested tmux wrappers")
vim.env.TMUX = _G.nvim_browser_original_tmux_env_for_escape

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
assert(many_labeled[1].hint_label == "aa", "large hint sets should use fixed-width labels")
assert(many_labeled[2].hint_label == "as", "fixed-width labels should stay keyboard-oriented")
assert(many_labeled[27].hint_label == "sa", "large hint labels should continue in keyboard order")
for outer = 1, #many_labeled do
  for inner = 1, #many_labeled do
    if outer ~= inner then
      local outer_label = many_labeled[outer].hint_label
      local inner_label = many_labeled[inner].hint_label
      assert(
        inner_label:sub(1, #outer_label) ~= outer_label,
        "generated hint labels should be prefix-free for transient hint mode"
      )
    end
  end
end

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
assert(terminal.state().last_find_match_count == nil, "failed find responses should clear stale find match count")

local warnings = {}
local original_echo = vim.api.nvim_echo
vim.api.nvim_echo = function(chunks)
  if chunks[1][2] == "WarningMsg" then
    table.insert(warnings, chunks[1][1])
  end
end

terminal._test.handle_find_text_response({ status = "ok", found = false, match_count = 0 })
assert(terminal.state().last_find_found == false, "not-found responses should update find state to false")
assert(terminal.state().last_find_match_count == 0, "not-found responses should store a zero find match count")
assert(
  terminal._test.preview_footer_line(120):match("find: 0 matches"),
  "preview footer should show zero find matches"
)
assert(warnings[#warnings] == "nvim-browser: text was not found", "not-found responses should warn")

terminal._test.handle_find_text_response({ status = "ok", found = true, match_count = 3 })
assert(terminal.state().last_find_found == true, "found responses should update find state to true")
assert(terminal.state().last_find_match_count == 3, "found responses should store a find match count")
assert(
  terminal._test.preview_footer_line(120):match("find: 3 matches"),
  "preview footer should show plural find matches"
)
terminal._test.handle_find_text_response({ status = "ok", found = true, match_count = 1 })
assert(
  terminal._test.preview_footer_line(120):match("find: 1 match"),
  "preview footer should show singular find match"
)
terminal._test.apply_serve_response({
  id = 97,
  status = "ok",
  payload = "new page frame",
  url = "https://example.com/new-page",
  title = "New Page",
})
assert(terminal.state().last_find_found == nil, "content-changing responses should clear stale find state")
assert(terminal.state().last_find_match_count == nil, "content-changing responses should clear stale find match count")

terminal._test.apply_serve_response({
  id = 98,
  status = "ok",
  payload = "frame with hint failure",
  hint_error = "hint extraction failed",
  hints = {},
})
assert(terminal.state().hint_error == "hint extraction failed", "serve responses should store hint extraction failures")
assert(#terminal.state().element_hints == 0, "hint extraction failures should keep active hints empty")

terminal._test.apply_serve_response({
  id = 99,
  status = "ok",
  url = "https://example.com/long",
  runtime = {
    protocol_version = 9,
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
assert(runtime_info.protocol_version == 9, "runtime metadata should preserve protocol version")
assert(runtime_info.output == "kitty-unicode", "runtime metadata should preserve output mode")
assert(runtime_info.cells.columns == 80, "runtime metadata should preserve preview columns")
assert(runtime_info.viewport.width == 800, "runtime metadata should preserve viewport width")
terminal._test.apply_serve_response({
  id = 99,
  status = "ok",
  payload = "focused frame",
  focused = {
    kind = "input",
    label = "Search",
    value = "hello",
    focusable = true,
    submittable = true,
  },
})
local focused = terminal.state().focused_element
assert(focused ~= nil, "serve responses should store focused element metadata")
assert(focused.kind == "input", "focused metadata should preserve element kind")
assert(focused.label == "Search", "focused metadata should preserve the readable label")
assert(focused.value == "hello", "focused metadata should preserve input value")
assert(focused.submittable == true, "focused metadata should preserve submit capability")
assert(
  terminal._test.preview_footer_line(120):match("focus=input Search"),
  "preview footer should include focused element metadata"
)
terminal._test.apply_serve_response({
  id = 99,
  status = "ok",
  payload = "frame without focused metadata",
})
assert(
  terminal.state().focused_element ~= nil,
  "serve responses without a focused field should preserve existing focused metadata"
)
terminal._test.apply_serve_response({
  id = 99,
  status = "ok",
  payload = "frame with no active focused element",
  focused = vim.NIL,
})
assert(
  terminal.state().focused_element == nil,
  "serve responses with focused=null should clear focused metadata"
)
terminal._test.apply_serve_response({
  id = 100,
  status = "ok",
  payload = "runtime frame",
  runtime = {
    protocol_version = 9,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "kitty-unicode",
    cells = { columns = 40, rows = 10 },
    viewport = { width = 360, height = 140, device_scale_factor = 1 },
  },
})
local rendered_frame_geometry = terminal.state().rendered_frame_geometry
assert(rendered_frame_geometry ~= nil, "ok frame responses with payload should store rendered frame geometry")
assert(rendered_frame_geometry.columns == 40, "rendered frame geometry should preserve runtime columns")
assert(rendered_frame_geometry.rows == 10, "rendered frame geometry should preserve runtime rows")
assert(rendered_frame_geometry.width == 360, "rendered frame geometry should preserve runtime viewport width")
assert(rendered_frame_geometry.height == 140, "rendered frame geometry should preserve runtime viewport height")
terminal._test.set_element_hints({
  {
    id = 10,
    hint_label = "a",
    kind = "button",
    label = "Retry",
    x = 1,
    y = 2,
    width = 3,
    height = 4,
    clickable = true,
    focusable = true,
  },
}, rendered_frame_geometry)
terminal._test.set_pending_operation({ id = 101, label = "loading", target = "https://example.com/fail" })
terminal._test.apply_serve_response({ id = 101, status = "error", error = "navigation failed" })
assert(terminal.state().pending_operation == nil, "matching error responses should clear pending operations")
assert(terminal.state().status == "error", "error responses should store error status")
assert(terminal.state().status_error == "navigation failed", "error responses should store error text")
assert(
  terminal.state().rendered_frame_geometry == rendered_frame_geometry,
  "error responses should preserve the last good rendered frame geometry"
)
assert(#terminal.state().element_hints == 1, "error responses should preserve last good hints when geometry is unchanged")
terminal.close()
assert(terminal.state().page_metrics == nil, "closing a browser session should clear page metrics")
assert(terminal.state().runtime_metadata == nil, "closing a browser session should clear runtime metadata")
assert(terminal.state().rendered_frame_geometry == nil, "closing a browser session should clear rendered frame geometry")
assert(terminal.state().focused_element == nil, "closing a browser session should clear focused element metadata")
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

terminal._test.handle_reader_response({
  status = "error",
  error = "page text failed",
})
assert(not vim.api.nvim_buf_is_valid(reader_bufnr), "failed reader snapshots should delete stale reader buffers")
assert(terminal.state().reader_bufnr == nil, "failed reader snapshots should clear stale reader state")

terminal._test.handle_reader_response({
  status = "ok",
  text = {
    title = "Empty Reader",
    url = "https://example.com/empty",
    text = "",
    truncated = false,
  },
})
assert(terminal.state().reader_bufnr == nil, "empty reader snapshots should not create stale reader buffers")

terminal._test.handle_reader_response({
  status = "ok",
  text = {
    title = "Example",
    url = "https://example.com",
    text = "# Example\n\nBody text\n\n[Docs](https://example.com/docs)",
    truncated = false,
  },
})
reader_bufnr = terminal.state().reader_bufnr
assert(reader_bufnr ~= nil and vim.api.nvim_buf_is_valid(reader_bufnr), "reader should recreate after a failed or empty snapshot")
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
assert(terminal._test.reader_url_at_line("[Docs](/docs)", 2) == "/docs", "reader URL extraction should read root-relative Markdown links")
assert(terminal._test.reader_url_at_line("[Next](guide/page.html)", 1) == "guide/page.html", "reader URL extraction should read relative Markdown links")
assert(terminal._test.reader_url_at_line("[Section](#intro)", 1) == "#intro", "reader URL extraction should read fragment Markdown links")
assert(terminal._test.reader_url_at_line("[Local](file:///tmp/page.html)", 1) == "file:///tmp/page.html", "reader URL extraction should read file URLs")
assert(terminal._test.reader_url_at_line("bare file:///tmp/page.html link", 1) == "file:///tmp/page.html", "reader URL extraction should read bare file URLs")
assert(terminal._test.reader_url_at_line("[Mail](mailto:a@example.com)", 1) == nil, "reader URL extraction should ignore unsupported schemes")
assert(terminal._test.reader_url_at_line("[Script](javascript:alert(1))", 1) == nil, "reader URL extraction should ignore javascript links")
assert(
  terminal._test.reader_url_at_line("[Mail](mailto:a@example.com) and [Docs](/docs)", 2) == nil,
  "reader URL extraction should not follow a supported link when the cursor is on an unsupported link"
)
assert(
  terminal._test.reader_url_at_line("[Bad](mailto:https://example.com) and [Docs](/docs)", 16) == nil,
  "reader URL extraction should not extract bare URLs nested inside unsupported Markdown links"
)
assert(
  terminal._test.reader_url_at_line("[Mail](mailto:a@example.com) and [Docs](/docs)", 31) == nil,
  "reader URL extraction should not guess when a line mixes unsupported and supported links"
)
assert(
  terminal._test.reader_url_at_line("single link away from cursor [Docs](/docs)", 1) == "/docs",
  "reader URL extraction should follow a single link on the line even when the cursor is outside it"
)
assert(
  terminal._test.reader_url_at_line("single absolute link [Docs](https://example.com/docs)", 1) == "https://example.com/docs",
  "reader URL extraction should not double-count a single Markdown absolute URL as an ambiguous line"
)
assert(
  terminal._test.reader_url_at_line("[One](/one) and [Two](/two)", 1) == "/one",
  "reader URL extraction should keep cursor-sensitive selection when multiple links exist"
)
assert(
  terminal._test.reader_url_at_line("[One](/one) and [Two](/two)", 14) == nil,
  "reader URL extraction should not guess when multiple links exist and the cursor is between links"
)

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
reader_requests = {}
vim.fn.chansend = function(job_id, payload)
  table.insert(reader_requests, { job_id = job_id, request = vim.json.decode(payload) })
  return 1
end
terminal._test.dispatch_serve_response_handler({
  id = followed_request.request.id,
  status = "ok",
  payload = "followed frame",
  url = "https://example.com/docs",
  title = "Docs",
})
vim.fn.chansend = original_chansend_for_reader
assert(reader_requests[1] ~= nil, "successful reader follow navigation should request a fresh reader snapshot")
assert(reader_requests[1].request.type == "page_text", "reader follow refresh should use a page_text request")
terminal._test.dispatch_serve_response_handler({
  id = reader_requests[1].request.id,
  status = "ok",
  text = {
    title = "Docs",
    url = "https://example.com/docs",
    text = "# Docs\n\n[Docs](https://example.com/docs)\n\nFollowed body",
    truncated = false,
  },
})
reader_lines = table.concat(vim.api.nvim_buf_get_lines(terminal.state().reader_bufnr, 0, -1, false), "\n")
assert(reader_lines:match("Followed body"), "reader follow should replace the reader buffer with the followed page text")

vim.api.nvim_set_current_buf(terminal.state().reader_bufnr)
vim.api.nvim_win_set_cursor(0, { 5, 1 })
reader_requests = {}
vim.fn.chansend = function(job_id, payload)
  table.insert(reader_requests, { job_id = job_id, request = vim.json.decode(payload) })
  return 1
end
assert(terminal.reader_follow() == "https://example.com/docs", "reader follow should send a navigation before a failed response")
vim.fn.chansend = original_chansend_for_reader
terminal._test.dispatch_serve_response_handler({
  id = reader_requests[1].request.id,
  status = "error",
  error = "navigation failed",
})
assert(#reader_requests == 1, "failed reader follow navigation should not request page_text")
reader_lines = table.concat(vim.api.nvim_buf_get_lines(terminal.state().reader_bufnr, 0, -1, false), "\n")
assert(reader_lines:match("Followed body"), "failed reader follow navigation should preserve existing reader content")

terminal._test.apply_serve_response({
  id = 222,
  status = "ok",
  url = "https://example.com/base/current.html",
  title = "Reader Base",
})
terminal._test.handle_reader_response({
  status = "ok",
  text = {
    title = "Reader Base",
    url = "https://example.com/base/current.html",
    text = "# Reader Base\n\n[Docs](/docs)\n\n[Next](guide/page.html)\n\n[Parent](../up/page.html)\n\n[Double](assets//app.js)\n\n[DotFragment](..#intro)\n\n[DotQuery](.?q=x)\n\n[Section](#intro)\n\n[Search](?q=x)",
  },
})
vim.api.nvim_set_current_buf(terminal.state().reader_bufnr)
reader_requests = {}
vim.fn.chansend = function(job_id, payload)
  table.insert(reader_requests, { job_id = job_id, request = vim.json.decode(payload) })
  return 1
end
vim.api.nvim_win_set_cursor(0, { 5, 1 })
assert(terminal.reader_follow() == "https://example.com/docs", "reader follow should resolve root-relative links from the current page")
vim.api.nvim_win_set_cursor(0, { 7, 1 })
assert(terminal.reader_follow() == "https://example.com/base/guide/page.html", "reader follow should resolve relative links from the current page directory")
vim.api.nvim_win_set_cursor(0, { 9, 1 })
assert(terminal.reader_follow() == "https://example.com/up/page.html", "reader follow should normalize parent segments in relative links")
vim.api.nvim_win_set_cursor(0, { 11, 1 })
assert(terminal.reader_follow() == "https://example.com/base/assets//app.js", "reader follow should preserve double slashes inside relative paths")
vim.api.nvim_win_set_cursor(0, { 13, 1 })
assert(terminal.reader_follow() == "https://example.com/#intro", "reader follow should normalize parent path segments before fragments")
vim.api.nvim_win_set_cursor(0, { 15, 1 })
assert(terminal.reader_follow() == "https://example.com/base/?q=x", "reader follow should normalize current-directory path segments before queries")
vim.api.nvim_win_set_cursor(0, { 17, 1 })
assert(terminal.reader_follow() == "https://example.com/base/current.html#intro", "reader follow should resolve fragments from the current page")
vim.api.nvim_win_set_cursor(0, { 19, 1 })
assert(terminal.reader_follow() == "https://example.com/base/current.html?q=x", "reader follow should resolve query-only links from the current page")
terminal._test.apply_serve_response({
  id = 223,
  status = "ok",
  url = "https://other.example/new/page.html",
  title = "Other Page",
})
vim.api.nvim_win_set_cursor(0, { 7, 1 })
assert(
  terminal.reader_follow() == "https://example.com/base/guide/page.html",
  "reader follow should keep resolving relative links against the reader snapshot URL after the active page changes"
)
vim.fn.chansend = original_chansend_for_reader
assert(reader_requests[1].request.url == "https://example.com/docs", "root-relative follow should send the resolved URL")
assert(reader_requests[2].request.url == "https://example.com/base/guide/page.html", "relative follow should send the resolved URL")
assert(reader_requests[3].request.url == "https://example.com/up/page.html", "parent-relative follow should send the normalized URL")
assert(reader_requests[4].request.url == "https://example.com/base/assets//app.js", "double-slash relative follow should preserve the URL path")
assert(reader_requests[5].request.url == "https://example.com/#intro", "dot-segment fragment follow should send the normalized URL")
assert(reader_requests[6].request.url == "https://example.com/base/?q=x", "dot-segment query follow should send the normalized URL")
assert(reader_requests[7].request.url == "https://example.com/base/current.html#intro", "fragment follow should send the resolved URL")
assert(reader_requests[8].request.url == "https://example.com/base/current.html?q=x", "query-only follow should send the resolved URL")
assert(reader_requests[9].request.url == "https://example.com/base/guide/page.html", "old reader buffers should keep using their snapshot URL as base")

terminal._test.apply_serve_response({
  id = 224,
  status = "ok",
  url = "file:///tmp/site/index.html",
  title = "Local Reader",
})
terminal._test.handle_reader_response({
  status = "ok",
  display_url = "file:///tmp/site/README.md#intro",
  text = {
    title = "Local Reader",
    url = "file:///tmp/nvbrowser-README-wrapper.html",
    text = "# Local Reader\n\n[Next](guide/page.html)\n\n[Parent](../docs/page.html)\n\n[Double](assets//app.js)\n\n[DotFragment](..#intro)\n\n[DotQuery](.?q=x)\n\n[Docs](/docs)\n\n[Section](#intro)\n\n[Search](?q=x)\n\n[Markdown](guide/notes.md)\n\n[Image](assets/pixel.png)\n\n[Pdf](manual.pdf)",
  },
})
_G.nvim_browser_display_reader_lines = vim.api.nvim_buf_get_lines(terminal.state().reader_bufnr, 0, 1, false)
assert(
  _G.nvim_browser_display_reader_lines[1] == "<file:///tmp/site/README.md#intro>",
  "reader header should prefer the serve display URL over an internal wrapper URL"
)
vim.api.nvim_set_current_buf(terminal.state().reader_bufnr)
reader_requests = {}
vim.fn.chansend = function(job_id, payload)
  table.insert(reader_requests, { job_id = job_id, request = vim.json.decode(payload) })
  return 1
end
vim.api.nvim_win_set_cursor(0, { 5, 1 })
assert(terminal.reader_follow() == "file:///tmp/site/guide/page.html", "reader follow should resolve relative file links from the display URL")
vim.api.nvim_win_set_cursor(0, { 7, 1 })
assert(terminal.reader_follow() == "file:///tmp/docs/page.html", "reader follow should normalize parent segments in file links")
vim.api.nvim_win_set_cursor(0, { 9, 1 })
assert(terminal.reader_follow() == "file:///tmp/site/assets//app.js", "reader follow should preserve double slashes inside relative file paths")
vim.api.nvim_win_set_cursor(0, { 11, 1 })
assert(terminal.reader_follow() == "file:///tmp/#intro", "reader follow should normalize file parent path segments before fragments")
vim.api.nvim_win_set_cursor(0, { 13, 1 })
assert(terminal.reader_follow() == "file:///tmp/site/?q=x", "reader follow should normalize file current-directory path segments before queries")
vim.api.nvim_win_set_cursor(0, { 15, 1 })
assert(terminal.reader_follow() == "file:///docs", "reader follow should resolve root-relative file links")
vim.api.nvim_win_set_cursor(0, { 17, 1 })
assert(terminal.reader_follow() == "file:///tmp/site/README.md#intro", "reader follow should resolve file fragments from the display URL")
vim.api.nvim_win_set_cursor(0, { 19, 1 })
assert(terminal.reader_follow() == "file:///tmp/site/README.md?q=x", "reader follow should resolve file query-only links from the display URL")
vim.fn.chansend = original_chansend_for_reader
assert(reader_requests[1].request.type == "navigate", "local HTML reader follow should use normal navigation")
assert(reader_requests[1].request.url == "file:///tmp/site/guide/page.html", "local HTML reader follow should send the resolved file URL")
assert(reader_requests[7].request.type == "navigate_markdown", "Markdown fragment follow should use the Markdown preview wrapper")
assert(reader_requests[7].request.path == "/tmp/site/README.md", "Markdown fragment follow should send the display-URL-relative filesystem path")
assert(reader_requests[7].request.display_url == "file:///tmp/site/README.md#intro", "Markdown fragment follow should preserve the display-URL-relative URL")
assert(reader_requests[8].request.type == "navigate_markdown", "Markdown query follow should use the Markdown preview wrapper")
assert(reader_requests[8].request.path == "/tmp/site/README.md", "Markdown query follow should send the display-URL-relative filesystem path")
assert(reader_requests[8].request.display_url == "file:///tmp/site/README.md?q=x", "Markdown query follow should preserve the display-URL-relative URL")
vim.fn.chansend = function(job_id, payload)
  table.insert(reader_requests, { job_id = job_id, request = vim.json.decode(payload) })
  return 1
end
vim.api.nvim_win_set_cursor(0, { 21, 1 })
assert(terminal.reader_follow() == "file:///tmp/site/guide/notes.md", "reader follow should resolve local Markdown links")
vim.api.nvim_win_set_cursor(0, { 23, 1 })
assert(terminal.reader_follow() == "file:///tmp/site/assets/pixel.png", "reader follow should resolve local raster image links")
vim.api.nvim_win_set_cursor(0, { 25, 1 })
assert(terminal.reader_follow() == "file:///tmp/site/manual.pdf", "reader follow should resolve local PDF links")
vim.fn.chansend = original_chansend_for_reader
assert(reader_requests[9].request.type == "navigate_markdown", "local Markdown reader follow should use the Markdown preview wrapper")
assert(reader_requests[9].request.path == "/tmp/site/guide/notes.md", "local Markdown reader follow should send a filesystem path")
assert(reader_requests[10].request.type == "navigate_image", "local raster reader follow should use the image preview wrapper")
assert(reader_requests[10].request.path == "/tmp/site/assets/pixel.png", "local raster reader follow should send a filesystem path")
assert(reader_requests[10].request.fit == "original", "local raster reader follow should preserve the default image fit")
assert(reader_requests[11].request.type == "navigate", "local PDF reader follow should keep normal Chromium file navigation")
assert(reader_requests[11].request.url == "file:///tmp/site/manual.pdf", "local PDF reader follow should send the resolved file URL")

terminal._test.handle_reader_response({
  status = "ok",
  text = {
    title = "Localhost Reader",
    url = "file:///tmp/site/index.html",
    text = "# Localhost Reader\n\n[LocalhostMd](file://localhost/tmp/localhost.md)\n\n[MdFragment](file:///tmp/site/guide/notes.md#intro)\n\n[ImageQuery](file:///tmp/site/assets/pixel.png?size=1)",
  },
})
vim.api.nvim_set_current_buf(terminal.state().reader_bufnr)
reader_requests = {}
vim.fn.chansend = function(job_id, payload)
  table.insert(reader_requests, { job_id = job_id, request = vim.json.decode(payload) })
  return 1
end
vim.api.nvim_win_set_cursor(0, { 5, 1 })
assert(terminal.reader_follow() == "file://localhost/tmp/localhost.md", "reader follow should preserve localhost file URLs")
vim.api.nvim_win_set_cursor(0, { 7, 1 })
assert(terminal.reader_follow() == "file:///tmp/site/guide/notes.md#intro", "reader follow should preserve Markdown file fragments")
vim.api.nvim_win_set_cursor(0, { 9, 1 })
assert(terminal.reader_follow() == "file:///tmp/site/assets/pixel.png?size=1", "reader follow should preserve raster image file queries")
vim.fn.chansend = original_chansend_for_reader
assert(reader_requests[1].request.type == "navigate_markdown", "localhost Markdown file URLs should use the Markdown preview wrapper")
assert(reader_requests[1].request.path == "/tmp/localhost.md", "localhost Markdown file URLs should decode to the local filesystem path")
assert(reader_requests[2].request.type == "navigate_markdown", "Markdown file URLs with fragments should use the Markdown preview wrapper")
assert(reader_requests[2].request.path == "/tmp/site/guide/notes.md", "Markdown file fragments should send only the filesystem path to the wrapper")
assert(
  reader_requests[2].request.display_url == "file:///tmp/site/guide/notes.md#intro",
  "Markdown file fragments should preserve the full user-facing display URL"
)
assert(reader_requests[3].request.type == "navigate_image", "raster image file URLs with queries should use the image preview wrapper")
assert(reader_requests[3].request.path == "/tmp/site/assets/pixel.png", "raster image file queries should send only the filesystem path to the wrapper")
assert(
  reader_requests[3].request.display_url == "file:///tmp/site/assets/pixel.png?size=1",
  "raster image file queries should preserve the full user-facing display URL"
)

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

terminal._test.set_mode("serve")
terminal._test.set_job_id(99)
stale_reader_requests = {}
vim.fn.chansend = function(job_id, payload)
  table.insert(stale_reader_requests, { job_id = job_id, request = vim.json.decode(payload) })
  return 1
end
assert(terminal.reader() == true, "first overlapping reader request should be sent")
assert(terminal.reader() == true, "second overlapping reader request should be sent")
vim.fn.chansend = original_chansend_for_reader
stale_reader_first_id = stale_reader_requests[1].request.id
stale_reader_second_id = stale_reader_requests[2].request.id
assert(stale_reader_first_id < stale_reader_second_id, "reader requests should have increasing ids")
terminal._test.dispatch_serve_response_handler({
  id = stale_reader_second_id,
  status = "ok",
  text = {
    title = "Fresh Reader",
    url = "https://example.com/fresh",
    text = "# Fresh Reader\n\nFresh body",
    truncated = false,
  },
})
fresh_reader_bufnr = terminal.state().reader_bufnr
assert(fresh_reader_bufnr ~= nil and vim.api.nvim_buf_is_valid(fresh_reader_bufnr), "fresh reader response should create a buffer")
terminal._test.dispatch_serve_response_handler({
  id = stale_reader_first_id,
  status = "error",
  error = "late reader failure",
})
assert(vim.api.nvim_buf_is_valid(fresh_reader_bufnr), "late stale reader failures should not delete newer reader buffers")
fresh_reader_lines = table.concat(vim.api.nvim_buf_get_lines(fresh_reader_bufnr, 0, -1, false), "\n")
assert(fresh_reader_lines:match("Fresh Reader"), "late stale reader failures should preserve newer reader content")

vim.cmd("vsplit")
local image_win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_width(image_win, 52)
vim.api.nvim_win_set_height(image_win, 14)
terminal._test.set_test_window(image_win)
local image_command = terminal._test.command_for_window({ "nvbrowser", "show-image", "/tmp/image.png", "--fit", "contain" })
local function command_option(command, option)
  for index, value in ipairs(command) do
    if value == option then
      return command[index + 1]
    end
  end
  return nil
end

assert(vim.tbl_contains(image_command, "--columns"), "show-image should receive preview columns")
assert(vim.tbl_contains(image_command, "--rows"), "show-image should receive preview rows")
assert(vim.tbl_contains(image_command, "--width"), "show-image should receive preview pixel width")
assert(vim.tbl_contains(image_command, "--height"), "show-image should receive preview pixel height")
assert(vim.tbl_contains(image_command, "50"), "show-image columns should come from preview width minus borders")
assert(vim.tbl_contains(image_command, "12"), "show-image rows should come from preview height minus borders")
assert(command_option(image_command, "--width") == "500", "show-image width should default to 10px cells")
assert(command_option(image_command, "--height") == "240", "show-image height should default to 20px cells")

terminal._test.set_mode("serve")
local serve_command = terminal._test.command_for_window({ "nvbrowser", "serve", "--output", "kitty-unicode", "--url", "https://example.com" })
assert(vim.tbl_contains(serve_command, "--rows"), "serve should receive preview rows")
assert(vim.tbl_contains(serve_command, "11"), "serve rows should reserve one footer row below the rendered page")
local ansi_serve_command = terminal._test.command_for_window({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com" })
assert(vim.tbl_contains(ansi_serve_command, "--rows"), "ansi serve should receive startup preview rows")
assert(vim.tbl_contains(ansi_serve_command, "--width"), "ansi serve should receive startup preview pixel width")
assert(vim.tbl_contains(ansi_serve_command, "--height"), "ansi serve should receive startup preview pixel height")
assert(vim.tbl_contains(ansi_serve_command, "11"), "ansi serve rows should reserve the footer before the first frame")
assert(command_option(ansi_serve_command, "--width") == "500", "serve width should default to 10px cells")
assert(command_option(ansi_serve_command, "--height") == "220", "serve height should reserve footer rows before applying 20px cells")

vim.cmd("vsplit")
_G.nvim_browser_guided_calibration_win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_width(_G.nvim_browser_guided_calibration_win, 84)
vim.api.nvim_win_set_height(_G.nvim_browser_guided_calibration_win, 30)
terminal._test.set_test_window(_G.nvim_browser_guided_calibration_win)
_G.nvim_browser_guided_calibration_bufnr = vim.api.nvim_win_get_buf(_G.nvim_browser_guided_calibration_win)
vim.bo[_G.nvim_browser_guided_calibration_bufnr].modifiable = true
vim.api.nvim_buf_set_lines(
  _G.nvim_browser_guided_calibration_bufnr,
  0,
  -1,
  false,
  vim.fn["repeat"]({ string.rep(" ", 82) }, 30)
)
terminal._test.set_mode("serve")
terminal._test.set_cursor_addressable_preview(true)
_G.nvim_browser_guided_calibration_command =
  terminal._test.command_for_window({ "nvbrowser", "serve", "--output", "ansi", "--url", "file:///tmp/nvim-browser/data/html/calibrate.html" })
terminal._test.apply_serve_response({
  id = 705,
  status = "ok",
  url = "file:///tmp/nvim-browser/data/html/calibrate.html",
  payload = "guided calibration frame",
  runtime = {
    protocol_version = 9,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "ansi",
    cells = {
      columns = tonumber(command_option(_G.nvim_browser_guided_calibration_command, "--columns")),
      rows = tonumber(command_option(_G.nvim_browser_guided_calibration_command, "--rows")),
    },
    viewport = {
      width = tonumber(command_option(_G.nvim_browser_guided_calibration_command, "--width")),
      height = tonumber(command_option(_G.nvim_browser_guided_calibration_command, "--height")),
      device_scale_factor = 1,
    },
  },
})
vim.api.nvim_win_set_cursor(_G.nvim_browser_guided_calibration_win, { 12, 40 })
_G.nvim_browser_guided_calibration = terminal.guided_calibration_at_cursor({ target_x = 405, target_y = 230 })
assert(type(_G.nvim_browser_guided_calibration) == "table", "guided calibration should return computed cell pixels")
assert(_G.nvim_browser_guided_calibration.cell_width_px == 10, "guided calibration should compute cell width from cursor column")
assert(_G.nvim_browser_guided_calibration.cell_height_px == 20, "guided calibration should compute cell height from cursor row")
assert(_G.nvim_browser_guided_calibration.row == 12, "guided calibration should report the cursor row used")
assert(_G.nvim_browser_guided_calibration.column == 41, "guided calibration should report the cursor column used")

terminal._test.set_cursor_addressable_preview(false)
_G.nvim_browser_unavailable_guided, _G.nvim_browser_unavailable_guided_err =
  terminal.guided_calibration_at_cursor({ target_x = 405, target_y = 230 })
assert(_G.nvim_browser_unavailable_guided == false, "guided calibration should fail when the preview is not cursor-addressable")
assert(
  _G.nvim_browser_unavailable_guided_err == "guided calibration requires an active cursor-addressable calibration preview",
  "guided calibration should explain inactive cursor-addressable previews"
)
terminal._test.set_cursor_addressable_preview(true)

terminal._test.apply_serve_response({
  id = 706,
  status = "ok",
  url = "https://example.com/not-calibration",
  payload = "non calibration frame",
  runtime = {
    protocol_version = 9,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "ansi",
    cells = { columns = 82, rows = 27 },
    viewport = { width = 820, height = 540, device_scale_factor = 1 },
  },
})
_G.nvim_browser_wrong_target_guided, _G.nvim_browser_wrong_target_err =
  terminal.guided_calibration_at_cursor({ target_x = 405, target_y = 230 })
assert(_G.nvim_browser_wrong_target_guided == false, "guided calibration should fail outside the calibration fixture")
assert(
  _G.nvim_browser_wrong_target_err == "guided calibration requires the bundled calibration fixture",
  "guided calibration should explain non-calibration targets"
)

terminal._test.apply_serve_response({
  id = 707,
  status = "ok",
  url = "https://example.com/stale-frame",
  payload = "stale non calibration frame",
  runtime = {
    protocol_version = 9,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "ansi",
    cells = {
      columns = tonumber(command_option(_G.nvim_browser_guided_calibration_command, "--columns")),
      rows = tonumber(command_option(_G.nvim_browser_guided_calibration_command, "--rows")),
    },
    viewport = {
      width = tonumber(command_option(_G.nvim_browser_guided_calibration_command, "--width")),
      height = tonumber(command_option(_G.nvim_browser_guided_calibration_command, "--height")),
      device_scale_factor = 1,
    },
  },
})
terminal._test.apply_serve_response({
  id = 708,
  status = "ok",
  url = "file:///tmp/nvim-browser/data/html/calibrate.html",
  runtime = {
    protocol_version = 9,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "ansi",
    cells = {
      columns = tonumber(command_option(_G.nvim_browser_guided_calibration_command, "--columns")),
      rows = tonumber(command_option(_G.nvim_browser_guided_calibration_command, "--rows")),
    },
    viewport = {
      width = tonumber(command_option(_G.nvim_browser_guided_calibration_command, "--width")),
      height = tonumber(command_option(_G.nvim_browser_guided_calibration_command, "--height")),
      device_scale_factor = 1,
    },
  },
})
_G.nvim_browser_stale_url_guided, _G.nvim_browser_stale_url_err =
  terminal.guided_calibration_at_cursor({ target_x = 405, target_y = 230 })
assert(_G.nvim_browser_stale_url_guided == false, "guided calibration should reject stale non-fixture rendered frames")
assert(
  _G.nvim_browser_stale_url_err == "guided calibration requires a fresh calibration fixture frame",
  "guided calibration should explain stale rendered fixture URLs"
)
pcall(vim.api.nvim_win_close, _G.nvim_browser_guided_calibration_win, true)
vim.api.nvim_set_current_win(image_win)
vim.api.nvim_win_set_width(image_win, 52)
vim.api.nvim_win_set_height(image_win, 14)
terminal._test.set_test_window(image_win)

terminal.configure({
  viewport = {
    cell_width_px = 9,
    cell_height_px = 15,
  },
})
local custom_image_command = terminal._test.command_for_window({ "nvbrowser", "show-image", "/tmp/image.png", "--fit", "contain" })
assert(command_option(custom_image_command, "--width") == "450", "show-image width should use configured cell width")
assert(command_option(custom_image_command, "--height") == "180", "show-image height should use configured cell height")
local custom_serve_command = terminal._test.command_for_window({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com" })
assert(command_option(custom_serve_command, "--width") == "450", "serve width should use configured cell width")
assert(command_option(custom_serve_command, "--height") == "165", "serve height should use configured cell height after footer reservation")

_G.nvim_browser_original_columns_for_oversized = vim.o.columns
_G.nvim_browser_original_lines_for_oversized = vim.o.lines
vim.o.columns = 420
vim.o.lines = 330
_G.nvim_browser_oversized_win = image_win
terminal._test.set_test_window(_G.nvim_browser_oversized_win)
_G.nvim_browser_kitty_unicode_cell_limit = terminal._test.kitty_unicode_cell_limit()
_G.nvim_browser_oversized_serve_command = terminal._test.command_for_window({ "nvbrowser", "serve", "--output", "kitty-unicode", "--url", "https://example.com" })
assert(tonumber(command_option(_G.nvim_browser_oversized_serve_command, "--columns")) <= _G.nvim_browser_kitty_unicode_cell_limit, "kitty-unicode serve columns should not exceed addressable placeholder columns")
assert(tonumber(command_option(_G.nvim_browser_oversized_serve_command, "--rows")) <= _G.nvim_browser_kitty_unicode_cell_limit, "kitty-unicode serve rows should not exceed addressable placeholder rows")
_G.nvim_browser_explicit_oversized_serve_command = terminal._test.command_for_window({
  "nvbrowser",
  "serve",
  "--output",
  "kitty-unicode",
  "--columns",
  "999",
  "--rows",
  "999",
  "--width",
  "9990",
  "--height",
  "9990",
  "--url",
  "https://example.com",
})
assert(command_option(_G.nvim_browser_explicit_oversized_serve_command, "--columns") == command_option(_G.nvim_browser_oversized_serve_command, "--columns"), "kitty-unicode serve should replace explicit oversized columns")
assert(command_option(_G.nvim_browser_explicit_oversized_serve_command, "--rows") == command_option(_G.nvim_browser_oversized_serve_command, "--rows"), "kitty-unicode serve should replace explicit oversized rows")
assert(command_option(_G.nvim_browser_explicit_oversized_serve_command, "--width") == command_option(_G.nvim_browser_oversized_serve_command, "--width"), "kitty-unicode serve should replace explicit oversized width")
assert(command_option(_G.nvim_browser_explicit_oversized_serve_command, "--height") == command_option(_G.nvim_browser_oversized_serve_command, "--height"), "kitty-unicode serve should replace explicit oversized height")
_G.nvim_browser_explicit_oversized_browse_command = terminal._test.command_for_window({
  "nvbrowser",
  "browse",
  "--output",
  "kitty-unicode",
  "--columns",
  "999",
  "--rows",
  "999",
  "--width",
  "9990",
  "--height",
  "9990",
  "https://example.com",
})
assert(tonumber(command_option(_G.nvim_browser_explicit_oversized_browse_command, "--columns")) <= _G.nvim_browser_kitty_unicode_cell_limit, "kitty-unicode browse should replace explicit oversized columns")
assert(tonumber(command_option(_G.nvim_browser_explicit_oversized_browse_command, "--rows")) <= _G.nvim_browser_kitty_unicode_cell_limit, "kitty-unicode browse should replace explicit oversized rows")
terminal._test.apply_serve_response({
  id = 901,
  status = "ok",
  runtime = {
    output = "kitty-unicode",
  },
})
_G.nvim_browser_oversized_geometry = terminal.state().current_preview_geometry
assert(_G.nvim_browser_oversized_geometry.columns <= _G.nvim_browser_kitty_unicode_cell_limit, "current preview geometry should match capped kitty-unicode placeholder columns")
assert(_G.nvim_browser_oversized_geometry.rows <= _G.nvim_browser_kitty_unicode_cell_limit, "current preview geometry should match capped kitty-unicode placeholder rows")
vim.o.columns = _G.nvim_browser_original_columns_for_oversized
vim.o.lines = _G.nvim_browser_original_lines_for_oversized
terminal._test.set_test_window(image_win)

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

terminal._test.apply_serve_response({
  id = 1011,
  status = "ok",
  url = "https://example.com/fallback",
  title = "ANSI Fallback",
  runtime = {
    output = "ansi",
    output_label = "ANSI fallback",
    cells = { columns = 44, rows = 10 },
  },
})
assert(
  terminal._test.preview_footer_line(120):find("ANSI fallback 44x10", 1, true),
  "Zellij-safe ANSI previews should label the effective fallback output"
)
assert(
  terminal._test.preview_footer_line(36):find("ANSI fallback", 1, true),
  "Zellij-safe ANSI fallback labels should remain visible in narrow preview footers"
)

terminal._test.apply_serve_response({
  id = 102,
  status = "ok",
  download = {
    path = "/tmp/nvbrowser-downloads/report.pdf",
    suggested_filename = "report.pdf",
    status = "completed",
  },
})
assert(terminal.state().latest_download.path == "/tmp/nvbrowser-downloads/report.pdf", "download responses should store latest download metadata")
assert(#terminal.downloads() == 1, "download responses should append to download history")
assert(terminal.downloads()[1].path == "/tmp/nvbrowser-downloads/report.pdf", "download history should include completed download paths")
terminal._test.apply_serve_response({
  id = 103,
  status = "ok",
  download = {
    path = "/tmp/nvbrowser-downloads/archive.zip",
    suggested_filename = "archive.zip",
    status = "completed",
  },
})
local downloads = terminal.downloads()
assert(#downloads == 2, "download history should retain multiple completed downloads")
assert(downloads[2].path == "/tmp/nvbrowser-downloads/archive.zip", "download history should keep later downloads in order")
downloads[1].path = "/tmp/changed.pdf"
assert(terminal.downloads()[1].path == "/tmp/nvbrowser-downloads/report.pdf", "download history should return a defensive copy")
assert(terminal.state().latest_download.path == "/tmp/nvbrowser-downloads/archive.zip", "latest download should remain the most recent completed download")
assert(
  terminal._test.preview_footer_line(120):find("download=archive%.zip"),
  "footer should expose the latest completed download filename"
)
terminal._test.apply_serve_response({
  id = 104,
  status = "ok",
  download = {
    path = "/tmp/nvbrowser-downloads/partial.tmp",
    suggested_filename = "partial.tmp",
    status = "in_progress",
  },
})
assert(terminal.state().latest_download.path == "/tmp/nvbrowser-downloads/partial.tmp", "latest download should still reflect the last reported download metadata")
assert(#terminal.downloads() == 2, "download history should only retain completed downloads")
terminal._test.apply_serve_response({
  id = 105,
  status = "ok",
  download = {
    path = "/tmp/nvbrowser-downloads/missing-status.bin",
    suggested_filename = "missing-status.bin",
  },
})
assert(terminal.state().latest_download.path == "/tmp/nvbrowser-downloads/missing-status.bin", "latest download should still reflect download metadata without status")
assert(#terminal.downloads() == 2, "download history should require completed download status")

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
terminal._test.set_cursor_addressable_preview(false)
vim.api.nvim_set_current_win(image_win)
vim.api.nvim_win_set_buf(image_win, payload_bufnr)
terminal._test.apply_serve_response({
  id = 200,
  status = "ok",
  payload = "interactive frame",
  runtime = {
    protocol_version = 9,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "kitty-unicode",
    cells = { columns = 50, rows = 11 },
    viewport = { width = 450, height = 165, device_scale_factor = 1 },
  },
})
assert(terminal.state().cursor_addressable_preview == true, "kitty-unicode runtime output should mark previews cursor-addressable")
assert(
  terminal.state().current_preview_geometry ~= nil,
  "serve state should expose current preview geometry for click calibration diagnostics"
)
terminal._test.set_cursor_addressable_preview(false)
terminal._test.apply_serve_response({
  id = 201,
  status = "ok",
  runtime = {
    protocol_version = 9,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "ansi",
    cells = { columns = 50, rows = 11 },
    viewport = { width = 450, height = 165, device_scale_factor = 1 },
  },
})
assert(terminal.state().cursor_addressable_preview == true, "ansi runtime output should mark previews cursor-addressable")
terminal._test.set_cursor_addressable_preview(true)
terminal._test.apply_serve_response({
  id = 202,
  status = "ok",
  runtime = {
    protocol_version = 9,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "kitty",
    cells = { columns = 50, rows = 11 },
    viewport = { width = 450, height = 165, device_scale_factor = 1 },
  },
})
assert(terminal.state().cursor_addressable_preview == false, "kitty runtime output should mark previews non cursor-addressable")
terminal._test.set_cursor_addressable_preview(true)
terminal._test.apply_serve_response({
  id = 203,
  status = "ok",
  runtime = {
    protocol_version = 9,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    cells = { columns = 50, rows = 11 },
    viewport = { width = 450, height = 165, device_scale_factor = 1 },
  },
})
assert(terminal.state().cursor_addressable_preview == true, "runtime metadata without output should preserve cursor-addressability")
terminal._test.set_cursor_addressable_preview(false)
terminal._test.apply_serve_response({
  id = 204,
  status = "ok",
  runtime = {
    output = "unknown",
  },
})
assert(terminal.state().cursor_addressable_preview == false, "unknown runtime output should preserve cursor-addressability")
terminal._test.set_cursor_addressable_preview(false)
terminal._test.apply_serve_response({
  id = 205,
  status = "ok",
  runtime = {
    protocol_version = 9,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    cells = { columns = 50, rows = 11 },
    viewport = { width = 450, height = 165, device_scale_factor = 1 },
  },
})
assert(terminal.state().cursor_addressable_preview == false, "runtime metadata without output should preserve non cursor-addressable state")
terminal._test.set_cursor_addressable_preview(true)
terminal._test.apply_serve_response({
  id = 206,
  status = "ok",
  runtime = {
    output = "unknown",
  },
})
assert(terminal.state().cursor_addressable_preview == true, "unknown runtime output should preserve cursor-addressable state")
terminal._test.set_cursor_addressable_preview(true)
local footer_click_requests = {}
local original_chansend_for_footer = vim.fn.chansend
vim.fn.chansend = function(job_id, payload)
  table.insert(footer_click_requests, { job_id = job_id, payload = payload })
  return 1
end

terminal._test.apply_serve_response({
  id = 207,
  status = "ok",
  history = {
    can_go_back = false,
    can_go_forward = true,
  },
})
assert(terminal.state().browser_history.can_go_back == false, "serve history metadata should store back availability")
assert(terminal.state().browser_history.can_go_forward == true, "serve history metadata should store forward availability")
footer_click_requests = {}
assert(terminal.back() == false, "unavailable browser back should not send a request")
assert(#footer_click_requests == 0, "unavailable browser back should not reach the serve backend")
assert(terminal.forward() == true, "available browser forward should send a request")
_G.nvim_browser_forward_request_seen = false
_G.nvim_browser_forward_request_id = nil
for _, request in ipairs(footer_click_requests) do
  _G.nvim_browser_forward_decode_ok, _G.nvim_browser_forward_decoded = pcall(vim.json.decode, request.payload)
  if _G.nvim_browser_forward_decode_ok and _G.nvim_browser_forward_decoded.type == "forward" then
    _G.nvim_browser_forward_request_seen = true
    _G.nvim_browser_forward_request_id = _G.nvim_browser_forward_decoded.id
  end
end
assert(_G.nvim_browser_forward_request_seen, "available browser forward should reach the serve backend")
terminal._test.apply_serve_response({
  id = _G.nvim_browser_forward_request_id,
  status = "ok",
  payload = "forward frame",
  url = "https://example.com/forward",
  title = "Forward",
  runtime = {
    protocol_version = 9,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "kitty-unicode",
    cells = { columns = 50, rows = 11 },
    viewport = { width = 450, height = 165, device_scale_factor = 1 },
  },
  history = {
    can_go_back = true,
    can_go_forward = false,
  },
})
terminal._test.dispatch_serve_response_handler({
  id = _G.nvim_browser_forward_request_id,
  status = "ok",
})
terminal._test.apply_serve_response({
  id = 208,
  status = "ok",
})
assert(terminal.state().browser_history == nil, "missing serve history metadata should restore legacy navigation behavior")
footer_click_requests = {}
assert(terminal.back() == true, "browser back should remain available when history metadata is absent")
_G.nvim_browser_legacy_back_seen = false
_G.nvim_browser_legacy_back_request_id = nil
for _, request in ipairs(footer_click_requests) do
  _G.nvim_browser_legacy_back_decode_ok, _G.nvim_browser_legacy_back_decoded = pcall(vim.json.decode, request.payload)
  if _G.nvim_browser_legacy_back_decode_ok and _G.nvim_browser_legacy_back_decoded.type == "back" then
    _G.nvim_browser_legacy_back_seen = true
    _G.nvim_browser_legacy_back_request_id = _G.nvim_browser_legacy_back_decoded.id
  end
end
assert(_G.nvim_browser_legacy_back_seen, "legacy browser back should reach the serve backend")
_G.nvim_browser_legacy_back_response = {
  id = _G.nvim_browser_legacy_back_request_id,
  status = "ok",
}
terminal._test.apply_serve_response(_G.nvim_browser_legacy_back_response)
terminal._test.dispatch_serve_response_handler(_G.nvim_browser_legacy_back_response)

local function interactive_runtime(width, height)
  return {
    protocol_version = 9,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "kitty-unicode",
    cells = { columns = 50, rows = 11 },
    viewport = { width = width, height = height, device_scale_factor = 1 },
  }
end

local expected_mouse_point = terminal.viewport_point_for_cell(6, 25, { columns = 50, rows = 11, width = 450, height = 165 })
assert(terminal.click_mouse({ winid = image_win, line = 6, column = 25 }) == true, "mouse click should send a browser click")
local mouse_click_seen = false
local mouse_click_request_id = nil
_G.nvim_browser_mouse_click_request = nil
for _, request in ipairs(footer_click_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "click_point" and decoded.x == expected_mouse_point.x and decoded.y == expected_mouse_point.y then
    mouse_click_seen = true
    mouse_click_request_id = decoded.id
    _G.nvim_browser_mouse_click_request = decoded
  end
end
assert(mouse_click_seen, "mouse click should map preview cells to viewport pixels")
assert(
  _G.nvim_browser_mouse_click_request.click_count == nil,
  "single mouse clicks should omit click_count for protocol compatibility"
)
assert(terminal.state().pending_operation ~= nil, "mouse click should mark the browser click as pending")
assert(terminal.state().pending_operation.label == "click", "mouse click pending footer should use a click label")
assert(#terminal.state().element_hints == 0, "mouse click should clear stale hints while a capture is pending")
terminal._test.apply_serve_response({
  id = mouse_click_request_id,
  status = "ok",
  payload = "clicked frame",
  url = "https://example.com/clicked",
  title = "Clicked",
  runtime = interactive_runtime(450, 165),
})
assert(terminal.state().pending_operation == nil, "matching click response should clear pending click state")

footer_click_requests = {}
assert(
  terminal.double_click_mouse({ winid = image_win, line = 6, column = 25 }) == true,
  "mouse double-click should send a browser double-click"
)
_G.nvim_browser_mouse_double_click_seen = false
_G.nvim_browser_mouse_double_click_request_id = nil
for _, request in ipairs(footer_click_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if
    ok
    and decoded.type == "click_point"
    and decoded.x == expected_mouse_point.x
    and decoded.y == expected_mouse_point.y
    and decoded.click_count == 2
  then
    _G.nvim_browser_mouse_double_click_seen = true
    _G.nvim_browser_mouse_double_click_request_id = decoded.id
  end
end
assert(
  _G.nvim_browser_mouse_double_click_seen,
  "mouse double-click should map preview cells to viewport pixels with click_count=2"
)
assert(terminal.state().pending_operation ~= nil, "mouse double-click should mark the browser click as pending")
assert(terminal.state().pending_operation.label == "click", "mouse double-click pending footer should use a click label")
terminal._test.apply_serve_response({
  id = _G.nvim_browser_mouse_double_click_request_id,
  status = "ok",
  payload = "double-clicked frame",
  url = "https://example.com/double-clicked",
  title = "Double Clicked",
  runtime = interactive_runtime(450, 165),
})
assert(terminal.state().pending_operation == nil, "matching double-click response should clear pending click state")

footer_click_requests = {}
expected_drag_start = terminal.viewport_drag_point_for_cell(6, 10, { columns = 50, rows = 11, width = 450, height = 165 }, "start")
expected_drag_end = terminal.viewport_drag_point_for_cell(6, 25, { columns = 50, rows = 11, width = 450, height = 165 }, "end")
assert(terminal.select_region(6, 10, 6, 25) == true, "preview region selection should send a browser drag")
drag_seen = false
drag_request_id = nil
for _, request in ipairs(footer_click_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if
    ok
    and decoded.type == "drag_point"
    and decoded.start_x == expected_drag_start.x
    and decoded.start_y == expected_drag_start.y
    and decoded.end_x == expected_drag_end.x
    and decoded.end_y == expected_drag_end.y
  then
    drag_seen = true
    drag_request_id = decoded.id
  end
end
assert(drag_seen, "preview region selection should map two cells to a native drag request")
assert(terminal.state().pending_operation ~= nil, "preview region selection should mark the drag as pending")
assert(terminal.state().pending_operation.label == "select", "preview region selection pending footer should use a select label")
terminal._test.apply_serve_response({
  id = drag_request_id,
  status = "ok",
  payload = "selected frame",
  runtime = interactive_runtime(450, 165),
})
assert(terminal.state().pending_operation == nil, "matching drag response should clear pending select state")

function _G.nvim_browser_last_footer_request_of_type(kind)
  for index = #footer_click_requests, 1, -1 do
    local ok, decoded = pcall(vim.json.decode, footer_click_requests[index].payload)
    if ok and decoded.type == kind then
      return decoded
    end
  end
  return nil
end

footer_click_requests = {}
old_b_register = vim.fn.getreg("b")
vim.fn.setreg("b", "old region")
assert(terminal.yank_region("b", 6, 10, 6, 25) == true, "preview region yank should send a browser drag")
region_drag_request = _G.nvim_browser_last_footer_request_of_type("drag_point")
assert(region_drag_request ~= nil, "preview region yank should begin with a native drag request")
assert(_G.nvim_browser_last_footer_request_of_type("selection_text") == nil, "preview region yank should not read selection before drag completes")
region_drag_response = {
  id = region_drag_request.id,
  status = "ok",
  payload = "selected frame",
  runtime = interactive_runtime(450, 165),
}
terminal._test.apply_serve_response(region_drag_response)
terminal._test.dispatch_serve_response_handler(region_drag_response)
region_selection_request = _G.nvim_browser_last_footer_request_of_type("selection_text")
assert(region_selection_request ~= nil, "preview region yank should request selected text after the drag succeeds")
region_selection_response = {
  id = region_selection_request.id,
  status = "ok",
  selection = "region selected from browser",
}
terminal._test.apply_serve_response(region_selection_response)
terminal._test.dispatch_serve_response_handler(region_selection_response)
assert(vim.wait(1000, function()
  return vim.fn.getreg("b") == "region selected from browser"
end), "preview region yank should write the selected text into the requested register")

warnings = {}
footer_click_requests = {}
vim.fn.setreg("b", "old region")
assert(terminal.yank_region("b", 6, 10, 6, 25) == true, "preview region yank should allow backend drag failures to report asynchronously")
region_drag_request = _G.nvim_browser_last_footer_request_of_type("drag_point")
region_drag_response = {
  id = region_drag_request.id,
  status = "error",
}
terminal._test.apply_serve_response(region_drag_response)
terminal._test.dispatch_serve_response_handler(region_drag_response)
assert(_G.nvim_browser_last_footer_request_of_type("selection_text") == nil, "failed region drags should not request selected text")
assert(vim.wait(1000, function()
  return #warnings > 0
end), "failed region drags should warn")
assert(warnings[#warnings] == "nvim-browser: browser selection yank failed or no browser selection is active", "failed region drags should use the expected warning")
assert(vim.fn.getreg("b") == "old region", "failed region yanks should not overwrite the register")

footer_click_requests = {}
assert(terminal.yank_region("b", 6, 10, 6, 25) == true, "preview region yank should guard stale drag responses")
region_drag_request = _G.nvim_browser_last_footer_request_of_type("drag_point")
terminal._test.set_pending_operation({ id = region_drag_request.id + 1, label = "loading", target = "https://example.com/newer" })
region_drag_response = {
  id = region_drag_request.id,
  status = "ok",
  payload = "stale selected frame",
  runtime = interactive_runtime(450, 165),
}
terminal._test.dispatch_serve_response_handler(region_drag_response)
assert(_G.nvim_browser_last_footer_request_of_type("selection_text") == nil, "stale region drag responses should not request selected text")
terminal._test.clear_pending_operation(region_drag_request.id + 1)

footer_click_requests = {}
assert(terminal.yank_region("b", 6, 10, 6, 25) == true, "preview region yank should guard responses older than the latest applied frame")
region_drag_request = _G.nvim_browser_last_footer_request_of_type("drag_point")
terminal._test.clear_pending_operation(region_drag_request.id)
terminal._test.set_latest_applied_response_id(region_drag_request.id + 1)
region_drag_response = {
  id = region_drag_request.id,
  status = "ok",
  payload = "older selected frame",
  runtime = interactive_runtime(450, 165),
}
terminal._test.dispatch_serve_response_handler(region_drag_response)
assert(_G.nvim_browser_last_footer_request_of_type("selection_text") == nil, "older-than-latest region drag responses should not request selected text")
terminal._test.set_latest_applied_response_id(region_drag_request.id)

footer_click_requests = {}
assert(terminal.yank_region("ab", 6, 10, 6, 25) == false, "preview region yank should reject invalid register names")
assert(#footer_click_requests == 0, "invalid region yank registers should not send a browser drag")

footer_click_requests = {}
assert(terminal.yank_region("%", 6, 10, 6, 25) == false, "preview region yank should reject unwritable one-character registers")
assert(#footer_click_requests == 0, "unwritable one-character region yank registers should not send a browser drag")

footer_click_requests = {}
assert(terminal.yank_region("b", 6, 10, 6, 51) == false, "preview region yank beyond rendered columns should be ignored")
assert(#footer_click_requests == 0, "invalid region yank geometry should not send a browser drag")
vim.fn.setreg("b", old_b_register)

footer_click_requests = {}
assert(terminal.right_click_mouse({ winid = image_win, line = 6, column = 25 }) == true, "mouse right click should send a browser right click")
right_mouse_click_seen = false
right_mouse_click_request_id = nil
for _, request in ipairs(footer_click_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "right_click_point" and decoded.x == expected_mouse_point.x and decoded.y == expected_mouse_point.y then
    right_mouse_click_seen = true
    right_mouse_click_request_id = decoded.id
  end
end
assert(right_mouse_click_seen, "mouse right click should map preview cells to viewport pixels")
assert(terminal.state().pending_operation ~= nil, "mouse right click should mark the browser right click as pending")
assert(terminal.state().pending_operation.label == "right-click", "mouse right click pending footer should use a right-click label")
assert(#terminal.state().element_hints == 0, "mouse right click should clear stale hints while a capture is pending")
terminal._test.apply_serve_response({
  id = right_mouse_click_request_id,
  status = "ok",
  payload = "right clicked frame",
  url = "https://example.com/right-clicked",
  title = "Right Clicked",
  runtime = interactive_runtime(450, 165),
})
assert(terminal.state().pending_operation == nil, "matching right click response should clear pending right click state")

footer_click_requests = {}
assert(terminal.wheel_mouse(120, 0, { winid = image_win, line = 6, column = 25 }) == true, "mouse wheel should queue a browser wheel")
assert(terminal.wheel_mouse(120, 0, { winid = image_win, line = 6, column = 25 }) == true, "second mouse wheel should coalesce at the same point")
assert(terminal.wheel_mouse(-40, 0, { winid = image_win, line = 6, column = 25 }) == true, "third mouse wheel should coalesce deltas at the same point")
function _G.nvim_browser_footer_wheel_request_count()
  local count = 0
  for _, request in ipairs(footer_click_requests) do
    local ok, decoded = pcall(vim.json.decode, request.payload)
    if ok and decoded.type == "wheel_point" then
      count = count + 1
    end
  end
  return count
end
assert(nvim_browser_footer_wheel_request_count() == 0, "rapid mouse wheel input should be delayed for coalescing")
assert(vim.wait(1000, function()
  return nvim_browser_footer_wheel_request_count() == 1
end), "coalesced mouse wheel should flush one browser wheel")
assert(
  terminal.wheel_point(expected_mouse_point.x, expected_mouse_point.y, nil, 0) == false,
  "browser wheel should reject missing vertical delta"
)
local mouse_wheel_seen = false
local mouse_wheel_request_id = nil
for _, request in ipairs(footer_click_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if
    ok
    and decoded.type == "wheel_point"
    and decoded.x == expected_mouse_point.x
    and decoded.y == expected_mouse_point.y
    and decoded.delta_y == 200
    and decoded.delta_x == 0
  then
    mouse_wheel_seen = true
    mouse_wheel_request_id = decoded.id
  end
end
assert(mouse_wheel_seen, "mouse wheel should map preview cells and deltas to a native wheel request")
assert(terminal.state().pending_operation ~= nil, "mouse wheel should mark the browser wheel as pending")
assert(terminal.state().pending_operation.label == "scroll", "mouse wheel pending footer should use a scroll label")
terminal._test.apply_serve_response({
  id = mouse_wheel_request_id,
  status = "ok",
  payload = "wheeled frame",
  url = "https://example.com/wheeled",
  title = "Wheeled",
  runtime = interactive_runtime(450, 165),
})
assert(terminal.state().pending_operation == nil, "matching wheel response should clear pending wheel state")

footer_click_requests = {}
vim.api.nvim_win_set_cursor(image_win, { 6, 24 })
_G.nvim_browser_expected_cursor_wheel_point = terminal.viewport_point_for_cell(6, vim.api.nvim_win_call(image_win, function()
  return vim.fn.virtcol(".")
end), { columns = 50, rows = 11, width = 450, height = 165 })
assert(terminal.wheel_here(120, 0) == true, "cursor wheel should send a browser wheel")
_G.nvim_browser_cursor_wheel_seen = false
assert(vim.wait(1000, function()
  for _, request in ipairs(footer_click_requests) do
    local ok, decoded = pcall(vim.json.decode, request.payload)
    if
      ok
      and decoded.type == "wheel_point"
      and decoded.x == _G.nvim_browser_expected_cursor_wheel_point.x
      and decoded.y == _G.nvim_browser_expected_cursor_wheel_point.y
      and decoded.delta_y == 120
      and decoded.delta_x == 0
    then
      _G.nvim_browser_cursor_wheel_seen = true
      return true
    end
  end
  return false
end), "cursor wheel should map preview cells to viewport pixels")
assert(_G.nvim_browser_cursor_wheel_seen, "cursor wheel should produce a native wheel request")

footer_click_requests = {}
vim.api.nvim_win_set_cursor(image_win, { 6, 24 })
expected_cursor_right_click_point = terminal.viewport_point_for_cell(6, vim.api.nvim_win_call(image_win, function()
  return vim.fn.virtcol(".")
end), { columns = 50, rows = 11, width = 450, height = 165 })
assert(terminal.right_click_here() == true, "cursor right click should send a browser right click")
cursor_right_click_seen = false
for _, request in ipairs(footer_click_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "right_click_point" and decoded.x == expected_cursor_right_click_point.x and decoded.y == expected_cursor_right_click_point.y then
    cursor_right_click_seen = true
  end
end
assert(cursor_right_click_seen, "cursor right click should map preview cells to viewport pixels")

footer_click_requests = {}
vim.api.nvim_win_set_cursor(image_win, { 6, 24 })
assert(terminal.double_click_here() == true, "cursor double-click should send a browser double-click")
_G.nvim_browser_cursor_double_click_seen = false
for _, request in ipairs(footer_click_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "click_point" and decoded.click_count == 2 then
    _G.nvim_browser_cursor_double_click_seen = true
  end
end
assert(_G.nvim_browser_cursor_double_click_seen, "cursor double-click should use click_point with click_count=2")

footer_click_requests = {}
vim.api.nvim_win_set_cursor(image_win, { 6, 24 })
local expected_cursor_hover_point = terminal.viewport_point_for_cell(6, vim.api.nvim_win_call(image_win, function()
  return vim.fn.virtcol(".")
end), { columns = 50, rows = 11, width = 450, height = 165 })
assert(terminal.hover_here() == true, "cursor hover should send a browser hover")
local cursor_hover_seen = false
local cursor_hover_request_id = nil
for _, request in ipairs(footer_click_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "hover_point" and decoded.x == expected_cursor_hover_point.x and decoded.y == expected_cursor_hover_point.y then
    cursor_hover_seen = true
    cursor_hover_request_id = decoded.id
  end
end
assert(cursor_hover_seen, "cursor hover should map preview cells to viewport pixels")
terminal._test.apply_serve_response({
  id = cursor_hover_request_id,
  status = "ok",
  payload = "hovered frame",
  runtime = interactive_runtime(450, 165),
})

footer_click_requests = {}
vim.api.nvim_win_set_cursor(image_win, { 6, 24 })
local expected_cursor_type_point = terminal.viewport_point_for_cell(6, vim.api.nvim_win_call(image_win, function()
  return vim.fn.virtcol(".")
end), { columns = 50, rows = 11, width = 450, height = 165 })
assert(terminal.type_here("cursor text") == true, "cursor typing should send browser point text input")
local cursor_type_seen = false
local cursor_type_request_id = nil
for _, request in ipairs(footer_click_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if
    ok
    and decoded.type == "type_point"
    and decoded.x == expected_cursor_type_point.x
    and decoded.y == expected_cursor_type_point.y
    and decoded.text == "cursor text"
    and decoded.submit == false
  then
    cursor_type_seen = true
    cursor_type_request_id = decoded.id
  end
end
assert(cursor_type_seen, "cursor typing should map preview cells to viewport pixels")
assert(terminal.state().pending_operation ~= nil, "cursor typing should mark the browser input as pending")
assert(terminal.state().pending_operation.label == "type", "cursor typing pending footer should use a type label")
assert(#terminal.state().element_hints == 0, "cursor typing should clear stale hints while a capture is pending")
terminal._test.apply_serve_response({
  id = cursor_type_request_id,
  status = "ok",
  payload = "typed frame",
  url = "https://example.com/typed",
  title = "Typed",
  runtime = interactive_runtime(450, 165),
})
assert(terminal.state().pending_operation == nil, "matching type response should clear pending type state")

footer_click_requests = {}
assert(terminal.type_here("search", { submit = true }) == true, "cursor submit should send browser point text input")
local cursor_submit_seen = false
for _, request in ipairs(footer_click_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "type_point" and decoded.text == "search" and decoded.submit == true then
    cursor_submit_seen = true
  end
end
assert(cursor_submit_seen, "cursor submit should mark type_point submit true")

footer_click_requests = {}
vim.api.nvim_win_set_cursor(image_win, { 6, 24 })
_G.nvim_browser_expected_cursor_select_point = terminal.viewport_point_for_cell(6, vim.api.nvim_win_call(image_win, function()
  return vim.fn.virtcol(".")
end), { columns = 50, rows = 11, width = 450, height = 165 })
assert(terminal.select_here("Canada") == true, "cursor select should send browser point select input")
_G.nvim_browser_cursor_select_seen = false
_G.nvim_browser_cursor_select_request_id = nil
for _, request in ipairs(footer_click_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if
    ok
    and decoded.type == "select_point"
    and decoded.x == _G.nvim_browser_expected_cursor_select_point.x
    and decoded.y == _G.nvim_browser_expected_cursor_select_point.y
    and decoded.choice == "Canada"
  then
    _G.nvim_browser_cursor_select_seen = true
    _G.nvim_browser_cursor_select_request_id = decoded.id
  end
end
assert(_G.nvim_browser_cursor_select_seen, "cursor select should map preview cells to viewport pixels")
assert(terminal.state().pending_operation ~= nil, "cursor select should mark the browser input as pending")
assert(terminal.state().pending_operation.label == "select", "cursor select pending footer should use a select label")
terminal._test.apply_serve_response({
  id = _G.nvim_browser_cursor_select_request_id,
  status = "ok",
  payload = "selected frame",
  url = "https://example.com/selected",
  title = "Selected",
  runtime = interactive_runtime(450, 165),
})
assert(terminal.state().pending_operation == nil, "matching select response should clear pending select state")

footer_click_requests = {}
vim.api.nvim_win_set_cursor(image_win, { 6, 24 })
_G.nvim_browser_expected_cursor_toggle_point = terminal.viewport_point_for_cell(6, vim.api.nvim_win_call(image_win, function()
  return vim.fn.virtcol(".")
end), { columns = 50, rows = 11, width = 450, height = 165 })
assert(terminal.toggle_here() == true, "cursor toggle should send browser point toggle input")
_G.nvim_browser_cursor_toggle_seen = false
_G.nvim_browser_cursor_toggle_request_id = nil
for _, request in ipairs(footer_click_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if
    ok
    and decoded.type == "toggle_point"
    and decoded.x == _G.nvim_browser_expected_cursor_toggle_point.x
    and decoded.y == _G.nvim_browser_expected_cursor_toggle_point.y
  then
    _G.nvim_browser_cursor_toggle_seen = true
    _G.nvim_browser_cursor_toggle_request_id = decoded.id
  end
end
assert(_G.nvim_browser_cursor_toggle_seen, "cursor toggle should map preview cells to viewport pixels")
assert(terminal.state().pending_operation ~= nil, "cursor toggle should mark the browser input as pending")
assert(terminal.state().pending_operation.label == "toggle", "cursor toggle pending footer should use a toggle label")
terminal._test.apply_serve_response({
  id = _G.nvim_browser_cursor_toggle_request_id,
  status = "ok",
  payload = "toggled frame",
  url = "https://example.com/toggled",
  title = "Toggled",
  runtime = interactive_runtime(450, 165),
})
assert(terminal.state().pending_operation == nil, "matching toggle response should clear pending toggle state")

footer_click_requests = {}
terminal.configure({
  viewport = {
    cell_width_px = 10,
    cell_height_px = 20,
  },
})
assert(terminal.click_here() == false, "stale rendered frame geometry should block cursor click")
assert(terminal.double_click_here() == false, "stale rendered frame geometry should block cursor double-click")
assert(terminal.wheel_here(120, 0) == false, "stale rendered frame geometry should block cursor wheel")
assert(terminal.hover_here() == false, "stale rendered frame geometry should block cursor hover")
assert(terminal.type_here("stale text") == false, "stale rendered frame geometry should block cursor typing")
assert(terminal.select_here("stale option") == false, "stale rendered frame geometry should block cursor select")
assert(terminal.toggle_here() == false, "stale rendered frame geometry should block cursor toggle")
assert(terminal.select_region(6, 10, 6, 25) == false, "stale rendered frame geometry should block region selection")
assert(terminal.yank_region("b", 6, 10, 6, 25) == false, "stale rendered frame geometry should block region yank")
assert(terminal.click_mouse({ winid = image_win, line = 6, column = 25 }) == false, "stale rendered frame geometry should block mouse click")
assert(terminal.double_click_mouse({ winid = image_win, line = 6, column = 25 }) == false, "stale rendered frame geometry should block mouse double-click")
assert(terminal.wheel_mouse(120, 0, { winid = image_win, line = 6, column = 25 }) == false, "stale rendered frame geometry should block mouse wheel")
local stale_resize_seen = false
local stale_point_seen = false
for _, request in ipairs(footer_click_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "resize" then
    stale_resize_seen = true
  end
  if ok and (decoded.type == "click_point" or decoded.type == "hover_point" or decoded.type == "type_point" or decoded.type == "select_point" or decoded.type == "toggle_point" or decoded.type == "wheel_point" or decoded.type == "drag_point") then
    stale_point_seen = true
  end
end
assert(stale_resize_seen, "stale rendered frame geometry should request a fresh resized frame")
assert(not stale_point_seen, "stale rendered frame geometry should not send point interactions")

footer_click_requests = {}
terminal._test.apply_serve_response({
  id = 201,
  status = "ok",
  payload = "refreshed interactive frame",
  runtime = {
    protocol_version = 9,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "kitty-unicode",
    cells = { columns = 50, rows = 11 },
    viewport = { width = 500, height = 220, device_scale_factor = 1 },
  },
})
terminal._test.apply_payload_to_buffer(
  vim.api.nvim_win_get_buf(image_win),
  "refreshed interactive frame",
  false,
  true,
  { "nvbrowser", "serve", "--output", "kitty-unicode" },
  { columns = 50, rows = 11, width = 500, height = 220 }
)
terminal._test.set_element_hints({
  { id = 10, hint_label = "s", kind = "input", label = "Search", x = 115, y = 70, width = 50, height = 40 },
}, { columns = 50, rows = 11, width = 500, height = 220 })
vim.api.nvim_win_set_cursor(image_win, { 1, 0 })
terminal._test.set_cursor_addressable_preview(false)
assert(terminal.jump_hint("s") == false, "jump_hint should require a cursor-addressable preview")
terminal._test.set_cursor_addressable_preview(true)
assert(terminal.jump_hint("s") == true, "jump_hint should move the preview cursor to a hinted element")
_G.nvim_browser_hinted_cursor = vim.api.nvim_win_get_cursor(image_win)
assert(_G.nvim_browser_hinted_cursor[1] == 4, "jump_hint should place the cursor on the hint center row")
_G.nvim_browser_hinted_virtcol = vim.api.nvim_win_call(image_win, function()
  return vim.fn.virtcol(".")
end)
assert(_G.nvim_browser_hinted_virtcol == 12, "jump_hint should place the cursor at the hint center screen cell")
assert(terminal.click_here() == true, "matching refreshed frame geometry should allow cursor click again")
_G.nvim_browser_jump_click_point = nil
for _, request in ipairs(footer_click_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "click_point" then
    _G.nvim_browser_jump_click_point = decoded
  end
end
assert(
  _G.nvim_browser_jump_click_point ~= nil
    and _G.nvim_browser_jump_click_point.x == 115
    and _G.nvim_browser_jump_click_point.y == 70,
  "jump_hint should position cursor-local clicks at the hinted center point"
)
terminal._test.set_pending_operation(nil)
assert(terminal.double_click_here() == true, "matching refreshed frame geometry should allow cursor double-click again")

footer_click_requests = {}
terminal._test.apply_serve_response({
  id = 202,
  status = "ok",
  payload = "column guard frame",
  runtime = {
    protocol_version = 9,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "kitty-unicode",
    cells = { columns = 50, rows = 11 },
    viewport = { width = 500, height = 220, device_scale_factor = 1 },
  },
})
vim.bo[payload_bufnr].modifiable = true
vim.api.nvim_buf_set_lines(payload_bufnr, 5, 6, false, { string.rep("x", 80) })
vim.bo[payload_bufnr].modifiable = false
vim.api.nvim_win_set_cursor(image_win, { 6, 60 })
terminal.configure({
  viewport = {
    cell_width_px = 11,
    cell_height_px = 20,
  },
})
footer_click_requests = {}
assert(terminal.click_here() == false, "cursor click beyond rendered columns should be ignored")
assert(terminal.double_click_here() == false, "cursor double-click beyond rendered columns should be ignored")
assert(terminal.hover_here() == false, "cursor hover beyond rendered columns should be ignored")
assert(terminal.type_here("outside") == false, "cursor typing beyond rendered columns should be ignored")
assert(terminal.select_region(6, 10, 6, 51) == false, "region selection beyond rendered columns should be ignored")
assert(#footer_click_requests == 0, "out-of-column cursor actions should not reach the serve backend")

footer_click_requests = {}
assert(terminal.click_mouse({ winid = image_win, line = 6, column = 51 }) == false, "mouse click beyond rendered columns should be ignored")
assert(terminal.double_click_mouse({ winid = image_win, line = 6, column = 51 }) == false, "mouse double-click beyond rendered columns should be ignored")
assert(terminal.wheel_mouse(120, 0, { winid = image_win, line = 6, column = 51 }) == false, "mouse wheel beyond rendered columns should be ignored")
assert(#footer_click_requests == 0, "out-of-column mouse clicks should not reach the serve backend")

footer_click_requests = {}
assert(terminal.click_mouse({ winid = image_win, line = 12, column = 25 }) == false, "mouse click on footer should be ignored")
assert(terminal.double_click_mouse({ winid = image_win, line = 12, column = 25 }) == false, "mouse double-click on footer should be ignored")
assert(terminal.wheel_mouse(120, 0, { winid = image_win, line = 12, column = 25 }) == false, "mouse wheel on footer should be ignored")
assert(terminal.select_region(6, 10, 12, 25) == false, "region selection ending on footer should be ignored")
assert(#footer_click_requests == 0, "footer mouse clicks should not reach the serve backend")

footer_click_requests = {}
assert(terminal.click_mouse({ winid = second_bufnr, line = 6, column = 25 }) == false, "mouse click from another window should be ignored")
assert(terminal.double_click_mouse({ winid = second_bufnr, line = 6, column = 25 }) == false, "mouse double-click from another window should be ignored")
assert(terminal.wheel_mouse(120, 0, { winid = second_bufnr, line = 6, column = 25 }) == false, "mouse wheel from another window should be ignored")
assert(#footer_click_requests == 0, "wrong-window mouse clicks should not reach the serve backend")

vim.api.nvim_win_set_cursor(image_win, { 12, 0 })
assert(terminal.click_here() == false, "clicking the footer row should not send a browser click")
assert(terminal.double_click_here() == false, "double-clicking the footer row should not send a browser click")
assert(terminal.hover_here() == false, "hovering the footer row should not send a browser hover")
assert(terminal.type_here("footer text") == false, "typing on the footer row should not send browser input")
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
local serve_exit = nil
local function last_request_of_type(kind)
  for index = #sent_requests, 1, -1 do
    local ok, decoded = pcall(vim.json.decode, sent_requests[index].payload)
    if ok and decoded.type == kind then
      return decoded
    end
  end
  return nil
end

function _G.nvim_browser_command_option(command, option)
  for index, value in ipairs(command or {}) do
    if value == option then
      return command[index + 1]
    end
  end
  return nil
end

function _G.nvim_browser_requests_of_type(kind)
  local matches = {}
  for _, request in ipairs(sent_requests) do
    local ok, decoded = pcall(vim.json.decode, request.payload)
    if ok and decoded.type == kind then
      table.insert(matches, decoded)
    end
  end
  return matches
end

function _G.nvim_browser_stop_with_backend_error()
  assert(terminal.stop() == true, "test setup should send stop_loading")
  _G.nvim_browser_stop_with_backend_error_request = last_request_of_type("stop_loading")
  assert(_G.nvim_browser_stop_with_backend_error_request ~= nil, "test setup should send stop_loading before fallback")
  serve_stdout(nil, { vim.json.encode({
    id = _G.nvim_browser_stop_with_backend_error_request.id,
    status = "error",
    error = "stop loading failed",
  }), "" })
  assert(vim.wait(1000, function()
    return terminal.state().mode == nil
  end), "test setup should hard stop after stop_loading failure")
end

function _G.nvim_browser_latest_timer()
  return fake_timers[#fake_timers]
end

local function flush_latest_timer()
  local timer = nvim_browser_latest_timer()
  if timer ~= nil and timer.callback ~= nil then
    timer.callback()
    vim.wait(100, function()
      return timer.closed == true
    end)
  end
end

function _G.nvim_browser_count_substrings(value, needle)
  _G.nvim_browser_count_substrings_count = 0
  _G.nvim_browser_count_substrings_start = 1
  while true do
    _G.nvim_browser_count_substrings_found = value:find(needle, _G.nvim_browser_count_substrings_start, true)
    if _G.nvim_browser_count_substrings_found == nil then
      return _G.nvim_browser_count_substrings_count
    end
    _G.nvim_browser_count_substrings_count = _G.nvim_browser_count_substrings_count + 1
    _G.nvim_browser_count_substrings_start = _G.nvim_browser_count_substrings_found + #needle
  end
end

function _G.nvim_browser_assert_redraw_before_payload(marker, label)
  _G.nvim_browser_payload_event_index = nil
  _G.nvim_browser_redraw_before_payload = false
  for index, event in ipairs(_G.nvim_browser_serve_egress_events) do
    if event == "redraw" and _G.nvim_browser_payload_event_index == nil then
      _G.nvim_browser_redraw_before_payload = true
    end
    if type(event) == "string" and event:find(marker, 1, true) then
      _G.nvim_browser_payload_event_index = index
      break
    end
  end
  assert(_G.nvim_browser_payload_event_index ~= nil, label .. " should emit a kitty-unicode payload")
  assert(_G.nvim_browser_redraw_before_payload, label .. " should redraw before emitting the kitty-unicode payload")
end

function _G.nvim_browser_request_sequence()
  local sequence = {}
  for _, request in ipairs(sent_requests) do
    local ok, decoded = pcall(vim.json.decode, request.payload)
    if ok then
      table.insert(sequence, decoded.type .. ":" .. (decoded.text or decoded.key or ""))
    end
  end
  return table.concat(sequence, ",")
end

function _G.nvim_browser_buffer_text(bufnr)
  return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
end

vim.fn.jobstart = function(command, opts)
  table.insert(jobstart_calls, command)
  serve_stdout = opts and opts.on_stdout or nil
  _G.nvim_browser_serve_stderr = opts and opts.on_stderr or nil
  serve_exit = opts and opts.on_exit or nil
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
local startup_lines = vim.api.nvim_buf_get_lines(first_state.bufnr, 0, -1, false)
local startup_columns = math.max(20, vim.api.nvim_win_get_width(first_state.winid) - 2)
local startup_expected_rows = math.max(6, vim.api.nvim_win_get_height(first_state.winid) - 3) + 1
assert(
  #startup_lines == startup_expected_rows,
  "serve startup placeholders should reserve render rows plus one footer row"
)
assert(
  startup_lines[#startup_lines] == terminal._test.preview_footer_line(startup_columns),
  "serve startup should append the preview footer"
)
assert(#fake_timers == 1, "serve sessions should start a live refresh timer by default")
assert(fake_timers[1].starts[1].timeout == 1500, "live refresh should use the default interval as its initial delay")
assert(fake_timers[1].starts[1].repeat_ms == 1500, "live refresh should repeat at the configured interval")

serve_stdout(nil, { vim.json.encode({
  id = 1,
  status = "error",
  error = "first frame failed",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().status_error == "first frame failed"
end), "first-frame serve errors should update status")
_G.nvim_browser_first_frame_error_text = _G.nvim_browser_buffer_text(first_state.bufnr)
assert(
  _G.nvim_browser_first_frame_error_text:find("Browser startup failed", 1, true),
  "first-frame serve errors should replace startup text with a failure message"
)
assert(
  _G.nvim_browser_first_frame_error_text:find("first frame failed", 1, true),
  "first-frame serve errors should show the backend error"
)
serve_exit(nil, 2)
assert(vim.wait(1000, function()
  return terminal.state().mode == nil
end), "serve exit after a first-frame JSON error should close the active serve state")
assert(
  terminal.state().status_error == "first frame failed",
  "serve exit after a first-frame JSON error should preserve the specific backend error"
)
_G.nvim_browser_first_frame_error_exit_text = _G.nvim_browser_buffer_text(first_state.bufnr)
assert(
  _G.nvim_browser_first_frame_error_exit_text:find("first frame failed", 1, true),
  "serve exit after a first-frame JSON error should keep the specific backend error in the preview"
)

terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com/stderr-fail" })
_G.nvim_browser_stderr_failure_state = terminal.state()
_G.nvim_browser_serve_stderr(nil, { "Chrome failed to start", "profile is locked", "" })
serve_exit(nil, 2)
assert(vim.wait(1000, function()
  return terminal.state().status_error ~= nil and terminal.state().status_error:find("Chrome failed to start", 1, true)
end), "first-frame serve exits should preserve stderr in status")
_G.nvim_browser_stderr_failure_text = _G.nvim_browser_buffer_text(_G.nvim_browser_stderr_failure_state.bufnr)
assert(
  _G.nvim_browser_stderr_failure_text:find("Browser startup failed: exit 2", 1, true),
  "first-frame serve exits should show the exit code"
)
assert(
  _G.nvim_browser_stderr_failure_text:find("Chrome failed to start", 1, true),
  "first-frame serve exits should show captured stderr"
)
assert(
  _G.nvim_browser_stderr_failure_text:find("profile is locked", 1, true),
  "first-frame serve exits should show multiple stderr lines"
)

terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com/large-stderr-fail" })
_G.nvim_browser_serve_stderr(nil, { string.rep("x", 3000) })
serve_exit(nil, 4)
assert(vim.wait(1000, function()
  return terminal.state().status_error ~= nil and terminal.state().status_error:find("%.%.%.", 1, false)
end), "large single-line stderr should be truncated in status")
assert(#terminal.state().status_error < 2200, "large single-line stderr should be bounded")

_G.nvim_browser_original_tmux_for_serve_egress = vim.env.TMUX
_G.nvim_browser_serve_egress_payloads = {}
_G.nvim_browser_serve_egress_events = {}
_G.nvim_browser_original_vim_cmd_for_serve_egress = vim.cmd
vim.env.TMUX = "/tmp/tmux-501/default,123,0"
vim.cmd = function(command)
  if command == "redraw" then
    table.insert(_G.nvim_browser_serve_egress_events, "redraw")
  end
  return _G.nvim_browser_original_vim_cmd_for_serve_egress(command)
end
vim.api.nvim_chan_send = function(channel, payload)
  if channel == vim.v.stderr then
    table.insert(_G.nvim_browser_serve_egress_payloads, payload)
    table.insert(_G.nvim_browser_serve_egress_events, payload)
    return 0
  end
  return original_nvim_chan_send(channel, payload)
end
terminal.open({ "nvbrowser", "serve", "--output", "kitty-unicode", "--url", "https://example.com/tmux" })
_G.nvim_browser_serve_egress_payloads = {}
_G.nvim_browser_serve_egress_events = {}
_G.nvim_browser_raw_unicode_payload = "\27_Ga=T,q=2,U=1,i=1,c=10,r=5,f=100,s=100,v=100,m=1;"
  .. string.rep("x", 5000)
  .. "\27\\\27_Gm=0;unicode-frame\27\\"
_G.nvim_browser_tmx_preview_geometry = terminal.state().current_preview_geometry
serve_stdout(nil, { vim.json.encode({
  id = 1,
  status = "ok",
  payload = _G.nvim_browser_raw_unicode_payload,
  url = "https://example.com/tmux",
  title = "tmux",
  runtime = {
    protocol_version = 18,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "kitty-unicode",
    cells = { columns = _G.nvim_browser_tmx_preview_geometry.columns, rows = _G.nvim_browser_tmx_preview_geometry.rows },
    viewport = { width = _G.nvim_browser_tmx_preview_geometry.width, height = _G.nvim_browser_tmx_preview_geometry.height, device_scale_factor = 1 },
  },
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title == "tmux"
end), "kitty-unicode serve frame responses should apply through the JSONL handler")
assert(terminal.state().has_payload == true, "kitty-unicode serve responses should store the last raw payload for replay")
assert(terminal.state().cursor_addressable_preview == true, "kitty-unicode serve previews should stay cursor-addressable")
_G.nvim_browser_tmux_state = terminal.state()
_G.nvim_browser_tmux_lines = vim.api.nvim_buf_get_lines(_G.nvim_browser_tmux_state.bufnr, 0, -1, false)
assert(
  #_G.nvim_browser_tmux_lines == _G.nvim_browser_tmx_preview_geometry.rows + 1,
  "kitty-unicode serve buffers should contain placeholder rows plus footer"
)
assert(#_G.nvim_browser_tmux_lines[1] > 0, "kitty-unicode serve buffers should contain placeholder cells")
assert(
  _G.nvim_browser_tmux_lines[#_G.nvim_browser_tmux_lines] == terminal._test.preview_footer_line(_G.nvim_browser_tmx_preview_geometry.columns),
  "kitty-unicode serve buffers should preserve a cursor-addressable footer"
)

terminal._test.apply_serve_response({
  id = 901,
  status = "ok",
  text = {
    text = table.concat({
      "calibration-click: observed",
      "calibration-right-click: pending",
      "calibration-hover: observed",
      "calibration-type: calibrated",
      "calibration-wheel: pending",
    }, "\n"),
    truncated = false,
    url = "file:///tmp/calibrate.html",
  },
})
assert(terminal.state().calibration_state ~= nil, "page_text responses should record calibration fixture state")
assert(terminal.state().calibration_state.click == true, "calibration page_text should record observed clicks")
assert(terminal.state().calibration_state.right_click == false, "calibration page_text should record pending right clicks")
assert(terminal.state().calibration_state.hover == true, "calibration page_text should record observed hovers")
assert(terminal.state().calibration_state.type == true, "calibration page_text should record typed input")
assert(terminal.state().calibration_state.wheel == false, "calibration page_text should record pending wheels")
terminal._test.apply_serve_response({
  id = 902,
  status = "ok",
  text = {
    text = "ordinary page text",
    truncated = false,
    url = "https://example.com",
  },
})
assert(terminal.state().calibration_state == nil, "non-calibration page_text should clear stale calibration state")
assert(
  terminal._test.is_kitty_unicode_payload("\27_Ga=T,f=100,U=1,m=0;unicode-frame\27\\") == true,
  "raw Kitty Unicode virtual placement payloads should be classified as Kitty Unicode"
)
assert(
  terminal._test.is_kitty_unicode_payload("\27_Ga=T,f=100,U=1,m=1;chunk-a\27\\\27_Gm=0;chunk-b\27\\") == true,
  "chunked Kitty Unicode virtual placement payloads should be classified as Kitty Unicode"
)
assert(
  terminal._test.is_kitty_unicode_payload("\27Ptmux;\27\27_Ga=T,f=100,U=1,m=0;unicode-frame\27\27\\\27\\") == true,
  "tmux passthrough wrapped Kitty Unicode payloads should be classified as Kitty Unicode"
)
assert(
  terminal._test.is_kitty_unicode_payload("\27_Ga=d\27\\\27_Ga=T,f=100,U=1,m=0;unicode-frame\27\\") == true,
  "a later valid Kitty Unicode payload should still be classified after a semicolon-free Kitty command"
)
assert(
  terminal._test.is_kitty_unicode_payload("\27_Ga=d\27\\,U=1;plain-text") == false,
  "Kitty Unicode classification should not read past a semicolon-free Kitty command boundary"
)
assert(
  terminal._test.is_kitty_unicode_payload("\27_Ga=T,f=100,m=0;plain-frame\27\\") == false,
  "plain Kitty graphics payloads without Unicode virtual placement should not be classified as Kitty Unicode"
)
assert(terminal._test.is_kitty_unicode_payload("plain text") == false, "plain text should not be classified as Kitty Unicode")
assert(terminal._test.is_kitty_unicode_payload("") == false, "empty payloads should not be classified as Kitty Unicode")
assert(terminal._test.is_kitty_unicode_payload(nil) == false, "nil payloads should not be classified as Kitty Unicode")
assert(#_G.nvim_browser_serve_egress_payloads == 1, "kitty-unicode serve frames should emit exactly one terminal payload")
assert(terminal.state().terminal_graphics_egress_count > 0, "kitty-unicode serve frames should count terminal graphics egress")
assert(
  terminal.state().last_terminal_graphics_egress_is_kitty_unicode == true,
  "kitty-unicode serve frames should expose the last terminal graphics egress classification"
)
assert(
  terminal.state().last_terminal_graphics_payload_bytes > 4096,
  "kitty-unicode serve frames should expose large terminal graphics payload byte length"
)
assert(
  terminal.state().last_terminal_graphics_egress_bytes > terminal.state().last_terminal_graphics_payload_bytes,
  "tmux kitty-unicode serve frames should expose terminal-wrapped graphics egress byte length"
)
assert(
  terminal.state().last_terminal_graphics_egress_reason == "frame",
  "kitty-unicode serve frames should expose fresh-frame graphics egress reason"
)
_G.nvim_browser_graphics_egress_count_after_frame = terminal.state().terminal_graphics_egress_count
_G.nvim_browser_wrapped_unicode_payload = _G.nvim_browser_serve_egress_payloads[1]
_G.nvim_browser_assert_redraw_before_payload("unicode-frame", "kitty-unicode serve frame")
assert(nvim_browser_count_substrings(_G.nvim_browser_wrapped_unicode_payload, "\27Ptmux;") == 1, "serve payload should be wrapped in tmux passthrough exactly once")
assert(_G.nvim_browser_wrapped_unicode_payload:find("unicode-frame", 1, true), "tmux-wrapped serve payload should preserve frame bytes")
assert(_G.nvim_browser_wrapped_unicode_payload:find("\27\27_G", 1, true), "tmux-wrapped serve payload should double Kitty start escapes")
assert(_G.nvim_browser_wrapped_unicode_payload:find("\27\27\\", 1, true), "tmux-wrapped serve payload should double Kitty end escapes")
assert(
  terminal._test.is_kitty_unicode_payload(_G.nvim_browser_wrapped_unicode_payload) == true,
  "tmux-wrapped serve payload should remain classifiable as Kitty Unicode"
)
_G.nvim_browser_serve_egress_payloads = {}
_G.nvim_browser_serve_egress_events = {}
vim.api.nvim_exec_autocmds("BufEnter", { buffer = _G.nvim_browser_tmux_state.bufnr, modeline = false })
assert(vim.wait(1000, function()
  for _, payload in ipairs(_G.nvim_browser_serve_egress_payloads) do
    if payload:find("unicode-frame", 1, true) then
      return true
    end
  end
  return false
end), "kitty-unicode previews should replay the last terminal payload on preview BufEnter")
_G.nvim_browser_assert_redraw_before_payload("unicode-frame", "kitty-unicode BufEnter replay")
assert(
  terminal.state().last_terminal_graphics_egress_reason == "focus-replay",
  "kitty-unicode BufEnter replay should expose focus-replay graphics egress reason"
)
_G.nvim_browser_serve_egress_payloads = {}
_G.nvim_browser_serve_egress_events = {}
vim.api.nvim_exec_autocmds("WinEnter", { buffer = _G.nvim_browser_tmux_state.bufnr, modeline = false })
assert(vim.wait(1000, function()
  for _, payload in ipairs(_G.nvim_browser_serve_egress_payloads) do
    if payload:find("unicode-frame", 1, true) then
      return true
    end
  end
  return false
end), "kitty-unicode previews should replay the last terminal payload on preview WinEnter")
_G.nvim_browser_assert_redraw_before_payload("unicode-frame", "kitty-unicode WinEnter replay")
_G.nvim_browser_serve_egress_payloads = {}
_G.nvim_browser_serve_egress_events = {}
vim.api.nvim_exec_autocmds("BufEnter", { buffer = _G.nvim_browser_tmux_state.bufnr, modeline = false })
vim.api.nvim_exec_autocmds("WinEnter", { buffer = _G.nvim_browser_tmux_state.bufnr, modeline = false })
assert(vim.wait(1000, function()
  for _, payload in ipairs(_G.nvim_browser_serve_egress_payloads) do
    if payload:find("unicode-frame", 1, true) then
      return true
    end
  end
  return false
end), "kitty-unicode focus events should replay a terminal payload")
_G.nvim_browser_focus_replay_count = 0
for _, payload in ipairs(_G.nvim_browser_serve_egress_payloads) do
  if payload:find("unicode-frame", 1, true) then
    _G.nvim_browser_focus_replay_count = _G.nvim_browser_focus_replay_count + 1
  end
end
assert(_G.nvim_browser_focus_replay_count == 1, "kitty-unicode BufEnter plus WinEnter should coalesce to one replay")
_G.nvim_browser_serve_egress_payloads = {}
_G.nvim_browser_serve_egress_events = {}
_G.nvim_browser_unrelated_bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_exec_autocmds("BufEnter", { buffer = _G.nvim_browser_unrelated_bufnr, modeline = false })
vim.wait(50)
assert(#_G.nvim_browser_serve_egress_payloads == 0, "unrelated buffers should not replay kitty-unicode browser payloads")
vim.api.nvim_set_current_win(_G.nvim_browser_tmux_state.winid)
assert(terminal.focus() == true, "focus should replay the active kitty-unicode preview")
_G.nvim_browser_assert_redraw_before_payload("unicode-frame", "kitty-unicode focus replay")
assert(
  terminal.state().terminal_graphics_egress_count > _G.nvim_browser_graphics_egress_count_after_frame,
  "kitty-unicode focus replay should count terminal graphics egress"
)
assert(
  terminal.state().last_terminal_graphics_egress_reason == "focus",
  "explicit focus replay should expose focus graphics egress reason"
)
_G.nvim_browser_serve_egress_payloads = {}
_G.nvim_browser_serve_egress_events = {}
assert(terminal.toggle() == false, "first toggle should close the active preview window")
assert(terminal.toggle() == true, "second toggle should reopen the preview window")
_G.nvim_browser_replayed_unicode_payloads = 0
for _, payload in ipairs(_G.nvim_browser_serve_egress_payloads) do
  if payload:find("unicode-frame", 1, true) then
    _G.nvim_browser_replayed_unicode_payloads = _G.nvim_browser_replayed_unicode_payloads + 1
  end
end
assert(_G.nvim_browser_replayed_unicode_payloads == 1, "reopening a kitty-unicode preview should replay one terminal frame payload")
assert(
  _G.nvim_browser_serve_egress_payloads[#_G.nvim_browser_serve_egress_payloads] == _G.nvim_browser_wrapped_unicode_payload,
  "replayed kitty-unicode payload should be wrapped at egress instead of storing tmux-wrapped data"
)
_G.nvim_browser_assert_redraw_before_payload("unicode-frame", "kitty-unicode toggle replay")
assert(
  terminal.state().last_terminal_graphics_egress_reason == "toggle-reopen",
  "kitty-unicode toggle reopen should expose toggle-reopen graphics egress reason"
)
_G.nvim_browser_serve_egress_payloads = {}
_G.nvim_browser_serve_egress_events = {}
terminal.open({ "nvbrowser", "browse", "https://example.com/capture", "--output", "kitty-unicode" })
_G.nvim_browser_serve_egress_payloads = {}
_G.nvim_browser_serve_egress_events = {}
serve_stdout(nil, { "\27_Ga=T,q=2,U=1,i=1,c=10,r=5,f=100,s=100,v=100,m=0;browse-unicode-frame\27\\", "" })
serve_exit(nil, 0)
assert(vim.wait(1000, function()
  for _, payload in ipairs(_G.nvim_browser_serve_egress_payloads) do
    if payload:find("browse-unicode-frame", 1, true) then
      return true
    end
  end
  return false
end), "kitty-unicode browse preview should emit one terminal payload")
_G.nvim_browser_assert_redraw_before_payload("browse-unicode-frame", "kitty-unicode browse frame")
vim.env.TMUX = _G.nvim_browser_original_tmux_for_serve_egress
vim.cmd = _G.nvim_browser_original_vim_cmd_for_serve_egress
vim.api.nvim_chan_send = function(channel, payload)
  if channel == vim.v.stderr then
    return 0
  end
  return original_nvim_chan_send(channel, payload)
end
vim.api.nvim_chan_send = function(channel, payload)
  if channel == vim.v.stderr then
    table.insert(_G.nvim_browser_serve_egress_payloads, payload)
    return 0
  end
  return original_nvim_chan_send(channel, payload)
end
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com" })
_G.nvim_browser_ansi_focus_state = terminal.state()
assert(_G.nvim_browser_ansi_focus_state.terminal_graphics_egress_count == 0, "ansi browser previews should reset terminal graphics egress count")
_G.nvim_browser_serve_egress_payloads = {}
vim.api.nvim_exec_autocmds("BufEnter", { buffer = _G.nvim_browser_ansi_focus_state.bufnr, modeline = false })
vim.wait(50)
assert(#_G.nvim_browser_serve_egress_payloads == 0, "ansi browser previews should not emit terminal graphics on BufEnter")
vim.api.nvim_chan_send = function(channel, payload)
  if channel == vim.v.stderr then
    return 0
  end
  return original_nvim_chan_send(channel, payload)
end
fake_timers[1] = fake_timers[#fake_timers]
jobstart_calls = { jobstart_calls[#jobstart_calls] }
jobstop_calls = {}
first_state = terminal.state()
startup_lines = vim.api.nvim_buf_get_lines(first_state.bufnr, 0, -1, false)
startup_columns = math.max(20, vim.api.nvim_win_get_width(first_state.winid) - 2)
startup_expected_rows = math.max(6, vim.api.nvim_win_get_height(first_state.winid) - 3) + 1

do
serve_stdout(nil, { vim.json.encode({
  id = 1,
  status = "ok",
  payload = "last good frame",
  url = "https://example.com",
  title = "Example",
  hints = {
    {
      id = 11,
      kind = "button",
      label = "Retry",
      x = 12,
      y = 24,
      width = 80,
      height = 32,
      clickable = true,
      focusable = true,
    },
  },
  runtime = {
    protocol_version = 9,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "ansi",
    cells = { columns = startup_columns, rows = startup_expected_rows - 1 },
    viewport = { width = startup_columns * 10, height = (startup_expected_rows - 1) * 20, device_scale_factor = 1 },
  },
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title == "Example"
end), "serve frame responses should update preview metadata")
local observed_metadata = nil
terminal.set_metadata_observer(function(metadata)
  observed_metadata = metadata
end)
terminal._test.apply_serve_response({
  id = 100,
  status = "ok",
  url = "https://example.com/history",
  title = "History Page",
})
assert(observed_metadata.url == "https://example.com/history", "metadata observer should receive serve response URLs")
assert(observed_metadata.title == "History Page", "metadata observer should receive serve response titles")
observed_metadata = nil
terminal._test.apply_serve_response({
  id = 101,
  status = "ok",
})
assert(observed_metadata == nil, "metadata observer should ignore responses without explicit URLs")
terminal.set_metadata_observer(nil)
local last_good_geometry = terminal.state().rendered_frame_geometry
assert(last_good_geometry ~= nil, "serve frame responses should store last good geometry")
assert(#terminal.state().element_hints == 1, "serve frame responses should store element hints")
local last_good_render_rows = vim.api.nvim_buf_get_lines(first_state.bufnr, 0, startup_expected_rows - 1, false)
terminal._test.set_pending_operation({ id = 2, label = "loading", target = "https://example.com/fail" })
serve_stdout(nil, { vim.json.encode({
  id = 2,
  status = "error",
  error = "navigation failed",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().status == "error"
end), "serve error responses should update status")
assert(terminal.state().pending_operation == nil, "serve error responses should clear matching pending operations")
assert(terminal.state().status_error == "navigation failed", "serve error responses should store error text")
assert(
  terminal.state().rendered_frame_geometry == last_good_geometry,
  "serve error responses should preserve last good geometry"
)
assert(#terminal.state().element_hints == 1, "serve error responses should preserve last good hints")
local render_rows_after_error = vim.api.nvim_buf_get_lines(first_state.bufnr, 0, startup_expected_rows - 1, false)
assert(vim.deep_equal(render_rows_after_error, last_good_render_rows), "serve errors should not replace the last rendered frame")

terminal._test.set_pending_operation({ id = 3, label = "loading", target = "https://example.com/protocol" })
serve_stdout(nil, { vim.json.encode({
  id = 0,
  status = "error",
  error = "invalid serve request",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().status_error == "invalid serve request"
end), "protocol error responses should be surfaced even while newer operations are pending")
assert(terminal.state().pending_operation == nil, "protocol error responses should clear pending operations")
assert(
  terminal.state().rendered_frame_geometry == last_good_geometry,
  "protocol error responses should preserve last good geometry"
)

sent_requests = {}
assert(terminal.navigate("https://example.com/protocol-during-navigation") == true, "test setup should send navigation before protocol error")
assert(terminal.state().pending_operation ~= nil, "navigation before protocol error should be pending")
serve_stdout(nil, { vim.json.encode({
  id = 0,
  status = "error",
  error = "invalid serve request during navigation",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().status_error == "invalid serve request during navigation"
end), "protocol error responses should be surfaced during navigation admission")
assert(terminal.state().pending_operation == nil, "protocol error responses should clear navigation admission pending operations")
assert(
  terminal.state().rendered_frame_geometry == last_good_geometry,
  "protocol errors during navigation admission should preserve last good geometry"
)
sent_requests = {}
assert(terminal.scroll(42) == true, "normal requests should still be usable after navigation admission protocol errors")
flush_latest_timer()
local post_protocol_scroll_request = last_request_of_type("scroll")
serve_stdout(nil, { vim.json.encode({
  id = post_protocol_scroll_request.id,
  status = "ok",
  payload = "post protocol scroll frame",
  url = "https://example.com/post-protocol-scroll",
  title = "Post Protocol Scroll",
  hints = {
    {
      id = 44,
      kind = "button",
      label = "Post Protocol Button",
      x = 1,
      y = 2,
      width = 3,
      height = 4,
      clickable = true,
      focusable = true,
    },
  },
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title == "Post Protocol Scroll"
end), "responses after navigation admission protocol errors should apply normally")
last_good_geometry = terminal.state().rendered_frame_geometry

sent_requests = {}
assert(terminal.navigate("https://example.com/fail-real") == true, "real navigation should send a pending request")
local failed_navigation_request = last_request_of_type("navigate")
assert(failed_navigation_request ~= nil, "real navigation should send a navigate request")
serve_stdout(nil, { vim.json.encode({
  id = failed_navigation_request.id,
  status = "error",
  error = "real navigation failed",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().status_error == "real navigation failed"
end), "real navigation errors should be surfaced")
assert(terminal.state().pending_operation == nil, "real navigation errors should clear pending operations")
assert(
  terminal.state().rendered_frame_geometry == last_good_geometry,
  "real navigation errors should preserve last good geometry"
)
assert(#terminal.state().element_hints == 1, "real navigation errors should preserve last good hints")

local original_send_before_failed_navigation = vim.fn.chansend
vim.fn.chansend = function()
  return 0
end
assert(terminal.navigate("https://example.com/send-fail") == false, "failed navigation send should report failure")
assert(
  terminal.state().rendered_frame_geometry == last_good_geometry,
  "failed navigation send should preserve last good geometry"
)
assert(#terminal.state().element_hints == 1, "failed navigation send should preserve last good hints")
vim.fn.chansend = original_send_before_failed_navigation
end

sent_requests = {}
assert(terminal.yank_selection("ab") == false, "selection yank should reject invalid register names")
assert(#sent_requests == 0, "invalid selection yank registers should not send a serve request")

_G.nvim_browser_old_page_text_register = vim.fn.getreg("b")
vim.fn.setreg("b", "old page text")
sent_requests = {}
assert(terminal.yank_page_text("b") == true, "page text yank should send a page_text request")
_G.nvim_browser_page_text_request = last_request_of_type("page_text")
assert(_G.nvim_browser_page_text_request ~= nil, "page text yank should use the page_text serve request")
_G.nvim_browser_reader_bufnr_before_yank = terminal.state().reader_bufnr
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_page_text_request.id,
  status = "ok",
  text = {
    title = "Example",
    url = "https://example.com",
    text = "# Example\n\nReadable body",
    truncated = false,
  },
}), "" })
assert(vim.wait(1000, function()
  return vim.fn.getreg("b") == "# Example\n\nReadable body"
end), "page text yank responses should write snapshot text to the requested register")
assert(terminal.state().reader_bufnr == _G.nvim_browser_reader_bufnr_before_yank, "page text yank should not create or replace reader buffers")

warnings = {}
sent_requests = {}
vim.fn.setreg("b", "preserve page text")
assert(terminal.yank_page_text("b") == true, "empty page text yank should still send a page_text request")
_G.nvim_browser_empty_page_text_request = last_request_of_type("page_text")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_empty_page_text_request.id,
  status = "ok",
  text = {
    title = "Empty",
    url = "https://example.com/empty",
    text = "",
    truncated = false,
  },
}), "" })
assert(vim.wait(1000, function()
  return #warnings > 0
end), "empty page text yank responses should warn")
assert(warnings[#warnings] == "nvim-browser: page text yank failed or snapshot was empty", "empty page text yank should use the expected warning")
assert(vim.fn.getreg("b") == "preserve page text", "empty page text yank should not overwrite the register")

warnings = {}
sent_requests = {}
assert(terminal.yank_page_text("b") == true, "failed page text yank should still send a page_text request")
_G.nvim_browser_failed_page_text_request = last_request_of_type("page_text")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_failed_page_text_request.id,
  status = "error",
  error = "snapshot failed",
}), "" })
assert(vim.wait(1000, function()
  return #warnings > 0
end), "failed page text yank responses should warn")
_G.nvim_browser_failed_page_text_warning_seen = false
for _, warning in ipairs(warnings) do
  if warning == "nvim-browser: page text yank failed or snapshot was empty" then
    _G.nvim_browser_failed_page_text_warning_seen = true
  end
end
assert(
  _G.nvim_browser_failed_page_text_warning_seen,
  "failed page text yank should use the expected warning"
)
assert(vim.fn.getreg("b") == "preserve page text", "failed page text yank should not overwrite the register")

sent_requests = {}
assert(terminal.yank_page_text("ab") == false, "page text yank should reject invalid register names")
assert(last_request_of_type("page_text") == nil, "invalid page text yank registers should not send a page_text request")

sent_requests = {}
assert(terminal.yank_page_text("%") == false, "page text yank should reject unwritable one-character registers")
assert(last_request_of_type("page_text") == nil, "unwritable one-character page text registers should not send a page_text request")

_G.nvim_browser_original_job_id_for_page_text_yank = terminal.state().job_id
terminal._test.set_job_id(nil)
assert(terminal.yank_page_text("b") == false, "page text yank should fail without an active serve job")
terminal._test.set_job_id(_G.nvim_browser_original_job_id_for_page_text_yank)

vim.fn.setreg("b", _G.nvim_browser_old_page_text_register)

local old_a_register = vim.fn.getreg("a")
vim.fn.setreg("a", "old register")
assert(terminal.yank_selection("a") == true, "selection yank should send a selection_text request")
local selection_request = last_request_of_type("selection_text")
assert(selection_request ~= nil, "selection yank should use the selection_text serve request")
serve_stdout(nil, { vim.json.encode({
  id = selection_request.id,
  status = "ok",
  selection = "selected from browser",
}), "" })
assert(vim.wait(1000, function()
  return vim.fn.getreg("a") == "selected from browser"
end), "selection yank responses should write the requested register")

warnings = {}
sent_requests = {}
assert(terminal.yank_selection("a") == true, "empty selection yank should still send a selection_text request")
selection_request = last_request_of_type("selection_text")
serve_stdout(nil, { vim.json.encode({
  id = selection_request.id,
  status = "ok",
  selection = "",
}), "" })
assert(vim.wait(1000, function()
  return #warnings > 0
end), "empty selection yank responses should warn")
assert(warnings[#warnings] == "nvim-browser: browser selection yank failed or no browser selection is active", "empty selection yank should use the expected warning")
assert(vim.fn.getreg("a") == "selected from browser", "empty selection yank should not overwrite the register")
vim.fn.setreg("a", old_a_register)

sent_requests = {}
assert(terminal.screenshot("") == false, "screenshot should reject empty paths")
assert(#sent_requests == 0, "empty screenshot paths should not send serve requests")

assert(terminal.screenshot("/tmp/page.png") == true, "screenshot should send a serve screenshot request")
screenshot_request = last_request_of_type("screenshot")
assert(screenshot_request ~= nil, "screenshot should use the screenshot serve request")
assert(screenshot_request.path == "/tmp/page.png", "screenshot should pass the target path")
assert(
  terminal.state().pending_operation == nil,
  "screenshot should not replace the active preview or mark a pending browser load"
)
screenshot_response_seen = false
assert(terminal.screenshot("/tmp/page-2.png", {
  on_response = function(response)
    screenshot_response_seen = response.status == "ok"
  end,
}) == true, "screenshot should allow callers to observe the backend response")
screenshot_request = last_request_of_type("screenshot")
serve_stdout(nil, { vim.json.encode({
  id = screenshot_request.id,
  status = "ok",
}), "" })
assert(vim.wait(1000, function()
  return screenshot_response_seen
end), "screenshot response handlers should run after backend success")

local original_job_id_for_screenshot = terminal.state().job_id
terminal._test.set_job_id(nil)
assert(terminal.screenshot("/tmp/page.png") == false, "screenshot should fail without an active serve job")
terminal._test.set_job_id(original_job_id_for_screenshot)

warnings = {}
sent_requests = {}
assert(terminal.yank_selection("%") == false, "selection yank should reject unwritable one-character registers")
assert(last_request_of_type("selection_text") == nil, "unwritable one-character registers should not send a selection_text request")

terminal._test.handle_reader_response({
  status = "ok",
  text = {
    title = "Start",
    url = "https://example.com/start",
    text = "# Start\n\n[Docs](/docs)\n\nOriginal reader body",
    truncated = false,
  },
})
sent_requests = {}
warnings = {}
reader_follow_result = vim.api.nvim_buf_call(terminal.state().reader_bufnr, function()
  vim.api.nvim_win_set_cursor(0, { 5, 1 })
  return terminal.reader_follow()
end)
assert(reader_follow_result == "https://example.com/docs", "reader follow should navigate with the active serve session: " .. tostring(warnings[#warnings]))
reader_follow_nav_request = last_request_of_type("navigate")
assert(reader_follow_nav_request ~= nil, "reader follow should send a navigate request through serve")
reader_follow_pending_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(reader_follow_pending_id == reader_follow_nav_request.id, "reader follow should mark its navigate request as pending")
serve_stdout(nil, { vim.json.encode({
  id = reader_follow_nav_request.id,
  status = "ok",
  payload = "reader follow frame",
  url = "https://example.com/docs",
  title = "Docs",
  runtime = interactive_runtime(450, 165),
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().pending_operation == nil and last_request_of_type("page_text") ~= nil
end), "successful reader follow stdout responses should clear pending state and request a fresh reader snapshot")
reader_follow_text_request = last_request_of_type("page_text")
serve_stdout(nil, { vim.json.encode({
  id = reader_follow_text_request.id,
  status = "ok",
  text = {
    title = "Docs",
    url = "https://example.com/docs",
    text = "# Docs\n\n[Docs](/docs)\n\nProduction path body",
    truncated = false,
  },
}), "" })
assert(vim.wait(1000, function()
  reader_lines = table.concat(vim.api.nvim_buf_get_lines(terminal.state().reader_bufnr, 0, -1, false), "\n")
  return reader_lines:match("Production path body") ~= nil
end), "reader follow stdout page_text responses should replace the reader buffer")

sent_requests = {}
warnings = {}
reader_follow_result = vim.api.nvim_buf_call(terminal.state().reader_bufnr, function()
  vim.api.nvim_win_set_cursor(0, { 5, 1 })
  return terminal.reader_follow()
end)
assert(reader_follow_result == "https://example.com/docs", "reader follow should send a serve navigation before stdout errors: " .. tostring(warnings[#warnings]))
reader_follow_failed_nav_request = last_request_of_type("navigate")
assert(reader_follow_failed_nav_request ~= nil, "failed reader follow should still send a navigate request")
serve_stdout(nil, { vim.json.encode({
  id = reader_follow_failed_nav_request.id,
  status = "error",
  error = "reader follow failed",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().pending_operation == nil and terminal.state().status_error == "reader follow failed"
end), "failed reader follow stdout responses should clear pending state and surface the error")
assert(last_request_of_type("page_text") == nil, "failed reader follow stdout responses should not request page_text")
reader_lines = table.concat(vim.api.nvim_buf_get_lines(terminal.state().reader_bufnr, 0, -1, false), "\n")
assert(reader_lines:match("Production path body"), "failed reader follow stdout responses should preserve reader content")

sent_requests = {}
fake_timers[1].callback()
assert(vim.wait(1000, function()
  for _, request in ipairs(sent_requests) do
    local ok, decoded = pcall(vim.json.decode, request.payload)
    if ok and decoded.type == "page_state" then
      return true
    end
  end
  return false
end), "live refresh timer should send page-state requests for active serve sessions")
local live_page_state_id = terminal.state().live_refresh_request_id
assert(live_page_state_id ~= nil, "live refresh should track an in-flight page-state request")
assert(terminal._test.response_handler_count() == 1, "live refresh should register one response handler")
serve_stdout(nil, { vim.json.encode({
  id = 0,
  status = "error",
  error = "unknown variant `page_state`",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().live_refresh_request_id == nil
end), "protocol errors should clear in-flight live refresh requests")
assert(terminal._test.response_handler_count() == 0, "protocol errors should clear the live refresh response handler")
sent_requests = {}
assert(terminal.refresh() == true, "manual refresh should still work after a live refresh protocol error")
terminal._test.clear_in_flight_capture()

sent_requests = {}
fake_timers[1].callback()
assert(vim.wait(1000, function()
  live_page_state_id = terminal.state().live_refresh_request_id
  return live_page_state_id ~= nil and last_request_of_type("page_state") ~= nil
end), "live refresh should recover after a protocol error is cleared")

sent_requests = {}
serve_stdout(nil, { vim.json.encode({
  id = live_page_state_id,
  status = "ok",
  url = "https://example.com/live-title",
  title = "Live Title Changed",
  page = {
    scroll_y = 0,
    viewport_height = 600,
    document_height = 1600,
  },
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().live_refresh_request_id == nil and terminal.state().current_title == "Live Title Changed"
end), "page-state responses should update lightweight metadata")
_G.nvim_browser_adaptive_capture_timer = nvim_browser_latest_timer()
assert(
  _G.nvim_browser_adaptive_capture_timer ~= fake_timers[1],
  "changed page-state metadata should schedule a debounced full-frame capture"
)
assert(_G.nvim_browser_adaptive_capture_timer.starts[1].timeout == 100, "adaptive capture should use a short debounce")
sent_requests = {}
fake_timers[1].callback()
vim.wait(50)
assert(
  last_request_of_type("page_state") == nil,
  "live refresh should not send page-state while an adaptive capture is debounced"
)
_G.nvim_browser_adaptive_capture_timer.callback()
assert(vim.wait(1000, function()
  local capture = last_request_of_type("capture")
  return capture ~= nil and terminal.state().live_refresh_request_id == capture.id
end), "adaptive capture timer should send one tracked full-frame capture")
_G.nvim_browser_adaptive_capture_id = terminal.state().live_refresh_request_id
_G.nvim_browser_adaptive_capture_timer.callback()
vim.wait(50)
assert(
  #nvim_browser_requests_of_type("capture") == 1,
  "adaptive capture debounce should not send duplicate captures while one is in flight"
)
terminal._test.clear_in_flight_capture()

sent_requests = {}
fake_timers[1].callback()
assert(vim.wait(1000, function()
  live_page_state_id = terminal.state().live_refresh_request_id
  return live_page_state_id ~= nil and last_request_of_type("page_state") ~= nil
end), "live refresh should send a page-state request before disabled adaptive capture")
serve_stdout(nil, { vim.json.encode({
  id = live_page_state_id,
  status = "ok",
  url = "https://example.com/disable-change",
  title = "Disable Change",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().live_refresh_request_id == nil
end), "disabled adaptive capture setup should clear live tracking")
_G.nvim_browser_disabled_adaptive_capture_timer = nvim_browser_latest_timer()
terminal.configure({ live_refresh = { enabled = false } })
sent_requests = {}
_G.nvim_browser_disabled_adaptive_capture_timer.callback()
vim.wait(50)
assert(last_request_of_type("capture") == nil, "disabling live refresh should cancel scheduled adaptive captures")
terminal.configure({ live_refresh = { enabled = true, interval_ms = 1500 } })
_G.nvim_browser_live_timer_after_reenable = nvim_browser_latest_timer()

sent_requests = {}
_G.nvim_browser_live_timer_after_reenable.callback()
assert(vim.wait(1000, function()
  live_page_state_id = terminal.state().live_refresh_request_id
  return live_page_state_id ~= nil and last_request_of_type("page_state") ~= nil
end), "live refresh should send a stable page-state request after adaptive capture clears")
_G.nvim_browser_timer_count_before_stable_page_state = #fake_timers
serve_stdout(nil, { vim.json.encode({
  id = live_page_state_id,
  status = "ok",
  url = "https://example.com/disable-change",
  title = "Disable Change",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().live_refresh_request_id == nil
end), "stable page-state responses should clear live tracking")
vim.wait(50)
assert(#fake_timers == _G.nvim_browser_timer_count_before_stable_page_state, "stable page-state responses should not schedule adaptive captures")

terminal._test.apply_serve_response({
  id = live_page_state_id + 800,
  status = "ok",
  url = "file:///tmp/nvbrowser-README-wrapper.html",
  display_url = "file:///tmp/README.md",
  title = "README",
})
sent_requests = {}
_G.nvim_browser_live_timer_after_reenable.callback()
assert(vim.wait(1000, function()
  live_page_state_id = terminal.state().live_refresh_request_id
  return live_page_state_id ~= nil and last_request_of_type("page_state") ~= nil
end), "live refresh should send a page-state request for wrapper previews")
_G.nvim_browser_timer_count_before_wrapper_page_state = #fake_timers
serve_stdout(nil, { vim.json.encode({
  id = live_page_state_id,
  status = "ok",
  url = "file:///tmp/nvbrowser-README-wrapper.html",
  display_url = "file:///tmp/README.md",
  title = "README",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().live_refresh_request_id == nil
end), "stable wrapper page-state responses should clear live tracking")
vim.wait(50)
assert(
  #fake_timers == _G.nvim_browser_timer_count_before_wrapper_page_state,
  "stable wrapper page-state responses should compare display URLs and avoid adaptive capture"
)

terminal._test.apply_serve_response({
  id = live_page_state_id + 900,
  status = "ok",
  url = "https://example.com/disable-change",
  title = "Disable Change",
  dom_epoch = 900,
})
assert(terminal.state().dom_epoch == 900, "capture metadata should establish the current DOM epoch baseline")

sent_requests = {}
_G.nvim_browser_live_timer_after_reenable.callback()
assert(vim.wait(1000, function()
  live_page_state_id = terminal.state().live_refresh_request_id
  return live_page_state_id ~= nil and last_request_of_type("page_state") ~= nil
end), "live refresh should send a page-state request before same DOM epoch check")
_G.nvim_browser_timer_count_before_same_dom_epoch = #fake_timers
serve_stdout(nil, { vim.json.encode({
  id = live_page_state_id,
  status = "ok",
  url = "https://example.com/disable-change",
  title = "Disable Change",
  dom_epoch = 900,
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().live_refresh_request_id == nil
end), "same DOM epoch page-state responses should clear live tracking")
vim.wait(50)
assert(
  #fake_timers == _G.nvim_browser_timer_count_before_same_dom_epoch,
  "same DOM epoch page-state responses should not schedule adaptive captures"
)

sent_requests = {}
_G.nvim_browser_live_timer_after_reenable.callback()
assert(vim.wait(1000, function()
  live_page_state_id = terminal.state().live_refresh_request_id
  return live_page_state_id ~= nil and last_request_of_type("page_state") ~= nil
end), "live refresh should send a page-state request before changed DOM epoch check")
serve_stdout(nil, { vim.json.encode({
  id = live_page_state_id,
  status = "ok",
  url = "https://example.com/disable-change",
  title = "Disable Change",
  dom_epoch = 901,
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().live_refresh_request_id == nil and terminal.state().dom_epoch == 901
end), "changed DOM epoch page-state responses should update DOM epoch metadata")
_G.nvim_browser_dom_epoch_adaptive_capture_timer = nvim_browser_latest_timer()
assert(
  _G.nvim_browser_dom_epoch_adaptive_capture_timer ~= _G.nvim_browser_live_timer_after_reenable,
  "changed DOM epoch without visible metadata changes should schedule adaptive capture"
)
sent_requests = {}
_G.nvim_browser_dom_epoch_adaptive_capture_timer.callback()
assert(vim.wait(1000, function()
  local capture = last_request_of_type("capture")
  return capture ~= nil and terminal.state().live_refresh_request_id == capture.id
end), "DOM epoch adaptive capture timer should send a tracked full-frame capture")
terminal._test.clear_in_flight_capture()

sent_requests = {}
_G.nvim_browser_live_timer_after_reenable.callback()
assert(vim.wait(1000, function()
  live_page_state_id = terminal.state().live_refresh_request_id
  return live_page_state_id ~= nil and last_request_of_type("page_state") ~= nil
end), "live refresh should send another page-state request after adaptive capture clears")
terminal._test.set_pending_operation({ id = live_page_state_id + 100, label = "loading", target = "https://example.com/pending" })
serve_stdout(nil, { vim.json.encode({
  id = live_page_state_id,
  status = "ok",
  url = "https://example.com/pending-change",
  title = "Pending Change",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().live_refresh_request_id == nil
end), "page-state responses should still clear live tracking while an operation is pending")
_G.nvim_browser_timer_count_after_pending_page_state = #fake_timers
vim.wait(50)
assert(
  #fake_timers == _G.nvim_browser_timer_count_after_pending_page_state,
  "page-state changes should not schedule adaptive capture while an operation is pending"
)
terminal._test.clear_pending_operation(live_page_state_id + 100)

sent_requests = {}
_G.nvim_browser_live_timer_after_reenable.callback()
assert(vim.wait(1000, function()
  live_page_state_id = terminal.state().live_refresh_request_id
  return live_page_state_id ~= nil and last_request_of_type("page_state") ~= nil
end), "live refresh should send a page-state request before text-mode suppression")
local text_mode_keys = { "\27" }
local text_mode_index = 0
assert(terminal.start_text_mode({
  getcharstr = function()
    text_mode_index = text_mode_index + 1
    if text_mode_index == 1 then
      serve_stdout(nil, { vim.json.encode({
        id = live_page_state_id,
        status = "ok",
        url = "https://example.com/text-mode-change",
        title = "Text Mode Change",
      }), "" })
      vim.wait(50)
      _G.nvim_browser_timer_count_during_text_mode_page_state = #fake_timers
    end
    return text_mode_keys[text_mode_index]
  end,
}) == true, "browser text mode should run while page-state responses are processed")
assert(
  #fake_timers <= _G.nvim_browser_timer_count_during_text_mode_page_state + 1,
  "page-state changes should not schedule adaptive capture while text mode is active beyond the exit capture watchdog"
)
terminal._test.clear_in_flight_capture()

sent_requests = {}
_G.nvim_browser_live_timer_after_reenable.callback()
assert(vim.wait(1000, function()
  live_page_state_id = terminal.state().live_refresh_request_id
  return live_page_state_id ~= nil and last_request_of_type("page_state") ~= nil
end), "live refresh should send a page-state request before resize suppression")
serve_stdout(nil, { vim.json.encode({
  id = live_page_state_id,
  status = "ok",
  url = "https://example.com/resize-change",
  title = "Resize Change",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().live_refresh_request_id == nil
end), "resize suppression setup should clear live tracking")
_G.nvim_browser_adaptive_capture_resize_timer = nvim_browser_latest_timer()
vim.api.nvim_exec_autocmds("VimResized", {})
sent_requests = {}
_G.nvim_browser_adaptive_capture_resize_timer.callback()
vim.wait(50)
assert(last_request_of_type("capture") == nil, "adaptive capture should not fire while resize debounce is pending")
flush_latest_timer()

sent_requests = {}
_G.nvim_browser_live_timer_after_reenable.callback()
assert(vim.wait(1000, function()
  live_page_state_id = terminal.state().live_refresh_request_id
  return live_page_state_id ~= nil and last_request_of_type("page_state") ~= nil
end), "live refresh should send a page-state request before scroll cancellation")

sent_requests = {}
assert(terminal.scroll(120, 0) == true, "scroll input should be accepted for coalescing")
assert(terminal.scroll(120, 0) == true, "second scroll input should be accepted for coalescing")
assert(terminal.scroll(120, 0) == true, "third scroll input should be accepted for coalescing")
assert(#nvim_browser_requests_of_type("scroll") == 0, "rapid scroll input should be delayed for coalescing")
assert(terminal.state().live_refresh_request_id == nil, "queued scroll should invalidate stale live page-state requests")
fake_timers[1].callback()
vim.wait(50)
_G.nvim_browser_live_page_state_while_scroll_queued_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "page_state" then
    _G.nvim_browser_live_page_state_while_scroll_queued_seen = true
  end
end
assert(not _G.nvim_browser_live_page_state_while_scroll_queued_seen, "live refresh should not request page_state while scroll input is queued")
serve_stdout(nil, { vim.json.encode({
  id = live_page_state_id,
  status = "ok",
  url = "https://example.com/stale-before-scroll",
  title = "Stale Before Scroll",
}), "" })
_G.nvim_browser_stale_before_scroll_applied = vim.wait(200, function()
  return terminal.state().current_title == "Stale Before Scroll"
end)
assert(not _G.nvim_browser_stale_before_scroll_applied, "page-state response made stale by queued scroll should not update metadata")
assert(nvim_browser_latest_timer() ~= nil, "coalesced scroll should create a trailing timer")
nvim_browser_latest_timer().callback()
assert(vim.wait(1000, function()
  return #nvim_browser_requests_of_type("scroll") == 1
end), "coalesced scroll should flush one scroll request")
_G.nvim_browser_coalesced_scroll_request = nvim_browser_requests_of_type("scroll")[1]
assert(_G.nvim_browser_coalesced_scroll_request.delta_y == 360, "coalesced scroll should accumulate vertical deltas")
assert(_G.nvim_browser_coalesced_scroll_request.delta_x == 0, "coalesced scroll should preserve horizontal deltas")
assert(terminal.state().pending_operation ~= nil, "coalesced scroll flush should mark a pending operation")
assert(terminal.state().pending_operation.label == "scroll", "coalesced scroll pending footer should use a scroll label")
terminal._test.dispatch_serve_response_handler({ id = _G.nvim_browser_coalesced_scroll_request.id, status = "ok" })
terminal._test.clear_pending_operation(_G.nvim_browser_coalesced_scroll_request.id)

sent_requests = {}
assert(terminal.click_point(12, 24) == true, "point click should work while live refresh is enabled")
local point_click_pending_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(point_click_pending_id ~= nil, "point click should mark the browser click as pending")
sent_requests = {}
fake_timers[1].callback()
local live_page_state_during_click_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "page_state" then
    live_page_state_during_click_seen = true
  end
end
assert(not live_page_state_during_click_seen, "live refresh should not request page_state while a click is pending")
sent_requests = {}
assert(terminal.scroll(30, 0) == true, "scroll input should still queue while a click is pending")
flush_latest_timer()
_G.nvim_browser_scroll_while_click_pending = last_request_of_type("scroll")
assert(_G.nvim_browser_scroll_while_click_pending ~= nil, "queued scroll should flush while a click is pending")
assert(
  terminal.state().pending_operation ~= nil and terminal.state().pending_operation.id == point_click_pending_id,
  "coalesced scroll should not replace an existing pending click operation"
)
terminal._test.clear_pending_operation(point_click_pending_id)

terminal._test.apply_serve_response({
  id = live_page_state_id,
  status = "ok",
  page = {
    scroll_y = 0,
    viewport_height = 600,
    document_height = 2000,
  },
  runtime = {
    viewport = { width = 800, height = 640, device_scale_factor = 1 },
  },
})
sent_requests = {}
assert(terminal.page_scroll(1) == true, "page_scroll should send a scroll request")
assert(#nvim_browser_requests_of_type("scroll") == 0, "page_scroll should use scroll coalescing")
nvim_browser_latest_timer().callback()
assert(vim.wait(1000, function()
  return #nvim_browser_requests_of_type("scroll") == 1
end), "page_scroll should flush one coalesced scroll request")
local page_down_request = last_request_of_type("scroll")
assert(page_down_request ~= nil, "page_scroll should reuse the scroll JSONL request type")
assert(page_down_request.delta_y == 540, "page_scroll should use 90 percent of page viewport height")
assert(page_down_request.delta_x == 0, "page_scroll should not scroll horizontally by default")

sent_requests = {}
assert(terminal.zoom_in() == true, "zoom_in should send a zoom request")
zoom_in_request = last_request_of_type("zoom")
assert(zoom_in_request ~= nil, "zoom_in should use the zoom JSONL request type")
assert(zoom_in_request.scale == 1.1, "zoom_in should increase the page scale by the default step")

terminal._test.dispatch_serve_response_handler({ id = zoom_in_request.id, status = "error", error = "zoom failed" })
terminal._test.clear_pending_operation(zoom_in_request.id)
assert(not terminal._test.preview_footer_line(120):find("zoom="), "failed zoom responses should not show a zoom label")
sent_requests = {}
assert(terminal.zoom_in() == true, "zoom_in should retry from the last applied zoom after backend failure")
retry_zoom_in_request = last_request_of_type("zoom")
assert(retry_zoom_in_request.scale == 1.1, "failed zoom responses should not advance client-side zoom state")
terminal._test.dispatch_serve_response_handler({ id = retry_zoom_in_request.id, status = "ok" })
terminal._test.clear_pending_operation(retry_zoom_in_request.id)
assert(terminal._test.preview_footer_line(120):find("zoom=110%%"), "successful zoom responses should show current zoom in the footer")
assert(terminal.state().zoom_scale == 1.1, "terminal state should expose the applied zoom scale")

sent_requests = {}
assert(terminal.zoom_in() == true, "zoom_in should compound after an applied zoom response")
compounded_zoom_in_request = last_request_of_type("zoom")
assert(compounded_zoom_in_request.scale == 1.21, "successful zoom responses should advance client-side zoom state")
terminal._test.dispatch_serve_response_handler({ id = compounded_zoom_in_request.id, status = "ok" })
terminal._test.clear_pending_operation(compounded_zoom_in_request.id)

sent_requests = {}
assert(terminal.zoom_out() == true, "zoom_out should send a zoom request")
zoom_out_request = last_request_of_type("zoom")
assert(zoom_out_request.scale == 1.1, "zoom_out should decrease the page scale by the default step")
terminal._test.dispatch_serve_response_handler({ id = zoom_out_request.id, status = "ok" })
terminal._test.clear_pending_operation(zoom_out_request.id)

sent_requests = {}
assert(terminal.zoom(1.25) == true, "zoom should send an exact zoom request")
_G.nvim_browser_exact_zoom_request = last_request_of_type("zoom")
assert(_G.nvim_browser_exact_zoom_request ~= nil, "zoom should use the zoom JSONL request type")
assert(_G.nvim_browser_exact_zoom_request.scale == 1.25, "zoom should preserve the requested exact scale")
terminal._test.dispatch_serve_response_handler({ id = _G.nvim_browser_exact_zoom_request.id, status = "ok" })
terminal._test.clear_pending_operation(_G.nvim_browser_exact_zoom_request.id)
assert(terminal._test.preview_footer_line(120):find("zoom=125%%"), "exact zoom should show current zoom in the footer")
assert(terminal.state().zoom_scale == 1.25, "exact zoom should update terminal zoom state after success")

sent_requests = {}
assert(terminal.zoom(1.234) == true, "zoom should preserve non-step exact zoom values")
_G.nvim_browser_precise_zoom_request = last_request_of_type("zoom")
assert(_G.nvim_browser_precise_zoom_request.scale == 1.234, "exact zoom should not round requested scales")
terminal._test.dispatch_serve_response_handler({ id = _G.nvim_browser_precise_zoom_request.id, status = "ok" })
terminal._test.clear_pending_operation(_G.nvim_browser_precise_zoom_request.id)
assert(terminal.state().zoom_scale == 1.234, "exact zoom should store precise applied scales")

sent_requests = {}
assert(terminal.zoom(nil) == false, "zoom should reject missing scales")
assert(last_request_of_type("zoom") == nil, "zoom should not send missing scales")
assert(terminal.zoom(0) == false, "zoom should reject zero scales")
assert(last_request_of_type("zoom") == nil, "zoom should not send zero scales")
assert(terminal.zoom(1 / 0) == false, "zoom should reject non-finite scales")
assert(last_request_of_type("zoom") == nil, "zoom should not send non-finite scales")

sent_requests = {}
assert(terminal.zoom_reset() == true, "zoom_reset should send a zoom request")
zoom_reset_request = last_request_of_type("zoom")
assert(zoom_reset_request.scale == 1.0, "zoom_reset should restore default page scale")
terminal._test.dispatch_serve_response_handler({ id = zoom_reset_request.id, status = "ok" })
terminal._test.clear_pending_operation(zoom_reset_request.id)
assert(not terminal._test.preview_footer_line(120):find("zoom="), "zoom_reset should remove the footer zoom label")
assert(terminal.state().zoom_scale == 1.0, "zoom_reset should restore state zoom scale")

sent_requests = {}
assert(terminal.page_scroll(1, { fraction = 0.5 }) == true, "page_scroll should support custom viewport fractions")
flush_latest_timer()
local half_page_down_request = last_request_of_type("scroll")
assert(half_page_down_request.delta_y == 300, "half-page down should use 50 percent of page viewport height")

sent_requests = {}
assert(terminal.page_scroll(-1, { fraction = 0.5 }) == true, "page_scroll should support backward half-page scrolling")
flush_latest_timer()
local half_page_up_request = last_request_of_type("scroll")
assert(half_page_up_request.delta_y == -300, "half-page up should negate 50 percent of page viewport height")

terminal._test.apply_serve_response({
  id = live_page_state_id + 1,
  status = "ok",
  page = {
    scroll_y = 250,
    viewport_height = 600,
    document_height = 1600,
  },
  runtime = {
    viewport = { width = 800, height = 640, device_scale_factor = 1 },
  },
})
sent_requests = {}
assert(terminal.scroll_top() == true, "scroll_top should send a scroll request")
flush_latest_timer()
local top_request = last_request_of_type("scroll")
assert(top_request.delta_y == -250, "scroll_top should scroll back by current page scroll position")

sent_requests = {}
assert(terminal.scroll_bottom() == true, "scroll_bottom should send a scroll request")
flush_latest_timer()
local bottom_request = last_request_of_type("scroll")
assert(bottom_request.delta_y == 750, "scroll_bottom should scroll to remaining document bottom")

terminal._test.apply_serve_response({
  id = live_page_state_id + 2,
  status = "ok",
  page = {
    scroll_y = 250.5,
    viewport_height = 600.25,
    document_height = 1600.5,
  },
  runtime = {
    viewport = { width = 800, height = 640, device_scale_factor = 1 },
  },
})
sent_requests = {}
assert(terminal.scroll_top() == true, "scroll_top should handle fractional page metrics")
flush_latest_timer()
local fractional_top_request = last_request_of_type("scroll")
assert(fractional_top_request.delta_y == -251, "scroll_top should round fractional deltas to integer JSONL")

sent_requests = {}
assert(terminal.scroll_bottom() == true, "scroll_bottom should handle fractional page metrics")
flush_latest_timer()
local fractional_bottom_request = last_request_of_type("scroll")
assert(fractional_bottom_request.delta_y == 750, "scroll_bottom should round fractional deltas to integer JSONL")

sent_requests = {}
assert(terminal.page_scroll(-1) == true, "page_scroll should support backward scrolling")
flush_latest_timer()
local page_up_request = last_request_of_type("scroll")
assert(page_up_request ~= nil, "backward page_scroll should send a scroll request")
assert(page_up_request.delta_y == -540, "backward page_scroll should negate the viewport-based delta")

terminal._test.apply_serve_response({
  id = live_page_state_id + 3,
  status = "ok",
  page = {
    viewport_height = 0,
  },
  runtime = {
    viewport = { width = 800, height = 500, device_scale_factor = 1 },
  },
})
sent_requests = {}
assert(terminal.page_scroll(1) == true, "page_scroll should fall back to runtime viewport metadata")
flush_latest_timer()
local runtime_page_request = last_request_of_type("scroll")
assert(runtime_page_request.delta_y == 450, "runtime viewport fallback should handle invalid page metrics")

sent_requests = {}
assert(terminal.page_scroll(1, { fraction = 0.5 }) == true, "half page scroll should fall back to runtime viewport metadata")
flush_latest_timer()
local runtime_half_page_request = last_request_of_type("scroll")
assert(runtime_half_page_request.delta_y == 250, "runtime viewport fallback should honor half-page fraction")

terminal._test.apply_serve_response({ id = live_page_state_id + 4, status = "ok", runtime = {} })
sent_requests = {}
assert(terminal.page_scroll(1) == true, "page_scroll should fall back when no metadata exists")
flush_latest_timer()
local fallback_page_request = last_request_of_type("scroll")
assert(fallback_page_request.delta_y == 400, "page_scroll should preserve the existing 400px fallback")

sent_requests = {}
assert(terminal.scroll_top() == true, "scroll_top should fall back without page metrics")
flush_latest_timer()
local fallback_top_request = last_request_of_type("scroll")
assert(fallback_top_request.delta_y == -40000, "scroll_top fallback should send a large upward scroll")

sent_requests = {}
assert(terminal.scroll_bottom() == true, "scroll_bottom should fall back without page metrics")
flush_latest_timer()
local fallback_bottom_request = last_request_of_type("scroll")
assert(fallback_bottom_request.delta_y == 40000, "scroll_bottom fallback should send a large downward scroll")

sent_requests = {}
assert(terminal.navigate("https://example.com/new") == true, "navigation should be allowed while a live page-state request is in flight")
serve_stdout(nil, { vim.json.encode({
  id = live_page_state_id,
  status = "ok",
  url = "https://example.com/stale",
  title = "Stale Page State",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().live_refresh_request_id == nil
end), "late live page-state responses should clear in-flight request state")
assert(
  terminal.state().current_title ~= "Stale Page State",
  "late live page-state responses should not overwrite navigation-pending preview metadata"
)
assert(
  terminal.state().pending_operation ~= nil,
  "late live page-state responses should not clear navigation pending feedback"
)
assert(terminal._test.response_handler_count() == 0, "stale live page-state handling should remove the response handler")
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
local page_state_while_pending = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "page_state" then
    page_state_while_pending = true
  end
end
assert(not page_state_while_pending, "live refresh should not send page_state while an operation is pending")
terminal._test.clear_pending_operation(777)

jobstart_calls = { jobstart_calls[#jobstart_calls] }
jobstop_calls = {}
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

sent_requests = {}
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--image-fit", "contain", "--image", "/tmp/image.png" })
local image_state = terminal.state()
local image_navigate_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "navigate_image" and decoded.path == "/tmp/image.png" and decoded.fit == "contain" then
    image_navigate_seen = true
  end
end
assert(#jobstart_calls == 1, "opening an image in an active serve session should reuse the existing job")
assert(image_state.bufnr == first_state.bufnr, "serve image reuse should keep the same preview buffer")
assert(image_state.job_id == first_state.job_id, "serve image reuse should keep the same backend job")
assert(image_state.last_target == "/tmp/image.png", "serve image reuse should update the remembered target")
assert(image_navigate_seen, "serve image reuse should send a navigate_image request for the image preview target")
terminal._test.clear_pending_operation(terminal.state().pending_operation.id)

terminal._test.apply_serve_response({
  id = 30001,
  status = "ok",
  payload = "image wrapper frame",
  url = "file:///tmp/nvbrowser-image-image-wrapper.html",
  display_url = "file:///tmp/image.png",
  title = "image.png",
})
sent_requests = {}
assert(terminal.refresh() == true, "image preview refresh should regenerate the wrapper source")
_G.nvim_browser_image_refresh_request = last_request_of_type("navigate_image")
assert(
  _G.nvim_browser_image_refresh_request ~= nil
    and _G.nvim_browser_image_refresh_request.path == "/tmp/image.png"
    and _G.nvim_browser_image_refresh_request.fit == "contain",
  "image preview refresh should send navigate_image with the original path and fit"
)
assert(last_request_of_type("capture") == nil, "image preview refresh should not recapture the stale wrapper")
terminal._test.clear_pending_operation(terminal.state().pending_operation.id)

sent_requests = {}
assert(terminal.navigate("file:///tmp/query-image.png?size=1") == true, "active image file URL queries should navigate")
_G.nvim_browser_image_query_request = last_request_of_type("navigate_image")
assert(
  _G.nvim_browser_image_query_request ~= nil
    and _G.nvim_browser_image_query_request.path == "/tmp/query-image.png"
    and _G.nvim_browser_image_query_request.fit == "contain"
    and _G.nvim_browser_image_query_request.display_url == "file:///tmp/query-image.png?size=1",
  "active image file URL queries should send navigate_image with path, fit, and display URL"
)
terminal._test.clear_pending_operation(terminal.state().pending_operation.id)

sent_requests = {}
assert(
  terminal.navigate("https://example.com/pending-from-image") == true,
  "test setup should send a pending navigation from an image preview"
)
_G.nvim_browser_pending_from_image_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(_G.nvim_browser_pending_from_image_id ~= nil, "pending navigation from image preview should be tracked")
sent_requests = {}
assert(terminal.refresh() == true, "refresh during pending navigation should preserve existing refresh behavior")
assert(
  terminal.state().pending_operation and terminal.state().pending_operation.id == _G.nvim_browser_pending_from_image_id,
  "image preview refresh should not replace a pending navigation"
)
assert(
  last_request_of_type("navigate_image") == nil,
  "image preview refresh should not regenerate the wrapper while another navigation is pending"
)
assert(last_request_of_type("capture") == nil, "image preview refresh should not capture while another navigation is pending")
terminal._test.clear_pending_operation(_G.nvim_browser_pending_from_image_id)

terminal._test.apply_serve_response({
  id = 30002,
  status = "ok",
  payload = "markdown wrapper frame",
  url = "file:///tmp/nvbrowser-markdown-wrapper.html",
  display_url = "file:///tmp/docs/README.md",
  title = "README.md",
})
sent_requests = {}
assert(
  terminal.navigate("https://example.com/pending-from-markdown") == true,
  "test setup should send a pending navigation from a Markdown preview"
)
_G.nvim_browser_pending_from_markdown_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(_G.nvim_browser_pending_from_markdown_id ~= nil, "pending navigation from Markdown preview should be tracked")
sent_requests = {}
assert(terminal.refresh() == true, "refresh during pending Markdown navigation should be treated as handled")
assert(
  terminal.state().pending_operation and terminal.state().pending_operation.id == _G.nvim_browser_pending_from_markdown_id,
  "Markdown preview refresh should not replace a pending navigation"
)
assert(
  last_request_of_type("navigate_markdown") == nil,
  "Markdown preview refresh should not regenerate the wrapper while another navigation is pending"
)
assert(last_request_of_type("capture") == nil, "Markdown preview refresh should not capture while another navigation is pending")
terminal._test.clear_pending_operation(_G.nvim_browser_pending_from_markdown_id)

terminal._test.apply_serve_response({
  id = 30003,
  status = "ok",
  payload = "direct web frame",
  url = "https://example.com/current",
  title = "Direct Current",
})
sent_requests = {}
assert(
  terminal.navigate("https://example.com/pending-from-web") == true,
  "test setup should send a pending navigation from a direct web page"
)
_G.nvim_browser_pending_from_web_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(_G.nvim_browser_pending_from_web_id ~= nil, "pending navigation from a direct web page should be tracked")
sent_requests = {}
assert(terminal.refresh() == true, "direct web refresh during pending navigation should keep existing capture behavior")
assert(
  terminal.state().pending_operation and terminal.state().pending_operation.id == _G.nvim_browser_pending_from_web_id,
  "direct web refresh should not replace a pending navigation"
)
assert(last_request_of_type("capture") ~= nil, "direct web refresh should still request a capture while navigation is pending")
terminal._test.clear_pending_operation(_G.nvim_browser_pending_from_web_id)

sent_requests = {}
assert(terminal.navigate("https://example.com/older") == true, "test setup should send an older navigation")
local older_navigation_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(older_navigation_id ~= nil, "older navigation should be tracked as pending")
sent_requests = {}
assert(terminal.navigate("https://example.com/newer") == true, "test setup should send a newer navigation")
local newer_navigation_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(newer_navigation_id ~= nil and newer_navigation_id ~= older_navigation_id, "newer navigation should replace older pending operation")
local active_hint_count_before_older_navigation = #terminal.state().element_hints
serve_stdout(nil, { vim.json.encode({
  id = older_navigation_id,
  status = "ok",
  payload = "older navigation frame",
  url = "https://example.com/older",
  title = "Older Navigation",
  download = {
    path = "/tmp/nvbrowser-downloads/stale-complete.txt",
    suggested_filename = "stale-complete.txt",
    status = "completed",
  },
  hints = {
    {
      id = 99,
      kind = "button",
      label = "Older Button",
      x = 1,
      y = 2,
      width = 3,
      height = 4,
      clickable = true,
      focusable = true,
    },
  },
}), "" })
local older_navigation_applied = vim.wait(200, function()
  return terminal.state().current_title == "Older Navigation"
end)
assert(not older_navigation_applied, "late older navigation response should not overwrite newer pending navigation state")
assert(
  terminal.state().pending_operation ~= nil and terminal.state().pending_operation.id == newer_navigation_id,
  "late older navigation response should not clear the newer pending operation"
)
assert(
  #terminal.state().element_hints == active_hint_count_before_older_navigation,
  "late older navigation response should not replace active hints"
)
assert(
  terminal.downloads()[#terminal.downloads()].path == "/tmp/nvbrowser-downloads/stale-complete.txt",
  "late older navigation responses should still record completed downloads"
)
serve_stdout(nil, { vim.json.encode({
  id = newer_navigation_id,
  status = "ok",
  payload = "newer navigation frame",
  url = "https://example.com/newer",
  title = "Newer Navigation",
  hints = {
    {
      id = 100,
      kind = "button",
      label = "Newer Button",
      x = 10,
      y = 20,
      width = 30,
      height = 40,
      clickable = true,
      focusable = true,
    },
  },
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title == "Newer Navigation"
end), "latest navigation response should still update browser metadata")
assert(terminal.state().pending_operation == nil, "latest navigation response should clear its pending operation")
assert(#terminal.state().element_hints == 1, "latest navigation response should update active hints")
serve_stdout(nil, { vim.json.encode({
  id = older_navigation_id,
  status = "ok",
  payload = "older navigation after latest frame",
  url = "https://example.com/older-after-latest",
  title = "Older Navigation After Latest",
  hints = {
    {
      id = 101,
      kind = "button",
      label = "Older After Latest Button",
      x = 11,
      y = 22,
      width = 33,
      height = 44,
      clickable = true,
      focusable = true,
    },
  },
}), "" })
local older_after_latest_applied = vim.wait(200, function()
  return terminal.state().current_title == "Older Navigation After Latest"
end)
assert(not older_after_latest_applied, "late older navigation response should not apply after the newer response has completed")
assert(terminal.state().current_title == "Newer Navigation", "newer navigation metadata should remain current")
assert(#terminal.state().element_hints == 1, "newer navigation hints should remain current")

terminal._test.clear_pending_operation()
sent_requests = {}
assert(terminal.navigate("https://example.com/admitted") == true, "test setup should send an admitted navigation")
_G.nvim_browser_admitted_navigation_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(_G.nvim_browser_admitted_navigation_id ~= nil, "admitted navigation should be tracked as pending")
sent_requests = {}
assert(terminal.scroll(200) == true, "non-navigation requests may still be sent while navigation is pending")
flush_latest_timer()
_G.nvim_browser_newer_scroll_id = last_request_of_type("scroll").id
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_newer_scroll_id,
  status = "ok",
  payload = "newer scroll during navigation",
  url = "https://example.com/scrolled-during-navigation",
  title = "Scrolled During Navigation",
  hints = {
    {
      id = 101,
      kind = "button",
      label = "Scroll Button",
      x = 1,
      y = 2,
      width = 3,
      height = 4,
      clickable = true,
      focusable = true,
    },
  },
}), "" })
assert(not vim.wait(200, function()
  return terminal.state().current_title == "Scrolled During Navigation"
end), "newer non-navigation response should not overwrite navigation-admitted state")
assert(
  terminal.state().pending_operation ~= nil and terminal.state().pending_operation.id == _G.nvim_browser_admitted_navigation_id,
  "newer non-navigation response should not clear the admitted navigation operation"
)
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_admitted_navigation_id,
  status = "ok",
  payload = "admitted navigation frame",
  url = "https://example.com/admitted",
  title = "Admitted Navigation",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().pending_operation == nil and terminal.state().current_title == "Admitted Navigation"
end), "admitted navigation response should update state and clear pending operation")

terminal._test.clear_pending_operation()
sent_requests = {}
assert(terminal.navigate("https://example.com/admitted-zoom") == true, "test setup should send navigation before suppressed zoom")
_G.nvim_browser_zoom_navigation_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(_G.nvim_browser_zoom_navigation_id ~= nil, "zoom navigation should be tracked as pending")
sent_requests = {}
assert(terminal.zoom_in() == true, "pending-class non-navigation requests may still be sent while navigation is pending")
_G.nvim_browser_suppressed_zoom_id = last_request_of_type("zoom").id
assert(
  terminal.state().pending_operation ~= nil and terminal.state().pending_operation.id == _G.nvim_browser_zoom_navigation_id,
  "suppressed non-navigation pending requests should not replace admitted navigation pending feedback"
)
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_suppressed_zoom_id,
  status = "ok",
  payload = "suppressed zoom frame",
  url = "https://example.com/suppressed-zoom",
  title = "Suppressed Zoom",
}), "" })
assert(not vim.wait(200, function()
  return terminal.state().current_title == "Suppressed Zoom"
end), "suppressed non-navigation pending responses should not update browser state")
assert(
  terminal.state().pending_operation ~= nil and terminal.state().pending_operation.id == _G.nvim_browser_zoom_navigation_id,
  "suppressed non-navigation pending responses should not clear admitted navigation feedback"
)
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_zoom_navigation_id,
  status = "ok",
  payload = "admitted zoom navigation frame",
  url = "https://example.com/admitted-zoom",
  title = "Admitted Zoom Navigation",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().pending_operation == nil and terminal.state().current_title == "Admitted Zoom Navigation"
end), "admitted navigation should clear pending after suppressed non-navigation pending requests")

terminal._test.clear_pending_operation()
sent_requests = {}
assert(terminal.navigate("https://example.com/admitted-find") == true, "test setup should send a navigation before stale find")
_G.nvim_browser_find_navigation_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(_G.nvim_browser_find_navigation_id ~= nil, "find navigation should be tracked as pending")
sent_requests = {}
assert(terminal.find_text("stale") == true, "find requests may still be sent while navigation is pending")
_G.nvim_browser_stale_find_id = last_request_of_type("find_text").id
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_stale_find_id,
  status = "ok",
  found = true,
  match_count = 9,
}), "" })
vim.wait(100)
assert(terminal.state().last_find_found == nil, "stale find responses should not update footer find state")
assert(terminal.state().last_find_match_count == nil, "stale find responses should not update footer match count")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_find_navigation_id,
  status = "ok",
  payload = "admitted find navigation frame",
  url = "https://example.com/admitted-find",
  title = "Admitted Find Navigation",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().pending_operation == nil and terminal.state().current_title == "Admitted Find Navigation"
end), "admitted navigation after stale find should still apply")
terminal._test.set_last_find_query(nil)

terminal._test.clear_pending_operation()
_G.nvim_browser_nav_class_commands = {
  {
    label = "reload",
    send = function()
      return terminal.reload()
    end,
  },
  {
    label = "back",
    send = function()
      return terminal.back()
    end,
  },
  {
    label = "forward",
    send = function()
      return terminal.forward()
    end,
  },
}
for _, scenario in ipairs(_G.nvim_browser_nav_class_commands) do
  sent_requests = {}
  assert(scenario.send() == true, "test setup should send " .. scenario.label)
  _G.nvim_browser_admitted_nav_class_id = terminal.state().pending_operation and terminal.state().pending_operation.id
  assert(_G.nvim_browser_admitted_nav_class_id ~= nil, scenario.label .. " should be tracked as pending")
  sent_requests = {}
  assert(terminal.scroll(123) == true, "non-navigation request should still send while " .. scenario.label .. " is pending")
  flush_latest_timer()
  _G.nvim_browser_nav_class_scroll_id = last_request_of_type("scroll").id
  serve_stdout(nil, { vim.json.encode({
    id = _G.nvim_browser_nav_class_scroll_id,
    status = "ok",
    payload = scenario.label .. " stale scroll frame",
    url = "https://example.com/" .. scenario.label .. "-scroll",
    title = scenario.label .. " Scroll",
  }), "" })
  assert(not vim.wait(200, function()
    return terminal.state().current_title == scenario.label .. " Scroll"
  end), "newer non-navigation response should not overwrite pending " .. scenario.label)
  assert(
    terminal.state().pending_operation ~= nil
      and terminal.state().pending_operation.id == _G.nvim_browser_admitted_nav_class_id,
    "newer non-navigation response should not clear pending " .. scenario.label
  )
  serve_stdout(nil, { vim.json.encode({
    id = _G.nvim_browser_admitted_nav_class_id,
    status = "ok",
    payload = scenario.label .. " admitted frame",
    url = "https://example.com/" .. scenario.label,
    title = scenario.label .. " Admitted",
  }), "" })
  assert(vim.wait(1000, function()
    return terminal.state().pending_operation == nil and terminal.state().current_title == scenario.label .. " Admitted"
  end), "admitted " .. scenario.label .. " response should update state")
end

terminal._test.clear_pending_operation()
_G.nvim_browser_last_good_title = terminal.state().current_title
sent_requests = {}
assert(terminal.navigate("https://example.com/failing-navigation") == true, "test setup should send a failing navigation")
_G.nvim_browser_failing_navigation_id = terminal.state().pending_operation and terminal.state().pending_operation.id
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_failing_navigation_id,
  status = "error",
  error = "navigation failed",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().pending_operation == nil and terminal.state().status_error == "navigation failed"
end), "admitted navigation errors should clear pending state and surface the error")
assert(
  terminal.state().current_title == _G.nvim_browser_last_good_title,
  "admitted navigation errors should preserve the last good frame metadata"
)

sent_requests = {}
assert(terminal.hover_point(10, 20) == true, "test setup should send an older hover operation")
local older_hover_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(older_hover_id ~= nil, "older hover should be tracked as pending")
sent_requests = {}
assert(terminal.navigate("https://example.com/after-hover") == true, "test setup should send a newer navigation after hover")
local after_hover_navigation_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(after_hover_navigation_id ~= nil and after_hover_navigation_id ~= older_hover_id, "newer navigation should replace hover as pending")
serve_stdout(nil, { vim.json.encode({
  id = older_hover_id,
  status = "ok",
  payload = "older hover frame",
  url = "https://example.com/hover",
  title = "Older Hover",
}), "" })
local older_hover_applied = vim.wait(200, function()
  return terminal.state().current_title == "Older Hover"
end)
assert(not older_hover_applied, "late older hover response should not overwrite newer pending navigation state")
assert(
  terminal.state().pending_operation ~= nil and terminal.state().pending_operation.id == after_hover_navigation_id,
  "late older hover response should not clear the newer pending operation"
)
serve_stdout(nil, { vim.json.encode({
  id = after_hover_navigation_id,
  status = "ok",
  payload = "after hover navigation frame",
  url = "https://example.com/after-hover",
  title = "After Hover Navigation",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title == "After Hover Navigation"
end), "latest navigation after hover should still apply")

sent_requests = {}
assert(terminal.refresh() == true, "test setup should send an older live capture")
local older_capture_before_reader_id = terminal.state().live_refresh_request_id
assert(older_capture_before_reader_id ~= nil, "older live capture should be tracked")
sent_requests = {}
assert(terminal.reader() == true, "test setup should send a newer reader request")
local reader_request_id = nil
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "page_text" then
    reader_request_id = decoded.id
  end
end
assert(reader_request_id ~= nil and reader_request_id > older_capture_before_reader_id, "reader request should be newer than the live capture")
serve_stdout(nil, { vim.json.encode({
  id = reader_request_id,
  status = "ok",
  text = {
    title = "Reader After Capture",
    url = "https://example.com/reader-after-capture",
    text = "# Reader After Capture\n\nreader body",
    truncated = false,
  },
}), "" })
assert(vim.wait(1000, function()
  local reader_bufnr = terminal.state().reader_bufnr
  if reader_bufnr == nil or not vim.api.nvim_buf_is_valid(reader_bufnr) then
    return false
  end
  local reader_lines = table.concat(vim.api.nvim_buf_get_lines(reader_bufnr, 0, -1, false), "\n")
  return reader_lines:match("Reader After Capture") ~= nil
end), "newer reader response should still run its handler")
serve_stdout(nil, { vim.json.encode({
  id = older_capture_before_reader_id,
  status = "ok",
  payload = "stale capture after reader frame",
  url = "https://example.com/stale-capture-after-reader",
  title = "Stale Capture After Reader",
}), "" })
local stale_capture_after_reader_applied = vim.wait(200, function()
  return terminal.state().current_title == "Stale Capture After Reader"
end)
assert(not stale_capture_after_reader_applied, "older live capture should not overwrite state after a newer response has applied")
assert(terminal.state().live_refresh_request_id == nil, "older live capture handler should still clear in-flight tracking")

sent_requests = {}
assert(terminal.find_next() == false, "find_next should fail before any find query is stored")
assert(terminal.find_previous() == false, "find_previous should fail before any find query is stored")
assert(#sent_requests == 0, "find repeat without a stored query should not send serve requests")

assert(terminal.find_text("needle") == true, "test setup should send an older find request")
local older_find_id = nil
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "find_text" then
    assert(decoded.query == "needle", "find request should include the query")
    assert(decoded.backwards == false, "find request should default to forward search")
    older_find_id = decoded.id
  end
end
assert(older_find_id ~= nil, "find request should be sent")
assert(terminal.state().pending_operation ~= nil, "find_text should mark the find request as pending")
assert(
  terminal.state().pending_operation.id == older_find_id,
  "find_text pending operation should track the find request"
)
assert(terminal.state().pending_operation.label == "find", "find_text pending footer should use a find label")
assert(
  terminal._test.preview_footer_line(120):match("^find | needle | Esc stop"),
  "find_text should refresh the footer with immediate pending feedback"
)

sent_requests = {}
assert(terminal.find_next() == true, "find_next should repeat the stored query forward")
local repeat_forward_seen = false
_G.nvim_browser_repeat_forward_find_id = nil
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "find_text" then
    repeat_forward_seen = decoded.query == "needle" and decoded.backwards == false
    _G.nvim_browser_repeat_forward_find_id = decoded.id
  end
end
assert(repeat_forward_seen, "find_next should send the stored query with forward direction")
assert(
  _G.nvim_browser_repeat_forward_find_id ~= nil and _G.nvim_browser_repeat_forward_find_id > older_find_id,
  "find_next should send a newer find request"
)

sent_requests = {}
assert(terminal.find_previous() == true, "find_previous should repeat the stored query backward")
local repeat_backward_seen = false
_G.nvim_browser_repeat_backward_find_id = nil
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "find_text" then
    repeat_backward_seen = decoded.query == "needle" and decoded.backwards == true
    _G.nvim_browser_repeat_backward_find_id = decoded.id
  end
end
assert(repeat_backward_seen, "find_previous should send the stored query with backward direction")
assert(
  _G.nvim_browser_repeat_backward_find_id ~= nil
    and _G.nvim_browser_repeat_backward_find_id > _G.nvim_browser_repeat_forward_find_id,
  "find_previous should send a newer find request"
)

serve_stdout(nil, { vim.json.encode({
  id = older_find_id,
  status = "ok",
  found = true,
  match_count = 7,
}), "" })
vim.wait(50)
assert(terminal.state().last_find_found == nil, "older find responses should not update find status after a newer find")
assert(terminal.state().last_find_match_count == nil, "older find responses should not update find match counts")

sent_requests = {}
assert(terminal.navigate("https://example.com/after-find") == true, "test setup should send a newer navigation after find")
local after_find_navigation_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(after_find_navigation_id ~= nil and after_find_navigation_id > older_find_id, "navigation after find should be newer")
serve_stdout(nil, { vim.json.encode({
  id = after_find_navigation_id,
  status = "ok",
  payload = "after find navigation frame",
  url = "https://example.com/after-find",
  title = "After Find Navigation",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title == "After Find Navigation"
end), "newer navigation after find should apply")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_repeat_backward_find_id,
  status = "ok",
  found = true,
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().last_find_found == true
end), "latest handler-only find response should still update find status after newer render response")
assert(terminal.state().current_title == "After Find Navigation", "older find response should not overwrite current browser metadata")

terminal.configure({ live_refresh = { enabled = false } })
assert(fake_timers[1].stopped == true and fake_timers[1].closed == true, "disabling live refresh should stop the active timer")
sent_requests = {}
fake_timers[1].callback()
vim.wait(50)
assert(#sent_requests == 0, "stopped live refresh timer callbacks should not send requests after disabling")
_G.nvim_browser_timer_count_before_reenable = #fake_timers
terminal.configure({ live_refresh = { enabled = true, interval_ms = 25 } })
assert(
  #fake_timers == _G.nvim_browser_timer_count_before_reenable + 1,
  "re-enabling live refresh should start a replacement timer for the active serve session"
)
_G.nvim_browser_reenabled_live_timer = fake_timers[#fake_timers]
assert(_G.nvim_browser_reenabled_live_timer.starts[1].timeout == 25, "live refresh reconfiguration should apply the new interval")
sent_requests = {}
fake_timers[1].callback()
vim.wait(50)
assert(#sent_requests == 0, "old live refresh timer callbacks should not send requests after reconfiguration")

sent_requests = {}
_G.nvim_browser_reenabled_live_timer.callback()
local reconfigured_page_state_id = nil
assert(vim.wait(1000, function()
  reconfigured_page_state_id = terminal.state().live_refresh_request_id
  return reconfigured_page_state_id ~= nil
end), "reconfigured live refresh should still track page-state requests")
assert(last_request_of_type("page_state") ~= nil, "timer-driven live refresh should request page_state metadata")
assert(last_request_of_type("capture") == nil, "timer-driven live refresh should avoid full frame capture")
terminal.configure({ live_refresh = { enabled = false } })
assert(
  terminal.state().live_refresh_request_id == reconfigured_page_state_id,
  "disabling live refresh should not forget an already in-flight page-state request"
)
assert(terminal.navigate("https://example.com/after-reconfigure") == true, "navigation should still work after live refresh reconfiguration")
serve_stdout(nil, { vim.json.encode({
  id = reconfigured_page_state_id,
  status = "ok",
  url = "https://example.com/stale-after-reconfigure",
  title = "Stale After Reconfigure",
  page = { scroll_y = 12, viewport_height = 480, document_height = 960 },
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().live_refresh_request_id == nil
end), "stale page-state after reconfigure should clear in-flight request state")
assert(
  terminal.state().current_title ~= "Stale After Reconfigure",
  "stale page-state after reconfigure should not overwrite pending navigation metadata"
)
terminal._test.clear_pending_operation(terminal.state().pending_operation.id)
terminal.configure({ live_refresh = { enabled = true, interval_ms = 25 } })

jobstart_calls = {}
sent_requests = {}
local served_bufnr = second_state.bufnr
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--markdown", "/tmp/README.md" })
local markdown_state = terminal.state()
_G.nvim_browser_markdown_navigate_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "navigate_markdown" and decoded.path == "/tmp/README.md" then
    _G.nvim_browser_markdown_navigate_seen = true
  end
end
assert(#jobstart_calls == 0, "opening Markdown in an active serve session should reuse the existing job")
assert(markdown_state.bufnr == served_bufnr, "serve Markdown reuse should keep the same preview buffer")
assert(markdown_state.job_id == first_state.job_id, "serve Markdown reuse should keep the same backend job")
assert(markdown_state.last_target == "/tmp/README.md", "serve Markdown reuse should update the remembered target")
assert(_G.nvim_browser_markdown_navigate_seen, "serve Markdown reuse should send a navigate_markdown request for the Markdown preview target")
terminal._test.clear_pending_operation(terminal.state().pending_operation.id)

terminal._test.apply_serve_response({
  id = 30002,
  status = "ok",
  payload = "markdown wrapper frame",
  url = "file:///tmp/nvbrowser-README-wrapper.html",
  display_url = "file:///tmp/README.md",
  title = "README",
})
sent_requests = {}
assert(terminal.refresh() == true, "Markdown preview refresh should regenerate the wrapper source")
_G.nvim_browser_markdown_refresh_request = last_request_of_type("navigate_markdown")
assert(
  _G.nvim_browser_markdown_refresh_request ~= nil and _G.nvim_browser_markdown_refresh_request.path == "/tmp/README.md",
  "Markdown preview refresh should send navigate_markdown with the original path"
)
assert(last_request_of_type("capture") == nil, "Markdown preview refresh should not recapture the stale wrapper")
terminal._test.clear_pending_operation(terminal.state().pending_operation.id)

sent_requests = {}
assert(terminal.navigate("file:///tmp/README.md#intro") == true, "active Markdown file fragments should navigate")
_G.nvim_browser_markdown_fragment_request = last_request_of_type("navigate_markdown")
assert(
  _G.nvim_browser_markdown_fragment_request ~= nil
    and _G.nvim_browser_markdown_fragment_request.path == "/tmp/README.md"
    and _G.nvim_browser_markdown_fragment_request.display_url == "file:///tmp/README.md#intro",
  "active Markdown file fragments should send navigate_markdown with path and display URL"
)
terminal._test.apply_serve_response({
  id = terminal.state().pending_operation.id,
  status = "ok",
  payload = "markdown fragment wrapper frame",
  url = "file:///tmp/nvbrowser-README-fragment-wrapper.html",
  display_url = "file:///tmp/README.md#intro",
  title = "README",
})
sent_requests = {}
assert(terminal.refresh() == true, "Markdown fragment preview refresh should regenerate the wrapper source")
_G.nvim_browser_markdown_fragment_refresh_request = last_request_of_type("navigate_markdown")
assert(
  _G.nvim_browser_markdown_fragment_refresh_request ~= nil
    and _G.nvim_browser_markdown_fragment_refresh_request.path == "/tmp/README.md"
    and _G.nvim_browser_markdown_fragment_refresh_request.display_url == "file:///tmp/README.md#intro",
  "Markdown fragment refresh should preserve the display URL when regenerating the wrapper"
)
assert(last_request_of_type("capture") == nil, "Markdown fragment refresh should not recapture the stale wrapper")
terminal._test.clear_pending_operation(terminal.state().pending_operation.id)

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
  dom_epoch = 77,
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

local saved_register_b = vim.fn.getreg("b")
vim.fn.setreg("b", "before-url-yank")
sent_requests = {}
assert(terminal.yank_current_url("b") == true, "current URL yank should write the active browser URL")
assert(vim.fn.getreg("b") == "https://example.com", "current URL yank should write the current URL to the requested register")
assert(#sent_requests == 0, "current URL yank should not send backend requests")
assert(terminal.yank_current_url("bb") == false, "current URL yank should reject invalid register names")

_G.nvim_browser_observed_wrapper_metadata = nil
terminal.set_metadata_observer(function(metadata)
  _G.nvim_browser_observed_wrapper_metadata = metadata
end)
terminal._test.apply_serve_response({
  id = 30,
  status = "ok",
  payload = "markdown wrapper frame",
  url = "file:///tmp/nvbrowser-README-wrapper.html",
  display_url = "file:///tmp/README.md",
  title = "README",
  runtime = {
    protocol_version = 27,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "ansi",
    cells = { columns = 80, rows = 24 },
    viewport = { width = 800, height = 480, device_scale_factor = 1.0 },
  },
})
assert(terminal.state().current_url == "file:///tmp/README.md", "wrapper display URL should become the user-facing current URL")
assert(
  terminal.state().rendered_frame_url == "file:///tmp/nvbrowser-README-wrapper.html",
  "wrapper browser URL should remain available as the rendered frame URL"
)
assert(
  _G.nvim_browser_observed_wrapper_metadata ~= nil and _G.nvim_browser_observed_wrapper_metadata.url == "file:///tmp/README.md",
  "metadata observers should receive the wrapper display URL, not the temp wrapper URL"
)
vim.fn.setreg("b", "before-wrapper-yank")
assert(terminal.yank_current_url("b") == true, "wrapper current URL yank should succeed")
assert(vim.fn.getreg("b") == "file:///tmp/README.md", "wrapper current URL yank should write the display URL")
terminal.set_metadata_observer(nil)
terminal._test.apply_serve_response({
  id = 31,
  status = "ok",
  url = "https://example.com",
  title = vim.NIL,
})

vim.fn.setreg("b", "before-hint-yank")
sent_requests = {}
assert(terminal.yank_hint_url("a", "b") == true, "hint URL yank should match hint labels")
assert(vim.fn.getreg("b") == "https://example.com/docs", "hint URL yank should write the hinted href")
assert(#sent_requests == 0, "hint URL yank should not send backend requests")

vim.fn.setreg("b", "before-numeric-hint-yank")
assert(terminal.yank_hint_url(1, "b") == true, "hint URL yank should match numeric backend ids")
assert(vim.fn.getreg("b") == "https://example.com/docs", "numeric hint URL yank should write the hinted href")

_G.nvim_browser_point_info_winid = terminal.state().winid
assert(_G.nvim_browser_point_info_winid ~= nil and vim.api.nvim_win_is_valid(_G.nvim_browser_point_info_winid), "browser preview window should exist for point inspection")
_G.nvim_browser_point_info_geometry = terminal.state().current_preview_geometry
terminal._test.apply_serve_response({
  id = 32,
  status = "ok",
  payload = "point info frame",
  url = "https://example.com",
  runtime = {
    protocol_version = 27,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "ansi",
    cells = { columns = _G.nvim_browser_point_info_geometry.columns, rows = _G.nvim_browser_point_info_geometry.rows },
    viewport = { width = _G.nvim_browser_point_info_geometry.width, height = _G.nvim_browser_point_info_geometry.height, device_scale_factor = 1 },
  },
})
vim.api.nvim_win_set_cursor(_G.nvim_browser_point_info_winid, { 1, 0 })
sent_requests = {}
_G.nvim_browser_observed_point_response = nil
assert(terminal.point_info_here(function(response)
  _G.nvim_browser_observed_point_response = response
end) == true, "point info should send a cursor-position inspection request")
_G.nvim_browser_point_info_request = last_request_of_type("point_info")
assert(_G.nvim_browser_point_info_request ~= nil, "point info should use the point_info serve request")
_G.nvim_browser_expected_point = terminal.viewport_point_for_cell(1, 1, terminal.state().rendered_frame_geometry)
assert(_G.nvim_browser_point_info_request.x == _G.nvim_browser_expected_point.x, "point info should send the cursor cell viewport x")
assert(_G.nvim_browser_point_info_request.y == _G.nvim_browser_expected_point.y, "point info should send the cursor cell viewport y")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_point_info_request.id,
  status = "ok",
  point = {
    tag = "a",
    label = "Docs",
    href = "https://example.com/docs",
    target = "_blank",
  },
}), "" })
assert(vim.wait(1000, function()
  return _G.nvim_browser_observed_point_response ~= nil
end), "point info responses should reach the caller callback")
assert(_G.nvim_browser_observed_point_response.point.href == "https://example.com/docs", "point info callback should receive href metadata")

vim.fn.setreg("b", "before-point-url-yank")
sent_requests = {}
assert(terminal.yank_point_url_here("b") == true, "cursor URL yank should send a point_info request")
_G.nvim_browser_point_yank_request = last_request_of_type("point_info")
assert(_G.nvim_browser_point_yank_request ~= nil, "cursor URL yank should use point_info")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_point_yank_request.id,
  status = "ok",
  point = {
    tag = "span",
    label = "Docs",
    href = "https://example.com/docs",
  },
}), "" })
assert(vim.wait(1000, function()
  return vim.fn.getreg("b") == "https://example.com/docs"
end), "cursor URL yank should write the inspected href")

vim.fn.setreg("b", "preserve-empty-point-url")
sent_requests = {}
assert(terminal.yank_point_url_here("b") == true, "cursor URL yank should still request point info before detecting missing href")
_G.nvim_browser_empty_point_yank_request = last_request_of_type("point_info")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_empty_point_yank_request.id,
  status = "ok",
  point = {
    tag = "button",
    label = "Search",
  },
}), "" })
assert(vim.wait(1000, function()
  return #warnings > 0
end), "cursor URL yank should warn when no href is under the cursor")
assert(vim.fn.getreg("b") == "preserve-empty-point-url", "cursor URL yank should not overwrite registers without href")
assert(terminal.yank_point_url_here("bb") == false, "cursor URL yank should reject invalid register names")

sent_requests = {}
assert(terminal.follow_point_url_here() == true, "cursor link follow should inspect the browser point first")
_G.nvim_browser_point_follow_request = last_request_of_type("point_info")
assert(_G.nvim_browser_point_follow_request ~= nil, "cursor link follow should use point_info before navigation")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_point_follow_request.id,
  status = "ok",
  point = {
    tag = "a",
    label = "Docs",
    href = "https://example.com/docs",
    target = "_blank",
  },
}), "" })
assert(vim.wait(1000, function()
  return last_request_of_type("navigate") ~= nil
end), "cursor link follow should navigate to the inspected href")
_G.nvim_browser_point_follow_navigate = last_request_of_type("navigate")
assert(_G.nvim_browser_point_follow_navigate.url == "https://example.com/docs", "cursor link follow should navigate to the href")
assert(last_request_of_type("click_point") == nil, "cursor link follow should not click the inspected point")
assert(terminal.state().last_target == "https://example.com/docs", "cursor link follow should update the terminal target")
terminal._test.apply_serve_response({
  id = _G.nvim_browser_point_follow_navigate.id,
  status = "ok",
  url = "https://example.com/docs",
})
assert(terminal.state().pending_operation == nil, "cursor link follow navigation response should clear the pending operation before the next inspection")

sent_requests = {}
_G.nvim_browser_warning_count_before_empty_point_follow = #warnings
assert(terminal.follow_point_url_here() == true, "cursor link follow should inspect before detecting missing href")
_G.nvim_browser_empty_point_follow_request = last_request_of_type("point_info")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_empty_point_follow_request.id,
  status = "ok",
  point = {
    tag = "button",
    label = "Search",
  },
}), "" })
assert(vim.wait(1000, function()
  return #warnings > _G.nvim_browser_warning_count_before_empty_point_follow
end), "cursor link follow should warn when no href is under the cursor")
assert(last_request_of_type("navigate") == nil, "cursor link follow should not navigate without href")
terminal._test.clear_frame_refresh()
terminal._test.set_latest_applied_response_id(2)

vim.fn.setreg("b", "preserve-missing-hint")
assert(terminal.yank_hint_url("missing", "b") == false, "hint URL yank should reject missing hints")
assert(vim.fn.getreg("b") == "preserve-missing-hint", "missing hints should not mutate registers")

vim.fn.setreg("b", "preserve-non-link-hint")
assert(terminal.yank_hint_url("s", "b") == false, "hint URL yank should reject hints without href")
assert(vim.fn.getreg("b") == "preserve-non-link-hint", "non-link hints should not mutate registers")

assert(terminal.yank_hint_url("a", "bb") == false, "hint URL yank should reject invalid register names")
assert(terminal._test.hint_href_for_identifier("a") == "https://example.com/docs", "test helper should expose hint href lookup")
assert(terminal._test.hint_href_for_identifier("s") == nil, "test helper should reject hints without href")
terminal._test.apply_serve_response({ id = 2, status = "ok", url = vim.NIL })
vim.fn.setreg("b", "preserve-missing-current-url")
assert(terminal.yank_current_url("b") == false, "current URL yank should reject missing URLs")
assert(vim.fn.getreg("b") == "preserve-missing-current-url", "missing current URLs should not mutate registers")
local restored_hints_response = vim.json.decode(hints_response)
restored_hints_response.id = 3
serve_stdout(nil, { vim.json.encode(restored_hints_response), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_url == "https://example.com"
end), "serve hint response should restore current URL after missing URL checks")
vim.fn.setreg("b", saved_register_b)

_G.nvim_browser_target_blank_hints_response = vim.json.decode(hints_response)
_G.nvim_browser_target_blank_hints_response.id = 9000
_G.nvim_browser_target_blank_hints_response.hints[1].target = "_blank"
terminal._test.set_latest_applied_response_id(_G.nvim_browser_target_blank_hints_response.id - 1)
serve_stdout(nil, { vim.json.encode(_G.nvim_browser_target_blank_hints_response), "" })
assert(vim.wait(1000, function()
  local state = terminal.state()
  return #state.element_hints == 2
    and state.current_url == "https://example.com"
    and state.element_hints[1].target == "_blank"
end), "serve hint response should repopulate target blank link hints")
assert(
  terminal.state().element_hints[1].target == "_blank",
  "target blank hint metadata should be preserved in Neovim state"
)
sent_requests = {}
assert(terminal.click_hint("a") == true, "target blank link hint clicks should navigate by href")
_G.nvim_browser_target_blank_navigate = last_request_of_type("navigate")
assert(
  _G.nvim_browser_target_blank_navigate ~= nil
    and _G.nvim_browser_target_blank_navigate.url == "https://example.com/docs",
  "target blank link hint clicks should send direct href navigation"
)
assert(last_request_of_type("click_hint") == nil, "target blank link hint clicks should not send backend hint ids")
terminal._test.set_pending_operation(nil)

terminal._test.set_element_hints({
  vim.tbl_extend("force", {}, terminal.state().element_hints[1], { target = "_self" }),
  terminal.state().element_hints[2],
}, terminal.state().current_preview_geometry)
sent_requests = {}
assert(terminal.click_hint("a") == true, "non-blank link hint clicks should use backend hint clicks")
assert(last_request_of_type("click_hint") ~= nil, "non-blank link hint clicks should send backend hint ids")
assert(last_request_of_type("navigate") == nil, "non-blank link hint clicks should not directly navigate")
terminal._test.set_pending_operation(nil)

_G.nvim_browser_no_target_hint = vim.tbl_extend("force", {}, terminal.state().element_hints[1])
_G.nvim_browser_no_target_hint.target = nil
terminal._test.set_element_hints({
  _G.nvim_browser_no_target_hint,
  terminal.state().element_hints[2],
}, terminal.state().current_preview_geometry)
sent_requests = {}
assert(terminal.click_hint("a") == true, "link hint clicks without target should use backend hint clicks")
assert(last_request_of_type("click_hint") ~= nil, "link hint clicks without target should send backend hint ids")
assert(last_request_of_type("navigate") == nil, "link hint clicks without target should not directly navigate")
terminal._test.set_pending_operation(nil)

terminal._test.set_element_hints({
  vim.tbl_extend("force", {}, terminal.state().element_hints[1], { target = "_blank" }),
  terminal.state().element_hints[2],
}, terminal.state().current_preview_geometry)
sent_requests = {}
assert(terminal.right_click_hint("a") == true, "target blank right-click hints should still use backend right clicks")
assert(last_request_of_type("right_click_hint") ~= nil, "target blank right-click hints should send backend hint ids")
assert(last_request_of_type("navigate") == nil, "target blank right-click hints should not directly navigate")
terminal._test.set_pending_operation(nil)

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
assert(#terminal.state().element_hints > 0, "link follow should preserve active hints until the next frame")
assert(terminal.state().pending_operation ~= nil, "link follow should mark the navigation as pending")
assert(terminal._test.preview_footer_line(120):match("^loading | https://example%.com/docs | Esc stop"), "link follow should refresh the footer with loading feedback")

sent_requests = {}
_G.nvim_browser_stop_pending_request_id = terminal.state().pending_operation.id
assert(terminal.stop() == true, "stop should cancel a pending browser operation")
_G.nvim_browser_stop_loading_request = last_request_of_type("stop_loading")
assert(_G.nvim_browser_stop_loading_request ~= nil, "stop should ask the backend to stop loading before killing the serve job")
assert(_G.nvim_browser_stop_loading_request.id ~= _G.nvim_browser_stop_pending_request_id, "stop loading should use its own protocol request id")
assert(#jobstop_calls == 0, "graceful stop should keep the serve job alive while waiting for the backend")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_stop_pending_request_id,
  status = "ok",
  payload = "early late frame",
  url = "https://example.com/docs",
  title = "Early Late Page",
  downloads = {
    { path = "/tmp/early-late.txt", status = "completed" },
  },
  dialogs = {
    { kind = "alert", message = "early late", action = "dismissed" },
  },
}), "" })
assert(not vim.wait(200, function()
  return terminal.state().current_title == "Early Late Page"
end), "stopped operation responses should be ignored even before stop_loading ack")
assert(#terminal.downloads() == 0, "stopped operation responses before stop_loading ack should not record downloads")
terminal._test.set_latest_applied_response_id(_G.nvim_browser_stop_loading_request.id - 1)
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_stop_loading_request.id,
  status = "ok",
  url = "https://example.com/docs",
  title = "Stopped Page",
  runtime = {
    protocol_version = 27,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "ansi",
    cells = { columns = 80, rows = 24 },
    viewport = { width = 800, height = 480, device_scale_factor = 1 },
  },
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().pending_operation == nil
end), "graceful stop ack should clear the pending browser operation")
assert(#jobstop_calls == 0, "successful stop_loading should not terminate the serve job")
assert(terminal.state().mode == "serve", "successful stop_loading should keep the serve session active")
assert(terminal.state().serve_output == "ansi", "successful stop_loading should keep serve output metadata")
_G.nvim_browser_stop_footer_after_ack = terminal._test.preview_footer_line(120)
assert(
  _G.nvim_browser_stop_footer_after_ack:match("^stopped |")
    and _G.nvim_browser_stop_footer_after_ack:find("https://example.com/docs", 1, true),
  "stop should leave a stopped footer message"
)
assert(terminal.state().stopped_operation ~= nil, "stop should keep stopped operation metadata for the footer")
_G.nvim_browser_cancelled_response = vim.json.encode({
  id = _G.nvim_browser_stop_pending_request_id,
  status = "ok",
  payload = "late frame",
  url = "https://example.com/docs",
  title = "Late Page",
  downloads = {
    { path = "/tmp/late.txt", status = "completed" },
  },
  dialogs = {
    { kind = "alert", message = "late", action = "dismissed" },
  },
})
serve_stdout(nil, { _G.nvim_browser_cancelled_response, "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title ~= "Late Page"
end), "cancelled operation responses should be ignored")
assert(#terminal.downloads() == 0, "cancelled operation responses should not record downloads")

terminal._test.clear_in_flight_capture()
assert(terminal.navigate("https://example.com/hard-stop") == true, "test setup should create a pending navigation for stop fallback")
sent_requests = {}
jobstop_calls = {}
_G.nvim_browser_hard_stop_pending_id = terminal.state().pending_operation.id
assert(terminal.stop() == true, "stop should send a stoppable backend request")
_G.nvim_browser_failed_stop_loading_request = last_request_of_type("stop_loading")
assert(_G.nvim_browser_failed_stop_loading_request ~= nil, "stop fallback setup should send stop_loading")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_failed_stop_loading_request.id,
  status = "error",
  error = "stop loading failed",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().mode == nil
end), "stop_loading errors should fall back to hard stopping the serve job")
assert(#jobstop_calls >= 1, "stop_loading errors should terminate the serve job")
assert(terminal.state().pending_operation == nil, "stop fallback should clear pending operation")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_hard_stop_pending_id,
  status = "ok",
  payload = "late hard stop frame",
  url = "https://example.com/hard-stop",
  title = "Late Hard Stop",
}), "" })
assert(not vim.wait(200, function()
  return terminal.state().current_title == "Late Hard Stop"
end), "hard-stopped operation responses should still be ignored")

jobstart_calls = {}
sent_requests = {}
assert(terminal.refresh() == true, "refresh after hard stop should restart the serve session")
assert(#jobstart_calls == 1, "refresh after hard stop should start one replacement serve job")
assert(jobstart_calls[1][2] == "serve", "refresh restart should use the serve backend")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--url") == "https://example.com/hard-stop", "refresh restart should target the stopped navigation URL")
assert(terminal.state().mode == "serve", "refresh restart should reactivate serve mode")
assert(terminal.state().pending_operation == nil, "refresh restart should start without stale pending operations")
assert(terminal._test.response_handler_count() == 0, "refresh restart should start without stale response handlers")
assert(#terminal.downloads() == 0, "refresh restart should clear stale download history")
assert(terminal.state().zoom_scale == 1.0, "refresh restart should reset stale zoom state")
assert(#terminal.state().element_hints == 0, "refresh restart should start without stale hints")

terminal._test.clear_in_flight_capture()
assert(terminal.navigate("https://example.com/reload-stopped") == true, "test setup should create another stoppable navigation")
_G.nvim_browser_reload_stopped_target = terminal.state().pending_operation.target
_G.nvim_browser_stop_with_backend_error()
jobstart_calls = {}
sent_requests = {}
assert(terminal.reload() == true, "reload after hard stop should restart the serve session")
assert(#jobstart_calls == 1, "reload after hard stop should start one replacement serve job")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--url") == _G.nvim_browser_reload_stopped_target, "reload restart should target the stopped operation")

terminal._test.clear_in_flight_capture()
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--image-fit", "contain", "--image", "/tmp/restart-image.png" })
assert(terminal.state().pending_operation ~= nil, "test setup should create a pending image navigation")
_G.nvim_browser_stop_with_backend_error()
jobstart_calls = {}
sent_requests = {}
assert(terminal.refresh() == true, "refresh after stopped image navigation should restart the serve session")
assert(#jobstart_calls == 1, "stopped image refresh should start one replacement serve job")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--url") == nil, "stopped image refresh should not restart as a raw URL")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--image") == "/tmp/restart-image.png", "stopped image refresh should preserve the image wrapper target")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--image-fit") == "contain", "stopped image refresh should preserve the image fit")

terminal._test.clear_in_flight_capture()
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--markdown", "/tmp/restart.md" })
assert(terminal.state().pending_operation ~= nil, "test setup should create a pending Markdown navigation")
_G.nvim_browser_stop_with_backend_error()
jobstart_calls = {}
sent_requests = {}
assert(terminal.refresh() == true, "refresh after stopped Markdown navigation should restart the serve session")
assert(#jobstart_calls == 1, "stopped Markdown refresh should start one replacement serve job")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--url") == nil, "stopped Markdown refresh should not restart as a raw URL")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--markdown") == "/tmp/restart.md", "stopped Markdown refresh should preserve the Markdown wrapper target")

terminal._test.clear_in_flight_capture()
assert(terminal.navigate("https://example.com/address-stopped") == true, "test setup should create a pending address navigation")
_G.nvim_browser_stop_with_backend_error()
jobstart_calls = {}
sent_requests = {}
assert(terminal.navigate("https://example.com/address-restart") == true, "address navigation after hard stop should restart serve")
assert(#jobstart_calls == 1, "address navigation after hard stop should start one replacement serve job")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--url") == "https://example.com/address-restart", "address restart should use the requested URL")

sent_requests = {}
terminal.close()
jobstart_calls = {}
assert(terminal.refresh() == false, "refresh after close should not restart the closed serve session")
assert(#jobstart_calls == 0, "refresh after close should not start a replacement serve job")
jobstart_calls = {}
assert(terminal.reload() == false, "reload after close should not restart the closed serve session")
assert(#jobstart_calls == 0, "reload after close should not start a replacement serve job")
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--markdown", "/tmp/docs/README.md" })
assert(terminal.navigate("https://example.com/from-markdown") == true, "test setup should create a pending navigation from markdown")
_G.nvim_browser_stop_with_backend_error()
jobstart_calls = {}
assert(terminal.navigate("https://example.com/markdown-address-restart") == true, "address navigation after markdown hard stop should restart serve")
assert(#jobstart_calls == 1, "markdown-origin address restart should start one replacement serve job")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--url") == "https://example.com/markdown-address-restart", "markdown-origin address restart should use the requested URL")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--markdown") == nil, "markdown-origin address restart should drop the old markdown target")
terminal.close()
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com" })
assert(terminal.find_text("cancel me") == true, "test setup should send a cancellable find request")
_G.nvim_browser_cancellable_find_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(_G.nvim_browser_cancellable_find_id ~= nil, "find_text should be pending before stop")
assert(terminal.state().pending_operation.label == "find", "cancellable find should use a find pending label")
assert(terminal.stop() == true, "stop should cancel a pending find request")
assert(terminal.state().pending_operation == nil, "stop should clear pending find state")
terminal._test.dispatch_serve_response_handler({
  id = _G.nvim_browser_cancellable_find_id,
  status = "ok",
  found = true,
  match_count = 9,
})
assert(terminal.state().last_find_found ~= true, "stopped find handlers should not update find status")
assert(terminal.state().last_find_match_count ~= 9, "stopped find handlers should not update find match count")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_cancellable_find_id,
  status = "ok",
  found = true,
  match_count = 9,
}), "" })
vim.wait(50)
assert(terminal.state().last_find_found ~= true, "late cancelled find stdout should not update find status")
assert(terminal.state().last_find_match_count ~= 9, "late cancelled find stdout should not update find match count")

terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com/watchdog" })
terminal._test.clear_in_flight_capture()
jobstop_calls = {}
sent_requests = {}
assert(terminal.navigate("https://example.com/watchdog-next") == true, "test setup should create a watchdog-tracked navigation")
_G.nvim_browser_watchdog_pending_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(_G.nvim_browser_watchdog_pending_id ~= nil, "watchdog test should leave a pending navigation")
_G.nvim_browser_watchdog_timer = nvim_browser_latest_timer()
assert(_G.nvim_browser_watchdog_timer ~= nil, "pending browser operations should start a watchdog timer")
assert(_G.nvim_browser_watchdog_timer.starts[#_G.nvim_browser_watchdog_timer.starts].timeout == 20000, "operation watchdog should derive its default from the navigation timeout")
_G.nvim_browser_watchdog_timer.callback()
assert(vim.wait(1000, function()
  return terminal.state().pending_operation == nil
end), "operation watchdog should clear stuck pending operations")
assert(#jobstop_calls >= 1, "operation watchdog should hard-stop the stuck serve job")
assert(terminal.state().mode == nil, "operation watchdog should mark the serve session inactive")
assert(terminal.state().stopped_operation ~= nil, "operation watchdog should keep stopped operation metadata for restart")
assert(
  terminal._test.preview_footer_line(120):match("^timeout | https://example%.com/watchdog%-next"),
  "operation watchdog should leave a timeout footer message"
)
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_watchdog_pending_id,
  status = "ok",
  payload = "late watchdog frame",
  url = "https://example.com/watchdog-next",
  title = "Late Watchdog",
  hints = {
    { id = 44, x = 10, y = 10, label = "Late" },
  },
  downloads = {
    {
      path = "/tmp/nvbrowser-downloads/late-watchdog.txt",
      suggested_filename = "late-watchdog.txt",
      status = "completed",
    },
  },
}), "" })
vim.wait(50)
assert(terminal.state().current_title ~= "Late Watchdog", "watchdog late stdout should not mutate title")
assert(#terminal.state().element_hints == 0, "watchdog late stdout should not mutate hints")
assert(#terminal.downloads() == 0, "watchdog late stdout should not record downloads")
_G.nvim_browser_old_watchdog_stdout = serve_stdout
jobstart_calls = {}
sent_requests = {}
assert(terminal.refresh() == true, "refresh after watchdog timeout should restart the serve session")
assert(#jobstart_calls == 1, "refresh after watchdog timeout should start one replacement serve job")
assert(
  _G.nvim_browser_command_option(jobstart_calls[1], "--url") == "https://example.com/watchdog-next",
  "watchdog restart should target the stopped navigation URL"
)
assert(terminal._test.response_handler_count() == 0, "watchdog restart should not keep stale response handlers")
assert(#terminal.state().element_hints == 0, "watchdog restart should start without stale hints")
_G.nvim_browser_old_watchdog_stdout(nil, { '{"id":' .. tostring(_G.nvim_browser_watchdog_pending_id) .. ',"status":"ok","payload":"stale partial"' })
serve_stdout(nil, { vim.json.encode({
  id = 1,
  status = "ok",
  payload = "fresh frame after stale partial",
  url = "https://example.com/watchdog-next",
  title = "Fresh After Stale Partial",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title == "Fresh After Stale Partial"
end), "fresh restart stdout should not be poisoned by stale partial output from the old job")

terminal._test.clear_in_flight_capture()
jobstop_calls = {}
sent_requests = {}
assert(terminal.refresh() == true, "test setup should create a watchdog-tracked capture")
_G.nvim_browser_capture_watchdog_id = terminal.state().live_refresh_request_id
assert(_G.nvim_browser_capture_watchdog_id ~= nil, "watchdog test should leave an in-flight capture")
_G.nvim_browser_capture_watchdog_timer = nvim_browser_latest_timer()
assert(_G.nvim_browser_capture_watchdog_timer ~= nil, "capture requests should start a watchdog timer")
assert(_G.nvim_browser_capture_watchdog_timer.starts[#_G.nvim_browser_capture_watchdog_timer.starts].timeout == 20000, "capture watchdog should derive its default from the navigation timeout")
_G.nvim_browser_capture_watchdog_timer.callback()
assert(vim.wait(1000, function()
  return terminal.state().live_refresh_request_id == nil
end), "capture watchdog should clear stuck capture requests")
assert(#jobstop_calls >= 1, "capture watchdog should hard-stop the stuck serve job")
assert(terminal.state().mode == nil, "capture watchdog should mark the serve session inactive")
assert(
  terminal._test.preview_footer_line(120):match("^timeout")
    and terminal._test.preview_footer_line(120):find("https://example.com/watchdog-next", 1, true),
  "capture watchdog should leave a timeout footer message"
)
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_capture_watchdog_id,
  status = "ok",
  payload = "late capture watchdog frame",
  url = "https://example.com/late-capture-watchdog",
  title = "Late Capture Watchdog",
}), "" })
vim.wait(50)
assert(terminal.state().current_title ~= "Late Capture Watchdog", "capture watchdog late stdout should not mutate title")
assert(terminal.refresh() == true, "refresh after capture watchdog timeout should restart the serve session")
assert(_G.nvim_browser_command_option(jobstart_calls[#jobstart_calls], "--url") == "https://example.com/watchdog-next", "capture watchdog restart should use the stopped URL")

terminal._test.clear_in_flight_capture()
sent_requests = {}
_G.nvim_browser_timer_count_before_completed_watchdog_request = #fake_timers
assert(terminal.navigate("https://example.com/watchdog-complete") == true, "test setup should create a completing watchdog request")
_G.nvim_browser_completing_watchdog_id = terminal.state().pending_operation and terminal.state().pending_operation.id
_G.nvim_browser_completing_watchdog_timer = fake_timers[#fake_timers]
assert(#fake_timers == _G.nvim_browser_timer_count_before_completed_watchdog_request + 1, "pending request should create one watchdog timer")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_completing_watchdog_id,
  status = "ok",
  payload = "completed watchdog frame",
  url = "https://example.com/watchdog-complete",
  title = "Watchdog Complete",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().pending_operation == nil
end), "completed responses should clear pending operations")
assert(_G.nvim_browser_completing_watchdog_timer.stopped == true and _G.nvim_browser_completing_watchdog_timer.closed == true, "completed responses should stop the watchdog timer")
_G.nvim_browser_jobstop_count_after_completed_watchdog = #jobstop_calls
_G.nvim_browser_completing_watchdog_timer.callback()
assert(#jobstop_calls == _G.nvim_browser_jobstop_count_after_completed_watchdog, "completed watchdog callbacks should not stop the serve job")

terminal.close()
sent_requests = {}
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com" })
serve_stdout(nil, { hints_response, "" })
assert(vim.wait(1000, function()
  return #terminal.state().element_hints == 2
end), "serve hint response should repopulate element hints after navigation clears them")
sent_requests = {}
assert(terminal.follow_hint("s") == true, "follow_hint should fall back to click for non-link hints")
local fallback_click_hint_seen = false
local fallback_click_point_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "click_hint" and decoded.hint_id == 2 then
    assert(decoded.dom_epoch == 77, "follow fallback click_hint should send the rendered frame DOM epoch")
    fallback_click_hint_seen = true
  end
  if ok and decoded.type == "click_point" then
    fallback_click_point_seen = true
  end
end
assert(fallback_click_hint_seen, "non-link follow fallback should send a backend hint click")
assert(not fallback_click_point_seen, "non-link follow fallback should avoid coordinate click requests")
local fallback_click_pending_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(fallback_click_pending_id ~= nil, "non-link follow fallback should mark the hint click as pending")
serve_stdout(nil, { vim.json.encode({
  id = fallback_click_pending_id,
  status = "ok",
  payload = "clicked hint frame",
  url = "https://example.com",
  title = "Example",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().pending_operation == nil
end), "hint click response should clear pending state before later hint captures")

sent_requests = {}
local direct_click_hints_response = vim.json.decode(hints_response)
direct_click_hints_response.id = fallback_click_pending_id + 1
serve_stdout(nil, { vim.json.encode(direct_click_hints_response), "" })
assert(vim.wait(1000, function()
  return #terminal.state().element_hints == 2
end), "serve hint response should repopulate element hints before direct hint click")
assert(terminal.refresh() == true, "manual refresh should create an in-flight capture before hint click")
assert(vim.wait(1000, function()
  return terminal.state().live_refresh_request_id ~= nil
end), "refresh capture should be in flight before hint click")
local stale_live_before_click_hint_id = terminal.state().live_refresh_request_id
sent_requests = {}
assert(terminal.click_hint("s") == true, "click_hint should click the hinted element")
local direct_click_hint_seen = false
local direct_click_point_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "click_hint" and decoded.hint_id == 2 then
    assert(decoded.dom_epoch == 77, "click_hint should send the rendered frame DOM epoch")
    direct_click_hint_seen = true
  end
  if ok and decoded.type == "click_point" then
    direct_click_point_seen = true
  end
end
assert(direct_click_hint_seen, "click_hint should send the backend hint id")
assert(not direct_click_point_seen, "click_hint should avoid coordinate click requests")
assert(terminal.state().live_refresh_request_id == nil, "click_hint should cancel in-flight refresh before using backend hint ids")
serve_stdout(nil, { vim.json.encode({
  id = stale_live_before_click_hint_id,
  status = "ok",
  payload = "stale live frame",
  url = "https://example.com/stale-click",
  title = "Stale Click",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title ~= "Stale Click"
end), "canceled refresh responses should not update metadata after click_hint starts")
local direct_click_pending_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(direct_click_pending_id ~= nil, "click_hint should mark the hint click as pending")
serve_stdout(nil, { vim.json.encode({
  id = direct_click_pending_id,
  status = "ok",
  payload = "direct clicked hint frame",
  url = "https://example.com",
  title = "Example",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().pending_operation == nil
end), "direct hint click response should clear pending state")

sent_requests = {}
right_click_hints_response = vim.json.decode(hints_response)
right_click_hints_response.id = direct_click_pending_id + 2
serve_stdout(nil, { vim.json.encode(right_click_hints_response), "" })
assert(vim.wait(1000, function()
  return #terminal.state().element_hints == 2
end), "serve hint response should repopulate element hints before direct hint right click")
assert(terminal.refresh() == true, "manual refresh should create an in-flight capture before hint right click")
assert(vim.wait(1000, function()
  return terminal.state().live_refresh_request_id ~= nil
end), "refresh capture should be in flight before hint right click")
stale_live_before_right_click_hint_id = terminal.state().live_refresh_request_id
sent_requests = {}
assert(terminal.right_click_hint("s") == true, "right_click_hint should right click the hinted element")
direct_right_click_hint_seen = false
direct_right_click_point_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "right_click_hint" and decoded.hint_id == 2 then
    assert(decoded.dom_epoch == 77, "right_click_hint should send the rendered frame DOM epoch")
    direct_right_click_hint_seen = true
  end
  if ok and decoded.type == "right_click_point" then
    direct_right_click_point_seen = true
  end
end
assert(direct_right_click_hint_seen, "right_click_hint should send the backend hint id")
assert(not direct_right_click_point_seen, "right_click_hint should avoid coordinate click requests")
assert(terminal.state().live_refresh_request_id == nil, "right_click_hint should cancel in-flight refresh before using backend hint ids")
serve_stdout(nil, { vim.json.encode({
  id = stale_live_before_right_click_hint_id,
  status = "ok",
  payload = "stale live frame",
  url = "https://example.com/stale-right-click",
  title = "Stale Right Click",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title ~= "Stale Right Click"
end), "canceled refresh responses should not update metadata after right_click_hint starts")
direct_right_click_pending_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(direct_right_click_pending_id ~= nil, "right_click_hint should mark the hint right click as pending")
assert(terminal.state().pending_operation.label == "right-click", "right_click_hint pending footer should use a right-click label")
serve_stdout(nil, { vim.json.encode({
  id = direct_right_click_pending_id,
  status = "ok",
  payload = "direct right clicked hint frame",
  url = "https://example.com",
  title = "Example",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().pending_operation == nil
end), "direct hint right click response should clear pending state")

sent_requests = {}
local focus_hints_response = vim.json.decode(hints_response)
focus_hints_response.id = direct_right_click_pending_id + 1
serve_stdout(nil, { vim.json.encode(focus_hints_response), "" })
assert(vim.wait(1000, function()
  return #terminal.state().element_hints == 2
end), "serve hint response should repopulate element hints before hinted focus")
assert(terminal.focus_hint("s") == true, "focus_hint should focus the hinted element")
local focus_hint_seen = false
local focus_point_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "focus_hint" and decoded.hint_id == 2 then
    assert(decoded.dom_epoch == 77, "focus_hint should send the rendered frame DOM epoch")
    focus_hint_seen = true
  end
  if ok and decoded.type == "focus_point" then
    focus_point_seen = true
  end
end
assert(focus_hint_seen, "focus_hint should send the backend hint id")
assert(not focus_point_seen, "focus_hint should avoid coordinate-based focus requests")
local focus_hint_pending_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(focus_hint_pending_id ~= nil, "hinted focus should mark the operation as pending")
assert(#terminal.state().element_hints > 0, "focus_hint should preserve active hints while a capture is pending")
serve_stdout(nil, { vim.json.encode({
  id = focus_hint_pending_id,
  status = "ok",
  payload = "focused hint frame",
  url = "https://example.com",
  title = "Example",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().pending_operation == nil
end), "focus_hint response should clear pending state before later hint captures")

sent_requests = {}
local type_hints_response = vim.json.decode(hints_response)
type_hints_response.id = focus_hint_pending_id + 1
serve_stdout(nil, { vim.json.encode(type_hints_response), "" })
assert(vim.wait(1000, function()
  return #terminal.state().element_hints == 2
end), "serve hint response should repopulate element hints before typed input")
assert(terminal.type_hint("s", "hello", { submit = true }) == true, "type_hint should type into the hinted element")
local type_hint_seen = false
local type_point_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "type_hint" and decoded.hint_id == 2 and decoded.text == "hello" and decoded.submit == true then
    assert(decoded.dom_epoch == 77, "type_hint should send the rendered frame DOM epoch")
    type_hint_seen = true
  end
  if ok and decoded.type == "type_point" then
    type_point_seen = true
  end
end
assert(type_hint_seen, "type_hint should send the backend hint id rather than viewport coordinates")
assert(not type_point_seen, "type_hint should avoid coordinate-based type_point requests")
local type_hint_pending_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(type_hint_pending_id ~= nil, "submitting a hinted input should mark the operation as pending")
serve_stdout(nil, { vim.json.encode({
  id = type_hint_pending_id,
  status = "ok",
  payload = "typed hint frame",
  url = "https://example.com",
  title = "Example",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().pending_operation == nil
end), "type_hint response should clear pending state before later hint captures")

sent_requests = {}
upload_hints_response = vim.json.decode(hints_response)
upload_hints_response.id = type_hint_pending_id + 1
table.insert(upload_hints_response.hints, {
  id = 9,
  hint_label = "u",
  kind = "file",
  label = "Attachment",
  x = 90,
  y = 120,
  width = 160,
  height = 24,
  clickable = true,
  focusable = true,
})
serve_stdout(nil, { vim.json.encode(upload_hints_response), "" })
assert(vim.wait(1000, function()
  return #terminal.state().element_hints == 3
end), "serve hint response should repopulate file hints before hinted upload")
assert(
  terminal.upload_hint("u", { "/tmp/file with spaces.txt" }) == true,
  "upload_hint should upload files into the hinted file input"
)
upload_hint_seen = false
upload_type_point_seen = false
for _, request in ipairs(sent_requests) do
  ok, decoded = pcall(vim.json.decode, request.payload)
  if
    ok
    and decoded.type == "upload_hint"
    and decoded.hint_id == 9
    and decoded.paths[1] == "/tmp/file with spaces.txt"
  then
    assert(decoded.dom_epoch == 77, "upload_hint should send the rendered frame DOM epoch")
    upload_hint_seen = true
  end
  if ok and decoded.type == "type_point" then
    upload_type_point_seen = true
  end
end
assert(upload_hint_seen, "upload_hint should send backend hint id and file paths")
assert(not upload_type_point_seen, "upload_hint should avoid coordinate-based input requests")
upload_hint_pending_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(upload_hint_pending_id ~= nil, "upload_hint should mark the upload operation as pending")
assert(#terminal.state().element_hints > 0, "upload_hint should preserve active hints while a capture is pending")
serve_stdout(nil, { vim.json.encode({
  id = upload_hint_pending_id,
  status = "ok",
  payload = "uploaded hint frame",
  url = "https://example.com",
  title = "Example",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().pending_operation == nil
end), "upload_hint response should clear pending state")
sent_requests = {}
assert(terminal.upload_hint("missing", { "/tmp/example.txt" }) == false, "upload_hint should fail for a missing hint label")
assert(terminal.upload_hint("s", { "/tmp/example.txt" }) == false, "upload_hint should fail for a non-file hint")
assert(terminal.upload_hint("u", {}) == false, "upload_hint should reject empty file lists")
assert(#sent_requests == 0, "upload_hint should not send a request for invalid upload inputs")

sent_requests = {}
local live_hint_response = vim.json.decode(hints_response)
live_hint_response.id = upload_hint_pending_id + 1
serve_stdout(nil, { vim.json.encode(live_hint_response), "" })
assert(vim.wait(1000, function()
  return #terminal.state().element_hints == 2
end), "serve hint response should repopulate element hints before live-refresh-safe typed input")
assert(terminal.refresh() == true, "manual refresh should create an in-flight capture before hinted typing")
assert(vim.wait(1000, function()
  return terminal.state().live_refresh_request_id ~= nil
end), "refresh capture should be in flight before hinted typing")
local stale_live_before_type_hint_id = terminal.state().live_refresh_request_id
sent_requests = {}
assert(terminal.type_hint("s", "live-safe", { submit = false }) == true, "type_hint should work while live refresh is in flight")
assert(
  terminal.state().live_refresh_request_id == nil,
  "type_hint should cancel in-flight refresh before using backend hint ids"
)
serve_stdout(nil, { vim.json.encode({
  id = stale_live_before_type_hint_id,
  status = "ok",
  payload = "stale live frame",
  url = "https://example.com/stale-live",
  title = "Stale Live",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title ~= "Stale Live"
end), "canceled refresh responses should not update metadata after type_hint starts")
local live_safe_pending_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(live_safe_pending_id ~= nil, "live-refresh-safe type_hint should leave the type operation pending")
serve_stdout(nil, { vim.json.encode({
  id = live_safe_pending_id,
  status = "ok",
  payload = "live-safe typed frame",
  url = "https://example.com",
  title = "Example",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().pending_operation == nil
end), "live-refresh-safe type_hint response should clear pending state")

sent_requests = {}
local draft_hints_response = vim.json.decode(hints_response)
draft_hints_response.id = live_safe_pending_id + 1
serve_stdout(nil, { vim.json.encode(draft_hints_response), "" })
assert(vim.wait(1000, function()
  return #terminal.state().element_hints == 2
end), "serve hint response should repopulate element hints before non-submit typed input")
assert(terminal.type_hint("s", "draft", { submit = false }) == true, "non-submit type_hint should type into the hinted element")
local draft_type_hint_seen = false
local draft_type_point_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "type_hint" and decoded.hint_id == 2 and decoded.text == "draft" and decoded.submit == false then
    assert(decoded.dom_epoch == 77, "non-submit type_hint should send the rendered frame DOM epoch")
    draft_type_hint_seen = true
  end
  if ok and decoded.type == "type_point" then
    draft_type_point_seen = true
  end
end
assert(draft_type_hint_seen, "non-submit type_hint should send the backend hint id")
assert(not draft_type_point_seen, "non-submit type_hint should avoid coordinate-based type_point requests")
local draft_type_hint_pending_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(draft_type_hint_pending_id ~= nil, "non-submit type_hint should mark the operation as pending")
assert(#terminal.state().element_hints > 0, "non-submit type_hint should preserve active hints while a capture is pending")
serve_stdout(nil, { vim.json.encode({
  id = draft_type_hint_pending_id,
  status = "ok",
  payload = "draft typed frame",
  url = "https://example.com",
  title = "Example",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().pending_operation == nil
end), "non-submit type_hint response should clear pending state")

sent_requests = {}
local select_hints_response = vim.json.decode(hints_response)
select_hints_response.id = draft_type_hint_pending_id + 1
serve_stdout(nil, { vim.json.encode(select_hints_response), "" })
assert(vim.wait(1000, function()
  return #terminal.state().element_hints == 2
end), "serve hint response should repopulate element hints before hinted select")
assert(terminal.select_hint("s", "Canada") == true, "select_hint should select an option on the hinted element")
local select_hint_seen = false
local select_type_point_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "select_hint" and decoded.hint_id == 2 and decoded.choice == "Canada" then
    assert(decoded.dom_epoch == 77, "select_hint should send the rendered frame DOM epoch")
    select_hint_seen = true
  end
  if ok and decoded.type == "type_point" then
    select_type_point_seen = true
  end
end
assert(select_hint_seen, "select_hint should send the backend hint id and choice")
assert(not select_type_point_seen, "select_hint should avoid coordinate-based type_point requests")
local select_hint_pending_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(select_hint_pending_id ~= nil, "select_hint should mark the select operation as pending")
assert(#terminal.state().element_hints > 0, "select_hint should preserve active hints while a capture is pending")
serve_stdout(nil, { vim.json.encode({
  id = select_hint_pending_id,
  status = "ok",
  payload = "selected hint frame",
  url = "https://example.com",
  title = "Example",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().pending_operation == nil
end), "select_hint response should clear pending state")
sent_requests = {}
assert(terminal.select_hint("missing", "Canada") == false, "select_hint should fail for a missing hint label")
assert(#sent_requests == 0, "select_hint should not send a request for a missing hint label")

sent_requests = {}
local toggle_hints_response = vim.json.decode(hints_response)
toggle_hints_response.id = select_hint_pending_id + 1
toggle_hints_response.hints[2].kind = "checkbox"
toggle_hints_response.hints[2].checked = false
serve_stdout(nil, { vim.json.encode(toggle_hints_response), "" })
assert(vim.wait(1000, function()
  return #terminal.state().element_hints == 2
end), "serve hint response should repopulate element hints before hinted toggle")
assert(terminal.toggle_hint("s") == true, "toggle_hint should toggle the hinted checkbox/radio")
local toggle_hint_seen = false
local toggle_type_point_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "toggle_hint" and decoded.hint_id == 2 then
    assert(decoded.dom_epoch == 77, "toggle_hint should send the rendered frame DOM epoch")
    toggle_hint_seen = true
  end
  if ok and decoded.type == "type_point" then
    toggle_type_point_seen = true
  end
end
assert(toggle_hint_seen, "toggle_hint should send the backend hint id")
assert(not toggle_type_point_seen, "toggle_hint should avoid coordinate-based type_point requests")
local toggle_hint_pending_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(toggle_hint_pending_id ~= nil, "toggle_hint should mark the toggle operation as pending")
assert(#terminal.state().element_hints > 0, "toggle_hint should preserve active hints while a capture is pending")
serve_stdout(nil, { vim.json.encode({
  id = toggle_hint_pending_id,
  status = "ok",
  payload = "toggled hint frame",
  url = "https://example.com",
  title = "Example",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().pending_operation == nil
end), "toggle_hint response should clear pending state")
sent_requests = {}
assert(terminal.toggle_hint("missing") == false, "toggle_hint should fail for a missing hint label")
assert(#sent_requests == 0, "toggle_hint should not send a request for a missing hint label")

sent_requests = {}
local hover_hints_response = vim.json.decode(hints_response)
hover_hints_response.id = toggle_hint_pending_id + 1
serve_stdout(nil, { vim.json.encode(hover_hints_response), "" })
assert(vim.wait(1000, function()
  return #terminal.state().element_hints == 2
end), "serve hint response should repopulate element hints before hover")
assert(terminal.hover_hint("s") == true, "hover_hint should hover hints by backend id")
local hover_hint_seen = false
local hover_point_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "hover_hint" and decoded.hint_id == 2 then
    assert(decoded.dom_epoch == 77, "hover_hint should send the rendered frame DOM epoch")
    hover_hint_seen = true
  end
  if ok and decoded.type == "hover_point" then
    hover_point_seen = true
  end
end
assert(hover_hint_seen, "hover_hint should send the backend hint id")
assert(not hover_point_seen, "hover_hint should avoid coordinate hover requests")
local hover_pending_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(hover_pending_id ~= nil, "hover_hint should mark the hover capture as pending")
serve_stdout(nil, { vim.json.encode({
  id = hover_pending_id,
  status = "ok",
  payload = "hovered frame",
  url = "https://example.com",
  title = "Example",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().pending_operation == nil
end), "hover response should clear the pending hover operation")

sent_requests = {}
vim.cmd("doautocmd VimResized")
vim.cmd("doautocmd WinResized")
vim.cmd("doautocmd VimResized")
assert(#nvim_browser_requests_of_type("resize") == 0, "resize autocmds should be coalesced instead of sending immediately")
assert(nvim_browser_latest_timer() ~= nil, "resize autocmds should create a trailing resize timer")
assert(nvim_browser_latest_timer().starts[#nvim_browser_latest_timer().starts].timeout == 50, "resize coalescing should use a short trailing delay")
vim.api.nvim_win_set_width(terminal.state().winid, math.max(45, vim.api.nvim_win_get_width(terminal.state().winid) - 3))
_G.nvim_browser_resize_expected_columns = math.max(20, vim.api.nvim_win_get_width(terminal.state().winid) - 2)
nvim_browser_latest_timer().callback()
assert(vim.wait(1000, function()
  return #nvim_browser_requests_of_type("resize") == 1
end), "active serve sessions should flush one coalesced resize after Neovim resize storms")
assert(
  nvim_browser_requests_of_type("resize")[1].columns == _G.nvim_browser_resize_expected_columns,
  "coalesced resize should use the latest preview geometry at flush time"
)

sent_requests = {}
assert(terminal.refresh() == true, "test setup should create an in-flight capture before resize")
local stale_before_resize_capture_id = terminal.state().live_refresh_request_id
assert(stale_before_resize_capture_id ~= nil, "test setup should track capture before resize")
sent_requests = {}
vim.cmd("doautocmd WinResized")
assert(#nvim_browser_requests_of_type("resize") == 0, "resize while a capture is in flight should still wait for the coalescing flush")
nvim_browser_latest_timer().callback()
assert(vim.wait(1000, function()
  return #nvim_browser_requests_of_type("resize") == 1
end), "resize should still be sent after coalescing while a capture is in flight")
serve_stdout(nil, { vim.json.encode({
  id = stale_before_resize_capture_id,
  status = "ok",
  payload = "stale before resize frame",
  url = "https://example.com/stale-before-resize",
  title = "Stale Before Resize",
  hints = {
    {
      id = 77,
      kind = "button",
      label = "Stale Resize Hint",
      x = 1,
      y = 2,
      width = 3,
      height = 4,
      clickable = true,
      focusable = true,
    },
  },
}), "" })
local stale_before_resize_applied = vim.wait(200, function()
  return terminal.state().current_title == "Stale Before Resize"
end)
assert(not stale_before_resize_applied, "capture response made stale by resize should not update browser metadata")
assert(terminal.state().live_refresh_request_id == nil, "stale capture tracking should be cleared after resize invalidates it")
assert(#terminal.state().element_hints == 0, "capture response made stale by resize should not update hints")

sent_requests = {}
vim.cmd("doautocmd WinResized")
assert(#nvim_browser_requests_of_type("resize") == 0, "window resize autocmd should be delayed for coalescing")
nvim_browser_latest_timer().callback()
assert(vim.wait(1000, function()
  return #nvim_browser_requests_of_type("resize") == 1
end), "active serve sessions should resize when the preview window changes size")

sent_requests = {}
vim.cmd("doautocmd WinResized")
terminal.open({ "nvbrowser", "show-image", "/tmp/replaces-serve-before-resize.png", "--output", "ansi" })
if nvim_browser_latest_timer() and nvim_browser_latest_timer().callback then
  nvim_browser_latest_timer().callback()
end
assert(#nvim_browser_requests_of_type("resize") == 0, "replacing a serve session should cancel pending coalesced resize timers")

terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com/resize-config" })
terminal._test.clear_in_flight_capture()
termopen_calls = {}

sent_requests = {}
vim.cmd("doautocmd WinResized")
terminal.configure({
  live_refresh = {
    enabled = false,
  },
})
if nvim_browser_latest_timer() and nvim_browser_latest_timer().callback then
  nvim_browser_latest_timer().callback()
end
vim.wait(100, function()
  return #nvim_browser_requests_of_type("resize") > 0
end)
assert(#nvim_browser_requests_of_type("resize") == 0, "config reset should cancel pending coalesced resize timers")

sent_requests = {}
terminal.configure({
  viewport = {
    cell_width_px = 8,
    cell_height_px = 16,
  },
})
local configure_resize_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "resize" and decoded.width == decoded.columns * 8 and decoded.height == decoded.rows * 16 then
    configure_resize_seen = true
  end
end
assert(configure_resize_seen, "active serve sessions should resize immediately when viewport cell pixels change")

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

terminal.configure({ live_refresh = { enabled = true, interval_ms = 1500 } })
_G.nvim_browser_quiet_live_timer = nvim_browser_latest_timer()
terminal._test.apply_serve_response({
  id = 500,
  status = "ok",
  payload = "quiet baseline frame",
  url = "https://example.com/before-quiet",
  title = "Before Quiet",
  runtime = {
    protocol_version = 15,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "ansi",
    cells = { columns = 50, rows = 11 },
    viewport = { width = 450, height = 165, device_scale_factor = 1 },
  },
})
local quiet_geometry = terminal.state().rendered_frame_geometry
assert(quiet_geometry ~= nil, "test setup should have a rendered frame geometry")
terminal._test.set_element_hints({
  {
    id = 1,
    kind = "input",
    label = "Search",
    x = 10,
    y = 20,
    width = 30,
    height = 10,
    clickable = true,
    focusable = true,
  },
}, quiet_geometry)
assert(#terminal.state().element_hints == 1, "test setup should have active hints before quiet metadata")
sent_requests = {}
assert(terminal.input_text("quiet metadata", { capture = false, resize = false }) == true, "quiet input should send a quiet text request")
local quiet_request = last_request_of_type("text_input")
assert(quiet_request ~= nil and quiet_request.capture == false, "quiet input should mark the request as capture=false")
serve_stdout(nil, { vim.json.encode({
  id = quiet_request.id,
  status = "ok",
  url = "https://example.com/after-quiet",
  title = "After Quiet",
  page = {
    scroll_x = 0,
    scroll_y = 80,
    viewport_width = 450,
    viewport_height = 165,
    document_width = 450,
    document_height = 900,
  },
  focused = {
    kind = "input",
    label = "Search",
    value = "quiet metadata",
    focusable = true,
    submittable = true,
  },
  runtime = {
    protocol_version = 15,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "ansi",
    cells = { columns = 50, rows = 11 },
    viewport = { width = 450, height = 165, device_scale_factor = 1 },
  },
}), "" })
assert(vim.wait(200, function()
  return terminal.state().current_title == "After Quiet"
end), "quiet ok responses should apply browser metadata")
assert(terminal.state().current_url == "https://example.com/after-quiet", "quiet metadata should update current URL")
assert(terminal.state().focused_element.value == "quiet metadata", "quiet metadata should update focused element state")
assert(terminal.state().page_metrics.scroll_y == 80, "quiet metadata should update page metrics")
assert(terminal.state().rendered_frame_geometry == quiet_geometry, "quiet metadata without payload should keep current frame geometry")
assert(#terminal.state().element_hints == 1, "quiet metadata without payload should keep current hints")
_G.nvim_browser_quiet_adaptive_timer = nvim_browser_latest_timer()
assert(
  _G.nvim_browser_quiet_adaptive_timer.starts[1].timeout == 100,
  "changed quiet metadata without payload should schedule a debounced full-frame capture"
)
sent_requests = {}
assert(terminal.input_text("quiet metadata again", { capture = false, resize = false }) == true, "second quiet input should send a quiet text request")
_G.nvim_browser_second_quiet_request = last_request_of_type("text_input")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_second_quiet_request.id,
  status = "ok",
  url = "https://example.com/after-quiet",
  title = "After Quiet Again",
  page = {
    scroll_x = 0,
    scroll_y = 81,
    viewport_width = 450,
    viewport_height = 165,
    document_width = 450,
    document_height = 900,
  },
  focused = {
    kind = "input",
    label = "Search",
    value = "quiet metadata again",
    focusable = true,
    submittable = true,
  },
}), "" })
assert(vim.wait(200, function()
  return terminal.state().current_title == "After Quiet Again"
end), "second changed quiet metadata should apply browser metadata")
_G.nvim_browser_second_quiet_adaptive_timer = nvim_browser_latest_timer()
assert(
  _G.nvim_browser_second_quiet_adaptive_timer ~= _G.nvim_browser_quiet_adaptive_timer,
  "second changed quiet metadata should replace the previous adaptive capture debounce"
)
_G.nvim_browser_quiet_adaptive_timer.callback()
vim.wait(50)
assert(last_request_of_type("capture") == nil, "replaced quiet adaptive capture timers should not send duplicate captures")
_G.nvim_browser_second_quiet_adaptive_timer.callback()
assert(vim.wait(1000, function()
  local capture = last_request_of_type("capture")
  return capture ~= nil and terminal.state().live_refresh_request_id == capture.id
end), "quiet metadata adaptive capture timer should send one tracked full-frame capture")
terminal._test.clear_in_flight_capture()

sent_requests = {}
_G.nvim_browser_quiet_live_timer.callback()
assert(vim.wait(1000, function()
  _G.nvim_browser_quiet_page_state_id = terminal.state().live_refresh_request_id
  return _G.nvim_browser_quiet_page_state_id ~= nil and last_request_of_type("page_state") ~= nil
end), "test setup should leave a live page-state request in flight")
_G.nvim_browser_quiet_race_timer_count = #fake_timers
sent_requests = {}
assert(terminal.input_text("quiet metadata race", { capture = false, resize = false }) == true, "quiet input should work while page-state is in flight")
_G.nvim_browser_quiet_race_request = last_request_of_type("text_input")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_quiet_race_request.id,
  status = "ok",
  url = "https://example.com/after-quiet",
  title = "After Quiet Race",
  page = {
    scroll_x = 0,
    scroll_y = 81,
    viewport_width = 450,
    viewport_height = 165,
    document_width = 450,
    document_height = 900,
  },
  focused = {
    kind = "input",
    label = "Search",
    value = "quiet metadata race",
    focusable = true,
    submittable = true,
  },
}), "" })
assert(vim.wait(200, function()
  return terminal.state().current_title == "After Quiet Race"
end), "quiet metadata should apply even when page-state is in flight")
assert(#fake_timers > _G.nvim_browser_quiet_race_timer_count, "changed quiet metadata should schedule capture even when page-state is in flight")
_G.nvim_browser_quiet_race_adaptive_timer = nvim_browser_latest_timer()
sent_requests = {}
_G.nvim_browser_quiet_race_adaptive_timer.callback()
assert(vim.wait(1000, function()
  local capture = last_request_of_type("capture")
  return capture ~= nil and terminal.state().live_refresh_request_id == capture.id
end), "quiet metadata race adaptive capture timer should send one tracked full-frame capture")
terminal._test.clear_in_flight_capture()

sent_requests = {}
assert(terminal.input_text("quiet metadata before capture", { capture = false, resize = false }) == true, "quiet input should send before a newer capture")
_G.nvim_browser_quiet_before_capture_request = last_request_of_type("text_input")
assert(terminal.refresh() == true, "test setup should start a newer full capture")
_G.nvim_browser_newer_capture_request = last_request_of_type("capture")
assert(
  _G.nvim_browser_newer_capture_request.id > _G.nvim_browser_quiet_before_capture_request.id,
  "test setup should make the in-flight capture newer than the quiet response"
)
_G.nvim_browser_newer_capture_timer_count = #fake_timers
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_quiet_before_capture_request.id,
  status = "ok",
  url = "https://example.com/after-quiet",
  title = "After Newer Capture",
  page = {
    scroll_x = 0,
    scroll_y = 82,
    viewport_width = 450,
    viewport_height = 165,
    document_width = 450,
    document_height = 900,
  },
  focused = {
    kind = "input",
    label = "Search",
    value = "quiet metadata before capture",
    focusable = true,
    submittable = true,
  },
}), "" })
assert(vim.wait(200, function()
  return terminal.state().current_title == "After Newer Capture"
end), "quiet metadata should apply while a newer full capture is in flight")
assert(
  terminal.state().live_refresh_request_id == _G.nvim_browser_newer_capture_request.id,
  "quiet metadata should keep a newer in-flight full capture alive"
)
assert(#fake_timers == _G.nvim_browser_newer_capture_timer_count, "quiet metadata should not schedule another capture when a newer full capture is in flight")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_newer_capture_request.id,
  status = "ok",
  payload = "newer capture frame",
  url = "https://example.com/after-quiet",
  title = "After Newer Capture",
  page = {
    scroll_x = 0,
    scroll_y = 82,
    viewport_width = 450,
    viewport_height = 165,
    document_width = 450,
    document_height = 900,
  },
  focused = {
    kind = "input",
    label = "Search",
    value = "quiet metadata before capture",
    focusable = true,
    submittable = true,
  },
  runtime = {
    protocol_version = 15,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "ansi",
    cells = { columns = 50, rows = 11 },
    viewport = { width = 450, height = 165, device_scale_factor = 1 },
  },
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().live_refresh_request_id == nil and terminal.state().rendered_frame_url == "https://example.com/after-quiet"
end), "newer full capture should still be allowed to replace the frame")

sent_requests = {}
_G.nvim_browser_quiet_stable_timer_count = #fake_timers
assert(terminal.input_text("same quiet metadata", { capture = false, resize = false }) == true, "stable quiet input should send a quiet text request")
_G.nvim_browser_stable_quiet_request = last_request_of_type("text_input")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_stable_quiet_request.id,
  status = "ok",
  url = "https://example.com/after-quiet",
  title = "After Newer Capture",
  page = {
    scroll_x = 0,
    scroll_y = 82,
    viewport_width = 450,
    viewport_height = 165,
    document_width = 450,
    document_height = 900,
  },
  focused = {
    kind = "input",
    label = "Search",
    value = "quiet metadata before capture",
    focusable = true,
    submittable = true,
  },
}), "" })
assert(vim.wait(200, function()
  return terminal.state().current_title == "After Newer Capture"
end), "stable quiet metadata should still apply browser metadata")
vim.wait(50)
assert(#fake_timers == _G.nvim_browser_quiet_stable_timer_count, "unchanged quiet metadata without payload should not schedule adaptive capture")

sent_requests = {}
assert(terminal.refresh() == true, "checkbox baseline should use a real capture request")
_G.nvim_browser_checkbox_baseline_request = last_request_of_type("capture")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_checkbox_baseline_request.id,
  status = "ok",
  payload = "checkbox baseline frame",
  url = "https://example.com/checkbox",
  title = "Checkbox",
  page = {
    scroll_x = 0,
    scroll_y = 0,
    viewport_width = 450,
    viewport_height = 165,
    document_width = 450,
    document_height = 165,
  },
  focused = {
    kind = "checkbox",
    label = "Newsletter",
    checked = false,
    focusable = true,
    submittable = true,
  },
  runtime = {
    protocol_version = 15,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "ansi",
    cells = { columns = 50, rows = 11 },
    viewport = { width = 450, height = 165, device_scale_factor = 1 },
  },
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title == "Checkbox" and terminal.state().focused_element.checked == false
end), "test setup should apply unchecked checkbox focus metadata")
assert(
  terminal._test.preview_footer_line(120):find("focus=checkbox Newsletter unchecked", 1, true),
  "preview footer should show unchecked checkbox focus state"
)
sent_requests = {}
_G.nvim_browser_checked_timer_count = #fake_timers
assert(terminal.input_text("toggle metadata", { capture = false, resize = false }) == true, "checked quiet input should send a quiet request")
_G.nvim_browser_checked_request = last_request_of_type("text_input")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_checked_request.id,
  status = "ok",
  url = "https://example.com/checkbox",
  title = "Checkbox",
  page = {
    scroll_x = 0,
    scroll_y = 0,
    viewport_width = 450,
    viewport_height = 165,
    document_width = 450,
    document_height = 165,
  },
  focused = {
    kind = "checkbox",
    label = "Newsletter",
    checked = true,
    focusable = true,
    submittable = true,
  },
}), "" })
assert(vim.wait(200, function()
  return terminal.state().focused_element.checked == true
end), "checked quiet metadata should update focused checkbox state")
assert(
  terminal._test.preview_footer_line(120):find("focus=checkbox Newsletter checked", 1, true),
  "preview footer should show checked checkbox focus state"
)
assert(#fake_timers > _G.nvim_browser_checked_timer_count, "checked-only quiet metadata changes should schedule adaptive capture")

sent_requests = {}
assert(terminal.refresh() == true, "DOM epoch baseline should use a real capture request")
_G.nvim_browser_dom_epoch_baseline_request = last_request_of_type("capture")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_dom_epoch_baseline_request.id,
  status = "ok",
  payload = "dom epoch baseline frame",
  url = "https://example.com/dom-epoch-baseline",
  title = "DOM Epoch Baseline",
  dom_epoch = 10,
  hints = {
    {
      id = 10,
      kind = "button",
      label = "Old DOM Button",
      href = "https://example.com/old-dom-button",
      x = 10,
      y = 20,
      width = 30,
      height = 10,
      clickable = true,
      focusable = true,
    },
  },
  runtime = {
    protocol_version = 19,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "ansi",
    cells = { columns = 50, rows = 11 },
    viewport = { width = 450, height = 165, device_scale_factor = 1 },
  },
}), "" })
assert(vim.wait(200, function()
  return terminal.state().dom_epoch == 10 and #terminal.state().element_hints == 1
end), "test setup should apply a captured DOM epoch baseline with hints")
_G.nvim_browser_dom_epoch_stale_geometry = terminal.state().rendered_frame_geometry
vim.fn.setreg("b", "before-same-dom")
terminal._test.apply_serve_response({
  id = _G.nvim_browser_dom_epoch_baseline_request.id,
  status = "ok",
  url = "https://example.com/dom-epoch-baseline",
  title = "DOM Epoch Baseline",
  dom_epoch = 10,
})
assert(terminal.yank_hint_url("a", "b") == true, "same DOM epoch lightweight metadata should keep existing hints usable")
assert(
  vim.fn.getreg("b") == "https://example.com/old-dom-button",
  "same DOM epoch lightweight metadata should keep hint hrefs available"
)
sent_requests = {}
assert(terminal.input_text("quiet stale dom", { capture = false, resize = false }) == true, "quiet stale setup should send quiet input")
_G.nvim_browser_stale_dom_request = last_request_of_type("text_input")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_stale_dom_request.id,
  status = "ok",
  url = "https://example.com/dom-epoch-baseline",
  title = "DOM Epoch Baseline",
  dom_epoch = 11,
}), "" })
assert(vim.wait(200, function()
  return terminal.state().dom_epoch == 11
end), "quiet DOM epoch changes should update DOM metadata")
_G.nvim_browser_quiet_dom_epoch_adaptive_timer = nvim_browser_latest_timer()
assert(
  _G.nvim_browser_quiet_dom_epoch_adaptive_timer ~= _G.nvim_browser_quiet_adaptive_timer,
  "quiet DOM epoch changes without payload should schedule adaptive capture"
)
assert(terminal.state().frame_health.stale == true, "quiet DOM epoch changes should mark the rendered frame stale")
assert(terminal.state().frame_health.refresh_pending == true, "quiet DOM epoch changes should mark the frame refresh pending")
assert(terminal.state().frame_health.reason == "dom_epoch", "quiet DOM epoch changes should explain stale frame health")
assert(
  terminal._test.preview_footer_line(120):find("frame=stale", 1, true),
  "quiet DOM epoch changes should show stale frame state in the footer"
)
assert(
  terminal._test.preview_footer_line(120):find("refreshing", 1, true),
  "quiet DOM epoch changes should show pending refresh state in the footer"
)
_G.nvim_browser_quiet_dom_epoch_footer = table.concat(
  vim.api.nvim_buf_get_lines(terminal.state().bufnr, 0, -1, false),
  "\n"
)
assert(
  _G.nvim_browser_quiet_dom_epoch_footer:find("refreshing", 1, true),
  "quiet DOM epoch changes should update the visible buffer footer with pending refresh state"
)
assert(#terminal.state().element_hints == 1, "quiet DOM epoch changes should leave stale hints visible until capture")
vim.fn.setreg("b", "preserve-stale-dom")
assert(terminal.yank_hint_url("a", "b") == false, "advanced DOM epoch should make old hint hrefs unavailable")
assert(vim.fn.getreg("b") == "preserve-stale-dom", "stale DOM hints should not mutate registers")
sent_requests = {}
assert(terminal.click_hint("a") == false, "advanced DOM epoch should make old hint actions unavailable")
assert(last_request_of_type("click_hint") == nil, "advanced DOM epoch should not send old backend hint ids")
_G.nvim_browser_quiet_dom_epoch_adaptive_timer.callback()
assert(vim.wait(1000, function()
  local capture = last_request_of_type("capture")
  return capture ~= nil and terminal.state().live_refresh_request_id == capture.id
end), "quiet DOM epoch adaptive capture timer should send one tracked full-frame capture")
assert(terminal.state().frame_health.refresh_pending == true, "in-flight adaptive capture should keep refresh pending visible")
terminal._test.clear_in_flight_capture()

serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_stale_dom_request.id + 1,
  status = "ok",
  payload = "fresh dom epoch frame",
  url = "https://example.com/dom-epoch-baseline",
  title = "DOM Epoch Baseline",
  dom_epoch = 11,
  runtime = {
    protocol_version = 19,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "ansi",
    cells = { columns = 50, rows = 11 },
    viewport = { width = 450, height = 165, device_scale_factor = 1 },
  },
  hints = {
    {
      id = 11,
      kind = "button",
      label = "Fresh DOM Button",
      x = 10,
      y = 20,
      width = 30,
      height = 10,
      clickable = true,
      focusable = true,
    },
  },
}), "" })
assert(vim.wait(200, function()
  return terminal.state().dom_epoch == 11 and terminal.state().rendered_frame_geometry ~= _G.nvim_browser_dom_epoch_stale_geometry
end), "fresh DOM epoch capture should replace the stale rendered frame")
assert(terminal.state().frame_health.stale == false, "fresh DOM epoch capture should clear stale frame health")
assert(terminal.state().frame_health.refresh_pending == false, "fresh DOM epoch capture should clear pending refresh health")
assert(
  not terminal._test.preview_footer_line(120):find("frame=stale", 1, true),
  "fresh DOM epoch capture should remove stale frame footer state"
)
terminal._test.apply_serve_response({
  id = _G.nvim_browser_stale_dom_request.id + 2,
  status = "ok",
  url = "https://example.com/dom-epoch-baseline",
  title = "DOM Epoch Baseline",
  dom_epoch = 12,
})
assert(terminal.state().frame_health.stale == true, "direct DOM metadata changes should make existing hints stale")
sent_requests = {}
assert(terminal.click_hint("a") == false, "DOM-stale hint actions should not use old backend hint ids")
assert(last_request_of_type("click_hint") == nil, "DOM-stale hint actions should not send old hint ids")
assert(last_request_of_type("capture") ~= nil, "DOM-stale hint actions should request a fresh captured frame")
assert(#nvim_browser_requests_of_type("capture") == 1, "DOM-stale hint actions should request exactly one capture")
assert(terminal.click_hint("a") == false, "repeated DOM-stale hint actions should remain unavailable until capture")
assert(#nvim_browser_requests_of_type("capture") == 1, "repeated DOM-stale hint actions should not duplicate captures in flight")
terminal._test.clear_in_flight_capture()
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_stale_dom_request.id + 3,
  status = "ok",
  payload = "fresh dom epoch frame after stale action",
  url = "https://example.com/dom-epoch-baseline",
  title = "DOM Epoch Baseline",
  dom_epoch = 12,
  runtime = {
    protocol_version = 19,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "ansi",
    cells = { columns = 50, rows = 11 },
    viewport = { width = 450, height = 165, device_scale_factor = 1 },
  },
  hints = {
    {
      id = 12,
      kind = "button",
      label = "Fresh DOM Button Again",
      x = 10,
      y = 20,
      width = 30,
      height = 10,
      clickable = true,
      focusable = true,
    },
  },
}), "" })
assert(vim.wait(200, function()
  return terminal.state().dom_epoch == 12 and terminal.state().frame_health.stale == false
end), "test setup should restore fresh hints after DOM-stale action refresh")
_G.nvim_browser_fresh_hint_geometry = terminal.state().current_preview_geometry
_G.nvim_browser_stale_hint_geometry = vim.deepcopy(_G.nvim_browser_fresh_hint_geometry)
_G.nvim_browser_stale_hint_geometry.width = _G.nvim_browser_stale_hint_geometry.width + 10
terminal._test.set_element_hints(terminal.state().element_hints, _G.nvim_browser_stale_hint_geometry)
sent_requests = {}
assert(terminal.click_hint("a") == false, "geometry-stale hint actions should not use old backend hint ids")
assert(last_request_of_type("click_hint") == nil, "geometry-stale hint actions should not send old hint ids")
assert(last_request_of_type("resize") ~= nil, "geometry-stale hint actions should request a resize refresh")
terminal._test.set_element_hints(terminal.state().element_hints, _G.nvim_browser_fresh_hint_geometry)
sent_requests = {}
assert(terminal.click_hint("a") == true, "captured DOM epoch frame should make fresh hints usable again")
assert(last_request_of_type("click_hint") ~= nil, "fresh hints should send backend hint ids")
terminal._test.set_pending_operation(nil)

sent_requests = {}
assert(terminal.start_text_mode({
  getcharstr = (function()
    local keys = { "h", "i", "\r", "\t", vim.keycode("<S-Tab>"), vim.keycode("<BS>"), vim.keycode("<Esc>") }
    local first = true
    return function()
      if first then
        first = false
        assert(terminal._test.preview_footer_line(120):match("^text"), "browser text mode should be visible in the preview footer")
      end
      return table.remove(keys, 1)
    end
  end)(),
}) == true, "browser text mode should start for active cursor-addressable previews")
assert(terminal.state().text_mode_active == false, "browser text mode should exit after Escape")
local text_mode_text = {}
local text_mode_keys = {}
local text_mode_captures = 0
local text_mode_resizes = 0
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "text_input" then
    table.insert(text_mode_text, decoded.text .. ":" .. tostring(decoded.capture))
  end
  if ok and decoded.type == "key_press" then
    table.insert(text_mode_keys, decoded.key .. ":" .. table.concat(decoded.modifiers or {}, "+") .. ":" .. tostring(decoded.capture))
  end
  if ok and decoded.type == "capture" then
    text_mode_captures = text_mode_captures + 1
  end
  if ok and decoded.type == "resize" then
    text_mode_resizes = text_mode_resizes + 1
  end
end
assert(table.concat(text_mode_text, ",") == "hi:false", "browser text mode should batch printable keys as quiet text_input")
assert(
  table.concat(text_mode_keys, ",") == "Enter::true,Tab::false,Tab:shift:false,Backspace::false",
  "browser text mode should capture Enter immediately and keep editing keys quiet"
)
assert(text_mode_captures == 1, "browser text mode should capture once when it exits")
assert(text_mode_resizes == 0, "browser text mode quiet input should not force resize captures for every key")
assert(terminal._test.text_mode_key_action("\1") == nil, "browser text mode should ignore unmapped control characters")
assert(terminal._test.text_mode_key_action(vim.keycode("<Del>")).key == "Delete", "browser text mode should translate Delete")
assert(terminal._test.text_mode_key_action(vim.keycode("<Up>")).key == "ArrowUp", "browser text mode should translate ArrowUp")
assert(terminal._test.text_mode_key_action(vim.keycode("<Down>")).key == "ArrowDown", "browser text mode should translate ArrowDown")
assert(terminal._test.text_mode_key_action(vim.keycode("<Left>")).key == "ArrowLeft", "browser text mode should translate ArrowLeft")
assert(terminal._test.text_mode_key_action(vim.keycode("<Right>")).key == "ArrowRight", "browser text mode should translate ArrowRight")

sent_requests = {}
_G.nvim_browser_debounce_step = 0
assert(terminal.start_text_mode({
  getcharstr = function()
    _G.nvim_browser_debounce_step = _G.nvim_browser_debounce_step + 1
    if _G.nvim_browser_debounce_step == 1 then
      return "d"
    end
    if _G.nvim_browser_debounce_step == 2 then
      return "e"
    end
    assert(#nvim_browser_requests_of_type("text_input") == 0, "text mode should not send batched text before debounce flush")
    assert(nvim_browser_latest_timer().starts[#nvim_browser_latest_timer().starts].timeout == 25, "text mode should use a short trailing text flush delay")
    nvim_browser_latest_timer().callback()
    assert(vim.wait(1000, function()
      return #nvim_browser_requests_of_type("text_input") == 1
    end), "text mode debounce timer should flush buffered text")
    return vim.keycode("<Esc>")
  end,
}) == true, "browser text mode should flush buffered text after the debounce timer")
assert(nvim_browser_requests_of_type("text_input")[1].text == "de", "text mode debounce flush should batch rapid printable text")

sent_requests = {}
assert(terminal.start_text_mode({
  getcharstr = (function()
    local keys = { "a", "b", "c", vim.keycode("<Esc>") }
    return function()
      return table.remove(keys, 1)
    end
  end)(),
}) == true, "browser text mode should batch rapid printable keys")
assert(#nvim_browser_requests_of_type("text_input") == 1, "rapid printable text should flush as one quiet request on exit")
assert(nvim_browser_requests_of_type("text_input")[1].text == "abc", "rapid printable text should preserve order in the batch")
assert(nvim_browser_request_sequence():match("text_input:abc,capture:"), "text mode should flush text before final exit capture")

sent_requests = {}
assert(terminal.start_text_mode({
  getcharstr = (function()
    local keys = {}
    for _ = 1, 33 do
      table.insert(keys, "x")
    end
    table.insert(keys, vim.keycode("<Esc>"))
    return function()
      return table.remove(keys, 1)
    end
  end)(),
}) == true, "browser text mode should flush full text batches")
assert(#nvim_browser_requests_of_type("text_input") == 2, "33 printable chars should flush at 32 and flush the remainder on exit")
assert(#nvim_browser_requests_of_type("text_input")[1].text == 32, "first full text batch should contain 32 chars")
assert(nvim_browser_requests_of_type("text_input")[2].text == "x", "remaining printable char should flush on exit")

sent_requests = {}
assert(terminal.start_text_mode({
  getcharstr = (function()
    local keys = { "a", "b", vim.keycode("<BS>"), vim.keycode("<Esc>") }
    return function()
      return table.remove(keys, 1)
    end
  end)(),
}) == true, "browser text mode should flush printable text before non-text keys")
assert(
  nvim_browser_request_sequence():match("^text_input:ab,key_press:Backspace"),
  "browser text mode should send pending text before Backspace"
)

terminal._test.clear_in_flight_capture()
sent_requests = {}
assert(terminal.refresh() == true, "test setup should create an in-flight capture")
local stale_text_mode_capture_id = terminal.state().live_refresh_request_id
assert(stale_text_mode_capture_id ~= nil, "test setup should track the in-flight capture")
sent_requests = {}
assert(terminal.start_text_mode({
  getcharstr = (function()
    local keys = { "x", vim.keycode("<Esc>") }
    return function()
      return table.remove(keys, 1)
    end
  end)(),
}) == true, "browser text mode should exit while a capture is in flight")
local forced_exit_capture = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "capture" then
    forced_exit_capture = true
  end
end
assert(forced_exit_capture, "browser text mode exit should queue a fresh capture even when another capture is in flight")
serve_stdout(nil, { vim.json.encode({
  id = stale_text_mode_capture_id,
  status = "ok",
  payload = "stale text mode frame",
  url = "https://example.com/stale-text-mode",
  title = "Stale Text Mode",
}), "" })
local stale_text_mode_applied = vim.wait(200, function()
  return terminal.state().current_title == "Stale Text Mode"
end)
assert(not stale_text_mode_applied, "browser text mode should ignore the older in-flight capture it replaced")
terminal._test.clear_in_flight_capture()

terminal._test.set_cursor_addressable_preview(false)
local text_mode_warning_count = #warnings
assert(terminal.start_text_mode({ getcharstr = function()
  error("inactive text mode should not read keys")
end }) == false, "browser text mode should refuse inactive cursor-addressable previews")
assert(
  warnings[#warnings] == "nvim-browser: text mode requires an active cursor-addressable browser preview",
  "browser text mode should warn when unavailable"
)
assert(#warnings == text_mode_warning_count + 1, "browser text mode should emit one inactive warning")
terminal._test.set_cursor_addressable_preview(true)

sent_requests = {}
assert(terminal.start_text_mode({
  getcharstr = (function()
    local keys = { "z", vim.keycode("<Esc>") }
    return function()
      return table.remove(keys, 1)
    end
  end)(),
}) == true, "test setup should leave a quiet request without a response")
jobstart_calls = {}
terminal.open({ "nvbrowser", "serve", "--output", "kitty", "--url", "https://example.com/quiet-reset" })
sent_requests = {}
assert(terminal.refresh() == true, "new serve session should be able to request capture")
assert(last_request_of_type("capture") ~= nil, "manual refresh should request a full capture")
assert(last_request_of_type("page_state") == nil, "manual refresh should not use page_state")
serve_stdout(nil, { vim.json.encode({
  id = terminal.state().live_refresh_request_id,
  status = "ok",
  payload = "fresh frame after quiet reset",
  url = "https://example.com/quiet-next",
  title = "Quiet Reset",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title == "Quiet Reset"
end), "new serve responses should not be suppressed by stale quiet request ids")
terminal._test.clear_in_flight_capture()
_G.nvim_browser_post_frame_exit_bufnr = terminal.state().bufnr
serve_exit(nil, 3)
assert(vim.wait(1000, function()
  return terminal.state().mode == nil
end), "serve exit after a good frame should close the active serve state")
_G.nvim_browser_post_frame_exit_text = _G.nvim_browser_buffer_text(_G.nvim_browser_post_frame_exit_bufnr)
assert(
  not _G.nvim_browser_post_frame_exit_text:find("Browser session exited: 3", 1, true),
  "serve exit after a good frame should not replace the preview body with the generic exit message"
)
assert(
  terminal.state().status_error == "browser exited 3",
  "serve exit after a good frame should keep the exit reason in status"
)
assert(terminal.state().serve_exit ~= nil, "serve exit after a good frame should expose restart metadata")
assert(terminal.state().serve_exit.code == 3, "serve exit restart metadata should expose the exit code")
assert(terminal.state().serve_exit.target == "https://example.com/quiet-next", "serve exit restart metadata should use the last rendered URL")
assert(terminal.state().serve_exit.restartable == true, "serve exit after a good frame should be explicitly restartable")
assert(
  _G.nvim_browser_post_frame_exit_text:find("exited", 1, true)
    and _G.nvim_browser_post_frame_exit_text:find("NBrowserRefresh", 1, true),
  "serve exit after a good frame should show a recoverable exited footer"
)
assert(
  not _G.nvim_browser_post_frame_exit_text:find("Browser startup failed", 1, true),
  "serve exit after a good frame should not be treated as a startup failure"
)
jobstart_calls = {}
sent_requests = {}
assert(terminal.refresh() == true, "refresh after post-frame serve exit should restart the serve session")
assert(#jobstart_calls == 1, "post-frame exit refresh should start one replacement serve job")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--url") == "https://example.com/quiet-next", "post-frame exit refresh should target the last rendered URL")

terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com/preserve-exit-frame" })
serve_stdout(nil, { vim.json.encode({
  id = 1,
  status = "ok",
  payload = "ansi last good frame",
  url = "https://example.com/preserve-exit-frame",
  title = "Preserve Exit Frame",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title == "Preserve Exit Frame"
end), "test setup should render an ANSI frame before serve exit")
_G.nvim_browser_ansi_post_frame_exit_bufnr = terminal.state().bufnr
_G.nvim_browser_ansi_post_frame_exit_before = vim.api.nvim_buf_get_lines(
  _G.nvim_browser_ansi_post_frame_exit_bufnr,
  0,
  -1,
  false
)
serve_exit(nil, 5)
assert(vim.wait(1000, function()
  return terminal.state().mode == nil
end), "ANSI serve exit after a good frame should close the active serve state")
_G.nvim_browser_ansi_post_frame_exit_after = vim.api.nvim_buf_get_lines(
  _G.nvim_browser_ansi_post_frame_exit_bufnr,
  0,
  -1,
  false
)
assert(
  _G.nvim_browser_ansi_post_frame_exit_after[1] == _G.nvim_browser_ansi_post_frame_exit_before[1],
  "ANSI serve exit after a good frame should preserve the first rendered row"
)
_G.nvim_browser_ansi_post_frame_exit_text = table.concat(_G.nvim_browser_ansi_post_frame_exit_after, "\n")
assert(
  not _G.nvim_browser_ansi_post_frame_exit_text:find("Browser session exited: 5", 1, true),
  "ANSI serve exit after a good frame should not replace the preview body with the generic exit message"
)
assert(
  terminal.state().status_error == "browser exited 5",
  "ANSI serve exit after a good frame should keep the exit reason in status"
)

terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--markdown", "/tmp/post-frame-exit.md" })
serve_stdout(nil, { vim.json.encode({
  id = 1,
  status = "ok",
  payload = "markdown post-frame exit",
  url = "file:///tmp/nvbrowser-post-frame-exit-wrapper.html",
  display_url = "file:///tmp/post-frame-exit.md",
  title = "Post Frame Markdown",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title == "Post Frame Markdown"
end), "test setup should render a Markdown wrapper frame before serve exit")
serve_exit(nil, 6)
assert(vim.wait(1000, function()
  return terminal.state().mode == nil and terminal.state().serve_exit ~= nil
end), "Markdown post-frame serve exit should expose restart metadata")
jobstart_calls = {}
sent_requests = {}
assert(terminal.refresh() == true, "refresh after Markdown post-frame exit should restart the serve session")
assert(#jobstart_calls == 1, "Markdown post-frame exit refresh should start one replacement serve job")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--url") == nil, "Markdown post-frame exit refresh should not restart as a raw URL")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--markdown") == "/tmp/post-frame-exit.md", "Markdown post-frame exit refresh should preserve the Markdown wrapper target")

terminal.close()
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--markdown", "/tmp/post-frame-start.md" })
serve_stdout(nil, { vim.json.encode({
  id = 1,
  status = "ok",
  payload = "markdown navigated to image",
  url = "file:///tmp/nvbrowser-post-frame-image-wrapper.html",
  display_url = "file:///tmp/post-frame-exit.png",
  title = "Post Frame Image",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title == "Post Frame Image"
end), "test setup should render an image display URL from a Markdown-origin serve")
serve_exit(nil, 7)
assert(vim.wait(1000, function()
  return terminal.state().mode == nil and terminal.state().serve_exit ~= nil
end), "Markdown-to-image post-frame serve exit should expose restart metadata")
jobstart_calls = {}
assert(terminal.refresh() == true, "refresh after Markdown-to-image post-frame exit should restart the serve session")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--markdown") == nil, "Markdown-to-image restart should drop the old Markdown wrapper")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--image") == "/tmp/post-frame-exit.png", "Markdown-to-image restart should use an image wrapper")

terminal.close()
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--image", "/tmp/post-frame-start.png" })
serve_stdout(nil, { vim.json.encode({
  id = 1,
  status = "ok",
  payload = "image navigated to markdown",
  url = "file:///tmp/nvbrowser-post-frame-markdown-wrapper.html",
  display_url = "file:///tmp/post-frame-exit.md",
  title = "Post Frame Markdown From Image",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title == "Post Frame Markdown From Image"
end), "test setup should render a Markdown display URL from an image-origin serve")
serve_exit(nil, 8)
assert(vim.wait(1000, function()
  return terminal.state().mode == nil and terminal.state().serve_exit ~= nil
end), "Image-to-Markdown post-frame serve exit should expose restart metadata")
jobstart_calls = {}
assert(terminal.refresh() == true, "refresh after image-to-Markdown post-frame exit should restart the serve session")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--image") == nil, "image-to-Markdown restart should drop the old image wrapper")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--markdown") == "/tmp/post-frame-exit.md", "image-to-Markdown restart should use a Markdown wrapper")

terminal.close()
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com/post-frame-start" })
serve_stdout(nil, { vim.json.encode({
  id = 1,
  status = "ok",
  payload = "url navigated to markdown",
  url = "file:///tmp/nvbrowser-url-post-frame-markdown-wrapper.html",
  display_url = "file:///tmp/url-post-frame-exit.md",
  title = "URL Post Frame Markdown",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title == "URL Post Frame Markdown"
end), "test setup should render a Markdown display URL from a URL-origin serve")
serve_exit(nil, 9)
assert(vim.wait(1000, function()
  return terminal.state().mode == nil and terminal.state().serve_exit ~= nil
end), "URL-to-Markdown post-frame serve exit should expose restart metadata")
jobstart_calls = {}
assert(terminal.refresh() == true, "refresh after URL-to-Markdown post-frame exit should restart the serve session")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--url") == nil, "URL-to-Markdown restart should drop the old URL target")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--markdown") == "/tmp/url-post-frame-exit.md", "URL-to-Markdown restart should use a Markdown wrapper")

terminal.close()
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com/post-frame-image-start" })
serve_stdout(nil, { vim.json.encode({
  id = 1,
  status = "ok",
  payload = "url navigated to image",
  url = "file:///tmp/nvbrowser-url-post-frame-image-wrapper.html",
  display_url = "file:///tmp/url-post-frame-exit.png",
  title = "URL Post Frame Image",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title == "URL Post Frame Image"
end), "test setup should render an image display URL from a URL-origin serve")
serve_exit(nil, 10)
assert(vim.wait(1000, function()
  return terminal.state().mode == nil and terminal.state().serve_exit ~= nil
end), "URL-to-image post-frame serve exit should expose restart metadata")
jobstart_calls = {}
assert(terminal.refresh() == true, "refresh after URL-to-image post-frame exit should restart the serve session")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--url") == nil, "URL-to-image restart should drop the old URL target")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--image") == "/tmp/url-post-frame-exit.png", "URL-to-image restart should use an image wrapper")

terminal.close()
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com/reload-post-frame-start" })
serve_stdout(nil, { vim.json.encode({
  id = 1,
  status = "ok",
  payload = "reload URL post-frame exit",
  url = "https://example.com/reload-post-frame-next",
  title = "Reload Post Frame URL",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title == "Reload Post Frame URL"
end), "test setup should render a URL frame before reload post-frame exit")
serve_exit(nil, 11)
assert(vim.wait(1000, function()
  return terminal.state().mode == nil and terminal.state().serve_exit ~= nil
end), "URL reload post-frame serve exit should expose restart metadata")
jobstart_calls = {}
sent_requests = {}
assert(terminal.reload() == true, "reload after URL post-frame exit should restart the serve session")
assert(#jobstart_calls == 1, "URL post-frame exit reload should start one replacement serve job")
assert(
  _G.nvim_browser_command_option(jobstart_calls[1], "--url") == "https://example.com/reload-post-frame-next",
  "URL post-frame exit reload should target the last rendered URL"
)

terminal.close()
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--markdown", "/tmp/reload-post-frame-start.md" })
serve_stdout(nil, { vim.json.encode({
  id = 1,
  status = "ok",
  payload = "reload markdown post-frame exit",
  url = "file:///tmp/nvbrowser-reload-post-frame-markdown-wrapper.html",
  display_url = "file:///tmp/reload-post-frame-exit.md",
  title = "Reload Post Frame Markdown",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title == "Reload Post Frame Markdown"
end), "test setup should render a Markdown frame before reload post-frame exit")
serve_exit(nil, 12)
assert(vim.wait(1000, function()
  return terminal.state().mode == nil and terminal.state().serve_exit ~= nil
end), "Markdown reload post-frame serve exit should expose restart metadata")
jobstart_calls = {}
sent_requests = {}
assert(terminal.reload() == true, "reload after Markdown post-frame exit should restart the serve session")
assert(#jobstart_calls == 1, "Markdown post-frame exit reload should start one replacement serve job")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--url") == nil, "Markdown post-frame exit reload should not restart as a raw URL")
assert(
  _G.nvim_browser_command_option(jobstart_calls[1], "--markdown") == "/tmp/reload-post-frame-exit.md",
  "Markdown post-frame exit reload should preserve the Markdown wrapper target"
)

terminal.close()
terminal.open({
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--image-fit",
  "contain",
  "--url",
  "https://example.com/reload-post-frame-image-start",
})
serve_stdout(nil, { vim.json.encode({
  id = 1,
  status = "ok",
  payload = "reload URL to image post-frame exit",
  url = "file:///tmp/nvbrowser-reload-url-post-frame-image-wrapper.html",
  display_url = "file:///tmp/reload-url-post-frame-exit.png",
  title = "Reload URL Post Frame Image",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title == "Reload URL Post Frame Image"
end), "test setup should render an image display URL before reload post-frame exit")
serve_exit(nil, 13)
assert(vim.wait(1000, function()
  return terminal.state().mode == nil and terminal.state().serve_exit ~= nil
end), "URL-to-image reload post-frame serve exit should expose restart metadata")
jobstart_calls = {}
sent_requests = {}
assert(terminal.reload() == true, "reload after URL-to-image post-frame exit should restart the serve session")
assert(#jobstart_calls == 1, "URL-to-image post-frame exit reload should start one replacement serve job")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--url") == nil, "URL-to-image reload should drop the old URL target")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--image") == "/tmp/reload-url-post-frame-exit.png", "URL-to-image reload should use an image wrapper")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--image-fit") == "contain", "URL-to-image reload should preserve image fit")

terminal.close()
terminal.open({
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--image-fit",
  "contain",
  "--markdown",
  "/tmp/reload-markdown-post-frame-image-start.md",
})
serve_stdout(nil, { vim.json.encode({
  id = 1,
  status = "ok",
  payload = "reload Markdown to image post-frame exit",
  url = "file:///tmp/nvbrowser-reload-markdown-post-frame-image-wrapper.html",
  display_url = "file:///tmp/reload-markdown-post-frame-exit.png",
  title = "Reload Markdown Post Frame Image",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title == "Reload Markdown Post Frame Image"
end), "test setup should render an image display URL from a Markdown-origin serve before reload post-frame exit")
serve_exit(nil, 14)
assert(vim.wait(1000, function()
  return terminal.state().mode == nil and terminal.state().serve_exit ~= nil
end), "Markdown-to-image reload post-frame serve exit should expose restart metadata")
jobstart_calls = {}
sent_requests = {}
assert(terminal.reload() == true, "reload after Markdown-to-image post-frame exit should restart the serve session")
assert(#jobstart_calls == 1, "Markdown-to-image post-frame exit reload should start one replacement serve job")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--markdown") == nil, "Markdown-to-image reload should drop the old Markdown target")
assert(
  _G.nvim_browser_command_option(jobstart_calls[1], "--image") == "/tmp/reload-markdown-post-frame-exit.png",
  "Markdown-to-image reload should use an image wrapper"
)
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--image-fit") == "contain", "Markdown-to-image reload should preserve image fit")

terminal.close()
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com/reload-post-frame-markdown-start" })
serve_stdout(nil, { vim.json.encode({
  id = 1,
  status = "ok",
  payload = "reload URL to markdown post-frame exit",
  url = "file:///tmp/nvbrowser-reload-url-post-frame-markdown-wrapper.html",
  display_url = "file:///tmp/reload-url-post-frame-exit.md",
  title = "Reload URL Post Frame Markdown",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title == "Reload URL Post Frame Markdown"
end), "test setup should render a Markdown display URL before reload post-frame exit")
serve_exit(nil, 15)
assert(vim.wait(1000, function()
  return terminal.state().mode == nil and terminal.state().serve_exit ~= nil
end), "URL-to-Markdown reload post-frame serve exit should expose restart metadata")
jobstart_calls = {}
sent_requests = {}
assert(terminal.reload() == true, "reload after URL-to-Markdown post-frame exit should restart the serve session")
assert(#jobstart_calls == 1, "URL-to-Markdown post-frame exit reload should start one replacement serve job")
assert(_G.nvim_browser_command_option(jobstart_calls[1], "--url") == nil, "URL-to-Markdown reload should drop the old URL target")
assert(
  _G.nvim_browser_command_option(jobstart_calls[1], "--markdown") == "/tmp/reload-url-post-frame-exit.md",
  "URL-to-Markdown reload should use a Markdown wrapper"
)

local reused_bufnr = second_state.bufnr
terminal.open({ "nvbrowser", "show-image", "/tmp/image.png", "--output", "ansi" })
local replacement_state = terminal.state()
assert(#termopen_calls == 1, "non-serve previews should still replace an active serve session")
assert(replacement_state.bufnr ~= reused_bufnr, "non-serve previews should use a replacement buffer")

terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com/exit" })
terminal._test.clear_in_flight_capture()
local handler_count_before_failed_send = terminal._test.response_handler_count()
local original_active_chansend = vim.fn.chansend
vim.fn.chansend = function()
  return 0
end
assert(terminal.refresh() == false, "failed chansend should report refresh failure")
assert(terminal.state().live_refresh_request_id == nil, "failed chansend should not leave an in-flight capture")
assert(
  terminal._test.response_handler_count() == handler_count_before_failed_send,
  "failed chansend should not leak response handlers"
)
vim.fn.chansend = original_active_chansend

terminal._test.set_timer_factory(function()
  return nil
end)
terminal._test.apply_serve_response({
  id = 701,
  status = "ok",
  download = {
    path = "/tmp/nvbrowser-downloads/before-reset.txt",
    suggested_filename = "before-reset.txt",
    status = "completed",
  },
})
assert(#terminal.downloads() > 0, "test setup should have download history before opening a new serve session")
sent_requests = {}
assert(terminal.zoom_in() == true, "test setup should apply zoom before replacing a browser session")
local pre_replace_zoom_request = last_request_of_type("zoom")
terminal._test.dispatch_serve_response_handler({ id = pre_replace_zoom_request.id, status = "ok" })
terminal._test.clear_pending_operation(pre_replace_zoom_request.id)
assert(terminal.state().zoom_scale ~= 1.0, "test setup should have non-default zoom before opening a new serve session")
terminal.open({ "nvbrowser", "show-image", "/tmp/reset-downloads.png", "--output", "ansi" })
assert(#terminal.downloads() == 0, "replacing the active browser session should reset download history")
assert(terminal.state().zoom_scale == 1.0, "replacing the active browser session should reset zoom state")
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://e.co" })
terminal._test.clear_in_flight_capture()
sent_requests = {}
assert(terminal.zoom_in() == true, "test setup should apply zoom before normal serve job exit")
normal_exit_zoom_request = last_request_of_type("zoom")
serve_stdout(nil, { vim.json.encode({
  id = normal_exit_zoom_request.id,
  status = "ok",
}) .. "\n" })
assert(vim.wait(1000, function()
  return terminal.state().pending_operation == nil
end), "zoom response should clear the pending operation before normal serve job exit")
normal_exit_state = terminal.state()
normal_exit_lines = vim.api.nvim_buf_get_lines(normal_exit_state.bufnr, 0, -1, false)
assert(normal_exit_lines[#normal_exit_lines]:find("zoom=110%%"), "test setup should render zoom in the footer before normal serve job exit")
serve_exit(nil, 0)
assert(vim.wait(1000, function()
  return terminal.state().job_id == nil
end), "normal serve job exit should clear the active job")
normal_exit_lines = vim.api.nvim_buf_get_lines(normal_exit_state.bufnr, 0, -1, false)
assert(not normal_exit_lines[#normal_exit_lines]:find("zoom="), "normal serve job exit should redraw stale footer zoom state")
assert(terminal.state().zoom_scale == 1.0, "normal serve job exit should reset zoom state")
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com/no-scroll-timer" })
terminal._test.clear_in_flight_capture()
sent_requests = {}
assert(terminal.scroll(55, 0) == true, "scroll should still work when no timer can be created")
assert(#nvim_browser_requests_of_type("scroll") == 1, "scroll should send immediately without a coalescing timer")
assert(nvim_browser_requests_of_type("scroll")[1].delta_y == 55, "immediate scroll fallback should preserve deltas")

terminal._test.set_pending_operation({ id = 4, label = "loading", target = "https://example.com/crash" })
terminal._test.apply_serve_response({
  id = 703,
  status = "ok",
  download = {
    path = "/tmp/nvbrowser-downloads/before-exit.txt",
    suggested_filename = "before-exit.txt",
    status = "completed",
  },
  downloads = {
    {
      path = "/tmp/nvbrowser-downloads/before-exit.txt",
      suggested_filename = "before-exit.txt",
      status = "completed",
    },
    {
      path = "/tmp/nvbrowser-downloads/before-exit-2.txt",
      suggested_filename = "before-exit-2.txt",
      status = "completed",
    },
  },
})
assert(#terminal.downloads() == 2, "multi-download responses should record all completed downloads without duplicating the compatibility download")
assert(terminal.downloads()[2].suggested_filename == "before-exit-2.txt", "multi-download responses should preserve download order")
terminal._test.clear_pending_operation(4)

terminal._test.apply_serve_response({
  id = 704,
  status = "ok",
  dialog = {
    kind = "confirm",
    message = "continue?",
    action = "dismissed",
  },
  dialogs = {
    {
      kind = "confirm",
      message = "continue?",
      action = "dismissed",
    },
  },
})
assert(terminal.state().latest_dialog.kind == "confirm", "serve dialog responses should record the latest dialog")
assert(
  terminal._test.preview_footer_line(120):find("dialog=confirm dismissed: continue?", 1, true),
  "preview footer should show the latest auto-handled dialog"
)
sent_requests = {}
assert(terminal.zoom_in() == true, "test setup should apply zoom before serve job exit")
local pre_exit_zoom_request = last_request_of_type("zoom")
terminal._test.dispatch_serve_response_handler({ id = pre_exit_zoom_request.id, status = "ok" })
terminal._test.clear_pending_operation(pre_exit_zoom_request.id)
assert(terminal.state().zoom_scale ~= 1.0, "test setup should have non-default zoom before serve job exit")
assert(type(serve_exit) == "function", "serve jobstart should expose an exit callback in tests")
serve_exit(nil, 17)
assert(vim.wait(1000, function()
  return terminal.state().job_id == nil
end), "serve job exit should clear the active job")
assert(terminal.state().pending_operation == nil, "serve job exit should clear pending operations")
assert(terminal._test.response_handler_count() == 0, "serve job exit should clear response handlers")
assert(#terminal.downloads() == 0, "serve job exit should reset download history")
assert(terminal.state().zoom_scale == 1.0, "serve job exit should reset zoom state")

terminal._test.apply_serve_response({
  id = 702,
  status = "ok",
  download = {
    path = "/tmp/nvbrowser-downloads/before-close.txt",
    suggested_filename = "before-close.txt",
    status = "completed",
  },
})
assert(#terminal.downloads() > 0, "test setup should have download history before close")

_G.nvim_browser_old_page_text_reset_register = vim.fn.getreg("b")
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com/before-reset-page-text-yank" })
sent_requests = {}
assert(terminal.yank_page_text("b") == true, "test setup should send a first page text yank before session replacement")
assert(terminal.yank_page_text("b") == true, "test setup should send a newer page text yank before session replacement")
_G.nvim_browser_pre_reset_page_text_request = last_request_of_type("page_text")
assert(_G.nvim_browser_pre_reset_page_text_request.id > 1, "test setup should create a page text request id greater than one")
terminal.close()
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com/reset-page-text-yank" })
sent_requests = {}
vim.fn.setreg("b", "before reset page text")
assert(terminal.yank_page_text("b") == true, "page text yank should work after replacing the serve session")
_G.nvim_browser_reset_page_text_request = last_request_of_type("page_text")
assert(_G.nvim_browser_reset_page_text_request ~= nil, "page text yank after session replacement should send page_text")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_reset_page_text_request.id,
  status = "ok",
  text = {
    title = "Reset",
    url = "https://example.com/reset-page-text-yank",
    text = "fresh session page text",
    truncated = false,
  },
}), "" })
assert(vim.wait(1000, function()
  return vim.fn.getreg("b") == "fresh session page text"
end), "page text yank request ids should reset with new serve sessions")
vim.fn.setreg("b", _G.nvim_browser_old_page_text_reset_register)

sent_requests = {}
terminal.configure({ reader = { auto_open_on_ansi_fallback = true } })
terminal.close()
terminal.open({
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--url",
  "https://example.com/zellij-fallback",
  nvim_browser_output_label = "ANSI fallback",
})
serve_stdout(nil, { vim.json.encode({
  id = 1,
  status = "ok",
  payload = "ansi fallback frame",
  url = "https://example.com/zellij-fallback",
  title = "Zellij Fallback",
  runtime = interactive_runtime(450, 165),
}), "" })
assert(vim.wait(1000, function()
  return last_request_of_type("page_text") ~= nil
end), "ANSI fallback serve frames should automatically request reader page text: label="
  .. tostring(terminal.state().serve_output_label)
  .. " title="
  .. tostring(terminal.state().current_title)
  .. " auto="
  .. tostring(terminal.state().auto_reader_request_in_flight)
  .. "/"
  .. tostring(terminal.state().auto_reader_opened))
_G.nvim_browser_fallback_reader_request = last_request_of_type("page_text")
_G.nvim_browser_fallback_preview_win = terminal.state().winid
_G.nvim_browser_fallback_preview_buf = terminal.state().bufnr
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_fallback_reader_request.id,
  status = "ok",
  text = {
    title = "Zellij Fallback",
    url = "https://example.com/zellij-fallback",
    text = "# Zellij Fallback\n\nReadable fallback body",
    truncated = false,
  },
}), "" })
assert(vim.wait(1000, function()
  local reader_bufnr = terminal.state().reader_bufnr
  return reader_bufnr ~= nil
    and vim.api.nvim_buf_is_valid(reader_bufnr)
    and nvim_browser_buffer_text(reader_bufnr):match("Readable fallback body") ~= nil
end), "ANSI fallback page_text responses should open the reader buffer")
assert(
  vim.api.nvim_win_is_valid(_G.nvim_browser_fallback_preview_win)
    and vim.api.nvim_win_get_buf(_G.nvim_browser_fallback_preview_win) == _G.nvim_browser_fallback_preview_buf,
  "ANSI fallback reader auto-open should not replace the browser preview window"
)
_G.nvim_browser_fallback_reader_buf = terminal.state().reader_bufnr
_G.nvim_browser_fallback_reader_win_count = vim.fn.winnr("$")
_G.nvim_browser_fallback_current_win = vim.api.nvim_get_current_win()

sent_requests = {}
serve_stdout(nil, { vim.json.encode({
  id = 3,
  status = "ok",
  payload = "ansi fallback frame after navigation",
  url = "https://example.com/zellij-fallback/next",
  title = "Zellij Fallback Next",
  runtime = interactive_runtime(450, 165),
}), "" })
assert(vim.wait(1000, function()
  return last_request_of_type("page_text") ~= nil
end), "ANSI fallback reader should refresh page_text after a later successful frame")
_G.nvim_browser_fallback_refresh_request = last_request_of_type("page_text")
assert(
  _G.nvim_browser_fallback_refresh_request.id ~= _G.nvim_browser_fallback_reader_request.id,
  "ANSI fallback reader refresh should use a fresh request id"
)
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_fallback_refresh_request.id,
  status = "ok",
  text = {
    title = "Zellij Fallback Next",
    url = "https://example.com/zellij-fallback/next",
    text = "# Zellij Fallback Next\n\nRefreshed fallback body",
    truncated = false,
  },
}), "" })
assert(vim.wait(1000, function()
  local reader_bufnr = terminal.state().reader_bufnr
  return reader_bufnr == _G.nvim_browser_fallback_reader_buf
    and vim.api.nvim_buf_is_valid(reader_bufnr)
    and nvim_browser_buffer_text(reader_bufnr):match("Refreshed fallback body") ~= nil
end), "ANSI fallback reader refresh responses should update the existing reader buffer")
assert(
  vim.fn.winnr("$") == _G.nvim_browser_fallback_reader_win_count,
  "ANSI fallback reader refresh should not open additional reader splits"
)
assert(
  vim.api.nvim_get_current_win() == _G.nvim_browser_fallback_current_win,
  "ANSI fallback reader refresh should not steal focus"
)

sent_requests = {}
serve_stdout(nil, { vim.json.encode({
  id = 5,
  status = "ok",
  payload = "ansi fallback frame with pending reader refresh",
  url = "https://example.com/zellij-fallback/pending",
  title = "Zellij Fallback Pending",
  runtime = interactive_runtime(450, 165),
}), "" })
assert(vim.wait(1000, function()
  return last_request_of_type("page_text") ~= nil
end), "ANSI fallback reader should request refresh page_text before testing duplicate suppression")
_G.nvim_browser_fallback_pending_refresh_request = last_request_of_type("page_text")
serve_stdout(nil, { vim.json.encode({
  id = 6,
  status = "ok",
  payload = "ansi fallback frame while reader refresh is pending",
  url = "https://example.com/zellij-fallback/pending-second",
  title = "Zellij Fallback Pending Second",
  runtime = interactive_runtime(450, 165),
}), "" })
vim.wait(100)
assert(
  #nvim_browser_requests_of_type("page_text") == 1,
  "ANSI fallback reader should not send duplicate refresh requests while one is in flight"
)
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_fallback_pending_refresh_request.id,
  status = "error",
  error = "page text refresh failed",
}), "" })
assert(
  terminal.state().reader_bufnr == _G.nvim_browser_fallback_reader_buf
    and vim.api.nvim_buf_is_valid(_G.nvim_browser_fallback_reader_buf)
    and nvim_browser_buffer_text(_G.nvim_browser_fallback_reader_buf):match("Refreshed fallback body") ~= nil,
  "ANSI fallback reader refresh failures should preserve the existing reader buffer"
)

sent_requests = {}
serve_stdout(nil, { vim.json.encode({
  id = 8,
  status = "ok",
  payload = "ansi fallback frame with empty reader refresh",
  url = "https://example.com/zellij-fallback/empty-refresh",
  title = "Zellij Fallback Empty Refresh",
  runtime = interactive_runtime(450, 165),
}), "" })
assert(vim.wait(1000, function()
  return last_request_of_type("page_text") ~= nil
end), "ANSI fallback reader should request refresh page_text before testing empty snapshot preservation")
_G.nvim_browser_fallback_empty_refresh_request = last_request_of_type("page_text")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_fallback_empty_refresh_request.id,
  status = "ok",
  text = {
    title = "Zellij Fallback Empty Refresh",
    url = "https://example.com/zellij-fallback/empty-refresh",
    text = "",
    truncated = false,
  },
}), "" })
assert(
  terminal.state().reader_bufnr == _G.nvim_browser_fallback_reader_buf
    and vim.api.nvim_buf_is_valid(_G.nvim_browser_fallback_reader_buf)
    and nvim_browser_buffer_text(_G.nvim_browser_fallback_reader_buf):match("Refreshed fallback body") ~= nil,
  "ANSI fallback reader empty refresh snapshots should preserve the existing reader buffer"
)

sent_requests = {}
serve_stdout(nil, { vim.json.encode({
  id = 10,
  status = "ok",
  payload = "ansi fallback frame before manual reader",
  url = "https://example.com/zellij-fallback/manual-reader",
  title = "Zellij Fallback Manual Reader",
  runtime = interactive_runtime(450, 165),
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().auto_reader_request_in_flight == true and last_request_of_type("page_text") ~= nil
end), "ANSI fallback reader should have an auto refresh in flight before testing manual reader separation")
_G.nvim_browser_auto_before_manual_reader_request = last_request_of_type("page_text")
assert(terminal.reader() == true, "manual reader should still be allowed while an auto refresh was pending")
_G.nvim_browser_manual_reader_request = last_request_of_type("page_text")
assert(
  _G.nvim_browser_manual_reader_request.id ~= _G.nvim_browser_auto_before_manual_reader_request.id,
  "manual reader should use a distinct page_text request id"
)
assert(
  terminal.state().auto_reader_request_in_flight == false and terminal.state().auto_reader_request_id == nil,
  "manual reader should clear pending auto reader bookkeeping"
)
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_manual_reader_request.id,
  status = "error",
  error = "manual reader failed",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().reader_bufnr == nil or not vim.api.nvim_buf_is_valid(_G.nvim_browser_fallback_reader_buf)
end), "manual reader failures should keep the existing failure semantics instead of being treated as auto refresh failures")

sent_requests = {}
terminal.close()
terminal.open({
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--url",
  "https://example.com/zellij-fallback-retry",
  nvim_browser_output_label = "ANSI fallback",
})
serve_stdout(nil, { vim.json.encode({
  id = 1,
  status = "ok",
  payload = "ansi fallback retry frame",
  url = "https://example.com/zellij-fallback-retry",
  title = "Zellij Fallback Retry",
  runtime = interactive_runtime(450, 165),
}), "" })
assert(vim.wait(1000, function()
  return last_request_of_type("page_text") ~= nil
end), "ANSI fallback should request page_text before testing retry")
_G.nvim_browser_failed_fallback_reader_request = last_request_of_type("page_text")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_failed_fallback_reader_request.id,
  status = "error",
  error = "page text not ready",
}), "" })
sent_requests = {}
serve_stdout(nil, { vim.json.encode({
  id = 3,
  status = "ok",
  payload = "ansi fallback retry second frame",
  url = "https://example.com/zellij-fallback-retry",
  title = "Zellij Fallback Retry",
  runtime = interactive_runtime(450, 165),
}), "" })
assert(vim.wait(1000, function()
  local request = last_request_of_type("page_text")
  return request ~= nil and request.id ~= _G.nvim_browser_failed_fallback_reader_request.id
end), "ANSI fallback reader auto-open should retry after failed page_text snapshots")

sent_requests = {}
terminal.close()
terminal.open({
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--url",
  "https://example.com/zellij-fallback-empty-retry",
  nvim_browser_output_label = "ANSI fallback",
})
serve_stdout(nil, { vim.json.encode({
  id = 1,
  status = "ok",
  payload = "ansi fallback empty retry frame",
  url = "https://example.com/zellij-fallback-empty-retry",
  title = "Zellij Fallback Empty Retry",
  runtime = interactive_runtime(450, 165),
}), "" })
assert(vim.wait(1000, function()
  return last_request_of_type("page_text") ~= nil
end), "ANSI fallback should request page_text before testing empty snapshot retry")
_G.nvim_browser_empty_fallback_reader_request = last_request_of_type("page_text")
serve_stdout(nil, { vim.json.encode({
  id = _G.nvim_browser_empty_fallback_reader_request.id,
  status = "ok",
  text = {
    title = "Zellij Fallback Empty Retry",
    url = "https://example.com/zellij-fallback-empty-retry",
    text = "",
    truncated = false,
  },
}), "" })
sent_requests = {}
serve_stdout(nil, { vim.json.encode({
  id = 3,
  status = "ok",
  payload = "ansi fallback empty retry second frame",
  url = "https://example.com/zellij-fallback-empty-retry",
  title = "Zellij Fallback Empty Retry",
  runtime = interactive_runtime(450, 165),
}), "" })
assert(vim.wait(1000, function()
  local request = last_request_of_type("page_text")
  return request ~= nil and request.id ~= _G.nvim_browser_empty_fallback_reader_request.id
end), "ANSI fallback reader auto-open should retry after empty page_text snapshots")

sent_requests = {}
terminal.close()
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--url", "https://example.com/plain-ansi" })
serve_stdout(nil, { vim.json.encode({
  id = 1,
  status = "ok",
  payload = "plain ansi frame",
  url = "https://example.com/plain-ansi",
  title = "Plain ANSI",
  runtime = interactive_runtime(450, 165),
}), "" })
vim.wait(100)
assert(last_request_of_type("page_text") == nil, "plain ANSI serve frames should not auto-open reader")

sent_requests = {}
terminal.configure({ reader = { auto_open_on_ansi_fallback = false } })
terminal.close()
terminal.open({
  "nvbrowser",
  "serve",
  "--output",
  "ansi",
  "--url",
  "https://example.com/zellij-fallback-disabled",
  nvim_browser_output_label = "ANSI fallback",
})
serve_stdout(nil, { vim.json.encode({
  id = 1,
  status = "ok",
  payload = "disabled fallback frame",
  url = "https://example.com/zellij-fallback-disabled",
  title = "Disabled Fallback",
  runtime = interactive_runtime(450, 165),
}), "" })
vim.wait(100)
assert(last_request_of_type("page_text") == nil, "disabled ANSI fallback reader option should suppress auto-open")
terminal.configure({ reader = { auto_open_on_ansi_fallback = true } })

terminal._test.set_timer_factory(nil)
vim.fn.jobstart = original_jobstart
vim.fn.chansend = original_chansend
vim.fn.jobstop = original_jobstop
vim.fn.termopen = original_termopen
terminal.close()
assert(#terminal.downloads() == 0, "closing the browser should reset download history")

vim.api.nvim_chan_send = original_nvim_chan_send
vim.api.nvim_echo = original_echo
