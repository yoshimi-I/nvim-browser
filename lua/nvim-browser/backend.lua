local M = {}

local function extension_for(target)
  return vim.fn.fnamemodify(target, ":e"):lower()
end

local function is_image_extension(extension)
  return vim.tbl_contains({ "png", "jpg", "jpeg", "gif", "webp" }, extension)
end

function M.command_for(binary, action, target)
  if action == "inspect" then
    return { binary, "inspect", target }
  end

  if target:match("^https?://") then
    return { binary, "browse", target, "--output", "kitty" }
  end

  local extension = extension_for(target)
  if extension == "md" or extension == "markdown" then
    return { binary, "render-md", target }
  end

  if is_image_extension(extension) then
    return { binary, "show-image", target }
  end

  return { binary, "inspect", target }
end

return M
