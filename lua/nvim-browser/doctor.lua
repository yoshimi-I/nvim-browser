local backend = require("nvim-browser.backend")
local terminal = require("nvim-browser.terminal")

local M = {}

local EXPECTED_SERVE_PROTOCOL_VERSION = 27

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
  local serve_exit = state and state.serve_exit or nil
  if type(serve_exit) == "table" then
    local code = serve_exit.code ~= nil and serve_exit.code ~= vim.NIL and tostring(serve_exit.code) or "unknown"
    local target = serve_exit.target ~= nil and serve_exit.target ~= vim.NIL and tostring(serve_exit.target) or "unknown"
    local restartable = serve_exit.restartable == true
    local line = "active session: exited code="
      .. code
      .. " target="
      .. target
      .. " restartable="
      .. tostring(restartable)
    if restartable then
      line = line .. "; run :NBrowserRefresh to restart"
    end
    return line
  end
  if state == nil or state.mode == nil or state.mode == "idle" then
    return "active session: none"
  end
  local output = state.serve_output or "unknown"
  local status = state.status or "unknown"
  return "active session: " .. state.mode .. " output=" .. output .. " status=" .. status
end

local function frame_health_line(state)
  if type(state) ~= "table" or type(state.frame_health) ~= "table" then
    if state ~= nil and state.mode == "serve" then
      return "frame health: ok"
    end
    return nil
  end
  local health = state.frame_health
  local parts = {}
  if health.stale == true then
    table.insert(parts, "stale")
  end
  if health.refresh_pending == true then
    table.insert(parts, "refresh pending")
  end
  if #parts == 0 then
    table.insert(parts, "ok")
  end
  if health.reason ~= nil and health.reason ~= vim.NIL and health.reason ~= "" then
    table.insert(parts, "reason=" .. tostring(health.reason))
  end
  return "frame health: " .. table.concat(parts, " ")
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

local function number_label(value)
  if type(value) ~= "number" then
    value = tonumber(value)
  end
  if value == nil then
    return "unknown"
  end
  if value % 1 == 0 then
    return tostring(math.floor(value))
  end
  return tostring(value)
end

local function geometry_label(geometry)
  return tostring(geometry.columns)
    .. "x"
    .. tostring(geometry.rows)
    .. " viewport="
    .. tostring(geometry.width)
    .. "x"
    .. tostring(geometry.height)
end

local function normalized_geometry(geometry)
  if type(geometry) ~= "table" then
    return nil
  end
  local columns = tonumber(geometry.columns)
  local rows = tonumber(geometry.rows)
  local width = tonumber(geometry.width)
  local height = tonumber(geometry.height)
  if columns == nil or rows == nil or width == nil or height == nil then
    return nil
  end
  if columns <= 0 or rows <= 0 or width <= 0 or height <= 0 then
    return nil
  end
  return {
    columns = columns,
    rows = rows,
    width = width,
    height = height,
  }
end

local function same_geometry(left, right)
  return left ~= nil
    and right ~= nil
    and left.columns == right.columns
    and left.rows == right.rows
    and left.width == right.width
    and left.height == right.height
end

local function output_is_cursor_addressable(output)
  return output == "ansi" or output == "kitty-unicode"
end

local function cursor_addressable(state)
  if state.cursor_addressable_preview ~= nil then
    return state.cursor_addressable_preview == true
  end
  local runtime = type(state.runtime_metadata) == "table" and state.runtime_metadata or nil
  return output_is_cursor_addressable(state.serve_output or (runtime and runtime.output))
end

local function click_calibration_line(state, cell)
  if state == nil or state.mode ~= "serve" then
    return "click calibration: inactive"
  end

  if not cursor_addressable(state) then
    return "click calibration: unavailable output=" .. tostring(state.serve_output or "unknown")
  end

  local rendered = normalized_geometry(state.rendered_frame_geometry)
  local current = normalized_geometry(state.current_preview_geometry)
  if rendered == nil or current == nil then
    return "click calibration: pending rendered frame"
  end

  if not same_geometry(rendered, current) then
    return "warning: click calibration rendered frame is stale; rendered="
      .. geometry_label(rendered)
      .. " current="
      .. geometry_label(current)
  end

  local first = terminal.viewport_point_for_cell(1, 1, rendered)
  local last = terminal.viewport_point_for_cell(rendered.rows, rendered.columns, rendered)
  return "click calibration: ok rendered="
    .. geometry_label(rendered)
    .. " cell="
    .. tostring(cell.width)
    .. "x"
    .. tostring(cell.height)
    .. " sample=1,1->"
    .. number_label(first.x)
    .. ","
    .. number_label(first.y)
    .. " "
    .. tostring(rendered.columns)
    .. ","
    .. tostring(rendered.rows)
    .. "->"
    .. number_label(last.x)
    .. ","
    .. number_label(last.y)
end

