local address = require("nvim-browser.address")
local backend = require("nvim-browser.backend")
local config = require("nvim-browser.config")
local doctor = require("nvim-browser.doctor")
local keymaps = require("nvim-browser.keymaps")
local terminal = require("nvim-browser.terminal")

local M = {}

local state = {
  last_target = nil,
  history = {},
  session_warning_messages = {},
  session_loaded_path = nil,
}

local history_limit = 50
local session_version = 1

local function plugin_root()
  return vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
end

local function calibration_fixture_path()
  return plugin_root() .. "/data/html/calibrate.html"
end

local function default_session_path()
  return vim.fn.stdpath("state") .. "/nvim-browser/session.json"
end

local function session_options()
  local opts = (M.config and M.config.session) or {}
  local limit = math.floor(tonumber(opts.history_limit) or history_limit)
  if limit < 0 then
    limit = 0
  end
  return {
    persist = opts.persist ~= false,
    history_limit = limit,
    path = opts.path or default_session_path(),
  }
end

local function warn_session(message)
  if state.session_warning_messages[message] then
    return
  end
  state.session_warning_messages[message] = true
  vim.api.nvim_echo({ { message, "WarningMsg" } }, false, {})
end

local function normalize_history_value(value)
  if value == nil or value == vim.NIL then
    return nil
  end
  value = tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
  if value == "" then
    return nil
  end
  return value
end

local function is_direct_history_url(target)
  return type(target) == "string" and target:match("^https?://") ~= nil
end

local function add_history_entry(url, title)
  url = normalize_history_value(url)
  if url == nil then
    return false
  end
  if not is_direct_history_url(url) then
    return false
  end
  title = normalize_history_value(title)
  for index = #state.history, 1, -1 do
    if state.history[index].url == url then
      table.remove(state.history, index)
    end
  end
  table.insert(state.history, 1, { url = url, title = title })
  while #state.history > history_limit do
    table.remove(state.history)
  end
  return true
end

local function save_session()
  local opts = session_options()
  if not opts.persist then
    return true
  end
  local directory = vim.fn.fnamemodify(opts.path, ":h")
  if directory ~= nil and directory ~= "" and directory ~= "." then
    local mkdir_ok, mkdir_result = pcall(vim.fn.mkdir, directory, "p")
    if not mkdir_ok or mkdir_result == 0 then
      warn_session("nvim-browser: failed to create session state directory")
      return false
    end
  end
  local payload = {
    version = session_version,
    last_target = normalize_history_value(state.last_target),
    history = M.history(),
  }
  local encoded_ok, encoded = pcall(vim.fn.json_encode, payload)
  if not encoded_ok then
    warn_session("nvim-browser: failed to encode session state")
    return false
  end
  local write_ok, write_result = pcall(vim.fn.writefile, { encoded }, opts.path)
  if not write_ok or write_result ~= 0 then
    warn_session("nvim-browser: failed to write session state")
    return false
  end
  return true
end

local function set_last_target(target)
  target = normalize_history_value(target)
  if target == nil then
    return false
  end
  state.last_target = target
  save_session()
  return true
end

local function record_target(target, title)
  target = normalize_history_value(target)
  if target == nil then
    return false
  end
  add_history_entry(target, title)
  state.last_target = target
  save_session()
  return true
end

local function session_file_signature(path, limit)
  local stat_ok, stat = pcall(vim.loop.fs_stat, path)
  if not stat_ok or stat == nil then
    return path .. "\n" .. tostring(limit) .. "\nmissing"
  end
  return table.concat({
    path,
    tostring(limit),
    tostring(stat.size or 0),
    tostring((stat.mtime or {}).sec or 0),
    tostring((stat.mtime or {}).nsec or 0),
  }, "\n")
end

local function load_session()
  local opts = session_options()
  history_limit = opts.history_limit
  if not opts.persist then
    state.session_loaded_path = nil
    return
  end
  local load_signature = session_file_signature(opts.path, opts.history_limit)
  if state.session_loaded_path == load_signature then
    return
  end
  state.session_loaded_path = load_signature
  state.last_target = nil
  state.history = {}
  local read_ok, lines = pcall(vim.fn.readfile, opts.path)
  if not read_ok or type(lines) ~= "table" or #lines == 0 then
    return
  end
  local decode_ok, decoded = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
  if not decode_ok or type(decoded) ~= "table" then
    warn_session("nvim-browser: ignored malformed session state")
    return
  end
  state.last_target = normalize_history_value(decoded.last_target)
  if type(decoded.history) == "table" then
    for index = #decoded.history, 1, -1 do
      local entry = decoded.history[index]
      if type(entry) == "table" then
        add_history_entry(entry.url, entry.title)
      end
    end
  end
