local address = require("nvim-browser.address")
local backend = require("nvim-browser.backend")
local config = require("nvim-browser.config")
local doctor = require("nvim-browser.doctor")
local keymaps = require("nvim-browser.keymaps")
local status_labels = require("nvim-browser.status")
local terminal = require("nvim-browser.terminal")

local M = {}

local state = {
  last_target = nil,
  history = {},
  bookmarks = {},
  downloads = {},
  session_warning_messages = {},
  session_loaded_path = nil,
  viewport_explicitly_configured = false,
  guided_calibration = nil,
  smoke_target = nil,
}

local history_limit = 50
local session_version = 1

local function plugin_root()
  return vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
end

local function calibration_fixture_path()
  return plugin_root() .. "/data/html/calibrate.html"
end

local function smoke_fixture_path()
  return plugin_root() .. "/data/html/smoke.html"
end

local function smoke_fixture_url()
  return vim.uri_from_fname(smoke_fixture_path())
end

local function default_session_path()
  return vim.fn.stdpath("state") .. "/nvim-browser/session.json"
end

local function default_calibration_path()
  return vim.fn.stdpath("state") .. "/nvim-browser/calibration.json"
end

local function session_options()
  local opts = (M.config and M.config.session) or {}
  local limit = math.floor(tonumber(opts.history_limit) or history_limit)
  if limit < 0 then
    limit = 0
  end
  return {
    persist = opts.persist ~= false,
    history_limit = limit,
    path = opts.path or default_session_path(),
  }
end

local function calibration_options()
  local opts = (M.config and M.config.calibration) or {}
  return {
    persist = opts.persist ~= false,
    path = opts.path or default_calibration_path(),
  }
end

local function warn_session(message)
  if state.session_warning_messages[message] then
    return
  end
  state.session_warning_messages[message] = true
  vim.api.nvim_echo({ { message, "WarningMsg" } }, false, {})
end

local function normalize_history_value(value)
  if value == nil or value == vim.NIL then
    return nil
  end
  value = tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
  if value == "" then
    return nil
  end
  return value
end

local function is_direct_history_url(target)
  return type(target) == "string" and target:match("^https?://") ~= nil
end

local function add_history_entry(url, title)
  url = normalize_history_value(url)
  if url == nil then
    return false
  end
  if not is_direct_history_url(url) then
    return false
  end
  title = normalize_history_value(title)
  for index = #state.history, 1, -1 do
    if state.history[index].url == url then
      table.remove(state.history, index)
    end
  end
  table.insert(state.history, 1, { url = url, title = title })
  while #state.history > history_limit do
    table.remove(state.history)
  end
  return true
end

local function normalize_bookmark_entry(bookmark)
  if type(bookmark) ~= "table" then
    return nil
  end
  local url = normalize_history_value(bookmark.url)
  if url == nil then
    return nil
  end
  return {
    url = url,
    title = normalize_history_value(bookmark.title),
  }
end

local function add_bookmark_entry(url, title)
  local entry = normalize_bookmark_entry({ url = url, title = title })
  if entry == nil then
    return false
  end
  for index = #state.bookmarks, 1, -1 do
    if state.bookmarks[index].url == entry.url then
      table.remove(state.bookmarks, index)
    end
  end
  table.insert(state.bookmarks, 1, entry)
  while #state.bookmarks > history_limit do
    table.remove(state.bookmarks)
  end
  return true
end

local function normalize_download_entry(download)
  if type(download) ~= "table" then
    return nil
  end
  local path = normalize_history_value(download.path)
  if path == nil then
    return nil
  end
  if download.status ~= "completed" then
    return nil
  end
  local entry = {
    path = path,
    status = "completed",
  }
  local suggested_filename = normalize_history_value(download.suggested_filename)
  if suggested_filename ~= nil then
    entry.suggested_filename = suggested_filename
  end
  return entry
end

local function add_download_entry(download)
  local entry = normalize_download_entry(download)
  if entry == nil then
    return false
  end
  for index = #state.downloads, 1, -1 do
    if state.downloads[index].path == entry.path then
      table.remove(state.downloads, index)
    end
  end
  table.insert(state.downloads, entry)
  while #state.downloads > history_limit do
    table.remove(state.downloads, 1)
  end
  return true
end

local function persisted_downloads()
  local downloads = {}
  for _, download in ipairs(state.downloads) do
    table.insert(downloads, vim.deepcopy(download))
  end
  return downloads
end

local function save_session()
  local opts = session_options()
  if not opts.persist then
    return true
  end
  local directory = vim.fn.fnamemodify(opts.path, ":h")
  if directory ~= nil and directory ~= "" and directory ~= "." then
    local mkdir_ok, mkdir_result = pcall(vim.fn.mkdir, directory, "p")
    if not mkdir_ok or mkdir_result == 0 then
      warn_session("nvim-browser: failed to create session state directory")
      return false
    end
  end
  local payload = {
    version = session_version,
    last_target = normalize_history_value(state.last_target),
    history = M.history(),
    bookmarks = M.bookmarks(),
    downloads = persisted_downloads(),
  }
  local encoded_ok, encoded = pcall(vim.fn.json_encode, payload)
  if not encoded_ok then
    warn_session("nvim-browser: failed to encode session state")
    return false
  end
  local write_ok, write_result = pcall(vim.fn.writefile, { encoded }, opts.path)
  if not write_ok or write_result ~= 0 then
    warn_session("nvim-browser: failed to write session state")
    return false
  end
  return true
end

local function set_last_target(target)
  target = normalize_history_value(target)
  if target == nil then
    return false
  end
  state.last_target = target
  save_session()
  return true
end

local function record_target(target, title)
  target = normalize_history_value(target)
  if target == nil then
    return false
  end
  if state.smoke_target ~= nil and target == state.smoke_target then
    return false
  end
  add_history_entry(target, title)
  state.last_target = target
  save_session()
  return true
end

local function session_file_signature(path, limit)
  local stat_ok, stat = pcall(vim.loop.fs_stat, path)
  if not stat_ok or stat == nil then
    return path .. "\n" .. tostring(limit) .. "\nmissing"
  end
  return table.concat({
    path,
    tostring(limit),
    tostring(stat.size or 0),
    tostring((stat.mtime or {}).sec or 0),
    tostring((stat.mtime or {}).nsec or 0),
  }, "\n")
end

local function load_session()
  local opts = session_options()
  history_limit = opts.history_limit
  if not opts.persist then
    state.session_loaded_path = nil
    state.bookmarks = {}
    state.downloads = {}
    return
  end
  local load_signature = session_file_signature(opts.path, opts.history_limit)
  if state.session_loaded_path == load_signature then
    return
  end
  state.session_loaded_path = load_signature
  state.last_target = nil
  state.history = {}
  state.bookmarks = {}
  state.downloads = {}
  local read_ok, lines = pcall(vim.fn.readfile, opts.path)
  if not read_ok or type(lines) ~= "table" or #lines == 0 then
    return
  end
  local decode_ok, decoded = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
  if not decode_ok or type(decoded) ~= "table" then
    warn_session("nvim-browser: ignored malformed session state")
    return
  end
  state.last_target = normalize_history_value(decoded.last_target)
  if type(decoded.history) == "table" then
    for index = #decoded.history, 1, -1 do
      local entry = decoded.history[index]
      if type(entry) == "table" then
        add_history_entry(entry.url, entry.title)
      end
    end
  end
  if type(decoded.bookmarks) == "table" then
    for index = #decoded.bookmarks, 1, -1 do
      local entry = normalize_bookmark_entry(decoded.bookmarks[index])
      if entry ~= nil then
        add_bookmark_entry(entry.url, entry.title)
      end
    end
  end
  if type(decoded.downloads) == "table" then
    for _, download in ipairs(decoded.downloads) do
      add_download_entry(download)
    end
  end
end

local function parse_cell_pixels(cell_width_px, cell_height_px)
  local width = tonumber(cell_width_px)
  local height = tonumber(cell_height_px)
  if width == nil or height == nil or width <= 0 or height <= 0 then
    return nil, nil, "viewport cell pixels must be positive numbers"
  end
  if width % 1 ~= 0 or height % 1 ~= 0 then
    return nil, nil, "viewport cell pixels must be positive integers"
  end
  return width, height
end

local function normalize_calibration_payload(payload)
  if type(payload) ~= "table" then
    return nil
  end
  local width, height = parse_cell_pixels(payload.cell_width_px, payload.cell_height_px)
  if width == nil or height == nil then
    return nil
  end
  return {
    cell_width_px = width,
    cell_height_px = height,
  }
end

