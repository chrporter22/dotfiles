return {
  {
    "williamboman/mason.nvim",
    lazy = false,
    config = function()
      require("mason").setup()
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    lazy = false,
    opts = {
      auto_install = true,
    },
  },
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    config = function()
      local cmp_nvim_lsp = require("cmp_nvim_lsp")
      local capabilities = vim.tbl_deep_extend(
        "force",
        {},
        vim.lsp.protocol.make_client_capabilities(),
        cmp_nvim_lsp.default_capabilities()
      )

      local lspconfig = require("lspconfig")

      lspconfig.lua_ls.setup({
        capabilities = capabilities
      })

      lspconfig.pyright.setup({
        capabilities = capabilities,
        cmd = { "pyright-langserver", "--stdio" },
        filetypes = { "python"},
        settings = {
            python = {
                analysis = {
                    autoSearchPaths = true,
                    diagnosticMode = "openFilesOnly",
                    useLibraryCodeForTypes = true
                }
            }
        }
      })
    
      lspconfig.rust_analyzer.setup({
				on_attach = on_attach,
				capabilities = capabilities,
				filetypes = { "rust" },
				settings = {
                    ['rust-analyzer'] = {
                        diagnostics = {
                            enable = false;
						},
					},
				},
			})

       lspconfig.bashls.setup({
            capabilities = capabilities,
            cmd = { "bash-language-server", "start" },
            filetypes = { "bash", "sh" },
            settings = {
                bashIde = {
                    globPattern = "*@(.sh|.inc|.bash|.command)"
                },
            },
       })

       lspconfig.r_language_server.setup({
             cmd = { "R", "--no-echo", "-e", "languageserver::run()" },
             filetypes = { "r", "rmd", "quarto" },
             log_level = 2
       })
      lspconfig.textlsp.setup({
            cmd = { "textlsp" },
            filetypes = { "text", "tex", "org" },
            settings = {
                textLSP = {
                    analysers = {
                        languagetool = {
                            check_text = {
                                on_change = false,
                                on_open = true,
                                on_save = true
                            },
                            enabled = true
                        }
                    },
                    documents = {
                        org = {
                            org_todo_keywords = { "TODO", "IN_PROGRESS", "DONE" }
                        }
                    }
                }
            }
       })

      vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
      vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, {})
      vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, {})
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, {})
      vim.keymap.set("n", "<leader>gf", vim.lsp.buf.format, {})
      vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, {})
    end,
  },
}