end

local function parse_cell_pixels(cell_width_px, cell_height_px)
  local width = tonumber(cell_width_px)
  local height = tonumber(cell_height_px)
  if width == nil or height == nil or width <= 0 or height <= 0 then
    return nil, nil, "viewport cell pixels must be positive numbers"
  end
  if width % 1 ~= 0 or height % 1 ~= 0 then
    return nil, nil, "viewport cell pixels must be positive integers"
  end
  return width, height
end

function M.setup(opts)
  M.config = config.setup(opts)
  load_session()
  terminal.configure(M.config)
  terminal.set_metadata_observer(function(metadata)
    M.record_history(metadata.url, metadata.title)
  end)
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

local function trim_cursor_target(value, opts)
  opts = opts or {}
  if value == nil or value == vim.NIL then
    return nil
  end
  value = tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
  if opts.strip_closing ~= false then
    value = value:gsub("[%)%]}>.,;]+$", "")
  else
    value = value:gsub("[%]}>.,;]+$", "")
  end
  value = value:gsub("^[%(<%[{]+", "")
  if value == "" then
    return nil
  end
  return value
end

local function unescape_markdown_target(value)
  if value == nil then
    return nil
  end
  return value:gsub("\\(.)", "%1")
end

local function cursor_line_and_column()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  return line, (cursor[2] or 0) + 1
end

local function markdown_link_target_under_cursor(line, column)
  local offset = 1
  while offset <= #line do
    local start_index = line:find("%[", offset)
    if start_index == nil then
      return nil
    end
    local label_end = start_index + 1
    while label_end <= #line do
      local char = line:sub(label_end, label_end)
      if char == "\\" then
        label_end = label_end + 2
      elseif char == "]" then
        break
      else
        label_end = label_end + 1
      end
    end
    if label_end > #line or line:sub(label_end + 1, label_end + 1) ~= "(" then
      offset = start_index + 1
      goto continue
    end
    local target_start = label_end + 2
    local index = target_start
    local depth = 0
    local target_end = nil
    while index <= #line do
      local char = line:sub(index, index)
      if char == "\\" then
        index = index + 1
      elseif char == "(" then
        depth = depth + 1
      elseif char == ")" then
        if depth == 0 then
          target_end = index - 1
          break
        end
        depth = depth - 1
      end
      index = index + 1
    end
    if target_end ~= nil then
      if column >= start_index and column <= index then
        local target = line:sub(target_start, target_end)
        target = trim_cursor_target(target:match("^(%S+)") or target, { strip_closing = false })
        return unescape_markdown_target(target)
      end
      offset = index + 1
    else
      offset = label_end + 1
    end
    ::continue::
  end
  return nil
end

local function url_under_cursor(line, column)
  local offset = 1
  while offset <= #line do
    local start_index, end_index = line:find("%f[%S]%a[%w+.-]*://%S+", offset)
    if start_index == nil then
      return nil
    end
    if column >= start_index and column <= end_index then
      return trim_cursor_target(line:sub(start_index, end_index))
    end
    offset = end_index + 1
  end
  return nil
end

local function readable_cursor_file(value)
  value = trim_cursor_target(value)
  if value == nil then
    return nil
  end
  if vim.fn.filereadable(value) == 1 then
    return value
  end
  local expanded = vim.fn.fnamemodify(value, ":p")
  if expanded ~= nil and expanded ~= "" and vim.fn.filereadable(expanded) == 1 then
    return expanded
  end
  return nil
end

local function cfile_under_cursor()
  local ok, value = pcall(vim.fn.expand, "<cfile>")
  if not ok then
    return nil
  end
  return trim_cursor_target(value)
end

local function should_use_cfile_as_target(value)
  return value ~= nil and (value:find("%.", 1, true) ~= nil or value:find("/", 1, true) ~= nil or value:find(":", 1, true) ~= nil)
end

local function is_readable_local_target(value)
  return value ~= nil and not value:match("^%a[%w+.-]*:") and readable_cursor_file(value) ~= nil
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
  record_target(target)
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