local function load_persisted_calibration()
  local opts = calibration_options()
  if not opts.persist then
    return nil
  end
  local read_ok, lines = pcall(vim.fn.readfile, opts.path)
  if not read_ok or type(lines) ~= "table" or #lines == 0 then
    return nil
  end
  local decode_ok, decoded = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
  if not decode_ok then
    warn_session("nvim-browser: ignored malformed calibration state")
    return nil
  end
  local normalized = normalize_calibration_payload(decoded)
  if normalized == nil then
    warn_session("nvim-browser: ignored malformed calibration state")
  end
  return normalized
end

local function save_calibration(width, height)
  local opts = calibration_options()
  if not opts.persist then
    return true
  end
  local directory = vim.fn.fnamemodify(opts.path, ":h")
  if directory ~= nil and directory ~= "" and directory ~= "." then
    local mkdir_ok, mkdir_result = pcall(vim.fn.mkdir, directory, "p")
    if not mkdir_ok or mkdir_result == 0 then
      warn_session("nvim-browser: failed to create calibration state directory")
      return false
    end
  end
  local encoded_ok, encoded = pcall(vim.fn.json_encode, {
    version = 1,
    cell_width_px = width,
    cell_height_px = height,
  })
  if not encoded_ok then
    warn_session("nvim-browser: failed to encode calibration state")
    return false
  end
  local write_ok, write_result = pcall(vim.fn.writefile, { encoded }, opts.path)
  if not write_ok or write_result ~= 0 then
    warn_session("nvim-browser: failed to write calibration state")
    return false
  end
  return true
end

local function apply_calibration(width, height)
  M.config.viewport = M.config.viewport or {}
  M.config.viewport.cell_width_px = width
  M.config.viewport.cell_height_px = height
  M.config.viewport_source = "config"
  save_calibration(width, height)
  terminal.configure({ viewport = M.config.viewport })
end

local function guided_calibration_matches_viewport(sample)
  local viewport = M.config and M.config.viewport or nil
  return type(sample) == "table"
    and type(viewport) == "table"
    and tonumber(sample.cell_width_px) == tonumber(viewport.cell_width_px)
    and tonumber(sample.cell_height_px) == tonumber(viewport.cell_height_px)
end

local function is_auto_refresh_preview_path(path)
  local extension = vim.fn.fnamemodify(path or "", ":e"):lower()
  return extension == "md"
    or extension == "markdown"
    or extension == "png"
    or extension == "jpg"
    or extension == "jpeg"
    or extension == "gif"
    or extension == "webp"
end

local function normalize_local_file_path(path)
  if path == nil or path == "" then
    return nil
  end
  path = vim.fn.fnamemodify(path, ":p")
  local uv = vim.uv or vim.loop
  local realpath = uv and uv.fs_realpath(path) or nil
  return realpath or path
end

local function source_path_from_file_url(url)
  if type(url) ~= "string" or not url:match("^file://") then
    return nil
  end
  local ok, path = pcall(vim.uri_to_fname, url)
  if not ok or path == nil or path == "" then
    return nil
  end
  return normalize_local_file_path(path)
end

local function setup_auto_refresh_on_write()
  local group = vim.api.nvim_create_augroup("NBrowserAutoRefreshOnWrite", { clear = true })
  if M.config.auto_refresh_on_write == false then
    return
  end
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(args)
      local written_path = args.file
      if written_path == nil or written_path == "" then
        written_path = vim.api.nvim_buf_get_name(args.buf)
      end
      if written_path == nil or written_path == "" then
        return
      end
      written_path = normalize_local_file_path(written_path)
      if not is_auto_refresh_preview_path(written_path) then
        return
      end
      local terminal_state = terminal.state()
      if terminal_state.mode ~= "serve" or terminal_state.job_id == nil or terminal_state.has_buffer ~= true then
        return
      end
      if source_path_from_file_url(terminal_state.current_url) ~= written_path then
        return
      end
      terminal.refresh()
    end,
  })
end

function M.setup(opts)
  opts = opts or {}
  local explicit_viewport = type(opts.viewport) == "table"
    and (opts.viewport.cell_width_px ~= nil or opts.viewport.cell_height_px ~= nil)
  M.config = config.setup(opts)
  if explicit_viewport then
    state.viewport_explicitly_configured = true
    M.config.viewport = {
      cell_width_px = opts.viewport.cell_width_px or 10,
      cell_height_px = opts.viewport.cell_height_px or 20,
    }
    M.config.viewport_source = "config"
  elseif state.viewport_explicitly_configured then
    M.config.viewport_source = "config"
  else
    M.config.viewport = {
      cell_width_px = 10,
      cell_height_px = 20,
    }
    M.config.viewport_source = "default"
    local persisted = load_persisted_calibration()
    if persisted ~= nil then
      M.config.viewport.cell_width_px = persisted.cell_width_px
      M.config.viewport.cell_height_px = persisted.cell_height_px
      M.config.viewport_source = "persisted"
    end
  end
  load_session()
  terminal.configure(M.config)
  terminal.set_metadata_observer(function(metadata)
    M.record_history(metadata.url, metadata.title)
  end)
  terminal.set_download_observer(function(download)
    if add_download_entry(download) then
      save_session()
    end
  end)
  if guided_calibration_matches_viewport(state.guided_calibration) then
    M.config.guided_calibration = vim.deepcopy(state.guided_calibration)
  else
    M.config.guided_calibration = nil
  end
  keymaps.setup(M, M.config.keymaps or {})
  setup_auto_refresh_on_write()
end

local function resolve_target(target)
  return target or vim.fn.expand("%:p")
end

local function has_active_browser_session()
  local terminal_state = terminal.state()
  return terminal_state.mode == "serve"
    and terminal_state.job_id ~= nil
    and terminal_state.has_buffer
end

local function trim_cursor_target(value, opts)
  opts = opts or {}
  if value == nil or value == vim.NIL then
    return nil
  end
  value = tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
  if opts.strip_closing ~= false then
    value = value:gsub("[%)%]}>.,;]+$", "")
  else
    value = value:gsub("[%]}>.,;]+$", "")
  end
  value = value:gsub("^[%(<%[{]+", "")
  if value == "" then
    return nil
  end
  return value
end

local function unescape_markdown_target(value)
  if value == nil then
    return nil
  end
  return value:gsub("\\(.)", "%1")
end

local function cursor_line_and_column()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  return line, (cursor[2] or 0) + 1
end

local function markdown_link_target_under_cursor(line, column)
  local offset = 1
  while offset <= #line do
    local start_index = line:find("%[", offset)
    if start_index == nil then
      return nil
    end
    local label_end = start_index + 1
    while label_end <= #line do
      local char = line:sub(label_end, label_end)
      if char == "\\" then
        label_end = label_end + 2
      elseif char == "]" then
        break
      else
        label_end = label_end + 1
      end
    end
    if label_end > #line or line:sub(label_end + 1, label_end + 1) ~= "(" then
      offset = start_index + 1
      goto continue
    end
    local target_start = label_end + 2
    local index = target_start
    local depth = 0
    local target_end = nil
    while index <= #line do
      local char = line:sub(index, index)
      if char == "\\" then
        index = index + 1
      elseif char == "(" then
        depth = depth + 1
      elseif char == ")" then
        if depth == 0 then
          target_end = index - 1
          break
        end
        depth = depth - 1
      end
      index = index + 1
    end
    if target_end ~= nil then
      if column >= start_index and column <= index then
        local target = line:sub(target_start, target_end)
        target = trim_cursor_target(target:match("^(%S+)") or target, { strip_closing = false })
        return unescape_markdown_target(target)
      end
      offset = index + 1
    else
      offset = label_end + 1
    end
    ::continue::
  end
  return nil
end

local function url_under_cursor(line, column)
  local offset = 1
  while offset <= #line do
    local start_index, end_index = line:find("%f[%S]%a[%w+.-]*://%S+", offset)
    if start_index == nil then
      return nil
    end
    if column >= start_index and column <= end_index then
      return trim_cursor_target(line:sub(start_index, end_index))
    end
    offset = end_index + 1
  end
  return nil
end

local function readable_cursor_file(value)
  value = trim_cursor_target(value)
  if value == nil then
    return nil
  end
  if vim.fn.filereadable(value) == 1 then
    return value
  end
  local expanded = vim.fn.fnamemodify(value, ":p")
  if expanded ~= nil and expanded ~= "" and vim.fn.filereadable(expanded) == 1 then
    return expanded
  end
  return nil
end

local function cfile_under_cursor()
  local ok, value = pcall(vim.fn.expand, "<cfile>")
  if not ok then
    return nil
  end
  return trim_cursor_target(value)
end

local function should_use_cfile_as_target(value)
  return value ~= nil and (value:find("%.", 1, true) ~= nil or value:find("/", 1, true) ~= nil or value:find(":", 1, true) ~= nil)
