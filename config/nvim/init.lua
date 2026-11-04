-- Leader keys (set before plugins/keymaps)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- nvim-tree replaces netrw; it has to be off before anything loads
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Options ---------------------------------------------------------------
local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.termguicolors = true
opt.guicursor = "a:block" -- block cursor in every mode, like Ghostty

opt.mouse = "a"
opt.clipboard = "unnamedplus" -- yank/paste via the macOS clipboard

opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true
opt.breakindent = true

opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "split" -- live preview of :s substitutions

opt.splitright = true
opt.splitbelow = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.wrap = false

opt.undofile = true
opt.swapfile = false
opt.updatetime = 250
opt.timeoutlen = 400

opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
opt.confirm = true
opt.showmode = false -- statusline shows the mode
opt.laststatus = 3 -- one statusline across all splits

-- Plugins (built-in vim.pack, Neovim 0.12+) -----------------------------
vim.pack.add({
  "https://github.com/echasnovski/mini.nvim",
  "https://github.com/lewis6991/gitsigns.nvim",
  "https://github.com/nvim-lualine/lualine.nvim",
  "https://github.com/nvim-tree/nvim-tree.lua",
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
  "https://github.com/neovim/nvim-lspconfig",
  "https://github.com/mason-org/mason.nvim",
  "https://github.com/mason-org/mason-lspconfig.nvim",
  { src = "https://github.com/obsidian-nvim/obsidian.nvim", version = vim.version.range("*") },
}, { confirm = false })

-- Nothing rewrites your code on save. Neovim's editorconfig support would trim
-- whitespace and add final newlines; keep its indent settings, drop those two.
local editorconfig = require("editorconfig")
editorconfig.properties.trim_trailing_whitespace = nil
editorconfig.properties.insert_final_newline = nil

-- Local theme in colors/shokunin.lua, built from the Ghostty themes picked in
-- install.sh. Light or dark follows the system (~/.local/bin/appearance):
-- checked at startup and whenever nvim regains focus, so an evening switch
-- lands the next time you look at it.
local function sync_background()
  vim.system({ vim.fn.expand("~/.local/bin/appearance") }, {}, function(r)
    local bg = vim.trim(r.stdout or "") == "dark" and "dark" or "light"
    vim.schedule(function()
      if vim.o.background ~= bg then vim.o.background = bg end
    end)
  end)
end

-- Powerline statusline: rounded pills like the zsh prompt, coloured from the
-- same palette, rebuilt whenever the colorscheme (light/dark) changes.
require("mini.icons").setup()
MiniIcons.mock_nvim_web_devicons() -- file-type icons for lualine

local function statusline()
  local c = vim.g.shokunin_colors
  if not c then return end
  local function mode(accent)
    return {
      a = { fg = c.bg, bg = accent, gui = "bold" },
      b = { fg = c.fg, bg = c.bg_line },
      c = { fg = c.fg_dim, bg = c.bg },
    }
  end
  require("lualine").setup({
    options = {
      theme = {
        normal = mode(c.blue), insert = mode(c.green), visual = mode(c.magenta),
        replace = mode(c.red), command = mode(c.yellow), terminal = mode(c.cyan),
        inactive = mode(c.fg_faint),
      },
      section_separators = { left = "\u{e0b4}", right = "\u{e0b6}" },
      component_separators = { left = "\u{e0b5}", right = "\u{e0b7}" },
      globalstatus = true,
    },
    sections = {
      lualine_a = { { "mode", separator = { left = "\u{e0b6}" } } },
      lualine_b = { "branch", "diff" },
      lualine_c = { { "filename", path = 1 }, "diagnostics" },
      lualine_x = { "filetype" },
      lualine_y = { "progress" },
      lualine_z = { { "location", separator = { right = "\u{e0b4}" } } },
    },
  })
end

