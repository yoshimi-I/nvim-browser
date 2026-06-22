local M = {}

local state = {
  bufnr = nil,
  winid = nil,
  job_id = nil,
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

local function create_window()
  vim.cmd("botright vertical split")
  vim.cmd("vertical resize " .. preview_width())
  state.winid = vim.api.nvim_get_current_win()
end

local function command_uses_ansi_browse(command)
  if type(command) ~= "table" or command[2] ~= "browse" then
    return false
  end

  for index, value in ipairs(command) do
    if value == "--output" and command[index + 1] == "ansi" then
      return true
    end
  end

  return false
end

local function command_has_columns(command)
  for _, value in ipairs(command) do
    if value == "--columns" then
      return true
    end
  end

  return false
end

local function command_for_window(command)
  if not command_uses_ansi_browse(command) or command_has_columns(command) then
    return command
  end

  local adjusted = vim.list_extend({}, command)
  table.insert(adjusted, "--columns")
  table.insert(adjusted, tostring(math.max(20, vim.api.nvim_win_get_width(state.winid) - 2)))
  return adjusted
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

  local previous_bufnr = state.bufnr
  state.bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(state.winid, state.bufnr)

  if previous_bufnr ~= nil and vim.api.nvim_buf_is_valid(previous_bufnr) then
    vim.api.nvim_buf_delete(previous_bufnr, { force = true })
  end

  vim.bo[state.bufnr].bufhidden = "hide"
  vim.bo[state.bufnr].filetype = "nvim-browser"
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
  return true
end

function M.close()
  if is_valid_window() then
    vim.api.nvim_win_close(state.winid, true)
  end
  if is_valid_buffer() then
    vim.api.nvim_buf_delete(state.bufnr, { force = true })
  end
  state.bufnr = nil
  state.winid = nil
  state.job_id = nil
end

function M.toggle()
  if is_valid_window() then
    vim.api.nvim_win_close(state.winid, true)
    state.winid = nil
    return false
  end

  if is_valid_buffer() then
    create_window()
    vim.api.nvim_win_set_buf(state.winid, state.bufnr)
    return true
  end

  return false
end

function M.state()
  return {
    bufnr = state.bufnr,
    winid = state.winid,
    job_id = state.job_id,
    has_buffer = is_valid_buffer(),
    has_window = is_valid_window(),
  }
end

return M