end

local function is_readable_local_target(value)
  return value ~= nil and not value:match("^%a[%w+.-]*:") and readable_cursor_file(value) ~= nil
end

local function is_raster_image_target(value)
  local extension = vim.fn.fnamemodify(value or "", ":e"):lower()
  return extension == "png" or extension == "jpg" or extension == "jpeg" or extension == "gif" or extension == "webp"
end

local function setup_preview_keymaps()
  local terminal_state = terminal.state()
  if terminal_state.bufnr ~= nil then
    keymaps.setup_buffer(M, terminal_state.bufnr, M.config.preview_keymaps or {})
  end
end

function M.inspect(target)
  target = resolve_target(target)
  state.last_target = target
  local previous_bufnr = terminal.state().bufnr
  terminal.open(backend.command_for(M.config.binary, "inspect", target, M.config))
  local current_bufnr = terminal.state().bufnr
  if previous_bufnr ~= current_bufnr then
    keymaps.clear_buffer(previous_bufnr)
  end
  setup_preview_keymaps()
end

local function open_target(target, opts)
  opts = opts or {}
  target = resolve_target(target)
  if opts.record ~= false then
    record_target(target)
  end
  local previous_bufnr = terminal.state().bufnr
  terminal.open(backend.command_for(M.config.binary, "open", target, M.config))
  local current_bufnr = terminal.state().bufnr
  if previous_bufnr ~= current_bufnr then
    keymaps.clear_buffer(previous_bufnr)
  end
  setup_preview_keymaps()
  return true
end

function M.open(target)
  return open_target(target, { record = true })
end

function M.preview()
  M.open(vim.fn.expand("%:p"))
end

local smoke_is_ready
local smoke_reader_ready
local smoke_focused_input_ready
local smoke_output_label
local smoke_report
local emit_smoke_report

function M.smoke(opts)
  opts = opts or {}
  local timeout_ms = math.max(1, math.floor(tonumber(opts.timeout_ms) or 30000))
  local interval_ms = math.max(1, math.floor(tonumber(opts.interval_ms) or 100))
  local clock = opts.clock or vim.uv or vim.loop
  local deadline = clock.now() + timeout_ms
  local last_reason = nil
  local interaction_text = opts.interaction_text or "nvim-browser interaction"
  local input_selector = "#nvim-browser-smoke-input"
  local stage = "render"
  local details = {
    interaction = false,
    focus = false,
    input = false,
    submit = false,
    reader = false,
  }

  state.smoke_target = smoke_fixture_url()
  open_target(state.smoke_target, { record = false })

  local function fail(reason)
    emit_smoke_report(smoke_report("failed", reason or last_reason or "timeout", details), opts)
  end

  local function poll()
    local ready, reason
    if stage == "render" then
      ready, reason = smoke_is_ready("nvim-browser smoke")
      if ready then
        stage = "focus"
        if not M.focus_selector(input_selector) then
          fail("focus: request failed")
          return
        end
        vim.defer_fn(poll, interval_ms)
        return
      end
      reason = "render: " .. tostring(reason)
    elseif stage == "focus" then
      ready, reason = smoke_focused_input_ready("Smoke input")
      if ready then
        details.focus = true
        stage = "input"
        if not M.input_text(interaction_text) then
          fail("input: request failed")
          return
        end
        details.input = true
        stage = "input_wait"
        vim.defer_fn(poll, interval_ms)
        return
      end
      reason = "focus: " .. tostring(reason)
    elseif stage == "input_wait" then
      local terminal_state = terminal.state()
      if terminal_state.pending_operation == nil
        and terminal_state.dom_epoch ~= nil
        and terminal_state.rendered_frame_dom_epoch ~= nil
        and terminal_state.dom_epoch == terminal_state.rendered_frame_dom_epoch
      then
        stage = "submitted"
        vim.defer_fn(poll, interval_ms)
        return
      end
      reason = "input: waiting for fresh hints"
    elseif stage == "submitted" then
      ready, reason = smoke_is_ready("nvim-browser smoke submitted: " .. interaction_text)
      if ready then
        details.submit = true
        details.interaction = true
        local terminal_state = terminal.state()
        local output = smoke_output_label(M.runtime_metadata(), terminal_state)
        local reader_options = (M.config and M.config.reader) or {}
        if output == "ANSI fallback" and reader_options.auto_open_on_ansi_fallback ~= false then
          stage = "reader"
          vim.defer_fn(poll, interval_ms)
          return
        end
        emit_smoke_report(smoke_report("ok", nil, details), opts)
        return
      end
      reason = "submit: " .. tostring(reason)
    elseif stage == "reader" then
      ready, reason = smoke_reader_ready()
      if ready then
        details.reader = true
        emit_smoke_report(smoke_report("ok", nil, details), opts)
        return
      end
      reason = "reader: " .. tostring(reason)
    else
      reason = "unknown smoke stage: " .. tostring(stage)
    end

    last_reason = reason or last_reason
    if clock.now() >= deadline then
      fail(last_reason or "timeout")
      return
    end
    vim.defer_fn(poll, interval_ms)
  end

  vim.defer_fn(poll, 1)
  return true
end

function M.calibrate(cell_width_px, cell_height_px)
  if cell_width_px ~= nil or cell_height_px ~= nil then
    local width, height, err = parse_cell_pixels(cell_width_px, cell_height_px)
    if err ~= nil then
      return false, err
    end
    state.guided_calibration = nil
    M.config.guided_calibration = nil
    apply_calibration(width, height)
  end

  M.open(calibration_fixture_path())
  local report = doctor.run(M.config, terminal.state())
  table.insert(report.lines, 2, "calibration target: " .. calibration_fixture_path())
  for index, line in ipairs(report.lines) do
    if line:find("^calibration:") or line:find("^warning: calibration") then
      report.lines[index] = "calibration: pending runtime metadata; run :NBrowserDoctor after the calibration frame renders"
      break
    end
  end
  return report
end

local function guided_calibration_line(sample)
  return "guided calibration: saved "
    .. tostring(sample.cell_width_px)
    .. "x"
    .. tostring(sample.cell_height_px)
    .. " from cursor row="
    .. tostring(sample.row)
    .. " column="
    .. tostring(sample.column)
    .. " target="
    .. tostring(sample.target_x)
    .. ","
    .. tostring(sample.target_y)
end

function M.calibrate_here()
  local sample, err = terminal.guided_calibration_at_cursor({ target_x = 405, target_y = 230 })
  if sample == false then
    return false, err
  end
  local width, height, parse_err = parse_cell_pixels(sample.cell_width_px, sample.cell_height_px)
  if parse_err ~= nil then
    return false, parse_err
  end
  sample.cell_width_px = width
  sample.cell_height_px = height
  state.guided_calibration = vim.deepcopy(sample)
  M.config.guided_calibration = vim.deepcopy(sample)
  apply_calibration(width, height)
  local report = doctor.run(M.config, terminal.state())
  table.insert(report.lines, 2, guided_calibration_line(sample))
  return report
end

function M.focus()
  return terminal.focus()
end

function M.close()
  keymaps.clear_buffer(terminal.state().bufnr)
  terminal.close()
end

function M.refresh()
  return terminal.refresh()
end

function M.reload()
  return terminal.reload()
end

function M.stop()
  return terminal.stop()
end

function M.navigate(target)
  if target == nil or target == "" then
    return false
  end
  local ok = terminal.navigate(target)
  if ok then
    set_last_target(target)
  end
  return ok
end

function M.resolve_address_target(input)
  return address.resolve(input, M.config.search_url or config.options.search_url)
end

function M.resolve_cursor_target()
  local line, column = cursor_line_and_column()
  local target = markdown_link_target_under_cursor(line, column)
  if target ~= nil then
    return target
  end
  target = url_under_cursor(line, column)
  if target ~= nil then
    return target
  end
  local cfile = cfile_under_cursor()
  target = readable_cursor_file(cfile)
  if target ~= nil then
    return target
  end
  if should_use_cfile_as_target(cfile) then
    return cfile
  end
  return trim_cursor_target(line)
end

function M.open_under_cursor()
  local target = M.resolve_cursor_target()
  if target == nil then
    return false
  end
  local local_file_target = is_readable_local_target(target)
  if not local_file_target then
    target = M.resolve_address_target(target)
  end
  if target == nil then
    return false
  end
  if has_active_browser_session() then
    if local_file_target and is_raster_image_target(target) then
      return M.open(target) ~= false
    end
    if local_file_target then
      target = vim.uri_from_fname(target)
    end
    return M.navigate(target)
  end
  return M.open(target) ~= false
end

