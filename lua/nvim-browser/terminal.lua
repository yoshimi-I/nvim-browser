local M = {}
local hints_overlay = require("nvim-browser.hints_overlay")
local status_labels = require("nvim-browser.status")

local state = {
  bufnr = nil,
  winid = nil,
  job_id = nil,
  image_id = 1,
  generation = 0,
  last_payload = nil,
  last_payload_is_unicode = false,
  last_target = nil,
  stream_buffer = "",
  mode = nil,
  serve_output = nil,
  last_serve_command = nil,
  next_request_id = 1,
  stop_timer = nil,
  resize_autocmd = nil,
  resize_timer = nil,
  current_url = nil,
  current_title = nil,
  page_metrics = nil,
  focused_element = nil,
  latest_download = nil,
  download_history = {},
  download_recorded_response_ids = {},
  latest_dialog = nil,
  dialog_history = {},
  calibration_state = nil,
  runtime_metadata = nil,
  rendered_frame_geometry = nil,
  status = nil,
  status_error = nil,
  hint_error = nil,
  pending_operation = nil,
  operation_watchdog_timer = nil,
  operation_watchdog_request_id = nil,
  navigation_admission_id = nil,
  navigation_suppressed_request_ids = {},
  live_refresh_timer = nil,
  live_refresh_generation = 0,
  live_refresh_request_id = nil,
  live_refresh_request_type = nil,
  adaptive_capture_timer = nil,
  scroll_coalesce_timer = nil,
  scroll_coalesce_request = nil,
  stopped_operation = nil,
  canceled_request_ids = {},
  quiet_request_ids = {},
  latest_applied_response_id = 0,
  latest_find_request_id = nil,
  last_find_found = nil,
  last_find_match_count = nil,
  last_find_query = nil,
  response_handlers = {},
  metadata_observer = nil,
  download_observer = nil,
  element_hints = {},
  element_hints_geometry = nil,
  cursor_addressable_preview = false,
  text_mode_active = false,
  text_mode_flush_timer = nil,
  zoom_scale = 1.0,
  reader_bufnr = nil,
  reader_base_url = nil,
  latest_reader_request_id = nil,
  latest_page_text_yank_request_id = nil,
}

local options = {
  live_refresh = {
    enabled = true,
    interval_ms = 1500,
  },
  viewport = {
    cell_width_px = 10,
    cell_height_px = 20,
  },
  navigation_timeout_ms = 20000,
}

local timer_factory = function()
  return vim.loop.new_timer()
end

local kitty_placeholder = vim.fn.nr2char(0x10eeee)
local serve_footer_rows = 1
local kitty_diacritics = {
  0x0305, 0x030d, 0x030e, 0x0310, 0x0312, 0x033d, 0x033e, 0x033f,
  0x0346, 0x034a, 0x034b, 0x034c, 0x0350, 0x0351, 0x0352, 0x0357,
  0x035b, 0x0363, 0x0364, 0x0365, 0x0366, 0x0367, 0x0368, 0x0369,
  0x036a, 0x036b, 0x036c, 0x036d, 0x036e, 0x036f, 0x0483, 0x0484,
  0x0485, 0x0486, 0x0487, 0x0592, 0x0593, 0x0594, 0x0595, 0x0597,
  0x0598, 0x0599, 0x059c, 0x059d, 0x059e, 0x059f, 0x05a0, 0x05a1,
  0x05a8, 0x05a9, 0x05ab, 0x05ac, 0x05af, 0x05c4, 0x0610, 0x0611,
  0x0612, 0x0613, 0x0614, 0x0615, 0x0616, 0x0617, 0x0657, 0x0658,
  0x0659, 0x065a, 0x065b, 0x065d, 0x065e, 0x06d6, 0x06d7, 0x06d8,
  0x06d9, 0x06da, 0x06db, 0x06dc, 0x06df, 0x06e0, 0x06e1, 0x06e2,
  0x06e4, 0x06e7, 0x06e8, 0x06eb, 0x06ec, 0x0730, 0x0732, 0x0733,
  0x0735, 0x0736, 0x073a, 0x073d, 0x073f, 0x0740, 0x0741, 0x0743,
  0x0745, 0x0747, 0x0749, 0x074a, 0x07eb, 0x07ec, 0x07ed, 0x07ee,
  0x07ef, 0x07f0, 0x07f1, 0x0816, 0x0817, 0x0818, 0x0819, 0x081b,
  0x081c, 0x081d, 0x081e, 0x081f, 0x0820, 0x0821, 0x0822, 0x0823,
}
local hint_label_keys = {
  "a", "s", "d", "f", "g", "h", "j", "k", "l",
  "q", "w", "e", "r", "t", "y", "u", "i", "o", "p",
  "z", "x", "c", "v", "b", "n", "m",
}

local resize_augroup = vim.api.nvim_create_augroup("nvim-browser-resize", { clear = true })

local function preview_width()
  return math.max(40, math.min(120, math.floor(vim.o.columns * 0.48)))
end

local function is_valid_buffer()
  return state.bufnr ~= nil and vim.api.nvim_buf_is_valid(state.bufnr)
end

local function is_valid_window()
  return state.winid ~= nil and vim.api.nvim_win_is_valid(state.winid)
end

local function is_valid_window_id(winid)
  return winid ~= nil and vim.api.nvim_win_is_valid(winid)
end

local function create_window()
  vim.cmd("botright vertical split")
  vim.cmd("vertical resize " .. preview_width())
  state.winid = vim.api.nvim_get_current_win()
end

local function command_uses_browse_output(command, output)
  if type(command) ~= "table" or command[2] ~= "browse" then
    return false
  end

  for index, value in ipairs(command) do
    if value == "--output" and command[index + 1] == output then
      return true
    end
  end

  return false
end

local function command_uses_serve_output(command, output)
  if type(command) ~= "table" or command[2] ~= "serve" then
    return false
  end

  for index, value in ipairs(command) do
    if value == "--output" and command[index + 1] == output then
      return true
    end
  end

  return false
end

local function command_uses_ansi_browse(command)
  return command_uses_browse_output(command, "ansi")
end

local function command_uses_kitty_browse(command)
  return command_uses_browse_output(command, "kitty")
end

local function command_uses_kitty_unicode_browse(command)
  return command_uses_browse_output(command, "kitty-unicode")
end

local function command_uses_ansi_serve(command)
  return command_uses_serve_output(command, "ansi")
end

local function command_uses_kitty_serve(command)
  return command_uses_serve_output(command, "kitty")
end

local function command_uses_kitty_unicode_serve(command)
  return command_uses_serve_output(command, "kitty-unicode")
end

local function command_uses_serve(command)
  return type(command) == "table" and command[2] == "serve"
end

local function command_output(command)
  if type(command) ~= "table" then
    return nil
  end
  for index, value in ipairs(command) do
    if value == "--output" then
      return command[index + 1]
    end
  end
  return nil
end

local function command_uses_show_image(command)
  return type(command) == "table" and command[2] == "show-image"
end

local function command_uses_captured_browse(command)
  return command_uses_ansi_browse(command)
    or command_uses_kitty_browse(command)
    or command_uses_kitty_unicode_browse(command)
end

local function output_is_cursor_addressable(output)
  return output == "ansi" or output == "kitty-unicode"
end

local function command_has_columns(command)
  return vim.tbl_contains(command, "--columns")
end

local function command_has_option(command, option)
  for _, value in ipairs(command) do
    if value == option then
      return true
    end
  end

  return false
end

local function command_option_value(command, option)
  for index, value in ipairs(command) do
    if value == option then
      return tonumber(command[index + 1])
    end
  end
  return nil
end

local function kitty_unicode_cell_limit()
  return #kitty_diacritics
end

local function preview_cells(opts)
  opts = opts or {}
  local reserved_rows = opts.reserve_footer and serve_footer_rows or 0
  local columns = math.max(20, vim.api.nvim_win_get_width(state.winid) - 2)
  local rows = math.max(6, vim.api.nvim_win_get_height(state.winid) - 2 - reserved_rows)
  if opts.cap_kitty_unicode then
    local limit = kitty_unicode_cell_limit()
    columns = math.min(columns, limit)
    rows = math.min(rows, limit)
  end
  return {
    columns = columns,
    rows = rows,
  }
end

local function viewport_cell_pixels()
  local viewport = options.viewport or {}
  return {
    width = math.max(1, tonumber(viewport.cell_width_px) or 10),
    height = math.max(1, tonumber(viewport.cell_height_px) or 20),
  }
end

local function current_preview_geometry()
  local runtime_output = type(state.runtime_metadata) == "table" and state.runtime_metadata.output or nil
  local cap_kitty_unicode = state.serve_output == "kitty-unicode" or runtime_output == "kitty-unicode"
  local cells = preview_cells({ reserve_footer = state.mode == "serve", cap_kitty_unicode = cap_kitty_unicode })
  local cell = viewport_cell_pixels()
  return {
    columns = cells.columns,
    rows = cells.rows,
    width = cells.columns * cell.width,
    height = cells.rows * cell.height,
  }
end

local function valid_preview_geometry()
  if not is_valid_window() then
    return nil
  end
  return current_preview_geometry()
end

local function add_option(command, option, value)
  if command_has_option(command, option) then
    return
  end

  table.insert(command, option)
  table.insert(command, tostring(value))
end

local function set_option(command, option, value)
  local index = 1
  while index <= #command do
    if command[index] == option then
      table.remove(command, index)
      if index <= #command then
        table.remove(command, index)
      end
    else
      index = index + 1
    end
  end

  table.insert(command, option)
  table.insert(command, tostring(value))
end

local function command_for_window(command)
  if
    not command_uses_ansi_browse(command)
    and not command_uses_kitty_browse(command)
    and not command_uses_kitty_unicode_browse(command)
    and not command_uses_serve(command)
    and not command_uses_show_image(command)
  then
    return command
  end

  local adjusted = vim.list_extend({}, command)

  if command_uses_show_image(command) then
    local cells = preview_cells()
    local cell = viewport_cell_pixels()
    add_option(adjusted, "--columns", cells.columns)
    add_option(adjusted, "--rows", cells.rows)
    add_option(adjusted, "--width", cells.columns * cell.width)
    add_option(adjusted, "--height", cells.rows * cell.height)
    return adjusted
  end

  local reserve_footer = command_uses_serve(command)

  if command_uses_ansi_browse(command) and not command_uses_ansi_serve(command) then
    add_option(adjusted, "--columns", preview_cells().columns)
    return adjusted
  end

  local cap_kitty_unicode = command_uses_kitty_unicode_browse(command) or command_uses_kitty_unicode_serve(command)
  local cells = preview_cells({
    reserve_footer = reserve_footer,
    cap_kitty_unicode = cap_kitty_unicode,
  })
  local cell = viewport_cell_pixels()
  local write_option = cap_kitty_unicode and set_option or add_option
  write_option(adjusted, "--columns", cells.columns)
  write_option(adjusted, "--rows", cells.rows)
  write_option(adjusted, "--width", cells.columns * cell.width)
  write_option(adjusted, "--height", cells.rows * cell.height)
  return adjusted
end

local function command_target(command)
  if type(command) ~= "table" then
    return nil
  end
  if command[2] == "serve" then
    for index, value in ipairs(command) do
      if value == "--url" then
        return command[index + 1]
      end
    end
    return nil
  end
  return command[3]
end

local function copy_command(command)
  if type(command) ~= "table" then
    return nil
  end
  return vim.list_extend({}, command)
end

local function command_with_target(command, target)
  local adjusted = copy_command(command)
  if adjusted == nil or target == nil or target == "" then
    return adjusted
  end
  if adjusted[2] ~= "serve" then
    return adjusted
  end
  for index, value in ipairs(adjusted) do
    if value == "--url" then
      adjusted[index + 1] = target
      return adjusted
    end
    if value == "--markdown" then
      table.remove(adjusted, index + 1)
      table.remove(adjusted, index)
      break
    end
  end
  table.insert(adjusted, "--url")
  table.insert(adjusted, target)
  return adjusted
end

local function kitty_placeholder_lines(columns, rows)
  local max_index = #kitty_diacritics
  columns = math.max(1, math.min(columns, max_index))
  rows = math.max(1, math.min(rows, max_index))

  local lines = {}
  for row = 0, rows - 1 do
    local row_mark = vim.fn.nr2char(kitty_diacritics[row + 1])
    local cells = {}
    for column = 0, columns - 1 do
      local column_mark = vim.fn.nr2char(kitty_diacritics[column + 1])
      table.insert(cells, kitty_placeholder .. row_mark .. column_mark)
    end
    table.insert(lines, table.concat(cells))
  end
  return lines
end

local function apply_kitty_placeholder_highlight(bufnr, rows)
  vim.api.nvim_set_hl(0, "NBrowserKittyImage", { fg = "#000001", ctermfg = 1 })
  local namespace = vim.api.nvim_create_namespace("nvim-browser-kitty-image")
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  for row = 0, rows - 1 do
    vim.api.nvim_buf_add_highlight(bufnr, namespace, "NBrowserKittyImage", row, 0, -1)
  end
end

local function kitty_cleanup_escape()
  local escapes = { "\x1b_Ga=d,d=i,i=" .. state.image_id .. "\x1b\\" }
  for image_id = 2, 257 do
    table.insert(escapes, "\x1b_Ga=d,d=i,i=" .. image_id .. "\x1b\\")
  end
  return table.concat(escapes)
end

local function terminal_escape(payload)
  if vim.env.TMUX == nil or vim.env.TMUX == "" or payload == nil or payload == "" then
    return payload
  end

  return "\x1bPtmux;" .. payload:gsub("\x1b", "\x1b\x1b") .. "\x1b\\"
end

local function send_terminal_escape(payload)
  vim.api.nvim_chan_send(vim.v.stderr, terminal_escape(payload))
end

local is_navigation_class_request
local stop_operation_watchdog_timer
local schedule_operation_watchdog
local hard_stop_pending_operation
local hard_stop_capture_operation

