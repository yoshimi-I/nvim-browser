local backend = require("nvim-browser.backend")
local config = require("nvim-browser.config")
local terminal = require("nvim-browser.terminal")

local M = {}

local state = {
  last_target = nil,
}

function M.setup(opts)
  M.config = config.setup(opts)
end

local function resolve_target(target)
  return target or vim.fn.expand("%:p")
end

function M.inspect(target)
  target = resolve_target(target)
  state.last_target = target
  terminal.open(backend.command_for(M.config.binary, "inspect", target, M.config))
end

function M.open(target)
  target = resolve_target(target)
  state.last_target = target
  terminal.open(backend.command_for(M.config.binary, "open", target, M.config))
end

function M.preview()
  M.open(vim.fn.expand("%:p"))
end

function M.focus()
  return terminal.focus()
end

function M.close()
  terminal.close()
end

function M.toggle()
  return terminal.toggle()
end

function M.last_target()
  return state.last_target
end

M.setup()

return M