function M.calibrate(cell_width_px, cell_height_px)
  if cell_width_px ~= nil or cell_height_px ~= nil then
    local width, height, err = parse_cell_pixels(cell_width_px, cell_height_px)
    if err ~= nil then
      return false, err
    end
    M.config.viewport = M.config.viewport or {}
    M.config.viewport.cell_width_px = width
    M.config.viewport.cell_height_px = height
    terminal.configure({ viewport = M.config.viewport })
  end

  M.open(calibration_fixture_path())
  local report = doctor.run(M.config, terminal.state())
  table.insert(report.lines, 2, "calibration target: " .. calibration_fixture_path())
  for index, line in ipairs(report.lines) do
    if line:find("^calibration:") or line:find("^warning: calibration") then
      report.lines[index] = "calibration: pending runtime metadata; run :NBrowserDoctor after the calibration frame renders"
      break
    end
  end
  return report
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
    set_last_target(target)
  end
  return ok
end

function M.resolve_address_target(input)
  return address.resolve(input, M.config.search_url or config.options.search_url)
end

function M.resolve_cursor_target()
  local line, column = cursor_line_and_column()
  local target = markdown_link_target_under_cursor(line, column)
  if target ~= nil then
    return target
  end
  target = url_under_cursor(line, column)
  if target ~= nil then
    return target
  end
  local cfile = cfile_under_cursor()
  target = readable_cursor_file(cfile)
  if target ~= nil then
    return target
  end
  if should_use_cfile_as_target(cfile) then
    return cfile
  end
  return trim_cursor_target(line)
end

function M.open_under_cursor()
  local target = M.resolve_cursor_target()
  if target == nil then
    return false
  end
  local local_file_target = is_readable_local_target(target)
  if not local_file_target then
    target = M.resolve_address_target(target)
  end
  if target == nil then
    return false
  end
  if has_active_browser_session() then
    if local_file_target then
      target = vim.uri_from_fname(target)
    end
    return M.navigate(target)
  end
  return M.open(target) ~= false
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
    return M.navigate(target)
  end
  local ok = M.open(target)
  return ok ~= false
end

function M.record_history(url, title)
  return record_target(url, title)
end

function M.clear_history()
  state.history = {}
  save_session()
end

function M.history()
  local entries = {}
  for index, entry in ipairs(state.history) do
    entries[index] = { url = entry.url, title = entry.title }
  end
  return entries
end

function M.history_urls()
  local urls = {}
  for _, entry in ipairs(state.history) do
    table.insert(urls, entry.url)
  end
  return urls
end

local function history_picker_label(entry)
  if type(entry) ~= "table" then
    return ""
  end
  if entry.title ~= nil and entry.title ~= "" then
    return entry.title .. " -> " .. entry.url
  end
  return entry.url or ""
end

function M.pick_history(select_or_opts, maybe_opts)
  local select = vim.ui.select
  local opts = maybe_opts or {}
  if type(select_or_opts) == "function" then
    select = select_or_opts
  elseif type(select_or_opts) == "table" then
    opts = select_or_opts
    if type(opts.select) == "function" then
      select = opts.select
    end
  end

  local entries = M.history()
  if #entries == 0 then
    return false
  end
  local completed = false
  local selected = nil
  local action_ok = true
  select(entries, {
    prompt = opts.prompt or "nvim-browser history: ",
    format_item = opts.format_item or history_picker_label,
  }, function(choice)
    completed = true
    selected = choice
    if choice == nil then
      return
    end
    action_ok = M.address(choice.url) ~= false
    if not action_ok and type(opts.on_error) == "function" then
      opts.on_error("action_failed")
    end
  end)
  if completed and selected == nil then
    return false
  end
  if completed and not action_ok then
    return false
  end
  return true
end

function M.resume()
  local target = nil
  if has_active_browser_session() then
    target = normalize_history_value(M.current_url())
  end
  target = target or normalize_history_value(state.last_target)
  if target == nil and #state.history > 0 then
    target = normalize_history_value(state.history[1].url)
  end
  if target == nil then
    return false
  end
  return M.open(target) ~= false
end

local function action_picker_label(item)
  return type(item) == "table" and item.label or ""
end

local function action_echo(message)
  vim.api.nvim_echo({ { tostring(message or "") } }, false, {})
end

local function report_action_error(opts, reason)
  if type(opts.on_error) == "function" then
    opts.on_error(reason)
    return
  end
  vim.api.nvim_echo({ { "nvim-browser: selected browser action failed or browser session is inactive", "WarningMsg" } }, false, {})
end

