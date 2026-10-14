local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", message, vim.inspect(expected), vim.inspect(actual)))
  end
end

local function assert_true(value, message)
  if not value then
    error(message)
  end
end

local function make_buffer(name)
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(bufnr, root .. "/" .. name)
  vim.bo[bufnr].buflisted = true
  return bufnr
end

local first = make_buffer("tests/alpha.txt")
local second = make_buffer("tests/deeper/beta.txt")
local outside = make_buffer("/tmp/bufexplorer-test-gamma.txt")
vim.api.nvim_set_current_buf(first)

local buffers = require("bufexplorer")
assert_equal(buffers.version, "0.1.0", "plugin version")

buffers.setup({
  window = {
    position = "left",
    width = 32,
    enter = true,
  },
})
local explorer_window = buffers.open()
local explorer_buffer = vim.api.nvim_win_get_buf(explorer_window)

assert_equal(vim.bo[explorer_buffer].filetype, "bufexplorer", "list filetype")
local lines = vim.api.nvim_buf_get_lines(explorer_buffer, 0, -1, false)
assert_equal(#lines, 3, "buffer list count")
local function find_line(pattern)
  for index, line in ipairs(lines) do
    if line:find(pattern, 1, true) then
      return index, line
    end
  end
  error("missing buffer list entry: " .. pattern)
end

local _, outside_line = find_line("gamma.txt")
local _, nested_line = find_line("beta.txt")
local alpha_row, alpha_line = find_line("alpha.txt")
assert_true(outside_line:find("/tmp", 1, true) ~= nil, "outside file should show absolute dirname")
assert_true(nested_line:find("tests/deeper", 1, true) ~= nil, "nested file should show relative dirname")
assert_true(alpha_line:find("tests", 1, true) ~= nil, "file should show relative dirname")
assert_true(#lines[1] == #lines[2] and #lines[2] == #lines[3], "buffer list columns should be aligned")

vim.api.nvim_win_set_cursor(explorer_window, { alpha_row, 0 })
buffers.select()
assert_equal(vim.api.nvim_get_current_buf(), first, "select should open in target window")
assert_true(buffers.is_open(explorer_window), "explorer window should remain open")

buffers.close()
assert_true(not vim.api.nvim_win_is_valid(explorer_window), "owned explorer window should close")

for _, bufnr in ipairs({ first, second, outside }) do
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

print("bufexplorer.nvim tests: ok")
