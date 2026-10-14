local M = {}

local defaults = {
  format = "{bufnr} {basename} {path}",
  current_marker = ">",
  modified_marker = "+",
  confirm_delete = true,
  keymaps = {
    select = "<CR>",
    delete = "d",
    refresh = "r",
    close = "q",
  },
  window = {
    position = "left",
    width = 30,
    height = 15,
    enter = true,
  },
}

local state = {
  config = vim.deepcopy(defaults),
  list_bufnr = nil,
  mru = {},
  line_to_bufnr = {},
  refresh_pending = false,
  previous_by_win = {},
  winid = nil,
  owned_windows = {},
  current_bufnr = nil,
  augroup = nil,
  setup_done = false,
}

local function notify(message, level)
  vim.notify("bufexplore: " .. message, level or vim.log.levels.INFO)
end

local function is_valid(bufnr)
  return type(bufnr) == "number" and vim.api.nvim_buf_is_valid(bufnr)
end

local function is_displayable(bufnr)
  if not is_valid(bufnr) or bufnr == state.list_bufnr then
    return false
  end

  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return false
  end

  local buffer = vim.bo[bufnr]
  if not buffer.buflisted or buffer.buftype ~= "" then
    return false
  end

  return vim.api.nvim_buf_get_name(bufnr) ~= ""
end

local function remove_from_mru(bufnr)
  for index = #state.mru, 1, -1 do
    if state.mru[index] == bufnr then
      table.remove(state.mru, index)
    end
  end
end

local function prune_mru()
  local seen = {}
  local mru = {}

  for _, bufnr in ipairs(state.mru) do
    if not seen[bufnr] and is_displayable(bufnr) then
      seen[bufnr] = true
      table.insert(mru, bufnr)
    end
  end

  state.mru = mru
end

local function touch(bufnr)
  if not is_displayable(bufnr) then
    return
  end

  remove_from_mru(bufnr)
  table.insert(state.mru, 1, bufnr)
end

local function collect_initial_mru()
  local buffers = vim.api.nvim_list_bufs()
  table.sort(buffers)
  state.mru = {}

  -- There is no visit history when the plugin is first loaded. Newer buffer
  -- numbers provide a deterministic starting order; BufEnter establishes MRU.
  for index = #buffers, 1, -1 do
    if is_displayable(buffers[index]) then
      table.insert(state.mru, buffers[index])
    end
  end

  touch(vim.api.nvim_get_current_buf())
  state.current_bufnr = is_displayable(vim.api.nvim_get_current_buf()) and vim.api.nvim_get_current_buf() or nil
end

local function ensure_list_buffer()
  if is_valid(state.list_bufnr) then
    return state.list_bufnr
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  state.list_bufnr = bufnr

  vim.api.nvim_buf_set_name(bufnr, "[bufexplore]")
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].filetype = "bufexplore"

  return bufnr
end

