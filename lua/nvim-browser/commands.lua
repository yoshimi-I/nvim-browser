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

  vim.api.nvim_create_user_command("NBrowserToggle", function()
    browser.toggle()
  end, {})
end

return M
