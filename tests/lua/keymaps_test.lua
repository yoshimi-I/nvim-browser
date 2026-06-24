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
  page_down = function()
    table.insert(calls, "page_down")
  end,
  page_up = function()
    table.insert(calls, "page_up")
  end,
  scroll_top = function()
    table.insert(calls, "scroll_top")
  end,
  scroll_bottom = function()
    table.insert(calls, "scroll_bottom")
  end,
  half_page_down = function()
    table.insert(calls, "half_page_down")
  end,
  half_page_up = function()
    table.insert(calls, "half_page_up")
  end,
  zoom_in = function()
    table.insert(calls, "zoom_in")
  end,
  zoom_out = function()
    table.insert(calls, "zoom_out")
  end,
  zoom_reset = function()
    table.insert(calls, "zoom_reset")
  end,
  address = function()
    table.insert(calls, "address")
  end,
  open_under_cursor = function()
    table.insert(calls, "open_under_cursor")
  end,
  find_text = function(query, opts)
    local direction = opts ~= nil and opts.backwards == true and "back" or "forward"
    table.insert(calls, "find:" .. direction .. ":" .. query)
    return true
  end,
  find_next = function()
    table.insert(calls, "find_next")
    return true
  end,
  find_previous = function()
    table.insert(calls, "find_previous")
    return true
  end,
  hint_mode = function()
    table.insert(calls, "hints")
  end,
  transient_hint_mode = function()
    table.insert(calls, "transient_hints")
  end,
  type_hint_mode = function(input, opts)
    local value = input("nvim-browser text: ")
    local suffix = opts ~= nil and opts.submit == true and ":submit" or ":type"
    table.insert(calls, "type_hints" .. suffix .. ":" .. value)
  end,
  select_hint_mode = function(input)
    local value = input("nvim-browser option: ")
    table.insert(calls, "select_hint:" .. value)
  end,
  toggle_hint_mode = function(input)
    local value = input("nvim-browser hint: ")
    table.insert(calls, "toggle_hint:" .. value)
  end,
  input_text_mode = function(input)
    table.insert(calls, "input_mode:" .. input("nvim-browser text: "))
  end,
  paste_register = function(register)
    table.insert(calls, "paste:" .. tostring(register))
    return true
  end,
  yank_selection = function(register)
    table.insert(calls, "yank:" .. tostring(register))
    return true
  end,
  yank_region = function(register, start_row, start_col, end_row, end_col)
    if start_row ~= nil then
      table.insert(
        calls,
        table.concat({
          "yank_region",
          tostring(register),
          tostring(start_row),
          tostring(start_col),
          tostring(end_row),
          tostring(end_col),
        }, ":")
      )
      return true
    end
    table.insert(calls, "yank_region:" .. tostring(register))
    return true
  end,
  yank_current_url = function(register)
    table.insert(calls, "yank_url:" .. tostring(register))
    return true
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
  right_click_mouse = function()
    table.insert(calls, "right_click_mouse")
  end,
  wheel_mouse = function(delta_y, delta_x)
    table.insert(calls, "wheel:" .. tostring(delta_y) .. ":" .. tostring(delta_x))
    return true
  end,
  click_here = function()
    table.insert(calls, "click_here")
  end,
  right_click_here = function()
    table.insert(calls, "right_click_here")
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
  actions = function()
    table.insert(calls, "actions")
    return true
  end,
}

local function mapping(lhs)
  return vim.fn.maparg(lhs, "n", false, true)
end

local function buffer_mapping(bufnr, lhs, mode)
  return vim.api.nvim_buf_call(bufnr, function()
    return vim.fn.maparg(lhs, mode or "n", false, true)
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

local function assert_buffer_visual_mapping(bufnr, lhs, message)
  local item = buffer_mapping(bufnr, lhs, "x")
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
    assert(
      prompt == "nvim-browser text: " or prompt == "nvim-browser option: " or prompt == "nvim-browser hint: ",
      "hinted input mapping should pass the configured input function"
    )
    return "global text"
  end,
})

