return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    -- does not support lazy-loading
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").setup({
        install_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site"),
      })

      -- Highlighting is no longer enabled by `setup` and must be started
      -- per-buffer. `start` asserts a parser exists, so swallow the error for
      -- filetypes that have none installed.
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(ev)
          pcall(vim.treesitter.start, ev.buf)
        end,
      })
    end,
  },
}

-- Parsers live in `install_dir` and persist across restarts, so this only has
-- to be run once (and again after `:TSUpdate`):
--   :TSInstall bash c cpp dockerfile go html javascript json julia lua
--            markdown markdown_inline python r rust sql vim vimdoc
