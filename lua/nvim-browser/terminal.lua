local M = {}

local state = {
  bufnr = nil,
  winid = nil,
  job_id = nil,
  image_id = 1,
  generation = 0,
  last_payload = nil,
  last_target = nil,
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

local function command_uses_ansi_browse(command)
  return command_uses_browse_output(command, "ansi")
end

local function command_uses_kitty_browse(command)
  return command_uses_browse_output(command, "kitty")
end

local function command_uses_captured_browse(command)
  return command_uses_ansi_browse(command) or command_uses_kitty_browse(command)
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
  if not command_uses_ansi_browse(command) and not command_uses_kitty_browse(command) then
    return command
  end

  local adjusted = vim.list_extend({}, command)

  if command_uses_ansi_browse(command) then
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

  if state.job_id ~= nil then
    pcall(vim.fn.jobstop, state.job_id)
  end

  state.generation = state.generation + 1
  state.last_payload = nil
  state.last_target = command[3]
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

  if command_uses_captured_browse(command) then
    local bufnr = state.bufnr
    local winid = state.winid
    local generation = state.generation
    local target = command[3]
    local uses_kitty = command_uses_kitty_browse(command)
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
          state.last_payload = uses_kitty and payload or nil

          vim.bo[bufnr].modifiable = true
          if code == 0 and not uses_kitty then
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
            local channel = vim.api.nvim_open_term(bufnr, {})
            vim.api.nvim_chan_send(channel, payload or "")
          else
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
          end
          vim.bo[bufnr].modifiable = false

          if code == 0 and uses_kitty then
            emit_terminal_graphics(payload, is_valid_window_id(state.winid) and state.winid or winid)
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
  emit_terminal_graphics(state.last_payload, state.winid)
  return true
end

function M.close()
  state.generation = state.generation + 1
  if state.job_id ~= nil then
    pcall(vim.fn.jobstop, state.job_id)
  end
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
  state.last_target = nil
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
    emit_terminal_graphics(state.last_payload, state.winid)
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
  }
end

return M
