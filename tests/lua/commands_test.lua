local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local commands = require("nvim-browser.commands")

local clicked = nil
local followed = nil
local prompted = nil
local prompt_default = nil
local warnings = {}
local addressed = nil
local found = nil
local typed_hint = nil
local submitted_hint = nil
local input_text = nil
local pressed_key = nil
local text_mode_called = false
local doctor_called = false
local reader_called = false
local reader_follow_called = false
local stop_called = false
local hovered_here = false
local hovered_hint = nil
local browser = {
  hints = function()
    return {
      { id = 1, hint_label = "a", kind = "link", label = "Docs", href = "https://example.com/docs", x = 10, y = 20 },
      { id = 2, hint_label = "s", kind = "input", label = "Search", x = 30, y = 40 },
    }
  end,
  click_hint = function(identifier)
    clicked = identifier
    return true
  end,
  follow_hint = function(identifier)
    followed = identifier
    return true
  end,
  hover_here = function()
    hovered_here = true
    return true
  end,
  hover_hint = function(identifier)
    hovered_hint = identifier
    return true
  end,
  address = function(input)
    if type(input) == "string" then
      addressed = input
    else
      addressed = input("nvim-browser address: ")
    end
    return true
  end,
  find_text = function(query)
    found = query
    return true
  end,
  input_text = function(text)
    input_text = text
    return true
  end,
  press_key = function(key, opts)
    pressed_key = { key = key, modifiers = opts and opts.modifiers or {} }
    return true
  end,
  input_text_mode = function(input_fn)
    input_text = input_fn("nvim-browser text: ")
    return true
  end,
  start_text_mode = function()
    text_mode_called = true
    return true
  end,
  type_hint = function(label, text, opts)
    if opts ~= nil and opts.submit then
      submitted_hint = label .. ":" .. text
    else
      typed_hint = label .. ":" .. text
    end
    return true
  end,
  doctor = function()
    doctor_called = true
    return { lines = { "nvim-browser doctor", "browser output: kitty-unicode" } }
  end,
  status = function()
    return "ok"
  end,
  current_url = function()
    return "https://example.com/long"
  end,
  current_title = function()
    return "Example"
  end,
  status_error = function()
    return nil
  end,
  page_metrics = function()
    return {
      scroll_x = 0,
      scroll_y = 250,
      viewport_width = 800,
      viewport_height = 600,
      document_width = 800,
      document_height = 1600,
    }
  end,
  runtime_metadata = function()
    return {
      protocol_version = 1,
      transport = "stdio-jsonl",
      renderer = "chromium-cdp",
      output = "kitty-unicode",
      cells = { columns = 80, rows = 24 },
      viewport = { width = 800, height = 600, device_scale_factor = 1 },
    }
  end,
  reader = function()
    reader_called = true
    return true
  end,
  reader_follow = function()
    reader_follow_called = true
    return true
  end,
  stop = function()
    stop_called = true
    return true
  end,
}

local echoed = nil
local original_echo = vim.api.nvim_echo
vim.api.nvim_echo = function(chunks)
  echoed = chunks[1][1]
  if chunks[1][2] == "WarningMsg" then
    table.insert(warnings, chunks[1][1])
  end
end

commands.register(browser, {
  input = function(prompt, default)
    prompted = prompt
    prompt_default = default
    return "s"
  end,
})
vim.cmd("NBrowserHints")

assert(echoed:match("^a%s+1%s+link%s+Docs%s+%->%s+https://example%.com/docs%s+@%s+10,20"), "NBrowserHints should show keyboard label before numeric id and href")
assert(echoed:match("https://example%.com/docs"), "NBrowserHints should show structured link hrefs")
assert(echoed:match("\ns%s+2%s+input%s+Search%s+@%s+30,40"), "NBrowserHints should show all keyboard labels")

vim.cmd("NBrowserDoctor")
assert(doctor_called == true, "NBrowserDoctor should call browser.doctor")
assert(echoed == "nvim-browser doctor\nbrowser output: kitty-unicode", "NBrowserDoctor should echo doctor lines")

vim.cmd("NBrowserStatus")
assert(echoed:match("scroll 25%%"), "NBrowserStatus should include scroll progress when page metrics exist")
assert(echoed:match("output=kitty%-unicode"), "NBrowserStatus should include runtime output when available")
assert(echoed:match("viewport=800x600"), "NBrowserStatus should include runtime viewport when available")
assert(echoed:match("cells=80x24"), "NBrowserStatus should include runtime cell size when available")
assert(echoed:match("renderer=chromium%-cdp"), "NBrowserStatus should include runtime renderer when available")

