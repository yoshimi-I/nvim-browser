local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local doctor = require("nvim-browser.doctor")

local original_zellij = vim.env.ZELLIJ
local original_term = vim.env.TERM
local original_tmux = vim.env.TMUX
local original_term_program = vim.env.TERM_PROGRAM
local original_ghostty = vim.env.GHOSTTY_RESOURCES_DIR

local function contains_line(report, pattern)
  for _, line in ipairs(report.lines) do
    if line:find(pattern, 1, true) then
      return true
    end
  end
  return false
end

local function has_line(report, expected)
  for _, line in ipairs(report.lines) do
    if line == expected then
      return true
    end
  end
  return false
end

local function count_lines(report, pattern)
  local count = 0
  for _, line in ipairs(report.lines) do
    if line:find(pattern, 1, true) then
      count = count + 1
    end
  end
  return count
end

vim.env.ZELLIJ = "1"
vim.env.TMUX = nil
vim.env.TERM = "xterm-256color"
vim.env.TERM_PROGRAM = nil
vim.env.GHOSTTY_RESOURCES_DIR = nil
local zellij_auto = doctor.run({
  binary = "definitely-missing-nvbrowser",
  graphics = "auto",
  image_fit = "original",
}, {})
assert(contains_line(zellij_auto, "browser output: ansi"), "auto graphics under Zellij should choose ANSI browser output")
assert(has_line(zellij_auto, "image target output: ansi"), "auto image targets under Zellij should choose ANSI browser output")
assert(contains_line(zellij_auto, "terminal: unknown"), "doctor should report detected terminal")
assert(contains_line(zellij_auto, "multiplexer: zellij"), "doctor should report detected multiplexer")
assert(contains_line(zellij_auto, "graphics reason: Zellij"), "doctor should explain auto graphics selection")
assert(
  has_line(zellij_auto, "ok: zellij ansi fallback keeps browser previews cursor-addressable"),
  "doctor should explain that Zellij auto fallback remains usable for cursor-addressable browser previews"
)
assert(contains_line(zellij_auto, "warning: ZELLIJ detected"), "auto graphics under Zellij should explain ANSI fallback")
assert(contains_line(zellij_auto, "warning: binary is not executable"), "missing binary should warn")

vim.env.ZELLIJ = nil
vim.env.TMUX = nil
vim.env.TERM_PROGRAM = "ghostty"
vim.env.TERM = "xterm-ghostty"
local outside_zellij = doctor.run({
  binary = "nvim",
  backend_diagnostics = false,
  graphics = "auto",
  image_fit = "original",
  viewport = {
    cell_width_px = 9,
    cell_height_px = 15,
  },
}, {})
assert(contains_line(outside_zellij, "browser output: kitty-unicode"), "auto graphics outside Zellij should choose Kitty Unicode")
assert(
  has_line(outside_zellij, "image target output: kitty-unicode"),
  "auto image targets in Ghostty should choose Kitty Unicode browser output"
)
assert(contains_line(outside_zellij, "terminal: ghostty"), "doctor should report Ghostty detection")
assert(contains_line(outside_zellij, "graphics reason: Ghostty"), "doctor should explain Ghostty graphics support")
assert(contains_line(outside_zellij, "viewport cell px: 9x15"), "doctor should report configured viewport cell pixel size")
assert(contains_line(outside_zellij, "viewport source: config"), "doctor should report configured viewport source")

vim.env.TERM_PROGRAM = nil
vim.env.TERM = "xterm-256color"
local normalized_viewport = doctor.run({
  binary = "nvim",
  backend_diagnostics = false,
  graphics = "auto",
  image_fit = "original",
  viewport = {
    cell_width_px = 0,
    cell_height_px = "bad",
  },
}, {})
assert(contains_line(normalized_viewport, "viewport cell px: 1x20"), "doctor should report effective normalized viewport cell pixel size")
assert(contains_line(normalized_viewport, "viewport source: default"), "doctor should report default viewport source")
assert(contains_line(normalized_viewport, "browser output: ansi"), "unknown terminals should use ANSI fallback")

