local backend = require("nvim-browser.backend")

local M = {}

local function command_output(command)
  for index, value in ipairs(command) do
    if value == "--output" then
      return command[index + 1]
    end
  end
  return "unknown"
end

local function add_item(report, level, message)
  table.insert(report.items, { level = level, message = message })
  table.insert(report.lines, level .. ": " .. message)
end

local function active_session_line(state)
  if state == nil or state.mode == nil or state.mode == "idle" then
    return "active session: none"
  end
  local output = state.serve_output or "unknown"
  local status = state.status or "unknown"
  return "active session: " .. state.mode .. " output=" .. output .. " status=" .. status
end

function M.run(config, terminal_state)
  config = config or {}
  terminal_state = terminal_state or {}

  local browser_output = command_output(backend.command_for(config.binary or "nvbrowser", "open", "https://example.com", config))
  local image_output = command_output(backend.command_for(config.binary or "nvbrowser", "open", "/tmp/nvim-browser-doctor.png", config))
  local report = {
    items = {},
    lines = {
      "nvim-browser doctor",
      "binary: " .. tostring(config.binary or "nvbrowser"),
      "graphics config: " .. tostring(config.graphics or "auto"),
      "browser output: " .. browser_output,
      "image output: " .. image_output,
      "environment: ZELLIJ=" .. tostring(vim.env.ZELLIJ or "") .. " TERM=" .. tostring(vim.env.TERM or ""),
      active_session_line(terminal_state),
    },
  }

  if vim.fn.executable(config.binary or "nvbrowser") == 1 then
    add_item(report, "ok", "binary is executable")
  else
    add_item(report, "warning", "binary is not executable")
  end

  if vim.env.ZELLIJ ~= nil and (config.graphics == nil or config.graphics == "auto") then
    add_item(report, "warning", "ZELLIJ detected; auto browser graphics uses ansi because terminal graphics may not pass through the multiplexer")
  elseif vim.env.ZELLIJ ~= nil and (config.graphics == "kitty" or config.graphics == "kitty-unicode") then
    add_item(report, "warning", "ZELLIJ detected with explicit Kitty graphics; images may not render unless the multiplexer passes graphics through")
  end

  if terminal_state.mode == "serve" and terminal_state.serve_output ~= nil and terminal_state.serve_output ~= browser_output then
    add_item(report, "warning", "active session output differs from current config; reopen the preview to use " .. browser_output)
  end

  return report
end

return M