function M.address(input, opts)
  opts = opts or {}
  local value = input
  if type(input) ~= "string" then
    input = input or vim.fn.input
    value = input("nvim-browser address: ", M.current_url() or M.last_target() or "")
  end
  local target = M.resolve_address_target(value)
  if target == nil then
    return false
  end
  local is_active = opts.is_active
  if is_active == nil then
    is_active = has_active_browser_session()
  end
  if is_active then
    return M.navigate(target)
  end
  local ok = M.open(target)
  return ok ~= false
end

function M.record_history(url, title)
  return record_target(url, title)
end

function M.clear_history()
  state.history = {}
  save_session()
end

function M.history()
  local entries = {}
  for index, entry in ipairs(state.history) do
    entries[index] = { url = entry.url, title = entry.title }
  end
  return entries
end

function M.history_urls()
  local urls = {}
  for _, entry in ipairs(state.history) do
    table.insert(urls, entry.url)
  end
  return urls
end

local function history_picker_label(entry)
  if type(entry) ~= "table" then
    return ""
  end
  if entry.title ~= nil and entry.title ~= "" then
    return entry.title .. " -> " .. entry.url
  end
  return entry.url or ""
end

function M.clear_bookmarks()
  state.bookmarks = {}
  save_session()
end

function M.bookmarks()
  local entries = {}
  for index, entry in ipairs(state.bookmarks) do
    entries[index] = { url = entry.url, title = entry.title }
  end
  return entries
end

function M.bookmark_current()
  local url = normalize_history_value(M.current_url())
  if url == nil then
    return false
  end
  if add_bookmark_entry(url, M.current_title()) then
    save_session()
    return true
  end
  return false
end

local function bookmark_picker_label(entry)
  if type(entry) ~= "table" then
    return ""
  end
  if entry.title ~= nil and entry.title ~= "" then
    return entry.title .. " -> " .. entry.url
  end
  return entry.url or ""
end

function M.pick_bookmark(select_or_opts, maybe_opts)
  local select = vim.ui.select
  local opts = maybe_opts or {}
  if type(select_or_opts) == "function" then
    select = select_or_opts
  elseif type(select_or_opts) == "table" then
    opts = select_or_opts
    if type(opts.select) == "function" then
      select = opts.select
    end
  end

  local entries = M.bookmarks()
  if #entries == 0 then
    return false
  end
  local completed = false
  local selected = nil
  local action_ok = true
  select(entries, {
    prompt = opts.prompt or "nvim-browser bookmarks: ",
    format_item = opts.format_item or bookmark_picker_label,
  }, function(choice)
    completed = true
    selected = choice
    if choice == nil then
      return
    end
    action_ok = M.address(choice.url) ~= false
    if not action_ok and type(opts.on_error) == "function" then
      opts.on_error("action_failed")
    end
  end)
  if completed and selected == nil then
    return false
  end
  if completed and not action_ok then
    return false
  end
  return true
end

function M.pick_history(select_or_opts, maybe_opts)
  local select = vim.ui.select
  local opts = maybe_opts or {}
  if type(select_or_opts) == "function" then
    select = select_or_opts
  elseif type(select_or_opts) == "table" then
    opts = select_or_opts
    if type(opts.select) == "function" then
      select = opts.select
    end
  end

  local entries = M.history()
  if #entries == 0 then
    return false
  end
  local completed = false
  local selected = nil
  local action_ok = true
  select(entries, {
    prompt = opts.prompt or "nvim-browser history: ",
    format_item = opts.format_item or history_picker_label,
  }, function(choice)
    completed = true
    selected = choice
    if choice == nil then
      return
    end
    action_ok = M.address(choice.url) ~= false
    if not action_ok and type(opts.on_error) == "function" then
      opts.on_error("action_failed")
    end
  end)
  if completed and selected == nil then
    return false
  end
  if completed and not action_ok then
    return false
  end
  return true
end

function M.resume()
  local target = nil
  if has_active_browser_session() then
    target = normalize_history_value(M.current_url())
  end
  target = target or normalize_history_value(state.last_target)
  if target == nil and #state.history > 0 then
    target = normalize_history_value(state.history[1].url)
  end
  if target == nil then
    return false
  end
  return M.open(target) ~= false
end

local function action_picker_label(item)
  return type(item) == "table" and item.label or ""
end

local function action_echo(message)
  vim.api.nvim_echo({ { tostring(message or "") } }, false, {})
end

local function report_action_error(opts, reason)
  if type(opts.on_error) == "function" then
    opts.on_error(reason)
    return
  end
  vim.api.nvim_echo({ { "nvim-browser: selected browser action failed or browser session is inactive", "WarningMsg" } }, false, {})
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
  local output = status_labels.runtime_output_label(runtime.output, runtime.output_label)
  if output ~= nil then
    table.insert(parts, "output=" .. output)
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

smoke_output_label = function(runtime, terminal_state)
  runtime = type(runtime) == "table" and runtime or {}
  terminal_state = type(terminal_state) == "table" and terminal_state or {}
  return status_labels.runtime_output_label(runtime.output, runtime.output_label)
    or terminal_state.serve_output_label
    or terminal_state.serve_output
    or "unknown"
end

smoke_report = function(status, reason, details)
  details = type(details) == "table" and details or {}
  local terminal_state = terminal.state()
  local runtime = M.runtime_metadata()
  local health = M.frame_health()
  local output = smoke_output_label(runtime, terminal_state)
  local lines = {
    "nvim-browser smoke",
    "status: " .. status,
    "output: " .. output,
  }
  if type(runtime) == "table" then
    local runtime_label = runtime_status_label(runtime)
    if runtime_label ~= nil then
      table.insert(lines, "runtime: " .. runtime_label)
    end
  end
  if terminal_state.rendered_frame_geometry ~= nil then
    local geometry = terminal_state.rendered_frame_geometry
    table.insert(lines, "frame: " .. tostring(geometry.width or "?") .. "x" .. tostring(geometry.height or "?"))
  end
  if type(health) == "table" then
    if health.stale == false and health.refresh_pending == false then
      table.insert(lines, "frame health: ok")
    else
      table.insert(
        lines,
        "frame health: stale=" .. tostring(health.stale) .. " refreshing=" .. tostring(health.refresh_pending)
      )
    end
  end
  if details.interaction == true then
    table.insert(lines, "interaction: ok")
  end
  if details.focus == true then
    table.insert(lines, "focus: ok")
  end
  if details.input == true then
    table.insert(lines, "input: ok")
  end
  if details.submit == true then
    table.insert(lines, "submit: ok")
  end
  if details.reader == true then
    table.insert(lines, "reader: ok")
  end
  if (output == "kitty" or output == "kitty-unicode") and tonumber(terminal_state.terminal_graphics_egress_count) ~= nil then
    if tonumber(terminal_state.terminal_graphics_egress_count) > 0 then
      table.insert(lines, "terminal graphics: ok")
    else
      table.insert(lines, "terminal graphics: none")
    end
  end
  if reason ~= nil and reason ~= "" then
    table.insert(lines, "reason: " .. tostring(reason))
  end
  if output == "ANSI fallback" then
    table.insert(lines, "zellij: ANSI fallback active")
  end
  return {
    ok = status == "ok",
    status = status,
    output = output,
    reason = reason,
    details = details,
    lines = lines,
  }
end

smoke_is_ready = function(expected_title)
  local terminal_state = terminal.state()
  local runtime = M.runtime_metadata()
  local health = M.frame_health()
  local target = state.smoke_target or smoke_fixture_url()
  expected_title = expected_title or "nvim-browser smoke"
  if terminal_state.pending_operation ~= nil then
    return false, "operation pending"
  end
  if terminal_state.current_url ~= target then
    return false, "url=" .. tostring(terminal_state.current_url)
  end
  if terminal_state.rendered_frame_url ~= nil and terminal_state.rendered_frame_url ~= target then
    return false, "frame url=" .. tostring(terminal_state.rendered_frame_url)
  end
  if M.status() ~= "ok" then
    return false, "status=" .. tostring(M.status())
  end
  if M.current_title() ~= expected_title then
    return false, "title=" .. tostring(M.current_title())
  end
  if type(runtime) ~= "table" then
    return false, "missing runtime metadata"
  end
  if terminal_state.rendered_frame_geometry == nil then
    return false, "missing rendered frame"
  end
  if type(health) ~= "table" then
    return false, "missing frame health"
  end
  if health.stale ~= false or health.refresh_pending ~= false then
    return false, "frame not healthy"
  end
  return true, nil
end

local function smoke_reader_buffer_text(bufnr)
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end
  local ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, 0, -1, false)
  if not ok then
    return nil
  end
  return table.concat(lines, "\n")
end

