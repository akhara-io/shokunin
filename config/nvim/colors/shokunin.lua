-- Shokunin colorscheme: built from the two Ghostty themes picked in
-- install.sh (~/.config/shokunin/palette.lua), light or dark per 'background'.
-- UI shades are blends of the theme's background and foreground, so any
-- theme pair gets a matching editor.
local ok, palettes = pcall(dofile, vim.fn.expand("~/.config/shokunin/palette.lua"))
if not ok then
  vim.notify("shokunin: no palette, run install.sh", vim.log.levels.WARN)
  return vim.cmd.colorscheme("default")
end

vim.cmd("highlight clear")
vim.g.colors_name = "shokunin"

local p = palettes[vim.o.background] or palettes.light
local a = p.ansi -- a[1] is ANSI 0

local function blend(from, to, t)
  local function ch(hex, i) return tonumber(hex:sub(i, i + 1), 16) end
  local out = "#"
  for i = 2, 6, 2 do
    out = out .. string.format("%02x", math.floor(ch(from, i) + (ch(to, i) - ch(from, i)) * t + 0.5))
  end
  return out
end

-- Light themes read best with the normal ANSI accents, dark ones with the brights.
local acc = vim.o.background == "dark" and 9 or 1
local function accent(n) return a[acc + n] end

local c = {
  bg = p.bg, fg = p.fg,
  bg_alt = blend(p.bg, p.fg, 0.04), -- floats, statusline
  bg_line = blend(p.bg, p.fg, 0.07), -- cursorline
  border = blend(p.bg, p.fg, 0.18),
  fg_dim = blend(p.bg, p.fg, 0.6),
  fg_faint = blend(p.bg, p.fg, 0.4),
  selection = p.selection or blend(p.bg, accent(4), 0.25),
  red = accent(1), green = accent(2), yellow = accent(3),
  blue = accent(4), magenta = accent(5), cyan = accent(6),
  red_br = a[10], green_br = a[11], yellow_br = a[12],
  blue_br = a[13], magenta_br = a[14], cyan_br = a[15],
}
c.search = blend(c.bg, c.yellow, 0.25)
c.diff_add = blend(c.bg, c.green, 0.14)
c.diff_del = blend(c.bg, c.red, 0.14)
c.diff_chg = blend(c.bg, c.blue, 0.12)
c.diff_txt = blend(c.bg, c.blue, 0.26)
vim.g.shokunin_colors = c -- for the statusline theme in init.lua

for i, color in ipairs(a) do
  vim.g["terminal_color_" .. (i - 1)] = color
end

