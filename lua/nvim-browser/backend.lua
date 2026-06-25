local M = {}
local DEFAULT_NAVIGATION_TIMEOUT_MS = 20000

local function extension_for(target)
  return vim.fn.fnamemodify(target, ":e"):lower()
end

local function is_browser_file_extension(extension)
  return vim.tbl_contains({ "html", "htm", "svg", "pdf", "png", "jpg", "jpeg", "gif", "webp" }, extension)
end

local function is_raster_image_extension(extension)
  return vim.tbl_contains({ "png", "jpg", "jpeg", "gif", "webp" }, extension)
end

local function env_value(env, key)
  if env ~= nil then
    return env[key]
  end
  return vim.env[key]
end

local function non_empty(value)
  return value ~= nil and value ~= ""
end

local function detect_terminal(env)
  local term_program = tostring(env_value(env, "TERM_PROGRAM") or ""):lower()
  local term = tostring(env_value(env, "TERM") or ""):lower()
  if term_program:find("ghostty", 1, true) or term:find("ghostty", 1, true) or non_empty(env_value(env, "GHOSTTY_RESOURCES_DIR")) then
    return "ghostty"
  end
  if term_program:find("kitty", 1, true) or term:find("kitty", 1, true) or non_empty(env_value(env, "KITTY_WINDOW_ID")) then
    return "kitty"
  end
  if term_program:find("wezterm", 1, true) or term:find("wezterm", 1, true) then
    return "wezterm"
  end
  return "unknown"
end

local function detect_multiplexer(env)
  if non_empty(env_value(env, "ZELLIJ")) then
    return "zellij"
  end
  if non_empty(env_value(env, "TMUX")) then
    return "tmux"
  end
  return "none"
end

function M.resolve_graphics(opts, env)
  local graphics = opts and opts.graphics or "auto"
  local terminal = detect_terminal(env)
  local multiplexer = detect_multiplexer(env)
  local resolution = {
    graphics = graphics,
    terminal = terminal,
    multiplexer = multiplexer,
    browser_output = "ansi",
    image_output = "ansi",
    reason = "",
    warnings = {},
  }

  if graphics == "ansi" then
    resolution.browser_output = "ansi"
    resolution.image_output = "ansi"
    resolution.reason = "explicit ANSI graphics"
    return resolution
  end
  if
    multiplexer == "zellij"
    and (graphics == "kitty" or graphics == "kitty-unicode")
    and not (opts and opts.allow_unsafe_multiplexer_graphics == true)
  then
    resolution.browser_output = "ansi"
    resolution.image_output = "ansi"
    resolution.reason = "Zellij detected; explicit Kitty graphics downgraded to ANSI because terminal graphics passthrough is unreliable"
    table.insert(
      resolution.warnings,
      "ZELLIJ detected with explicit Kitty graphics; downgraded to ANSI. Set allow_unsafe_multiplexer_graphics=true to keep Kitty graphics"
    )
    return resolution
  end
  if graphics == "kitty" then
    resolution.browser_output = "kitty"
    resolution.image_output = "kitty"
    resolution.reason = "explicit Kitty graphics"
  elseif graphics == "kitty-unicode" then
    resolution.browser_output = "kitty-unicode"
    resolution.image_output = "kitty"
    resolution.reason = "explicit Kitty Unicode browser graphics"
  elseif multiplexer == "zellij" then
    resolution.browser_output = "ansi"
    resolution.image_output = "ansi"
    resolution.reason = "Zellij detected; auto uses ANSI because terminal graphics passthrough is unreliable"
    return resolution
  elseif multiplexer == "tmux" then
    resolution.browser_output = "kitty-unicode"
    resolution.image_output = "kitty"
    resolution.reason = "tmux detected; auto keeps Kitty graphics and relies on tmux passthrough wrapping"
    table.insert(resolution.warnings, "tmux detected; Kitty graphics require passthrough support")
    return resolution
  elseif terminal == "ghostty" then
    resolution.browser_output = "kitty-unicode"
    resolution.image_output = "kitty"
    resolution.reason = "Ghostty detected; auto uses Kitty graphics"
    return resolution
  elseif terminal == "kitty" or terminal == "wezterm" then
    resolution.browser_output = "kitty-unicode"
    resolution.image_output = "kitty"
    resolution.reason = terminal .. " detected; auto uses Kitty graphics"
    return resolution
  else
    resolution.browser_output = "ansi"
    resolution.image_output = "ansi"
    resolution.reason = "unknown terminal; auto uses safe ANSI fallback"
    return resolution
  end

  if multiplexer == "zellij" then
    table.insert(resolution.warnings, "ZELLIJ detected with explicit Kitty graphics; images may not render unless the multiplexer passes graphics through")
  elseif multiplexer == "tmux" then
    table.insert(resolution.warnings, "tmux detected with explicit Kitty graphics; Kitty graphics require passthrough support")
  end

  return resolution