smoke_reader_ready = function()
  local terminal_state = terminal.state()
  local bufnr = terminal_state.reader_bufnr
  local text = smoke_reader_buffer_text(bufnr)
  if text == nil then
    return false, "missing reader buffer"
  end
  if text:find("nvim%-browser smoke") == nil and text:find("deterministic local browser runtime fixture", 1, true) == nil then
    return false, "reader missing smoke fixture text"
  end
  if terminal_state.winid ~= nil and not vim.api.nvim_win_is_valid(terminal_state.winid) then
    return false, "preview window invalid"
  end
  return true, nil
end

smoke_focused_input_ready = function(expected_label)
  local focused = M.focused_element()
  if type(focused) ~= "table" then
    return false, "missing focused element"
  end
  if focused.kind ~= "input" and focused.kind ~= "textarea" then
    return false, "kind=" .. tostring(focused.kind)
  end
  if focused.label ~= expected_label then
    return false, "label=" .. tostring(focused.label)
  end
  return true, nil
end

emit_smoke_report = function(report, opts)
  if opts ~= nil and type(opts.on_report) == "function" then
    opts.on_report(report)
    return
  end
  local highlight = report.ok and "None" or "WarningMsg"
  vim.api.nvim_echo({ { table.concat(report.lines or {}, "\n"), highlight } }, false, {})
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

local function dialog_status_label(dialog)
  if type(dialog) ~= "table" then
    return nil
  end
  local kind = dialog.kind ~= nil and dialog.kind ~= vim.NIL and tostring(dialog.kind) or nil
  local action = dialog.action ~= nil and dialog.action ~= vim.NIL and tostring(dialog.action) or nil
  if kind == nil or kind == "" or action == nil or action == "" then
    return nil
  end
  local label = "dialog=" .. kind .. " " .. action
  local message = dialog.message ~= nil and dialog.message ~= vim.NIL and tostring(dialog.message) or nil
  if message ~= nil then
    message = message:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if message ~= "" then
      label = label .. ": " .. message
    end
  end
  return label
end

local function browser_history_status_label(history)
  if type(history) ~= "table" then
    return nil
  end
  local available = {}
  if history.can_go_back == true then
    table.insert(available, "back")
  end
  if history.can_go_forward == true then
    table.insert(available, "forward")
  end
  if #available == 0 then
    return "history=none"
  end
  return "history=" .. table.concat(available, ",")
end

local function action_status_message()
  local parts = { M.status() or "unknown" }
  local title = M.current_title()
  if title ~= nil and title ~= "" then
    table.insert(parts, title)
  end
  local scroll = M.page_metrics and page_scroll_label(M.page_metrics()) or nil
  if scroll ~= nil then
    table.insert(parts, scroll)
  end
  local history = M.browser_history and browser_history_status_label(M.browser_history()) or nil
  if history ~= nil then
    table.insert(parts, history)
  end
  local zoom = M.zoom_scale and status_labels.zoom_label(M.zoom_scale()) or nil
  if zoom ~= nil then
    table.insert(parts, zoom)
  end
  local focused = M.focused_element and status_labels.focused_element_label(M.focused_element()) or nil
  if focused ~= nil then
    table.insert(parts, focused)
  end
  local download = M.latest_download and download_status_label(M.latest_download()) or nil
  if download ~= nil then
    table.insert(parts, download)
  end
  local dialog = M.latest_dialog and dialog_status_label(M.latest_dialog()) or nil
  if dialog ~= nil then
    table.insert(parts, dialog)
  end
  local runtime = M.runtime_metadata and runtime_status_label(M.runtime_metadata()) or nil
  if runtime ~= nil then
    table.insert(parts, runtime)
  end
  local frame = M.frame_health and status_labels.frame_health_label(M.frame_health()) or nil
  if frame ~= nil then
    table.insert(parts, frame)
  end
  local url = M.current_url()
  if url ~= nil and url ~= "" then
    table.insert(parts, url)
  end
  local error = M.status_error()
  if error ~= nil and error ~= "" then
    table.insert(parts, error)
  end
  return table.concat(parts, " ")
end

local function current_buffer_target()
  local buffer_name = vim.api.nvim_buf_get_name(0)
  if buffer_name:match("^nvim%-browser://") then
    return M.current_url() or M.last_target()
  end
  local target = vim.fn.expand("%:p")
  if target == nil or target == "" then
    target = vim.fn.expand("%")
  end
  return target
end

local function resume_available()
  if M.last_target() ~= nil then
    return true
  end
  local history = M.history()
  return type(history) == "table" and history[1] ~= nil and history[1].url ~= nil
end

local function action_items(opts, report_error)
  local items = {
    {
      label = "Open current buffer",
      run = function()
        return M.open(current_buffer_target())
      end,
    },
    {
      label = "Preview current buffer",
      run = function()
        return M.preview()
      end,
    },
    {
      label = "Inspect current buffer",
      run = function()
        return M.inspect(current_buffer_target())
      end,
    },
  }

  if resume_available() then
    table.insert(items, {
      label = "Resume",
      run = function()
        return M.resume()
      end,
    })
  end

  if normalize_history_value(M.current_url()) ~= nil then
    table.insert(items, {
      label = "Bookmark page",
      run = function()
        return M.bookmark_current()
      end,
    })
  end

  if #M.bookmarks() > 0 then
    table.insert(items, {
      label = "Bookmarks",
      run = function()
        return M.pick_bookmark({
          select = opts.select,
          on_error = report_error,
        })
      end,
    })
  end

  vim.list_extend(items, {
    {
      label = "Address",
      run = function()
        local value = (opts.input or vim.fn.input)("nvim-browser address: ", M.current_url() or M.last_target() or "")
        if value == nil or value == "" then
          return true
        end
        return M.address(value)
      end,
    },
    {
      label = "Reload",
      run = function()
        return M.reload()
      end,
    },
    {
      label = "Back",
      run = function()
        return M.back()
      end,
    },
    {
      label = "Forward",
      run = function()
        return M.forward()
      end,
    },
    {
      label = "Find",
      run = function()
        local text = (opts.input or vim.fn.input)("nvim-browser find: ")
        if text == nil or text == "" then
          return true
        end
        return M.find_text(text, { backwards = false })
      end,
    },
    {
      label = "Hints",
      run = function()
        if M.pick_hint ~= nil then
          local hint_error_reported = false
          local hint_canceled = false
          local function report_hint_error(reason)
            hint_error_reported = true
            report_error(reason)
          end
          local function report_hint_cancel()
            hint_canceled = true
          end
          local ok = M.pick_hint({
            select = opts.select,
            input = opts.input,
            on_error = report_hint_error,
            on_cancel = report_hint_cancel,
          }) ~= false
          return ok or (hint_canceled and not hint_error_reported)
        end
        return M.hint_mode(opts.input)
      end,
    },
    {
      label = "Text mode",
      reports_own_error = true,
      run = function()
        return M.start_text_mode()
      end,
    },
    {
      label = "Click cursor",
      run = function()
        return M.click_here()
      end,
    },
    {
      label = "Double-click cursor",
      run = function()
        return M.double_click_here()
      end,
    },
    {
      label = "Right-click cursor",
      run = function()
        return M.right_click_here()
      end,
    },
    {
      label = "Hover cursor",
      run = function()
        return M.hover_here()
      end,
    },
    {
      label = "Wheel down at cursor",
      run = function()
        return M.wheel_here(120, 0)
      end,
    },
    {
      label = "Wheel up at cursor",
      run = function()
        return M.wheel_here(-120, 0)
      end,
    },
    {
      label = "Type at cursor",
      run = function()
        local text = (opts.input or vim.fn.input)("nvim-browser type at cursor: ")
        if text == nil or text == "" then
          return true
        end
        return M.type_here(text)
      end,
    },
    {
      label = "Submit focused",
      run = function()
        return M.submit_focused()
      end,
    },
    {
      label = "Open download",
      run = function()
        local ok = M.open_download(nil, {
          select = opts.select,
          on_error = report_error,
        })
        return ok ~= false
      end,
    },
    {
      label = "Screenshot",
      run = function()
        local saved_path = nil
        local pending_response = nil
        local function handle_response(response)
          if saved_path == nil then
            pending_response = response
            return
          end
          if type(response) == "table" and response.status == "ok" then
            action_echo("nvim-browser: screenshot saved: " .. tostring(saved_path))
          end
        end
        local ok, path = M.screenshot(nil, {
          on_response = handle_response,
        })
        saved_path = path
        if pending_response ~= nil then
          handle_response(pending_response)
        end
        return ok == true
      end,
    },
    {
      label = "Reader",
      run = function()
        return M.reader()
      end,
    },
    {
      label = "Status",
      run = function()
        local status = action_status_message()
        if type(opts.on_status) == "function" then
          opts.on_status(status)
        else
          action_echo(status)
        end
        return true
      end,
    },
    {
      label = "Zoom in",
      run = function()
        return M.zoom_in()
      end,
    },
    {
      label = "Zoom out",
      run = function()
        return M.zoom_out()
      end,
    },
    {
      label = "Zoom reset",
      run = function()
        return M.zoom_reset()
      end,
    },
    {
      label = "Doctor",
      run = function()
        local report = M.doctor()
        if type(opts.on_report) == "function" then
          opts.on_report(report)
        elseif report ~= nil then
          action_echo(table.concat(report.lines or {}, "\n"))
        end
        return report ~= nil
      end,
    },
    {
      label = "Close",
      run = function()
        M.close()
        return true
      end,
    },
  })

  return items
