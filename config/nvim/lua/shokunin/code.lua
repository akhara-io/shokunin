-- Code intelligence: treesitter highlighting, language servers (diagnostics,
-- definitions, rename) and completion that only appears when you ask for it
-- with Tab. No snippets, no auto-popup, no auto-inserted includes, and nothing
-- ever formats your code.

-- Treesitter ------------------------------------------------------------------
-- Parsers build with the tree-sitter CLI (brew: tree-sitter-cli) and a C
-- compiler; install() is a no-op for ones already built.
require("nvim-treesitter").install({
  "asm", "c", "cpp", "c_sharp", "powershell", "python", "ruby",
  "lua", "bash", "json", "yaml", "toml", "xml", "markdown", "markdown_inline",
  "make", "cmake", "vim", "vimdoc", "query", "diff", "gitcommit",
})
vim.treesitter.language.register("powershell", "ps1")
vim.api.nvim_create_autocmd("FileType", {
  callback = function(ev) pcall(vim.treesitter.start, ev.buf) end,
})

-- Language servers --------------------------------------------------------------
-- nvim-lspconfig supplies each server's defaults; Mason installs the ones
-- whose runtime this machine has (:Mason to see them).
local function has(cmd) return vim.fn.executable(cmd) == 1 end

local servers = { "clangd", "lua_ls" }
if has("node") then vim.list_extend(servers, { "pyright", "bashls" }) end
if has("python3") then table.insert(servers, "ruff") end
if has("dotnet") then table.insert(servers, "omnisharp") end
if has("pwsh") then table.insert(servers, "powershell_es") end
if has("ruby") and vim.fn.exepath("ruby") ~= "/usr/bin/ruby" then table.insert(servers, "ruby_lsp") end

-- Every server: plain-text completion only, so nothing expands into snippets.
vim.lsp.config("*", {
  capabilities = { textDocument = { completion = { completionItem = { snippetSupport = false } } } },
})
vim.lsp.config("clangd", {
  cmd = { "clangd", "--clang-tidy", "--header-insertion=never", "--function-arg-placeholders=0" },
})
vim.lsp.config("powershell_es", {
  bundle_path = vim.fn.stdpath("data") .. "/mason/packages/powershell-editor-services",
})

require("mason").setup({ ui = { border = "rounded" } })
require("mason-lspconfig").setup({ ensure_installed = servers }) -- and enables them
if has("asm-lsp") then vim.lsp.enable("asm_lsp") end -- from Homebrew, not Mason

vim.diagnostic.config({
  severity_sort = true,
  virtual_text = { current_line = true }, -- the message, on the line you're on only
  float = { border = "rounded", source = true },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "\u{f057}", [vim.diagnostic.severity.WARN] = "\u{f071}",
      [vim.diagnostic.severity.INFO] = "\u{f05a}", [vim.diagnostic.severity.HINT] = "\u{f0eb}",
    },
  },
})

-- Completion ------------------------------------------------------------------
-- Tab opens the list (or moves down it), Shift-Tab moves up, Enter accepts.
vim.opt.completeopt = { "menuone", "noselect", "fuzzy" }
vim.opt.pumheight = 12

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
    if client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = false })
    end
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = ev.buf, desc = "Go to definition" })
  end,
})

local function blank_before_cursor()
  local col = vim.fn.col(".") - 1
  return col == 0 or vim.fn.getline("."):sub(col, col):match("%s") ~= nil
end

vim.keymap.set("i", "<Tab>", function()
  if vim.fn.pumvisible() == 1 then return "<C-n>" end
  if blank_before_cursor() then return "<Tab>" end
  if #vim.lsp.get_clients({ bufnr = 0, method = "textDocument/completion" }) > 0 then
    return "<Cmd>lua vim.lsp.completion.get()<CR>"
  end
  return "<C-n>" -- no server: words from open buffers
end, { expr = true, desc = "Complete / next item" })

vim.keymap.set("i", "<S-Tab>", function()
  return vim.fn.pumvisible() == 1 and "<C-p>" or "<S-Tab>"
end, { expr = true, desc = "Previous item" })

-- Enter accepts a chosen item; otherwise it's a plain newline.
vim.keymap.set("i", "<CR>", function()
  if vim.fn.pumvisible() == 1 and vim.fn.complete_info({ "selected" }).selected ~= -1 then
    return vim.keycode("<C-y>")
  end
  return vim.keycode("<CR>")
end, { expr = true, replace_keycodes = false, desc = "Accept / newline" })