local function calibration_fixture_line(state)
  local calibration = state and state.calibration_state or nil
  if type(calibration) ~= "table" then
    return nil
  end
  local checks = {
    { key = "click", label = "click" },
    { key = "right_click", label = "right-click" },
    { key = "hover", label = "hover" },
    { key = "type", label = "type" },
    { key = "wheel", label = "wheel" },
  }
  local observed = {}
  local pending = {}
  for _, check in ipairs(checks) do
    if calibration[check.key] == true then
      table.insert(observed, check.label)
    else
      table.insert(pending, check.label)
    end
  end
  local observed_label = #observed > 0 and table.concat(observed, ", ") or "none"
  local pending_label = #pending > 0 and table.concat(pending, ", ") or "none"
  return "calibration fixture: observed " .. observed_label .. "; pending " .. pending_label
end

local function guided_calibration_line(config)
  local guided = config and config.guided_calibration or nil
  if type(guided) ~= "table" then
    return nil
  end
  local width = tonumber(guided.cell_width_px)
  local height = tonumber(guided.cell_height_px)
  if width == nil or height == nil then
    return nil
  end
  return "guided calibration: last saved "
    .. number_label(width)
    .. "x"
    .. number_label(height)
    .. " from row="
    .. tostring(guided.row or "unknown")
    .. " column="
    .. tostring(guided.column or "unknown")
    .. " target="
    .. tostring(guided.target_x or "unknown")
    .. ","
    .. tostring(guided.target_y or "unknown")
end

local function viewport_cell_pixels(config)
  local viewport = (config and config.viewport) or {}
  return {
    width = math.max(1, tonumber(viewport.cell_width_px) or 10),
    height = math.max(1, tonumber(viewport.cell_height_px) or 20),
  }
end

local function viewport_source(config, cell)
  if config ~= nil and config.viewport_source ~= nil and config.viewport_source ~= vim.NIL then
    return tostring(config.viewport_source)
  end
  local viewport = (config and config.viewport) or {}
  if tonumber(viewport.cell_width_px) == cell.width and tonumber(viewport.cell_height_px) == cell.height then
    if cell.width ~= 10 or cell.height ~= 20 then
      return "config"
    end
  end
  return "default"
end

local function doctor_command(config)
  local command = { config.binary or "nvbrowser", "doctor", "--json" }
  if config.cdp_ws_url ~= nil and config.cdp_ws_url ~= "" then
    table.insert(command, "--cdp-ws-url")
    table.insert(command, config.cdp_ws_url)
  end
  if config.user_data_dir ~= nil and config.user_data_dir ~= "" then
    table.insert(command, "--user-data-dir")
    table.insert(command, config.user_data_dir)
  end
  return command
end

local function default_system(command)
  local output = vim.fn.system(command)
  return {
    code = vim.v.shell_error,
    stdout = output,
    stderr = "",
  }
end

local function trim(value)
  return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function uses_kitty_graphics(output)
  return output == "kitty" or output == "kitty-unicode"
end

local function read_tmux_allow_passthrough(config)
  local runner = config._system or default_system
  local ok, result = pcall(runner, { "tmux", "show", "-gqv", "allow-passthrough" })
  if not ok or type(result) ~= "table" or result.code ~= 0 then
    return nil
  end
  local value = trim(result.stdout)
  if value == "" then
    return nil
  end
  return value
end

local function append_tmux_passthrough_diagnostics(report, config, graphics_resolution, browser_output)
  if graphics_resolution.multiplexer ~= "tmux" or not uses_kitty_graphics(browser_output) then
    return
  end

  local allow_passthrough = read_tmux_allow_passthrough(config)
  if allow_passthrough == "on" or allow_passthrough == "all" then
    add_item(report, "ok", "tmux allow-passthrough=" .. allow_passthrough)
    return
  end

  if allow_passthrough == nil then
    add_item(report, "warning", "tmux allow-passthrough unavailable; set -g allow-passthrough on")
  else
    add_item(report, "warning", "tmux allow-passthrough=" .. allow_passthrough .. "; set -g allow-passthrough on")
  end
end

local function read_backend_diagnostics(config)
  if config.backend_diagnostics == false then
    return nil
  end
  local runner = config._system or default_system
  local ok, result = pcall(runner, doctor_command(config))
  if not ok or type(result) ~= "table" or result.code ~= 0 then
    return nil, "backend diagnostics unavailable"
  end
  local decoded_ok, decoded = pcall(vim.json.decode, result.stdout or "")
  if not decoded_ok or type(decoded) ~= "table" or type(decoded.backend) ~= "table" then
    return nil, "backend diagnostics unavailable"
  end
  return decoded, nil
end

