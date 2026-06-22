local M = {}

local state = {
  bufnr = nil,
  winid = nil,
  job_id = nil,
}

local function is_valid_buffer()
  return state.bufnr ~= nil and vim.api.nvim_buf_is_valid(state.bufnr)
end

local function is_valid_window()
  return state.winid ~= nil and vim.api.nvim_win_is_valid(state.winid)
end

local function create_window()
  vim.cmd("botright split")
  vim.cmd("resize 16")
  state.winid = vim.api.nvim_get_current_win()
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
