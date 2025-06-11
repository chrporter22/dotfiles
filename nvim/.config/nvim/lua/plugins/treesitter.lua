return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local config = require("nvim-treesitter.configs")
      config.setup({
        auto_install = false,
        ensure_installed = {
          "bash",
          "c",
          "python",
          "r",
          "dockerfile",
          "sql",
          "rust",
          "html",
          "vim",
          "vimdoc",
          "javascript",
          "markdown",
          "markdown_inline",
          "json",
          "go",
          "lua",
        },
        highlight = { enable = true },
        indent = { enable = false },
      })
    end
  }
}
