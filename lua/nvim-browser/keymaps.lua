local M = {}

local installed = {}
local installed_buffers = {}

local function normalize_prefix(prefix)
  if prefix == nil then
    return ""
  end
  return prefix
end

local function delete_installed()
  for _, item in ipairs(installed) do
    local current = vim.fn.maparg(item.lhs, "n", false, true)
    if current.callback == item.callback then
      pcall(vim.keymap.del, "n", item.lhs)
    end
  end
  installed = {}
end

local function delete_installed_buffer(bufnr)
  if bufnr == nil then
    return
  end
  if not vim.api.nvim_buf_is_valid(bufnr) then
    installed_buffers[bufnr] = nil
    return
  end
  local items = installed_buffers[bufnr] or {}
  for _, item in ipairs(items) do
    local current = vim.api.nvim_buf_call(bufnr, function()
      return vim.fn.maparg(item.lhs, "n", false, true)
    end)
    if current.callback == item.callback then
      pcall(vim.keymap.del, "n", item.lhs, { buffer = bufnr })
    end
  end
  installed_buffers[bufnr] = nil
end

local function has_buffer_mapping(bufnr, lhs)
  local current = vim.api.nvim_buf_call(bufnr, function()
    return vim.fn.maparg(lhs, "n", false, true)
  end)
  return current.lhs ~= nil and current.buffer == 1
end

local function set_mapping(prefix, lhs, callback, desc, opts)
  opts = opts or {}
  if lhs == nil or lhs == false or lhs == "" then
    return
  end
  local full_lhs = normalize_prefix(prefix) .. lhs
  if opts.buffer ~= nil then
    if has_buffer_mapping(opts.buffer, full_lhs) then
      return
    end
  elseif vim.fn.maparg(full_lhs, "n") ~= "" then
    return
  end
  local keymap_opts = {
    desc = desc,
    silent = true,
  }
  if opts.buffer ~= nil then
    keymap_opts.buffer = opts.buffer
  end
  vim.keymap.set("n", full_lhs, callback, keymap_opts)
  local item = {
    lhs = full_lhs,
    callback = callback,
  }
  if opts.buffer ~= nil then
    installed_buffers[opts.buffer] = installed_buffers[opts.buffer] or {}
    table.insert(installed_buffers[opts.buffer], item)
  else
    table.insert(installed, item)
  end
end

local function mapping_lhs(mappings, name, default)
  if mappings[name] == nil then
    return default
  end
  return mappings[name]
end

function M.setup(browser, opts)
  opts = opts or {}
  delete_installed()

  if opts.enabled ~= true then
    return
  end

  local mappings = opts.mappings or {}
  local prefix = opts.prefix
  local scroll_pixels = tonumber(opts.scroll_pixels) or 400
  local input = opts.input or vim.fn.input

  set_mapping(prefix, mapping_lhs(mappings, "reload", "r"), function()
    browser.reload()
  end, "nvim-browser: reload")

  set_mapping(prefix, mapping_lhs(mappings, "back", "h"), function()
    browser.back()
  end, "nvim-browser: back")

  set_mapping(prefix, mapping_lhs(mappings, "forward", "l"), function()
    browser.forward()
  end, "nvim-browser: forward")

  set_mapping(prefix, mapping_lhs(mappings, "scroll_down", "j"), function()
    browser.scroll(scroll_pixels, 0)
  end, "nvim-browser: scroll down")

  set_mapping(prefix, mapping_lhs(mappings, "scroll_up", "k"), function()
    browser.scroll(-scroll_pixels, 0)
  end, "nvim-browser: scroll up")

  set_mapping(prefix, mapping_lhs(mappings, "address", "a"), function()
    browser.address()
  end, "nvim-browser: address")

  set_mapping(prefix, mapping_lhs(mappings, "find", "/"), function()
    local query = input("nvim-browser find: ")
    if query == nil or query == "" then
      return
    end
    browser.find_text(query)
  end, "nvim-browser: find")

  set_mapping(prefix, mapping_lhs(mappings, "hints", "f"), function()
    browser.hint_mode()
  end, "nvim-browser: hints")

  set_mapping(prefix, mapping_lhs(mappings, "type_hint_mode", "t"), function()
    browser.type_hint_mode(input)
  end, "nvim-browser: type into hint")

  set_mapping(prefix, mapping_lhs(mappings, "submit_hint_mode", "s"), function()
    browser.type_hint_mode(input, { submit = true })
  end, "nvim-browser: submit hinted input")
