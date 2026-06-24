local M = {}

function M.zoom_label(scale)
  scale = tonumber(scale)
  if scale == nil or math.abs(scale - 1.0) < 0.005 then
    return nil
  end
  return "zoom=" .. tostring(math.floor((scale * 100) + 0.5)) .. "%"
end

return M
