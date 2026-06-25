if vim.env.NVBROWSER_NVIM_E2E ~= "1" then
  return
end

local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path
local expected_serve_protocol = 26

local function fail(message)
  error("nvim smoke e2e: " .. message, 0)
end

local function executable(path)
  return path ~= nil and path ~= "" and vim.fn.executable(path) == 1
end

local function backend_diagnostics(candidate)
  local output = vim.fn.system({ candidate, "doctor", "--json" })
  if vim.v.shell_error ~= 0 then
    return nil, "doctor failed"
  end
  local ok, decoded = pcall(vim.json.decode, output)
  if not ok or type(decoded) ~= "table" or type(decoded.backend) ~= "table" then
    return nil, "doctor did not return backend diagnostics"
  end
  if decoded.backend.status ~= "available" then
    return nil, "Chromium/CDP backend is not available"
  end
  local serve_protocol = type(decoded.protocol) == "table" and tonumber(decoded.protocol.serve) or nil
  if serve_protocol ~= expected_serve_protocol then
    return nil,
      "serve protocol mismatch for "
        .. candidate
        .. ": expected "
        .. tostring(expected_serve_protocol)
        .. ", got "
        .. tostring(serve_protocol)
  end
  return decoded, nil
end

local function backend_binary()
  local mismatches = {}
  for _, profile in ipairs({ "release", "debug" }) do
    local candidate = root .. "/target/" .. profile .. "/nvbrowser"
    if executable(candidate) then
      local diagnostics, err = backend_diagnostics(candidate)
      if diagnostics ~= nil then
        return candidate, diagnostics
      end
      table.insert(mismatches, err)
    end
  end
  local path_binary = vim.fn.exepath("nvbrowser")
  if executable(path_binary) then
    local diagnostics, err = backend_diagnostics(path_binary)
    if diagnostics ~= nil then
      return path_binary, diagnostics
    end
    table.insert(mismatches, err)
  end
  return nil, nil, table.concat(mismatches, "; ")
end

local function skip(message)
  print("nvim smoke e2e skipped: " .. message)
  vim.cmd("qa")
end

local binary, decoded, binary_error = backend_binary()
if binary == nil then
  skip(
    "compatible nvbrowser binary is not available; build with cargo build -p nvbrowser or cargo build --release -p nvbrowser"
      .. (binary_error ~= nil and binary_error ~= "" and ("; " .. binary_error) or "")
  )
end

vim.opt.runtimepath:prepend(root)
vim.cmd("runtime plugin/nvim-browser.lua")
if vim.fn.exists(":NBrowserOpen") ~= 2 then
  fail(":NBrowserOpen is not registered")
end
if vim.fn.exists(":NBrowserSmoke") ~= 2 then
  fail(":NBrowserSmoke is not registered")
end

local browser = require("nvim-browser")
local terminal = require("nvim-browser.terminal")
local original_nvim_chan_send = vim.api.nvim_chan_send
local original_nvim_echo = vim.api.nvim_echo
local original_env = {
  ZELLIJ = vim.env.ZELLIJ,
  TMUX = vim.env.TMUX,
  TERM_PROGRAM = vim.env.TERM_PROGRAM,
  KITTY_WINDOW_ID = vim.env.KITTY_WINDOW_ID,
}
local active_stderr_chunks = nil
local smoke_echo = nil

vim.api.nvim_chan_send = function(channel, data)
  if channel == vim.v.stderr and type(data) == "string" and data:find("\27", 1, true) then
    if active_stderr_chunks ~= nil then
      table.insert(active_stderr_chunks, data)
    end
    return
  end
  return original_nvim_chan_send(channel, data)
end
vim.api.nvim_echo = function(chunks, history, opts)
  if type(chunks) == "table" and chunks[1] ~= nil and type(chunks[1][1]) == "string" then
    local text = chunks[1][1]
    if text:find("nvim-browser smoke", 1, true) ~= nil then
      smoke_echo = text
    end
  end
  return original_nvim_echo(chunks, history, opts)
end

local fixture_path = root .. "/data/html/smoke.html"
local fixture_url = vim.uri_from_fname(fixture_path)
local env_keys = { "ZELLIJ", "TMUX", "TERM_PROGRAM", "KITTY_WINDOW_ID" }

local profiles = {
  {
    name = "zellij_ansi_fallback",
    env = { ZELLIJ = "1", TMUX = nil, TERM_PROGRAM = nil, KITTY_WINDOW_ID = nil },
    expected_runtime_output = "ansi",
    expected_serve_output = "ansi",
    expected_output_line = "output: ANSI fallback",
    expect_reader = true,
  },
  {
    name = "kitty_unicode",
    env = { ZELLIJ = nil, TMUX = nil, TERM_PROGRAM = "kitty", KITTY_WINDOW_ID = "1" },
    expected_runtime_output = "kitty-unicode",
    expected_serve_output = "kitty-unicode",
    expected_output_line = "output: kitty-unicode",
    expect_kitty_unicode = true,
    expect_reader = false,
  },
}

