local M = {}

local state = {
  last_target = nil,
}

local function default_binary()
  local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
  local candidate = root .. "/target/debug/nvbrowser"
  if vim.fn.executable(candidate) == 1 then
    return candidate
  end
  return "nvbrowser"
end

local function open_terminal(command)
  vim.cmd("botright split")
  vim.cmd("resize 16")
  vim.bo.bufhidden = "wipe"
  vim.bo.filetype = "nvim-browser"
  vim.fn.termopen(command)
  vim.cmd("startinsert")
end

local function is_image_extension(extension)
  return vim.tbl_contains({ "png", "jpg", "jpeg", "gif", "webp" }, extension)
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", {
    binary = default_binary(),
  }, opts or {})
end

function M.inspect(target)
  target = target or vim.fn.expand("%:p")
  state.last_target = target
  open_terminal({ M.config.binary, "inspect", target })
end

function M.open(target)
  target = target or vim.fn.expand("%:p")
  state.last_target = target

  local extension = vim.fn.fnamemodify(target, ":e"):lower()
  if extension == "md" or extension == "markdown" then
    open_terminal({ M.config.binary, "render-md", target })
    return
  end

  if is_image_extension(extension) then
    open_terminal({ M.config.binary, "show-image", target })
    return
  end

  open_terminal({ M.config.binary, "inspect", target })
end

function M.preview()
  M.open(vim.fn.expand("%:p"))
end

function M.last_target()
  return state.last_target
end

M.setup()

return M
