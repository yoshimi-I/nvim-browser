local M = {}

local namespace = vim.api.nvim_create_namespace("nvim-browser-hints")

local function clamp(value, lower, upper)
  return math.max(lower, math.min(value, upper))
end

function M.namespace()
  return namespace
end

function M.clear(bufnr)
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  end
end

function M.apply(bufnr, hints, geometry)
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  M.clear(bufnr)
  if type(hints) ~= "table" or #hints == 0 or geometry == nil then
    return
  end

  local columns = tonumber(geometry.columns) or 0
  local rows = tonumber(geometry.rows) or 0
  local width = tonumber(geometry.width) or 0
  local height = tonumber(geometry.height) or 0
  if columns <= 0 or rows <= 0 or width <= 0 or height <= 0 then
    return
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if line_count <= 0 then
    return
  end

  vim.api.nvim_set_hl(0, "NBrowserHint", { fg = "#111827", bg = "#facc15", bold = true })

  for _, hint in ipairs(hints) do
    local x = tonumber(hint.x)
    local y = tonumber(hint.y)
    if x ~= nil and y ~= nil and hint.id ~= nil then
      local label = tostring(hint.id)
      local label_width = math.max(1, vim.fn.strdisplaywidth(label))
      local row = clamp(math.floor(y * rows / height), 0, math.min(rows - 1, line_count - 1))
      local column = clamp(math.floor(x * columns / width), 0, math.max(0, columns - label_width))
      vim.api.nvim_buf_set_extmark(bufnr, namespace, row, 0, {
        virt_text = { { label, "NBrowserHint" } },
        virt_text_pos = "overlay",
        virt_text_win_col = column,
        hl_mode = "combine",
        priority = 200,
      })
    end
  end
end

return M