vim.api.nvim_create_autocmd("ColorScheme", { pattern = "shokunin", callback = statusline })
vim.cmd.colorscheme("shokunin")
sync_background()
vim.api.nvim_create_autocmd("FocusGained", { callback = sync_background })
vim.api.nvim_create_autocmd("OptionSet", {
  pattern = "background",
  callback = function() vim.cmd.colorscheme("shokunin") end,
})

-- No mini.pairs: typing a quote, backtick or bracket inserts just that one.
require("mini.surround").setup()
require("mini.ai").setup()
require("mini.pick").setup()

-- Obsidian vaults, straight from Obsidian's own list, so nothing to configure.
-- Follow [[links]] with Enter; Space o... for the vault commands below.
local vaults = {}
for _, registry in ipairs({
  "~/Library/Application Support/obsidian/obsidian.json",
  "~/.config/obsidian/obsidian.json",
  "~/.var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json",
}) do
  local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(vim.fn.expand(registry)), "\n")) end)
  for _, vault in pairs(ok and data.vaults or {}) do
    table.insert(vaults, { name = vim.fs.basename(vault.path), path = vault.path })
  end
end
if #vaults > 0 then
  require("obsidian").setup({ legacy_commands = false, workspaces = vaults, picker = { name = "mini.pick" } })
end

-- File tree on the left. Cmd+E (Ghostty sends it as Alt+e) opens and closes it.
require("nvim-tree").setup({
  hijack_cursor = true,
  sync_root_with_cwd = true,
  update_focused_file = { enable = true },
  view = { width = 34, preserve_window_proportions = true },
  renderer = {
    root_folder_label = ":~",
    group_empty = true, -- a/b/c instead of three nested folders
    highlight_git = "name",
    indent_markers = { enable = true },
    icons = { git_placement = "after" },
  },
  filters = { custom = { "^\\.git$", "^\\.DS_Store$" } },
  diagnostics = { enable = true, show_on_dirs = true },
})

-- Quitting the last real window quits Neovim, instead of leaving the tree
-- open on its own: close the tree first so :q / :wq exit straight away.
vim.api.nvim_create_autocmd("QuitPre", {
  callback = function()
    local trees, others = {}, 0
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "NvimTree" then
        table.insert(trees, win)
      elseif vim.api.nvim_win_get_config(win).relative == "" then
        others = others + 1
      end
    end
    if others == 1 then
      for _, win in ipairs(trees) do vim.api.nvim_win_close(win, true) end
    end
  end,
})

-- Open the tree on startup: beside a file (cursor stays in the file), or
-- focused for a folder or a bare `nvim`. Not for commit messages, diffs,
-- piped input, or panes too narrow for a sidebar.
vim.api.nvim_create_autocmd("StdinReadPre", { callback = function() vim.g.from_stdin = true end })
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function(data)
    local skip = { gitcommit = true, gitrebase = true, help = true }
    if vim.g.from_stdin or vim.o.diff or skip[vim.bo[data.buf].filetype]
      or vim.bo[data.buf].buftype ~= "" or vim.o.columns < 100 then
      return
    end
    local api = require("nvim-tree.api")
    if vim.fn.isdirectory(data.file) == 1 then
      vim.cmd.cd(data.file)
      api.tree.open()
    elseif data.file ~= "" then
      api.tree.toggle({ focus = false, find_file = true })
    else
      api.tree.open()
    end
  end,
})

require("mini.clue").setup({
  triggers = {
    { mode = "n", keys = "<Leader>" },
    { mode = "x", keys = "<Leader>" },
    { mode = "n", keys = "g" },
    { mode = "n", keys = "<C-w>" },
  },
  clues = {
    require("mini.clue").gen_clues.g(),
    require("mini.clue").gen_clues.windows(),
  },
})
require("gitsigns").setup()
require("shokunin.code") -- treesitter, language servers, completion

-- Keymaps ---------------------------------------------------------------
local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
map("n", "<leader>w", "<cmd>write<CR>", { desc = "Save" })
map("n", "<leader>q", "<cmd>quit<CR>", { desc = "Quit" })