local function apply_env(profile)
  for _, key in ipairs(env_keys) do
    vim.env[key] = profile.env[key]
  end
end

local function diagnostics(profile)
  local runtime = browser.runtime_metadata()
  local health = browser.frame_health()
  local state = terminal.state()
  return "profile="
    .. profile.name
    .. " status="
    .. tostring(browser.status())
    .. " error="
    .. tostring(browser.status_error())
    .. " title="
    .. tostring(browser.current_title())
    .. " url="
    .. tostring(browser.current_url())
    .. " serve_output="
    .. tostring(state.serve_output)
    .. " runtime_output="
    .. tostring(type(runtime) == "table" and runtime.output or nil)
    .. " egress="
    .. tostring(state.terminal_graphics_egress_count)
    .. " kitty_unicode_egress="
    .. tostring(state.last_terminal_graphics_egress_is_kitty_unicode)
    .. " frame_health="
    .. vim.inspect(health)
    .. " smoke_echo="
    .. tostring(smoke_echo)
end

local function common_ready(profile)
  local runtime = browser.runtime_metadata()
  local health = browser.frame_health()
  local state = terminal.state()
  if browser.status() ~= "ok" then
    return false
  end
  if browser.current_title() ~= "nvim-browser smoke submitted: nvim-browser interaction" then
    return false
  end
  if type(runtime) ~= "table" or runtime.output ~= profile.expected_runtime_output then
    return false
  end
  if state.serve_output ~= profile.expected_serve_output then
    return false
  end
  if state.rendered_frame_geometry == nil then
    return false
  end
  if type(health) ~= "table" or health.stale ~= false or health.refresh_pending ~= false then
    return false
  end
  if smoke_echo == nil or smoke_echo:find("nvim-browser smoke", 1, true) == nil then
    return false
  end
  for _, line in ipairs({ "status: ok", "interaction: ok", "focus: ok", "input: ok", "submit: ok" }) do
    if smoke_echo:find(line, 1, true) == nil then
      return false
    end
  end
  if smoke_echo:find(profile.expected_output_line, 1, true) == nil then
    return false
  end
  if profile.expect_reader and smoke_echo:find("reader: ok", 1, true) == nil then
    return false
  end
  if profile.expect_kitty_unicode then
    return state.last_payload_is_unicode == true
      and tonumber(state.terminal_graphics_egress_count) ~= nil
      and tonumber(state.terminal_graphics_egress_count) > 0
      and state.last_terminal_graphics_egress_is_kitty_unicode == true
      and smoke_echo:find("terminal graphics: ok", 1, true) ~= nil
      and smoke_echo:find("kitty unicode payload: ok", 1, true) ~= nil
  end
  return true
end

local function profile_assert(profile, condition, message)
  if not condition then
    fail(message .. "; " .. diagnostics(profile))
  end
end

local function last_kitty_payload(chunks)
  for index = #chunks, 1, -1 do
    if chunks[index]:find("\27_G", 1, true) ~= nil then
      return chunks[index]
    end
  end
  return nil
end