vim.cmd("NBrowserReader")
assert(reader_called == true, "NBrowserReader should call browser.reader")

vim.cmd("NBrowserReaderFollow")
assert(reader_follow_called == true, "NBrowserReaderFollow should call browser.reader_follow")

vim.cmd("NBrowserStop")
assert(stop_called == true, "NBrowserStop should call browser.stop")

vim.cmd("NBrowserAddress")
assert(addressed == "s", "NBrowserAddress should pass the injected input function to browser.address")
assert(prompt_default == "https://example.com/long", "NBrowserAddress should prefill the current URL when prompting")

prompted = nil
prompt_default = nil
addressed = nil
vim.cmd("NBrowserAddress hello world")
assert(addressed == "hello world", "NBrowserAddress should accept address text as command arguments")
assert(prompted == nil, "NBrowserAddress with arguments should not prompt")

vim.cmd("NBrowserFind needle")
assert(found == "needle", "NBrowserFind should pass an argument to browser.find_text")

found = nil
vim.cmd("NBrowserFind")
assert(prompted == "nvim-browser find: ", "NBrowserFind should prompt without an argument")
assert(found == "s", "NBrowserFind should find the entered text")

vim.cmd("NBrowserInput hello world")
assert(input_text == "hello world", "NBrowserInput should pass text to browser.input_text")

