local M = {}

local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function encode_query(value)
  if vim.uri_encode ~= nil then
    return vim.uri_encode(value)
  end
  return value:gsub("([^%w%-_%.~])", function(char)
    return string.format("%%%02X", string.byte(char))
  end)
end

local function has_scheme(value)
  return value:match("^%a[%w+.-]*://") ~= nil
    or value:match("^data:") ~= nil
    or value:match("^file:") ~= nil
    or value:match("^about:") ~= nil
end

local function is_localhost_like(value)
  return value == "localhost"
    or value:match("^localhost[:/].*") ~= nil
    or value:match("^127%.%d+%.%d+%.%d+$") ~= nil
    or value:match("^127%.%d+%.%d+%.%d+[:/].*") ~= nil
    or value == "[::1]"
    or value:match("^%[%:%:1%][:/].*") ~= nil
end

local function is_host_like(value)
  if value:find("%s") ~= nil then
    return false
  end
  if value:match("^%d") ~= nil then
    return is_localhost_like(value)
      or value:match("^%d+%.%d+%.%d+%.%d+$") ~= nil
      or value:match("^%d+%.%d+%.%d+%.%d+[:/].*") ~= nil
  end
  return is_localhost_like(value)
    or value:match("^[%w-]+%.[%w.-]+[%:/]?.*") ~= nil
end

function M.resolve(input, search_url)
  input = trim(input)
  if input == "" then
    return nil
  end
  if has_scheme(input) then
    return input
  end
  if is_localhost_like(input) then
    return "http://" .. input
  end
  if is_host_like(input) then
    return "https://" .. input
  end
  return search_url:format(encode_query(input))
end

return M
