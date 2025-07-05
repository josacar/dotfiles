-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

local home_dir = os.getenv("HOME")

---@class ParserInfo[]
local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
parser_config.crystal = {
  install_info = {
    url = home_dir .. "/code/tree-sitter-crystal",
    files = { "src/parser.c", "src/scanner.c" },
    branch = "main",
  },
  filetype = "cr",
}