end

function M.actions(select_or_opts, maybe_opts)
  local select = vim.ui.select
  local opts = maybe_opts or {}
  if type(select_or_opts) == "function" then
    select = select_or_opts
  elseif type(select_or_opts) == "table" then
    opts = select_or_opts
    if type(opts.select) == "function" then
      select = opts.select
    end
  end

  local action_error_reported = false
  local function report_error_once(reason)
    if action_error_reported then
      return
    end
    action_error_reported = true
    report_action_error(opts, reason)
  end
  local items = action_items(opts, report_error_once)
  local completed = false
  local selected = nil
  local action_ok = true
  select(items, {
    prompt = opts.prompt or "nvim-browser action: ",
    format_item = opts.format_item or action_picker_label,
  }, function(choice)
    completed = true
    selected = choice
    if choice == nil then
      return
    end
    action_ok = choice.run() ~= false
    if not action_ok and not choice.reports_own_error then
      report_error_once("action_failed")
    end
  end)

  if completed and selected == nil then
    return true
  end
  if completed and not action_ok then
    return false
  end
  return true
end

function M.back()
  return terminal.back()
end

function M.forward()
  return terminal.forward()
end

function M.scroll(delta_y, delta_x)
  return terminal.scroll(delta_y, delta_x)
end

function M.page_scroll(direction)
  return terminal.page_scroll(direction)
end

function M.page_down()
  return terminal.page_scroll(1)
end

function M.page_up()
  return terminal.page_scroll(-1)
end

function M.scroll_top()
  return terminal.scroll_top()
end

function M.scroll_bottom()
  return terminal.scroll_bottom()
end

function M.half_page_down()
  return terminal.page_scroll(1, { fraction = 0.5 })
end

function M.half_page_up()
  return terminal.page_scroll(-1, { fraction = 0.5 })
end

function M.zoom_in()
  return terminal.zoom_in()
end

function M.zoom(scale)
  return terminal.zoom(scale)
end

function M.zoom_out()
  return terminal.zoom_out()
end

function M.zoom_reset()
  return terminal.zoom_reset()
end

function M.zoom_scale()
  return terminal.state().zoom_scale or 1.0
end

function M.input_text(text)
  return terminal.input_text(text)
end

function M.paste_register(register)
  register = register or '"'
  if type(register) ~= "string" or #register ~= 1 then
    return false
  end
  local ok, text = pcall(vim.fn.getreg, register)
  if not ok or text == nil or text == "" then
    return false
  end
  return M.input_text(text)
end

function M.yank_selection(register)
  return terminal.yank_selection(register or '"')
end

function M.yank_page_text(register)
  return terminal.yank_page_text(register or '"')
end

function M.yank_region(register, start_row, start_col, end_row, end_col)
  if start_row == nil and start_col == nil and end_row == nil and end_col == nil then
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    start_row = start_pos[2]
    end_row = end_pos[2]
    start_col = vim.fn.virtcol("'<")
    end_col = vim.fn.virtcol("'>")
  end
  return terminal.yank_region(register or '"', start_row, start_col, end_row, end_col)
end

function M.yank_current_url(register)
  return terminal.yank_current_url(register or '"')
end

function M.yank_hint_url(id, register)
  return terminal.yank_hint_url(id, register or '"')
end

local function screenshot_slug(value)
  value = value ~= nil and tostring(value) or ""
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  value = value:gsub("[^%w%-_%.]+", "-")
  value = value:gsub("%-+", "-")
  value = value:gsub("^%-+", ""):gsub("%-+$", "")
  if value == "" then
    return "browser"
  end
  return value:sub(1, 80)
end

local screenshot_name_sequences = {}

local function screenshot_default_path(opts)
  opts = opts or {}
  local stdpath = opts.stdpath or vim.fn.stdpath
  local timestamp = opts.timestamp or function()
    return os.date("%Y%m%d-%H%M%S")
  end
  local base = stdpath("cache") .. "/nvim-browser/screenshots"
  local title = M.current_title()
  local url = M.current_url()
  local name_source = title ~= nil and title ~= "" and title or url ~= nil and url ~= "" and url or "browser"
  local name_key = screenshot_slug(name_source) .. "-" .. timestamp()
  local screenshot_name_sequence = (screenshot_name_sequences[name_key] or 0) + 1
  screenshot_name_sequences[name_key] = screenshot_name_sequence
  local suffix = screenshot_name_sequence > 1 and "-" .. tostring(screenshot_name_sequence) or ""
  return base .. "/" .. name_key .. suffix .. ".png"
end

local function screenshot_prepare_directory(path, opts)
  opts = opts or {}
  local mkdir = opts.mkdir or vim.fn.mkdir
  local directory = vim.fn.fnamemodify(path, ":h")
  if directory == nil or directory == "" or directory == "." then
    return true
  end
  local ok, result = pcall(mkdir, directory, "p")
  return ok and result ~= 0
end

function M.screenshot(path, opts)
  opts = opts or {}
  if path == "" then
    return false, nil
  end
  path = path or screenshot_default_path(opts)
  if not screenshot_prepare_directory(path, opts) then
    return false, path
  end
  return terminal.screenshot(path, opts) == true, path
end

function M.input_text_mode(input)
  input = input or vim.fn.input
  local text = input("nvim-browser text: ")
  if text == nil or text == "" then
    return false
  end
  return M.input_text(text)
end

function M.start_text_mode(opts)
  return terminal.start_text_mode(opts)
end

function M.press_key(key, opts)
  return terminal.press_key(key, opts)
end

function M.submit_focused()
  return terminal.submit_focused()
end

function M.focus_selector(selector)
  return terminal.focus_selector(selector)
end

function M.click_point(x, y, opts)
  return terminal.click_point(x, y, opts)
end

function M.drag_point(start_x, start_y, end_x, end_y)
  return terminal.drag_point(start_x, start_y, end_x, end_y)
end

function M.select_region(start_row, start_col, end_row, end_col)
  return terminal.select_region(start_row, start_col, end_row, end_col)
end

function M.right_click_point(x, y)
  return terminal.right_click_point(x, y)
end

function M.hover_point(x, y)
  return terminal.hover_point(x, y)
end

function M.wheel_point(x, y, delta_y, delta_x)
  return terminal.wheel_point(x, y, delta_y, delta_x)
end

function M.type_point(x, y, text, opts)
  return terminal.type_point(x, y, text, opts)
end

function M.find_text(query, opts)
  return terminal.find_text(query, opts)
end

function M.find_next()
  return terminal.find_next()
end

function M.find_previous()
  return terminal.find_previous()
end

function M.reader()
  return terminal.reader()
end

function M.reader_follow()
  local target = terminal.reader_follow()
  if target == false or target == nil then
    return false
  end
  set_last_target(target)
  return true
end

function M.click_here()
  return terminal.click_here()
end

function M.double_click_here()
  return terminal.double_click_here()
end

function M.right_click_here()
  return terminal.right_click_here()
end

function M.hover_here()
  return terminal.hover_here()
end

function M.wheel_here(delta_y, delta_x)
  return terminal.wheel_here(delta_y, delta_x)
end

function M.type_here(text, opts)
  return terminal.type_here(text, opts)
end

function M.click_mouse(mousepos)
  return terminal.click_mouse(mousepos)
end

function M.double_click_mouse(mousepos)
  return terminal.double_click_mouse(mousepos)
end

function M.right_click_mouse(mousepos)
  return terminal.right_click_mouse(mousepos)
end

function M.wheel_mouse(delta_y, delta_x, mousepos)
  return terminal.wheel_mouse(delta_y, delta_x, mousepos)
end

function M.click_hint(id)
  return terminal.click_hint(id)
end

function M.right_click_hint(id)
  return terminal.right_click_hint(id)
end

function M.hover_hint(id)
  return terminal.hover_hint(id)
end

