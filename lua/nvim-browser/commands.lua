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

  vim.api.nvim_create_user_command("NBrowserToggle", function()
    browser.toggle()
  end, {})
end

return M