local function page_scroll_label(metrics)
  if type(metrics) ~= "table" then
    return nil
  end
  local scroll_y = tonumber(metrics.scroll_y)
  local viewport_height = tonumber(metrics.viewport_height)
  local document_height = tonumber(metrics.document_height)
  if scroll_y == nil or viewport_height == nil or document_height == nil then
    return nil
  end
  local scrollable = document_height - viewport_height
  if scrollable <= 0 then
    return "scroll 0%"
  end
  local percent = math.floor(math.max(0, math.min(100, (scroll_y / scrollable) * 100)) + 0.5)
  return "scroll " .. percent .. "%"
end

local function runtime_status_label(runtime)
  if type(runtime) ~= "table" then
    return nil
  end
  local parts = {}
  if runtime.output ~= nil and runtime.output ~= vim.NIL then
    table.insert(parts, "output=" .. tostring(runtime.output))
  end
  if type(runtime.viewport) == "table" then
    local width = runtime.viewport.width
    local height = runtime.viewport.height
    if width ~= nil and height ~= nil then
      table.insert(parts, "viewport=" .. tostring(width) .. "x" .. tostring(height))
    end
  end
  if type(runtime.cells) == "table" then
    local columns = runtime.cells.columns
    local rows = runtime.cells.rows
    if columns ~= nil and rows ~= nil then
      table.insert(parts, "cells=" .. tostring(columns) .. "x" .. tostring(rows))
    end
  end
  if runtime.renderer ~= nil and runtime.renderer ~= vim.NIL then
    table.insert(parts, "renderer=" .. tostring(runtime.renderer))
  end
  if #parts == 0 then
    return nil
  end
  return table.concat(parts, " ")
end

local function focused_element_label(focused)
  if type(focused) ~= "table" then
    return nil
  end
  local kind = focused.kind ~= nil and tostring(focused.kind) or nil
  if kind == nil or kind == "" then
    return nil
  end
  local label = focused.label ~= nil and focused.label ~= vim.NIL and tostring(focused.label) or nil
  if label ~= nil then
    label = label:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if label == "" then
      label = nil
    end
  end
  if label ~= nil then
    return "focus=" .. kind .. " " .. label
  end
  return "focus=" .. kind
end

local function download_status_label(download)
  if type(download) ~= "table" then
    return nil
  end
  local filename = download.suggested_filename
  if filename == nil or filename == vim.NIL or filename == "" then
    local path = download.path
    if path ~= nil and path ~= vim.NIL and path ~= "" then
      filename = vim.fn.fnamemodify(tostring(path), ":t")
    end
  end
  if filename == nil or filename == vim.NIL or filename == "" then
    return "download"
  end
  return "download=" .. tostring(filename)
end

local function action_status_message()
  local parts = { M.status() or "unknown" }
  local title = M.current_title()
  if title ~= nil and title ~= "" then
    table.insert(parts, title)
  end
  local scroll = M.page_metrics and page_scroll_label(M.page_metrics()) or nil
  if scroll ~= nil then
    table.insert(parts, scroll)
  end
  local focused = M.focused_element and focused_element_label(M.focused_element()) or nil
  if focused ~= nil then
    table.insert(parts, focused)
  end
  local download = M.latest_download and download_status_label(M.latest_download()) or nil
  if download ~= nil then
    table.insert(parts, download)
  end
  local runtime = M.runtime_metadata and runtime_status_label(M.runtime_metadata()) or nil
  if runtime ~= nil then
    table.insert(parts, runtime)
  end
  local url = M.current_url()
  if url ~= nil and url ~= "" then
    table.insert(parts, url)
  end
  local error = M.status_error()
  if error ~= nil and error ~= "" then
    table.insert(parts, error)
  end
  return table.concat(parts, " ")
end

