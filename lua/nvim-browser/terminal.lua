local M = {}

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
  next_request_id = 1,
  stop_timer = nil,
  current_url = nil,
  current_title = nil,
  status = nil,
  status_error = nil,
}

local kitty_placeholder = vim.fn.nr2char(0x10eeee)
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

local function command_uses_captured_browse(command)
  return command_uses_ansi_browse(command)
    or command_uses_kitty_browse(command)
    or command_uses_kitty_unicode_browse(command)
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

local function preview_cells()
  return {
    columns = math.max(20, vim.api.nvim_win_get_width(state.winid) - 2),
    rows = math.max(6, vim.api.nvim_win_get_height(state.winid) - 2),
  }
end

local function add_option(command, option, value)
  if command_has_option(command, option) then
    return
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
  then
    return command
  end

  local adjusted = vim.list_extend({}, command)

  if command_uses_ansi_browse(command) or command_uses_ansi_serve(command) then
    add_option(adjusted, "--columns", preview_cells().columns)
    return adjusted
  end

  local cells = preview_cells()
  add_option(adjusted, "--columns", cells.columns)
  add_option(adjusted, "--rows", cells.rows)
  add_option(adjusted, "--width", cells.columns * 10)
  add_option(adjusted, "--height", cells.rows * 20)
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

local function kitty_delete_escape()
  return "\x1b_Ga=d,d=i,i=" .. state.image_id .. "\x1b\\"
end

local function terminal_escape(payload)
  if vim.env.TMUX == nil or payload == nil or payload == "" then
    return payload
  end

  return "\x1bPtmux;" .. payload:gsub("\x1b", "\x1b\x1b") .. "\x1b\\"
end

local function send_terminal_escape(payload)
  vim.api.nvim_chan_send(vim.v.stderr, terminal_escape(payload))
end

local function send_serve_request(request)
  if state.mode ~= "serve" or state.job_id == nil then
    return false
  end

  request.id = state.next_request_id
  state.next_request_id = state.next_request_id + 1
  vim.fn.chansend(state.job_id, vim.json.encode(request) .. "\n")
  return true
end

local function stop_existing_job(force)
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

local function request_resize()
  if state.mode ~= "serve" or not is_valid_window() then
    return false
  end

  local cells = preview_cells()
  return send_serve_request({
    type = "resize",
    columns = cells.columns,
    rows = cells.rows,
    width = cells.columns * 10,
    height = cells.rows * 20,
  })
end

