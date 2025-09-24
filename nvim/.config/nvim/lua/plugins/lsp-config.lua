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

      vim.lsp.config('lua_ls', {
        capabilities = capabilities
      })

      vim.lsp.config('pyright', {
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

      vim.lsp.config('rust_analyzer', {
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

       vim.lsp.config('bashls', {
            capabilities = capabilities,
            cmd = { "bash-language-server", "start" },
            filetypes = { "bash", "sh" },
            settings = {
                bashIde = {
                    globPattern = "*@(.sh|.inc|.bash|.command)"
                },
            },
       })

       vim.lsp.config('r_language_server', {
             cmd = { "R", "--no-echo", "-e", "languageserver::run()" },
             filetypes = { "r", "rmd", "quarto" },
             log_level = 2
       })

       vim.lsp.config('texlab', {
            settings = {
                texlab = {
                    build = {
                        executable = "latexmk",
                        args = { "-pdf", "-interaction=nonstopmode", "-synctex=1", "%f" },
                        onSave = true,
                    },
                    -- forwardSearch = {
                    --     executable = "zathura",  -- or your preferred PDF viewer
                    --     args = { "--synctex-forward", "%l:1:%f", "%p" },
                    -- },
                    chktex = {
                        onEdit = true,
                        onOpenAndSave = true,
                    },
                }
            }
        })

        vim.lsp.config('lua_ls', {
            settings = {
                Lua = {
                    runtime = { version = "LuaJIT" },
                    diagnostics = {
                        globals = { "vim" }, -- Recognize the `vim` global
                    },
                    workspace = {
                        library = vim.api.nvim_get_runtime_file("", true),
                        checkThirdParty = false,
                    },
                    telemetry = { enable = false },
                },
            },
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
