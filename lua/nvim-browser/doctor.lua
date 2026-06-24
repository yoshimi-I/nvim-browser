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

local function runtime_line(state)
  local runtime = state and state.runtime_metadata or nil
  if type(runtime) ~= "table" then
    return nil
  end
  local cells = "unknown"
  if type(runtime.cells) == "table" and runtime.cells.columns ~= nil and runtime.cells.rows ~= nil then
    cells = tostring(runtime.cells.columns) .. "x" .. tostring(runtime.cells.rows)
  end
  local viewport = "unknown"
  if type(runtime.viewport) == "table" and runtime.viewport.width ~= nil and runtime.viewport.height ~= nil then
    viewport = tostring(runtime.viewport.width) .. "x" .. tostring(runtime.viewport.height)
    if runtime.viewport.device_scale_factor ~= nil then
      viewport = viewport .. "@" .. tostring(runtime.viewport.device_scale_factor)
    end
  end
  return "runtime: protocol="
    .. tostring(runtime.protocol_version or "unknown")
    .. " transport="
    .. tostring(runtime.transport or "unknown")
    .. " renderer="
    .. tostring(runtime.renderer or "unknown")
    .. " output="
    .. tostring(runtime.output or "unknown")
    .. " cells="
    .. cells
    .. " viewport="
    .. viewport
end

local function runtime_calibration(config, state, cell)
  local runtime = state and state.runtime_metadata or nil
  if type(runtime) ~= "table" then
    return "calibration: pending runtime metadata"
  end
  if type(runtime.cells) ~= "table" or type(runtime.viewport) ~= "table" then
    return "calibration: pending runtime metadata"
  end
  local columns = tonumber(runtime.cells.columns)
  local rows = tonumber(runtime.cells.rows)
  local width = tonumber(runtime.viewport.width)
  local height = tonumber(runtime.viewport.height)
  if columns == nil or rows == nil or width == nil or height == nil then
    return "calibration: pending runtime metadata"
  end
  local expected_width = columns * cell.width
  local expected_height = rows * cell.height
  local expected = tostring(expected_width) .. "x" .. tostring(expected_height)
  local actual = tostring(width) .. "x" .. tostring(height)
  if expected_width == width and expected_height == height then
    return "calibration: ok expected viewport=" .. expected
  end
  return "warning: calibration runtime viewport differs from configured cell pixels; expected viewport="
    .. expected
    .. " actual viewport="
    .. actual
end

local function viewport_cell_pixels(config)
  local viewport = (config and config.viewport) or {}
  return {
    width = math.max(1, tonumber(viewport.cell_width_px) or 10),
    height = math.max(1, tonumber(viewport.cell_height_px) or 20),
  }
end

function M.run(config, terminal_state)
  config = config or {}
  terminal_state = terminal_state or {}
  local cell = viewport_cell_pixels(config)

  local graphics_resolution = backend.resolve_graphics(config)
  local browser_output = command_output(backend.command_for(config.binary or "nvbrowser", "open", "https://example.com", config))
  local image_target_output = command_output(backend.command_for(config.binary or "nvbrowser", "open", "/tmp/nvim-browser-doctor.png", config))
  local report = {
    items = {},
    lines = {
      "nvim-browser doctor",
      "binary: " .. tostring(config.binary or "nvbrowser"),
      "graphics config: " .. tostring(config.graphics or "auto"),
      "terminal: " .. tostring(graphics_resolution.terminal or "unknown"),
      "multiplexer: " .. tostring(graphics_resolution.multiplexer or "unknown"),
      "viewport cell px: " .. tostring(cell.width) .. "x" .. tostring(cell.height),
      "browser output: " .. browser_output,
      "image target output: " .. image_target_output,
      "graphics reason: " .. tostring(graphics_resolution.reason or "unknown"),
      "environment: ZELLIJ=" .. tostring(vim.env.ZELLIJ or "") .. " TERM=" .. tostring(vim.env.TERM or ""),
      active_session_line(terminal_state),
    },
  }
  local runtime = runtime_line(terminal_state)
  if runtime ~= nil then
    table.insert(report.lines, runtime)
  end
  table.insert(report.lines, runtime_calibration(config, terminal_state, cell))

  if vim.fn.executable(config.binary or "nvbrowser") == 1 then
    add_item(report, "ok", "binary is executable")
  else
    add_item(report, "warning", "binary is not executable")
  end

  for _, warning in ipairs(graphics_resolution.warnings or {}) do
    add_item(report, "warning", warning)
  end

  if vim.env.ZELLIJ ~= nil and (config.graphics == nil or config.graphics == "auto") then
    add_item(report, "warning", "ZELLIJ detected; auto browser graphics uses ansi because terminal graphics may not pass through the multiplexer")
  end

  local active_output = terminal_state.runtime_metadata and terminal_state.runtime_metadata.output or terminal_state.serve_output
  if terminal_state.mode == "serve" and active_output ~= nil and active_output ~= browser_output then
    add_item(report, "warning", "active session output differs from current config; reopen the preview to use " .. browser_output)
  end

  return report
end

return M
