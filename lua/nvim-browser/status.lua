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

function M.frame_health_label(health)
  if type(health) ~= "table" then
    return nil
  end
  local parts = {}
  if health.stale == true then
    table.insert(parts, "frame=stale")
  end
  if health.refresh_pending == true then
    table.insert(parts, "refreshing")
  end
  if #parts == 0 then
    return nil
  end
  return table.concat(parts, " ")
end

function M.runtime_output_label(output, label)
  if output == nil or output == vim.NIL then
    return nil
  end
  if label ~= nil and label ~= vim.NIL and label ~= "" then
    return tostring(label)
  end
  output = tostring(output)
  return output
end

local function normalize_text(value)
  if value == nil or value == vim.NIL then
    return nil
  end
  value = tostring(value):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if value == "" then
    return nil
  end
  return value
end

local function truncate_chars(value, max_chars)
  max_chars = math.floor(tonumber(max_chars) or 40)
  if max_chars <= 0 then
    return nil
  end
  if vim.fn.strchars(value) <= max_chars then
    return value
  end
  if max_chars <= 3 then
    return vim.fn.strcharpart(value, 0, max_chars)
  end
  return vim.fn.strcharpart(value, 0, max_chars - 3) .. "..."
end

local function display_kind(kind)
  kind = normalize_text(kind)
  if kind == nil then
    return nil
  end
  if kind == "text_area" then
    return "textarea"
  end
  return kind
end

function M.focused_element_label(focused, opts)
  if type(focused) ~= "table" then
    return nil
  end
  local kind = display_kind(focused.kind)
  if kind == nil then
    return nil
  end

  opts = opts or {}
  local max_detail_chars = opts.max_detail_chars or 40
  local detail = normalize_text(focused.label)
  if detail ~= nil then
    detail = truncate_chars(detail, max_detail_chars)
  end
  if focused.checked ~= nil and focused.checked ~= vim.NIL and (kind == "checkbox" or kind == "radio") then
    local checked = focused.checked == true and "checked" or "unchecked"
    detail = detail ~= nil and (detail .. " " .. checked) or checked
  end
  if detail ~= nil and detail ~= "" then
    return "focus=" .. kind .. " " .. detail
  end
  return "focus=" .. kind
end

return M
