local M = {}

function M.zoom_label(scale)
  scale = tonumber(scale)
  if scale == nil or math.abs(scale - 1.0) < 0.005 then
    return nil
  end
  return "zoom=" .. tostring(math.floor((scale * 100) + 0.5)) .. "%"
end

function M.download_list_label(download, index)
  if type(download) ~= "table" then
    return nil
  end
  local filename = download.suggested_filename
  if filename == nil or filename == vim.NIL or filename == "" then
    local path = download.path
    if path ~= nil and path ~= vim.NIL and path ~= "" then
      filename = vim.fn.fnamemodify(tostring(path), ":t")
    end
  end
  if filename == nil or filename == vim.NIL or filename == "" then
    filename = "download"
  end
  local path = download.path ~= nil and download.path ~= vim.NIL and tostring(download.path) or ""
  local label
  if path == "" then
    label = tostring(filename)
  else
    label = tostring(filename) .. " " .. path
  end
  if index ~= nil then
    return tostring(index) .. ". " .. label
  end
  return label
end

return M