local function assert_common(profile, state, stderr_chunks)
  profile_assert(profile, state.cursor_addressable_preview == true, profile.name .. ": smoke preview should be cursor-addressable")
  profile_assert(profile, state.rendered_frame_geometry.width > 0, profile.name .. ": smoke frame should have rendered width")
  profile_assert(profile, state.rendered_frame_geometry.height > 0, profile.name .. ": smoke frame should have rendered height")
  profile_assert(
    profile,
    browser.current_url() == fixture_url,
    profile.name .. ": smoke URL should preserve the local fixture target; got " .. tostring(browser.current_url())
  )

  local lines = vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)
  local buffer_text = table.concat(lines, "\n")
  profile_assert(profile, not buffer_text:find("Browser startup failed", 1, true), profile.name .. ": smoke buffer should not show startup failure")
  profile_assert(
    profile,
    not buffer_text:find("Starting browser session", 1, true),
    profile.name .. ": smoke buffer should not remain in startup placeholder"
  )
  profile_assert(profile, smoke_echo ~= nil and smoke_echo:find("nvim-browser smoke", 1, true), profile.name .. ": NBrowserSmoke should echo a smoke report")
  profile_assert(profile, smoke_echo:find("status: ok", 1, true), profile.name .. ": NBrowserSmoke should report a successful smoke result")
  profile_assert(profile, not smoke_echo:find("status: failed", 1, true), profile.name .. ": NBrowserSmoke should not report failure after a healthy smoke run")
  profile_assert(profile, smoke_echo:find(profile.expected_output_line, 1, true), profile.name .. ": smoke report should show effective output")
  profile_assert(profile, smoke_echo:find("interaction: ok", 1, true), profile.name .. ": smoke report should show a completed interaction loop")
  profile_assert(profile, smoke_echo:find("focus: ok", 1, true), profile.name .. ": smoke report should show focused input")
  profile_assert(profile, smoke_echo:find("input: ok", 1, true), profile.name .. ": smoke report should show typed text")
  profile_assert(profile, smoke_echo:find("submit: ok", 1, true), profile.name .. ": smoke report should show submitted fixture state")

  if profile.expect_reader then
    profile_assert(profile, smoke_echo:find("reader: ok", 1, true), profile.name .. ": smoke report should show ANSI fallback reader health")
    profile_assert(
      profile,
      state.reader_bufnr ~= nil and vim.api.nvim_buf_is_valid(state.reader_bufnr),
      profile.name .. ": ANSI fallback smoke should open a reader buffer"
    )
    local reader_text = table.concat(vim.api.nvim_buf_get_lines(state.reader_bufnr, 0, -1, false), "\n")
    profile_assert(
      profile,
      reader_text:find("deterministic local browser runtime fixture", 1, true),
      profile.name .. ": ANSI fallback smoke reader should include smoke fixture text"
    )
  else
    profile_assert(profile, not smoke_echo:find("reader: ok", 1, true), profile.name .. ": non-fallback smoke should not require reader health")
  end

  if profile.expect_kitty_unicode then
    local stderr_text = table.concat(stderr_chunks, "")
    local kitty_payload = last_kitty_payload(stderr_chunks)
    profile_assert(profile, state.serve_output_label == nil, profile.name .. ": direct Kitty Unicode should not have an ANSI fallback label")
    profile_assert(profile, state.last_payload_is_unicode == true, profile.name .. ": smoke should store a Kitty Unicode payload")
    profile_assert(profile, state.terminal_graphics_egress_count > 0, profile.name .. ": smoke should emit terminal graphics")
    profile_assert(
      profile,
      state.last_terminal_graphics_egress_is_kitty_unicode == true,
      profile.name .. ": smoke should classify the last graphics egress as Kitty Unicode"
    )
    profile_assert(profile, smoke_echo:find("terminal graphics: ok", 1, true), profile.name .. ": smoke report should show graphics egress")
    profile_assert(profile, smoke_echo:find("kitty unicode payload: ok", 1, true), profile.name .. ": smoke report should show Unicode payload egress")
    profile_assert(profile, not smoke_echo:find("output: ANSI fallback", 1, true), profile.name .. ": direct Kitty smoke should not report ANSI fallback")
    profile_assert(profile, not smoke_echo:find("zellij: ANSI fallback active", 1, true), profile.name .. ": direct Kitty smoke should not report Zellij fallback")
    profile_assert(profile, stderr_text:find("\27_G", 1, true), profile.name .. ": smoke should write Kitty escape payload to stderr")
    profile_assert(profile, kitty_payload ~= nil, profile.name .. ": smoke should capture a Kitty graphics egress payload")
    profile_assert(profile, kitty_payload:find("U=1", 1, true), profile.name .. ": last Kitty egress payload should use Unicode placement")
  end
end

local function run_profile(profile)
  apply_env(profile)
  smoke_echo = nil
  active_stderr_chunks = {}

  browser.setup({
    binary = binary,
    graphics = "kitty-unicode",
    session = { persist = false },
    calibration = { persist = false },
    auto_refresh_on_write = false,
    backend_diagnostics = false,
  })

  vim.cmd("NBrowserSmoke")

  local ready = vim.wait(35000, function()
    return common_ready(profile)
  end, 50)

  if not ready then
    fail("timed out waiting for healthy frame; " .. diagnostics(profile))
  end

  local state = terminal.state()
  assert_common(profile, state, active_stderr_chunks)
  local close_ok, close_err = pcall(browser.close)
  active_stderr_chunks = nil
  if not close_ok then
    fail(profile.name .. ": failed to close browser after smoke; " .. tostring(close_err) .. "; " .. diagnostics(profile))
  end
end

local ok, err = xpcall(function()
  for _, profile in ipairs(profiles) do
    run_profile(profile)
  end
end, debug.traceback)

local close_ok, close_err = pcall(browser.close)
vim.api.nvim_chan_send = original_nvim_chan_send
vim.api.nvim_echo = original_nvim_echo
for _, key in ipairs(env_keys) do
  vim.env[key] = original_env[key]
end

if not ok then
  error(err, 0)
end
if not close_ok then
  error("nvim smoke e2e cleanup failed: " .. tostring(close_err), 0)
end
