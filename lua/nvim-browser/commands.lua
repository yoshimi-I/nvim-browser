local M = {}

function M.register(browser)
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

  vim.api.nvim_create_user_command("NBrowserNavigate", function(opts)
    browser.navigate(opts.args)
  end, {
    nargs = 1,
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

  vim.api.nvim_create_user_command("NBrowserInput", function(opts)
    browser.input_text(opts.args)
  end, {
    nargs = "+",
  })

  vim.api.nvim_create_user_command("NBrowserKey", function(opts)
    browser.press_key(opts.args)
  end, {
    nargs = 1,
  })

  vim.api.nvim_create_user_command("NBrowserFocusSelector", function(opts)
    browser.focus_selector(opts.args)
  end, {
    nargs = "+",
  })

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

  vim.api.nvim_create_user_command("NBrowserHints", function()
    local hints = browser.hints()
    if #hints == 0 then
      vim.api.nvim_echo({ { "nvim-browser: no browser hints available" } }, false, {})
      return
    end
    local lines = {}
    for _, hint in ipairs(hints) do
      table.insert(lines, string.format(
        "%d %s %s @ %.0f,%.0f",
        hint.id,
        hint.kind or "other",
        hint.label or "",
        hint.x or 0,
        hint.y or 0
      ))
    end
    vim.api.nvim_echo({ { table.concat(lines, "\n") } }, false, {})
  end, {})

  vim.api.nvim_create_user_command("NBrowserClickHint", function(opts)
    if not browser.click_hint(opts.args) then
      vim.api.nvim_echo({ { "nvim-browser: hint not found, stale, or browser session is inactive", "WarningMsg" } }, false, {})
    end
  end, {
    nargs = 1,
  })

  vim.api.nvim_create_user_command("NBrowserCurrentUrl", function()
    vim.api.nvim_echo({ { browser.current_url() or "" } }, false, {})
  end, {})

  vim.api.nvim_create_user_command("NBrowserCurrentTitle", function()
    vim.api.nvim_echo({ { browser.current_title() or "" } }, false, {})
  end, {})

  vim.api.nvim_create_user_command("NBrowserStatus", function()
    local status = browser.status() or "unknown"
    local url = browser.current_url() or ""
    local title = browser.current_title and browser.current_title() or nil
    local error = browser.status_error and browser.status_error() or nil
    local message = status
    if title ~= nil and title ~= "" then
      message = message .. " " .. title
    end
    if url ~= "" then
      message = message .. " " .. url
    end
    if error ~= nil and error ~= "" then
      message = message .. " " .. error
    end
    vim.api.nvim_echo({ { message } }, false, {})
  end, {})

  vim.api.nvim_create_user_command("NBrowserToggle", function()
    browser.toggle()
  end, {})
end

return M
