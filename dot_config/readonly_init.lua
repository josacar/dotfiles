-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

---@class list
local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
parser_config.crystal = {
  install_info = {
    url = "/home/selu/code/tree-sitter-crystal",
    files = { "src/parser.c", "src/scanner.c" },
    branch = "main",
  },
  filetype = "cr",
}