assert_mapping("\\xr", "enabled keymaps should install reload mapping")
assert_mapping("\\xh", "enabled keymaps should install back mapping")
assert_mapping("\\xl", "enabled keymaps should install forward mapping")
assert_mapping("\\xj", "enabled keymaps should install scroll-down mapping")
assert_mapping("\\xk", "enabled keymaps should install scroll-up mapping")
assert_mapping("\\xa", "enabled keymaps should install address mapping")
assert_mapping("\\xg", "enabled keymaps should install open-under-cursor mapping")
assert_mapping("\\x/", "enabled keymaps should install find mapping")
assert_mapping("\\xf", "enabled keymaps should install hint mapping")
assert_mapping("\\xt", "enabled keymaps should install hinted input mapping")
assert_mapping("\\xs", "enabled keymaps should install hinted submit mapping")
assert_mapping("\\xo", "enabled keymaps should install hinted select mapping")
assert_mapping("\\xc", "enabled keymaps should install hinted toggle mapping")

trigger("\\xr")
trigger("\\xh")
trigger("\\xl")
trigger("\\xj")
trigger("\\xk")
trigger("\\xa")
trigger("\\xg")
trigger("\\x/")
trigger("\\xf")
trigger("\\xt")
trigger("\\xs")
trigger("\\xo")
trigger("\\xc")

assert(
  table.concat(calls, ",")
    == "reload,back,forward,scroll:250:0,scroll:-250:0,address,open_under_cursor,find:forward:needle,hints,type_hints:type:global text,type_hints:submit:global text,select_hint:global text,toggle_hint:global text",
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
    select_hint_mode = "o",
    toggle_hint_mode = "c",
  },
})

assert_no_mapping("\\xr", "re-running setup should remove previously installed mappings")
assert_mapping("\\zR", "custom mapping should be installed")
assert_no_mapping("\\zl", "false custom mapping should disable the default mapping")
assert_mapping("\\z<C-d>", "custom scroll mapping should be installed")
assert_mapping("\\zi", "custom hinted input mapping should be installed")
assert_no_mapping("\\zs", "false hinted submit mapping should disable the default mapping")
assert_mapping("\\zo", "custom hinted select mapping should be installed")
assert_mapping("\\zc", "custom hinted toggle mapping should be installed")

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
    assert(
      prompt == "nvim-browser text: " or prompt == "nvim-browser option: " or prompt == "nvim-browser hint: ",
      "buffer hinted input mapping should pass the configured input function"
    )
    return "buffer text"
  end,
})

