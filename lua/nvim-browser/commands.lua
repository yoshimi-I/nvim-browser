local M = {}

function M.register(browser, opts)
  opts = opts or {}
  local input = opts.input or vim.fn.input

  local function warn_hint_unavailable()
    vim.api.nvim_echo({ { "nvim-browser: hint not found, stale, or browser session is inactive", "WarningMsg" } }, false, {})
  end

  local function page_scroll_label(metrics)
    if type(metrics) ~= "table" then
      return nil
    end
    local scroll_y = tonumber(metrics.scroll_y)
    local viewport_height = tonumber(metrics.viewport_height)
    local document_height = tonumber(metrics.document_height)
    if scroll_y == nil or viewport_height == nil or document_height == nil then
      return nil
    end
    local scrollable = document_height - viewport_height
    if scrollable <= 0 then
      return "scroll 0%"
    end
    local percent = math.floor(math.max(0, math.min(100, (scroll_y / scrollable) * 100)) + 0.5)
    return "scroll " .. percent .. "%"
  end

  local function runtime_status_label(runtime)
    if type(runtime) ~= "table" then
      return nil
    end
    local parts = {}
    if runtime.output ~= nil and runtime.output ~= vim.NIL then
      table.insert(parts, "output=" .. tostring(runtime.output))
    end
    if type(runtime.viewport) == "table" then
      local width = runtime.viewport.width
      local height = runtime.viewport.height
      if width ~= nil and height ~= nil then
        table.insert(parts, "viewport=" .. tostring(width) .. "x" .. tostring(height))
      end
    end
    if type(runtime.cells) == "table" then
      local columns = runtime.cells.columns
      local rows = runtime.cells.rows
      if columns ~= nil and rows ~= nil then
        table.insert(parts, "cells=" .. tostring(columns) .. "x" .. tostring(rows))
      end
    end
    if runtime.renderer ~= nil and runtime.renderer ~= vim.NIL then
      table.insert(parts, "renderer=" .. tostring(runtime.renderer))
    end
    if #parts == 0 then
      return nil
    end
    return table.concat(parts, " ")
  end

  local function warn_hint_input_unavailable()
    vim.api.nvim_echo({ { "nvim-browser: hint input failed, stale, or browser session is inactive", "WarningMsg" } }, false, {})
  end

  local function current_hint_error()
    if browser.hint_error == nil then
      return nil
    end
    local hint_error = browser.hint_error()
    if hint_error == nil or hint_error == vim.NIL or hint_error == "" then
      return nil
    end
    return tostring(hint_error)
  end

  local function warn_no_hints()
    local hint_error = current_hint_error()
    if hint_error ~= nil then
      vim.api.nvim_echo({ { "nvim-browser: hint extraction failed: " .. hint_error, "WarningMsg" } }, false, {})
      return
    end
    vim.api.nvim_echo({ { "nvim-browser: no browser hints available", "WarningMsg" } }, false, {})
  end

  local function warn_address_unavailable()
    vim.api.nvim_echo({ { "nvim-browser: address was empty or could not be opened", "WarningMsg" } }, false, {})
  end

  local function warn_focused_input_unavailable()
    vim.api.nvim_echo({ { "nvim-browser: focused text input failed or browser session is inactive", "WarningMsg" } }, false, {})
  end

  local function warn_find_repeat_unavailable()
    vim.api.nvim_echo({ { "nvim-browser: no previous browser find query", "WarningMsg" } }, false, {})
  end

  local function warn_selection_yank_unavailable()
    vim.api.nvim_echo({ { "nvim-browser: browser selection yank failed or no browser selection is active", "WarningMsg" } }, false, {})
  end

  local function warn_text_mode_unavailable()
    vim.api.nvim_echo({ { "nvim-browser: text mode requires an active cursor-addressable browser preview", "WarningMsg" } }, false, {})
  end

  local function warn_cursor_text_unavailable()
    vim.api.nvim_echo({ { "nvim-browser: cursor text input requires an active cursor-addressable browser preview", "WarningMsg" } }, false, {})
  end

  local function follow_hint(label)
    if browser.follow_hint ~= nil then
      return browser.follow_hint(label)
    end
    return browser.click_hint(label)
  end

  local function parse_hint_text(args)
    local label, text = (args or ""):match("^(%S+)%s+(.+)$")
    return label, text
  end

  vim.api.nvim_create_user_command("NBrowserOpen", function(opts)
    browser.open(opts.args ~= "" and opts.args or nil)
  end, {
    nargs = "?",
    complete = "file",
  })

  vim.api.nvim_create_user_command("NBrowserPreview", function()
    browser.preview()
  end, {})

  vim.api.nvim_create_user_command("NBrowserInspect", function(opts)
    browser.inspect(opts.args ~= "" and opts.args or nil)
  end, {
    nargs = "?",
    complete = "file",
  })

  vim.api.nvim_create_user_command("NBrowserFocus", function()
    browser.focus()
  end, {})

  vim.api.nvim_create_user_command("NBrowserClose", function()
    browser.close()
  end, {})

  vim.api.nvim_create_user_command("NBrowserRefresh", function()
    browser.refresh()
  end, {})

  vim.api.nvim_create_user_command("NBrowserReload", function()
    browser.reload()
  end, {})

  vim.api.nvim_create_user_command("NBrowserStop", function()
    if not browser.stop() then
      vim.api.nvim_echo({ { "nvim-browser: no pending browser operation to stop", "WarningMsg" } }, false, {})
    end
  end, {})

  vim.api.nvim_create_user_command("NBrowserNavigate", function(opts)
    browser.navigate(opts.args)
  end, {
    nargs = 1,
  })

  vim.api.nvim_create_user_command("NBrowserAddress", function(opts)
    local value = opts.args ~= "" and opts.args or nil
    local function address_input(prompt, fallback)
      local default = fallback
      if browser.current_url ~= nil then
        default = browser.current_url() or default
      end
      if default == nil and browser.last_target ~= nil then
        default = browser.last_target()
      end
      default = default or ""
      return input(prompt, default)
    end
    if value == nil then
      value = address_input("nvim-browser address: ")
    end
    if value == nil or value == "" then
      return
    end
    if not browser.address(value) then
      warn_address_unavailable()
    end
  end, {
    nargs = "*",
  })

  vim.api.nvim_create_user_command("NBrowserBack", function()
    browser.back()
  end, {})

  vim.api.nvim_create_user_command("NBrowserForward", function()
    browser.forward()
  end, {})

  vim.api.nvim_create_user_command("NBrowserScrollDown", function(opts)
    browser.scroll(tonumber(opts.args) or 400, 0)
  end, {
    nargs = "?",
  })

  vim.api.nvim_create_user_command("NBrowserScrollUp", function(opts)
    browser.scroll(-(tonumber(opts.args) or 400), 0)
  end, {
    nargs = "?",
  })

  vim.api.nvim_create_user_command("NBrowserPageDown", function()
    browser.page_down()
  end, {})

  vim.api.nvim_create_user_command("NBrowserPageUp", function()
    browser.page_up()
  end, {})

  vim.api.nvim_create_user_command("NBrowserInput", function(opts)
    if not browser.input_text(opts.args) then
      warn_focused_input_unavailable()
    end
  end, {
    nargs = "+",
  })

  vim.api.nvim_create_user_command("NBrowserPaste", function(opts)
    local register = opts.args ~= "" and opts.args or nil
    if not browser.paste_register(register) then
      warn_focused_input_unavailable()
    end
  end, {
    nargs = "?",
  })

  vim.api.nvim_create_user_command("NBrowserYankSelection", function(opts)
    local register = opts.args ~= "" and opts.args or nil
    if not browser.yank_selection(register) then
      warn_selection_yank_unavailable()
    end
  end, {
    nargs = "?",
  })

  vim.api.nvim_create_user_command("NBrowserInputMode", function()
    local text = input("nvim-browser text: ")
    if text == nil or text == "" then
      return
    end
    if browser.input_text_mode ~= nil then
      if not browser.input_text_mode(function()
        return text
      end) then
        warn_focused_input_unavailable()
      end
      return
    end
    if not browser.input_text(text) then
      warn_focused_input_unavailable()
    end
  end, {})

  vim.api.nvim_create_user_command("NBrowserTextMode", function()
    if browser.start_text_mode == nil then
      warn_text_mode_unavailable()
      return
    end
    if not browser.start_text_mode() then
      warn_text_mode_unavailable()
    end
  end, {})

  vim.api.nvim_create_user_command("NBrowserKey", function(opts)
    local parts = vim.split(opts.args or "", "%s+", { trimempty = true })
    local key = table.remove(parts, 1)
    if key == nil or key == "" then
      return
    end
    browser.press_key(key, { modifiers = parts })
  end, {
    nargs = "+",
  })

  vim.api.nvim_create_user_command("NBrowserFocusSelector", function(opts)
    browser.focus_selector(opts.args)
  end, {
    nargs = "+",
  })

  vim.api.nvim_create_user_command("NBrowserFind", function(opts)
    local query = opts.args
    if query == nil or query == "" then
      query = input("nvim-browser find: ")
    end
    if query == nil or query == "" then
      return
    end
    if not browser.find_text(query, { backwards = false }) then
      vim.api.nvim_echo({ { "nvim-browser: text was not found or browser session is inactive", "WarningMsg" } }, false, {})
    end
  end, {
    nargs = "*",
  })

  vim.api.nvim_create_user_command("NBrowserFindNext", function()
    if browser.find_next == nil or not browser.find_next() then
      warn_find_repeat_unavailable()
    end
  end, {})

  vim.api.nvim_create_user_command("NBrowserFindPrevious", function()
    if browser.find_previous == nil or not browser.find_previous() then
      warn_find_repeat_unavailable()
    end
  end, {})

  vim.api.nvim_create_user_command("NBrowserClick", function(opts)
    local parts = vim.split(opts.args, "%s+", { trimempty = true })
    browser.click_point(parts[1], parts[2])
  end, {
    nargs = "+",
  })

  vim.api.nvim_create_user_command("NBrowserClickHere", function()
    if not browser.click_here() then
      vim.api.nvim_echo({ { "nvim-browser: cursor click requires an active cursor-addressable browser preview", "WarningMsg" } }, false, {})
    end
  end, {})

  vim.api.nvim_create_user_command("NBrowserHoverHere", function()
    if not browser.hover_here() then
      vim.api.nvim_echo({ { "nvim-browser: cursor hover requires an active cursor-addressable browser preview", "WarningMsg" } }, false, {})
    end
  end, {})

  vim.api.nvim_create_user_command("NBrowserHints", function()
    local hints = browser.hints()
    if #hints == 0 then
      warn_no_hints()
      return
    end
    local lines = {}
    for _, hint in ipairs(hints) do
      local label = hint.label or ""
      if hint.href ~= nil and hint.href ~= "" then
        label = label .. " -> " .. hint.href
      end
      table.insert(lines, string.format(
        "%s %d %s %s @ %.0f,%.0f",
        hint.hint_label or tostring(hint.id),
        hint.id,
        hint.kind or "other",
        label,
        hint.x or 0,
        hint.y or 0
      ))
    end
    vim.api.nvim_echo({ { table.concat(lines, "\n") } }, false, {})
  end, {})

  vim.api.nvim_create_user_command("NBrowserClickHint", function(opts)
    if not browser.click_hint(opts.args) then
      warn_hint_unavailable()
    end
  end, {
    nargs = 1,
  })

  vim.api.nvim_create_user_command("NBrowserHoverHint", function(opts)
    if not browser.hover_hint(opts.args) then
      warn_hint_unavailable()
    end
  end, {
    nargs = 1,
  })

  vim.api.nvim_create_user_command("NBrowserFollowHint", function(opts)
    if not follow_hint(opts.args) then
      warn_hint_unavailable()
    end
  end, {
    nargs = 1,
  })

  vim.api.nvim_create_user_command("NBrowserTypeHint", function(opts)
    local label, text = parse_hint_text(opts.args)
    if label == nil or text == nil or not browser.type_hint(label, text) then
      warn_hint_input_unavailable()
    end
  end, {
    nargs = "+",
  })

  vim.api.nvim_create_user_command("NBrowserSubmitHint", function(opts)
    local label, text = parse_hint_text(opts.args)
    if label == nil or text == nil or not browser.type_hint(label, text, { submit = true }) then
      warn_hint_input_unavailable()
    end
  end, {
    nargs = "+",
  })

  vim.api.nvim_create_user_command("NBrowserTypeHere", function(opts)
    if opts.args == nil or opts.args == "" or not browser.type_here(opts.args) then
      warn_cursor_text_unavailable()
    end
  end, {
    nargs = "*",
  })

  vim.api.nvim_create_user_command("NBrowserSubmitHere", function(opts)
    if opts.args == nil or opts.args == "" or not browser.type_here(opts.args, { submit = true }) then
      warn_cursor_text_unavailable()
    end
  end, {
    nargs = "*",
  })

  vim.api.nvim_create_user_command("NBrowserTypeHintMode", function()
    local hints = browser.hints()
    if #hints == 0 then
      warn_no_hints()
      return
    end
    local label = input("nvim-browser hint: ")
    if label == nil or label == "" then
      return
    end
    local text = input("nvim-browser text: ")
    if text == nil or text == "" then
      return
    end
    if not browser.type_hint(label, text) then
      warn_hint_input_unavailable()
    end
  end, {})

  vim.api.nvim_create_user_command("NBrowserSubmitHintMode", function()
    local hints = browser.hints()
    if #hints == 0 then
      warn_no_hints()
      return
    end
    local label = input("nvim-browser hint: ")
    if label == nil or label == "" then
      return
    end
    local text = input("nvim-browser text: ")
    if text == nil or text == "" then
      return
    end
    if not browser.type_hint(label, text, { submit = true }) then
      warn_hint_input_unavailable()
    end
  end, {})

  vim.api.nvim_create_user_command("NBrowserHintMode", function()
    local hints = browser.hints()
    if #hints == 0 then
      warn_no_hints()
      return
    end
    local label = input("nvim-browser hint: ")
    if label == nil or label == "" then
      return
    end
    if not follow_hint(label) then
      warn_hint_unavailable()
    end
  end, {})

  vim.api.nvim_create_user_command("NBrowserCurrentUrl", function()
    vim.api.nvim_echo({ { browser.current_url() or "" } }, false, {})
  end, {})

  vim.api.nvim_create_user_command("NBrowserCurrentTitle", function()
    vim.api.nvim_echo({ { browser.current_title() or "" } }, false, {})
  end, {})

  vim.api.nvim_create_user_command("NBrowserReader", function()
    if not browser.reader() then
      vim.api.nvim_echo({ { "nvim-browser: reader requires an active browser session", "WarningMsg" } }, false, {})
    end
  end, {})

  vim.api.nvim_create_user_command("NBrowserReaderFollow", function()
    browser.reader_follow()
  end, {})

  vim.api.nvim_create_user_command("NBrowserStatus", function()
    local status = browser.status() or "unknown"
    local url = browser.current_url() or ""
    local title = browser.current_title and browser.current_title() or nil
    local error = browser.status_error and browser.status_error() or nil
    local scroll = browser.page_metrics and page_scroll_label(browser.page_metrics()) or nil
    local runtime = browser.runtime_metadata and runtime_status_label(browser.runtime_metadata()) or nil
    local message = status
    if title ~= nil and title ~= "" then
      message = message .. " " .. title
    end
    if scroll ~= nil then
      message = message .. " " .. scroll
    end
    if runtime ~= nil then
      message = message .. " " .. runtime
    end
    if url ~= "" then
      message = message .. " " .. url
    end
    if error ~= nil and error ~= "" then
      message = message .. " " .. error
    end
    vim.api.nvim_echo({ { message } }, false, {})
  end, {})

  vim.api.nvim_create_user_command("NBrowserDoctor", function()
    local report = browser.doctor()
    vim.api.nvim_echo({ { table.concat(report.lines or {}, "\n") } }, false, {})
  end, {})

  vim.api.nvim_create_user_command("NBrowserToggle", function()
    browser.toggle()
  end, {})
end

return M