function M.focus_hint(id)
  return terminal.focus_hint(id)
end

function M.follow_hint(id)
  return terminal.follow_hint(id)
end

local function hint_identifier(hint)
  if type(hint) ~= "table" then
    return nil
  end
  if hint.hint_label ~= nil and hint.hint_label ~= "" then
    return tostring(hint.hint_label)
  end
  if hint.id ~= nil then
    return tostring(hint.id)
  end
  return nil
end

local function hint_picker_label(hint)
  if type(hint) ~= "table" then
    return ""
  end
  local parts = { hint_identifier(hint) or "?", tostring(hint.kind or "other") }
  local label = hint.label ~= nil and tostring(hint.label) or ""
  if hint.checked ~= nil then
    label = string.format("[%s] %s", hint.checked and "checked" or "unchecked", label)
  end
  if label ~= "" then
    table.insert(parts, label)
  end
  if hint.href ~= nil and hint.href ~= "" then
    table.insert(parts, "-> " .. tostring(hint.href))
  end
  if hint.x ~= nil and hint.y ~= nil then
    table.insert(parts, string.format("@ %.0f,%.0f", hint.x or 0, hint.y or 0))
  end
  return table.concat(parts, " ")
end

local function select_option_picker_label(option)
  if type(option) ~= "table" then
    return ""
  end
  local label = option.label ~= nil and tostring(option.label) or ""
  local value = option.value ~= nil and tostring(option.value) or ""
  local parts = {}
  if option.selected == true then
    table.insert(parts, "[selected]")
  end
  if label ~= "" then
    table.insert(parts, label)
  end
  if value ~= "" and value ~= label then
    table.insert(parts, "(" .. value .. ")")
  end
  return table.concat(parts, " ")
end

local function select_option_choice(option)
  if type(option) ~= "table" then
    return nil
  end
  local value = option.value ~= nil and tostring(option.value) or ""
  if value ~= "" then
    return value
  end
  local label = option.label ~= nil and tostring(option.label) or ""
  if label ~= "" then
    return label
  end
  return nil
end

local function select_hints_with_options(hints)
  local selectable = {}
  for _, hint in ipairs(hints) do
    if type(hint) == "table" and type(hint.options) == "table" and #hint.options > 0 then
      table.insert(selectable, hint)
    end
  end
  return selectable
end

local function enabled_select_options(hint)
  local enabled = {}
  if type(hint) ~= "table" or type(hint.options) ~= "table" then
    return enabled
  end
  for _, option in ipairs(hint.options) do
    if type(option) == "table" and option.disabled ~= true then
      table.insert(enabled, option)
    end
  end
  return enabled
end

local function select_hints_with_enabled_options(hints)
  local selectable = {}
  for _, hint in ipairs(hints) do
    if #enabled_select_options(hint) > 0 then
      table.insert(selectable, hint)
    end
  end
  return selectable
end

local function input_like_hints(hints)
  local inputs = {}
  for _, hint in ipairs(hints) do
    if type(hint) == "table" and (hint.kind == "input" or hint.kind == "text_area" or hint.kind == "editable") then
      table.insert(inputs, hint)
    end
  end
  return inputs
end

local function upload_like_hints(hints)
  local uploads = {}
  for _, hint in ipairs(hints) do
    if type(hint) == "table" and hint.kind == "file" then
      table.insert(uploads, hint)
    end
  end
  return uploads
end

local function href_hints(hints)
  local links = {}
  for _, hint in ipairs(hints) do
    if type(hint) == "table" and hint.href ~= nil and hint.href ~= "" then
      table.insert(links, hint)
    end
  end
  return links
end

local function pick_hint_action(action)
  if action == nil or action == "" or action == "follow" then
    return M.follow_hint
  end
  if action == "click" then
    return M.click_hint
  end
  if action == "right-click" then
    return M.right_click_hint
  end
  if action == "focus" then
    return M.focus_hint
  end
  if action == "hover" then
    return M.hover_hint
  end
  if action == "toggle" then
    return M.toggle_hint
  end
  if action == "type" or action == "submit" then
    return M.type_hint
  end
  if action == "select" then
    return M.select_hint
  end
  if action == "upload" then
    return M.upload_hint
  end
  if action == "yank-url" then
    return M.yank_hint_url
  end
  return nil
end

function M.pick_hint_action_available(action)
  return pick_hint_action(action) ~= nil
end

function M.pick_hint(select_or_opts, maybe_opts)
  local select = vim.ui.select
  local opts = maybe_opts or {}
  if type(select_or_opts) == "function" then
    select = select_or_opts
  elseif type(select_or_opts) == "table" then
    opts = select_or_opts
    if type(opts.select) == "function" then
      select = opts.select
    end
  end

  local hints = M.hints()
  if #hints == 0 then
    return false
  end
  local action_name = opts.action or "follow"
  local action = pick_hint_action(action_name)
  if action == nil then
    return false
  end
  if action_name == "type" or action_name == "submit" then
    hints = input_like_hints(hints)
    if #hints == 0 then
      return false
    end
  elseif action_name == "select" then
    hints = select_hints_with_enabled_options(hints)
    if #hints == 0 then
      return false
    end
  elseif action_name == "upload" then
    hints = upload_like_hints(hints)
    if #hints == 0 then
      return false
    end
  elseif action_name == "yank-url" then
    hints = href_hints(hints)
    if #hints == 0 then
      return false
    end
  end

  local selected = nil
  local completed = false
  local action_ok = true
  local error_reported = false
  local input = opts.input or vim.fn.input
  local function report_error(reason)
    if not error_reported and type(opts.on_error) == "function" then
      error_reported = true
      opts.on_error(reason)
    end
  end
  select(hints, {
    prompt = opts.prompt or "nvim-browser hint: ",
    format_item = opts.format_item or hint_picker_label,
  }, function(choice)
    completed = true
    selected = choice
    if choice == nil then
      return
    end
    local identifier = hint_identifier(choice)
    if identifier ~= nil then
      if action_name == "type" or action_name == "submit" then
        local text = input("nvim-browser text: ")
        if text == nil or text == "" then
          return
        end
        action_ok = action(identifier, text, { submit = action_name == "submit" }) ~= false
      elseif action_name == "select" then
        local options = enabled_select_options(choice)
        if #options == 0 then
          action_ok = false
          report_error("no_enabled_options")
          return
        end
        select(options, {
          prompt = "nvim-browser option: ",
          format_item = select_option_picker_label,
        }, function(option)
          if option == nil then
            return
          end
          local option_choice = select_option_choice(option)
          if option_choice == nil then
            action_ok = false
            report_error("missing_identifier")
            return
          end
          action_ok = action(identifier, option_choice) ~= false
          if not action_ok then
            report_error("action_failed")
          end
        end)
      elseif action_name == "upload" then
        local path = input("nvim-browser file: ")
        if path == nil or path == "" then
          return
        end
        action_ok = action(identifier, { path }) ~= false
      elseif action_name == "yank-url" then
        action_ok = action(identifier, opts.register or '"') ~= false
      else
        action_ok = action(identifier) ~= false
      end
      if not action_ok then
        report_error("action_failed")
      end
    else
      report_error("missing_identifier")
    end
  end)

  if completed and selected == nil then
    if type(opts.on_cancel) == "function" then
      opts.on_cancel()
    end
    return false
  end
  if completed and not action_ok then
    return false
  end
  return true
end

function M.type_hint(id, text, opts)
  return terminal.type_hint(id, text, opts)
end

function M.select_hint(id, choice)
  return terminal.select_hint(id, choice)
end

function M.upload_hint(id, paths)
  if type(paths) == "string" then
    paths = { paths }
  end
  return terminal.upload_hint(id, paths)
end

function M.toggle_hint(id)
  return terminal.toggle_hint(id)
end

function M.hint_mode(input)
  input = input or vim.fn.input
  if #M.hints() == 0 then
    return false
  end
  local label = input("nvim-browser hint: ")
  if label == nil or label == "" then
    return false
  end
  return M.follow_hint(label)
end

