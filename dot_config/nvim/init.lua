-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

local home_dir = os.getenv("HOME")

vim.api.nvim_create_autocmd("User", {
  pattern = "TSUpdate",
  callback = function()
    require("nvim-treesitter.parsers").crystal = {
      ---@diagnostic disable-next-line missing-fields
      install_info = {
        path = home_dir .. "/code/tree-sitter-crystal",
        -- files = { "src/parser.c", "src/scanner.c" },
      },
      filetype = "cr",
      tier = 2,
    }
  end,
})