local function action_items(opts, report_error)
  return {
    {
      label = "Address",
      run = function()
        local value = (opts.input or vim.fn.input)("nvim-browser address: ", M.current_url() or M.last_target() or "")
        if value == nil or value == "" then
          return true
        end
        return M.address(value)
      end,
    },
    {
      label = "Reload",
      run = function()
        return M.reload()
      end,
    },
    {
      label = "Back",
      run = function()
        return M.back()
      end,
    },
    {
      label = "Forward",
      run = function()
        return M.forward()
      end,
    },
    {
      label = "Find",
      run = function()
        local text = (opts.input or vim.fn.input)("nvim-browser find: ")
        if text == nil or text == "" then
          return true
        end
        return M.find_text(text, { backwards = false })
      end,
    },
    {
      label = "Hints",
      run = function()
        if M.pick_hint ~= nil then
          local hint_error_reported = false
          local hint_canceled = false
          local function report_hint_error(reason)
            hint_error_reported = true
            report_error(reason)
          end
          local function report_hint_cancel()
            hint_canceled = true
          end
          local ok = M.pick_hint({
            select = opts.select,
            input = opts.input,
            on_error = report_hint_error,
            on_cancel = report_hint_cancel,
          }) ~= false
          return ok or (hint_canceled and not hint_error_reported)
        end
        return M.hint_mode(opts.input)
      end,
    },
    {
      label = "Text mode",
      reports_own_error = true,
      run = function()
        return M.start_text_mode()
      end,
    },
    {
      label = "Screenshot",
      run = function()
        local saved_path = nil
        local pending_response = nil
        local function handle_response(response)
          if saved_path == nil then
            pending_response = response
            return
          end
          if type(response) == "table" and response.status == "ok" then
            action_echo("nvim-browser: screenshot saved: " .. tostring(saved_path))
          end
        end
        local ok, path = M.screenshot(nil, {
          on_response = handle_response,
        })
        saved_path = path
        if pending_response ~= nil then
          handle_response(pending_response)
        end
        return ok == true
      end,
    },
    {
      label = "Reader",
      run = function()
        return M.reader()
      end,
    },
    {
      label = "Status",
      run = function()
        local status = action_status_message()
        if type(opts.on_status) == "function" then
          opts.on_status(status)
        else
          action_echo(status)
        end
        return true
      end,
    },
    {
      label = "Doctor",
      run = function()
        local report = M.doctor()
        if type(opts.on_report) == "function" then
          opts.on_report(report)
        elseif report ~= nil then
          action_echo(table.concat(report.lines or {}, "\n"))
        end
        return report ~= nil
      end,
    },
    {
      label = "Close",
      run = function()
        M.close()
        return true
      end,
    },
  }
end

function M.actions(select_or_opts, maybe_opts)
  local select = vim.ui.select
  local opts = maybe_opts or {}
  if type(select_or_opts) == "function" then
    select = select_or_opts
  elseif type(select_or_opts) == "table" then
    opts = select_or_opts
    if type(opts.select) == "function" then
      select = opts.select
    end
  end

  local action_error_reported = false
  local function report_error_once(reason)
    if action_error_reported then
      return
    end
    action_error_reported = true
    report_action_error(opts, reason)
  end
  local items = action_items(opts, report_error_once)
  local completed = false
  local selected = nil
  local action_ok = true
  select(items, {
    prompt = opts.prompt or "nvim-browser action: ",
    format_item = opts.format_item or action_picker_label,
  }, function(choice)
    completed = true
    selected = choice
    if choice == nil then
      return
    end
    action_ok = choice.run() ~= false
    if not action_ok and not choice.reports_own_error then
      report_error_once("action_failed")
    end
  end)

  if completed and selected == nil then
    return true
  end
  if completed and not action_ok then
    return false
  end
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

function M.page_scroll(direction)
  return terminal.page_scroll(direction)
end

function M.page_down()
  return terminal.page_scroll(1)
end

function M.page_up()
  return terminal.page_scroll(-1)
end

function M.scroll_top()
  return terminal.scroll_top()
end

function M.scroll_bottom()
  return terminal.scroll_bottom()
end

function M.half_page_down()
  return terminal.page_scroll(1, { fraction = 0.5 })
end

function M.half_page_up()
  return terminal.page_scroll(-1, { fraction = 0.5 })
end

function M.zoom_in()
  return terminal.zoom_in()
end

function M.zoom_out()
  return terminal.zoom_out()
end

function M.zoom_reset()
  return terminal.zoom_reset()
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

function M.yank_current_url(register)
  return terminal.yank_current_url(register or '"')
end

function M.yank_hint_url(id, register)
  return terminal.yank_hint_url(id, register or '"')
end

local function screenshot_slug(value)
  value = value ~= nil and tostring(value) or ""
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  value = value:gsub("[^%w%-_%.]+", "-")
  value = value:gsub("%-+", "-")
  value = value:gsub("^%-+", ""):gsub("%-+$", "")
  if value == "" then
    return "browser"
  end
  return value:sub(1, 80)
end

local screenshot_name_sequences = {}