local function send_serve_request(request, on_response)
  if state.mode ~= "serve" or state.job_id == nil then
    return false
  end

  request.id = state.next_request_id
  state.next_request_id = state.next_request_id + 1
  if state.navigation_admission_id ~= nil and not is_navigation_class_request(request) then
    state.navigation_suppressed_request_ids[request.id] = true
  end
  if request.capture == false then
    state.quiet_request_ids[request.id] = true
  end
  if on_response ~= nil then
    state.response_handlers[request.id] = on_response
  end
  local ok, sent = pcall(vim.fn.chansend, state.job_id, vim.json.encode(request) .. "\n")
  if not ok or sent == 0 then
    state.quiet_request_ids[request.id] = nil
    state.navigation_suppressed_request_ids[request.id] = nil
    state.response_handlers[request.id] = nil
    return false
  end
  return true, request.id
end

local function should_apply_find_response(response)
  if response.id ~= nil and response.id ~= vim.NIL and state.canceled_request_ids[response.id] then
    return false
  end

  if
    response.id ~= nil
    and response.id ~= vim.NIL
    and state.latest_find_request_id ~= nil
    and response.id ~= state.latest_find_request_id
  then
    return false
  end

  return true
end

local function handle_find_text_response(response)
  if not should_apply_find_response(response) then
    return
  end

  if response.status ~= "ok" then
    state.last_find_found = nil
    state.last_find_match_count = nil
    return
  end

  state.last_find_found = response.found == true
  if response.match_count ~= nil and response.match_count ~= vim.NIL then
    state.last_find_match_count = math.max(0, math.floor(tonumber(response.match_count) or 0))
  else
    state.last_find_match_count = nil
  end
  if response.found == false then
    vim.api.nvim_echo({ { "nvim-browser: text was not found", "WarningMsg" } }, false, {})
  end
end

local function reader_buffer_name(snapshot)
  local title = snapshot and snapshot.title
  if title == nil or title == "" or title == vim.NIL then
    title = snapshot and snapshot.url or "page"
  end
  title = tostring(title):gsub("[/\\:]", "-")
  if title == "" then
    title = "page"
  end
  return "nvim-browser-reader://" .. title
end

local function reader_url_at_line(line, column)
  if line == nil or line == "" then
    return nil
  end
  column = tonumber(column) or 1

  local function unescape_markdown(value)
    return value:gsub("\\(.)", "%1")
  end

  local function is_supported_reader_url(value)
    return type(value) == "string"
      and (
        value:match("^https?://") ~= nil
        or value:match("^file://") ~= nil
        or value:match("^/") ~= nil
        or value:match("^#") ~= nil
        or value:match("^[^%s:]+$") ~= nil
      )
  end

  local candidates = {}
  local link_ranges = {}
  local function add_link_range(start_index, end_index)
    table.insert(link_ranges, { start_index = start_index, end_index = end_index })
  end
  local function add_candidate(url, start_index, end_index)
    add_link_range(start_index, end_index)
    if url ~= nil and url ~= "" and is_supported_reader_url(url) then
      table.insert(candidates, { url = url, start_index = start_index, end_index = end_index })
    end
  end
  local function overlaps_existing(start_index, end_index)
    for _, link_range in ipairs(link_ranges) do
      if start_index <= link_range.end_index and end_index >= link_range.start_index then
        return true
      end
    end
    return false
  end

  local index = 1
  while index <= #line do
    local label_start = line:find("%[", index)
    if label_start == nil then
      break
    end
    local cursor = label_start + 1
    while cursor <= #line do
      local char = line:sub(cursor, cursor)
      if char == "\\" then
        cursor = cursor + 2
      elseif char == "]" then
        break
      else
        cursor = cursor + 1
      end
    end
    if cursor <= #line and line:sub(cursor + 1, cursor + 1) == "(" then
      local url_start = cursor + 2
      cursor = url_start
      while cursor <= #line do
        local char = line:sub(cursor, cursor)
        if char == "\\" then
          cursor = cursor + 2
        elseif char == ")" then
          break
        else
          cursor = cursor + 1
        end
      end
      if cursor <= #line then
        local link_end = cursor
        local url = unescape_markdown(line:sub(url_start, cursor - 1))
        add_candidate(url, label_start, link_end)
        index = link_end + 1
      else
        index = label_start + 1
      end
    else
      index = label_start + 1
    end
  end

  local search_start = 1
  while true do
    local start_index, end_index, url = line:find("<(https?://[^>%s]+)>", search_start)
    if start_index == nil then
      break
    end
    if not overlaps_existing(start_index, end_index) then
      add_candidate(url, start_index, end_index)
    end
    search_start = end_index + 1
  end

  search_start = 1
  while true do
    local start_index, end_index, url = line:find("<(file://[^>%s]+)>", search_start)
    if start_index == nil then
      break
    end
    if not overlaps_existing(start_index, end_index) then
      add_candidate(url, start_index, end_index)
    end
    search_start = end_index + 1
  end

  search_start = 1
  while true do
    local start_index, end_index, url = line:find("(https?://[^%s%)>%]]+)", search_start)
    if start_index == nil then
      break
    end
    if not overlaps_existing(start_index, end_index) then
      add_candidate(url, start_index, end_index)
    end
    search_start = end_index + 1
  end

  search_start = 1
  while true do
    local start_index, end_index, url = line:find("(file://[^%s%)>%]]+)", search_start)
    if start_index == nil then
      break
    end
    if not overlaps_existing(start_index, end_index) then
      add_candidate(url, start_index, end_index)
    end
    search_start = end_index + 1
  end

  for _, candidate in ipairs(candidates) do
    if column >= candidate.start_index and column <= candidate.end_index then
      return candidate.url
    end
  end
  if #candidates == 1 then
    if #link_ranges == 1 then
      return candidates[1].url
    end
  end
  return nil
end

local function has_url_scheme(value)
  return type(value) == "string" and value:match("^%a[%w+.-]*:") ~= nil
end

local function normalize_reader_path(path)
  if type(path) ~= "string" or path == "" then
    return "/"
  end
  local absolute = path:sub(1, 1) == "/"
  local trailing_slash = path:sub(-1) == "/" or path:match("/%.$") ~= nil or path:match("/%.%.$") ~= nil
  local segments = {}
  local index = 1
  while index <= #path do
    local next_slash = path:find("/", index, true)
    local segment
    if next_slash == nil then
      segment = path:sub(index)
      index = #path + 1
    else
      segment = path:sub(index, next_slash - 1)
      index = next_slash + 1
    end
    if segment == ".." then
      if #segments > 0 then
        table.remove(segments)
      end
    elseif segment == "." then
      -- skip explicit current-directory segments
    elseif segment ~= "" or #segments > 0 then
      table.insert(segments, segment)
    end
  end
  local normalized = table.concat(segments, "/")
  if absolute then
    normalized = "/" .. normalized
  end
  if normalized == "" then
    normalized = absolute and "/" or "."
  end
  if trailing_slash and normalized ~= "/" then
    normalized = normalized .. "/"
  end
  return normalized
end

local function normalize_reader_reference(reference)
  local path, suffix = tostring(reference):match("^([^?#]*)([?#].*)$")
  if path == nil then
    path = tostring(reference)
    suffix = ""
  end
  return normalize_reader_path(path) .. suffix
end

local function reader_resolve_url(target, base)
  if target == nil or target == "" then
    return nil
  end
  if has_url_scheme(target) then
    return target
  end
  if base == nil or base == "" or not has_url_scheme(base) then
    return nil
  end
  if target:sub(1, 1) == "#" then
    return (base:gsub("#.*$", "")) .. target
  end
  if target:sub(1, 1) == "?" then
    return (base:gsub("[?#].*$", "")) .. target
  end
  local scheme, authority, path_prefix = base:match("^(https?://)([^/#?]+)([^#?]*)")
  if scheme ~= nil then
    if target:sub(1, 1) == "/" then
      return scheme .. authority .. target
    end
    local directory = path_prefix:gsub("[^/]*$", "")
    if directory == "" then
      directory = "/"
    end
    return scheme .. authority .. normalize_reader_reference(directory .. target)
  end
  local file_path = base:match("^file://([^#?]*)")
  if file_path == nil then
    return nil
  end
  if target:sub(1, 1) == "/" then
    return "file://" .. target
  end
  local directory = file_path:gsub("[^/]*$", "")
  if directory == "" then
    directory = "/"
  end
  return "file://" .. normalize_reader_reference(directory .. target)
end

local function warn_reader_follow(message)
  vim.api.nvim_echo({ { message, "WarningMsg" } }, false, {})
end

local function install_reader_keymaps(bufnr)
  local function follow()
    M.reader_follow()
  end
  vim.keymap.set("n", "<CR>", follow, { buffer = bufnr, silent = true, desc = "nvim-browser: follow reader link" })
  vim.keymap.set("n", "gf", follow, { buffer = bufnr, silent = true, desc = "nvim-browser: follow reader link" })
end

local function delete_reader_buffer()
  if state.reader_bufnr ~= nil and vim.api.nvim_buf_is_valid(state.reader_bufnr) then
    vim.api.nvim_buf_delete(state.reader_bufnr, { force = true })
  end
  state.reader_bufnr = nil
  state.reader_base_url = nil
end

