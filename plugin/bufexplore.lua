-- Register the user command without configuring the plugin itself.
vim.api.nvim_create_user_command("BufExplore", function()
  require("bufexplore").open()
end, {})