local function append_backend_diagnostics(report, config)
  local decoded, warning = read_backend_diagnostics(config)
  if decoded == nil then
    if warning ~= nil then
      add_item(report, "warning", warning)
    end
    return
  end

  local diagnostics = decoded.backend
  local status = diagnostics.status ~= nil and diagnostics.status ~= vim.NIL and tostring(diagnostics.status) or "unknown"
  local source = diagnostics.source ~= nil and diagnostics.source ~= vim.NIL and tostring(diagnostics.source) or nil
  if source ~= nil and source ~= "" and source ~= "none" then
    table.insert(report.lines, "backend: " .. status .. " via " .. source)
  else
    table.insert(report.lines, "backend: " .. status)
  end
  if diagnostics.cdp_ws_url ~= nil and diagnostics.cdp_ws_url ~= vim.NIL and diagnostics.cdp_ws_url ~= "" then
    table.insert(report.lines, "backend cdp: " .. tostring(diagnostics.cdp_ws_url))
  end
  if diagnostics.chrome_binary ~= nil and diagnostics.chrome_binary ~= vim.NIL and diagnostics.chrome_binary ~= "" then
    table.insert(report.lines, "backend chrome: " .. tostring(diagnostics.chrome_binary))
  end
  if diagnostics.user_data_dir ~= nil and diagnostics.user_data_dir ~= vim.NIL and diagnostics.user_data_dir ~= "" then
    table.insert(report.lines, "backend user data dir: " .. tostring(diagnostics.user_data_dir))
  end
  if diagnostics.warning ~= nil and diagnostics.warning ~= vim.NIL and diagnostics.warning ~= "" then
    add_item(report, "warning", tostring(diagnostics.warning))
  end

  local protocol = type(decoded.protocol) == "table" and tonumber(decoded.protocol.serve) or nil
  if protocol == nil then
    add_item(
      report,
      "warning",
      "backend protocol unavailable; plugin expects serve protocol="
        .. tostring(EXPECTED_SERVE_PROTOCOL_VERSION)
        .. "; rebuild or pin nvim-browser and nvbrowser to the same tag or commit"
    )
    return
  end
  if protocol == EXPECTED_SERVE_PROTOCOL_VERSION then
    add_item(report, "ok", "backend protocol matches plugin serve protocol=" .. tostring(EXPECTED_SERVE_PROTOCOL_VERSION))
  else
    add_item(
      report,
      "warning",
      "backend protocol mismatch; plugin expects serve protocol="
        .. tostring(EXPECTED_SERVE_PROTOCOL_VERSION)
        .. " but backend reports "
        .. tostring(protocol)
        .. "; rebuild or pin nvim-browser and nvbrowser to the same tag or commit"
    )
  end
end

local function append_active_protocol_diagnostics(report, terminal_state)
  local runtime = terminal_state and terminal_state.runtime_metadata or nil
  if type(runtime) ~= "table" then
    if terminal_state and terminal_state.mode == "serve" then
      add_item(
        report,
        "warning",
        "active session protocol unavailable; plugin expects serve protocol="
          .. tostring(EXPECTED_SERVE_PROTOCOL_VERSION)
          .. "; reopen the preview after rebuilding or updating nvbrowser"
      )
    end
    return
  end
  local protocol = tonumber(runtime.protocol_version)
  if protocol == EXPECTED_SERVE_PROTOCOL_VERSION then
    return
  end
  if protocol == nil then
    add_item(
      report,
      "warning",
      "active session protocol unavailable; plugin expects serve protocol="
        .. tostring(EXPECTED_SERVE_PROTOCOL_VERSION)
        .. "; reopen the preview after rebuilding or updating nvbrowser"
    )
    return
  end
  add_item(
    report,
    "warning",
    "active session protocol mismatch; plugin expects serve protocol="
      .. tostring(EXPECTED_SERVE_PROTOCOL_VERSION)
      .. " but session reports "
      .. tostring(protocol)
      .. "; reopen the preview after rebuilding or updating nvbrowser"
  )
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
      "viewport source: " .. viewport_source(config, cell),
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
  local frame_health = frame_health_line(terminal_state)
  if frame_health ~= nil then
    table.insert(report.lines, frame_health)
  end
  append_active_protocol_diagnostics(report, terminal_state)
  table.insert(report.lines, runtime_calibration(config, terminal_state, cell))
  table.insert(report.lines, click_calibration_line(terminal_state, cell))
  local fixture_line = calibration_fixture_line(terminal_state)
  if fixture_line ~= nil then
    table.insert(report.lines, fixture_line)
  end
  local guided_line = guided_calibration_line(config)
  if guided_line ~= nil then
    table.insert(report.lines, guided_line)
  end
  append_backend_diagnostics(report, config)

  if vim.fn.executable(config.binary or "nvbrowser") == 1 then
    add_item(report, "ok", "binary is executable")
  else
    add_item(report, "warning", "binary is not executable")
  end

  for _, warning in ipairs(graphics_resolution.warnings or {}) do
    add_item(report, "warning", warning)
  end
  append_tmux_passthrough_diagnostics(report, config, graphics_resolution, browser_output)

  if vim.env.ZELLIJ ~= nil and (config.graphics == nil or config.graphics == "auto") then
    if browser_output == "ansi" then
      add_item(report, "ok", "zellij ansi fallback keeps browser previews cursor-addressable")
    end
    add_item(report, "warning", "ZELLIJ detected; auto browser graphics uses ansi because terminal graphics may not pass through the multiplexer")
  end

  local active_output = terminal_state.runtime_metadata and terminal_state.runtime_metadata.output or terminal_state.serve_output
  if terminal_state.mode == "serve" and active_output ~= nil and active_output ~= browser_output then
    add_item(report, "warning", "active session output differs from current config; reopen the preview to use " .. browser_output)
  end

  return report
end

return M
