local M = {}

local function extension_for(target)
  return vim.fn.fnamemodify(target, ":e"):lower()
end

local function is_image_extension(extension)
  return vim.tbl_contains({ "png", "jpg", "jpeg", "gif", "webp" }, extension)
end

local function image_graphics_output(opts)
  local graphics = opts and opts.graphics or "auto"
  if graphics == "kitty" or graphics == "ansi" then
    return graphics
  end

  return "kitty"
end

local function browser_graphics_output(opts)
  local graphics = opts and opts.graphics or "auto"
  if graphics == "kitty" or graphics == "kitty-unicode" or graphics == "ansi" then
    return graphics
  end
  if vim.env.ZELLIJ ~= nil then
    return "ansi"
  end

  return "kitty-unicode"
end

local function add_cdp_ws_url(command, opts)
  if opts ~= nil and opts.cdp_ws_url ~= nil and opts.cdp_ws_url ~= "" then
    table.insert(command, "--cdp-ws-url")
    table.insert(command, opts.cdp_ws_url)
  end
  return command
end

function M.command_for(binary, action, target, opts)
  if action == "inspect" then
    return { binary, "inspect", target }
  end

  if target:match("^https?://") then
    local command = { binary, "serve", "--output", browser_graphics_output(opts) }
    add_cdp_ws_url(command, opts)
    table.insert(command, "--url")
    table.insert(command, target)
    return command
  end

  local extension = extension_for(target)
  if extension == "md" or extension == "markdown" then
    local command = { binary, "serve", "--output", browser_graphics_output(opts) }
    add_cdp_ws_url(command, opts)
    table.insert(command, "--markdown")
    table.insert(command, target)
    return command
  end

  if is_image_extension(extension) then
    return {
      binary,
      "show-image",
      target,
      "--output",
      image_graphics_output(opts),
      "--fit",
      (opts and opts.image_fit) or "original",
    }
  end

  return { binary, "inspect", target }
end

return M
