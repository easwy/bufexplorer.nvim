# bufexplorer.nvim

A small, dependency-free buffer list for Neovim 0.10+, designed to be embeddable in Edgy without depending on Edgy.

`bufexplorer.nvim` is a fully agent-coded project. It is intended as a modern Neovim replacement for [jlanzarotta/bufexplorer](https://github.com/jlanzarotta/bufexplorer), while keeping the familiar `:BufExplore` command name distinct from that plugin's commands.

## Features

- Lists valid, listed, named, ordinary file buffers.
- Orders buffers by most recently used (MRU).
- Shows buffer number, base name, and absolute path by default.
- Opens selected files in the main editing window rather than the explorer window.
- Updates on buffer enter, creation, deletion, rename, and modified-state changes.
- Supports fixed sidebars or top/bottom windows, and Edgy integration.
- Exposes `filetype = "bufexplorer.nvim"` for Edgy integration.

## Installation

The plugin has no runtime dependencies. Install it with your preferred plugin manager.

### lazy.nvim

```lua
return {
  {
    "easwy/bufexplorer.nvim",
    config = function()
      require("bufexplorer").setup()
    end,
  },
}
```

Replace `easwy/bufexplorer.nvim` with the repository owner/name if you are using a fork.

### vim.pack (Neovim 0.12+)

```lua
vim.pack.add({
  "https://github.com/easwy/bufexplorer.nvim",
})
```

### packer.nvim

```lua
use({
  "easwy/bufexplorer.nvim",
  config = function()
    require("bufexplorer").setup()
  end,
})
```

### Manual installation via `:h packages`

```sh
git clone https://github.com/easwy/bufexplorer.nvim \
  ~/.local/share/nvim/site/pack/plugins/start/bufexplorer.nvim
```

The plugin is loaded automatically by Neovim's package mechanism. Then configure it with:

```lua
require("bufexplorer").setup()
```

## Setup

```lua
require("bufexplorer").setup()
```

The `:BufExplore` user command remains intentionally unchanged so it is easy to distinguish from other buffer explorer implementations:

```vim
:BufExplore
```

The default format is:

```text
{bufnr} {basename} {path}
```

Example:

```text
12 README.md /home/user/project/README.md
3 init.lua /home/user/project/lua/bufexplorer/init.lua
```

The default keymaps are buffer-local to the list:

| Key | Action |
| --- | --- |
| `<CR>` | Switch to the selected buffer in the main editing window |
| `d` | Normally delete the selected buffer |
| `r` | Refresh |
| `q` | Close the list and restore the previous buffer |

## Configuration

```lua
require("bufexplorer").setup({
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
    position = "left", -- left, right, top, bottom, or current
    width = 30,
    height = 15,
    enter = true,
    exit_on_last_window = true,
    open_files_in_last_window = true,
    create_target_window = true,
  },
})
```

Supported format fields are `{bufnr}`, `{basename}`, `{path}`, `{current}`, and `{modified}`. Unknown fields render as an empty string. Add state markers explicitly when desired:

```lua
format = "{current}{modified} {bufnr} {basename} {path}"
```

Set a keymap to `false` to disable it.

When the BufExplorer window is the last Neovim window, `exit_on_last_window` controls whether closing it exits Neovim. It is enabled by default. Set it to `false` to keep Neovim open.

The target-window selection follows the Neo-tree approach: it tracks recently used windows, skips configured special windows such as Edgy, terminals, quickfix, and other explorers, and can create a new split if no suitable target exists.

## Commands and API

```lua
local buffers = require("bufexplorer")

buffers.open()    -- open in the configured window position
buffers.close()
buffers.toggle()
buffers.refresh()
buffers.select()
buffers.delete()
buffers.get_bufnr()
buffers.is_open()
```

`setup()` is initialized automatically when `open()` is called, but explicit setup is recommended. The plugin does not depend on Edgy or call Edgy APIs. To embed it in Edgy, configure Edgy to recognize `filetype = "bufexplorer.nvim"` and use `position = "current"` when Edgy supplies the target window.

## License

See [LICENSE](LICENSE).
