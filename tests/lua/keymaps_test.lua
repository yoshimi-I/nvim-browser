local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local keymaps = require("nvim-browser.keymaps")

local calls = {}
local browser = {
  reload = function()
    table.insert(calls, "reload")
  end,
  back = function()
    table.insert(calls, "back")
  end,
  forward = function()
    table.insert(calls, "forward")
  end,
  scroll = function(delta_y, delta_x)
    table.insert(calls, "scroll:" .. tostring(delta_y) .. ":" .. tostring(delta_x))
  end,
  address = function()
    table.insert(calls, "address")
  end,
  find_text = function(query)
    table.insert(calls, "find:" .. query)
    return true
  end,
  hint_mode = function()
    table.insert(calls, "hints")
  end,
  type_hint_mode = function(input, opts)
    local value = input("nvim-browser text: ")
    local suffix = opts ~= nil and opts.submit == true and ":submit" or ":type"
    table.insert(calls, "type_hints" .. suffix .. ":" .. value)
  end,
  input_text_mode = function(input)
    table.insert(calls, "input_mode:" .. input("nvim-browser text: "))
  end,
  start_text_mode = function()
    table.insert(calls, "text_mode")
    return true
  end,
  press_key = function(key, opts)
    local modifiers = opts ~= nil and opts.modifiers ~= nil and table.concat(opts.modifiers, "+") or ""
    table.insert(calls, "key:" .. key .. ":" .. modifiers)
  end,
  click_mouse = function()
    table.insert(calls, "click_mouse")
  end,
  hover_here = function()
    table.insert(calls, "hover_here")
  end,
  stop = function()
    table.insert(calls, "stop")
  end,
  close = function()
    table.insert(calls, "close")
  end,
}

local function mapping(lhs)
  return vim.fn.maparg(lhs, "n", false, true)
end

local function buffer_mapping(bufnr, lhs)
  return vim.api.nvim_buf_call(bufnr, function()
    return vim.fn.maparg(lhs, "n", false, true)
  end)
end

local function assert_no_mapping(lhs, message)
  assert(mapping(lhs).lhs == nil, message)
end

local function assert_mapping(lhs, message)
  assert(mapping(lhs).lhs ~= nil, message)
end

local function assert_no_buffer_mapping(bufnr, lhs, message)
  assert(buffer_mapping(bufnr, lhs).lhs == nil, message)
end

local function assert_buffer_mapping(bufnr, lhs, message)
  local item = buffer_mapping(bufnr, lhs)
  assert(item.lhs ~= nil and item.buffer == 1, message)
end

local function trigger(lhs)
  local callback = mapping(lhs).callback
  assert(type(callback) == "function", "mapping should install a Lua callback for " .. lhs)
  callback()
end

local function trigger_buffer(bufnr, lhs)
  local callback = buffer_mapping(bufnr, lhs).callback
  assert(type(callback) == "function", "buffer mapping should install a Lua callback for " .. lhs)
  callback()
end

keymaps.setup(browser, {
  enabled = false,
  prefix = "<leader>x",
})
assert_no_mapping("\\xr", "disabled keymaps should not install reload mapping")

keymaps.setup(browser, {
  enabled = true,
  prefix = "<leader>x",
  scroll_pixels = 250,
  input = function(prompt)
    if prompt == "nvim-browser find: " then
      return "needle"
    end
    assert(prompt == "nvim-browser text: ", "hinted input mapping should pass the configured input function")
    return "global text"
  end,
})

assert_mapping("\\xr", "enabled keymaps should install reload mapping")
assert_mapping("\\xh", "enabled keymaps should install back mapping")
assert_mapping("\\xl", "enabled keymaps should install forward mapping")
assert_mapping("\\xj", "enabled keymaps should install scroll-down mapping")
assert_mapping("\\xk", "enabled keymaps should install scroll-up mapping")
assert_mapping("\\xa", "enabled keymaps should install address mapping")
assert_mapping("\\x/", "enabled keymaps should install find mapping")
assert_mapping("\\xf", "enabled keymaps should install hint mapping")
assert_mapping("\\xt", "enabled keymaps should install hinted input mapping")
assert_mapping("\\xs", "enabled keymaps should install hinted submit mapping")

trigger("\\xr")
trigger("\\xh")
trigger("\\xl")
trigger("\\xj")
trigger("\\xk")
trigger("\\xa")
trigger("\\x/")
trigger("\\xf")
trigger("\\xt")
trigger("\\xs")

assert(
  table.concat(calls, ",")
    == "reload,back,forward,scroll:250:0,scroll:-250:0,address,find:needle,hints,type_hints:type:global text,type_hints:submit:global text",
  "keymaps should call browser APIs"
)

