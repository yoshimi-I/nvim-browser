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
local found_next = false
local found_previous = false
local typed_hint = nil
local submitted_hint = nil
local submitted_focused = false
local selected_hint = nil
local toggled_hint = nil
local focused_hint = nil
local typed_here = nil
local submitted_here = nil
local input_text = nil
local pasted_register = nil
local yanked_register = nil
local pressed_key = nil
local text_mode_called = false
local doctor_called = false
local reader_called = false
local reader_follow_called = false
local stop_called = false
local hovered_here = false
local hovered_hint = nil
local page_scroll_direction = nil
local picked_action = nil
local browser = {
  hints = function()
    return {
      { id = 1, hint_label = "a", kind = "link", label = "Docs", href = "https://example.com/docs", x = 10, y = 20 },
      { id = 2, hint_label = "s", kind = "input", label = "Search", x = 30, y = 40 },
      { id = 3, hint_label = "c", kind = "checkbox", label = "Subscribe", checked = true, x = 50, y = 60 },
      { id = 4, hint_label = "r", kind = "radio", label = "Standard", checked = false, x = 70, y = 80 },
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
  focus_hint = function(identifier)
    focused_hint = identifier
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
  find_text = function(query, opts)
    found = { query = query, backwards = opts ~= nil and opts.backwards == true }
    return true
  end,
  find_next = function()
    found_next = true
    return true
  end,
  find_previous = function()
    found_previous = true
    return true
  end,
  input_text = function(text)
    input_text = text
    return true
  end,
  paste_register = function(register)
    if register == "ab" then
      return false
    end
    pasted_register = register or '"'
    return true
  end,
  yank_selection = function(register)
    if register == "ab" then
      return false
    end
    yanked_register = register or '"'
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
  select_hint = function(label, choice)
    selected_hint = label .. ":" .. choice
    return true
  end,
  toggle_hint = function(label)
    toggled_hint = label
    return true
  end,
  submit_focused = function()
    submitted_focused = true
    return true
  end,
  type_here = function(text, opts)
    if opts ~= nil and opts.submit then
      submitted_here = text
    else
      typed_here = text
    end
    return true
  end,
  doctor = function()
    doctor_called = true
    return { lines = { "nvim-browser doctor", "browser output: kitty-unicode" } }
  end,
  pick_hint = function(select, opts)
    picked_action = opts and opts.action or "follow"
    select({
      { id = 1, hint_label = "a", kind = "link", label = "Docs" },
    }, { prompt = "nvim-browser hint: " }, function() end)
    if opts ~= nil and opts.action == "hover" and opts.on_error ~= nil then
      opts.on_error("action_failed")
    end
    return true
  end,
  pick_hint_action_available = function(action)
    return action == nil
      or action == "follow"
      or action == "click"
      or action == "focus"
      or action == "hover"
      or action == "toggle"
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
  focused_element = function()
    return {
      kind = "input",
      label = "Search",
      value = "hello",
      focusable = true,
      submittable = true,
    }
  end,
  hint_error = function()
    return nil
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
  page_down = function()
    page_scroll_direction = 1
    return true
  end,
  page_up = function()
    page_scroll_direction = -1
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
  select = function(items, opts, on_choice)
    prompted = opts.prompt
    on_choice(items[1])
  end,
})
vim.cmd("NBrowserHints")

assert(echoed:match("^a%s+1%s+link%s+Docs%s+%->%s+https://example%.com/docs%s+@%s+10,20"), "NBrowserHints should show keyboard label before numeric id and href")
assert(echoed:match("https://example%.com/docs"), "NBrowserHints should show structured link hrefs")
assert(echoed:match("\ns%s+2%s+input%s+Search%s+@%s+30,40"), "NBrowserHints should show all keyboard labels")
assert(echoed:match("\nc%s+3%s+checkbox%s+%[checked%]%s+Subscribe%s+@%s+50,60"), "NBrowserHints should show checked checkbox state")
assert(echoed:match("\nr%s+4%s+radio%s+%[unchecked%]%s+Standard%s+@%s+70,80"), "NBrowserHints should show unchecked radio state")

vim.cmd("NBrowserPickHint")
assert(picked_action == "follow", "NBrowserPickHint should default to follow action")
assert(prompted == "nvim-browser hint: ", "NBrowserPickHint should pass configured select prompt")

