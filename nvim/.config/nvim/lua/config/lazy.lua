-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Parsers to keep installed. These are tree-sitter *language* names, which do
-- not always match Neovim filetypes (parser `bash` serves filetype `sh`), so
-- the autocmd below maps filetype -> language rather than matching on names.
local languages = {
  'bash', 'c', 'cue', 'diff', 'dockerfile', 'git_config', 'git_rebase',
  'gitcommit', 'gitignore', 'groovy', 'hcl', 'helm', 'html', 'java', 'jinja',
  'jq', 'json', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'nginx', 'php',
  'python', 'query', 'ssh_config', 'terraform', 'typescript', 'vim', 'vimdoc',
  'xml', 'yaml',
}

-- Filetypes that still want Vim's regex syntax running alongside tree-sitter
-- (the old `additional_vim_regex_highlighting` list).
local also_regex_syntax = { markdown = true, ruby = true }

-- Filetypes where tree-sitter indent misbehaves (the old `indent.disable`).
local no_treesitter_indent = { ruby = true }

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    -- import your plugins
    ---{ import = "plugins" },
    { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
    {
      -- Highlight, edit, and navigate code.
      --
      -- Pinned to `main` explicitly. nvim-treesitter's default branch moved
      -- from `master` to `main`, and `main` is a rewrite with an incompatible
      -- API: no `nvim-treesitter.configs` module, no `ensure_installed`,
      -- `highlight` or `indent` options, and no `:TSInstallSync`. Without the
      -- explicit branch here a plugin update silently switches branch and the
      -- old-style config stops loading entirely — which is exactly what
      -- happened before this rewrite.
      --
      -- Requires Neovim 0.12+.
      'nvim-treesitter/nvim-treesitter',
      branch = 'main',
      lazy = false,
      build = ':TSUpdate',
      config = function()
        local ts = require('nvim-treesitter')

        ts.setup({
          install_dir = vim.fn.stdpath('data') .. '/site',
        })

        -- Neovim detects *.tf as filetype `tf`, but the terraform parser is
        -- registered only for `terraform` and `terraform-vars`, so .tf files
        -- would silently get no highlighting at all. `master` registered this
        -- mapping itself; on `main` it has to be declared. Every other language
        -- in the list above already resolves from its filetype.
        vim.treesitter.language.register('terraform', 'tf')

        -- `main` has no ensure_installed; install whatever is missing once, in
        -- the background. Diffing against get_installed() first keeps this a
        -- no-op on a warm setup rather than re-running the installer at every
        -- start.
        local installed = ts.get_installed()
        local missing = vim.tbl_filter(function(lang)
          return not vim.tbl_contains(installed, lang)
        end, languages)
        if #missing > 0 then
          ts.install(missing)
        end

        -- `main` also drops the highlight/indent options: highlighting is
        -- started per buffer instead. One filetype-agnostic autocmd covers
        -- every language, rather than enumerating filetypes that may not match
        -- parser names.
        vim.api.nvim_create_autocmd('FileType', {
          group = vim.api.nvim_create_augroup('treesitter_start', { clear = true }),
          callback = function(ev)
            local ft = vim.bo[ev.buf].filetype
            local lang = vim.treesitter.language.get_lang(ft)
            if not lang then
              return
            end

            -- start() throws when the parser is not installed, which doubles
            -- as the check for it.
            if not pcall(vim.treesitter.start, ev.buf, lang) then
              -- Stands in for the old `auto_install`: fetch it in the
              -- background so the next buffer of this type is highlighted.
              if vim.tbl_contains(ts.get_available(), lang) then
                ts.install(lang)
              end
              return
            end

            if also_regex_syntax[ft] then
              vim.bo[ev.buf].syntax = 'on'
            end

            if not no_treesitter_indent[ft] then
              vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end
          end,
        })
      end,
    },
  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "habamax" } },
  -- automatically check for plugin updates
  checker = {
    enabled = true,
    notify = false,
  },
})