end

local function is_browser_url(target)
  return target:match("^https?://") or target:match("^file://")
end

local function local_path_from_file_url(target)
  if type(target) ~= "string" or not target:match("^file://") or target:find("[#?]") ~= nil then
    return nil
  end
  local authority = target:match("^file://([^/]*)")
  if authority ~= nil and authority ~= "" and authority:lower() ~= "localhost" then
    return nil
  end
  local path = target:match("^file://[^/]*(/.*)$")
  if path == nil or path == "" then
    return nil
  end
  return path:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
end

local function browser_graphics_output(opts)
  return M.resolve_graphics(opts).browser_output
end

local function annotate_graphics_resolution(command, resolution)
  if
    resolution.browser_output == "ansi"
    and resolution.graphics ~= "ansi"
    and resolution.multiplexer == "zellij"
  then
    command.nvim_browser_output_label = "ANSI fallback"
  end
  return command
end

local function add_cdp_ws_url(command, opts)
  if opts ~= nil and opts.cdp_ws_url ~= nil and opts.cdp_ws_url ~= "" then
    table.insert(command, "--cdp-ws-url")
    table.insert(command, opts.cdp_ws_url)
  end
  return command
end

local function add_user_data_dir(command, opts)
  if opts ~= nil and opts.user_data_dir ~= nil and opts.user_data_dir ~= "" then
    table.insert(command, "--user-data-dir")
    table.insert(command, opts.user_data_dir)
  end
  return command
end

local function add_download_dir(command, opts)
  if opts ~= nil and opts.download_dir ~= nil and opts.download_dir ~= "" then
    table.insert(command, "--download-dir")
    table.insert(command, opts.download_dir)
  end
  return command
end

local function add_navigation_timeout(command, opts)
  local timeout = opts and tonumber(opts.navigation_timeout_ms) or nil
  if timeout ~= nil then
    timeout = math.floor(timeout)
  end
  if timeout ~= nil and timeout > 0 and timeout ~= DEFAULT_NAVIGATION_TIMEOUT_MS then
    table.insert(command, "--navigation-timeout-ms")
    table.insert(command, tostring(timeout))
  end
  return command
end

local function serve_command(binary, opts)
  local resolution = M.resolve_graphics(opts)
  local command = { binary, "serve", "--output", resolution.browser_output }
  annotate_graphics_resolution(command, resolution)
  add_navigation_timeout(command, opts)
  add_cdp_ws_url(command, opts)
  add_user_data_dir(command, opts)
  add_download_dir(command, opts)
  return command
end

function M.command_for(binary, action, target, opts)
  if action == "inspect" then
    return { binary, "inspect", target }
  end

  local local_file_url_path = local_path_from_file_url(target)
  if local_file_url_path ~= nil then
    local local_file_url_extension = extension_for(local_file_url_path)
    if local_file_url_extension == "md" or local_file_url_extension == "markdown" then
      local command = serve_command(binary, opts)
      table.insert(command, "--markdown")
      table.insert(command, local_file_url_path)
      return command
    end
    if is_raster_image_extension(local_file_url_extension) then
      local command = serve_command(binary, opts)
      table.insert(command, "--image-fit")
      table.insert(command, opts and opts.image_fit or "original")
      table.insert(command, "--image")
      table.insert(command, local_file_url_path)
      return command
    end
  end

  if is_browser_url(target) then
    local command = serve_command(binary, opts)
    table.insert(command, "--url")
    table.insert(command, target)
    return command
  end

  local extension = extension_for(target)
  if extension == "md" or extension == "markdown" then
    local command = serve_command(binary, opts)
    table.insert(command, "--markdown")
    table.insert(command, vim.fn.fnamemodify(target, ":p"))
    return command
  end

  if is_browser_file_extension(extension) then
    local command = serve_command(binary, opts)
    if is_raster_image_extension(extension) then
      table.insert(command, "--image-fit")
      table.insert(command, opts and opts.image_fit or "original")
      table.insert(command, "--image")
      table.insert(command, vim.fn.fnamemodify(target, ":p"))
      return command
    end
    table.insert(command, "--url")
    table.insert(command, vim.uri_from_fname(vim.fn.fnamemodify(target, ":p")))
    return command
  end

  return { binary, "inspect", target }
end

return M