local function screenshot_default_path(opts)
  opts = opts or {}
  local stdpath = opts.stdpath or vim.fn.stdpath
  local timestamp = opts.timestamp or function()
    return os.date("%Y%m%d-%H%M%S")
  end
  local base = stdpath("cache") .. "/nvim-browser/screenshots"
  local title = M.current_title()
  local url = M.current_url()
  local name_source = title ~= nil and title ~= "" and title or url ~= nil and url ~= "" and url or "browser"
  local name_key = screenshot_slug(name_source) .. "-" .. timestamp()
  local screenshot_name_sequence = (screenshot_name_sequences[name_key] or 0) + 1
  screenshot_name_sequences[name_key] = screenshot_name_sequence
  local suffix = screenshot_name_sequence > 1 and "-" .. tostring(screenshot_name_sequence) or ""
  return base .. "/" .. name_key .. suffix .. ".png"
end

local function screenshot_prepare_directory(path, opts)
  opts = opts or {}
  local mkdir = opts.mkdir or vim.fn.mkdir
  local directory = vim.fn.fnamemodify(path, ":h")
  if directory == nil or directory == "" or directory == "." then
    return true
  end
  local ok, result = pcall(mkdir, directory, "p")
  return ok and result ~= 0
end

function M.screenshot(path, opts)
  opts = opts or {}
  if path == "" then
    return false, nil
  end
  path = path or screenshot_default_path(opts)
  if not screenshot_prepare_directory(path, opts) then
    return false, path
  end
  return terminal.screenshot(path, opts) == true, path
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

function M.submit_focused()
  return terminal.submit_focused()
end

function M.focus_selector(selector)
  return terminal.focus_selector(selector)
end

function M.click_point(x, y)
  return terminal.click_point(x, y)
end

function M.drag_point(start_x, start_y, end_x, end_y)
  return terminal.drag_point(start_x, start_y, end_x, end_y)
end

function M.select_region(start_row, start_col, end_row, end_col)
  return terminal.select_region(start_row, start_col, end_row, end_col)
end

function M.right_click_point(x, y)
  return terminal.right_click_point(x, y)
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
  set_last_target(target)
  return true
end

function M.click_here()
  return terminal.click_here()
end

function M.right_click_here()
  return terminal.right_click_here()
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

function M.right_click_mouse(mousepos)
  return terminal.right_click_mouse(mousepos)
end

function M.wheel_mouse(delta_y, delta_x, mousepos)
  return terminal.wheel_mouse(delta_y, delta_x, mousepos)
end

function M.click_hint(id)
  return terminal.click_hint(id)
end

function M.right_click_hint(id)
  return terminal.right_click_hint(id)
end

function M.hover_hint(id)
  return terminal.hover_hint(id)
end

function M.focus_hint(id)
  return terminal.focus_hint(id)
end

function M.follow_hint(id)
  return terminal.follow_hint(id)
end

local function hint_identifier(hint)
  if type(hint) ~= "table" then
    return nil
  end
  if hint.hint_label ~= nil and hint.hint_label ~= "" then
    return tostring(hint.hint_label)
  end
  if hint.id ~= nil then
    return tostring(hint.id)
  end
  return nil
end

local function hint_picker_label(hint)
  if type(hint) ~= "table" then
    return ""
  end
  local parts = { hint_identifier(hint) or "?", tostring(hint.kind or "other") }
  local label = hint.label ~= nil and tostring(hint.label) or ""
  if hint.checked ~= nil then
    label = string.format("[%s] %s", hint.checked and "checked" or "unchecked", label)
  end
  if label ~= "" then
    table.insert(parts, label)
  end
  if hint.href ~= nil and hint.href ~= "" then
    table.insert(parts, "-> " .. tostring(hint.href))
  end
  if hint.x ~= nil and hint.y ~= nil then
    table.insert(parts, string.format("@ %.0f,%.0f", hint.x or 0, hint.y or 0))
  end
  return table.concat(parts, " ")
end

local function select_option_picker_label(option)
  if type(option) ~= "table" then
    return ""
  end
  local label = option.label ~= nil and tostring(option.label) or ""
  local value = option.value ~= nil and tostring(option.value) or ""
  local parts = {}
  if option.selected == true then
    table.insert(parts, "[selected]")
  end
  if label ~= "" then
    table.insert(parts, label)
  end
  if value ~= "" and value ~= label then
    table.insert(parts, "(" .. value .. ")")
  end
  return table.concat(parts, " ")
end

local function select_option_choice(option)
  if type(option) ~= "table" then
    return nil
  end
  local value = option.value ~= nil and tostring(option.value) or ""
  if value ~= "" then
    return value
  end
  local label = option.label ~= nil and tostring(option.label) or ""
  if label ~= "" then
    return label
  end
  return nil
end

