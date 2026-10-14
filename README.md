# bufexplore.nvim

A small, dependency-free buffer list for Neovim 0.10+, designed to be embeddable in Edgy without depending on Edgy.

## Features

- Lists loaded, listed, named, ordinary file buffers only.
- Orders buffers by most recently used (MRU).
- Shows buffer number, base name, and absolute path by default.
- Switches and normally deletes buffers from a buffer-local keymap.
- Updates on buffer enter, creation, deletion, rename, and modified-state changes.
- Does not create splits or floating windows.
- Exposes `filetype = "bufexplore"` for Edgy integration.

## Setup

```lua
require("bufexplore").setup()
```

The default format is:

```text
{bufnr} {basename} {path}
```

Example:

```text
12 README.md /home/user/project/README.md
3 init.lua /home/user/project/lua/bufexplore/init.lua
```

The default keymaps are buffer-local to the list:

| Key | Action |
| --- | --- |
| `<CR>` | Switch to the selected buffer |
| `d` | Normally delete the selected buffer |
| `r` | Refresh |
| `q` | Close the list and restore the previous buffer |

## Configuration

```lua
require("bufexplore").setup({
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
})
```

Supported format fields are `{bufnr}`, `{basename}`, `{path}`, `{current}`, and `{modified}`. Unknown fields render as an empty string. The default format intentionally omits state markers; add them explicitly when desired:

```lua
format = "{current}{modified} {bufnr} {basename} {path}"
```

Set a keymap to `false` to disable it.

## Commands/API

The plugin registers the `:BufExplore` user command. By default it opens a fixed-width left sidebar:

```vim
:BufExplore
```

Window behavior can be configured as follows:

```lua
require("bufexplore").setup({
  window = {
    position = "left", -- left, right, top, bottom, or current
    width = 30,
    height = 15,
    enter = true,
  },
})
```

The Neo-tree-style window implementation reuses the managed window, creates it only when needed, sets its width or height, and fixes both dimensions. Use `position = "current"` to restore the old behavior of replacing the current window.


```lua
local buffers = require("bufexplore")

buffers.open()    -- open in the configured window position
buffers.close()
buffers.toggle()
buffers.refresh()
buffers.select()
buffers.delete()
buffers.get_bufnr()
buffers.is_open()
```

`setup()` is not called automatically. The plugin does not depend on Edgy or call Edgy APIs. To embed it, configure Edgy to recognize the `bufexplore` filetype and use `position = "current"` when Edgy supplies the target window.