end

function M.setup_buffer(browser, bufnr, opts)
  opts = opts or {}
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    if bufnr ~= nil then
      installed_buffers[bufnr] = nil
    end
    return
  end
  delete_installed_buffer(bufnr)

  if opts.enabled ~= true then
    return
  end

  local mappings = opts.mappings or {}
  local scroll_pixels = tonumber(opts.scroll_pixels) or 400
  local input = opts.input or vim.fn.input
  local buffer_opts = { buffer = bufnr }

  set_mapping(nil, mapping_lhs(mappings, "reload", "r"), function()
    browser.reload()
  end, "nvim-browser: reload", buffer_opts)

  set_mapping(nil, mapping_lhs(mappings, "back", "H"), function()
    browser.back()
  end, "nvim-browser: back", buffer_opts)

  set_mapping(nil, mapping_lhs(mappings, "forward", "L"), function()
    browser.forward()
  end, "nvim-browser: forward", buffer_opts)

  set_mapping(nil, mapping_lhs(mappings, "scroll_down", "j"), function()
    browser.scroll(scroll_pixels, 0)
  end, "nvim-browser: scroll down", buffer_opts)

  set_mapping(nil, mapping_lhs(mappings, "scroll_up", "k"), function()
    browser.scroll(-scroll_pixels, 0)
  end, "nvim-browser: scroll up", buffer_opts)

  set_mapping(nil, mapping_lhs(mappings, "address", "a"), function()
    browser.address()
  end, "nvim-browser: address", buffer_opts)

  set_mapping(nil, mapping_lhs(mappings, "find", "/"), function()
    local query = input("nvim-browser find: ")
    if query == nil or query == "" then
      return
    end
    browser.find_text(query)
  end, "nvim-browser: find", buffer_opts)

  set_mapping(nil, mapping_lhs(mappings, "hints", "f"), function()
    browser.hint_mode()
  end, "nvim-browser: hints", buffer_opts)

  set_mapping(nil, mapping_lhs(mappings, "type_hint_mode", "t"), function()
    browser.type_hint_mode(input)
  end, "nvim-browser: type into hint", buffer_opts)

  set_mapping(nil, mapping_lhs(mappings, "submit_hint_mode", "s"), function()
    browser.type_hint_mode(input, { submit = true })
  end, "nvim-browser: submit hinted input", buffer_opts)

  set_mapping(nil, mapping_lhs(mappings, "stop", "<Esc>"), function()
    browser.stop()
  end, "nvim-browser: stop loading", buffer_opts)

  set_mapping(nil, mapping_lhs(mappings, "left_click", "<LeftMouse>"), function()
    browser.click_mouse()
  end, "nvim-browser: click preview", buffer_opts)

  set_mapping(nil, mapping_lhs(mappings, "wheel_down", "<ScrollWheelDown>"), function()
    browser.scroll(scroll_pixels, 0)
  end, "nvim-browser: wheel down", buffer_opts)

  set_mapping(nil, mapping_lhs(mappings, "wheel_up", "<ScrollWheelUp>"), function()
    browser.scroll(-scroll_pixels, 0)
  end, "nvim-browser: wheel up", buffer_opts)

  set_mapping(nil, mapping_lhs(mappings, "close", "q"), function()
    browser.close()
  end, "nvim-browser: close", buffer_opts)
end

function M.clear_buffer(bufnr)
  delete_installed_buffer(bufnr)
end

M._test = {
  tracked_buffer_count = function()
    local count = 0
    for _ in pairs(installed_buffers) do
      count = count + 1
    end
    return count
  end,
}

return M
