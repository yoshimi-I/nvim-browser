local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local terminal = require("nvim-browser.terminal")

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

vim.api.nvim_echo = original_echo