local function get_path(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  return vim.fn.fnamemodify(name, ":p")
end

local function format_line(bufnr)
  local path = get_path(bufnr)
  local basename = vim.fn.fnamemodify(path, ":t")
  local current = bufnr == state.current_bufnr
  local modified = vim.bo[bufnr].modified
  local values = {
    bufnr = tostring(bufnr),
    basename = basename,
    path = path,
    current = current and state.config.current_marker or "",
    modified = modified and state.config.modified_marker or "",
  }

  return (state.config.format:gsub("{([%w_]+)}", function(key)
    return values[key] or ""
  end))
end

local function is_valid_window(winid)
  return type(winid) == "number" and vim.api.nvim_win_is_valid(winid)
end

local function current_list_window()
  local current_window = vim.api.nvim_get_current_win()
  if is_valid(state.list_bufnr)
      and vim.api.nvim_win_get_buf(current_window) == state.list_bufnr then
    return current_window
  end
  return nil
end

local function render()
  if not is_valid(state.list_bufnr) then
    return
  end

  prune_mru()

  local lines = {}
  local line_to_bufnr = {}
  for _, bufnr in ipairs(state.mru) do
    table.insert(lines, format_line(bufnr))
    table.insert(line_to_bufnr, bufnr)
  end

  local window = current_list_window() or (is_valid_window(state.winid) and state.winid or nil)
  local cursor_row = 1
  if window then
    cursor_row = vim.api.nvim_win_get_cursor(window)[1]
  end

  vim.bo[state.list_bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(state.list_bufnr, 0, -1, false, lines)
  vim.bo[state.list_bufnr].modifiable = false
  state.line_to_bufnr = line_to_bufnr

  if window and vim.api.nvim_win_is_valid(window) then
    local line_count = math.max(#lines, 1)
    vim.api.nvim_win_set_cursor(window, { math.min(cursor_row, line_count), 0 })
  end
end

local function schedule_refresh()
  if state.refresh_pending then
    return
  end

  state.refresh_pending = true
  vim.schedule(function()
    state.refresh_pending = false
    render()
  end)
end

local function configure_window(window)
  vim.wo[window].number = false
  vim.wo[window].relativenumber = false
  vim.wo[window].signcolumn = "no"
  vim.wo[window].wrap = false
  vim.wo[window].cursorline = true
end

local function acquire_window(position)
  local bufnr = ensure_list_buffer()
  position = position or state.config.window.position

  if position == "current" then
    state.winid = vim.api.nvim_get_current_win()
    return state.winid
  end

  if is_valid_window(state.winid) then
    if vim.api.nvim_win_get_buf(state.winid) ~= bufnr then
      vim.api.nvim_win_set_buf(state.winid, bufnr)
    end
    return state.winid
  end

  local vertical = position == "left" or position == "right"
  local split = position == "top" and "above"
      or position == "bottom" and "below"
      or position
  local winid = vim.api.nvim_open_win(bufnr, state.config.window.enter, {
    win = -1,
    vertical = vertical,
    width = vertical and state.config.window.width or nil,
    height = not vertical and state.config.window.height or nil,
    split = split,
  })

  state.winid = winid
  state.owned_windows[winid] = true
  vim.wo[winid].winfixwidth = true
  vim.wo[winid].winfixheight = true
  return winid
end

local function map_key(bufnr, key, callback)
  if key == false or key == nil then
    return
  end
  if type(key) ~= "string" then
    notify("keymap values must be strings or false", vim.log.levels.WARN)
    return
  end

  vim.keymap.set("n", key, callback, {
    buffer = bufnr,
    silent = true,
    nowait = true,
  })
end

local function setup_keymaps(bufnr)
  local keymaps = state.config.keymaps
  map_key(bufnr, keymaps.select, M.select)
  map_key(bufnr, keymaps.delete, M.delete)
  map_key(bufnr, keymaps.refresh, M.refresh)
  map_key(bufnr, keymaps.close, M.close)
end

local function selected_bufnr()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local bufnr = state.line_to_bufnr[row]
  if not bufnr or not is_displayable(bufnr) then
    render()
    notify("the selected buffer is no longer available", vim.log.levels.WARN)
    return nil
  end
  return bufnr
end

local function confirm_delete(bufnr)
  if not state.config.confirm_delete then
    return true
  end

  local path = get_path(bufnr)
  return vim.fn.confirm("Delete buffer " .. path .. "?", "&Yes\n&No", 2) == 1
end

local function create_autocmds()
  if state.augroup then
    vim.api.nvim_del_augroup_by_id(state.augroup)
  end
  state.augroup = vim.api.nvim_create_augroup("BufferList", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    group = state.augroup,
    callback = function(args)
      if args.buf ~= state.list_bufnr then
        state.current_bufnr = is_displayable(args.buf) and args.buf or nil
        touch(args.buf)
        schedule_refresh()
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "BufWipeout", "BufFilePost", "BufModifiedSet", "DirChanged" }, {
    group = state.augroup,
    callback = function(args)
      if args.buf ~= state.list_bufnr then
        schedule_refresh()
      end
    end,
  })
end

function M.setup(opts)
  opts = opts or {}
  if type(opts) ~= "table" then
    error("bufexplore.setup() expects a table")
  end

  local config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts)
  if type(config.format) ~= "string" then
    error("bufexplore: format must be a string")
  end
  if type(config.keymaps) ~= "table" then
    error("bufexplore: keymaps must be a table")
  end
  if type(config.current_marker) ~= "string" or type(config.modified_marker) ~= "string" then
    error("bufexplore: markers must be strings")
  end
  if type(config.window) ~= "table" then
    error("bufexplore: window must be a table")
  end
  if not vim.tbl_contains({ "current", "left", "right", "top", "bottom" }, config.window.position) then
    error("bufexplore: window.position must be current, left, right, or top/bottom")
  end
  if type(config.window.width) ~= "number" or type(config.window.height) ~= "number" then
    error("bufexplore: window dimensions must be numbers")
  end

  state.config = config
  ensure_list_buffer()
  if not state.setup_done then
    collect_initial_mru()
  else
    touch(vim.api.nvim_get_current_buf())
    state.current_bufnr = is_displayable(vim.api.nvim_get_current_buf())
        and vim.api.nvim_get_current_buf()
        or state.current_bufnr
  end
  create_autocmds()
  setup_keymaps(state.list_bufnr)
  state.setup_done = true
  render()

  return M
end

function M.get_bufnr()
  return ensure_list_buffer()
end

function M.is_open(winid)
  winid = winid or state.winid or vim.api.nvim_get_current_win()
  return is_valid_window(winid)
      and is_valid(state.list_bufnr)
      and vim.api.nvim_win_get_buf(winid) == state.list_bufnr
end

function M.open(opts)
  opts = opts or {}
  if type(opts) ~= "table" then
    error("bufexplore.open() expects a table")
  end

  local bufnr = ensure_list_buffer()
  local position = opts.position or state.config.window.position
  local window = acquire_window(position)

  if position == "current" and vim.api.nvim_win_get_buf(window) ~= bufnr then
    state.previous_by_win[window] = vim.api.nvim_win_get_buf(window)
    vim.api.nvim_win_set_buf(window, bufnr)
  elseif position ~= "current" and vim.api.nvim_win_get_buf(window) ~= bufnr then
    state.previous_by_win[window] = vim.api.nvim_win_get_buf(window)
    vim.api.nvim_win_set_buf(window, bufnr)
  end

  configure_window(window)
  setup_keymaps(bufnr)
  render()
  return window
end

function M.close()
  local window = state.winid or current_list_window()
  if not window then
    return
  end

  local previous = state.previous_by_win[window]
  state.previous_by_win[window] = nil
  local owned = state.owned_windows[window]
  state.owned_windows[window] = nil
  state.winid = nil
  if owned and is_valid_window(window) then
    vim.api.nvim_win_close(window, true)
  elseif is_valid(previous) and previous ~= state.list_bufnr then
    vim.api.nvim_win_set_buf(window, previous)
  elseif is_valid_window(window) then
    vim.api.nvim_win_set_buf(window, state.mru[1] or vim.api.nvim_create_buf(true, false))
  end
end

function M.toggle()
  if M.is_open() then
    M.close()
  else
    M.open()
  end
end

function M.refresh()
  prune_mru()
  render()
end

function M.select()
  if not M.is_open() then
    return
  end

  local bufnr = selected_bufnr()
  if not bufnr then
    return
  end

  touch(bufnr)
  state.current_bufnr = bufnr
  vim.api.nvim_win_set_buf(state.winid or vim.api.nvim_get_current_win(), bufnr)
  schedule_refresh()
end

function M.delete()
  if not M.is_open() then
    return
  end

  local bufnr = selected_bufnr()
  if not bufnr or not confirm_delete(bufnr) then
    return
  end

  local ok, err = pcall(vim.api.nvim_buf_delete, bufnr, {})
  if not ok then
    notify(err, vim.log.levels.WARN)
    return
  end

  remove_from_mru(bufnr)
  render()
end

return M