local function select_hints_with_options(hints)
  local selectable = {}
  for _, hint in ipairs(hints) do
    if type(hint) == "table" and type(hint.options) == "table" and #hint.options > 0 then
      table.insert(selectable, hint)
    end
  end
  return selectable
end

local function enabled_select_options(hint)
  local enabled = {}
  if type(hint) ~= "table" or type(hint.options) ~= "table" then
    return enabled
  end
  for _, option in ipairs(hint.options) do
    if type(option) == "table" and option.disabled ~= true then
      table.insert(enabled, option)
    end
  end
  return enabled
end

local function select_hints_with_enabled_options(hints)
  local selectable = {}
  for _, hint in ipairs(hints) do
    if #enabled_select_options(hint) > 0 then
      table.insert(selectable, hint)
    end
  end
  return selectable
end

local function input_like_hints(hints)
  local inputs = {}
  for _, hint in ipairs(hints) do
    if type(hint) == "table" and (hint.kind == "input" or hint.kind == "text_area" or hint.kind == "editable") then
      table.insert(inputs, hint)
    end
  end
  return inputs
end

local function upload_like_hints(hints)
  local uploads = {}
  for _, hint in ipairs(hints) do
    if type(hint) == "table" and hint.kind == "file" then
      table.insert(uploads, hint)
    end
  end
  return uploads
end

local function href_hints(hints)
  local links = {}
  for _, hint in ipairs(hints) do
    if type(hint) == "table" and hint.href ~= nil and hint.href ~= "" then
      table.insert(links, hint)
    end
  end
  return links
end

local function pick_hint_action(action)
  if action == nil or action == "" or action == "follow" then
    return M.follow_hint
  end
  if action == "click" then
    return M.click_hint
  end
  if action == "right-click" then
    return M.right_click_hint
  end
  if action == "focus" then
    return M.focus_hint
  end
  if action == "hover" then
    return M.hover_hint
  end
  if action == "toggle" then
    return M.toggle_hint
  end
  if action == "type" or action == "submit" then
    return M.type_hint
  end
  if action == "select" then
    return M.select_hint
  end
  if action == "upload" then
    return M.upload_hint
  end
  if action == "yank-url" then
    return M.yank_hint_url
  end
  return nil
end

function M.pick_hint_action_available(action)
  return pick_hint_action(action) ~= nil
end

function M.pick_hint(select_or_opts, maybe_opts)
  local select = vim.ui.select
  local opts = maybe_opts or {}
  if type(select_or_opts) == "function" then
    select = select_or_opts
  elseif type(select_or_opts) == "table" then
    opts = select_or_opts
    if type(opts.select) == "function" then
      select = opts.select
    end
  end

  local hints = M.hints()
  if #hints == 0 then
    return false
  end
  local action_name = opts.action or "follow"
  local action = pick_hint_action(action_name)
  if action == nil then
    return false
  end
  if action_name == "type" or action_name == "submit" then
    hints = input_like_hints(hints)
    if #hints == 0 then
      return false
    end
  elseif action_name == "select" then
    hints = select_hints_with_enabled_options(hints)
    if #hints == 0 then
      return false
    end
  elseif action_name == "upload" then
    hints = upload_like_hints(hints)
    if #hints == 0 then
      return false
    end
  elseif action_name == "yank-url" then
    hints = href_hints(hints)
    if #hints == 0 then
      return false
    end
  end

  local selected = nil
  local completed = false
  local action_ok = true
  local error_reported = false
  local input = opts.input or vim.fn.input
  local function report_error(reason)
    if not error_reported and type(opts.on_error) == "function" then
      error_reported = true
      opts.on_error(reason)
    end
  end
  select(hints, {
    prompt = opts.prompt or "nvim-browser hint: ",
    format_item = opts.format_item or hint_picker_label,
  }, function(choice)
    completed = true
    selected = choice
    if choice == nil then
      return
    end
    local identifier = hint_identifier(choice)
    if identifier ~= nil then
      if action_name == "type" or action_name == "submit" then
        local text = input("nvim-browser text: ")
        if text == nil or text == "" then
          return
        end
        action_ok = action(identifier, text, { submit = action_name == "submit" }) ~= false
      elseif action_name == "select" then
        local options = enabled_select_options(choice)
        if #options == 0 then
          action_ok = false
          report_error("no_enabled_options")
          return
        end
        select(options, {
          prompt = "nvim-browser option: ",
          format_item = select_option_picker_label,
        }, function(option)
          if option == nil then
            return
          end
          local option_choice = select_option_choice(option)
          if option_choice == nil then
            action_ok = false
            report_error("missing_identifier")
            return
          end
          action_ok = action(identifier, option_choice) ~= false
          if not action_ok then
            report_error("action_failed")
          end
        end)
      elseif action_name == "upload" then
        local path = input("nvim-browser file: ")
        if path == nil or path == "" then
          return
        end
        action_ok = action(identifier, { path }) ~= false
      elseif action_name == "yank-url" then
        action_ok = action(identifier, opts.register or '"') ~= false
      else
        action_ok = action(identifier) ~= false
      end
      if not action_ok then
        report_error("action_failed")
      end
    else
      report_error("missing_identifier")
    end
  end)

  if completed and selected == nil then
    if type(opts.on_cancel) == "function" then
      opts.on_cancel()
    end
    return false
  end
  if completed and not action_ok then
    return false
  end
  return true