assert_buffer_mapping(first_bufnr, "r", "buffer-local controls should install reload mapping")
assert_buffer_mapping(first_bufnr, "H", "buffer-local controls should install back mapping")
assert_buffer_mapping(first_bufnr, "L", "buffer-local controls should install forward mapping")
assert_buffer_mapping(first_bufnr, "j", "buffer-local controls should install scroll-down mapping")
assert_buffer_mapping(first_bufnr, "k", "buffer-local controls should install scroll-up mapping")
assert_buffer_mapping(first_bufnr, "<PageDown>", "buffer-local controls should install page-down mapping")
assert_buffer_mapping(first_bufnr, "<PageUp>", "buffer-local controls should install page-up mapping")
assert_buffer_mapping(first_bufnr, "+", "buffer-local controls should install zoom-in mapping")
assert_buffer_mapping(first_bufnr, "-", "buffer-local controls should install zoom-out mapping")
assert_buffer_mapping(first_bufnr, "=", "buffer-local controls should install zoom-reset mapping")
assert_buffer_mapping(first_bufnr, "a", "buffer-local controls should install address mapping")
assert_buffer_mapping(first_bufnr, "?", "buffer-local controls should install actions picker mapping")
assert_buffer_mapping(first_bufnr, "/", "buffer-local controls should install find mapping")
assert_buffer_mapping(first_bufnr, "n", "buffer-local controls should install find-next mapping")
assert_buffer_mapping(first_bufnr, "N", "buffer-local controls should install find-previous mapping")
assert_buffer_mapping(first_bufnr, "f", "buffer-local controls should install hint mapping")
assert_buffer_mapping(first_bufnr, "t", "buffer-local controls should install hinted input mapping")
assert_buffer_mapping(first_bufnr, "s", "buffer-local controls should install hinted submit mapping")
assert_buffer_mapping(first_bufnr, "i", "buffer-local controls should install focused input mode")
assert_buffer_mapping(first_bufnr, "p", "buffer-local controls should install register paste")
assert_buffer_mapping(first_bufnr, "y", "buffer-local controls should install browser selection yank")
assert_buffer_visual_mapping(first_bufnr, "y", "buffer-local controls should install visual browser region yank")
assert_buffer_mapping(first_bufnr, "Y", "buffer-local controls should install current URL yank")
assert_buffer_mapping(first_bufnr, "<CR>", "buffer-local controls should install Enter forwarding")
assert_buffer_mapping(first_bufnr, "<Tab>", "buffer-local controls should install Tab forwarding")
assert_buffer_mapping(first_bufnr, "<S-Tab>", "buffer-local controls should install Shift-Tab forwarding")
assert_buffer_mapping(first_bufnr, "<BS>", "buffer-local controls should install Backspace forwarding")
assert_buffer_mapping(first_bufnr, "x", "buffer-local controls should install Delete forwarding")
assert_buffer_mapping(first_bufnr, "ge", "buffer-local controls should install browser Escape forwarding")
assert_buffer_mapping(first_bufnr, "A", "buffer-local controls should install select-all forwarding")
assert_buffer_mapping(first_bufnr, "gl", "buffer-local controls should install address prompt shortcut")
assert_buffer_mapping(first_bufnr, "<Up>", "buffer-local controls should install ArrowUp forwarding")
assert_buffer_mapping(first_bufnr, "<Down>", "buffer-local controls should install ArrowDown forwarding")
assert_buffer_mapping(first_bufnr, "<Left>", "buffer-local controls should install ArrowLeft forwarding")
assert_buffer_mapping(first_bufnr, "<Right>", "buffer-local controls should install ArrowRight forwarding")
assert_buffer_mapping(first_bufnr, "gc", "buffer-local controls should install cursor click mapping")
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
trigger_buffer(first_bufnr, "<PageDown>")
trigger_buffer(first_bufnr, "<PageUp>")
trigger_buffer(first_bufnr, "gg")
trigger_buffer(first_bufnr, "G")
trigger_buffer(first_bufnr, "<C-d>")
trigger_buffer(first_bufnr, "<C-u>")
trigger_buffer(first_bufnr, "+")
trigger_buffer(first_bufnr, "-")
trigger_buffer(first_bufnr, "=")
trigger_buffer(first_bufnr, "a")
trigger_buffer(first_bufnr, "?")
trigger_buffer(first_bufnr, "/")
trigger_buffer(first_bufnr, "n")
trigger_buffer(first_bufnr, "N")
trigger_buffer(first_bufnr, "f")
trigger_buffer(first_bufnr, "t")
trigger_buffer(first_bufnr, "s")
trigger_buffer(first_bufnr, "o")
trigger_buffer(first_bufnr, "c")
trigger_buffer(first_bufnr, "i")
vim.api.nvim_set_current_buf(first_bufnr)
vim.cmd([[normal "+p]])
vim.cmd([[normal "+y]])
vim.cmd([[normal "+Y]])
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
trigger_buffer(first_bufnr, "gc")
trigger_buffer(first_bufnr, "gr")
trigger_buffer(first_bufnr, "gh")
trigger_buffer(first_bufnr, "q")
trigger_buffer(first_bufnr, "<LeftMouse>")
trigger_buffer(first_bufnr, "<RightMouse>")
trigger_buffer(first_bufnr, "<ScrollWheelDown>")
trigger_buffer(first_bufnr, "<ScrollWheelUp>")
trigger_buffer(first_bufnr, "<Esc>")

local buffer_calls = {}
for index = buffer_call_start + 1, #calls do
  table.insert(buffer_calls, calls[index])
end
assert(
  table.concat(buffer_calls, ",")
    == "reload,back,forward,scroll:120:0,scroll:-120:0,page_down,page_up,scroll_top,scroll_bottom,half_page_down,half_page_up,zoom_in,zoom_out,zoom_reset,address,actions,find:forward:local,find_next,find_previous,transient_hints,type_hints:type:buffer text,type_hints:submit:buffer text,select_hint:buffer text,toggle_hint:buffer text,text_mode,paste:+,yank:+,yank_url:+,key:Enter:,key:Tab:,key:Tab:shift,key:Backspace:,key:Delete:,key:Escape:,key:A:ctrl,address,key:ArrowUp:,key:ArrowDown:,key:ArrowLeft:,key:ArrowRight:,click_here,right_click_here,hover_here,close,click_mouse,right_click_mouse,wheel:120:0,wheel:-120:0,stop",
  "buffer-local controls should call browser APIs and prefer transient hints"
)

local visual_yank_start = #calls
vim.api.nvim_set_current_buf(first_bufnr)
vim.api.nvim_buf_set_lines(first_bufnr, 0, -1, false, { "abcdef", "ghijkl" })
vim.cmd([[normal! gg0]])
vim.api.nvim_feedkeys("vly", "xt", false)
assert(
  vim.wait(1000, function()
    return #calls > visual_yank_start
  end),
  "visual yank mapping should call browser.yank_region"
)
assert(calls[#calls] == 'yank_region:":1:1:1:2', "visual yank mapping should pass live Visual virtual columns")

local original_wheel_mouse = browser.wheel_mouse
browser.wheel_mouse = function(delta_y, delta_x)
  table.insert(calls, "wheel:false:" .. tostring(delta_y) .. ":" .. tostring(delta_x))
  return false
end
local fallback_start = #calls
trigger_buffer(first_bufnr, "<ScrollWheelDown>")
trigger_buffer(first_bufnr, "<ScrollWheelUp>")
local fallback_calls = {}
for index = fallback_start + 1, #calls do
  table.insert(fallback_calls, calls[index])
end
assert(
  table.concat(fallback_calls, ",") == "wheel:false:120:0,scroll:120:0,wheel:false:-120:0,scroll:-120:0",
  "buffer-local wheel controls should fall back to page scroll when native wheel coordinates are unavailable"
)
browser.wheel_mouse = original_wheel_mouse

vim.keymap.set("n", "x", function()
  table.insert(calls, "buffer-existing")
end, { buffer = first_bufnr })
keymaps.setup_buffer(browser, first_bufnr, {
  enabled = true,
  mappings = {
    reload = "x",
    actions = "??",
    forward = false,
    type_hint_mode = "i",
    submit_hint_mode = false,
    select_hint_mode = false,
    toggle_hint_mode = false,
    page_down = "<C-f>",
    page_up = false,
    zoom_in = "zi",
    zoom_out = false,
    zoom_reset = "z0",
    click_here = "cc",
    input_text_mode = "I",
    paste_register = "P",
    yank_selection = "yy",
    yank_current_url = "YU",
    key_enter = false,
    key_focus_location = "ga",
  },
})
trigger_buffer(first_bufnr, "x")
assert(calls[#calls] == "buffer-existing", "buffer-local controls should not overwrite existing buffer mappings")
assert_no_buffer_mapping(first_bufnr, "L", "false buffer-local mappings should disable defaults after reinstall")
assert_buffer_mapping(first_bufnr, "i", "custom buffer-local hinted input mapping should be installed")
assert_no_buffer_mapping(first_bufnr, "s", "false buffer-local hinted submit mapping should disable default")
assert_no_buffer_mapping(first_bufnr, "o", "false buffer-local hinted select mapping should disable default")
assert_no_buffer_mapping(first_bufnr, "c", "false buffer-local hinted toggle mapping should disable default")
assert_buffer_mapping(first_bufnr, "<C-f>", "custom buffer-local page-down mapping should be installed")
assert_no_buffer_mapping(first_bufnr, "<PageUp>", "false buffer-local page-up mapping should disable default")
assert_buffer_mapping(first_bufnr, "zi", "custom buffer-local zoom-in mapping should be installed")
assert_no_buffer_mapping(first_bufnr, "-", "false buffer-local zoom-out mapping should disable default")
assert_buffer_mapping(first_bufnr, "z0", "custom buffer-local zoom-reset mapping should be installed")
assert_buffer_mapping(first_bufnr, "cc", "custom buffer-local cursor click mapping should be installed")
assert_buffer_mapping(first_bufnr, "I", "custom buffer-local focused input mapping should be installed")
assert_buffer_mapping(first_bufnr, "??", "custom buffer-local actions mapping should be installed")
assert_buffer_mapping(first_bufnr, "P", "custom buffer-local paste mapping should be installed")
assert_buffer_mapping(first_bufnr, "yy", "custom buffer-local browser selection yank mapping should be installed")
assert_buffer_visual_mapping(first_bufnr, "yy", "custom buffer-local visual browser region yank mapping should be installed")
assert_buffer_mapping(first_bufnr, "YU", "custom buffer-local current URL yank mapping should be installed")
assert_no_buffer_mapping(first_bufnr, "gl", "remapped address prompt shortcut should remove the default")
assert_buffer_mapping(first_bufnr, "ga", "custom address prompt shortcut should be installed")
assert_no_buffer_mapping(first_bufnr, "<CR>", "false buffer-local browser key mappings should disable defaults")
assert_buffer_mapping(first_bufnr, "<LeftMouse>", "mouse mappings should remain enabled by default after reinstall")
assert_buffer_mapping(first_bufnr, "<Esc>", "stop mapping should remain enabled by default after reinstall")
trigger_buffer(first_bufnr, "ga")
assert(calls[#calls] == "address", "custom address prompt shortcut should call browser.address")

vim.keymap.set("n", "<LeftMouse>", function()
  table.insert(calls, "mouse-existing")
end, { buffer = second_bufnr })
keymaps.setup_buffer(browser, second_bufnr, {
  enabled = true,
})
trigger_buffer(second_bufnr, "<LeftMouse>")
assert(calls[#calls] == "mouse-existing", "buffer-local mouse controls should not overwrite existing mouse mappings")

vim.keymap.set("n", "gc", function()
  table.insert(calls, "cursor-click-existing")
end, { buffer = second_bufnr })
keymaps.setup_buffer(browser, second_bufnr, {
  enabled = true,
})
trigger_buffer(second_bufnr, "gc")
assert(calls[#calls] == "cursor-click-existing", "buffer-local cursor click should not overwrite existing mappings")

local disabled_click_bufnr = vim.api.nvim_create_buf(false, true)
keymaps.setup_buffer(browser, disabled_click_bufnr, {
  enabled = true,
  mappings = {
    click_here = false,
    actions = false,
  },
})
assert(
  buffer_mapping(disabled_click_bufnr, "gc").buffer ~= 1,
  "false cursor click mapping should disable the default buffer-local mapping"
)
assert(
  buffer_mapping(disabled_click_bufnr, "?").buffer ~= 1,
  "false actions mapping should disable the default buffer-local mapping"
)

keymaps.setup_buffer(browser, first_bufnr, {
  enabled = false,
})
assert_no_buffer_mapping(first_bufnr, "r", "disabling buffer-local controls should delete owned buffer mappings")
