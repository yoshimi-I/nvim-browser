local M = {}

local function default_binary()
  local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
  local candidate = root .. "/target/debug/nvbrowser"
  if vim.fn.executable(candidate) == 1 then
    return candidate
  end
  return "nvbrowser"
end

M.options = {
  binary = default_binary(),
}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})
  return M.options
end

return M
