local address = require("nvim-browser.address")
local backend = require("nvim-browser.backend")
local config = require("nvim-browser.config")
local doctor = require("nvim-browser.doctor")
local keymaps = require("nvim-browser.keymaps")
local terminal = require("nvim-browser.terminal")

local M = {}

local state = {
  last_target = nil,
}

function M.setup(opts)
  M.config = config.setup(opts)
  terminal.configure(M.config)
  keymaps.setup(M, M.config.keymaps or {})
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

local function setup_preview_keymaps()
  local terminal_state = terminal.state()
  if terminal_state.bufnr ~= nil then
    keymaps.setup_buffer(M, terminal_state.bufnr, M.config.preview_keymaps or {})
  end
end

function M.inspect(target)
  target = resolve_target(target)
  state.last_target = target
  local previous_bufnr = terminal.state().bufnr
  terminal.open(backend.command_for(M.config.binary, "inspect", target, M.config))
  local current_bufnr = terminal.state().bufnr
  if previous_bufnr ~= current_bufnr then
    keymaps.clear_buffer(previous_bufnr)
  end
  setup_preview_keymaps()
end

function M.open(target)
  target = resolve_target(target)
  state.last_target = target
  local previous_bufnr = terminal.state().bufnr
  terminal.open(backend.command_for(M.config.binary, "open", target, M.config))
  local current_bufnr = terminal.state().bufnr
  if previous_bufnr ~= current_bufnr then
    keymaps.clear_buffer(previous_bufnr)
  end
  setup_preview_keymaps()
end

function M.preview()
  M.open(vim.fn.expand("%:p"))
end

function M.focus()
  return terminal.focus()
end

function M.close()
  keymaps.clear_buffer(terminal.state().bufnr)
  terminal.close()
end

function M.refresh()
  return terminal.refresh()
end

function M.reload()
  return terminal.reload()
end

function M.stop()
  return terminal.stop()
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
  local value = input
  if type(input) ~= "string" then
    input = input or vim.fn.input
    value = input("nvim-browser address: ", M.current_url() or M.last_target() or "")
  end
  local target = M.resolve_address_target(value)
  if target == nil then
    return false
  end
  local is_active = opts.is_active
  if is_active == nil then
    is_active = has_active_browser_session()
  end
  if is_active then
    local ok = M.navigate(target)
    if ok then
      state.last_target = target
    end
    return ok
  end
  local ok = M.open(target)
  state.last_target = target
  return ok ~= false
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

function M.page_scroll(direction)
  return terminal.page_scroll(direction)
end

function M.page_down()
  return terminal.page_scroll(1)
end

function M.page_up()
  return terminal.page_scroll(-1)
end

function M.input_text(text)
  return terminal.input_text(text)
end

function M.paste_register(register)
  register = register or '"'
  if type(register) ~= "string" or #register ~= 1 then
    return false
  end
  local ok, text = pcall(vim.fn.getreg, register)
  if not ok or text == nil or text == "" then
    return false
  end
  return M.input_text(text)
end

function M.yank_selection(register)
  return terminal.yank_selection(register or '"')
end

function M.input_text_mode(input)
  input = input or vim.fn.input
  local text = input("nvim-browser text: ")
  if text == nil or text == "" then
    return false
  end
  return M.input_text(text)
end

function M.start_text_mode(opts)
  return terminal.start_text_mode(opts)
end

function M.press_key(key, opts)
  return terminal.press_key(key, opts)
end

function M.focus_selector(selector)
  return terminal.focus_selector(selector)
end

function M.click_point(x, y)
  return terminal.click_point(x, y)
end

function M.hover_point(x, y)
  return terminal.hover_point(x, y)
end

function M.wheel_point(x, y, delta_y, delta_x)
  return terminal.wheel_point(x, y, delta_y, delta_x)
end

function M.type_point(x, y, text, opts)
  return terminal.type_point(x, y, text, opts)
end

function M.find_text(query, opts)
  return terminal.find_text(query, opts)
end

function M.find_next()
  return terminal.find_next()
end

