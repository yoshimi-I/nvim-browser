local M = {}

function M.open(command)
  vim.cmd("botright split")
  vim.cmd("resize 16")
  vim.bo.bufhidden = "wipe"
  vim.bo.filetype = "nvim-browser"
  vim.fn.termopen(command)
  vim.cmd("startinsert")
end

return M