local function apply_payload_to_buffer(bufnr, payload, uses_kitty, uses_kitty_unicode, command)
  state.last_payload = (uses_kitty or uses_kitty_unicode) and payload or nil
  state.last_payload_is_unicode = uses_kitty_unicode and payload ~= nil

  vim.bo[bufnr].modifiable = true
  if uses_kitty_unicode then
    local columns = command_option_value(command, "--columns") or preview_cells().columns
    local rows = command_option_value(command, "--rows") or preview_cells().rows
    local lines = kitty_placeholder_lines(columns, rows)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    apply_kitty_placeholder_highlight(bufnr, #lines)
  elseif not uses_kitty then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
    local channel = vim.api.nvim_open_term(bufnr, {})
    vim.api.nvim_chan_send(channel, payload or "")
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
  send_terminal_escape(kitty_delete_escape())
  vim.api.nvim_chan_send(vim.v.stderr, cursor_position_escape(winid))
  send_terminal_escape(payload)
end

local function preview_lines(message, target)
  local lines = {
    message,
    "",
    "Target: " .. (target or ""),
  }
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
  command = command_for_window(command)

  stop_existing_job(false)

  state.generation = state.generation + 1
  state.last_payload = nil
  state.last_payload_is_unicode = false
  state.last_target = command_target(command)
  state.stream_buffer = ""
  state.mode = nil
  state.next_request_id = 1
  state.current_url = nil
  state.current_title = nil
  state.status = nil
  pcall(send_terminal_escape, kitty_delete_escape())

  local previous_bufnr = state.bufnr
  state.bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(state.winid, state.bufnr)

  if previous_bufnr ~= nil and vim.api.nvim_buf_is_valid(previous_bufnr) then
    vim.api.nvim_buf_delete(previous_bufnr, { force = true })
  end

  vim.bo[state.bufnr].bufhidden = "hide"
  vim.bo[state.bufnr].filetype = "nvim-browser"
  vim.bo[state.bufnr].buftype = "nofile"
  vim.bo[state.bufnr].swapfile = false

  if command_uses_serve(command) then
    state.mode = "serve"
    local bufnr = state.bufnr
    local generation = state.generation
    local target = command_target(command)
    local uses_kitty = command_uses_kitty_serve(command)
    local uses_kitty_unicode = command_uses_kitty_unicode_serve(command)

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

        state.status = response.status
        state.status_error = response.error
        if response.url ~= nil then
          state.current_url = response.url
        end
        if response.title ~= nil then
          state.current_title = response.title ~= vim.NIL and response.title or nil
        end

        if response.status == "ok" and response.payload ~= nil then
          apply_payload_to_buffer(bufnr, response.payload, uses_kitty, uses_kitty_unicode, command)
          if uses_kitty then
            emit_terminal_graphics(response.payload, state.winid)
          elseif uses_kitty_unicode then
            send_terminal_escape(response.payload)
            vim.cmd("redraw")
          end
          return
        end

        if response.status == "error" then
          vim.api.nvim_echo({ { "nvim-browser: " .. (response.error or "unknown error"), "WarningMsg" } }, false, {})
        end
      end)
    end

    state.job_id = vim.fn.jobstart(command, {
      stdout_buffered = false,
      stderr_buffered = true,
      on_stdout = function(_, data)
        if not data then
          return
        end
        state.stream_buffer = state.stream_buffer .. table.concat(data, "\n")
        while true do
          local newline = state.stream_buffer:find("\n", 1, true)
          if newline == nil then
            break
          end
          local line = state.stream_buffer:sub(1, newline - 1)
          state.stream_buffer = state.stream_buffer:sub(newline + 1)
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
          if code ~= 0 and vim.api.nvim_buf_is_valid(bufnr) then
            vim.bo[bufnr].modifiable = true
            vim.api.nvim_buf_set_lines(
              bufnr,
              0,
              -1,
              false,
              preview_lines("Browser session exited: " .. code, target)
            )
            vim.bo[bufnr].modifiable = false
          end
        end)
      end,
    })
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
  pcall(send_terminal_escape, kitty_delete_escape())
  if is_valid_window() then
    vim.api.nvim_win_close(state.winid, true)
  end
  if is_valid_buffer() then
    vim.api.nvim_buf_delete(state.bufnr, { force = true })
  end
  state.bufnr = nil
  state.winid = nil
  state.job_id = nil
  state.last_payload = nil
  state.last_payload_is_unicode = false
  state.last_target = nil
  state.stream_buffer = ""
  state.mode = nil
  state.current_url = nil
  state.current_title = nil
  state.status = nil
  state.status_error = nil
  if state.stop_timer ~= nil then
    state.stop_timer:stop()
    state.stop_timer:close()
    state.stop_timer = nil
  end
end

function M.refresh()
  if request_resize() then
    return true
  end
  return send_serve_request({ type = "capture" })
end

function M.reload()
  request_resize()
  return send_serve_request({ type = "reload" })
end

function M.navigate(url)
  if url == nil or url == "" then
    return false
  end
  request_resize()
  return send_serve_request({
    type = "navigate",
    url = url,
  })
end

function M.back()
  request_resize()
  return send_serve_request({ type = "back" })
end

function M.forward()
  request_resize()
  return send_serve_request({ type = "forward" })
end

function M.scroll(delta_y, delta_x)
  request_resize()
  return send_serve_request({
    type = "scroll",
    delta_x = delta_x or 0,
    delta_y = delta_y or 0,
  })
end

function M.input_text(text)
  if text == nil or text == "" then
    return false
  end
  request_resize()
  return send_serve_request({
    type = "text_input",
    text = text,
  })
end

function M.press_key(key)
  if key == nil or key == "" then
    return false
  end
  request_resize()
  return send_serve_request({
    type = "key_press",
    key = key,
  })
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
  return send_serve_request({
    type = "click_point",
    x = x,
    y = y,
  })
end

function M.toggle()
  if is_valid_window() then
    pcall(send_terminal_escape, kitty_delete_escape())
    vim.api.nvim_win_close(state.winid, true)
    state.winid = nil
    return false
  end

  if is_valid_buffer() then
    create_window()
    vim.api.nvim_win_set_buf(state.winid, state.bufnr)
    if state.last_payload_is_unicode and state.last_payload ~= nil then
      send_terminal_escape(state.last_payload)
      vim.cmd("redraw")
    else
      emit_terminal_graphics(state.last_payload, state.winid)
    end
    return true
  end

  return false
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
    current_url = state.current_url,
    current_title = state.current_title,
    status = state.status,
    status_error = state.status_error,
  }
end

return M