vim.cmd("NBrowserPickHint focus")
assert(picked_action == "focus", "NBrowserPickHint should pass explicit action")

local invalid_warning_count = #warnings
vim.cmd("NBrowserPickHint bogus")
assert(warnings[#warnings] == "nvim-browser: unsupported hint picker action: bogus", "NBrowserPickHint should warn for invalid actions")
assert(#warnings == invalid_warning_count + 1, "invalid actions should produce one warning")

vim.cmd("NBrowserPickHint hover")
assert(warnings[#warnings] == "nvim-browser: hint not found, stale, or browser session is inactive", "NBrowserPickHint should warn when async picked action fails")

vim.cmd("NBrowserDoctor")
assert(doctor_called == true, "NBrowserDoctor should call browser.doctor")
assert(echoed == "nvim-browser doctor\nbrowser output: kitty-unicode", "NBrowserDoctor should echo doctor lines")

vim.cmd("NBrowserStatus")
assert(echoed:match("scroll 25%%"), "NBrowserStatus should include scroll progress when page metrics exist")
assert(echoed:match("focus=input Search"), "NBrowserStatus should include focused element metadata")
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

vim.cmd("NBrowserPageDown")
assert(page_scroll_direction == 1, "NBrowserPageDown should request a forward page scroll")

vim.cmd("NBrowserPageUp")
assert(page_scroll_direction == -1, "NBrowserPageUp should request a backward page scroll")

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
assert(found.query == "needle", "NBrowserFind should pass an argument to browser.find_text")
assert(found.backwards == false, "NBrowserFind should search forward")

found = nil
vim.cmd("NBrowserFind")
assert(prompted == "nvim-browser find: ", "NBrowserFind should prompt without an argument")
assert(found.query == "s", "NBrowserFind should find the entered text")
assert(found.backwards == false, "prompted NBrowserFind should search forward")

vim.cmd("NBrowserFindNext")
assert(found_next == true, "NBrowserFindNext should repeat the last find forward")

vim.cmd("NBrowserFindPrevious")
assert(found_previous == true, "NBrowserFindPrevious should repeat the last find backward")

vim.cmd("NBrowserInput hello world")
assert(input_text == "hello world", "NBrowserInput should pass text to browser.input_text")

vim.cmd("NBrowserPaste")
assert(pasted_register == '"', "NBrowserPaste should default to the unnamed register")

pasted_register = nil
vim.cmd("NBrowserPaste +")
assert(pasted_register == "+", "NBrowserPaste should pass an explicit register")

pasted_register = nil
vim.cmd("NBrowserPaste ab")
assert(warnings[#warnings] == "nvim-browser: focused text input failed or browser session is inactive", "NBrowserPaste should warn on invalid register names")
assert(pasted_register == nil, "NBrowserPaste should not paste invalid register names")

vim.cmd("NBrowserYankSelection")
assert(yanked_register == '"', "NBrowserYankSelection should default to the unnamed register")

yanked_register = nil
vim.cmd("NBrowserYankSelection +")
assert(yanked_register == "+", "NBrowserYankSelection should pass an explicit register")

yanked_register = nil
vim.cmd("NBrowserYankSelection ab")
assert(warnings[#warnings] == "nvim-browser: browser selection yank failed or no browser selection is active", "NBrowserYankSelection should warn on invalid register names")
assert(yanked_register == nil, "NBrowserYankSelection should not yank invalid register names")

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

vim.cmd("NBrowserSubmitFocused")
assert(submitted_focused == true, "NBrowserSubmitFocused should call browser.submit_focused")

vim.cmd("NBrowserSelectHint s Canada")
assert(selected_hint == "s:Canada", "NBrowserSelectHint should pass the label and choice to browser.select_hint")

vim.cmd("NBrowserToggleHint c")
assert(toggled_hint == "c", "NBrowserToggleHint should pass the label to browser.toggle_hint")

vim.cmd("NBrowserFocusHint s")
assert(focused_hint == "s", "NBrowserFocusHint should pass the label to browser.focus_hint")

vim.cmd("NBrowserTypeHere hello world")
assert(typed_here == "hello world", "NBrowserTypeHere should type at the preview cursor")

vim.cmd("NBrowserSubmitHere hello world")
assert(submitted_here == "hello world", "NBrowserSubmitHere should type at the preview cursor and submit")

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

selected_hint = nil
hint_responses = { "s", "Canada" }
local select_prompts = {}
commands.register(browser, {
  input = function(prompt)
    table.insert(select_prompts, prompt)
    return table.remove(hint_responses, 1)
  end,
})
vim.cmd("NBrowserSelectHintMode")
assert(selected_hint == "s:Canada", "NBrowserSelectHintMode should prompt and select a hinted option")

focused_hint = nil
hint_responses = { "s" }
local focus_prompts = {}
commands.register(browser, {
  input = function(prompt)
    table.insert(focus_prompts, prompt)
    return table.remove(hint_responses, 1)
  end,
})
vim.cmd("NBrowserFocusHintMode")
assert(focused_hint == "s", "NBrowserFocusHintMode should prompt and focus a hint")
assert(table.concat(focus_prompts, "|") == "nvim-browser hint: ", "NBrowserFocusHintMode should prompt for hint")
assert(
  table.concat(select_prompts, "|") == "nvim-browser hint: |nvim-browser option: ",
  "NBrowserSelectHintMode should prompt for hint then option"
)

toggled_hint = nil
hint_responses = { "c" }
local toggle_prompts = {}
commands.register(browser, {
  input = function(prompt)
    table.insert(toggle_prompts, prompt)
    return table.remove(hint_responses, 1)
  end,
})
vim.cmd("NBrowserToggleHintMode")
assert(toggled_hint == "c", "NBrowserToggleHintMode should prompt and toggle a hinted checkbox/radio")
assert(
  table.concat(toggle_prompts, "|") == "nvim-browser hint: ",
  "NBrowserToggleHintMode should prompt for hint"
)

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
  find_next = function()
    return false
  end,
  find_previous = function()
    return false
  end,
  input_text = function()
    return false
  end,
  paste_register = function()
    return false
  end,
  yank_selection = function()
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
  select_hint = function()
    return false
  end,
  toggle_hint = function()
    return false
  end,
  focus_hint = function()
    return false
  end,
  type_here = function()
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

vim.cmd("NBrowserFindNext")
assert(warnings[#warnings] == "nvim-browser: no previous browser find query", "NBrowserFindNext should warn when no query is available")

vim.cmd("NBrowserFindPrevious")
assert(warnings[#warnings] == "nvim-browser: no previous browser find query", "NBrowserFindPrevious should warn when no query is available")

vim.cmd("NBrowserInput missing")
assert(warnings[#warnings] == "nvim-browser: focused text input failed or browser session is inactive", "NBrowserInput should warn when focused text input fails")

vim.cmd("NBrowserPaste")
assert(warnings[#warnings] == "nvim-browser: focused text input failed or browser session is inactive", "NBrowserPaste should warn when register paste fails")

vim.cmd("NBrowserYankSelection")
assert(warnings[#warnings] == "nvim-browser: browser selection yank failed or no browser selection is active", "NBrowserYankSelection should warn when selection yank fails")

vim.cmd("NBrowserInputMode")
assert(warnings[#warnings] == "nvim-browser: focused text input failed or browser session is inactive", "NBrowserInputMode should warn when focused text input fails")

vim.cmd("NBrowserTextMode")
assert(warnings[#warnings] == "nvim-browser: text mode requires an active cursor-addressable browser preview", "NBrowserTextMode should warn when text mode fails")

vim.cmd("NBrowserTypeHint s missing")
assert(warnings[#warnings] == "nvim-browser: hint input failed, stale, or browser session is inactive", "NBrowserTypeHint should warn when type_hint fails")

vim.cmd("NBrowserSelectHint s missing")
assert(warnings[#warnings] == "nvim-browser: hint input failed, stale, or browser session is inactive", "NBrowserSelectHint should warn when select_hint fails")

vim.cmd("NBrowserToggleHint s")
assert(warnings[#warnings] == "nvim-browser: hint input failed, stale, or browser session is inactive", "NBrowserToggleHint should warn when toggle_hint fails")

vim.cmd("NBrowserFocusHint s")
assert(warnings[#warnings] == "nvim-browser: hint not found, stale, or browser session is inactive", "NBrowserFocusHint should warn when focus_hint fails")

vim.cmd("NBrowserTypeHere missing")
assert(warnings[#warnings] == "nvim-browser: cursor text input requires an active cursor-addressable browser preview", "NBrowserTypeHere should warn when cursor typing fails")

vim.cmd("NBrowserSubmitHere missing")
assert(warnings[#warnings] == "nvim-browser: cursor text input requires an active cursor-addressable browser preview", "NBrowserSubmitHere should warn when cursor submit fails")

vim.cmd("NBrowserTypeHintMode")
assert(
  warnings[#warnings] == "nvim-browser: hint input failed, stale, or browser session is inactive",
  "NBrowserTypeHintMode should warn when hinted input mode fails"
)

vim.cmd("NBrowserSelectHintMode")
assert(
  warnings[#warnings] == "nvim-browser: hint input failed, stale, or browser session is inactive",
  "NBrowserSelectHintMode should warn when hinted select mode fails"
)

vim.cmd("NBrowserToggleHintMode")
assert(
  warnings[#warnings] == "nvim-browser: hint input failed, stale, or browser session is inactive",
  "NBrowserToggleHintMode should warn when hinted toggle mode fails"
)

vim.cmd("NBrowserFocusHintMode")
assert(
  warnings[#warnings] == "nvim-browser: hint not found, stale, or browser session is inactive",
  "NBrowserFocusHintMode should warn when hinted focus mode fails"
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

vim.cmd("NBrowserTypeHere")
assert(
  warnings[#warnings] == "nvim-browser: cursor text input requires an active cursor-addressable browser preview",
  "NBrowserTypeHere should warn on empty text instead of failing command parsing"
)

vim.cmd("NBrowserSubmitHere")
assert(
  warnings[#warnings] == "nvim-browser: cursor text input requires an active cursor-addressable browser preview",
  "NBrowserSubmitHere should warn on empty text instead of failing command parsing"
)

local empty_browser = {
  hints = function()
    return {}
  end,
  hint_error = function()
    return nil
  end,
  click_hint = function()
    error("click_hint should not be called without hints")
  end,
  focus_hint = function()
    error("focus_hint should not be called without hints")
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

vim.cmd("NBrowserSelectHintMode")
assert(warnings[#warnings] == "nvim-browser: no browser hints available", "NBrowserSelectHintMode should warn when no hints exist")
assert(no_hint_input_called == false, "NBrowserSelectHintMode should not prompt when no hints exist")

vim.cmd("NBrowserToggleHintMode")
assert(warnings[#warnings] == "nvim-browser: no browser hints available", "NBrowserToggleHintMode should warn when no hints exist")
assert(no_hint_input_called == false, "NBrowserToggleHintMode should not prompt when no hints exist")

vim.cmd("NBrowserFocusHintMode")
assert(warnings[#warnings] == "nvim-browser: no browser hints available", "NBrowserFocusHintMode should warn when no hints exist")
assert(no_hint_input_called == false, "NBrowserFocusHintMode should not prompt when no hints exist")

local hint_error_browser = {
  hints = function()
    return {}
  end,
  hint_error = function()
    return "hint extraction failed"
  end,
}
commands.register(hint_error_browser, {
  input = function()
    error("input should not be called when hint extraction failed")
  end,
})
vim.cmd("NBrowserHintMode")
assert(
  warnings[#warnings] == "nvim-browser: hint extraction failed: hint extraction failed",
  "NBrowserHintMode should distinguish hint extraction failures from empty hint sets"
)
vim.cmd("NBrowserTypeHintMode")
assert(
  warnings[#warnings] == "nvim-browser: hint extraction failed: hint extraction failed",
  "NBrowserTypeHintMode should distinguish hint extraction failures from empty hint sets"
)
vim.cmd("NBrowserSelectHintMode")
assert(
  warnings[#warnings] == "nvim-browser: hint extraction failed: hint extraction failed",
  "NBrowserSelectHintMode should distinguish hint extraction failures from empty hint sets"
)
vim.cmd("NBrowserToggleHintMode")
assert(
  warnings[#warnings] == "nvim-browser: hint extraction failed: hint extraction failed",
  "NBrowserToggleHintMode should distinguish hint extraction failures from empty hint sets"
)
vim.cmd("NBrowserFocusHintMode")
assert(
  warnings[#warnings] == "nvim-browser: hint extraction failed: hint extraction failed",
  "NBrowserFocusHintMode should distinguish hint extraction failures from empty hint sets"
)

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