end

function M.type_hint(id, text, opts)
  return terminal.type_hint(id, text, opts)
end

function M.select_hint(id, choice)
  return terminal.select_hint(id, choice)
end

function M.upload_hint(id, paths)
  if type(paths) == "string" then
    paths = { paths }
  end
  return terminal.upload_hint(id, paths)
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

function M.select_hint_mode(input_or_opts, maybe_opts)
  local input = vim.fn.input
  local select = vim.ui.select
  local opts = maybe_opts or {}
  if type(input_or_opts) == "function" then
    input = input_or_opts
  elseif type(input_or_opts) == "table" then
    opts = input_or_opts
  elseif input_or_opts ~= nil then
    input = input_or_opts
  end
  if type(opts.input) == "function" then
    input = opts.input
  end
  if type(opts.select) == "function" then
    select = opts.select
  end

  local hints = M.hints()
  if #hints == 0 then
    return false
  end

  local selectable = select_hints_with_options(hints)
  if #selectable > 0 then
    local selected_hint = nil
    local selected_option = nil
    local completed_hint = false
    local completed_option = false
    local action_ok = true
    select(selectable, {
      prompt = "nvim-browser hint: ",
      format_item = hint_picker_label,
    }, function(hint)
      completed_hint = true
      selected_hint = hint
      if hint == nil then
        return
      end
      local options = enabled_select_options(hint)
      if #options == 0 then
        action_ok = false
        if type(opts.on_error) == "function" then
          opts.on_error("no_enabled_options")
        end
        return
      end
      select(options, {
        prompt = "nvim-browser option: ",
        format_item = select_option_picker_label,
      }, function(option)
        completed_option = true
        selected_option = option
        if option == nil then
          return
        end
        local identifier = hint_identifier(hint)
        local choice = select_option_choice(option)
        if identifier == nil or choice == nil then
          action_ok = false
          if type(opts.on_error) == "function" then
            opts.on_error("missing_identifier")
          end
          return
        end
        action_ok = M.select_hint(identifier, choice) ~= false
        if not action_ok and type(opts.on_error) == "function" then
          opts.on_error("action_failed")
        end
      end)
    end)

    if completed_hint and selected_hint == nil then
      return false
    end
    if completed_option and selected_option == nil then
      return false
    end
    if (completed_hint or completed_option) and not action_ok then
      return false
    end
    return true
  end

  local label = input("nvim-browser hint: ")
  if label == nil or label == "" then
    return false
  end
  local choice = input("nvim-browser option: ")
  if choice == nil or choice == "" then
    return false
  end
  local ok = M.select_hint(label, choice)
  if not ok and type(opts.on_error) == "function" then
    opts.on_error("action_failed")
  end
  return ok
end

function M.focus_hint_mode(input)
  input = input or vim.fn.input
  if #M.hints() == 0 then
    return false
  end
  local label = input("nvim-browser hint: ")
  if label == nil or label == "" then
    return false
  end
  return M.focus_hint(label)
end

function M.upload_hint_mode(input)
  input = input or vim.fn.input
  if #M.hints() == 0 then
    return false
  end
  local label = input("nvim-browser hint: ")
  if label == nil or label == "" then
    return false
  end
  local path = input("nvim-browser file: ")
  if path == nil or path == "" then
    return false
  end
  return M.upload_hint(label, { path })
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

function M.focused_element()
  return terminal.state().focused_element
end

function M.latest_download()
  return terminal.state().latest_download
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

function M.last_find_match_count()
  return terminal.state().last_find_match_count
end

function M.hints()
  return terminal.state().element_hints or {}
end

M.setup()

return M
