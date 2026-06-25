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

local browser = require("nvim-browser")
local terminal = require("nvim-browser.terminal")
local original_nvim_chan_send = vim.api.nvim_chan_send
vim.api.nvim_chan_send = function(channel, data)
  if channel == vim.v.stderr and type(data) == "string" and data:find("\27", 1, true) then
    return
  end
  return original_nvim_chan_send(channel, data)
end

local fixture_path = vim.fn.tempname() .. ".html"
vim.fn.writefile({
  "<!doctype html>",
  "<html>",
  "<head>",
  "  <meta charset=\"utf-8\">",
  "  <title>NBrowser Neovim Smoke Fixture</title>",
  "  <style>body { font-family: sans-serif; } #ready { color: #157347; }</style>",
  "</head>",
  "<body>",
  "  <h1 id=\"ready\">NBrowser Neovim Smoke Fixture</h1>",
  "  <p>deterministic local browser smoke</p>",
  "</body>",
  "</html>",
}, fixture_path)

local original_zellij = vim.env.ZELLIJ
local original_tmux = vim.env.TMUX
vim.env.ZELLIJ = "1"
vim.env.TMUX = nil

browser.setup({
  binary = binary,
  graphics = "kitty-unicode",
  session = { persist = false },
  calibration = { persist = false },
  auto_refresh_on_write = false,
  backend_diagnostics = false,
})

vim.cmd("NBrowserOpen " .. vim.fn.fnameescape(fixture_path))

local ready = vim.wait(20000, function()
  local runtime = browser.runtime_metadata()
  local health = browser.frame_health()
  local state = terminal.state()
  return browser.status() == "ok"
    and browser.current_title() == "NBrowser Neovim Smoke Fixture"
    and type(runtime) == "table"
    and runtime.output == "ansi"
    and state.serve_output == "ansi"
    and state.rendered_frame_geometry ~= nil
    and type(health) == "table"
    and health.stale == false
    and health.refresh_pending == false
end, 50)

if not ready then
  local runtime = browser.runtime_metadata()
  local health = browser.frame_health()
  local state = terminal.state()
  fail(
    "timed out waiting for healthy frame; status="
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
      .. " frame_health="
      .. vim.inspect(health)
  )
end

local state = terminal.state()
assert(state.cursor_addressable_preview == true, "ANSI smoke preview should be cursor-addressable")
assert(state.rendered_frame_geometry.width > 0, "smoke frame should have rendered width")
assert(state.rendered_frame_geometry.height > 0, "smoke frame should have rendered height")
assert(
  browser.current_url() == vim.uri_from_fname(fixture_path),
  "smoke URL should preserve the local fixture target; got " .. tostring(browser.current_url())
)

local lines = vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)
local buffer_text = table.concat(lines, "\n")
assert(not buffer_text:find("Browser startup failed", 1, true), "smoke buffer should not show startup failure")
assert(not buffer_text:find("Starting browser session", 1, true), "smoke buffer should not remain in startup placeholder")
assert(
  lines[#lines] ~= nil and lines[#lines]:find("ANSI fallback", 1, true),
  "Zellij smoke footer should show the effective ANSI fallback output; footer="
    .. vim.inspect(lines[#lines])
    .. " buffer_tail="
    .. vim.inspect({ lines[#lines - 2], lines[#lines - 1], lines[#lines] })
)

browser.close()
vim.api.nvim_chan_send = original_nvim_chan_send
vim.fn.delete(fixture_path)
vim.env.ZELLIJ = original_zellij
vim.env.TMUX = original_tmux
