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

function M.command_for(binary, action, target, opts)
  if action == "inspect" then
    return { binary, "inspect", target }
  end

  if target:match("^https?://") then
    return { binary, "serve", "--output", browser_graphics_output(opts), "--url", target }
  end

  local extension = extension_for(target)
  if extension == "md" or extension == "markdown" then
    return { binary, "serve", "--output", browser_graphics_output(opts), "--markdown", target }
  end

  if is_image_extension(extension) then
    return { binary, "show-image", target, "--output", image_graphics_output(opts) }
  end

  return { binary, "inspect", target }
end

return M