local persisted_viewport = doctor.run({
  binary = "nvim",
  backend_diagnostics = false,
  graphics = "auto",
  image_fit = "original",
  viewport = {
    cell_width_px = 11,
    cell_height_px = 22,
  },
  viewport_source = "persisted",
}, {})
assert(contains_line(persisted_viewport, "viewport cell px: 11x22"), "doctor should report persisted viewport cell size")
assert(contains_line(persisted_viewport, "viewport source: persisted"), "doctor should report persisted viewport source")

vim.env.ZELLIJ = "1"
local explicit_kitty = doctor.run({
  binary = "nvim",
  backend_diagnostics = false,
  graphics = "kitty-unicode",
  image_fit = "original",
}, {})
assert(contains_line(explicit_kitty, "warning: ZELLIJ detected with explicit Kitty graphics"), "explicit Kitty under Zellij should warn")
assert(count_lines(explicit_kitty, "warning: ZELLIJ detected with explicit Kitty graphics") == 1, "explicit Kitty under Zellij should warn only once")

vim.env.ZELLIJ = nil
vim.env.TMUX = "/tmp/tmux-501/default,123,0"
vim.env.TERM_PROGRAM = "ghostty"
vim.env.TERM = "tmux-256color"
local tmux_auto = doctor.run({
  binary = "nvim",
  backend_diagnostics = false,
  graphics = "auto",
  image_fit = "original",
  _system = function(command)
    assert(table.concat(command, " ") == "tmux show -gqv allow-passthrough", "doctor should probe tmux allow-passthrough")
    return { code = 0, stdout = "on\n", stderr = "" }
  end,
}, {})
assert(contains_line(tmux_auto, "multiplexer: tmux"), "doctor should report tmux detection")
assert(contains_line(tmux_auto, "browser output: kitty-unicode"), "tmux auto should preserve Kitty Unicode output")
assert(contains_line(tmux_auto, "graphics reason: tmux"), "doctor should explain tmux passthrough selection")
assert(contains_line(tmux_auto, "warning: tmux detected"), "doctor should warn that tmux passthrough must be enabled")
assert(has_line(tmux_auto, "ok: tmux allow-passthrough=on"), "doctor should report enabled tmux passthrough")

local tmux_disabled = doctor.run({
  binary = "nvim",
  backend_diagnostics = false,
  graphics = "kitty-unicode",
  image_fit = "original",
  _system = function()
    return { code = 0, stdout = "off\n", stderr = "" }
  end,
}, {})
assert(has_line(tmux_disabled, "warning: tmux allow-passthrough=off; set -g allow-passthrough on"), "doctor should warn when tmux passthrough is disabled")

local tmux_all = doctor.run({
  binary = "nvim",
  backend_diagnostics = false,
  graphics = "kitty-unicode",
  image_fit = "original",
  _system = function()
    return { code = 0, stdout = "all\n", stderr = "" }
  end,
}, {})
assert(has_line(tmux_all, "ok: tmux allow-passthrough=all"), "doctor should accept tmux allow-passthrough=all")

local tmux_empty_probe = doctor.run({
  binary = "nvim",
  backend_diagnostics = false,
  graphics = "kitty-unicode",
  image_fit = "original",
  _system = function()
    return { code = 0, stdout = "\n", stderr = "" }
  end,
}, {})
assert(contains_line(tmux_empty_probe, "warning: tmux allow-passthrough unavailable"), "doctor should warn when tmux passthrough output is empty")

local tmux_missing_probe = doctor.run({
  binary = "nvim",
  backend_diagnostics = false,
  graphics = "kitty",
  image_fit = "original",
  _system = function()
    return { code = 127, stdout = "", stderr = "tmux not found" }
  end,
}, {})
assert(contains_line(tmux_missing_probe, "warning: tmux allow-passthrough unavailable"), "doctor should warn when the tmux passthrough probe fails")