function M.find_previous()
  return terminal.find_previous()
end

function M.reader()
  return terminal.reader()
end

function M.reader_follow()
  local target = terminal.reader_follow()
  if target == false or target == nil then
    return false
  end
  state.last_target = target
  return true
end

function M.click_here()
  return terminal.click_here()
end

function M.hover_here()
  return terminal.hover_here()
end

function M.type_here(text, opts)
  return terminal.type_here(text, opts)
end

function M.click_mouse(mousepos)
  return terminal.click_mouse(mousepos)
end

function M.wheel_mouse(delta_y, delta_x, mousepos)
  return terminal.wheel_mouse(delta_y, delta_x, mousepos)
end

function M.click_hint(id)
  return terminal.click_hint(id)
end

function M.hover_hint(id)
  return terminal.hover_hint(id)
end

function M.follow_hint(id)
  return terminal.follow_hint(id)
end

function M.type_hint(id, text, opts)
  return terminal.type_hint(id, text, opts)
end

function M.select_hint(id, choice)
  return terminal.select_hint(id, choice)
end

function M.toggle_hint(id)
  return terminal.toggle_hint(id)
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

local function hint_mode_match(hints, prefix)
  local exact = nil
  local prefixed = 0
  for _, hint in ipairs(hints) do
    local label = hint.hint_label ~= nil and tostring(hint.hint_label):lower() or nil
    if label ~= nil then
      if label == prefix then
        exact = label
      end
      if label:sub(1, #prefix) == prefix then
        prefixed = prefixed + 1
      end
    end
  end
  return exact, prefixed
end

function M.transient_hint_mode(opts)
  opts = opts or {}
  local hints = M.hints()
  if #hints == 0 then
    return false
  end

  local getcharstr = opts.getcharstr or vim.fn.getcharstr
  local prefix = ""
  while true do
    local key = getcharstr()
    if key == nil or key == "" then
      return false
    end
    if key == "\27" or key == vim.keycode("<Esc>") then
      return false
    end
    prefix = prefix .. key:lower()

    local exact, prefixed = hint_mode_match(hints, prefix)
    if prefixed == 0 then
      return false
    end
    if exact ~= nil and prefixed == 1 then
      return M.follow_hint(exact)
    end
  end
end

function M.type_hint_mode(input, opts)
  input = input or vim.fn.input
  opts = opts or {}
  if #M.hints() == 0 then
    return false
  end
  local label = input("nvim-browser hint: ")
  if label == nil or label == "" then
    return false
  end
  local text = input("nvim-browser text: ")
  if text == nil or text == "" then
    return false
  end
  return M.type_hint(label, text, { submit = opts.submit == true })
end

function M.select_hint_mode(input)
  input = input or vim.fn.input
  if #M.hints() == 0 then
    return false
  end
  local label = input("nvim-browser hint: ")
  if label == nil or label == "" then
    return false
  end
  local choice = input("nvim-browser option: ")
  if choice == nil or choice == "" then
    return false
  end
  return M.select_hint(label, choice)
end

function M.toggle_hint_mode(input)
  input = input or vim.fn.input
  if #M.hints() == 0 then
    return false
  end
  local label = input("nvim-browser hint: ")
  if label == nil or label == "" then
    return false
  end
  return M.toggle_hint(label)
end

function M.toggle()
  return terminal.toggle()
end

function M.last_target()
  return terminal.state().last_target or state.last_target
end

function M.current_url()
  return terminal.state().current_url
end

function M.current_title()
  return terminal.state().current_title
end

function M.page_metrics()
  return terminal.state().page_metrics
end

function M.runtime_metadata()
  return terminal.state().runtime_metadata
end

function M.status()
  return terminal.state().status
end

function M.status_error()
  return terminal.state().status_error
end

function M.hint_error()
  return terminal.state().hint_error
end

function M.doctor()
  return doctor.run(M.config, terminal.state())
end

function M.last_find_found()
  return terminal.state().last_find_found
end

function M.hints()
  return terminal.state().element_hints or {}
end

M.setup()

return M
