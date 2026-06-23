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
    protocol_version = 8,
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
assert(runtime_info.protocol_version == 8, "runtime metadata should preserve protocol version")
assert(runtime_info.output == "kitty-unicode", "runtime metadata should preserve output mode")
assert(runtime_info.cells.columns == 80, "runtime metadata should preserve preview columns")
assert(runtime_info.viewport.width == 800, "runtime metadata should preserve viewport width")
terminal._test.apply_serve_response({
  id = 100,
  status = "ok",
  payload = "runtime frame",
  runtime = {
    protocol_version = 8,
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
terminal.close()
assert(terminal.state().page_metrics == nil, "closing a browser session should clear page metrics")
assert(terminal.state().runtime_metadata == nil, "closing a browser session should clear runtime metadata")
assert(terminal.state().rendered_frame_geometry == nil, "closing a browser session should clear rendered frame geometry")
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
    text = "# Reader Base\n\n[Docs](/docs)\n\n[Next](guide/page.html)\n\n[Section](#intro)\n\n[Search](?q=x)",
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
assert(terminal.reader_follow() == "https://example.com/base/current.html#intro", "reader follow should resolve fragments from the current page")
vim.api.nvim_win_set_cursor(0, { 11, 1 })
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
assert(reader_requests[3].request.url == "https://example.com/base/current.html#intro", "fragment follow should send the resolved URL")
assert(reader_requests[4].request.url == "https://example.com/base/current.html?q=x", "query-only follow should send the resolved URL")
assert(reader_requests[5].request.url == "https://example.com/base/guide/page.html", "old reader buffers should keep using their snapshot URL as base")

terminal._test.apply_serve_response({
  id = 224,
  status = "ok",
  url = "file:///tmp/site/index.html",
  title = "Local Reader",
})
terminal._test.handle_reader_response({
  status = "ok",
  text = {
    title = "Local Reader",
    url = "file:///tmp/site/index.html",
    text = "# Local Reader\n\n[Next](guide/page.html)\n\n[Docs](/docs)\n\n[Section](#intro)\n\n[Search](?q=x)",
  },
})
vim.api.nvim_set_current_buf(terminal.state().reader_bufnr)
reader_requests = {}
vim.fn.chansend = function(job_id, payload)
  table.insert(reader_requests, { job_id = job_id, request = vim.json.decode(payload) })
  return 1
end
vim.api.nvim_win_set_cursor(0, { 5, 1 })
assert(terminal.reader_follow() == "file:///tmp/site/guide/page.html", "reader follow should resolve relative file links from the reader snapshot")
vim.api.nvim_win_set_cursor(0, { 7, 1 })
assert(terminal.reader_follow() == "file:///docs", "reader follow should resolve root-relative file links")
vim.api.nvim_win_set_cursor(0, { 9, 1 })
assert(terminal.reader_follow() == "file:///tmp/site/index.html#intro", "reader follow should resolve file fragments")
vim.api.nvim_win_set_cursor(0, { 11, 1 })
assert(terminal.reader_follow() == "file:///tmp/site/index.html?q=x", "reader follow should resolve file query-only links")
vim.fn.chansend = original_chansend_for_reader

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
terminal._test.apply_serve_response({
  id = 200,
  status = "ok",
  payload = "interactive frame",
  runtime = {
    protocol_version = 8,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "kitty-unicode",
    cells = { columns = 50, rows = 11 },
    viewport = { width = 450, height = 165, device_scale_factor = 1 },
  },
})
local footer_click_requests = {}
local original_chansend_for_footer = vim.fn.chansend
vim.fn.chansend = function(job_id, payload)
  table.insert(footer_click_requests, { job_id = job_id, payload = payload })
  return 1
end

local function interactive_runtime(width, height)
  return {
    protocol_version = 8,
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
for _, request in ipairs(footer_click_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "click_point" and decoded.x == expected_mouse_point.x and decoded.y == expected_mouse_point.y then
    mouse_click_seen = true
    mouse_click_request_id = decoded.id
  end
end
assert(mouse_click_seen, "mouse click should map preview cells to viewport pixels")
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
assert(terminal.wheel_mouse(120, 0, { winid = image_win, line = 6, column = 25 }) == true, "mouse wheel should send a browser wheel")
local mouse_wheel_seen = false
local mouse_wheel_request_id = nil
for _, request in ipairs(footer_click_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if
    ok
    and decoded.type == "wheel_point"
    and decoded.x == expected_mouse_point.x
    and decoded.y == expected_mouse_point.y
    and decoded.delta_y == 120
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
terminal.configure({
  viewport = {
    cell_width_px = 10,
    cell_height_px = 20,
  },
})
assert(terminal.click_here() == false, "stale rendered frame geometry should block cursor click")
assert(terminal.hover_here() == false, "stale rendered frame geometry should block cursor hover")
assert(terminal.type_here("stale text") == false, "stale rendered frame geometry should block cursor typing")
assert(terminal.click_mouse({ winid = image_win, line = 6, column = 25 }) == false, "stale rendered frame geometry should block mouse click")
assert(terminal.wheel_mouse(120, 0, { winid = image_win, line = 6, column = 25 }) == false, "stale rendered frame geometry should block mouse wheel")
local stale_resize_seen = false
local stale_point_seen = false
for _, request in ipairs(footer_click_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "resize" then
    stale_resize_seen = true
  end
  if ok and (decoded.type == "click_point" or decoded.type == "hover_point" or decoded.type == "type_point" or decoded.type == "wheel_point") then
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
    protocol_version = 8,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "kitty-unicode",
    cells = { columns = 50, rows = 11 },
    viewport = { width = 500, height = 220, device_scale_factor = 1 },
  },
})
assert(terminal.click_here() == true, "matching refreshed frame geometry should allow cursor click again")

footer_click_requests = {}
terminal._test.apply_serve_response({
  id = 202,
  status = "ok",
  payload = "column guard frame",
  runtime = {
    protocol_version = 8,
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
assert(terminal.hover_here() == false, "cursor hover beyond rendered columns should be ignored")
assert(terminal.type_here("outside") == false, "cursor typing beyond rendered columns should be ignored")
assert(#footer_click_requests == 0, "out-of-column cursor actions should not reach the serve backend")

footer_click_requests = {}
assert(terminal.click_mouse({ winid = image_win, line = 6, column = 51 }) == false, "mouse click beyond rendered columns should be ignored")
assert(terminal.wheel_mouse(120, 0, { winid = image_win, line = 6, column = 51 }) == false, "mouse wheel beyond rendered columns should be ignored")
assert(#footer_click_requests == 0, "out-of-column mouse clicks should not reach the serve backend")

footer_click_requests = {}
assert(terminal.click_mouse({ winid = image_win, line = 12, column = 25 }) == false, "mouse click on footer should be ignored")
assert(terminal.wheel_mouse(120, 0, { winid = image_win, line = 12, column = 25 }) == false, "mouse wheel on footer should be ignored")
assert(#footer_click_requests == 0, "footer mouse clicks should not reach the serve backend")

footer_click_requests = {}
assert(terminal.click_mouse({ winid = second_bufnr, line = 6, column = 25 }) == false, "mouse click from another window should be ignored")
assert(terminal.wheel_mouse(120, 0, { winid = second_bufnr, line = 6, column = 25 }) == false, "mouse wheel from another window should be ignored")
assert(#footer_click_requests == 0, "wrong-window mouse clicks should not reach the serve backend")

vim.api.nvim_win_set_cursor(image_win, { 12, 0 })
assert(terminal.click_here() == false, "clicking the footer row should not send a browser click")
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
local function last_request_of_type(kind)
  for index = #sent_requests, 1, -1 do
    local ok, decoded = pcall(vim.json.decode, sent_requests[index].payload)
    if ok and decoded.type == kind then
      return decoded
    end
  end
  return nil
end

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

sent_requests = {}
assert(terminal.yank_selection("ab") == false, "selection yank should reject invalid register names")
assert(#sent_requests == 0, "invalid selection yank registers should not send a serve request")

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

warnings = {}
sent_requests = {}
assert(terminal.yank_selection(":") == true, "one-character invalid registers should be handled by the response path")
selection_request = last_request_of_type("selection_text")
local invalid_register_ok, invalid_register_error = pcall(serve_stdout, nil, { vim.json.encode({
  id = selection_request.id,
  status = "ok",
  selection = "cannot write here",
}), "" })
assert(invalid_register_ok, "invalid writable registers should not throw from the async response handler: " .. tostring(invalid_register_error))
assert(vim.wait(1000, function()
  return #warnings > 0
end), "invalid writable registers should warn after the response")
assert(warnings[#warnings] == "nvim-browser: browser selection yank failed or no browser selection is active", "invalid writable register should use the expected warning")

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
assert(terminal.click_point(12, 24) == true, "point click should work while live refresh is enabled")
local point_click_pending_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(point_click_pending_id ~= nil, "point click should mark the browser click as pending")
sent_requests = {}
fake_timers[1].callback()
local live_capture_during_click_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "capture" then
    live_capture_during_click_seen = true
  end
end
assert(not live_capture_during_click_seen, "live refresh should not capture while a click is pending")
terminal._test.clear_pending_operation(point_click_pending_id)

terminal._test.apply_serve_response({
  id = live_capture_id,
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
local page_down_request = last_request_of_type("scroll")
assert(page_down_request ~= nil, "page_scroll should reuse the scroll JSONL request type")
assert(page_down_request.delta_y == 540, "page_scroll should use 90 percent of page viewport height")
assert(page_down_request.delta_x == 0, "page_scroll should not scroll horizontally by default")

sent_requests = {}
assert(terminal.page_scroll(-1) == true, "page_scroll should support backward scrolling")
local page_up_request = last_request_of_type("scroll")
assert(page_up_request ~= nil, "backward page_scroll should send a scroll request")
assert(page_up_request.delta_y == -540, "backward page_scroll should negate the viewport-based delta")

terminal._test.apply_serve_response({
  id = live_capture_id + 1,
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
local runtime_page_request = last_request_of_type("scroll")
assert(runtime_page_request.delta_y == 450, "runtime viewport fallback should handle invalid page metrics")

terminal._test.apply_serve_response({ id = live_capture_id + 2, status = "ok", runtime = {} })
sent_requests = {}
assert(terminal.page_scroll(1) == true, "page_scroll should fall back when no metadata exists")
local fallback_page_request = last_request_of_type("scroll")
assert(fallback_page_request.delta_y == 400, "page_scroll should preserve the existing 400px fallback")

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

sent_requests = {}
assert(terminal.navigate("https://example.com/older") == true, "test setup should send an older navigation")
local older_navigation_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(older_navigation_id ~= nil, "older navigation should be tracked as pending")
sent_requests = {}
assert(terminal.navigate("https://example.com/newer") == true, "test setup should send a newer navigation")
local newer_navigation_id = terminal.state().pending_operation and terminal.state().pending_operation.id
assert(newer_navigation_id ~= nil and newer_navigation_id ~= older_navigation_id, "newer navigation should replace older pending operation")
serve_stdout(nil, { vim.json.encode({
  id = older_navigation_id,
  status = "ok",
  payload = "older navigation frame",
  url = "https://example.com/older",
  title = "Older Navigation",
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
assert(#terminal.state().element_hints == 0, "late older navigation response should not replace active hints")
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

sent_requests = {}
assert(terminal.find_next() == true, "find_next should repeat the stored query forward")
local repeat_forward_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "find_text" then
    repeat_forward_seen = decoded.query == "needle" and decoded.backwards == false
  end
end
assert(repeat_forward_seen, "find_next should send the stored query with forward direction")

sent_requests = {}
assert(terminal.find_previous() == true, "find_previous should repeat the stored query backward")
local repeat_backward_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "find_text" then
    repeat_backward_seen = decoded.query == "needle" and decoded.backwards == true
  end
end
assert(repeat_backward_seen, "find_previous should send the stored query with backward direction")

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
  id = older_find_id,
  status = "ok",
  found = true,
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().last_find_found == true
end), "older handler-only find response should still update find status after newer render response")
assert(terminal.state().current_title == "After Find Navigation", "older find response should not overwrite current browser metadata")

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
local fallback_click_hint_seen = false
local fallback_click_point_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "click_hint" and decoded.hint_id == 2 then
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
local type_hints_response = vim.json.decode(hints_response)
type_hints_response.id = direct_click_pending_id + 1
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
local live_hint_response = vim.json.decode(hints_response)
live_hint_response.id = type_hint_pending_id + 1
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
assert(#terminal.state().element_hints == 0, "non-submit type_hint should clear stale hints while a capture is pending")
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
assert(#terminal.state().element_hints == 0, "select_hint should clear stale hints while a capture is pending")
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
local hover_hints_response = vim.json.decode(hints_response)
hover_hints_response.id = select_hint_pending_id + 1
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
local resize_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "resize" then
    resize_seen = true
  end
end
assert(resize_seen, "active serve sessions should resize when Neovim is resized")

sent_requests = {}
assert(terminal.refresh() == true, "test setup should create an in-flight capture before resize")
local stale_before_resize_capture_id = terminal.state().live_refresh_request_id
assert(stale_before_resize_capture_id ~= nil, "test setup should track capture before resize")
sent_requests = {}
vim.cmd("doautocmd WinResized")
local resize_after_capture_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "resize" then
    resize_after_capture_seen = true
  end
end
assert(resize_after_capture_seen, "resize should still be sent while a capture is in flight")
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
local win_resize_seen = false
for _, request in ipairs(sent_requests) do
  local ok, decoded = pcall(vim.json.decode, request.payload)
  if ok and decoded.type == "resize" then
    win_resize_seen = true
  end
end
assert(win_resize_seen, "active serve sessions should resize when the preview window changes size")

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
assert(table.concat(text_mode_text, ",") == "h:false,i:false", "browser text mode should send printable keys as quiet text_input")
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
terminal.open({ "nvbrowser", "serve", "--output", "ansi", "--markdown", "/tmp/quiet-reset.md" })
sent_requests = {}
assert(terminal.refresh() == true, "new serve session should be able to request capture")
serve_stdout(nil, { vim.json.encode({
  id = terminal.state().live_refresh_request_id,
  status = "ok",
  payload = "fresh frame after quiet reset",
  url = "https://example.com/quiet-reset",
  title = "Quiet Reset",
}), "" })
assert(vim.wait(1000, function()
  return terminal.state().current_title == "Quiet Reset"
end), "new serve responses should not be suppressed by stale quiet request ids")
terminal._test.clear_in_flight_capture()

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