keymaps.setup(browser, {
  enabled = true,
  prefix = "<leader>z",
  mappings = {
    reload = "R",
    forward = false,
    scroll_down = "<C-d>",
    type_hint_mode = "i",
    submit_hint_mode = false,
  },
})

assert_no_mapping("\\xr", "re-running setup should remove previously installed mappings")
assert_mapping("\\zR", "custom mapping should be installed")
assert_no_mapping("\\zl", "false custom mapping should disable the default mapping")
assert_mapping("\\z<C-d>", "custom scroll mapping should be installed")
assert_mapping("\\zi", "custom hinted input mapping should be installed")
assert_no_mapping("\\zs", "false hinted submit mapping should disable the default mapping")

vim.keymap.set("n", "\\yt", function()
  table.insert(calls, "existing")
end, {})
keymaps.setup(browser, {
  enabled = true,
  prefix = "<leader>y",
  mappings = {
    reload = "t",
  },
})
trigger("\\yt")
assert(calls[#calls] == "existing", "keymaps should not overwrite existing user mappings")

vim.keymap.set("n", "\\zR", function()
  table.insert(calls, "replacement")
end, {})
keymaps.setup(browser, {
  enabled = false,
})
trigger("\\zR")
assert(calls[#calls] == "replacement", "disabling keymaps should not delete mappings replaced by another owner")

local first_bufnr = vim.api.nvim_create_buf(false, true)
local second_bufnr = vim.api.nvim_create_buf(false, true)
keymaps.setup_buffer(browser, first_bufnr, {
  enabled = true,
  scroll_pixels = 120,
  input = function(prompt)
    if prompt == "nvim-browser find: " then
      return "local"
    end
    assert(prompt == "nvim-browser text: ", "buffer hinted input mapping should pass the configured input function")
    return "buffer text"
  end,
})

assert_buffer_mapping(first_bufnr, "r", "buffer-local controls should install reload mapping")
assert_buffer_mapping(first_bufnr, "H", "buffer-local controls should install back mapping")
assert_buffer_mapping(first_bufnr, "L", "buffer-local controls should install forward mapping")
assert_buffer_mapping(first_bufnr, "j", "buffer-local controls should install scroll-down mapping")
assert_buffer_mapping(first_bufnr, "k", "buffer-local controls should install scroll-up mapping")
assert_buffer_mapping(first_bufnr, "a", "buffer-local controls should install address mapping")
assert_buffer_mapping(first_bufnr, "/", "buffer-local controls should install find mapping")
assert_buffer_mapping(first_bufnr, "f", "buffer-local controls should install hint mapping")
assert_buffer_mapping(first_bufnr, "t", "buffer-local controls should install hinted input mapping")
assert_buffer_mapping(first_bufnr, "s", "buffer-local controls should install hinted submit mapping")
assert_buffer_mapping(first_bufnr, "i", "buffer-local controls should install focused input mode")
assert_buffer_mapping(first_bufnr, "<CR>", "buffer-local controls should install Enter forwarding")
assert_buffer_mapping(first_bufnr, "<Tab>", "buffer-local controls should install Tab forwarding")
assert_buffer_mapping(first_bufnr, "<S-Tab>", "buffer-local controls should install Shift-Tab forwarding")
assert_buffer_mapping(first_bufnr, "<BS>", "buffer-local controls should install Backspace forwarding")
assert_buffer_mapping(first_bufnr, "x", "buffer-local controls should install Delete forwarding")
assert_buffer_mapping(first_bufnr, "ge", "buffer-local controls should install browser Escape forwarding")
assert_buffer_mapping(first_bufnr, "A", "buffer-local controls should install select-all forwarding")
assert_buffer_mapping(first_bufnr, "gl", "buffer-local controls should install location focus forwarding")
assert_buffer_mapping(first_bufnr, "<Up>", "buffer-local controls should install ArrowUp forwarding")
assert_buffer_mapping(first_bufnr, "<Down>", "buffer-local controls should install ArrowDown forwarding")
assert_buffer_mapping(first_bufnr, "<Left>", "buffer-local controls should install ArrowLeft forwarding")
assert_buffer_mapping(first_bufnr, "<Right>", "buffer-local controls should install ArrowRight forwarding")
assert_buffer_mapping(first_bufnr, "gh", "buffer-local controls should install cursor hover mapping")
assert_buffer_mapping(first_bufnr, "q", "buffer-local controls should install close mapping")
assert_buffer_mapping(first_bufnr, "<LeftMouse>", "buffer-local controls should install left-click mouse mapping")
assert_buffer_mapping(first_bufnr, "<ScrollWheelDown>", "buffer-local controls should install wheel-down mapping")
assert_buffer_mapping(first_bufnr, "<ScrollWheelUp>", "buffer-local controls should install wheel-up mapping")
assert_buffer_mapping(first_bufnr, "<Esc>", "buffer-local controls should install stop mapping")
assert_no_buffer_mapping(second_bufnr, "r", "buffer-local controls should not leak to other buffers")

local buffer_call_start = #calls
trigger_buffer(first_bufnr, "r")
trigger_buffer(first_bufnr, "H")
trigger_buffer(first_bufnr, "L")
trigger_buffer(first_bufnr, "j")
trigger_buffer(first_bufnr, "k")
trigger_buffer(first_bufnr, "a")
trigger_buffer(first_bufnr, "/")
trigger_buffer(first_bufnr, "f")
trigger_buffer(first_bufnr, "t")
trigger_buffer(first_bufnr, "s")
trigger_buffer(first_bufnr, "i")
trigger_buffer(first_bufnr, "<CR>")
trigger_buffer(first_bufnr, "<Tab>")
trigger_buffer(first_bufnr, "<S-Tab>")
trigger_buffer(first_bufnr, "<BS>")
trigger_buffer(first_bufnr, "x")
trigger_buffer(first_bufnr, "ge")
trigger_buffer(first_bufnr, "A")
trigger_buffer(first_bufnr, "gl")
trigger_buffer(first_bufnr, "<Up>")
trigger_buffer(first_bufnr, "<Down>")
trigger_buffer(first_bufnr, "<Left>")
trigger_buffer(first_bufnr, "<Right>")
trigger_buffer(first_bufnr, "gh")
trigger_buffer(first_bufnr, "q")
trigger_buffer(first_bufnr, "<LeftMouse>")
trigger_buffer(first_bufnr, "<ScrollWheelDown>")
trigger_buffer(first_bufnr, "<ScrollWheelUp>")
trigger_buffer(first_bufnr, "<Esc>")

local buffer_calls = {}
for index = buffer_call_start + 1, #calls do
  table.insert(buffer_calls, calls[index])
end
assert(
  table.concat(buffer_calls, ",")
    == "reload,back,forward,scroll:120:0,scroll:-120:0,address,find:local,hints,type_hints:type:buffer text,type_hints:submit:buffer text,text_mode,key:Enter:,key:Tab:,key:Tab:shift,key:Backspace:,key:Delete:,key:Escape:,key:A:ctrl,key:L:meta,key:ArrowUp:,key:ArrowDown:,key:ArrowLeft:,key:ArrowRight:,hover_here,close,click_mouse,scroll:120:0,scroll:-120:0,stop",
  "buffer-local controls should call browser APIs"
)

vim.keymap.set("n", "x", function()
  table.insert(calls, "buffer-existing")
end, { buffer = first_bufnr })
keymaps.setup_buffer(browser, first_bufnr, {
  enabled = true,
  mappings = {
    reload = "x",
    forward = false,
    type_hint_mode = "i",
    submit_hint_mode = false,
    input_text_mode = "I",
    key_enter = false,
  },
})
trigger_buffer(first_bufnr, "x")
assert(calls[#calls] == "buffer-existing", "buffer-local controls should not overwrite existing buffer mappings")
assert_no_buffer_mapping(first_bufnr, "L", "false buffer-local mappings should disable defaults after reinstall")
assert_buffer_mapping(first_bufnr, "i", "custom buffer-local hinted input mapping should be installed")
assert_no_buffer_mapping(first_bufnr, "s", "false buffer-local hinted submit mapping should disable default")
assert_buffer_mapping(first_bufnr, "I", "custom buffer-local focused input mapping should be installed")
assert_no_buffer_mapping(first_bufnr, "<CR>", "false buffer-local browser key mappings should disable defaults")
assert_buffer_mapping(first_bufnr, "<LeftMouse>", "mouse mappings should remain enabled by default after reinstall")
assert_buffer_mapping(first_bufnr, "<Esc>", "stop mapping should remain enabled by default after reinstall")

vim.keymap.set("n", "<LeftMouse>", function()
  table.insert(calls, "mouse-existing")
end, { buffer = second_bufnr })
keymaps.setup_buffer(browser, second_bufnr, {
  enabled = true,
})
trigger_buffer(second_bufnr, "<LeftMouse>")
assert(calls[#calls] == "mouse-existing", "buffer-local mouse controls should not overwrite existing mouse mappings")

keymaps.setup_buffer(browser, first_bufnr, {
  enabled = false,
})
assert_no_buffer_mapping(first_bufnr, "r", "disabling buffer-local controls should delete owned buffer mappings")
