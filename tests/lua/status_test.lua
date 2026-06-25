local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local status = require("nvim-browser.status")

assert(type(status.focused_element_label) == "function", "focused element status label API should exist")

assert(
  status.focused_element_label({ kind = "input", label = "  Search\n\tbox  " }) == "focus=input Search box",
  "focused labels should be whitespace-normalized"
)

assert(
  status.focused_element_label({ kind = "text_area", label = "Comment" }) == "focus=textarea Comment",
  "focused text_area kind should be displayed as textarea"
)

assert(
  status.focused_element_label({ kind = "input", value = "draft" }) == "focus=input",
  "focused labels should not expose raw field values when no readable label exists"
)

assert(
  status.focused_element_label({ kind = "checkbox", label = "Newsletter", checked = true }) == "focus=checkbox Newsletter checked",
  "focused checkbox labels should include checked state"
)

assert(
  status.focused_element_label({ kind = "radio", label = "Plan", checked = false }) == "focus=radio Plan unchecked",
  "focused radio labels should include unchecked state"
)

local long_value = string.rep("x", 80)
local long_label = status.focused_element_label({ kind = "input", value = long_value }, { max_detail_chars = 16 })
assert(long_label == "focus=input", "focused value hints should be omitted")
assert(not long_label:find(long_value, 1, true), "focused labels should not dump long raw values")

local long_checkbox = status.focused_element_label({
  kind = "checkbox",
  label = "Very long newsletter preference label",
  checked = true,
}, { max_detail_chars = 16 })
assert(long_checkbox == "focus=checkbox Very long new... checked", "focused checked state should survive label truncation")

assert(status.focused_element_label({ kind = "" }) == nil, "focused labels should reject empty element kinds")
assert(status.focused_element_label(vim.NIL) == nil, "focused labels should reject null focused metadata")