local function hint_mode_match(hints, prefix)
  local exact = nil
  local prefixed = 0
  for _, hint in ipairs(hints) do
    local label = hint.hint_label ~= nil and tostring(hint.hint_label):lower() or nil
    if label ~= nil then
      if label == prefix then
        exact = label
      end
      if label:sub(1, #prefix) == prefix then
        prefixed = prefixed + 1
      end
    end
  end
  return exact, prefixed
end

function M.transient_hint_mode(opts)
  opts = opts or {}
  local hints = M.hints()
  if #hints == 0 then
    return false
  end

  local getcharstr = opts.getcharstr or vim.fn.getcharstr
  local prefix = ""
  while true do
    local key = getcharstr()
    if key == nil or key == "" then
      return false
    end
    if key == "\27" or key == vim.keycode("<Esc>") then
      return false
    end
    prefix = prefix .. key:lower()

    local exact, prefixed = hint_mode_match(hints, prefix)
    if prefixed == 0 then
      return false
    end
    if exact ~= nil and prefixed == 1 then
      return M.follow_hint(exact)
    end
  end
end

function M.type_hint_mode(input, opts)
  input = input or vim.fn.input
  opts = opts or {}
  if #M.hints() == 0 then
    return false
  end
  local label = input("nvim-browser hint: ")
  if label == nil or label == "" then
    return false
  end
  local text = input("nvim-browser text: ")
  if text == nil or text == "" then
    return false
  end
  return M.type_hint(label, text, { submit = opts.submit == true })
end

function M.select_hint_mode(input_or_opts, maybe_opts)
  local input = vim.fn.input
  local select = vim.ui.select
  local opts = maybe_opts or {}
  if type(input_or_opts) == "function" then
    input = input_or_opts
  elseif type(input_or_opts) == "table" then
    opts = input_or_opts
  elseif input_or_opts ~= nil then
    input = input_or_opts
  end
  if type(opts.input) == "function" then
    input = opts.input
  end
  if type(opts.select) == "function" then
    select = opts.select
  end

  local hints = M.hints()
  if #hints == 0 then
    return false
  end

  local selectable = select_hints_with_options(hints)
  if #selectable > 0 then
    local selected_hint = nil
    local selected_option = nil
    local completed_hint = false
    local completed_option = false
    local action_ok = true
    select(selectable, {
      prompt = "nvim-browser hint: ",
      format_item = hint_picker_label,
    }, function(hint)
      completed_hint = true
      selected_hint = hint
      if hint == nil then
        return
      end
      local options = enabled_select_options(hint)
      if #options == 0 then
        action_ok = false
        if type(opts.on_error) == "function" then
          opts.on_error("no_enabled_options")
        end
        return
      end
      select(options, {
        prompt = "nvim-browser option: ",
        format_item = select_option_picker_label,
      }, function(option)
        completed_option = true
        selected_option = option
        if option == nil then
          return
        end
        local identifier = hint_identifier(hint)
        local choice = select_option_choice(option)
        if identifier == nil or choice == nil then
          action_ok = false
          if type(opts.on_error) == "function" then
            opts.on_error("missing_identifier")
          end
          return
        end
        action_ok = M.select_hint(identifier, choice) ~= false
        if not action_ok and type(opts.on_error) == "function" then
          opts.on_error("action_failed")
        end
      end)
    end)

    if completed_hint and selected_hint == nil then
      return false
    end
    if completed_option and selected_option == nil then
      return false
    end
    if (completed_hint or completed_option) and not action_ok then
      return false
    end
    return true
  end

  local label = input("nvim-browser hint: ")
  if label == nil or label == "" then
    return false
  end
  local choice = input("nvim-browser option: ")
  if choice == nil or choice == "" then
    return false
  end
  local ok = M.select_hint(label, choice)
  if not ok and type(opts.on_error) == "function" then
    opts.on_error("action_failed")
  end
  return ok
end

function M.focus_hint_mode(input)
  input = input or vim.fn.input
  if #M.hints() == 0 then
    return false
  end
  local label = input("nvim-browser hint: ")
  if label == nil or label == "" then
    return false
  end
  return M.focus_hint(label)
end

function M.upload_hint_mode(input)
  input = input or vim.fn.input
  if #M.hints() == 0 then
    return false
  end
  local label = input("nvim-browser hint: ")
  if label == nil or label == "" then
    return false
  end
  local path = input("nvim-browser file: ")
  if path == nil or path == "" then
    return false
  end
  return M.upload_hint(label, { path })
end

function M.toggle_hint_mode(input)
  input = input or vim.fn.input
  if #M.hints() == 0 then
    return false
  end
  local label = input("nvim-browser hint: ")
  if label == nil or label == "" then
    return false
  end
  return M.toggle_hint(label)
end

function M.toggle()
  return terminal.toggle()
end

function M.last_target()
  local target = terminal.state().last_target
  if target ~= nil and target ~= state.smoke_target then
    return target
  end
  return state.last_target
end

function M.current_url()
  return terminal.state().current_url
end

function M.current_title()
  return terminal.state().current_title
end

function M.page_metrics()
  return terminal.state().page_metrics
end

function M.browser_history()
  return terminal.state().browser_history
end

function M.runtime_metadata()
  local terminal_state = terminal.state()
  local runtime = terminal_state.runtime_metadata
  if type(runtime) == "table" and terminal_state.serve_output_label ~= nil then
    runtime = vim.deepcopy(runtime)
    runtime.output_label = terminal_state.serve_output_label
  end
  return runtime
end

function M.focused_element()
  return terminal.state().focused_element
end

function M.latest_download()
  return terminal.state().latest_download
end

function M.latest_dialog()
  return terminal.state().latest_dialog
end

local function copy_dialogs(dialogs)
  local copy = {}
  if type(dialogs) ~= "table" then
    return copy
  end
  for _, dialog in ipairs(dialogs) do
    local item = {}
    if type(dialog) == "table" then
      for key, value in pairs(dialog) do
        item[key] = value
      end
    end
    table.insert(copy, item)
  end
  return copy
end

function M.dialogs()
  return copy_dialogs(terminal.state().dialog_history)
end

local function copy_downloads(downloads)
  local copy = {}
  if type(downloads) ~= "table" then
    return copy
  end
  for _, download in ipairs(downloads) do
    local item = {}
    if type(download) == "table" then
      for key, value in pairs(download) do
        item[key] = value
      end
    end
    table.insert(copy, item)
  end
  return copy
end

function M.downloads()
  local downloads = {}
  local seen_paths = {}

  local function add(download)
    local entry = normalize_download_entry(download)
    if entry == nil or seen_paths[entry.path] then
      return
    end
    seen_paths[entry.path] = true
    table.insert(downloads, entry)
  end

  if session_options().persist then
    for _, download in ipairs(state.downloads) do
      add(download)
    end
  end
  for _, download in ipairs(copy_downloads(terminal.downloads())) do
    add(download)
  end
  return downloads
end

local function download_path(download)
  if type(download) ~= "table" or download.path == nil or download.path == vim.NIL or download.path == "" then
    return nil
  end
  return tostring(download.path)
end

local function report_download_error(opts, reason)
  if type(opts) == "table" and type(opts.on_error) == "function" then
    opts.on_error(reason)
  end
end

local function open_download_path(path)
  return M.open(path) == true
end

function M.open_download(index, opts)
  opts = opts or {}
  local downloads = M.downloads()
  if index ~= nil then
    index = tonumber(index)
    if index == nil or index < 1 or index % 1 ~= 0 then
      report_download_error(opts, "invalid_index")
      return false
    end
    local path = download_path(downloads[index])
    if path == nil then
      report_download_error(opts, "missing_path")
      return false
    end
    return open_download_path(path)
  end

  local candidates = {}
  for download_index, download in ipairs(downloads) do
    local path = download_path(download)
    if path ~= nil then
      table.insert(candidates, {
        index = download_index,
        download = download,
        path = path,
      })
    end
  end
  if #candidates == 0 then
    report_download_error(opts, "no_downloads")
    return false
  end
  if #candidates == 1 then
    return open_download_path(candidates[1].path)
  end

  local callback_called = false
  local opened = false
  local select = opts.select or vim.ui.select
  select(candidates, {
    prompt = "nvim-browser download: ",
    format_item = function(item)
      return status_labels.download_list_label(item.download, item.index) or item.path
    end,
  }, function(choice)
    callback_called = true
    if choice == nil then
      report_download_error(opts, "canceled")
      return
    end
    opened = open_download_path(choice.path)
    if not opened then
      report_download_error(opts, "open_failed")
    end
  end)
  if callback_called then
    return opened
  end
  return nil
end

function M.status()
  return terminal.state().status
end

function M.status_error()
  return terminal.state().status_error
end

function M.frame_health()
  return terminal.state().frame_health
end

function M.hint_error()
  return terminal.state().hint_error
end

function M.doctor()
  return doctor.run(M.config, terminal.state())
end

function M.refresh_doctor_async(callback)
  if type(callback) ~= "function" then
    return false
  end
  local ok = terminal.probe_calibration_state(function()
    callback(M.doctor())
  end)
  if ok then
    return true
  end
  return false
end

function M.last_find_found()
  return terminal.state().last_find_found
end

function M.last_find_match_count()
  return terminal.state().last_find_match_count
end

function M.hints()
  return terminal.state().element_hints or {}
end

M.setup()

return M