vim.cmd("NBrowserKey Enter")
assert(pressed_key.key == "Enter", "NBrowserKey should pass a key to browser.press_key")
assert(#pressed_key.modifiers == 0, "NBrowserKey without modifiers should pass an empty modifier list")

vim.cmd("NBrowserKey A ctrl shift")
assert(pressed_key.key == "A", "NBrowserKey should parse the first argument as the key")
assert(
  table.concat(pressed_key.modifiers, "+") == "ctrl+shift",
  "NBrowserKey should pass remaining arguments as modifiers"
)

input_text = nil
vim.cmd("NBrowserInputMode")
assert(prompted == "nvim-browser text: ", "NBrowserInputMode should prompt for focused text")
assert(input_text == "s", "NBrowserInputMode should type prompted text into the focused element")

vim.cmd("NBrowserTextMode")
assert(text_mode_called == true, "NBrowserTextMode should start interactive browser text mode")

vim.cmd("NBrowserTypeHint s hello world")
assert(typed_hint == "s:hello world", "NBrowserTypeHint should pass the label and text to browser.type_hint")

vim.cmd("NBrowserSubmitHint s hello world")
assert(submitted_hint == "s:hello world", "NBrowserSubmitHint should request submit mode")

typed_hint = nil
local hint_prompts = {}
local hint_responses = { "s", "hello world" }
commands.register(browser, {
  input = function(prompt)
    table.insert(hint_prompts, prompt)
    return table.remove(hint_responses, 1)
  end,
})
vim.cmd("NBrowserTypeHintMode")
assert(typed_hint == "s:hello world", "NBrowserTypeHintMode should prompt and type into a hint")
assert(
  table.concat(hint_prompts, "|") == "nvim-browser hint: |nvim-browser text: ",
  "NBrowserTypeHintMode should prompt for hint then text"
)

submitted_hint = nil
hint_responses = { "s", "hello world" }
commands.register(browser, {
  input = function()
    return table.remove(hint_responses, 1)
  end,
})
vim.cmd("NBrowserSubmitHintMode")
assert(submitted_hint == "s:hello world", "NBrowserSubmitHintMode should prompt and submit a hinted input")

commands.register(browser, {
  input = function(prompt, default)
    prompted = prompt
    prompt_default = default
    return "s"
  end,
})

vim.cmd("NBrowserFollowHint a")
assert(followed == "a", "NBrowserFollowHint should pass the label to follow_hint")
assert(clicked == nil, "NBrowserFollowHint should not call click_hint when follow_hint exists")

vim.cmd("NBrowserHoverHere")
assert(hovered_here == true, "NBrowserHoverHere should call hover_here")

vim.cmd("NBrowserHoverHint m")
assert(hovered_hint == "m", "NBrowserHoverHint should pass the label to hover_hint")

followed = nil
vim.cmd("NBrowserHintMode")
assert(prompted == "nvim-browser hint: ", "NBrowserHintMode should prompt for a hint label")
assert(followed == "s", "NBrowserHintMode should follow the entered label")

followed = nil
commands.register(browser, {
  input = function()
    return ""
  end,
})
vim.cmd("NBrowserHintMode")
assert(followed == nil, "NBrowserHintMode should silently cancel on empty input")

local failed_browser = {
  hints = browser.hints,
  follow_hint = function()
    return false
  end,
  address = function()
    return false
  end,
  find_text = function()
    return false
  end,
  input_text = function()
    return false
  end,
  input_text_mode = function()
    return false
  end,
  start_text_mode = function()
    return false
  end,
  type_hint = function()
    return false
  end,
  stop = function()
    return false
  end,
}
commands.register(failed_browser, {
  input = function()
    return "missing"
  end,
})
vim.cmd("NBrowserHintMode")
assert(
  warnings[#warnings] == "nvim-browser: hint not found, stale, or browser session is inactive",
  "NBrowserHintMode should warn when following a label fails"
)

vim.cmd("NBrowserAddress")
assert(warnings[#warnings] == "nvim-browser: address was empty or could not be opened", "NBrowserAddress should warn when address fails")

vim.cmd("NBrowserFind missing")
assert(warnings[#warnings] == "nvim-browser: text was not found or browser session is inactive", "NBrowserFind should warn when find fails")

vim.cmd("NBrowserInput missing")
assert(warnings[#warnings] == "nvim-browser: focused text input failed or browser session is inactive", "NBrowserInput should warn when focused text input fails")

vim.cmd("NBrowserInputMode")
assert(warnings[#warnings] == "nvim-browser: focused text input failed or browser session is inactive", "NBrowserInputMode should warn when focused text input fails")

vim.cmd("NBrowserTextMode")
assert(warnings[#warnings] == "nvim-browser: text mode requires an active cursor-addressable browser preview", "NBrowserTextMode should warn when text mode fails")

vim.cmd("NBrowserTypeHint s missing")
assert(warnings[#warnings] == "nvim-browser: hint input failed, stale, or browser session is inactive", "NBrowserTypeHint should warn when type_hint fails")

vim.cmd("NBrowserTypeHintMode")
assert(
  warnings[#warnings] == "nvim-browser: hint input failed, stale, or browser session is inactive",
  "NBrowserTypeHintMode should warn when hinted input mode fails"
)

vim.cmd("NBrowserStop")
assert(warnings[#warnings] == "nvim-browser: no pending browser operation to stop", "NBrowserStop should warn when no operation is pending")

local warning_count = #warnings
commands.register(failed_browser, {
  input = function()
    return ""
  end,
})
vim.cmd("NBrowserAddress")
assert(#warnings == warning_count, "NBrowserAddress should silently cancel on empty input")

vim.cmd("NBrowserFind")
assert(#warnings == warning_count, "NBrowserFind should silently cancel on empty input")

vim.cmd("NBrowserInputMode")
assert(#warnings == warning_count, "NBrowserInputMode should silently cancel on empty input")

local empty_browser = {
  hints = function()
    return {}
  end,
  click_hint = function()
    error("click_hint should not be called without hints")
  end,
}
commands.register(empty_browser, {
  input = function()
    error("input should not be called without hints")
  end,
})
vim.cmd("NBrowserHintMode")
assert(warnings[#warnings] == "nvim-browser: no browser hints available", "NBrowserHintMode should warn when no hints exist")

local no_hint_input_called = false
commands.register(empty_browser, {
  input = function()
    no_hint_input_called = true
    return "s"
  end,
})
vim.cmd("NBrowserTypeHintMode")
assert(warnings[#warnings] == "nvim-browser: no browser hints available", "NBrowserTypeHintMode should warn when no hints exist")
assert(no_hint_input_called == false, "NBrowserTypeHintMode should not prompt when no hints exist")

local no_default_prompt = nil
local no_default_browser = {
  address = function()
    error("address should not be called for empty first-use prompt input")
  end,
  current_url = function()
    return nil
  end,
  last_target = function()
    return nil
  end,
}
commands.register(no_default_browser, {
  input = function(_, default)
    no_default_prompt = default
    return ""
  end,
})
local no_default_warning_count = #warnings
vim.cmd("NBrowserAddress")
assert(no_default_prompt == "", "NBrowserAddress should use an empty prompt default when no URL or target exists")
assert(#warnings == no_default_warning_count, "NBrowserAddress should silently cancel empty first-use prompt input")

vim.api.nvim_echo = original_echo