local function apply_reader_snapshot(snapshot)
  if state.reader_bufnr == nil or not vim.api.nvim_buf_is_valid(state.reader_bufnr) then
    state.reader_bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[state.reader_bufnr].buftype = "nofile"
    vim.bo[state.reader_bufnr].bufhidden = "hide"
    vim.bo[state.reader_bufnr].swapfile = false
    vim.bo[state.reader_bufnr].filetype = "markdown"
    install_reader_keymaps(state.reader_bufnr)
  end
  pcall(vim.api.nvim_buf_set_name, state.reader_bufnr, reader_buffer_name(snapshot))
  local lines = {}
  if snapshot.url ~= nil and snapshot.url ~= "" then
    table.insert(lines, "<" .. snapshot.url .. ">")
    table.insert(lines, "")
    state.reader_base_url = snapshot.url
  end
  vim.list_extend(lines, vim.split(snapshot.text or "", "\n", { plain = true }))
  if snapshot.truncated == true then
    local last_line = lines[#lines]
    if last_line ~= "[truncated]" then
      table.insert(lines, "")
      table.insert(lines, "[truncated]")
    end
  end
  vim.bo[state.reader_bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(state.reader_bufnr, 0, -1, false, lines)
  vim.bo[state.reader_bufnr].modifiable = false
  vim.cmd("botright split")
  vim.api.nvim_win_set_buf(0, state.reader_bufnr)
end

local function handle_reader_response(response)
  if
    response.id ~= nil
    and state.latest_reader_request_id ~= nil
    and tonumber(response.id) ~= nil
    and tonumber(response.id) < state.latest_reader_request_id
  then
    return
  end
  if response.status ~= "ok" or response.text == nil or response.text == vim.NIL then
    delete_reader_buffer()
    vim.api.nvim_echo({ { "nvim-browser: reader snapshot failed", "WarningMsg" } }, false, {})
    return
  end
  if response.text.text == nil or response.text.text == "" or response.text.text == vim.NIL then
    delete_reader_buffer()
    vim.api.nvim_echo({ { "nvim-browser: reader snapshot was empty", "WarningMsg" } }, false, {})
    return
  end
  apply_reader_snapshot(response.text)
end

local function warn_selection_yank_failed()
  vim.api.nvim_echo({ { "nvim-browser: browser selection yank failed or no browser selection is active", "WarningMsg" } }, false, {})
end

local function warn_page_text_yank_failed()
  vim.api.nvim_echo({ { "nvim-browser: page text yank failed or snapshot was empty", "WarningMsg" } }, false, {})
end

local function handle_yank_page_text_response(register)
  return function(response)
    if
      response.id ~= nil
      and state.latest_page_text_yank_request_id ~= nil
      and tonumber(response.id) ~= nil
      and tonumber(response.id) < state.latest_page_text_yank_request_id
    then
      return
    end
    if
      response.status ~= "ok"
      or type(response.text) ~= "table"
      or response.text.text == nil
      or response.text.text == vim.NIL
      or response.text.text == ""
    then
      warn_page_text_yank_failed()
      return
    end
    local ok = pcall(vim.fn.setreg, register, response.text.text, "v")
    if not ok then
      warn_page_text_yank_failed()
    end
  end
end

local function handle_yank_selection_response(register)
  return function(response)
    if response.status ~= "ok" or response.selection == nil or response.selection == vim.NIL or response.selection == "" then
      warn_selection_yank_failed()
      return
    end
    local ok = pcall(vim.fn.setreg, register, response.selection, "v")
    if not ok then
      warn_selection_yank_failed()
    end
  end
end

local function valid_register(register)
  if type(register) ~= "string" or #register ~= 1 then
    return false
  end
  local value_ok, previous_value = pcall(vim.fn.getreg, register)
  local type_ok, previous_type = pcall(vim.fn.getregtype, register)
  if not value_ok or not type_ok then
    return false
  end
  local ok = pcall(vim.fn.setreg, register, previous_value, previous_type)
  if ok then
    pcall(vim.fn.setreg, register, previous_value, previous_type)
  end
  return ok
end

local function set_register(register, value, regtype)
  if not valid_register(register) or value == nil or value == vim.NIL or value == "" then
    return false
  end
  return pcall(vim.fn.setreg, register, value, regtype or "v")
end

local rendered_frame_geometry_from_runtime

local function parse_calibration_state(text)
  if type(text) ~= "string" then
    return nil
  end
  if not text:find("calibration%-click:", 1, false) and not text:find("calibration%-hover:", 1, false) then
    return nil
  end
  local typed = text:match("calibration%-type:%s*([^\n]+)")
  return {
    click = text:find("calibration%-click:%s*observed") ~= nil,
    right_click = text:find("calibration%-right%-click:%s*observed") ~= nil,
    hover = text:find("calibration%-hover:%s*observed") ~= nil,
    type = typed ~= nil and typed:gsub("^%s+", ""):gsub("%s+$", "") ~= "pending",
    wheel = text:find("calibration%-wheel:%s*observed") ~= nil,
  }
end

local function copy_download(download)
  if type(download) ~= "table" then
    return nil
  end
  local copy = {}
  for key, value in pairs(download) do
    if value ~= vim.NIL then
      copy[key] = value
    end
  end
  return copy
end

local function download_is_completed(download)
  return type(download) == "table" and download.status == "completed"
end

local function downloads_from_response(response)
  local downloads = {}
  if type(response) ~= "table" then
    return downloads
  end
  if type(response.downloads) == "table" then
    for _, download in ipairs(response.downloads) do
      if download_is_completed(download) then
        table.insert(downloads, download)
      end
    end
  end
  if #downloads == 0 and download_is_completed(response.download) then
    table.insert(downloads, response.download)
  end
  return downloads
end

local function latest_download_from_response(response)
  local downloads = downloads_from_response(response)
  if #downloads > 0 then
    return downloads[#downloads]
  end
  return nil
end

local function copy_dialog(dialog)
  if type(dialog) ~= "table" then
    return nil
  end
  local copy = {}
  for key, value in pairs(dialog) do
    if value ~= vim.NIL then
      copy[key] = value
    end
  end
  return copy
end

local function dialogs_from_response(response)
  local dialogs = {}
  if type(response) ~= "table" then
    return dialogs
  end
  if type(response.dialogs) == "table" then
    for _, dialog in ipairs(response.dialogs) do
      local copied = copy_dialog(dialog)
      if copied ~= nil then
        table.insert(dialogs, copied)
      end
    end
  end
  if #dialogs == 0 then
    local copied = copy_dialog(response.dialog)
    if copied ~= nil then
      table.insert(dialogs, copied)
    end
  end
  return dialogs
end

local function latest_dialog_from_response(response)
  local dialogs = dialogs_from_response(response)
  if #dialogs > 0 then
    return dialogs[#dialogs]
  end
  return nil
end

local function record_dialogs(response)
  for _, dialog in ipairs(dialogs_from_response(response)) do
    table.insert(state.dialog_history, dialog)
  end
end

local function copy_download_history()
  local downloads = {}
  for _, download in ipairs(state.download_history) do
    table.insert(downloads, copy_download(download))
  end
  return downloads
end

local function record_completed_download(response)
  local downloads = downloads_from_response(response)
  if #downloads == 0 then
    return
  end
  local id = response.id
  if id ~= nil and id ~= vim.NIL then
    if state.download_recorded_response_ids[id] then
      return
    end
    state.download_recorded_response_ids[id] = true
  end
  for _, download in ipairs(downloads) do
    local copied = copy_download(download)
    table.insert(state.download_history, copied)
    if type(state.download_observer) == "function" then
      pcall(state.download_observer, copied)
    end
  end
end

local function clear_navigation_admission(id)
  if state.navigation_admission_id == id then
    state.navigation_admission_id = nil
  end
end

local function apply_serve_response_metadata(response)
  if
    state.pending_operation ~= nil
    and (state.pending_operation.id == response.id or (response.id == 0 and response.status == "error"))
  then
    state.pending_operation = nil
    stop_operation_watchdog_timer()
    state.stopped_operation = nil
    if response.id == 0 and response.status == "error" then
      state.navigation_admission_id = nil
    else
      clear_navigation_admission(response.id)
    end
  elseif state.pending_operation == nil then
    state.stopped_operation = nil
  end
  state.status = response.status
  state.status_error = response.error
  if response.hint_error ~= nil and response.hint_error ~= vim.NIL and response.hint_error ~= "" then
    state.hint_error = tostring(response.hint_error)
  else
    state.hint_error = nil
  end
  if response.url ~= nil then
    state.current_url = response.url
  end
  if response.title ~= nil then
    state.current_title = response.title ~= vim.NIL and response.title or nil
  end
  if
    type(state.metadata_observer) == "function"
    and response.status == "ok"
    and response.url ~= nil
    and response.url ~= vim.NIL
    and response.url ~= ""
  then
    pcall(state.metadata_observer, {
      url = state.current_url,
      title = state.current_title,
    })
  end
  if response.page ~= nil and response.page ~= vim.NIL then
    state.page_metrics = response.page
  else
    state.page_metrics = nil
  end
  if response.focused ~= nil and response.focused ~= vim.NIL then
    state.focused_element = response.focused
  elseif response.focused == vim.NIL then
    state.focused_element = nil
  end
  if type(response.text) == "table" and response.text.text ~= nil and response.text.text ~= vim.NIL then
    local calibration_state = parse_calibration_state(response.text.text)
    if calibration_state ~= nil then
      state.calibration_state = calibration_state
    else
      state.calibration_state = nil
    end
  end
  if response.runtime ~= nil and response.runtime ~= vim.NIL then
    state.runtime_metadata = response.runtime
    if type(response.runtime) == "table" and output_is_cursor_addressable(response.runtime.output) then
      state.cursor_addressable_preview = true
    elseif type(response.runtime) == "table" and response.runtime.output == "kitty" then
      state.cursor_addressable_preview = false
    end
  end
  if response.download ~= nil and response.download ~= vim.NIL then
    state.latest_download = response.download
    record_completed_download(response)
  else
    local latest_download = latest_download_from_response(response)
    if latest_download ~= nil then
      state.latest_download = latest_download
      record_completed_download(response)
    end
  end
  if response.dialog ~= nil and response.dialog ~= vim.NIL then
    state.latest_dialog = copy_dialog(response.dialog)
    record_dialogs(response)
  else
    local latest_dialog = latest_dialog_from_response(response)
    if latest_dialog ~= nil then
      state.latest_dialog = latest_dialog
      record_dialogs(response)
    end
  end
  if response.status == "ok" and response.payload ~= nil then
    state.rendered_frame_geometry = rendered_frame_geometry_from_runtime(response.runtime)
    if response.found == nil then
      state.last_find_found = nil
      state.last_find_match_count = nil
    end
  end
end

local function dispatch_serve_response_handler(response)
  local response_handler = state.response_handlers[response.id]
  if response_handler ~= nil then
    state.response_handlers[response.id] = nil
    response_handler(response)
    return true
  end
  if response.found ~= nil and should_apply_find_response(response) then
    state.last_find_found = response.found == true
    if response.match_count ~= nil and response.match_count ~= vim.NIL then
      state.last_find_match_count = math.max(0, math.floor(tonumber(response.match_count) or 0))
    else
      state.last_find_match_count = nil
    end
    return true
  end
  return false
end

is_navigation_class_request = function(request)
  return type(request) == "table"
    and (
      request.type == "navigate"
      or request.type == "reload"
      or request.type == "back"
      or request.type == "forward"
    )
end

local function is_stale_serve_response(response)
  if response.id == 0 and response.status == "error" then
    return false
  end
  if state.navigation_suppressed_request_ids[response.id] then
    return true
  end
  return state.navigation_admission_id ~= nil and response.id ~= state.navigation_admission_id
end

local function clear_stale_serve_response_bookkeeping(response)
  state.navigation_suppressed_request_ids[response.id] = nil
  state.response_handlers[response.id] = nil
  if state.live_refresh_request_id == response.id then
    state.live_refresh_request_id = nil
    state.live_refresh_request_type = nil
  end
  state.quiet_request_ids[response.id] = nil
end

local stop_live_refresh_timer
local stop_live_refresh
local stop_resize_timer
local stop_text_mode_flush_timer
local stop_adaptive_capture_timer
local stop_scroll_coalesce_timer
local clear_scroll_coalesce
local flush_scroll_coalesce
local live_refresh_interval

local function stop_existing_job(force)
  stop_operation_watchdog_timer()
  stop_text_mode_flush_timer()
  stop_resize_timer()
  clear_scroll_coalesce()
  stop_live_refresh()
  if state.job_id == nil then
    return
  end

  local job_id = state.job_id
  if state.mode == "serve" and not force then
    pcall(vim.fn.chansend, job_id, vim.json.encode({ type = "quit", id = 0 }) .. "\n")
    if state.stop_timer ~= nil then
      state.stop_timer:stop()
      state.stop_timer:close()
    end
    state.stop_timer = vim.loop.new_timer()
    state.stop_timer:start(500, 0, function()
      vim.schedule(function()
        pcall(vim.fn.jobstop, job_id)
      end)
    end)
    state.job_id = nil
    return
  end

  pcall(vim.fn.jobstop, job_id)
  state.job_id = nil
end

local clear_in_flight_capture
local cancel_in_flight_capture
local same_preview_geometry
local resize_coalesce_ms = 50
local scroll_coalesce_ms = 25

local function request_resize()
  if state.mode ~= "serve" or not is_valid_window() then
    return false
  end

  local geometry = valid_preview_geometry()
  if geometry == nil then
    return false
  end
  cancel_in_flight_capture()
  return send_serve_request({
    type = "resize",
    columns = geometry.columns,
    rows = geometry.rows,
    width = geometry.width,
    height = geometry.height,
  })
end

stop_resize_timer = function()
  if state.resize_timer == nil then
    return
  end
  state.resize_timer:stop()
  state.resize_timer:close()
  state.resize_timer = nil
end

local function schedule_resize()
  if state.mode ~= "serve" or state.job_id == nil or not is_valid_window() then
    stop_resize_timer()
    return false
  end

  stop_resize_timer()
  local timer = timer_factory()
  if timer == nil then
    return request_resize()
  end
  state.resize_timer = timer
  timer:start(resize_coalesce_ms, 0, function()
    vim.schedule(function()
      if state.resize_timer ~= timer then
        return
      end
      state.resize_timer = nil
      timer:close()
      request_resize()
    end)
  end)
  return true
end

local send_pending_request
local send_capture_request
local send_page_state_request

stop_live_refresh_timer = function()
  state.live_refresh_generation = state.live_refresh_generation + 1
  if state.live_refresh_timer == nil then
    return
  end
  state.live_refresh_timer:stop()
  state.live_refresh_timer:close()
  state.live_refresh_timer = nil
end

clear_in_flight_capture = function()
  if state.live_refresh_request_id ~= nil then
    state.response_handlers[state.live_refresh_request_id] = nil
    if state.operation_watchdog_request_id == state.live_refresh_request_id then
      stop_operation_watchdog_timer()
    end
  end
  state.live_refresh_request_id = nil
  state.live_refresh_request_type = nil
end

cancel_in_flight_capture = function()
  if state.live_refresh_request_id ~= nil then
    state.canceled_request_ids[state.live_refresh_request_id] = true
  end
  clear_in_flight_capture()
end

stop_live_refresh = function()
  stop_live_refresh_timer()
  clear_in_flight_capture()
  stop_adaptive_capture_timer()
end

stop_adaptive_capture_timer = function()
  if state.adaptive_capture_timer == nil then
    return
  end
  state.adaptive_capture_timer:stop()
  state.adaptive_capture_timer:close()
  state.adaptive_capture_timer = nil
end

local function response_field_changed(response, key, current)
  local value = response[key]
  return value ~= nil and value ~= vim.NIL and value ~= current
end

local function table_field_changed(response_value, current_value, key)
  if type(response_value) ~= "table" then
    return false
  end
  local value = response_value[key]
  if value == nil or value == vim.NIL then
    return false
  end
  if type(current_value) ~= "table" then
    return true
  end
  return value ~= current_value[key]
end

local function completed_download_changed(response)
  return type(response) == "table" and download_is_completed(response.download)
end

local function page_state_needs_capture(response)
  if type(response) ~= "table" or response.status ~= "ok" then
    return false
  end
  if response_field_changed(response, "url", state.current_url) then
    return true
  end
  if response_field_changed(response, "title", state.current_title) then
    return true
  end
  local page = response.page
  if
    table_field_changed(page, state.page_metrics, "scroll_x")
    or table_field_changed(page, state.page_metrics, "scroll_y")
    or table_field_changed(page, state.page_metrics, "viewport_width")
    or table_field_changed(page, state.page_metrics, "viewport_height")
    or table_field_changed(page, state.page_metrics, "document_width")
    or table_field_changed(page, state.page_metrics, "document_height")
  then
    return true
  end
  local focused = response.focused
  if
    table_field_changed(focused, state.focused_element, "kind")
    or table_field_changed(focused, state.focused_element, "label")
    or table_field_changed(focused, state.focused_element, "value")
    or table_field_changed(focused, state.focused_element, "focusable")
    or table_field_changed(focused, state.focused_element, "submittable")
  then
    return true
  end
  return completed_download_changed(response)
end

local function schedule_adaptive_capture()
  if
    state.mode ~= "serve"
    or state.job_id == nil
    or state.pending_operation ~= nil
    or state.live_refresh_request_id ~= nil
    or state.scroll_coalesce_request ~= nil
    or state.resize_timer ~= nil
    or state.text_mode_active
    or state.text_mode_flush_timer ~= nil
  then
    return false
  end
  stop_adaptive_capture_timer()
  local timer = timer_factory()
  if timer == nil then
    return false
  end
  state.adaptive_capture_timer = timer
  local generation = state.generation
  timer:start(100, 0, function()
    vim.schedule(function()
      if state.adaptive_capture_timer ~= timer then
        return
      end
      state.adaptive_capture_timer = nil
      timer:close()
      if
        generation ~= state.generation
        or state.mode ~= "serve"
        or state.job_id == nil
        or live_refresh_interval() == nil
        or state.pending_operation ~= nil
        or state.live_refresh_request_id ~= nil
        or state.scroll_coalesce_request ~= nil
        or state.resize_timer ~= nil
        or state.text_mode_active
        or state.text_mode_flush_timer ~= nil
      then
        return
      end
      send_capture_request()
    end)
  end)
  return true
end

live_refresh_interval = function()
  local live_refresh = options.live_refresh or {}
  if live_refresh.enabled == false then
    return nil
  end
  local interval = tonumber(live_refresh.interval_ms)
  if interval == nil or interval <= 0 then
    return nil
  end
  return interval
end

local function start_live_refresh_timer(generation)
  stop_live_refresh_timer()
  local interval = live_refresh_interval()
  if interval == nil then
    return
  end
  local timer = timer_factory()
  if timer == nil then
    return
  end
  state.live_refresh_timer = timer
  local live_refresh_generation = state.live_refresh_generation
  timer:start(interval, interval, function()
    vim.schedule(function()
      if state.live_refresh_generation ~= live_refresh_generation or state.live_refresh_timer ~= timer then
        return
      end
      if live_refresh_interval() == nil then
        return
      end
      if generation ~= state.generation then
        return
      end
      if state.mode ~= "serve" or state.job_id == nil or not is_valid_buffer() then
        return
      end
      if
        state.pending_operation ~= nil
        or state.live_refresh_request_id ~= nil
        or state.adaptive_capture_timer ~= nil
        or state.scroll_coalesce_request ~= nil
      then
        return
      end
      send_page_state_request()
    end)
  end)
end

local function send_live_refresh_request(request, opts)
  opts = opts or {}
  if opts.force == true then
    cancel_in_flight_capture()
  end
  if state.live_refresh_request_id ~= nil then
    return false
  end
  local ok, id = send_serve_request(request, function()
    if state.operation_watchdog_request_id == state.live_refresh_request_id then
      stop_operation_watchdog_timer()
    end
    state.live_refresh_request_id = nil
    state.live_refresh_request_type = nil
  end)
  if ok then
    state.live_refresh_request_id = id
    state.live_refresh_request_type = request.type
    if request.type == "capture" then
      schedule_operation_watchdog(id)
    end
  end
  return ok
end

send_capture_request = function(opts)
  return send_live_refresh_request({ type = "capture" }, opts)
end

send_page_state_request = function(opts)
  return send_live_refresh_request({ type = "page_state" }, opts)
end

local function ensure_resize_autocmd()
  if state.resize_autocmd ~= nil then
    return
  end

  state.resize_autocmd = vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
    group = resize_augroup,
    callback = function()
      schedule_resize()
    end,
  })
end

local function reuse_active_serve_command(command)
  if state.mode ~= "serve" or state.job_id == nil or not is_valid_buffer() then
    return nil
  end
  if not command_uses_serve(command) then
    return nil
  end
  local output = command_output(command)
  if state.serve_output ~= nil and output ~= nil and output ~= state.serve_output then
    return nil
  end
  local target = command_target(command)
  if target == nil or target == "" then
    return nil
  end

  state.last_target = target
  request_resize()
  return send_pending_request({
    type = "navigate",
    url = target,
  }, target)
end

function M.viewport_point_for_cell(row, column, geometry)
  if geometry == nil then
    geometry = current_preview_geometry()
  end

  row = math.max(1, math.min(tonumber(row) or 1, geometry.rows))
  column = math.max(1, math.min(tonumber(column) or 1, geometry.columns))
  return {
    x = (column - 0.5) * geometry.width / geometry.columns,
    y = (row - 0.5) * geometry.height / geometry.rows,
  }
end

function M.viewport_drag_point_for_cell(row, column, geometry, edge)
  if geometry == nil then
    geometry = current_preview_geometry()
  end

  row = math.max(1, math.min(tonumber(row) or 1, geometry.rows))
  column = math.max(1, math.min(tonumber(column) or 1, geometry.columns))
  local cell_width = geometry.width / geometry.columns
  local x
  if edge == "end" then
    x = column * cell_width - math.min(1, cell_width * 0.15)
  else
    x = (column - 1) * cell_width + math.min(1, cell_width * 0.15)
  end
  return {
    x = math.max(0, math.min(x, geometry.width)),
    y = (row - 0.5) * geometry.height / geometry.rows,
  }
end

same_preview_geometry = function(left, right)
  if left == nil or right == nil then
    return false
  end
  return left.columns == right.columns
    and left.rows == right.rows
    and left.width == right.width
    and left.height == right.height
end

rendered_frame_geometry_from_runtime = function(runtime)
  if type(runtime) ~= "table" or type(runtime.cells) ~= "table" or type(runtime.viewport) ~= "table" then
    return nil
  end
  local columns = tonumber(runtime.cells.columns)
  local rows = tonumber(runtime.cells.rows)
  local width = tonumber(runtime.viewport.width)
  local height = tonumber(runtime.viewport.height)
  if columns == nil or rows == nil or width == nil or height == nil then
    return nil
  end
  if columns <= 0 or rows <= 0 or width <= 0 or height <= 0 then
    return nil
  end
  return {
    columns = columns,
    rows = rows,
    width = width,
    height = height,
  }
end

local function current_rendered_frame_geometry()
  local geometry = current_preview_geometry()
  if state.rendered_frame_geometry ~= nil and same_preview_geometry(state.rendered_frame_geometry, geometry) then
    return state.rendered_frame_geometry
  end
  request_resize()
  return nil
end

local function cell_within_geometry(row, column, geometry)
  return row > 0 and column > 0 and row <= geometry.rows and column <= geometry.columns
end

local function hint_label_width(count)
  local base = #hint_label_keys
  local width = 1
  local capacity = base
  while count > capacity do
    width = width + 1
    capacity = capacity * base
  end
  return width
end

local function hint_label_for_index(index, width)
  local base = #hint_label_keys
  local value = index - 1
  local label = ""
  for position = width - 1, 0, -1 do
    local divisor = base ^ position
    local key_index = (math.floor(value / divisor) % base) + 1
    label = label .. hint_label_keys[key_index]
  end
  return label
end

local function assign_hint_labels(hints)
  local labeled = {}
  local width = hint_label_width(#(hints or {}))
  for index, hint in ipairs(hints or {}) do
    local copy = vim.tbl_extend("force", {}, hint)
    copy.hint_label = copy.hint_label or hint_label_for_index(index, width)
    table.insert(labeled, copy)
  end
  return labeled
end

local function find_hint(hints, identifier)
  if identifier == nil then
    return nil
  end
  local numeric_id = tonumber(identifier)
  local label = tostring(identifier):lower()
  for _, hint in ipairs(hints or {}) do
    if numeric_id ~= nil and tonumber(hint.id) == numeric_id then
      return hint
    end
    if hint.hint_label ~= nil and tostring(hint.hint_label):lower() == label then
      return hint
    end
  end
  return nil
end

local function browser_buffer_label(title, url)
  if title == vim.NIL then
    title = nil
  end
  if title ~= nil and title ~= "" then
    return title
  end
  if url ~= nil and url ~= "" then
    local label = tostring(url):gsub("^%w+://", "")
    label = label:gsub("[?#].*$", "")
    label = label:gsub("/$", "")
    if label ~= "" then
      return label
    end
  end
  return "browser"
end

local function browser_buffer_name(title, url)
  if title == vim.NIL then
    title = nil
  end
  local label = browser_buffer_label(title, url)
  if title ~= nil and title ~= "" then
    label = label:gsub("[/:\\]", "-")
  else
    label = label:gsub("[:\\]", "-")
  end
  label = label:gsub("[%c]", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if label == "" then
    label = "browser"
  end
  if vim.fn.strchars(label) > 80 then
    label = vim.fn.strcharpart(label, 0, 80)
  end
  return "nvim-browser://" .. label
end

local function set_browser_buffer_name(bufnr, title, url)
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  local name = browser_buffer_name(title, url)
  if vim.api.nvim_buf_get_name(bufnr) == name then
    return true, name
  end
  local ok = pcall(vim.api.nvim_buf_set_name, bufnr, name)
  if ok then
    return true, name
  end
  local suffixed = name .. " [" .. bufnr .. "]"
  ok = pcall(vim.api.nvim_buf_set_name, bufnr, suffixed)
  return ok, ok and suffixed or nil
end

local function update_browser_buffer_name(bufnr)
  return set_browser_buffer_name(bufnr, state.current_title, state.current_url or state.last_target)
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

local function runtime_footer_label(runtime)
  if type(runtime) ~= "table" then
    return nil
  end
  local output = runtime.output ~= nil and runtime.output ~= vim.NIL and tostring(runtime.output) or nil
  if type(runtime.cells) ~= "table" then
    return output
  end
  local columns = runtime.cells.columns
  local rows = runtime.cells.rows
  if columns == nil or rows == nil then
    return output
  end
  local cells = tostring(columns) .. "x" .. tostring(rows)
  return output ~= nil and (output .. " " .. cells) or cells
end

local function download_footer_label(download)
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

local function dialog_footer_label(dialog)
  if type(dialog) ~= "table" then
    return nil
  end
  local kind = dialog.kind ~= nil and dialog.kind ~= vim.NIL and tostring(dialog.kind) or nil
  local action = dialog.action ~= nil and dialog.action ~= vim.NIL and tostring(dialog.action) or nil
  if kind == nil or kind == "" or action == nil or action == "" then
    return nil
  end
  local label = "dialog=" .. kind .. " " .. action
  local message = dialog.message ~= nil and dialog.message ~= vim.NIL and tostring(dialog.message) or nil
  if message ~= nil then
    message = message:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if message ~= "" then
      label = label .. ": " .. message
    end
  end
  return label
end

local function truncate_cells(value, width)
  width = tonumber(width) or 0
  if width <= 0 then
    return ""
  end
  value = tostring(value or "")
  if vim.fn.strchars(value) <= width then
    return value
  end
  return vim.fn.strcharpart(value, 0, width)
end

local function preview_footer_line(width)
  local parts = {}
  local pending = state.pending_operation
  if pending ~= nil then
    table.insert(parts, pending.label or "loading")
    table.insert(parts, pending.target or state.current_url or state.last_target or "operation")
    table.insert(parts, "Esc stop")
    local runtime = runtime_footer_label(state.runtime_metadata)
    if runtime ~= nil then
      table.insert(parts, runtime)
    end
    return truncate_cells(table.concat(parts, " | "), width)
  end

  local stopped_label = state.stopped_operation ~= nil and (state.stopped_operation.reason or "stopped") or nil
  table.insert(parts, state.text_mode_active and "text" or stopped_label or state.status or "idle")

  local title = state.current_title ~= nil and state.current_title ~= "" and state.current_title or nil
  local url = state.stopped_operation ~= nil
      and state.stopped_operation.target
    or state.current_url ~= nil and state.current_url ~= "" and state.current_url
    or state.last_target
  if title ~= nil then
    table.insert(parts, title)
  elseif url ~= nil and url ~= "" then
    table.insert(parts, url)
    url = nil
  end

  local scroll = page_scroll_label(state.page_metrics)
  if scroll ~= nil then
    table.insert(parts, scroll)
  end

  local focused = focused_element_label(state.focused_element)
  if focused ~= nil then
    table.insert(parts, focused)
  end

  local dialog = dialog_footer_label(state.latest_dialog)
  if dialog ~= nil then
    table.insert(parts, dialog)
  end

  local download = download_footer_label(state.latest_download)
  if download ~= nil then
    table.insert(parts, download)
  end

  local zoom = status_labels.zoom_label(state.zoom_scale)
  if zoom ~= nil then
    table.insert(parts, zoom)
  end

  if state.last_find_match_count ~= nil then
    local suffix = state.last_find_match_count == 1 and "match" or "matches"
    table.insert(parts, "find: " .. tostring(state.last_find_match_count) .. " " .. suffix)
  end

  local runtime = runtime_footer_label(state.runtime_metadata)
  if runtime ~= nil then
    table.insert(parts, runtime)
  end

  if url ~= nil and url ~= "" then
    table.insert(parts, url)
  end

  if state.status_error ~= nil and state.status_error ~= vim.NIL and state.status_error ~= "" then
    table.insert(parts, state.status_error)
  end

  return truncate_cells(table.concat(parts, " | "), width)
end

local function append_preview_footer(lines, geometry)
  if state.mode ~= "serve" then
    return lines
  end
  geometry = geometry or current_preview_geometry()
  local rows = geometry.rows or #lines
  local columns = geometry.columns or preview_cells({ reserve_footer = true }).columns
  local with_footer = {}
  for index = 1, math.min(#lines, rows) do
    table.insert(with_footer, lines[index])
  end
  while #with_footer < rows do
    table.insert(with_footer, "")
  end
  table.insert(with_footer, preview_footer_line(columns))
  return with_footer
end

local function refresh_preview_footer(bufnr, geometry)
  if state.mode ~= "serve" or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  geometry = geometry or current_preview_geometry()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if #lines == 0 then
    return
  end
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, append_preview_footer(lines, geometry))
  vim.bo[bufnr].modifiable = false
end

stop_operation_watchdog_timer = function()
  if state.operation_watchdog_timer ~= nil then
    state.operation_watchdog_timer:stop()
    state.operation_watchdog_timer:close()
  end
  state.operation_watchdog_timer = nil
  state.operation_watchdog_request_id = nil
end

local function operation_watchdog_timeout_ms()
  local timeout = tonumber(options.navigation_timeout_ms)
  if timeout == nil or timeout <= 0 then
    return 20000
  end
  return math.floor(timeout)
end

schedule_operation_watchdog = function(id)
  stop_operation_watchdog_timer()
  local timer = timer_factory()
  if timer == nil then
    return false
  end
  state.operation_watchdog_timer = timer
  state.operation_watchdog_request_id = id
  local generation = state.generation
  timer:start(operation_watchdog_timeout_ms(), 0, function()
    vim.schedule(function()
      if state.operation_watchdog_timer ~= timer or state.operation_watchdog_request_id ~= id or state.generation ~= generation then
        return
      end
      if state.pending_operation ~= nil and state.pending_operation.id == id then
        hard_stop_pending_operation("timeout")
      elseif state.live_refresh_request_id == id and state.live_refresh_request_type == "capture" then
        hard_stop_capture_operation("timeout")
      end
    end)
  end)
  return true
end

local function mark_pending_operation(id, label, target)
  if id == nil then
    return
  end
  state.pending_operation = {
    id = id,
    label = label or "loading",
    target = target or state.current_url or state.last_target,
  }
  state.stopped_operation = nil
  state.operation_watchdog_request_id = id
  state.status_error = nil
  state.hint_error = nil
  schedule_operation_watchdog(id)
  if is_valid_buffer() then
    refresh_preview_footer(state.bufnr)
  end
end

local function clear_pending_operation(id)
  if state.pending_operation ~= nil and (id == nil or state.pending_operation.id == id) then
    state.pending_operation = nil
    stop_operation_watchdog_timer()
    if is_valid_buffer() then
      refresh_preview_footer(state.bufnr)
    end
  end
end

function send_pending_request(request, target, label, on_response)
  local ok, id = send_serve_request(request, on_response)
  if ok then
    if is_navigation_class_request(request) then
      state.navigation_admission_id = id
    elseif state.navigation_suppressed_request_ids[id] then
      return ok
    end
    mark_pending_operation(id, label or "loading", target)
  end
  return ok, id
end

stop_scroll_coalesce_timer = function()
  if state.scroll_coalesce_timer == nil then
    return
  end
  state.scroll_coalesce_timer:stop()
  state.scroll_coalesce_timer:close()
  state.scroll_coalesce_timer = nil
end

clear_scroll_coalesce = function()
  stop_scroll_coalesce_timer()
  state.scroll_coalesce_request = nil
end

flush_scroll_coalesce = function()
  local queued = state.scroll_coalesce_request
  clear_scroll_coalesce()
  if queued == nil then
    return false
  end

  local request
  if queued.kind == "wheel_point" then
    request = {
      type = "wheel_point",
      x = queued.x,
      y = queued.y,
      delta_x = queued.delta_x,
      delta_y = queued.delta_y,
    }
  else
    request = {
      type = "scroll",
      delta_x = queued.delta_x,
      delta_y = queued.delta_y,
    }
  end

  if state.pending_operation ~= nil then
    return send_serve_request(request)
  end
  return send_pending_request(request, queued.target, "scroll")
end

local function same_scroll_coalesce_target(queued, next_request)
  if queued == nil or queued.kind ~= next_request.kind then
    return false
  end
  if queued.kind == "wheel_point" then
    return queued.x == next_request.x and queued.y == next_request.y
  end
  return queued.target == next_request.target
end

local function schedule_scroll_coalesce()
  stop_scroll_coalesce_timer()
  local timer = timer_factory()
  if timer == nil then
    return flush_scroll_coalesce()
  end
  state.scroll_coalesce_timer = timer
  local ok = pcall(timer.start, timer, scroll_coalesce_ms, 0, function()
    vim.schedule(function()
      if state.scroll_coalesce_timer ~= timer then
        return
      end
      state.scroll_coalesce_timer = nil
      timer:close()
      flush_scroll_coalesce()
    end)
  end)
  if not ok then
    state.scroll_coalesce_timer = nil
    pcall(function()
      timer:close()
    end)
    return flush_scroll_coalesce()
  end
  return true
end

local function queue_scroll_coalesce(next_request)
  if state.mode ~= "serve" or state.job_id == nil then
    return false
  end
  if state.scroll_coalesce_request ~= nil and not same_scroll_coalesce_target(state.scroll_coalesce_request, next_request) then
    flush_scroll_coalesce()
  end
  local queued = state.scroll_coalesce_request
  if queued == nil then
    queued = next_request
    state.scroll_coalesce_request = queued
  else
    queued.delta_x = queued.delta_x + next_request.delta_x
    queued.delta_y = queued.delta_y + next_request.delta_y
    queued.target = next_request.target or queued.target
  end
  cancel_in_flight_capture()
  return schedule_scroll_coalesce()
end

local function apply_payload_to_buffer(bufnr, payload, uses_kitty, uses_kitty_unicode, command, geometry)
  state.last_payload = (uses_kitty or uses_kitty_unicode) and payload or nil
  state.last_payload_is_unicode = uses_kitty_unicode and payload ~= nil

  vim.bo[bufnr].modifiable = true
  if uses_kitty_unicode then
    geometry = command_uses_serve(command) and geometry or nil
    local columns = (geometry and geometry.columns)
      or command_option_value(command, "--columns")
      or preview_cells().columns
    local rows = (geometry and geometry.rows)
      or command_option_value(command, "--rows")
      or preview_cells().rows
    local lines = append_preview_footer(kitty_placeholder_lines(columns, rows), geometry)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    apply_kitty_placeholder_highlight(bufnr, rows)
  elseif not uses_kitty then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
    local channel = vim.api.nvim_open_term(bufnr, {})
    vim.api.nvim_chan_send(channel, payload or "")
    if command_uses_serve(command) then
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      vim.bo[bufnr].modifiable = true
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, append_preview_footer(lines, geometry))
    end
  end
  vim.bo[bufnr].modifiable = false
end

local function cursor_position_escape(winid)
  local row, column = unpack(vim.fn.win_screenpos(winid))
  return ("\x1b[%d;%dH"):format(row, column)
end

local function emit_terminal_graphics(payload, winid)
  if payload == nil or payload == "" then
    return
  end
  if not is_valid_window_id(winid) then
    return
  end

  vim.cmd("redraw")
  send_terminal_escape(kitty_cleanup_escape())
  vim.api.nvim_chan_send(vim.v.stderr, cursor_position_escape(winid))
  send_terminal_escape(payload)
end

local function preview_lines(message, target)
  local lines = {
    message,
    "",
    "Target: " .. (target or ""),
  }
  if state.mode == "serve" and is_valid_window() then
    return append_preview_footer(lines, current_preview_geometry())
  end
  local height = is_valid_window() and vim.api.nvim_win_get_height(state.winid) or 24
  while #lines < height do
    table.insert(lines, "")
  end
  return lines
end

local function ensure_window()
  if is_valid_window() then
    vim.api.nvim_set_current_win(state.winid)
    return
  end

  create_window()
  if is_valid_buffer() then
    vim.api.nvim_win_set_buf(state.winid, state.bufnr)
  end
end

function M.open(command)
  ensure_window()
  local original_command = copy_command(command)
  command = command_for_window(command)

  local reused = reuse_active_serve_command(command)
  if reused ~= nil then
    return reused
  end

  stop_existing_job(false)

  state.generation = state.generation + 1
  state.last_payload = nil
  state.last_payload_is_unicode = false
  state.last_target = command_target(command)
  state.stream_buffer = ""
  state.mode = nil
  state.serve_output = nil
  state.last_serve_command = command_uses_serve(original_command) and original_command or nil
  state.next_request_id = 1
  state.current_url = nil
  state.current_title = nil
  state.page_metrics = nil
  state.focused_element = nil
  state.latest_download = nil
  state.download_history = {}
  state.download_recorded_response_ids = {}
  state.latest_dialog = nil
  state.dialog_history = {}
  state.calibration_state = nil
  state.runtime_metadata = nil
  state.rendered_frame_geometry = nil
  state.status = nil
  state.status_error = nil
  state.hint_error = nil
  state.pending_operation = nil
  state.live_refresh_request_id = nil
  state.live_refresh_request_type = nil
  stop_adaptive_capture_timer()
  state.scroll_coalesce_request = nil
  state.stopped_operation = nil
  state.canceled_request_ids = {}
  state.quiet_request_ids = {}
  state.navigation_admission_id = nil
  state.navigation_suppressed_request_ids = {}
  state.latest_applied_response_id = 0
  state.latest_reader_request_id = nil
  state.latest_page_text_yank_request_id = nil
  state.latest_find_request_id = nil
  state.last_find_found = nil
  state.last_find_match_count = nil
  state.last_find_query = nil
  state.response_handlers = {}
  state.element_hints = {}
  state.element_hints_geometry = nil
  state.cursor_addressable_preview = false
  state.zoom_scale = 1.0
  delete_reader_buffer()
  pcall(send_terminal_escape, kitty_cleanup_escape())

  local previous_bufnr = state.bufnr
  state.bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(state.winid, state.bufnr)

  if previous_bufnr ~= nil and vim.api.nvim_buf_is_valid(previous_bufnr) then
    vim.api.nvim_buf_delete(previous_bufnr, { force = true })
  end
  set_browser_buffer_name(state.bufnr, nil, state.last_target)

  vim.bo[state.bufnr].bufhidden = "hide"
  vim.bo[state.bufnr].filetype = "nvim-browser"
  vim.bo[state.bufnr].buftype = "nofile"
  vim.bo[state.bufnr].swapfile = false

  if command_uses_serve(command) then
    state.mode = "serve"
    state.serve_output = command_output(command)
    ensure_resize_autocmd()
    local bufnr = state.bufnr
    local generation = state.generation
    local target = command_target(command)
    local uses_kitty = command_uses_kitty_serve(command)
    local uses_kitty_unicode = command_uses_kitty_unicode_serve(command)
    local stream_buffer = ""
    state.cursor_addressable_preview = uses_kitty_unicode or command_uses_ansi_serve(command)

    vim.bo[state.bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(
      state.bufnr,
      0,
      -1,
      false,
      preview_lines("Starting browser session...", target)
    )
    vim.bo[state.bufnr].modifiable = false

    local function handle_line(line)
      if line == "" then
        return
      end
      local ok, response = pcall(vim.json.decode, line)
      if not ok or type(response) ~= "table" then
        return
      end
      vim.schedule(function()
        if generation ~= state.generation or state.bufnr ~= bufnr then
          return
        end
        if not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end
        record_completed_download(response)
        if state.canceled_request_ids[response.id] then
          state.canceled_request_ids[response.id] = nil
          state.navigation_suppressed_request_ids[response.id] = nil
          state.response_handlers[response.id] = nil
          return
        end
        if is_stale_serve_response(response) then
          clear_stale_serve_response_bookkeeping(response)
          return
        end
        state.quiet_request_ids[response.id] = nil
        local is_protocol_error = response.id == 0 and response.status == "error"
        if is_protocol_error and state.live_refresh_request_id ~= nil then
          clear_in_flight_capture()
        end
        if response.id == state.live_refresh_request_id and state.pending_operation ~= nil then
          dispatch_serve_response_handler(response)
          if state.live_refresh_request_id == response.id then
            state.live_refresh_request_id = nil
          end
          return
        end
        if not is_protocol_error and state.pending_operation ~= nil and response.id < state.pending_operation.id then
          dispatch_serve_response_handler(response)
          return
        end
        if not is_protocol_error and response.id < state.latest_applied_response_id then
          dispatch_serve_response_handler(response)
          return
        end

        local should_adaptively_capture = state.live_refresh_request_id == response.id
          and state.live_refresh_request_type == "page_state"
          and page_state_needs_capture(response)

        apply_serve_response_metadata(response)
        state.latest_applied_response_id = math.max(state.latest_applied_response_id, response.id)
        update_browser_buffer_name(bufnr)
        dispatch_serve_response_handler(response)
        local has_payload = response.payload ~= nil and response.payload ~= vim.NIL
        local has_hints = type(response.hints) == "table" and #response.hints > 0
        local has_hint_error = response.hint_error ~= nil and response.hint_error ~= vim.NIL and response.hint_error ~= ""
        if response.status == "ok" and not has_payload and not has_hints and not has_hint_error then
          refresh_preview_footer(bufnr, valid_preview_geometry())
          if should_adaptively_capture then
            schedule_adaptive_capture()
          end
          return
        end
        local geometry = valid_preview_geometry()
        if response.status ~= "error" then
          state.element_hints = assign_hint_labels(response.hints or {})
          state.element_hints_geometry = #state.element_hints > 0 and geometry or nil
        end

        if response.status == "ok" and response.payload ~= nil then
          state.rendered_frame_geometry = rendered_frame_geometry_from_runtime(response.runtime)
          apply_payload_to_buffer(bufnr, response.payload, uses_kitty, uses_kitty_unicode, command, geometry)
          if uses_kitty then
            emit_terminal_graphics(response.payload, state.winid)
          elseif uses_kitty_unicode then
            send_terminal_escape(response.payload)
          end
          if state.cursor_addressable_preview and geometry ~= nil then
            hints_overlay.apply(bufnr, state.element_hints, state.element_hints_geometry)
          else
            hints_overlay.clear(bufnr)
          end
          vim.cmd("redraw")
          return
        end

        if response.status == "error" then
          refresh_preview_footer(bufnr, geometry)
          if
            state.cursor_addressable_preview
            and #state.element_hints > 0
            and same_preview_geometry(state.element_hints_geometry, geometry)
          then
            hints_overlay.apply(bufnr, state.element_hints, state.element_hints_geometry)
          else
            hints_overlay.clear(bufnr)
          end
          vim.api.nvim_echo({ { "nvim-browser: " .. (response.error or "unknown error"), "WarningMsg" } }, false, {})
          return
        end
        hints_overlay.clear(bufnr)
      end)
    end

    state.job_id = vim.fn.jobstart(command, {
      stdout_buffered = false,
      stderr_buffered = true,
      on_stdout = function(_, data)
        if not data then
          return
        end
        stream_buffer = stream_buffer .. table.concat(data, "\n")
        while true do
          local newline = stream_buffer:find("\n", 1, true)
          if newline == nil then
            break
          end
          local line = stream_buffer:sub(1, newline - 1)
          stream_buffer = stream_buffer:sub(newline + 1)
          handle_line(line)
        end
      end,
      on_exit = function(_, code)
        vim.schedule(function()
          if state.stop_timer ~= nil then
            state.stop_timer:stop()
            state.stop_timer:close()
            state.stop_timer = nil
          end
          if generation ~= state.generation or state.bufnr ~= bufnr then
            return
          end
          state.job_id = nil
          stop_text_mode_flush_timer()
          stop_resize_timer()
          clear_scroll_coalesce()
          stop_live_refresh()
          state.mode = nil
          state.serve_output = nil
          state.pending_operation = nil
          state.stopped_operation = nil
          state.live_refresh_request_id = nil
          state.scroll_coalesce_request = nil
          state.response_handlers = {}
          state.canceled_request_ids = {}
          state.quiet_request_ids = {}
          state.navigation_admission_id = nil
          state.navigation_suppressed_request_ids = {}
          state.runtime_metadata = nil
          state.rendered_frame_geometry = nil
          state.focused_element = nil
          state.latest_download = nil
          state.download_history = {}
          state.download_recorded_response_ids = {}
          state.latest_dialog = nil
          state.dialog_history = {}
          state.calibration_state = nil
          state.zoom_scale = 1.0
          state.element_hints = {}
          state.element_hints_geometry = nil
          state.cursor_addressable_preview = false
          hints_overlay.clear(bufnr)
          if vim.api.nvim_buf_is_valid(bufnr) then
            vim.bo[bufnr].modifiable = true
            if code ~= 0 then
              vim.api.nvim_buf_set_lines(
                bufnr,
                0,
                -1,
                false,
                preview_lines("Browser session exited: " .. code, target)
              )
            else
              local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
              if #lines > 0 then
                local width = math.max(1, vim.fn.strdisplaywidth(lines[#lines]))
                lines[#lines] = preview_footer_line(width)
                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
              end
            end
            vim.bo[bufnr].modifiable = false
          end
        end)
      end,
    })
    start_live_refresh_timer(generation)
    return
  end

  if command_uses_captured_browse(command) then
    local bufnr = state.bufnr
    local winid = state.winid
    local generation = state.generation
    local target = command_target(command)
    local uses_kitty = command_uses_kitty_browse(command)
    local uses_kitty_unicode = command_uses_kitty_unicode_browse(command)
    vim.bo[state.bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(
      state.bufnr,
      0,
      -1,
      false,
      preview_lines("Loading browser preview...", target)
    )
    vim.bo[state.bufnr].modifiable = false

    local chunks = {}
    state.job_id = vim.fn.jobstart(command, {
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = function(_, data)
        if data then
          table.insert(chunks, table.concat(data, "\n"))
        end
      end,
      on_exit = function(_, code)
        vim.schedule(function()
          if generation ~= state.generation or state.bufnr ~= bufnr then
            return
          end
          if not vim.api.nvim_buf_is_valid(bufnr) then
            return
          end

          local payload = code == 0 and table.concat(chunks) or nil
          if code == 0 and not uses_kitty and not uses_kitty_unicode then
            apply_payload_to_buffer(bufnr, payload, uses_kitty, uses_kitty_unicode, command)
          elseif code == 0 and uses_kitty_unicode then
            apply_payload_to_buffer(bufnr, payload, uses_kitty, uses_kitty_unicode, command)
          else
            vim.bo[bufnr].modifiable = true
            vim.api.nvim_buf_set_lines(
              bufnr,
              0,
              -1,
              false,
              preview_lines(
                code == 0 and "Browser preview" or ("Browser preview failed: exit " .. code),
                target
              )
            )
            vim.bo[bufnr].modifiable = false
          end

          if code == 0 and uses_kitty then
            emit_terminal_graphics(payload, is_valid_window_id(state.winid) and state.winid or winid)
          elseif code == 0 and uses_kitty_unicode then
            send_terminal_escape(payload)
            vim.cmd("redraw")
          end
        end)
      end,
    })
    return
  end

  state.job_id = vim.api.nvim_buf_call(state.bufnr, function()
    return vim.fn.termopen(command)
  end)
  vim.cmd("startinsert")
end

function M.focus()
  if not is_valid_window() then
    return false
  end

  vim.api.nvim_set_current_win(state.winid)
  if state.last_payload_is_unicode and state.last_payload ~= nil then
    send_terminal_escape(state.last_payload)
    vim.cmd("redraw")
  else
    emit_terminal_graphics(state.last_payload, state.winid)
  end
  return true
end

function M.close()
  state.generation = state.generation + 1
  stop_existing_job(false)
  pcall(send_terminal_escape, kitty_cleanup_escape())
  hints_overlay.clear(state.bufnr)
  if is_valid_window() then
    vim.api.nvim_win_close(state.winid, true)
  end
  if is_valid_buffer() then
    vim.api.nvim_buf_delete(state.bufnr, { force = true })
  end
  delete_reader_buffer()
  state.bufnr = nil
  state.winid = nil
  state.job_id = nil
  state.last_payload = nil
  state.last_payload_is_unicode = false
  state.last_target = nil
  state.stream_buffer = ""
  state.mode = nil
  state.serve_output = nil
  state.last_serve_command = nil
  state.current_url = nil
  state.current_title = nil
  state.page_metrics = nil
  state.focused_element = nil
  state.latest_download = nil
  state.download_history = {}
  state.download_recorded_response_ids = {}
  state.latest_dialog = nil
  state.dialog_history = {}
  state.calibration_state = nil
  state.runtime_metadata = nil
  state.rendered_frame_geometry = nil
  state.status = nil
  state.status_error = nil
  state.hint_error = nil
  state.pending_operation = nil
  state.live_refresh_request_id = nil
  state.live_refresh_request_type = nil
  stop_adaptive_capture_timer()
  state.scroll_coalesce_request = nil
  stop_resize_timer()
  clear_scroll_coalesce()
  state.stopped_operation = nil
  state.canceled_request_ids = {}
  state.quiet_request_ids = {}
  state.navigation_admission_id = nil
  state.navigation_suppressed_request_ids = {}
  state.latest_applied_response_id = 0
  state.latest_reader_request_id = nil
  state.latest_page_text_yank_request_id = nil
  state.last_find_found = nil
  state.last_find_match_count = nil
  state.last_find_query = nil
  state.response_handlers = {}
  state.element_hints = {}
  state.element_hints_geometry = nil
  state.cursor_addressable_preview = false
  state.text_mode_active = false
  stop_text_mode_flush_timer()
  state.zoom_scale = 1.0
  if state.stop_timer ~= nil then
    state.stop_timer:stop()
    state.stop_timer:close()
    state.stop_timer = nil
  end
end

local function restart_stopped_serve(target)
  if state.mode == "serve" and state.job_id ~= nil then
    return false
  end
  local command = state.last_serve_command
  if command == nil then
    return false
  end
  target = target
    or (state.stopped_operation and state.stopped_operation.target)
    or state.current_url
    or state.last_target
  M.open(command_with_target(command, target))
  return state.mode == "serve" and state.job_id ~= nil
end

function M.refresh()
  if state.mode ~= "serve" or state.job_id == nil then
    return restart_stopped_serve()
  end
  return send_capture_request()
end

function M.reload()
  if state.mode ~= "serve" or state.job_id == nil then
    return restart_stopped_serve((state.stopped_operation and state.stopped_operation.target) or state.current_url or state.last_target)
  end
  request_resize()
  return send_pending_request({ type = "reload" }, state.current_url or state.last_target or "reload")
end

function M.navigate(url)
  if url == nil or url == "" then
    return false
  end
  if state.mode ~= "serve" or state.job_id == nil then
    local ok = restart_stopped_serve(url)
    if ok then
      state.last_target = url
    end
    return ok
  end
  request_resize()
  local ok = send_pending_request({
    type = "navigate",
    url = url,
  }, url)
  if ok then
    state.last_target = url
  end
  return ok
end

function M.back()
  request_resize()
  return send_pending_request({ type = "back" }, state.current_url or state.last_target or "back")
end

function M.forward()
  request_resize()
  return send_pending_request({ type = "forward" }, state.current_url or state.last_target or "forward")
end

function M.stop()
  if state.pending_operation == nil then
    if state.scroll_coalesce_request ~= nil then
      clear_scroll_coalesce()
      state.status_error = nil
      state.hint_error = nil
      if is_valid_buffer() then
        refresh_preview_footer(state.bufnr)
      end
      return true
    end
    return false
  end

  return hard_stop_pending_operation()
end

hard_stop_pending_operation = function(reason)
  local pending = state.pending_operation
  state.canceled_request_ids[pending.id] = true
  state.pending_operation = nil
  stop_operation_watchdog_timer()
  clear_navigation_admission(pending.id)
  state.stopped_operation = {
    id = pending.id,
    target = pending.target,
    reason = reason,
  }
  state.status_error = nil
  state.hint_error = nil
  state.rendered_frame_geometry = nil
  state.response_handlers[pending.id] = nil
  if state.latest_find_request_id == pending.id then
    state.latest_find_request_id = nil
  end
  state.generation = state.generation + 1
  stop_text_mode_flush_timer()
  stop_live_refresh()
  stop_resize_timer()
  clear_scroll_coalesce()
  hints_overlay.clear(state.bufnr)
  if is_valid_buffer() then
    refresh_preview_footer(state.bufnr)
  end
  state.mode = nil
  state.serve_output = nil
  state.runtime_metadata = nil
  state.latest_download = nil
  state.download_history = {}
  state.download_recorded_response_ids = {}
  state.latest_dialog = nil
  state.dialog_history = {}
  state.calibration_state = nil
  state.element_hints = {}
  state.element_hints_geometry = nil
  state.cursor_addressable_preview = false
  if state.job_id ~= nil then
    pcall(vim.fn.jobstop, state.job_id)
    state.job_id = nil
  end
  return true
end

hard_stop_capture_operation = function(reason)
  local request_id = state.live_refresh_request_id
  if request_id == nil then
    return false
  end
  state.canceled_request_ids[request_id] = true
  clear_in_flight_capture()
  state.stopped_operation = {
    id = request_id,
    target = state.current_url or state.last_target,
    reason = reason,
  }
  state.status_error = nil
  state.hint_error = nil
  state.rendered_frame_geometry = nil
  state.generation = state.generation + 1
  stop_text_mode_flush_timer()
  stop_live_refresh()
  stop_resize_timer()
  clear_scroll_coalesce()
  hints_overlay.clear(state.bufnr)
  if is_valid_buffer() then
    refresh_preview_footer(state.bufnr)
  end
  state.mode = nil
  state.serve_output = nil
  state.runtime_metadata = nil
  state.latest_download = nil
  state.download_history = {}
  state.download_recorded_response_ids = {}
  state.latest_dialog = nil
  state.dialog_history = {}
  state.element_hints = {}
  state.element_hints_geometry = nil
  state.cursor_addressable_preview = false
  if state.job_id ~= nil then
    pcall(vim.fn.jobstop, state.job_id)
    state.job_id = nil
  end
  return true
end

local function normalize_scroll_delta(value)
  value = tonumber(value) or 0
  if value > 0 then
    return math.ceil(value)
  end
  if value < 0 then
    return math.floor(value)
  end
  return 0
end

function M.scroll(delta_y, delta_x)
  request_resize()
  return queue_scroll_coalesce({
    kind = "scroll",
    delta_x = normalize_scroll_delta(delta_x),
    delta_y = normalize_scroll_delta(delta_y),
    target = state.current_url or state.last_target or "scroll",
  })
end

local function viewport_scroll_height()
  local metrics_height = state.page_metrics and tonumber(state.page_metrics.viewport_height) or nil
  local runtime_height = state.runtime_metadata
    and state.runtime_metadata.viewport
    and tonumber(state.runtime_metadata.viewport.height)
    or nil
  local height = metrics_height ~= nil and metrics_height > 0 and metrics_height or runtime_height
  if height ~= nil and height > 0 then
    return height
  end
  return nil
end

local function page_scroll_delta(fraction)
  fraction = tonumber(fraction) or 0.9
  if fraction <= 0 then
    fraction = 0.9
  end
  local height = viewport_scroll_height()
  if height == nil then
    return 400
  end
  return math.max(1, math.floor(height * fraction))
end

function M.page_scroll(direction, opts)
  opts = opts or {}
  local sign = tonumber(direction) or 1
  if sign < 0 then
    sign = -1
  else
    sign = 1
  end
  return M.scroll(page_scroll_delta(opts.fraction) * sign, 0)
end

local function metrics_scroll_delta_to_top()
  if type(state.page_metrics) ~= "table" then
    return nil
  end
  local scroll_y = tonumber(state.page_metrics.scroll_y)
  if scroll_y == nil then
    return nil
  end
  return -math.max(0, scroll_y)
end

local function metrics_scroll_delta_to_bottom()
  if type(state.page_metrics) ~= "table" then
    return nil
  end
  local scroll_y = tonumber(state.page_metrics.scroll_y)
  local viewport_height = tonumber(state.page_metrics.viewport_height)
  local document_height = tonumber(state.page_metrics.document_height)
  if scroll_y == nil or viewport_height == nil or document_height == nil then
    return nil
  end
  return math.max(0, document_height - viewport_height - scroll_y)
end

function M.scroll_top()
  local delta = metrics_scroll_delta_to_top() or -((viewport_scroll_height() or 400) * 100)
  return M.scroll(delta, 0)
end

function M.scroll_bottom()
  local delta = metrics_scroll_delta_to_bottom() or ((viewport_scroll_height() or 400) * 100)
  return M.scroll(delta, 0)
end

local function normalized_zoom_scale(value)
  value = tonumber(value) or 1.0
  value = math.max(0.25, math.min(3.0, value))
  return math.floor((value * 100) + 0.5) / 100
end

local function send_zoom(scale)
  request_resize()
  local next_scale = normalized_zoom_scale(scale)
  local ok = send_pending_request({
    type = "zoom",
    scale = next_scale,
  }, state.current_url or state.last_target or "zoom", "zoom", function(response)
    if response.status == "ok" then
      state.zoom_scale = next_scale
    end
  end)
  return ok
end

function M.zoom_in()
  return send_zoom(state.zoom_scale * 1.1)
end

function M.zoom_out()
  return send_zoom(state.zoom_scale / 1.1)
end

function M.zoom_reset()
  return send_zoom(1.0)
end

function M.input_text(text, opts)
  opts = opts or {}
  if text == nil or text == "" then
    return false
  end
  if opts.resize ~= false then
    request_resize()
  end
  return send_serve_request({
    type = "text_input",
    text = text,
    capture = opts.capture,
  })
end

function M.press_key(key, opts)
  opts = opts or {}
  if key == nil or key == "" then
    return false
  end
  if opts.resize ~= false then
    request_resize()
  end
  return send_serve_request({
    type = "key_press",
    key = key,
    modifiers = opts.modifiers or {},
    capture = opts.capture,
  })
end

function M.submit_focused()
  if state.mode ~= "serve" or state.job_id == nil then
    return false
  end
  request_resize()
  cancel_in_flight_capture()
  return send_pending_request({
    type = "submit_focused",
  }, state.current_url or state.last_target or "submit", "submit")
end

local function text_mode_key_action(key)
  if key == nil or key == "" then
    return nil
  end
  local keycodes = {
    escape = vim.keycode("<Esc>"),
    enter = vim.keycode("<CR>"),
    tab = vim.keycode("<Tab>"),
    shift_tab = vim.keycode("<S-Tab>"),
    backspace = vim.keycode("<BS>"),
    delete = vim.keycode("<Del>"),
    up = vim.keycode("<Up>"),
    down = vim.keycode("<Down>"),
    left = vim.keycode("<Left>"),
    right = vim.keycode("<Right>"),
  }
  if key == "\27" or key == keycodes.escape then
    return { type = "exit" }
  end
  if key == "\r" or key == "\n" or key == keycodes.enter then
    return { type = "key", key = "Enter" }
  end
  if key == "\t" or key == keycodes.tab then
    return { type = "key", key = "Tab" }
  end
  if key == keycodes.shift_tab then
    return { type = "key", key = "Tab", modifiers = { "shift" } }
  end
  if key == "\127" or key == "\8" or key == keycodes.backspace then
    return { type = "key", key = "Backspace" }
  end
  if key == keycodes.delete then
    return { type = "key", key = "Delete" }
  end
  if key == keycodes.up then
    return { type = "key", key = "ArrowUp" }
  end
  if key == keycodes.down then
    return { type = "key", key = "ArrowDown" }
  end
  if key == keycodes.left then
    return { type = "key", key = "ArrowLeft" }
  end
  if key == keycodes.right then
    return { type = "key", key = "ArrowRight" }
  end
  if key:find("\27", 1, true) == nil and vim.fn.strchars(key) == 1 and key:byte(1) >= 32 then
    return { type = "text", text = key }
  end
  return nil
end

local text_mode_flush_ms = 25
local text_mode_max_batch_chars = 32

stop_text_mode_flush_timer = function()
  if state.text_mode_flush_timer == nil then
    return
  end
  state.text_mode_flush_timer:stop()
  state.text_mode_flush_timer:close()
  state.text_mode_flush_timer = nil
end

function M.start_text_mode(opts)
  opts = opts or {}
  if state.mode ~= "serve" or state.job_id == nil or not is_valid_window() or not state.cursor_addressable_preview then
    vim.api.nvim_echo({ { "nvim-browser: text mode requires an active cursor-addressable browser preview", "WarningMsg" } }, false, {})
    return false
  end

  local getcharstr = opts.getcharstr or vim.fn.getcharstr
  local text_buffer = {}
  local text_buffer_chars = 0

  local function flush_text_buffer()
    stop_text_mode_flush_timer()
    if text_buffer_chars == 0 then
      return false
    end
    local text = table.concat(text_buffer)
    text_buffer = {}
    text_buffer_chars = 0
    return M.input_text(text, { capture = false, resize = false })
  end

  local function schedule_text_flush()
    stop_text_mode_flush_timer()
    local timer = timer_factory()
    if timer == nil then
      return false
    end
    state.text_mode_flush_timer = timer
    timer:start(text_mode_flush_ms, 0, function()
      vim.schedule(function()
        if state.text_mode_flush_timer ~= timer then
          return
        end
        state.text_mode_flush_timer = nil
        timer:close()
        flush_text_buffer()
      end)
    end)
    return true
  end

  state.text_mode_active = true
  refresh_preview_footer(state.bufnr)
  local ok, err = pcall(function()
    while state.text_mode_active do
      local key = getcharstr()
      local action = text_mode_key_action(key)
      if action == nil then
        -- Ignore terminal-only control sequences that do not map to browser input.
      elseif action.type == "exit" then
        flush_text_buffer()
        state.text_mode_active = false
      elseif action.type == "text" then
        table.insert(text_buffer, action.text)
        text_buffer_chars = text_buffer_chars + vim.fn.strchars(action.text)
        if text_buffer_chars >= text_mode_max_batch_chars then
          flush_text_buffer()
        else
          schedule_text_flush()
        end
      elseif action.type == "key" then
        flush_text_buffer()
        M.press_key(action.key, {
          capture = action.key == "Enter",
          modifiers = action.modifiers or {},
          resize = false,
        })
      end
    end
  end)
  flush_text_buffer()
  stop_text_mode_flush_timer()
  state.text_mode_active = false
  refresh_preview_footer(state.bufnr)
  send_capture_request({ force = true })
  if not ok then
    error(err)
  end
  return true
end

function M.focus_selector(selector)
  if selector == nil or selector == "" then
    return false
  end
  request_resize()
  return send_serve_request({
    type = "focus_selector",
    selector = selector,
  })
end

function M.click_point(x, y)
  x = tonumber(x)
  y = tonumber(y)
  if x == nil or y == nil then
    return false
  end
  request_resize()
  return send_pending_request({
    type = "click_point",
    x = x,
    y = y,
  }, state.current_url or state.last_target or "click", "click")
end

function M.drag_point(start_x, start_y, end_x, end_y)
  start_x = tonumber(start_x)
  start_y = tonumber(start_y)
  end_x = tonumber(end_x)
  end_y = tonumber(end_y)
  if start_x == nil or start_y == nil or end_x == nil or end_y == nil then
    return false
  end
  request_resize()
  return send_pending_request({
    type = "drag_point",
    start_x = start_x,
    start_y = start_y,
    end_x = end_x,
    end_y = end_y,
  }, state.current_url or state.last_target or "select", "select")
end

local function send_drag_point(start_x, start_y, end_x, end_y, on_response)
  start_x = tonumber(start_x)
  start_y = tonumber(start_y)
  end_x = tonumber(end_x)
  end_y = tonumber(end_y)
  if start_x == nil or start_y == nil or end_x == nil or end_y == nil then
    return false
  end
  request_resize()
  return send_pending_request({
    type = "drag_point",
    start_x = start_x,
    start_y = start_y,
    end_x = end_x,
    end_y = end_y,
  }, state.current_url or state.last_target or "select", "select", on_response)
end

function M.right_click_point(x, y)
  x = tonumber(x)
  y = tonumber(y)
  if x == nil or y == nil then
    return false
  end
  request_resize()
  return send_pending_request({
    type = "right_click_point",
    x = x,
    y = y,
  }, state.current_url or state.last_target or "right-click", "right-click")
end

function M.hover_point(x, y)
  x = tonumber(x)
  y = tonumber(y)
  if x == nil or y == nil then
    return false
  end
  request_resize()
  return send_pending_request({
    type = "hover_point",
    x = x,
    y = y,
  }, state.current_url or state.last_target or "hover", "hover")
end

function M.wheel_point(x, y, delta_y, delta_x)
  x = tonumber(x)
  y = tonumber(y)
  local raw_delta_y = tonumber(delta_y)
  if x == nil or y == nil or raw_delta_y == nil then
    return false
  end
  delta_y = normalize_scroll_delta(raw_delta_y)
  delta_x = normalize_scroll_delta(delta_x)
  request_resize()
  return queue_scroll_coalesce({
    kind = "wheel_point",
    x = x,
    y = y,
    delta_x = delta_x,
    delta_y = delta_y,
    target = state.current_url or state.last_target or "scroll",
  })
end

function M.type_point(x, y, text, opts)
  x = tonumber(x)
  y = tonumber(y)
  if x == nil or y == nil or text == nil or text == "" then
    return false
  end
  opts = opts or {}
  request_resize()
  return send_pending_request({
    type = "type_point",
    x = x,
    y = y,
    text = text,
    submit = opts.submit == true,
  }, state.current_url or state.last_target or "type", "type")
end

function M.find_text(query, opts)
  if query == nil or query == "" then
    return false
  end
  opts = opts or {}
  local backwards = opts.backwards == true
  state.last_find_query = query
  state.last_find_found = nil
  state.last_find_match_count = nil
  request_resize()
  local ok, id = send_pending_request({
    type = "find_text",
    query = query,
    backwards = backwards,
  }, query, "find", handle_find_text_response)
  if ok then
    state.latest_find_request_id = id
  end
  return ok
end

function M.find_next()
  if state.last_find_query == nil or state.last_find_query == "" then
    return false
  end
  return M.find_text(state.last_find_query, { backwards = false })
end

function M.find_previous()
  if state.last_find_query == nil or state.last_find_query == "" then
    return false
  end
  return M.find_text(state.last_find_query, { backwards = true })
end

function M.reader()
  local ok, id = send_serve_request({ type = "page_text" }, handle_reader_response)
  if ok then
    state.latest_reader_request_id = id
  end
  return ok
end

function M.probe_calibration_state(on_response)
  if state.mode ~= "serve" then
    return false
  end
  return send_serve_request({ type = "page_text" }, function(response)
    if response.status == "ok" and type(response.text) == "table" and response.text.text ~= nil then
      local calibration_state = parse_calibration_state(response.text.text)
      if calibration_state ~= nil then
        state.calibration_state = calibration_state
      end
    end
    if type(on_response) == "function" then
      on_response(response)
    end
  end)
end

function M.yank_selection(register)
  register = register or '"'
  if not valid_register(register) then
    return false
  end
  return send_serve_request({ type = "selection_text" }, handle_yank_selection_response(register))
end

function M.yank_page_text(register)
  register = register or '"'
  if not valid_register(register) then
    return false
  end
  local ok, id = send_serve_request({ type = "page_text" }, handle_yank_page_text_response(register))
  if ok then
    state.latest_page_text_yank_request_id = id
  end
  return ok
end

function M.yank_current_url(register)
  register = register or '"'
  return set_register(register, state.current_url)
end

function M.screenshot(path, opts)
  opts = opts or {}
  if path == nil or path == "" then
    return false
  end
  return send_serve_request({
    type = "screenshot",
    path = vim.fn.fnamemodify(tostring(path), ":p"),
  }, opts.on_response)
end

function M.reader_follow()
  if state.reader_bufnr == nil or not vim.api.nvim_buf_is_valid(state.reader_bufnr) then
    warn_reader_follow("nvim-browser: reader follow requires a reader buffer")
    return false
  end
  if vim.api.nvim_get_current_buf() ~= state.reader_bufnr then
    warn_reader_follow("nvim-browser: reader follow must be run from the reader buffer")
    return false
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_buf_get_lines(state.reader_bufnr, cursor[1] - 1, cursor[1], false)[1]
  local target = reader_url_at_line(line, cursor[2] + 1)
  local url = reader_resolve_url(target, state.reader_base_url or state.current_url or state.last_target)
  if url == nil then
    warn_reader_follow("nvim-browser: no reader link under cursor")
    return false
  end
  request_resize()
  local ok = send_pending_request({
    type = "navigate",
    url = url,
  }, url, "loading", function(response)
    if response.status == "ok" then
      M.reader()
    end
  end)
  if not ok then
    return false
  end
  state.last_target = url
  return url
end

function M.click_here()
  if state.mode ~= "serve" or not is_valid_window() or not state.cursor_addressable_preview then
    return false
  end

  local cursor = vim.api.nvim_win_get_cursor(state.winid)
  local geometry = current_preview_geometry()
  if cursor[1] > geometry.rows then
    return false
  end
  local column = vim.api.nvim_win_call(state.winid, function()
    return vim.fn.virtcol(".")
  end)
  if column > geometry.columns then
    return false
  end
  geometry = current_rendered_frame_geometry()
  if geometry == nil then
    return false
  end
  local point = M.viewport_point_for_cell(cursor[1], column, geometry)
  return M.click_point(point.x, point.y)
end

local function region_drag_points(start_row, start_col, end_row, end_col)
  if state.mode ~= "serve" or not is_valid_window() or not state.cursor_addressable_preview then
    return nil
  end

  start_row = tonumber(start_row)
  start_col = tonumber(start_col)
  end_row = tonumber(end_row)
  end_col = tonumber(end_col)
  if start_row == nil or start_col == nil or end_row == nil or end_col == nil then
    return nil
  end

  local preview_geometry = current_preview_geometry()
  if not cell_within_geometry(start_row, start_col, preview_geometry) then
    return nil
  end
  if not cell_within_geometry(end_row, end_col, preview_geometry) then
    return nil
  end

  local rendered_geometry = current_rendered_frame_geometry()
  if rendered_geometry == nil then
    return nil
  end

  local start_point = M.viewport_drag_point_for_cell(start_row, start_col, rendered_geometry, "start")
  local end_point = M.viewport_drag_point_for_cell(end_row, end_col, rendered_geometry, "end")
  return start_point, end_point
end

function M.select_region(start_row, start_col, end_row, end_col)
  local start_point, end_point = region_drag_points(start_row, start_col, end_row, end_col)
  if start_point == nil or end_point == nil then
    return false
  end
  return M.drag_point(start_point.x, start_point.y, end_point.x, end_point.y)
end

function M.yank_region(register, start_row, start_col, end_row, end_col)
  register = register or '"'
  if not valid_register(register) then
    return false
  end

  local start_point, end_point = region_drag_points(start_row, start_col, end_row, end_col)
  if start_point == nil or end_point == nil then
    return false
  end

  local drag_request_id
  local ok, id = send_drag_point(start_point.x, start_point.y, end_point.x, end_point.y, function(response)
    if drag_request_id ~= nil and response.id < state.latest_applied_response_id then
      return
    end
    if
      drag_request_id ~= nil
      and state.pending_operation ~= nil
      and state.pending_operation.id ~= drag_request_id
      and response.id < state.pending_operation.id
    then
      return
    end
    if response.status ~= "ok" then
      warn_selection_yank_failed()
      return
    end
    send_serve_request({ type = "selection_text" }, handle_yank_selection_response(register))
  end)
  drag_request_id = id
  return ok
end

function M.right_click_here()
  if state.mode ~= "serve" or not is_valid_window() or not state.cursor_addressable_preview then
    return false
  end

  local cursor = vim.api.nvim_win_get_cursor(state.winid)
  local geometry = current_preview_geometry()
  if cursor[1] > geometry.rows then
    return false
  end
  local column = vim.api.nvim_win_call(state.winid, function()
    return vim.fn.virtcol(".")
  end)
  if column > geometry.columns then
    return false
  end
  geometry = current_rendered_frame_geometry()
  if geometry == nil then
    return false
  end
  local point = M.viewport_point_for_cell(cursor[1], column, geometry)
  return M.right_click_point(point.x, point.y)
end

function M.hover_here()
  if state.mode ~= "serve" or not is_valid_window() or not state.cursor_addressable_preview then
    return false
  end

  local cursor = vim.api.nvim_win_get_cursor(state.winid)
  local geometry = current_preview_geometry()
  if cursor[1] > geometry.rows then
    return false
  end
  local column = vim.api.nvim_win_call(state.winid, function()
    return vim.fn.virtcol(".")
  end)
  if column > geometry.columns then
    return false
  end
  geometry = current_rendered_frame_geometry()
  if geometry == nil then
    return false
  end
  local point = M.viewport_point_for_cell(cursor[1], column, geometry)
  return M.hover_point(point.x, point.y)
end

function M.type_here(text, opts)
  if state.mode ~= "serve" or not is_valid_window() or not state.cursor_addressable_preview then
    return false
  end
  if text == nil or text == "" then
    return false
  end

  local cursor = vim.api.nvim_win_get_cursor(state.winid)
  local geometry = current_preview_geometry()
  if cursor[1] > geometry.rows then
    return false
  end
  local column = vim.api.nvim_win_call(state.winid, function()
    return vim.fn.virtcol(".")
  end)
  if column > geometry.columns then
    return false
  end
  geometry = current_rendered_frame_geometry()
  if geometry == nil then
    return false
  end
  local point = M.viewport_point_for_cell(cursor[1], column, geometry)
  return M.type_point(point.x, point.y, text, opts)
end

function M.click_mouse(mousepos)
  if state.mode ~= "serve" or not is_valid_window() or not state.cursor_addressable_preview then
    return false
  end
  mousepos = mousepos or vim.fn.getmousepos()
  if type(mousepos) ~= "table" or mousepos.winid ~= state.winid then
    return false
  end

  local row = tonumber(mousepos.line)
  local column = tonumber(mousepos.column)
  if row == nil or column == nil or row <= 0 or column <= 0 then
    return false
  end

  local geometry = current_preview_geometry()
  if not cell_within_geometry(row, column, geometry) then
    return false
  end
  geometry = current_rendered_frame_geometry()
  if geometry == nil then
    return false
  end

  local point = M.viewport_point_for_cell(row, column, geometry)
  return M.click_point(point.x, point.y)
end

function M.right_click_mouse(mousepos)
  if state.mode ~= "serve" or not is_valid_window() or not state.cursor_addressable_preview then
    return false
  end
  mousepos = mousepos or vim.fn.getmousepos()
  if type(mousepos) ~= "table" or mousepos.winid ~= state.winid then
    return false
  end

  local row = tonumber(mousepos.line)
  local column = tonumber(mousepos.column)
  if row == nil or column == nil or row <= 0 or column <= 0 then
    return false
  end

  local geometry = current_preview_geometry()
  if not cell_within_geometry(row, column, geometry) then
    return false
  end
  geometry = current_rendered_frame_geometry()
  if geometry == nil then
    return false
  end

  local point = M.viewport_point_for_cell(row, column, geometry)
  return M.right_click_point(point.x, point.y)
end

function M.wheel_mouse(delta_y, delta_x, mousepos)
  if state.mode ~= "serve" or not is_valid_window() or not state.cursor_addressable_preview then
    return false
  end
  mousepos = mousepos or vim.fn.getmousepos()
  if type(mousepos) ~= "table" or mousepos.winid ~= state.winid then
    return false
  end

  local row = tonumber(mousepos.line)
  local column = tonumber(mousepos.column)
  if row == nil or column == nil or row <= 0 or column <= 0 then
    return false
  end

  local geometry = current_preview_geometry()
  if not cell_within_geometry(row, column, geometry) then
    return false
  end
  geometry = current_rendered_frame_geometry()
  if geometry == nil then
    return false
  end

  local point = M.viewport_point_for_cell(row, column, geometry)
  return M.wheel_point(point.x, point.y, delta_y, delta_x)
end

local function send_click_hint_request(hint)
  cancel_in_flight_capture()
  return send_pending_request({
    type = "click_hint",
    hint_id = hint.id,
  }, state.current_url or state.last_target or "click", "click")
end

local function send_right_click_hint_request(hint)
  cancel_in_flight_capture()
  return send_pending_request({
    type = "right_click_hint",
    hint_id = hint.id,
  }, state.current_url or state.last_target or "right-click", "right-click")
end

function M.click_hint(id)
  if state.mode ~= "serve" or not is_valid_window() or state.element_hints_geometry == nil then
    return false
  end
  if not same_preview_geometry(state.element_hints_geometry, current_preview_geometry()) then
    return false
  end
  local hint = find_hint(state.element_hints, id)
  if hint ~= nil then
    return send_click_hint_request(hint)
  end
  return false
end

function M.right_click_hint(id)
  if state.mode ~= "serve" or not is_valid_window() or state.element_hints_geometry == nil then
    return false
  end
  if not same_preview_geometry(state.element_hints_geometry, current_preview_geometry()) then
    return false
  end
  local hint = find_hint(state.element_hints, id)
  if hint ~= nil then
    return send_right_click_hint_request(hint)
  end
  return false
end

function M.hover_hint(id)
  if state.mode ~= "serve" or not is_valid_window() or state.element_hints_geometry == nil then
    return false
  end
  if not same_preview_geometry(state.element_hints_geometry, current_preview_geometry()) then
    return false
  end
  local hint = find_hint(state.element_hints, id)
  if hint ~= nil then
    cancel_in_flight_capture()
    return send_pending_request({
      type = "hover_hint",
      hint_id = hint.id,
    }, state.current_url or state.last_target or "hover", "hover")
  end
  return false
end

function M.focus_hint(id)
  if state.mode ~= "serve" or not is_valid_window() or state.element_hints_geometry == nil then
    return false
  end
  if not same_preview_geometry(state.element_hints_geometry, current_preview_geometry()) then
    return false
  end
  local hint = find_hint(state.element_hints, id)
  if hint == nil then
    return false
  end
  cancel_in_flight_capture()
  return send_pending_request({
    type = "focus_hint",
    hint_id = hint.id,
  }, state.current_url or state.last_target or "focus", "focus")
end

function M.follow_hint(id)
  if state.mode ~= "serve" or not is_valid_window() or state.element_hints_geometry == nil then
    return false
  end
  if not same_preview_geometry(state.element_hints_geometry, current_preview_geometry()) then
    return false
  end
  local hint = find_hint(state.element_hints, id)
  if hint == nil then
    return false
  end
  if hint.kind == "link" and hint.href ~= nil and hint.href ~= "" then
    return M.navigate(hint.href)
  end
  return send_click_hint_request(hint)
end

local function active_hint_for_identifier(id)
  if state.mode ~= "serve" or not is_valid_window() or state.element_hints_geometry == nil then
    return nil
  end
  if not same_preview_geometry(state.element_hints_geometry, current_preview_geometry()) then
    return nil
  end
  return find_hint(state.element_hints, id)
end

local function hint_href_for_identifier(id)
  local hint = active_hint_for_identifier(id)
  if hint == nil or hint.href == nil or hint.href == vim.NIL or hint.href == "" then
    return nil
  end
  return tostring(hint.href)
end

function M.yank_hint_url(id, register)
  register = register or '"'
  if not valid_register(register) then
    return false
  end
  return set_register(register, hint_href_for_identifier(id))
end

function M.type_hint(id, text, opts)
  opts = opts or {}
  if text == nil or text == "" then
    return false
  end
  if state.mode ~= "serve" or not is_valid_window() or state.element_hints_geometry == nil then
    return false
  end
  if not same_preview_geometry(state.element_hints_geometry, current_preview_geometry()) then
    return false
  end
  local hint = find_hint(state.element_hints, id)
  if hint == nil then
    return false
  end
  local request = {
    type = "type_hint",
    hint_id = hint.id,
    text = text,
    submit = opts.submit == true,
  }
  local label = opts.submit == true and "submit" or "typing"
  cancel_in_flight_capture()
  return send_pending_request(request, state.current_url or state.last_target or label, label)
end

function M.select_hint(id, choice)
  if choice == nil or choice == "" then
    return false
  end
  if state.mode ~= "serve" or not is_valid_window() or state.element_hints_geometry == nil then
    return false
  end
  if not same_preview_geometry(state.element_hints_geometry, current_preview_geometry()) then
    return false
  end
  local hint = find_hint(state.element_hints, id)
  if hint == nil then
    return false
  end
  cancel_in_flight_capture()
  return send_pending_request({
    type = "select_hint",
    hint_id = hint.id,
    choice = choice,
  }, state.current_url or state.last_target or "select", "select")
end

function M.upload_hint(id, paths)
  if type(paths) == "string" then
    paths = { paths }
  end
  if type(paths) ~= "table" or #paths == 0 then
    return false
  end
  local normalized = {}
  for _, path in ipairs(paths) do
    if path == nil or path == "" then
      return false
    end
    table.insert(normalized, vim.fn.fnamemodify(tostring(path), ":p"))
  end
  if state.mode ~= "serve" or not is_valid_window() or state.element_hints_geometry == nil then
    return false
  end
  if not same_preview_geometry(state.element_hints_geometry, current_preview_geometry()) then
    return false
  end
  local hint = find_hint(state.element_hints, id)
  if hint == nil or hint.kind ~= "file" then
    return false
  end
  cancel_in_flight_capture()
  return send_pending_request({
    type = "upload_hint",
    hint_id = hint.id,
    paths = normalized,
  }, state.current_url or state.last_target or "upload", "upload")
end

function M.toggle_hint(id)
  if state.mode ~= "serve" or not is_valid_window() or state.element_hints_geometry == nil then
    return false
  end
  if not same_preview_geometry(state.element_hints_geometry, current_preview_geometry()) then
    return false
  end
  local hint = find_hint(state.element_hints, id)
  if hint == nil then
    return false
  end
  cancel_in_flight_capture()
  return send_pending_request({
    type = "toggle_hint",
    hint_id = hint.id,
  }, state.current_url or state.last_target or "toggle", "toggle")
end

function M.toggle()
  if is_valid_window() then
    pcall(send_terminal_escape, kitty_cleanup_escape())
    hints_overlay.clear(state.bufnr)
    vim.api.nvim_win_close(state.winid, true)
    state.winid = nil
    return false
  end

  if is_valid_buffer() then
    create_window()
    vim.api.nvim_win_set_buf(state.winid, state.bufnr)
    if state.last_payload_is_unicode and state.last_payload ~= nil then
      send_terminal_escape(state.last_payload)
    else
      emit_terminal_graphics(state.last_payload, state.winid)
    end
    if state.cursor_addressable_preview and same_preview_geometry(state.element_hints_geometry, current_preview_geometry()) then
      hints_overlay.apply(state.bufnr, state.element_hints, state.element_hints_geometry)
    else
      hints_overlay.clear(state.bufnr)
    end
    vim.cmd("redraw")
    return true
  end

  return false
end

function M.configure(opts)
  opts = opts or {}
  stop_text_mode_flush_timer()
  stop_resize_timer()
  clear_scroll_coalesce()
  options = vim.tbl_deep_extend("force", options, {
    live_refresh = opts.live_refresh or {},
    viewport = opts.viewport or {},
    navigation_timeout_ms = opts.navigation_timeout_ms,
  })
  if state.mode == "serve" and state.job_id ~= nil and is_valid_buffer() then
    if opts.viewport ~= nil then
      request_resize()
    end
    if opts.live_refresh ~= nil and opts.live_refresh.enabled == false then
      stop_adaptive_capture_timer()
    end
    start_live_refresh_timer(state.generation)
  else
    stop_live_refresh()
  end
end

function M.set_metadata_observer(observer)
  if observer ~= nil and type(observer) ~= "function" then
    return false
  end
  state.metadata_observer = observer
  return true
end

function M.set_download_observer(observer)
  if observer ~= nil and type(observer) ~= "function" then
    return false
  end
  state.download_observer = observer
  return true
end

function M.state()
  return {
    bufnr = state.bufnr,
    winid = state.winid,
    job_id = state.job_id,
    generation = state.generation,
    has_buffer = is_valid_buffer(),
    has_window = is_valid_window(),
    has_payload = state.last_payload ~= nil,
    mode = state.mode,
    serve_output = state.serve_output,
    cursor_addressable_preview = state.cursor_addressable_preview,
    current_preview_geometry = valid_preview_geometry(),
    text_mode_active = state.text_mode_active,
    last_target = state.last_target,
    current_url = state.current_url,
    current_title = state.current_title,
    page_metrics = state.page_metrics,
    focused_element = state.focused_element,
    latest_download = state.latest_download,
    download_history = copy_download_history(),
    latest_dialog = state.latest_dialog,
    dialog_history = vim.deepcopy(state.dialog_history),
    calibration_state = vim.deepcopy(state.calibration_state),
    zoom_scale = state.zoom_scale,
    runtime_metadata = state.runtime_metadata,
    rendered_frame_geometry = state.rendered_frame_geometry,
    status = state.status,
    status_error = state.status_error,
    hint_error = state.hint_error,
    pending_operation = state.pending_operation,
    live_refresh_request_id = state.live_refresh_request_id,
    stopped_operation = state.stopped_operation,
    last_find_found = state.last_find_found,
    last_find_match_count = state.last_find_match_count,
    last_find_query = state.last_find_query,
    element_hints = state.element_hints,
    reader_bufnr = state.reader_bufnr,
  }
end

function M.downloads()
  return copy_download_history()
end

M._test = {
  assign_hint_labels = assign_hint_labels,
  find_hint = find_hint,
  hint_href_for_identifier = hint_href_for_identifier,
  browser_buffer_name = browser_buffer_name,
  set_browser_buffer_name = set_browser_buffer_name,
  apply_hint_overlay = hints_overlay.apply,
  clear_hint_overlay = hints_overlay.clear,
  hint_namespace = function()
    return hints_overlay.namespace()
  end,
  handle_find_text_response = handle_find_text_response,
  dispatch_serve_response_handler = dispatch_serve_response_handler,
  handle_reader_response = handle_reader_response,
  reader_url_at_line = reader_url_at_line,
  apply_serve_response = apply_serve_response_metadata,
  apply_payload_to_buffer = apply_payload_to_buffer,
  preview_footer_line = preview_footer_line,
  focused_element_label = focused_element_label,
  append_preview_footer = append_preview_footer,
  set_pending_operation = function(value)
    state.pending_operation = value
  end,
  set_latest_applied_response_id = function(value)
    state.latest_applied_response_id = value
  end,
  response_handler_count = function()
    local count = 0
    for _ in pairs(state.response_handlers) do
      count = count + 1
    end
    return count
  end,
  set_timer_factory = function(factory)
    stop_text_mode_flush_timer()
    stop_live_refresh()
    stop_resize_timer()
    stop_adaptive_capture_timer()
    stop_operation_watchdog_timer()
    clear_scroll_coalesce()
    timer_factory = factory or function()
      return vim.loop.new_timer()
    end
  end,
  clear_pending_operation = clear_pending_operation,
  clear_in_flight_capture = function()
    clear_in_flight_capture()
  end,
  kitty_cleanup_escape = kitty_cleanup_escape,
  terminal_escape = terminal_escape,
  set_last_find_found = function(value)
    state.last_find_found = value
  end,
  set_last_find_query = function(value)
    state.last_find_query = value
  end,
  set_mode = function(value)
    state.mode = value
  end,
  set_job_id = function(value)
    state.job_id = value
  end,
  set_cursor_addressable_preview = function(value)
    state.cursor_addressable_preview = value
  end,
  set_element_hints = function(hints, geometry)
    state.element_hints = hints or {}
    state.element_hints_geometry = geometry
  end,
  text_mode_key_action = text_mode_key_action,
  command_for_window = command_for_window,
  kitty_unicode_cell_limit = kitty_unicode_cell_limit,
  set_test_window = function(winid)
    state.winid = winid
  end,
}

return M