local tmux_ansi = doctor.run({
  binary = "nvim",
  backend_diagnostics = false,
  graphics = "ansi",
  image_fit = "original",
  _system = function()
    error("ansi output should not probe tmux passthrough")
  end,
}, {})
assert(not contains_line(tmux_ansi, "allow-passthrough"), "ANSI output should not report tmux passthrough")

vim.env.TMUX = nil
vim.env.TERM_PROGRAM = "ghostty"
vim.env.TERM = "xterm-ghostty"
local stale_session = doctor.run({
  binary = "nvim",
  backend_diagnostics = false,
  graphics = "auto",
  image_fit = "original",
}, {
  mode = "serve",
  serve_output = "ansi",
  has_buffer = true,
  has_window = true,
  status = "ok",
  runtime_metadata = {
    protocol_version = 1,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "ansi",
    cells = { columns = 80, rows = 24 },
    viewport = { width = 800, height = 480, device_scale_factor = 1 },
  },
})
assert(contains_line(stale_session, "active session: serve output=ansi status=ok"), "active serve state should be reported")
assert(
  contains_line(stale_session, "runtime: protocol=1 transport=stdio-jsonl renderer=chromium-cdp output=ansi cells=80x24 viewport=800x480@1"),
  "runtime metadata should be reported"
)
assert(contains_line(stale_session, "calibration: ok expected viewport=800x480"), "doctor should report matching runtime viewport calibration")
assert(contains_line(stale_session, "warning: active session output differs"), "doctor should warn about stale active output")

local mismatched_runtime = doctor.run({
  binary = "nvim",
  backend_diagnostics = false,
  graphics = "auto",
  image_fit = "original",
  viewport = {
    cell_width_px = 9,
    cell_height_px = 18,
  },
}, {
  mode = "serve",
  serve_output = "kitty-unicode",
  status = "ok",
  runtime_metadata = {
    protocol_version = 1,
    transport = "stdio-jsonl",
    renderer = "chromium-cdp",
    output = "kitty-unicode",
    cells = { columns = 80, rows = 24 },
    viewport = { width = 800, height = 480, device_scale_factor = 1 },
  },
})
assert(
  contains_line(mismatched_runtime, "warning: calibration runtime viewport differs from configured cell pixels; expected viewport=720x432 actual viewport=800x480"),
  "doctor should warn when runtime viewport does not match configured calibration"
)

local inactive_click_calibration = doctor.run({
  binary = "nvim",
  backend_diagnostics = false,
  graphics = "auto",
  image_fit = "original",
}, {})
assert(
  has_line(inactive_click_calibration, "click calibration: inactive"),
  "doctor should report inactive click calibration without an active serve session"
)

local unavailable_click_calibration = doctor.run({
  binary = "nvim",
  backend_diagnostics = false,
  graphics = "auto",
  image_fit = "original",
}, {
  mode = "serve",
  serve_output = "kitty",
  cursor_addressable_preview = false,
  status = "ok",
})
assert(
  has_line(unavailable_click_calibration, "click calibration: unavailable output=kitty"),
  "doctor should report unavailable click calibration for non cursor-addressable output"
)

local pending_click_calibration = doctor.run({
  binary = "nvim",
  backend_diagnostics = false,
  graphics = "auto",
  image_fit = "original",
}, {
  mode = "serve",
  serve_output = "ansi",
  cursor_addressable_preview = true,
  current_preview_geometry = { columns = 80, rows = 24, width = 800, height = 480 },
  status = "ok",
})
assert(
  has_line(pending_click_calibration, "click calibration: pending rendered frame"),
  "doctor should wait for rendered frame geometry before reporting click calibration ok"
)

