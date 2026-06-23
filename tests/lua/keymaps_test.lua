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
}

local function mapping(lhs)
  return vim.fn.maparg(lhs, "n", false, true)
end

local function assert_no_mapping(lhs, message)
  assert(mapping(lhs).lhs == nil, message)
end

local function assert_mapping(lhs, message)
  assert(mapping(lhs).lhs ~= nil, message)
end

local function trigger(lhs)
  local callback = mapping(lhs).callback
  assert(type(callback) == "function", "mapping should install a Lua callback for " .. lhs)
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
    assert(prompt == "nvim-browser find: ", "find mapping should prompt with the expected label")
    return "needle"
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

trigger("\\xr")
trigger("\\xh")
trigger("\\xl")
trigger("\\xj")
trigger("\\xk")
trigger("\\xa")
trigger("\\x/")
trigger("\\xf")

assert(table.concat(calls, ",") == "reload,back,forward,scroll:250:0,scroll:-250:0,address,find:needle,hints", "keymaps should call browser APIs")

keymaps.setup(browser, {
  enabled = true,
  prefix = "<leader>z",
  mappings = {
    reload = "R",
    forward = false,
    scroll_down = "<C-d>",
  },
})

assert_no_mapping("\\xr", "re-running setup should remove previously installed mappings")
assert_mapping("\\zR", "custom mapping should be installed")
assert_no_mapping("\\zl", "false custom mapping should disable the default mapping")
assert_mapping("\\z<C-d>", "custom scroll mapping should be installed")

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
