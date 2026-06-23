local M = {}

local installed = {}

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

local function set_mapping(prefix, lhs, callback, desc)
  if lhs == nil or lhs == false or lhs == "" then
    return
  end
  local full_lhs = normalize_prefix(prefix) .. lhs
  if vim.fn.maparg(full_lhs, "n") ~= "" then
    return
  end
  vim.keymap.set("n", full_lhs, callback, {
    desc = desc,
    silent = true,
  })
  table.insert(installed, {
    lhs = full_lhs,
    callback = callback,
  })
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
end

return M