local ok_click_calibration = doctor.run({
  binary = "nvim",
  backend_diagnostics = false,
  graphics = "auto",
  image_fit = "original",
  viewport = {
    cell_width_px = 10,
    cell_height_px = 20,
  },
}, {
  mode = "serve",
  serve_output = "ansi",
  cursor_addressable_preview = true,
  rendered_frame_geometry = { columns = 80, rows = 24, width = 800, height = 480 },
  current_preview_geometry = { columns = 80, rows = 24, width = 800, height = 480 },
  status = "ok",
})
assert(
  has_line(
    ok_click_calibration,
    "click calibration: ok rendered=80x24 viewport=800x480 cell=10x20 sample=1,1->5,10 80,24->795,470"
  ),
  "doctor should report exact click sample mapping when rendered and current geometry match"
)

local observed_fixture_calibration = doctor.run({
  binary = "nvim",
  backend_diagnostics = false,
  graphics = "auto",
  image_fit = "original",
  viewport = {
    cell_width_px = 10,
    cell_height_px = 20,
  },
}, {
  mode = "serve",
  serve_output = "ansi",
  cursor_addressable_preview = true,
  rendered_frame_geometry = { columns = 80, rows = 24, width = 800, height = 480 },
  current_preview_geometry = { columns = 80, rows = 24, width = 800, height = 480 },
  status = "ok",
  calibration_state = {
    click = true,
    right_click = false,
    hover = true,
    type = true,
    wheel = false,
  },
})
assert(
  has_line(observed_fixture_calibration, "calibration fixture: observed click, hover, type; pending right-click, wheel"),
  "doctor should report observed and pending calibration fixture hit tests"
)

local guided_fixture_calibration = doctor.run({
  binary = "nvim",
  backend_diagnostics = false,
  graphics = "auto",
  image_fit = "original",
  viewport = {
    cell_width_px = 12,
    cell_height_px = 24,
  },
  guided_calibration = {
    cell_width_px = 12,
    cell_height_px = 24,
    row = 12,
    column = 41,
    target_x = 405,
    target_y = 230,
  },
}, {
  mode = "serve",
  serve_output = "ansi",
  cursor_addressable_preview = true,
  rendered_frame_geometry = { columns = 80, rows = 24, width = 960, height = 576 },
  current_preview_geometry = { columns = 80, rows = 24, width = 960, height = 576 },
  status = "ok",
})
assert(
  has_line(guided_fixture_calibration, "guided calibration: last saved 12x24 from row=12 column=41 target=405,230"),
  "doctor should report the last guided calibration sample"
)

local stale_click_calibration = doctor.run({
  binary = "nvim",
  backend_diagnostics = false,
  graphics = "auto",
  image_fit = "original",
}, {
  mode = "serve",
  serve_output = "ansi",
  cursor_addressable_preview = true,
  rendered_frame_geometry = { columns = 80, rows = 24, width = 800, height = 480 },
  current_preview_geometry = { columns = 90, rows = 20, width = 900, height = 400 },
  status = "ok",
})
assert(
  has_line(
    stale_click_calibration,
    "warning: click calibration rendered frame is stale; rendered=80x24 viewport=800x480 current=90x20 viewport=900x400"
  ),
  "doctor should warn when rendered geometry no longer matches the current preview geometry"
)

local malformed_click_calibration = doctor.run({
  binary = "nvim",
  backend_diagnostics = false,
  graphics = "auto",
  image_fit = "original",
}, {
  mode = "serve",
  serve_output = "ansi",
  cursor_addressable_preview = true,
  rendered_frame_geometry = { columns = vim.NIL, rows = vim.NIL, width = vim.NIL, height = vim.NIL },
  current_preview_geometry = { columns = vim.NIL, rows = vim.NIL, width = vim.NIL, height = vim.NIL },
  status = "ok",
})
assert(
  has_line(malformed_click_calibration, "click calibration: pending rendered frame"),
  "doctor should not sample malformed click calibration geometry"
)