local groups = {
  -- Editor UI
  Normal = { fg = c.fg, bg = c.bg },
  NormalFloat = { fg = c.fg, bg = c.bg_alt },
  FloatBorder = { fg = c.border, bg = c.bg_alt },
  FloatTitle = { fg = c.blue, bg = c.bg_alt, bold = true },
  Cursor = { fg = c.bg, bg = c.fg },
  CursorLine = { bg = c.bg_line },
  CursorColumn = { bg = c.bg_line },
  ColorColumn = { bg = c.bg_line },
  LineNr = { fg = c.fg_faint },
  CursorLineNr = { fg = c.yellow, bold = true },
  SignColumn = { bg = c.bg },
  FoldColumn = { fg = c.fg_faint, bg = c.bg },
  Folded = { fg = c.fg_dim, bg = c.bg_alt },
  WinSeparator = { fg = c.border },
  VertSplit = { link = "WinSeparator" },
  StatusLine = { fg = c.fg, bg = c.bg_alt },
  StatusLineNC = { fg = c.fg_dim, bg = c.bg_alt },
  TabLine = { fg = c.fg_dim, bg = c.bg_alt },
  TabLineSel = { fg = c.fg, bg = c.bg, bold = true },
  TabLineFill = { bg = c.bg_alt },
  WinBar = { fg = c.fg, bold = true },
  WinBarNC = { fg = c.fg_dim },
  Visual = { bg = c.selection },
  Search = { fg = c.fg, bg = c.search },
  IncSearch = { fg = c.bg, bg = c.yellow },
  CurSearch = { link = "IncSearch" },
  Substitute = { fg = c.bg, bg = c.red },
  MatchParen = { fg = c.blue, bold = true, underline = true },
  Pmenu = { fg = c.fg, bg = c.bg_alt },
  PmenuSel = { bg = c.selection, bold = true },
  PmenuSbar = { bg = c.bg_alt },
  PmenuThumb = { bg = c.border },
  NonText = { fg = c.border },
  Whitespace = { fg = c.border },
  SpecialKey = { fg = c.fg_faint },
  EndOfBuffer = { fg = c.bg },
  Directory = { fg = c.blue },
  Title = { fg = c.blue, bold = true },
  Question = { fg = c.green },
  MoreMsg = { fg = c.green },
  ModeMsg = { fg = c.fg, bold = true },
  ErrorMsg = { fg = c.red },
  WarningMsg = { fg = c.yellow },
  QuickFixLine = { bg = c.selection },
  Conceal = { fg = c.fg_faint },
  SpellBad = { sp = c.red, undercurl = true },
  SpellCap = { sp = c.yellow, undercurl = true },
  SpellLocal = { sp = c.cyan, undercurl = true },
  SpellRare = { sp = c.magenta, undercurl = true },

  -- Syntax
  Comment = { fg = c.fg_dim, italic = true },
  Constant = { fg = c.magenta },
  String = { fg = c.green },
  Character = { fg = c.green },
  Number = { fg = c.magenta },
  Boolean = { fg = c.magenta },
  Float = { fg = c.magenta },
  Identifier = { fg = c.fg },
  Function = { fg = c.blue },
  Statement = { fg = c.red },
  Keyword = { fg = c.red },
  Conditional = { fg = c.red },
  Repeat = { fg = c.red },
  Label = { fg = c.red },
  Exception = { fg = c.red },
  Operator = { fg = c.fg_dim },
  PreProc = { fg = c.cyan },
  Include = { fg = c.red },
  Type = { fg = c.yellow },
  StorageClass = { fg = c.red },
  Structure = { fg = c.yellow },
  Typedef = { fg = c.yellow },
  Special = { fg = c.cyan },
  SpecialChar = { fg = c.cyan_br },
  Delimiter = { fg = c.fg_dim },
  Tag = { fg = c.blue },
  Underlined = { underline = true },
  Error = { fg = c.red },
  Todo = { fg = c.bg, bg = c.yellow, bold = true },

  -- Treesitter
  ["@variable"] = { fg = c.fg },
  ["@variable.builtin"] = { fg = c.magenta, italic = true },
  ["@variable.parameter"] = { fg = c.fg },
  ["@variable.member"] = { fg = c.cyan },
  ["@property"] = { fg = c.cyan },
  ["@constant.builtin"] = { fg = c.magenta },
  ["@module"] = { fg = c.yellow },
  ["@string.escape"] = { fg = c.cyan_br },
  ["@string.special"] = { fg = c.cyan },
  ["@function.builtin"] = { fg = c.blue_br },
  ["@constructor"] = { fg = c.yellow },
  ["@keyword.function"] = { fg = c.red },
  ["@keyword.return"] = { fg = c.red, bold = true },
  ["@type.builtin"] = { fg = c.yellow, italic = true },
  ["@punctuation.bracket"] = { fg = c.fg_dim },
  ["@tag"] = { fg = c.blue },
  ["@tag.attribute"] = { fg = c.cyan },
  ["@tag.delimiter"] = { fg = c.fg_dim },
  ["@markup.heading"] = { fg = c.blue, bold = true },
  ["@markup.strong"] = { bold = true },
  ["@markup.italic"] = { italic = true },
  ["@markup.link"] = { fg = c.cyan, underline = true },
  ["@markup.link.url"] = { fg = c.cyan, underline = true },
  ["@markup.raw"] = { fg = c.green },
  ["@markup.list"] = { fg = c.red },

  -- Diagnostics
  DiagnosticError = { fg = c.red },
  DiagnosticWarn = { fg = c.yellow },
  DiagnosticInfo = { fg = c.blue },
  DiagnosticHint = { fg = c.cyan },
  DiagnosticOk = { fg = c.green },
  DiagnosticUnderlineError = { sp = c.red, undercurl = true },
  DiagnosticUnderlineWarn = { sp = c.yellow, undercurl = true },
  DiagnosticUnderlineInfo = { sp = c.blue, undercurl = true },
  DiagnosticUnderlineHint = { sp = c.cyan, undercurl = true },
  LspReferenceText = { bg = c.bg_line },
  LspReferenceRead = { bg = c.bg_line },
  LspReferenceWrite = { bg = c.bg_line, underline = true },
  LspInlayHint = { fg = c.fg_faint, italic = true },

  -- Diff / git
  DiffAdd = { bg = c.diff_add },
  DiffDelete = { fg = c.red, bg = c.diff_del },
  DiffChange = { bg = c.diff_chg },
  DiffText = { bg = c.diff_txt },
  Added = { fg = c.green },
  Removed = { fg = c.red },
  Changed = { fg = c.yellow },
  GitSignsAdd = { fg = c.green_br },
  GitSignsChange = { fg = c.yellow_br },
  GitSignsDelete = { fg = c.red_br },

  -- mini.nvim
  MiniStatuslineModeNormal = { fg = c.bg, bg = c.blue, bold = true },
  MiniStatuslineModeInsert = { fg = c.bg, bg = c.green, bold = true },
  MiniStatuslineModeVisual = { fg = c.bg, bg = c.magenta, bold = true },
  MiniStatuslineModeReplace = { fg = c.bg, bg = c.red, bold = true },
  MiniStatuslineModeCommand = { fg = c.bg, bg = c.yellow, bold = true },
  MiniStatuslineModeOther = { fg = c.bg, bg = c.cyan, bold = true },
  MiniStatuslineDevinfo = { fg = c.fg, bg = c.bg_line },
  MiniStatuslineFilename = { fg = c.fg_dim, bg = c.bg_alt },
  MiniStatuslineFileinfo = { fg = c.fg, bg = c.bg_line },
  MiniStatuslineInactive = { fg = c.fg_dim, bg = c.bg_alt },
  MiniPickMatchCurrent = { bg = c.selection },
  MiniPickMatchRanges = { fg = c.blue, bold = true },
  MiniPickPrompt = { fg = c.blue, bg = c.bg_alt },
  MiniFilesTitleFocused = { fg = c.blue, bg = c.bg_alt, bold = true },
  MiniClueTitle = { fg = c.blue, bg = c.bg_alt, bold = true },
  MiniClueDescGroup = { fg = c.magenta },
  MiniClueNextKey = { fg = c.red, bold = true },
  MiniSurround = { fg = c.bg, bg = c.yellow },

  -- nvim-tree: a tinted sidebar with no visible edge
  NvimTreeNormal = { fg = c.fg, bg = c.bg_alt },
  NvimTreeNormalNC = { fg = c.fg, bg = c.bg_alt },
  NvimTreeEndOfBuffer = { fg = c.bg_alt, bg = c.bg_alt },
  NvimTreeWinSeparator = { fg = c.bg_alt, bg = c.bg_alt },
  NvimTreeCursorLine = { bg = c.bg_line },
  NvimTreeRootFolder = { fg = c.magenta, bold = true },
  NvimTreeFolderName = { fg = c.blue },
  NvimTreeOpenedFolderName = { fg = c.blue, bold = true },
  NvimTreeEmptyFolderName = { fg = c.fg_dim },
  NvimTreeFolderIcon = { fg = c.blue },
  NvimTreeIndentMarker = { fg = c.border },
  NvimTreeSpecialFile = { fg = c.yellow, underline = true },
  NvimTreeGitDirtyIcon = { fg = c.yellow },
  NvimTreeGitStagedIcon = { fg = c.green },
  NvimTreeGitNewIcon = { fg = c.green },
  NvimTreeGitDeletedIcon = { fg = c.red },
  NvimTreeGitIgnoredIcon = { fg = c.fg_faint },
  NvimTreeDiagnosticErrorIcon = { fg = c.red },
  NvimTreeDiagnosticWarnIcon = { fg = c.yellow },
}

for name, spec in pairs(groups) do
  vim.api.nvim_set_hl(0, name, spec)
end
