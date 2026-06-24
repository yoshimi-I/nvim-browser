local M = {}

function M.register(browser, opts)
  opts = opts or {}
  local input = opts.input or vim.fn.input
  local select = opts.select or vim.ui.select

  local function warn_hint_unavailable()
    vim.api.nvim_echo({ { "nvim-browser: hint not found, stale, or browser session is inactive", "WarningMsg" } }, false, {})
  end

  local function warn_invalid_picker_action(action)
    vim.api.nvim_echo({ { "nvim-browser: unsupported hint picker action: " .. tostring(action), "WarningMsg" } }, false, {})
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

  local function focused_element_label(focused)
    if type(focused) ~= "table" then
      return nil
    end
    local kind = focused.kind ~= nil and tostring(focused.kind) or nil
    if kind == nil or kind == "" then
      return nil
    end
    local label = focused.label ~= nil and focused.label ~= vim.NIL and tostring(focused.label) or nil
    if label ~= nil then
      label = label:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      if label == "" then
        label = nil
      end
    end
    if label ~= nil then
      return "focus=" .. kind .. " " .. label
    end
    return "focus=" .. kind
  end

  local function download_status_label(download)
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
      return "download"
    end
    return "download=" .. tostring(filename)
  end

  local function download_list_label(download)
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
    if path == "" then
      return tostring(filename)
    end
    return tostring(filename) .. " " .. path
  end

  local function warn_hint_input_unavailable()
    vim.api.nvim_echo({ { "nvim-browser: hint input failed, stale, or browser session is inactive", "WarningMsg" } }, false, {})
  end

  local function warn_hint_upload_unavailable()
    vim.api.nvim_echo({ { "nvim-browser: hint file upload failed, stale, non-file, missing path, or browser session is inactive", "WarningMsg" } }, false, {})
  end

  local function warn_submit_focused_unavailable()
    vim.api.nvim_echo({ { "nvim-browser: focused element is not submittable or browser session is inactive", "WarningMsg" } }, false, {})
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

  local function warn_open_under_cursor_unavailable()
    vim.api.nvim_echo({ { "nvim-browser: no URL, file, or search text under cursor", "WarningMsg" } }, false, {})
  end

  local function warn_history_unavailable()
    vim.api.nvim_echo({ { "nvim-browser: no browser history available or selected page could not be opened", "WarningMsg" } }, false, {})
  end

  local function warn_resume_unavailable()
    vim.api.nvim_echo({ { "nvim-browser: no browser session target to resume", "WarningMsg" } }, false, {})
  end

  local function warn_action_unavailable()
    vim.api.nvim_echo({ { "nvim-browser: selected browser action failed or browser session is inactive", "WarningMsg" } }, false, {})
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

  local function valid_register(register)
    if type(register) ~= "string" or #register ~= 1 then
      return false
    end
    local value_ok, value = pcall(vim.fn.getreg, register)
    local type_ok, regtype = pcall(vim.fn.getregtype, register)
    if not value_ok or not type_ok then
      return false
    end
    local ok = pcall(vim.fn.setreg, register, value, regtype)
    if ok then
      pcall(vim.fn.setreg, register, value, regtype)
    end
    return ok
  end

  local function warn_current_url_yank_unavailable()
    vim.api.nvim_echo({ { "nvim-browser: no current browser URL to yank or register is invalid", "WarningMsg" } }, false, {})
  end

  local function warn_hint_url_yank_unavailable()
    vim.api.nvim_echo({ { "nvim-browser: hint URL not found, stale, non-link, or register is invalid", "WarningMsg" } }, false, {})
  end

  local function warn_screenshot_unavailable()
    vim.api.nvim_echo({ { "nvim-browser: browser screenshot failed, missing path, or browser session is inactive", "WarningMsg" } }, false, {})
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

  local function history_url_completions(arglead)
    if browser.history_urls == nil then
      return {}
    end
    local urls = browser.history_urls()
    if type(urls) ~= "table" then
      return {}
    end
    local matches = {}
    arglead = arglead or ""
    for _, url in ipairs(urls) do
      url = tostring(url)
      if arglead == "" or url:sub(1, #arglead) == arglead then
        table.insert(matches, url)
      end
    end
    return matches
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
    complete = function(arglead)
      return history_url_completions(arglead)
    end,
  })

  vim.api.nvim_create_user_command("NBrowserOpenUnderCursor", function()
    if browser.open_under_cursor == nil or not browser.open_under_cursor() then
      warn_open_under_cursor_unavailable()
    end
  end, {})

  vim.api.nvim_create_user_command("NBrowserHistory", function()
    local history_error_reported = false
    local function report_history_error()
      if history_error_reported then
        return
      end
      history_error_reported = true
      warn_history_unavailable()
    end
    if browser.pick_history == nil or not browser.pick_history(select, {
      on_error = function()
        report_history_error()
      end,
    }) then
      report_history_error()
    end
  end, {
    nargs = 0,
  })

  vim.api.nvim_create_user_command("NBrowserResume", function()
    if browser.resume == nil or not browser.resume() then
      warn_resume_unavailable()
    end
  end, {
    nargs = 0,
  })

  vim.api.nvim_create_user_command("NBrowserActions", function()
    local action_error_reported = false
    local function report_action_error()
      if action_error_reported then
        return
      end
      action_error_reported = true
      warn_action_unavailable()
    end
    if browser.actions == nil or not browser.actions({
      select = select,
      input = input,
      on_error = function()
        report_action_error()
      end,
      on_status = function(status)
        vim.api.nvim_echo({ { status or "unknown" } }, false, {})
      end,
      on_report = function(report)
        vim.api.nvim_echo({ { table.concat((report and report.lines) or {}, "\n") } }, false, {})
      end,
    }) then
      report_action_error()
    end
  end, {
    nargs = 0,
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

  vim.api.nvim_create_user_command("NBrowserScrollTop", function()
    browser.scroll_top()
  end, {})

  vim.api.nvim_create_user_command("NBrowserScrollBottom", function()
    browser.scroll_bottom()
  end, {})

  vim.api.nvim_create_user_command("NBrowserHalfPageDown", function()
    browser.half_page_down()
  end, {})

  vim.api.nvim_create_user_command("NBrowserHalfPageUp", function()
    browser.half_page_up()
  end, {})

  vim.api.nvim_create_user_command("NBrowserZoomIn", function()
    browser.zoom_in()
  end, {})

  vim.api.nvim_create_user_command("NBrowserZoomOut", function()
    browser.zoom_out()
  end, {})

  vim.api.nvim_create_user_command("NBrowserZoomReset", function()
    browser.zoom_reset()
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

  vim.api.nvim_create_user_command("NBrowserYankUrl", function(opts)
    local register = opts.args ~= "" and opts.args or nil
    if not browser.yank_current_url(register) then
      warn_current_url_yank_unavailable()
    end
  end, {
    nargs = "?",
  })

  vim.api.nvim_create_user_command("NBrowserYankHintUrl", function(opts)
    local parts = vim.split(opts.args or "", "%s+", { trimempty = true })
    local identifier = parts[1]
    local register = parts[2]
    if identifier == nil or #parts > 2 or not browser.yank_hint_url(identifier, register) then
      warn_hint_url_yank_unavailable()
    end
  end, {
    nargs = "+",
  })

  vim.api.nvim_create_user_command("NBrowserScreenshot", function(opts)
    local path = opts.args ~= nil and opts.args ~= "" and opts.args or nil
    local saved_path = nil
    local ok, result_path = browser.screenshot(path, {
      on_response = function(response)
        if type(response) == "table" and response.status == "ok" then
          vim.api.nvim_echo({ { "nvim-browser: screenshot saved: " .. tostring(saved_path) } }, false, {})
        end
      end,
    })
    if ok ~= true then
      warn_screenshot_unavailable()
      return
    end
    saved_path = result_path
  end, {
    nargs = "?",
    complete = "file",
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

  vim.api.nvim_create_user_command("NBrowserRightClick", function(opts)
    local parts = vim.split(opts.args, "%s+", { trimempty = true })
    browser.right_click_point(parts[1], parts[2])
  end, {
    nargs = "+",
  })

  vim.api.nvim_create_user_command("NBrowserSelectRegion", function(opts)
    local parts = vim.split(opts.args or "", "%s+", { trimempty = true })
    local start_row
    local start_col
    local end_row
    local end_col
    if #parts == 4 then
      start_row = parts[1]
      start_col = parts[2]
      end_row = parts[3]
      end_col = parts[4]
    elseif #parts == 0 then
      local visual_start = vim.fn.getpos("'<")
      local visual_end = vim.fn.getpos("'>")
      start_row = visual_start[2]
      start_col = vim.fn.virtcol("'<")
      end_row = visual_end[2]
      end_col = vim.fn.virtcol("'>")
    else
      vim.api.nvim_echo({ { "nvim-browser: NBrowserSelectRegion expects either zero arguments or four preview-cell coordinates", "WarningMsg" } }, false, {})
      return
    end
    if not browser.select_region(start_row, start_col, end_row, end_col) then
      vim.api.nvim_echo({ { "nvim-browser: region selection requires an active cursor-addressable browser preview", "WarningMsg" } }, false, {})
    end
  end, {
    nargs = "*",
    range = true,
  })

  vim.api.nvim_create_user_command("NBrowserYankRegion", function(opts)
    local parts = vim.split(opts.args or "", "%s+", { trimempty = true })
    local register = '"'
    local start_row
    local start_col
    local end_row
    local end_col
    if #parts == 5 then
      start_row = parts[1]
      start_col = parts[2]
      end_row = parts[3]
      end_col = parts[4]
      register = parts[5]
    elseif #parts == 4 then
      start_row = parts[1]
      start_col = parts[2]
      end_row = parts[3]
      end_col = parts[4]
    elseif #parts == 1 then
      register = parts[1]
      local visual_start = vim.fn.getpos("'<")
      local visual_end = vim.fn.getpos("'>")
      start_row = visual_start[2]
      start_col = vim.fn.virtcol("'<")
      end_row = visual_end[2]
      end_col = vim.fn.virtcol("'>")
    elseif #parts == 0 then
      local visual_start = vim.fn.getpos("'<")
      local visual_end = vim.fn.getpos("'>")
      start_row = visual_start[2]
      start_col = vim.fn.virtcol("'<")
      end_row = visual_end[2]
      end_col = vim.fn.virtcol("'>")
    else
      vim.api.nvim_echo({ { "nvim-browser: NBrowserYankRegion expects zero args, one register, four preview-cell coordinates, or four coordinates plus one register", "WarningMsg" } }, false, {})
      return
    end
    if not valid_register(register) or not browser.yank_region(register, start_row, start_col, end_row, end_col) then
      warn_selection_yank_unavailable()
    end
  end, {
    nargs = "*",
    range = true,
  })

  vim.api.nvim_create_user_command("NBrowserClickHere", function()
    if not browser.click_here() then
      vim.api.nvim_echo({ { "nvim-browser: cursor click requires an active cursor-addressable browser preview", "WarningMsg" } }, false, {})
    end
  end, {})

  vim.api.nvim_create_user_command("NBrowserRightClickHere", function()
    if not browser.right_click_here() then
      vim.api.nvim_echo({ { "nvim-browser: cursor right click requires an active cursor-addressable browser preview", "WarningMsg" } }, false, {})
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
      if hint.checked ~= nil then
        label = string.format("[%s] %s", hint.checked and "checked" or "unchecked", label)
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

  vim.api.nvim_create_user_command("NBrowserPickHint", function(cmd_opts)
    local action = cmd_opts.args ~= nil and cmd_opts.args ~= "" and cmd_opts.args or "follow"
    if browser.pick_hint_action_available ~= nil and not browser.pick_hint_action_available(action) then
      warn_invalid_picker_action(action)
      return
    end
    local picker_error_reported = false
    local function warn_picker_unavailable()
      if picker_error_reported then
        return
      end
      picker_error_reported = true
      if action == "upload" then
        warn_hint_upload_unavailable()
      elseif action == "yank-url" then
        warn_hint_url_yank_unavailable()
      else
        warn_hint_unavailable()
      end
    end
    if browser.pick_hint == nil or not browser.pick_hint(select, {
      action = action,
      input = input,
      on_error = function()
        warn_picker_unavailable()
      end,
    }) then
      if #browser.hints() == 0 then
        warn_no_hints()
      else
        warn_picker_unavailable()
      end
    end
  end, {
    nargs = "?",
    complete = function()
      return { "follow", "click", "right-click", "focus", "hover", "toggle", "type", "submit", "select", "upload", "yank-url" }
    end,
  })

  vim.api.nvim_create_user_command("NBrowserClickHint", function(opts)
    if not browser.click_hint(opts.args) then
      warn_hint_unavailable()
    end
  end, {
    nargs = 1,
  })

  vim.api.nvim_create_user_command("NBrowserRightClickHint", function(opts)
    if not browser.right_click_hint(opts.args) then
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

  vim.api.nvim_create_user_command("NBrowserFocusHint", function(opts)
    if not browser.focus_hint(opts.args) then
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

  vim.api.nvim_create_user_command("NBrowserSubmitFocused", function()
    if not browser.submit_focused or not browser.submit_focused() then
      warn_submit_focused_unavailable()
    end
  end, {})

  vim.api.nvim_create_user_command("NBrowserSelectHint", function(opts)
    local label, choice = parse_hint_text(opts.args)
    if label == nil or choice == nil or not browser.select_hint(label, choice) then
      warn_hint_input_unavailable()
    end
  end, {
    nargs = "+",
  })

  vim.api.nvim_create_user_command("NBrowserUploadHint", function(opts)
    local args = opts.fargs or {}
    local label = args[1]
    local paths = {}
    for index = 2, #args do
      table.insert(paths, args[index])
    end
    if label == nil or label == "" or #paths == 0 or not browser.upload_hint(label, paths) then
      warn_hint_upload_unavailable()
    end
  end, {
    nargs = "+",
    complete = "file",
  })

  vim.api.nvim_create_user_command("NBrowserToggleHint", function(opts)
    if opts.args == nil or opts.args == "" or not browser.toggle_hint(opts.args) then
      warn_hint_input_unavailable()
    end
  end, {
    nargs = 1,
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

  vim.api.nvim_create_user_command("NBrowserSelectHintMode", function()
    local hints = browser.hints()
    if #hints == 0 then
      warn_no_hints()
      return
    end
    browser.select_hint_mode({
      input = input,
      select = select,
      on_error = warn_hint_input_unavailable,
    })
  end, {})

  vim.api.nvim_create_user_command("NBrowserUploadHintMode", function()
    local hints = browser.hints()
    if #hints == 0 then
      warn_no_hints()
      return
    end
    local label = input("nvim-browser hint: ")
    if label == nil or label == "" then
      return
    end
    local path = input("nvim-browser file: ")
    if path == nil or path == "" then
      return
    end
    if not browser.upload_hint(label, { path }) then
      warn_hint_upload_unavailable()
    end
  end, {})

  vim.api.nvim_create_user_command("NBrowserFocusHintMode", function()
    local hints = browser.hints()
    if #hints == 0 then
      warn_no_hints()
      return
    end
    local label = input("nvim-browser hint: ")
    if label == nil or label == "" then
      return
    end
    if not browser.focus_hint(label) then
      warn_hint_unavailable()
    end
  end, {})

  vim.api.nvim_create_user_command("NBrowserToggleHintMode", function()
    local hints = browser.hints()
    if #hints == 0 then
      warn_no_hints()
      return
    end
    local label = input("nvim-browser hint: ")
    if label == nil or label == "" then
      return
    end
    if not browser.toggle_hint(label) then
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
    local focused = browser.focused_element and focused_element_label(browser.focused_element()) or nil
    local download = browser.latest_download and download_status_label(browser.latest_download()) or nil
    local message = status
    if title ~= nil and title ~= "" then
      message = message .. " " .. title
    end
    if scroll ~= nil then
      message = message .. " " .. scroll
    end
    if focused ~= nil then
      message = message .. " " .. focused
    end
    if download ~= nil then
      message = message .. " " .. download
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

  vim.api.nvim_create_user_command("NBrowserDownloads", function()
    local downloads = browser.downloads ~= nil and browser.downloads() or {}
    if type(downloads) ~= "table" or #downloads == 0 then
      vim.api.nvim_echo({ { "nvim-browser: no completed downloads" } }, false, {})
      return
    end

    local lines = {}
    for _, download in ipairs(downloads) do
      local label = download_list_label(download)
      if label ~= nil and label ~= "" then
        table.insert(lines, label)
      end
    end
    if #lines == 0 then
      vim.api.nvim_echo({ { "nvim-browser: no completed downloads" } }, false, {})
      return
    end
    vim.api.nvim_echo({ { table.concat(lines, "\n") } }, false, {})
  end, {})

  vim.api.nvim_create_user_command("NBrowserDoctor", function()
    local report = browser.doctor()
    vim.api.nvim_echo({ { table.concat(report.lines or {}, "\n") } }, false, {})
  end, {})

  vim.api.nvim_create_user_command("NBrowserCalibrate", function(opts)
    local parts = vim.split(opts.args or "", "%s+", { trimempty = true })
    local width = parts[1] ~= nil and tonumber(parts[1]) or nil
    local height = parts[2] ~= nil and tonumber(parts[2]) or nil
    if #parts > 0 and (width == nil or height == nil or width <= 0 or height <= 0 or #parts > 2) then
      vim.api.nvim_echo({ { "nvim-browser: viewport cell pixels must be positive numbers", "WarningMsg" } }, false, {})
      return
    end
    if #parts > 0 and (width % 1 ~= 0 or height % 1 ~= 0) then
      vim.api.nvim_echo({ { "nvim-browser: viewport cell pixels must be positive integers", "WarningMsg" } }, false, {})
      return
    end
    local report, err = browser.calibrate(width, height)
    if report == false then
      vim.api.nvim_echo({ { "nvim-browser: " .. tostring(err or "calibration failed"), "WarningMsg" } }, false, {})
      return
    end
    vim.api.nvim_echo({ { table.concat(report.lines or {}, "\n") } }, false, {})
  end, {
    nargs = "*",
  })

  vim.api.nvim_create_user_command("NBrowserToggle", function()
    browser.toggle()
  end, {})
end

return M