-- Move by display lines when wrapped (counts like 5j still work)
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true })

-- Window navigation. Alt-hjkl is shared with tmux: move between nvim splits,
-- and at the edge hand off to the neighbouring tmux pane.
local function navigate(dir)
  return function()
    local win = vim.api.nvim_get_current_win()
    vim.cmd.wincmd(dir)
    if vim.env.TMUX and vim.api.nvim_get_current_win() == win then
      local flag = ({ h = "-L", j = "-D", k = "-U", l = "-R" })[dir]
      vim.system({ "tmux", "select-pane", flag })
    end
  end
end

for key, name in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  map("n", "<M-" .. key .. ">", navigate(key), { desc = "Window/pane " .. name })
  map("n", "<C-" .. key .. ">", "<C-w>" .. key, { desc = "Window " .. name })
end

-- Move selected lines up/down
map("x", "J", ":move '>+1<CR>gv=gv", { desc = "Move selection down" })
map("x", "K", ":move '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Keep selection when indenting
map("x", "<", "<gv")
map("x", ">", ">gv")

-- Keep cursor centred on half-page jumps and search results
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Finder / file explorer
map("n", "<leader>ff", "<cmd>Pick files<CR>", { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Pick grep_live<CR>", { desc = "Live grep" })
map("n", "<leader>fb", "<cmd>Pick buffers<CR>", { desc = "Buffers" })
map("n", "<leader>fh", "<cmd>Pick help<CR>", { desc = "Help" })
map({ "n", "i" }, "<M-P>", "<cmd>Pick files<CR>", { desc = "Find files" })      -- Cmd+P in Ghostty
map({ "n", "i" }, "<M-F>", "<cmd>Pick grep_live<CR>", { desc = "Search files" }) -- Cmd+Shift+F

-- Obsidian (only when a vault exists)
map("n", "<leader>oo", "<cmd>Obsidian quick_switch<CR>", { desc = "Open note" })
map("n", "<leader>os", "<cmd>Obsidian search<CR>", { desc = "Search notes" })
map("n", "<leader>on", "<cmd>Obsidian new<CR>", { desc = "New note" })
map("n", "<leader>ob", "<cmd>Obsidian backlinks<CR>", { desc = "Backlinks" })
map("n", "<leader>ot", "<cmd>Obsidian today<CR>", { desc = "Today's note" })

-- lazygit in a popup over everything (tmux), or a floating terminal without tmux
map("n", "<leader>gg", function()
  if vim.env.TMUX then
    vim.system({ "tmux", "display-popup", "-E", "-w", "90%", "-h", "90%", "-d", vim.fn.getcwd(), "lazygit" })
  else
    local buf = vim.api.nvim_create_buf(false, true)
    local w, h = math.floor(vim.o.columns * 0.9), math.floor(vim.o.lines * 0.9)
    vim.api.nvim_open_win(buf, true, { relative = "editor", width = w, height = h,
      row = math.floor((vim.o.lines - h) / 2), col = math.floor((vim.o.columns - w) / 2), border = "rounded" })
    vim.fn.jobstart({ "lazygit" }, { term = true, on_exit = function() vim.api.nvim_buf_delete(buf, { force = true }) end })
    vim.cmd.startinsert()
  end
end, { desc = "lazygit" })
map({ "n", "i" }, "<M-e>", "<Cmd>NvimTreeToggle<CR>", { desc = "File tree" })
map("n", "<leader>e", "<Cmd>NvimTreeToggle<CR>", { desc = "File tree" })

-- Diagnostics
map("n", "<leader>d", vim.diagnostic.open_float, { desc = "Line diagnostics" })

-- Autocommands ----------------------------------------------------------
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Briefly highlight yanked text",
  callback = function() vim.hl.on_yank() end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
  desc = "Restore last cursor position",
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(args.buf) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})
