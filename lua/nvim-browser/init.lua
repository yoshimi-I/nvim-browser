local address = require("nvim-browser.address")
local backend = require("nvim-browser.backend")
local config = require("nvim-browser.config")
local terminal = require("nvim-browser.terminal")

local M = {}

local state = {
  last_target = nil,
}

function M.setup(opts)
  M.config = config.setup(opts)
end

local function resolve_target(target)
  return target or vim.fn.expand("%:p")
end

local function has_active_browser_session()
  local terminal_state = terminal.state()
  return terminal_state.mode == "serve"
    and terminal_state.job_id ~= nil
    and terminal_state.has_buffer
end

function M.inspect(target)
  target = resolve_target(target)
  state.last_target = target
  terminal.open(backend.command_for(M.config.binary, "inspect", target, M.config))
end

function M.open(target)
  target = resolve_target(target)
  state.last_target = target
  terminal.open(backend.command_for(M.config.binary, "open", target, M.config))
end

function M.preview()
  M.open(vim.fn.expand("%:p"))
end

function M.focus()
  return terminal.focus()
end

function M.close()
  terminal.close()
end

function M.refresh()
  return terminal.refresh()
end

function M.reload()
  return terminal.reload()
end

function M.navigate(target)
  if target == nil or target == "" then
    return false
  end
  local ok = terminal.navigate(target)
  if ok then
    state.last_target = target
  end
  return ok
end

function M.resolve_address_target(input)
  return address.resolve(input, M.config.search_url or config.options.search_url)
end

function M.address(input, opts)
  opts = opts or {}
  input = input or vim.fn.input
  local target = M.resolve_address_target(input("nvim-browser address: "))
  if target == nil then
    return false
  end
  local is_active = opts.is_active
  if is_active == nil then
    is_active = has_active_browser_session()
  end
  if is_active then
    return M.navigate(target)
  end
  M.open(target)
  return true
end

function M.back()
  return terminal.back()
end

function M.forward()
  return terminal.forward()
end

function M.scroll(delta_y, delta_x)
  return terminal.scroll(delta_y, delta_x)
end

function M.input_text(text)
  return terminal.input_text(text)
end

function M.press_key(key)
  return terminal.press_key(key)
end

function M.focus_selector(selector)
  return terminal.focus_selector(selector)
end

function M.click_point(x, y)
  return terminal.click_point(x, y)
end

function M.click_here()
  return terminal.click_here()
end

function M.click_hint(id)
  return terminal.click_hint(id)
end

function M.follow_hint(id)
  return terminal.click_hint(id)
end

function M.hint_mode(input)
  input = input or vim.fn.input
  if #M.hints() == 0 then
    return false
  end
  local label = input("nvim-browser hint: ")
  if label == nil or label == "" then
    return false
  end
  return M.follow_hint(label)
end

function M.toggle()
  return terminal.toggle()
end

function M.last_target()
  return state.last_target
end

function M.current_url()
  return terminal.state().current_url
end

function M.current_title()
  return terminal.state().current_title
end

function M.status()
  return terminal.state().status
end

function M.status_error()
  return terminal.state().status_error
end

function M.hints()
  return terminal.state().element_hints or {}
end

M.setup()

return M