local backend_ready = doctor.run({
  binary = "nvbrowser-test",
  graphics = "auto",
  image_fit = "original",
  cdp_ws_url = "ws://127.0.0.1:9222/devtools/browser/test",
  user_data_dir = "/tmp/nvbrowser-profile",
  _system = function(command)
    assert(table.concat(command, " "):find("doctor %-%-json", 1, false), "doctor should call CLI doctor --json")
    assert(vim.tbl_contains(command, "--cdp-ws-url"), "doctor should pass configured CDP URL")
    assert(vim.tbl_contains(command, "--user-data-dir"), "doctor should pass configured user data dir")
    return {
      code = 0,
      stdout = vim.json.encode({
        backend = {
          status = "available",
          source = "cdp",
          cdp_ws_url = "ws://127.0.0.1:9222/devtools/browser/test",
          chrome_binary = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
          user_data_dir = "/tmp/nvbrowser-profile",
        },
      }),
      stderr = "",
    }
  end,
}, {})
assert(contains_line(backend_ready, "backend: available via cdp"), "doctor should include backend readiness")
assert(contains_line(backend_ready, "backend cdp: ws://127.0.0.1:9222/devtools/browser/test"), "doctor should include CDP URL")
assert(contains_line(backend_ready, "backend chrome: /Applications/Google Chrome.app/Contents/MacOS/Google Chrome"), "doctor should include Chrome path")
assert(contains_line(backend_ready, "backend user data dir: /tmp/nvbrowser-profile"), "doctor should include user data dir")

local custom_binary_backend = doctor.run({
  binary = "/opt/bin/browser-backend",
  graphics = "auto",
  image_fit = "original",
  _system = function(command)
    assert(command[1] == "/opt/bin/browser-backend", "doctor should use the configured binary even when it is renamed")
    return {
      code = 0,
      stdout = vim.json.encode({
        backend = {
          status = "available",
          source = "chrome",
          chrome_binary = "/tmp/chrome",
        },
      }),
      stderr = "",
    }
  end,
}, {})
assert(contains_line(custom_binary_backend, "backend: available via chrome"), "doctor should run backend diagnostics for renamed binaries")

local backend_missing = doctor.run({
  binary = "nvbrowser-test",
  graphics = "auto",
  image_fit = "original",
  _system = function()
    return {
      code = 0,
      stdout = vim.json.encode({
        backend = {
          status = "missing",
          source = "none",
          warning = "Chrome/CDP backend was not found; set NVBROWSER_CDP_WS_URL or NVBROWSER_CHROME",
        },
      }),
      stderr = "",
    }
  end,
}, {})
assert(contains_line(backend_missing, "backend: missing"), "doctor should report missing backend state")
assert(contains_line(backend_missing, "warning: Chrome/CDP backend was not found"), "doctor should include backend warning")

local invalid_backend = doctor.run({
  binary = "nvbrowser-test",
  graphics = "auto",
  image_fit = "original",
  _system = function()
    return { code = 0, stdout = "not json", stderr = "" }
  end,
}, {})
assert(contains_line(invalid_backend, "warning: backend diagnostics unavailable"), "doctor should degrade on invalid CLI JSON")

local malformed_backend = doctor.run({
  binary = "nvbrowser-test",
  graphics = "auto",
  image_fit = "original",
  _system = function()
    return {
      code = 0,
      stdout = vim.json.encode({
        backend = {
          status = vim.NIL,
          source = vim.NIL,
        },
      }),
      stderr = "",
    }
  end,
}, {})
assert(contains_line(malformed_backend, "backend: unknown"), "doctor should not stringify vim.NIL backend status/source")

local missing_cli_backend = doctor.run({
  binary = "nvbrowser-test",
  graphics = "auto",
  image_fit = "original",
  _system = function()
    return { code = 127, stdout = "", stderr = "not found" }
  end,
}, {})
assert(contains_line(missing_cli_backend, "warning: backend diagnostics unavailable"), "doctor should degrade when CLI diagnostics cannot run")

vim.env.ZELLIJ = original_zellij
vim.env.TERM = original_term
vim.env.TMUX = original_tmux
vim.env.TERM_PROGRAM = original_term_program
vim.env.GHOSTTY_RESOURCES_DIR = original_ghostty
