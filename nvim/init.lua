-- Using my terminal colors for nvim
vim.opt.termguicolors = true


-- ============================================================
--  NEOVIM CONFIG — Step 2: Core quality of life
-- ============================================================

-- ── LEADER KEY ───────────────────────────────────────────────
-- Space as leader. Must be set before anything else.
-- This becomes your personal prefix for all custom shortcuts.
vim.g.mapleader      = " "
vim.g.maplocalleader = " "

-- ── APPEARANCE ───────────────────────────────────────────────
vim.opt.termguicolors  = true   -- true color (required for transparent bg)
vim.opt.background     = "dark" -- make colorschemes choose their dark palette
vim.opt.number         = true   -- show line numbers
vim.opt.relativenumber = true   -- relative numbers (makes jumping with 5j etc easy)
vim.opt.cursorline     = true   -- highlight the line your cursor is on
vim.opt.signcolumn     = "yes"  -- always show the gutter (prevents layout jumping)
vim.opt.showmode       = false  -- don't show -- INSERT -- (we'll add a status bar later)
vim.opt.wrap           = false  -- no line wrapping
vim.opt.list           = true   -- reveal whitespace that can make code alignment confusing
vim.opt.listchars      = { trail = "·", tab = "  ", extends = "›", precedes = "‹", nbsp = "␣" }
vim.opt.showmatch      = true   -- briefly jump/highlight to the matching bracket
vim.opt.matchtime      = 2

-- ── PURPLE DESIGN SYSTEM ─────────────────────────────────────
-- One palette drives every highlight, the statusline and the
-- rainbow brackets. Change a value here and the whole UI follows.
local palette = {
  -- Surfaces. bg = "none" everywhere the buffer shows through,
  -- so Ghostty's blur stays visible.
  cursorline   = "#2a2a30", -- neutral gray bar under the cursor line
  visual       = "#3a2a5c",
  float        = "#1e1530",
  statusline_b = "#2a1f40",
  separator    = "#3d2f5c",
  indent       = "#2b2040",

  -- Text
  fg      = "#ece4fb",
  fg_dim  = "#c7b8e6",
  muted   = "#7c6a9c",
  comment = "#727169", -- soft gray (Kanagawa fujiGray): comments recede
  ink     = "#140d20", -- dark text that sits on a bright accent

  -- The purple family — the spine of the theme
  purple    = "#a855f7",
  purple_lt = "#c9a4ff",
  purple_dp = "#7c3aed",
  lavender  = "#b79dff",
  magenta   = "#e879f9",
  pink      = "#f472b6",

  -- Supporting accents, all tuned to sit beside the purple
  cyan   = "#5ee6e6",
  green  = "#6ee7a0",
  yellow = "#ffd479",
  orange = "#ff9e64",
  red    = "#ff6b8a",
}


-- Who paints the code (token) colours:
--   "mono"     monochrome: near-white code, gray keywords, blue-gray fields,
--              dim comments, orange warnings (see mono_syntax_highlights)
--   "purple"   the hand-painted palette from before Kanagawa
--   "kanagawa" leave tokens to the Kanagawa colorscheme
local syntax_style = "mono"

-- Monochrome text palette; only syntax_style = "mono" uses it.
local mono = {
  bright  = "#ececec", -- identifiers, calls, the current line number
  text    = "#d2d2d2", -- strings, types, modules
  keyword = "#9a9a9a", -- local / if / then / end, operators, literals
  field   = "#8792a2", -- .fn .loop .opt: members and properties, cool gray-blue
  punct   = "#6e6e6e", -- brackets, commas
  comment = "#5f5f5f", -- recedes furthest
  linenr  = "#4b4b4b",
  warn    = "#e5925a", -- the orange diagnostic in the reference
}

local function mono_syntax_highlights()
  local m = mono
  return {
    Identifier                 = { fg = m.bright },
    Function                   = { fg = m.bright },
    Statement                  = { fg = m.keyword },
    Keyword                    = { fg = m.keyword },
    Conditional                = { fg = m.keyword },
    Repeat                     = { fg = m.keyword },
    Operator                   = { fg = m.keyword },
    Type                       = { fg = m.text },
    String                     = { fg = m.text },
    Character                  = { fg = m.text },
    Number                     = { fg = m.keyword },
    Boolean                    = { fg = m.keyword },
    Float                      = { fg = m.keyword },
    Constant                   = { fg = m.text },
    PreProc                    = { fg = m.keyword },
    Special                    = { fg = m.text },
    Delimiter                  = { fg = m.punct },
    Todo                       = { fg = m.warn, bold = true },
    Error                      = { fg = palette.red },
    ["@variable"]              = { fg = m.bright },
    ["@variable.builtin"]      = { fg = m.bright },
    ["@variable.parameter"]    = { fg = m.text },
    ["@variable.member"]       = { fg = m.field },
    ["@property"]              = { fg = m.field },
    ["@field"]                 = { fg = m.field },
    ["@function"]              = { fg = m.bright },
    ["@function.builtin"]      = { fg = m.bright },
    ["@function.call"]         = { fg = m.bright },
    ["@function.method"]       = { fg = m.field },
    ["@function.method.call"]  = { fg = m.field },
    ["@constructor"]           = { fg = m.text },
    ["@keyword"]               = { fg = m.keyword },
    ["@keyword.function"]      = { fg = m.keyword },
    ["@keyword.return"]        = { fg = m.keyword },
    ["@keyword.import"]        = { fg = m.keyword },
    ["@keyword.conditional"]   = { fg = m.keyword },
    ["@keyword.repeat"]        = { fg = m.keyword },
    ["@keyword.operator"]      = { fg = m.keyword },
    ["@operator"]              = { fg = m.keyword },
    ["@type"]                  = { fg = m.text },
    ["@type.builtin"]          = { fg = m.text },
    ["@module"]                = { fg = m.text },
    ["@string"]                = { fg = m.text },
    ["@string.escape"]         = { fg = m.bright },
    ["@number"]                = { fg = m.keyword },
    ["@boolean"]               = { fg = m.keyword },
    ["@constant"]              = { fg = m.text },
    ["@constant.builtin"]      = { fg = m.keyword },
    ["@punctuation.bracket"]   = { fg = m.punct },
    ["@punctuation.delimiter"] = { fg = m.punct },
    ["@punctuation.special"]   = { fg = m.punct },
    ["@tag"]                   = { fg = m.bright },
    ["@tag.attribute"]         = { fg = m.field },
    ["@tag.delimiter"]         = { fg = m.punct },
    -- Gutter and diagnostics, matching the reference
    LineNr                     = { fg = m.linenr },
    LineNrAbove                = { fg = m.linenr },
    LineNrBelow                = { fg = m.linenr },
    CursorLineNr               = { fg = m.bright, bold = true },
    DiagnosticWarn             = { fg = m.warn },
    DiagnosticVirtualTextWarn  = { fg = m.warn },
    DiagnosticSignWarn         = { fg = m.warn },
    DiagnosticUnderlineWarn    = { undercurl = true, sp = m.warn },
    NonText                    = { fg = "#3a3a3a" }, -- listchars like the ↲ markers
    Whitespace                 = { fg = "#3a3a3a" },
  }
end

local function custom_syntax_highlights()
  local p = palette
  return {
    Delimiter                  = { fg = p.lavender },
    Identifier                 = { fg = p.fg },
    Function                   = { fg = p.purple_lt },
    Statement                  = { fg = p.magenta },
    Keyword                    = { fg = p.magenta },
    Conditional                = { fg = p.magenta },
    Repeat                     = { fg = p.magenta },
    Operator                   = { fg = p.pink },
    Type                       = { fg = p.cyan },
    String                     = { fg = p.green },
    Character                  = { fg = p.green },
    Number                     = { fg = p.orange },
    Boolean                    = { fg = p.orange, bold = true },
    Float                      = { fg = p.orange },
    Constant                   = { fg = p.orange },
    PreProc                    = { fg = p.purple },
    Special                    = { fg = p.pink },
    Todo                       = { fg = p.ink, bg = p.yellow, bold = true },
    Error                      = { fg = p.red, bold = true },
    ["@punctuation.bracket"]   = { fg = p.lavender },
    ["@punctuation.delimiter"] = { fg = p.muted },
    ["@punctuation.special"]   = { fg = p.pink },
    ["@constructor"]           = { fg = p.cyan },
    ["@variable"]              = { fg = p.fg },
    ["@variable.builtin"]      = { fg = p.pink, italic = true },
    ["@variable.member"]       = { fg = p.fg_dim },
    ["@variable.parameter"]    = { fg = p.orange, italic = true },
    ["@property"]              = { fg = p.fg_dim },
    ["@function"]              = { fg = p.purple_lt },
    ["@function.builtin"]      = { fg = p.purple_lt, italic = true },
    ["@function.call"]         = { fg = p.purple_lt },
    ["@function.method"]       = { fg = p.purple_lt },
    ["@keyword"]               = { fg = p.magenta },
    ["@keyword.return"]        = { fg = p.magenta, bold = true },
    ["@keyword.import"]        = { fg = p.purple },
    ["@type"]                  = { fg = p.cyan },
    ["@type.builtin"]          = { fg = p.cyan, italic = true },
    ["@string"]                = { fg = p.green },
    ["@string.escape"]         = { fg = p.pink, bold = true },
    ["@number"]                = { fg = p.orange },
    ["@boolean"]               = { fg = p.orange, bold = true },
    ["@comment"]               = { fg = p.comment, italic = true },
    ["@comment.documentation"]  = { fg = p.comment, italic = true },
    ["@lsp.type.comment"]       = { fg = p.comment, italic = true },
    SpecialComment              = { fg = p.comment, italic = true },
    ["@tag"]                   = { fg = p.magenta },
    ["@tag.attribute"]         = { fg = p.orange, italic = true },
    ["@tag.delimiter"]         = { fg = p.muted },
    ["@module"]                = { fg = p.lavender },
    ["@lsp.type.namespace"]    = { fg = p.lavender },

  }
end

local function apply_coding_highlights()
  local p = palette
  local none = "none"

  local highlights = {
    -- Base surfaces
    Normal       = { fg = p.fg, bg = none },
    NormalNC     = { fg = p.fg_dim, bg = none },
    NormalFloat  = { fg = p.fg, bg = none },
    FloatBorder  = { fg = p.purple, bg = none },
    FloatTitle   = { fg = p.purple_lt, bg = none, bold = true },
    SignColumn   = { bg = none },
    EndOfBuffer  = { fg = p.indent, bg = none },
    WinSeparator = { fg = p.separator, bg = none },
    VertSplit    = { fg = p.separator, bg = none },

    -- Cursor + selection
    CursorLine    = { bg = p.cursorline },
    CursorLineNr  = { fg = p.purple_lt, bold = true },
    CursorColumn  = { bg = p.cursorline },
    LineNr        = { fg = p.muted },
    LineNrAbove   = { fg = p.muted },
    LineNrBelow   = { fg = p.muted },
    Visual        = { bg = p.visual },
    VisualNOS     = { bg = p.visual },
    MatchParen    = { fg = p.ink, bg = p.purple, bold = true },
    Search        = { fg = p.ink, bg = p.lavender, bold = true },
    IncSearch     = { fg = p.ink, bg = p.magenta, bold = true },
    CurSearch     = { fg = p.ink, bg = p.magenta, bold = true },
    Substitute    = { fg = p.ink, bg = p.pink, bold = true },
    ColorColumn   = { bg = p.cursorline },
    Whitespace    = { fg = p.indent },
    NonText       = { fg = p.indent },
    Folded        = { fg = p.lavender, bg = p.cursorline },
    FoldColumn    = { fg = p.muted, bg = none },
    Comment       = { fg = p.comment, italic = true },
    Title         = { fg = p.purple_lt, bold = true },
    Directory     = { fg = p.lavender, bold = true },
    Question      = { fg = p.cyan },
    MoreMsg       = { fg = p.green },
    ModeMsg       = { fg = p.purple_lt, bold = true },
    ErrorMsg      = { fg = p.red, bold = true },
    WarningMsg    = { fg = p.yellow },
    Conceal       = { fg = p.muted },
    SpecialKey    = { fg = p.purple_dp },
    Winbar        = { fg = p.fg_dim, bg = none },
    WinbarNC      = { fg = p.muted, bg = none },

    -- Completion menu (blink.cmp reads these)
    Pmenu         = { fg = p.fg_dim, bg = p.float },
    PmenuSel      = { fg = p.ink, bg = p.purple, bold = true },
    PmenuSbar     = { bg = p.float },
    PmenuThumb    = { bg = p.purple_dp },
    PmenuMatch    = { fg = p.magenta, bold = true },
    PmenuMatchSel = { fg = p.ink, bg = p.purple, bold = true },
    BlinkCmpMenuBorder        = { fg = p.purple, bg = none },
    BlinkCmpDocBorder         = { fg = p.purple_dp, bg = none },
    BlinkCmpSignatureHelpBorder = { fg = p.purple_dp, bg = none },
    BlinkCmpLabelMatch        = { fg = p.magenta, bold = true },
    BlinkCmpKind              = { fg = p.lavender },

    -- Diagnostics
    DiagnosticError = { fg = p.red },
    DiagnosticWarn  = { fg = p.yellow },
    DiagnosticInfo  = { fg = p.cyan },
    DiagnosticHint  = { fg = p.lavender },
    DiagnosticOk    = { fg = p.green },
    DiagnosticUnderlineError = { undercurl = true, sp = p.red },
    DiagnosticUnderlineWarn  = { undercurl = true, sp = p.yellow },
    DiagnosticUnderlineInfo  = { undercurl = true, sp = p.cyan },
    DiagnosticUnderlineHint  = { undercurl = true, sp = p.lavender },
    DiagnosticVirtualTextError = { fg = p.red, italic = true },
    DiagnosticVirtualTextWarn  = { fg = p.yellow, italic = true },
    DiagnosticVirtualTextInfo  = { fg = p.cyan, italic = true },
    DiagnosticVirtualTextHint  = { fg = p.lavender, italic = true },

    -- LSP
    LspReferenceText  = { bg = p.visual },
    LspReferenceRead  = { bg = p.visual },
    LspReferenceWrite = { bg = p.visual, underline = true },
    LspInlayHint      = { fg = p.muted, italic = true },
    LspSignatureActiveParameter = { fg = p.magenta, bold = true },

    -- Git / diff
    DiffAdd    = { fg = "#d9ffe9", bg = "#123d2a" },
    DiffChange = { fg = "#efe4ff", bg = "#2e2050" },
    DiffDelete = { fg = "#ffdfe6", bg = "#471a2a" },
    DiffText   = { fg = "#ffffff", bg = p.purple_dp, bold = true },
    Added      = { fg = p.green, bold = true },
    Changed    = { fg = p.lavender, bold = true },
    Removed    = { fg = p.red, bold = true },
    GitSignsAdd           = { fg = p.green, bold = true },
    GitSignsChange        = { fg = p.lavender, bold = true },
    GitSignsDelete        = { fg = p.red, bold = true },
    GitSignsAddInline     = { fg = "#ffffff", bg = "#1a7a4d", bold = true },
    GitSignsChangeInline  = { fg = "#ffffff", bg = p.purple_dp, bold = true },
    GitSignsDeleteInline  = { fg = "#ffffff", bg = "#9c2f47", bold = true },
    GitSignsCurrentLineBlame = { fg = p.muted, italic = true },
    DiffviewStatusAdded    = { fg = p.green, bold = true },
    DiffviewStatusModified = { fg = p.lavender, bold = true },
    DiffviewStatusDeleted  = { fg = p.red, bold = true },
    DiffviewFilePanelTitle    = { fg = p.purple_lt, bold = true },
    DiffviewFilePanelCounter  = { fg = p.magenta, bold = true },
    DiffviewNormal            = { bg = none },

    -- Brackets: a purple-led gradient, kept as part of the UI identity
    -- rather than the syntax colourway.
    RainbowDelimiterRed    = { fg = p.purple,    bold = true },
    RainbowDelimiterYellow = { fg = p.magenta,   bold = true },
    RainbowDelimiterBlue   = { fg = p.pink,      bold = true },
    RainbowDelimiterOrange = { fg = p.lavender,  bold = true },
    RainbowDelimiterGreen  = { fg = p.cyan,      bold = true },
    RainbowDelimiterViolet = { fg = p.purple_lt, bold = true },
    RainbowDelimiterCyan   = { fg = p.orange,    bold = true },

    -- Indent guides
    IblIndent = { fg = p.indent },
    IblScope  = { fg = p.purple },

    -- Snacks (picker / explorer / notifier / input)
    SnacksNormal            = { bg = none },
    SnacksNormalNC          = { bg = none },
    SnacksWinBar            = { fg = p.purple_lt, bg = none, bold = true },
    SnacksPickerBorder      = { fg = p.purple, bg = none },
    SnacksPickerTitle       = { fg = p.purple_lt, bold = true },
    SnacksPickerMatch       = { fg = p.magenta, bold = true },
    SnacksPickerDir         = { fg = p.muted },
    SnacksPickerPathHidden  = { fg = p.muted },
    SnacksPickerCursorLine  = { bg = p.visual },
    SnacksIndentScope       = { fg = p.purple },
    SnacksNotifierInfo      = { fg = p.cyan },
    SnacksNotifierWarn      = { fg = p.yellow },
    SnacksNotifierError     = { fg = p.red },
    SnacksInputBorder       = { fg = p.purple },

    -- Start screen
    DashSpider1             = { fg = "#ecc4ff" },
    DashSpider2             = { fg = "#daa6ff" },
    DashSpider3             = { fg = "#c88afc" },
    DashSpider4             = { fg = "#b670f4" },
    DashSpider5             = { fg = "#a45cea" },
    DashSpider6             = { fg = "#924cde" },
    SnacksDashboardHeader   = { fg = p.purple_lt },
    SnacksDashboardIcon     = { fg = p.purple },
    SnacksDashboardDesc     = { fg = p.fg },
    SnacksDashboardKey      = { fg = p.muted },
    SnacksDashboardFooter   = { fg = p.muted, italic = true },
    SnacksDashboardSpecial  = { fg = p.lavender },

    -- Breadcrumbs (dropbar) and outline (aerial)
    WinBar                 = { fg = p.fg_dim, bg = none },
    WinBarNC               = { fg = p.muted, bg = none },
    DropBarIconUISeparator = { fg = p.muted },
    DropBarMenuHoverEntry  = { bg = p.visual },
    AerialLine             = { bg = p.visual },
    AerialGuide            = { fg = p.indent },

    -- which-key
    WhichKey          = { fg = p.magenta, bold = true },
    WhichKeyGroup     = { fg = p.lavender },
    WhichKeyDesc      = { fg = p.fg_dim },
    WhichKeySeparator = { fg = p.muted },
    WhichKeyFloat     = { bg = p.float }, -- bottom key panel
    WhichKeyNormal    = { bg = p.float },
    WhichKeyBorder    = { fg = p.purple },

    -- Trouble / todo-comments
    TroubleNormal   = { bg = none },
    TroubleText     = { fg = p.fg_dim },
    TroubleCount    = { fg = p.magenta, bold = true },
    TroubleFoldIcon = { fg = p.purple },

    -- Markdown (render-markdown)
    ["@markup.heading.1.markdown"] = { fg = p.purple_lt, bold = true },
    ["@markup.heading.2.markdown"] = { fg = p.magenta, bold = true },
    ["@markup.heading.3.markdown"] = { fg = p.pink, bold = true },
    ["@markup.heading.4.markdown"] = { fg = p.lavender, bold = true },
    ["@markup.link"]               = { fg = p.cyan, underline = true },
    ["@markup.raw"]                = { fg = p.green },
    ["@markup.strong"]             = { fg = p.fg, bold = true },
    ["@markup.italic"]             = { fg = p.fg_dim, italic = true },
    RenderMarkdownH1Bg = { fg = p.purple_lt, bg = "#2a1a44" },
    RenderMarkdownH2Bg = { fg = p.magenta, bg = "#2a1a3c" },
    RenderMarkdownH3Bg = { fg = p.pink, bg = "#2a1a34" },
    RenderMarkdownCode = { bg = "#1a1228" },
    RenderMarkdownBullet = { fg = p.purple },
  }

  if syntax_style == "purple" then
    for group, opts in pairs(custom_syntax_highlights()) do
      highlights[group] = opts
    end
  elseif syntax_style == "mono" then
    for group, opts in pairs(mono_syntax_highlights()) do
      highlights[group] = opts
    end
    -- LSP semantic tokens (@lsp.*) would repaint names in the colorscheme's
    -- colours on top of treesitter; clear them so the monochrome look holds.
    for _, group in ipairs(vim.fn.getcompletion("@lsp", "highlight")) do
      if group ~= "@lsp.type.comment" then highlights[group] = {} end
    end
  end

  -- Comments stay gray regardless of colourscheme, so they sit quietly
  -- behind the code.
  local comment = syntax_style == "mono" and mono.comment or p.comment
  for _, g in ipairs({ "Comment", "@comment", "@comment.documentation", "@lsp.type.comment", "SpecialComment" }) do
    highlights[g] = { fg = comment, italic = true }
  end

  for group, opts in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, opts)
  end
end

-- Statusline theme built from the same palette. Each mode gets its
-- own accent so you can read the mode from colour alone.
local function lualine_purple()
  local p = palette
  local function mode(accent)
    return {
      a = { fg = p.ink, bg = accent, gui = "bold" },
      b = { fg = p.lavender, bg = p.statusline_b },
      c = { fg = p.muted, bg = "none" },
    }
  end

  return {
    normal   = mode(p.purple),
    insert   = mode(p.cyan),
    visual   = mode(p.magenta),
    replace  = mode(p.red),
    command  = mode(p.yellow),
    terminal = mode(p.green),
    inactive = {
      a = { fg = p.muted, bg = "none" },
      b = { fg = p.muted, bg = "none" },
      c = { fg = p.muted, bg = "none" },
    },
  }
end

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = apply_coding_highlights,
})
apply_coding_highlights()

-- ── INDENTATION ──────────────────────────────────────────────
vim.opt.tabstop     = 2        -- 2 spaces per tab
vim.opt.shiftwidth  = 2        -- 2 spaces when indenting with > or <
vim.opt.expandtab   = true     -- use spaces instead of actual tab characters
vim.opt.smartindent = true     -- auto-indent new lines intelligently

-- ── SEARCH ───────────────────────────────────────────────────
vim.opt.ignorecase = true      -- case-insensitive search by default
vim.opt.smartcase  = true      -- ...unless you type an uppercase letter
vim.opt.hlsearch   = true      -- highlight search matches
vim.opt.incsearch  = true      -- show matches as you type

-- ── SPLITS ───────────────────────────────────────────────────
vim.opt.splitbelow = true      -- horizontal splits open below (not above)
vim.opt.splitright = true      -- vertical splits open to the right

-- ── SCROLLING ────────────────────────────────────────────────
vim.opt.scrolloff     = 8      -- always keep 8 lines above/below cursor
vim.opt.sidescrolloff = 8      -- always keep 8 columns left/right of cursor

-- ── CLIPBOARD ────────────────────────────────────────────────
vim.opt.clipboard = "unnamedplus"  -- yank/paste uses your system clipboard

-- ── UNDO ─────────────────────────────────────────────────────
vim.opt.undofile = true        -- persist undo history between sessions
vim.opt.undodir  = vim.fn.stdpath("cache") .. "/undo"

-- ── SWAP FILES ───────────────────────────────────────────────
-- Answer the "swap file already exists" prompt with (E)dit anyway, always.
-- Nearly every one of these is a ghost: a session that was killed rather than
-- quit leaves its .swp behind, and nvim then flags it forever even though the
-- owning process is long gone. undofile above is the real safety net.
--
-- The tradeoff, stated plainly: if the same file genuinely IS open in another
-- live nvim, this no longer warns you, and the last one to write wins.
vim.api.nvim_create_autocmd("SwapExists", {
  group = vim.api.nvim_create_augroup("SwapSkipPrompt", { clear = true }),
  callback = function()
    vim.v.swapchoice = "e"
  end,
})

-- ── PERFORMANCE / FEEL ───────────────────────────────────────
vim.opt.updatetime = 100       -- faster refresh (affects git signs, LSP later)
vim.opt.timeoutlen = 400       -- how long to wait for key combos (ms)
vim.opt.pumheight  = 10        -- max items in autocomplete dropdown
vim.opt.autoread   = true      -- reload files changed by an external agent

-- Keep normal buffers and an open Diffview synced with external AI edits.
-- Unsaved local buffers are never overwritten by :checktime.
local agent_refresh_group = vim.api.nvim_create_augroup("AgentEditRefresh", { clear = true })
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI", "TermLeave" }, {
  group = agent_refresh_group,
  callback = function()
    vim.cmd("silent! checktime")
  end,
})

if vim._agent_refresh_timer then
  vim._agent_refresh_timer:stop()
  vim._agent_refresh_timer:close()
end

local agent_refresh_timer = vim.uv.new_timer()
vim._agent_refresh_timer = agent_refresh_timer
agent_refresh_timer:start(1000, 1000, vim.schedule_wrap(function()
  if vim.fn.mode() ~= "c" then
    vim.cmd("silent! checktime")
  end

  local diffview_lib = package.loaded["diffview.lib"]
  if diffview_lib then
    local view = diffview_lib.get_current_view()
    if view and type(view.update_files) == "function" then
      view:update_files()
    end
  end
end))

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = agent_refresh_group,
  once = true,
  callback = function()
    if agent_refresh_timer and not agent_refresh_timer:is_closing() then
      agent_refresh_timer:stop()
      agent_refresh_timer:close()
    end
  end,
})

-- ── KEYMAPS ──────────────────────────────────────────────────
local map = vim.keymap.set

local controls_win = nil
local controls_buf = nil
local controls_expanded = false
local controls_help_path = vim.fn.expand("~/.config/dev-help/nvim-workflow.md")

local controls_lines = {
  "Neovim Controls",
  "",
  "Popup controls",
  "  Space ?        open this cheat sheet",
  "  :Controls      open this cheat sheet from command mode",
  "  q / Esc        close this popup",
  "  m / Enter      expand or collapse this popup",
  "  Ctrl-d/u       scroll down/up",
  "",
  "Opening projects and files",
  "  cd ~/Projects/traci && nvim .       open a project",
  "  cd ~/Projects/tecosystem && nvim .  open a project",
  "  nvim path/to/file                    open one file",
  "  nvim +42 path/to/file                open at line 42",
  "  nvim -O file1 file2                  open side by side",
  "  :e path/to/file                      open a file inside nvim",
  "  :vsp path/to/file                    open file in vertical split",
  "  :sp path/to/file                     open file in horizontal split",
  "",
  "Cursor-style navigation",
  "  Space e        file explorer",
  "  Space Space    quick open files",
  "  Space /        search across project",
  "  Space ,        open buffers",
  "  Space x        close current buffer",
  "  Space tt       terminal toggle",
  "  Space gg       lazygit / source control",
  "  Space f        format file",
  "",
  "Modes",
  "  i              insert mode",
  "  Esc            normal mode",
  "  v              visual selection",
  "  :              command mode",
  "",
  "Movement",
  "  h j k l        left / down / up / right",
  "  w / b          next / previous word",
  "  gg / G         top / bottom of file",
  "  /text          search in current file",
  "  n / N          next / previous search match",
  "  Ctrl-h/j/k/l   move between splits",
  "",
  "Editing",
  "  Ctrl-s         save",
  "  u              undo",
  "  Ctrl-r         redo",
  "  dd             delete line",
  "  yy             copy line",
  "  p              paste",
  "  ciw            change inner word",
  "  .              repeat last edit",
  "  < / >          indent visual selection",
  "  Alt-j/k        move selected lines down/up",
  "",
  "Splits and buffers",
  "  Space |        vertical split",
  "  Space -        horizontal split",
  "  Ctrl-h/j/k/l   move between splits",
  "  Space ,        switch buffers",
  "  Space x        close current buffer",
  "",
  "Code intelligence",
  "  gd             go to definition",
  "  gD             go to declaration",
  "  gi             go to implementation",
  "  grr            references",
  "  grn            rename symbol",
  "  gra            code action",
  "  K              hover docs",
  "  Space ad       AI define selected code",
  "  Space ld       line diagnostic",
  "  [d / ]d        previous / next diagnostic",
  "  Space sd       project diagnostics",
  "  Space ss       symbols",
  "",
  "Autocomplete",
  "  Ctrl-space     show completion and docs",
  "  Ctrl-n/p       next / previous completion",
  "  Ctrl-y         accept completion",
  "  Ctrl-e         close completion",
  "  Ctrl-k         signature help",
  "",
  "Git",
  "  Space gg       lazygit",
  "  Space gl       git log",
  "  Space gL       current file git log",
  "  ]h / [h        next / previous hunk",
  "  Space hp       preview hunk",
  "  Space hs       stage hunk",
  "  Space hr       reset hunk",
  "  Space gd       open diff review",
  "  Space ga       live agent changes",
  "  Space gc       close diff review",
  "  Space gh       file history",
  "",
  "Diagnostics and lists",
  "  Space xx       diagnostics list",
  "  Space xq       quickfix list",
  "  Space st       TODO comments",
  "",
  "IDE layout",
  "  Shift-h / l    previous / next tab",
  "  Space bp       pin tab",
  "  Space bo       close other tabs",
  "  Space bb       pick a tab",
  "  Space .        file browser",
  "  Space r        recent files",
  "  Space cs       code outline sidebar",
  "  Space u        undo tree",
  "  ]] / [[        next / previous reference",
  "  Space qs       restore session for this folder",
  "  Space ql       restore last session",
  "",
  "Plugin management",
  "  Space L        :Lazy",
  "  Space M        :Mason",
  "  :Lazy          manage plugins",
  "  :Mason         manage language servers and tools",
}

local function get_controls_lines()
  if vim.fn.filereadable(controls_help_path) == 1 then
    return vim.fn.readfile(controls_help_path)
  end
  return controls_lines
end

local function controls_config(expanded, line_count)
  local columns = vim.o.columns
  local rows = vim.o.lines
  local max_width = math.max(20, columns - 4)
  local max_height = math.max(8, rows - 6)
  local width = expanded and max_width or math.min(96, max_width)
  local height = expanded and max_height or math.min(line_count or #controls_lines, max_height)

  return {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(0, math.floor((rows - height) / 2) - 1),
    col = math.max(0, math.floor((columns - width) / 2)),
    style = "minimal",
    border = "rounded",
    title = " Neovim Controls ",
    title_pos = "center",
  }
end

local function close_controls()
  if controls_win and vim.api.nvim_win_is_valid(controls_win) then
    vim.api.nvim_win_close(controls_win, true)
  end
  controls_win = nil
  controls_buf = nil
  controls_expanded = false
end

local function resize_controls()
  if not (controls_win and vim.api.nvim_win_is_valid(controls_win)) then
    return
  end
  controls_expanded = not controls_expanded
  local line_count = controls_buf and vim.api.nvim_buf_is_valid(controls_buf) and vim.api.nvim_buf_line_count(controls_buf) or #controls_lines
  vim.api.nvim_win_set_config(controls_win, controls_config(controls_expanded, line_count))
end

local function show_nvim_controls()
  if controls_win and vim.api.nvim_win_is_valid(controls_win) then
    vim.api.nvim_set_current_win(controls_win)
    return
  end

  controls_expanded = false
  local lines = get_controls_lines()
  controls_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[controls_buf].buftype = "nofile"
  vim.bo[controls_buf].bufhidden = "wipe"
  vim.bo[controls_buf].filetype = "markdown"
  vim.bo[controls_buf].modifiable = true
  vim.api.nvim_buf_set_lines(controls_buf, 0, -1, false, lines)
  vim.bo[controls_buf].modifiable = false

  controls_win = vim.api.nvim_open_win(controls_buf, true, controls_config(false, #lines))
  vim.wo[controls_win].cursorline = true
  vim.wo[controls_win].wrap = false

  local popup_opts = { buffer = controls_buf, nowait = true, silent = true }
  map("n", "q", close_controls, vim.tbl_extend("force", popup_opts, { desc = "Close controls" }))
  map("n", "<Esc>", close_controls, vim.tbl_extend("force", popup_opts, { desc = "Close controls" }))
  map("n", "m", resize_controls, vim.tbl_extend("force", popup_opts, { desc = "Expand controls" }))
  map("n", "<CR>", resize_controls, vim.tbl_extend("force", popup_opts, { desc = "Expand controls" }))
end

vim.api.nvim_create_user_command("Controls", show_nvim_controls, {
  desc = "Open the Neovim controls cheat sheet",
})
map("n", "<leader>?", show_nvim_controls, { desc = "Controls cheat sheet" })

local function get_visual_selection_text()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line, start_col = start_pos[2], start_pos[3]
  local end_line, end_col = end_pos[2], end_pos[3]

  if start_line == 0 or end_line == 0 then
    return ""
  end

  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  if #lines == 0 then
    return ""
  end

  lines[#lines] = string.sub(lines[#lines], 1, end_col)
  lines[1] = string.sub(lines[1], start_col)
  return table.concat(lines, "\n")
end

local function get_project_root()
  local markers = {
    ".git",
    "package.json",
    "pyproject.toml",
    "Cargo.toml",
    "go.mod",
    "Makefile",
  }
  local bufname = vim.api.nvim_buf_get_name(0)
  local start_path = bufname ~= "" and vim.fs.dirname(bufname) or vim.fn.getcwd()
  local found = vim.fs.find(markers, { path = start_path, upward = true })[1]
  return found and vim.fs.dirname(found) or vim.fn.getcwd()
end

local function set_ai_definition_lines(buf, text)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local lines = vim.split((text or ""):gsub("\r\n", "\n"), "\n", { plain = true })
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

local function open_ai_definition_buffer(lines)
  vim.cmd("botright 16split")
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_buf_set_name(buf, "AI Definition " .. os.date("%H:%M:%S"))
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].swapfile = false
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  set_ai_definition_lines(buf, table.concat(lines, "\n"))
  return buf
end

local function build_ai_definition_prompt(selection, question)
  local file = vim.api.nvim_buf_get_name(0)
  local root = get_project_root()
  local filetype = vim.bo.filetype ~= "" and vim.bo.filetype or "text"

  return root, table.concat({
    "You are helping me learn this codebase while I code.",
    "Explain the selected code using this project's actual context. Use read-only project inspection only when it helps you be more specific.",
    "Do not edit files. Do not suggest broad refactors unless the selected code is misleading.",
    "",
    "Answer style:",
    "- Start with a plain-English definition of what the selected code is.",
    "- Explain important variables, functions, components, braces, brackets, and data flow.",
    "- Tie the explanation to the current file and project scope.",
    "- Define technical terms briefly instead of assuming I already know them.",
    "- Keep it direct and useful for learning while coding.",
    "",
    "User question: " .. (question ~= "" and question or "Define this selection and explain what it means."),
    "Project root: " .. root,
    "File: " .. (file ~= "" and file or "[unnamed buffer]"),
    "Filetype: " .. filetype,
    "",
    "Selected code:",
    "```" .. filetype,
    selection,
    "```",
  }, "\n")
end

local function run_ai_definition(root, prompt, buf)
  local function finish(provider, result)
    vim.schedule(function()
      local output = vim.trim(result.stdout or "")
      local err = vim.trim(result.stderr or "")

      if result.code == 0 and output ~= "" then
        set_ai_definition_lines(buf, "# AI Definition\n\n" .. output)
        return
      end

      set_ai_definition_lines(buf, table.concat({
        "# AI Definition Failed",
        "",
        provider .. " did not return a usable explanation.",
        "",
        "Exit code: " .. tostring(result.code),
        "",
        "Output:",
        "```",
        output ~= "" and output or err,
        "```",
      }, "\n"))
    end)
  end

  local function run_codex()
    if vim.fn.executable("codex") ~= 1 then
      finish("AI", { code = 127, stderr = "Neither claude nor codex is executable." })
      return
    end

    vim.system({
      "codex",
      "exec",
      "--ephemeral",
      "--sandbox",
      "read-only",
      "--ask-for-approval",
      "never",
      "--skip-git-repo-check",
      "-C",
      root,
      "-",
    }, { text = true, stdin = prompt, cwd = root }, function(result)
      finish("Codex", result)
    end)
  end

  if vim.fn.executable("claude") ~= 1 then
    run_codex()
    return
  end

  vim.system({
    "claude",
    "-p",
    "--no-session-persistence",
    "--permission-mode",
    "dontAsk",
    "--tools",
    "Read,Grep,Glob,LS",
    prompt,
  }, { text = true, cwd = root }, function(result)
    if result.code == 0 and vim.trim(result.stdout or "") ~= "" then
      finish("Claude", result)
    else
      run_codex()
    end
  end)
end

local function explain_visual_selection_with_ai()
  local selection = get_visual_selection_text()
  if vim.trim(selection) == "" then
    vim.notify("Select code first, then press <leader>ad.", vim.log.levels.WARN)
    return
  end

  vim.ui.input({
    prompt = "Ask about selection: ",
    default = "Define this code in this project",
  }, function(question)
    if question == nil then
      return
    end

    local root, prompt = build_ai_definition_prompt(selection, question)
    local buf = open_ai_definition_buffer({
      "# AI Definition",
      "",
      "Reading project context and explaining the selected code...",
      "",
      "Provider order: Claude, then Codex fallback.",
    })
    run_ai_definition(root, prompt, buf)
  end)
end

local function close_current_pane()
  local wins = vim.api.nvim_tabpage_list_wins(0)
  if #wins > 1 then
    local ok = pcall(vim.cmd.close)
    if ok then
      return
    end
  end

  pcall(vim.cmd.bdelete)
end

-- Clear search highlight with Escape
map("n", "<Esc>", "<cmd>noh<cr>", { desc = "Clear search highlight" })

-- Save with Ctrl+S from any mode
map({ "n", "i", "v" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save file" })

-- Better window navigation (Ctrl + hjkl to move between splits)
map("n", "<C-h>", "<C-w>h", { desc = "Move to left split"  })
map("n", "<C-j>", "<C-w>j", { desc = "Move to lower split" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to upper split" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right split" })

-- AeroSpace owns Ctrl-h/j/k/l globally, so Space-h/j/k/l is the reliable nvim pane path.
map("n", "<leader>h", "<C-w>h", { desc = "Focus left pane" })
map("n", "<leader>j", "<C-w>j", { desc = "Focus lower pane" })
map("n", "<leader>k", "<C-w>k", { desc = "Focus upper pane" })
map("n", "<leader>l", "<C-w>l", { desc = "Focus right pane" })

-- Stay in indent mode when shifting in visual mode
map("v", "<", "<gv", { desc = "Indent left and reselect"  })
map("v", ">", ">gv", { desc = "Indent right and reselect" })

-- Move selected lines up/down with Alt+j/k
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move selection up"   })

-- Quick split creation
map("n", "<leader>|", "<cmd>vsp<cr>", { desc = "Vertical split"   })
map("n", "<leader>-", "<cmd>sp<cr>",  { desc = "Horizontal split" })

-- Close current buffer
map("n", "<leader>x", function() Snacks.bufdelete() end, { desc = "Close buffer" })
map("n", "<leader>bd", function() Snacks.bufdelete() end, { desc = "Close tab" })
map("n", "<leader>L", "<cmd>Lazy<cr>", { desc = "Lazy (plugins)" })
map("n", "<leader>M", "<cmd>Mason<cr>", { desc = "Mason (language servers)" })

-- Close the current split/pane without needing to remember :close
map("n", "<leader>w", close_current_pane, { desc = "Close current pane" })

-- Explain selected code with project-aware AI, except in competition no-AI mode.
if vim.env.NO_AI_HACK ~= "1" then
  map("v", "<leader>ad", explain_visual_selection_with_ai, { desc = "AI define selection" })
end

-- ============================================================
--  IDE PLUGINS
-- ============================================================

-- ── START SCREEN HELPERS ─────────────────────────────────────
-- Spider #3 from fastfetch, one row per line so each gets its own
-- step of the purple gradient (DashSpider1 top .. DashSpider6 bottom).
local dashboard_spider = {
  { 1, "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣴⡶⢶⣄⠀⠀⠀⢀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀" },
  { 1, "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣠⣨⣿⠀⢀⣤⡿⣡⣶⠾⠶⣶⣤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀" },
  { 1, "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⡾⠟⠿⣶⣄⠀⠀⣸⡏⠉⠉⣿⣿⠟⠉⠀⠈⠀⠀⠀⠀⠈⠻⣷⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀" },
  { 1, "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣾⠏⠀⠀⢠⣿⠻⣷⣄⠻⠇⠀⣰⡿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀" },
  { 2, "⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⠃⠀⢰⠾⢿⣧⠀⠈⢻⣧⡀⠀⣿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣿⠿⠛⢿⡿⣶⣤⡀⠀⠀⠀⠀" },
  { 2, "⠀⠀⠀⠀⠀⠀⠀⢀⣤⡾⠟⠛⢻⡿⣶⣤⣻⣇⠀⢀⣽⡿⠾⠛⠻⠷⢶⣦⣴⠄⠀⠀⠀⢀⣴⡿⠋⠁⠀⠀⣼⡇⠀⠙⢻⣦⡀⠀⠀" },
  { 2, "⠀⠀⠀⠀⠀⠀⣴⡿⠋⠀⠀⠀⣾⡇⠀⠙⠻⣿⣶⣿⡁⠀⠀⠀⠀⠀⠀⠈⠡⡶⠆⠀⣠⣾⣯⣤⣶⣶⣶⣤⡛⠻⢷⣤⣾⠟⢿⣦⠀" },
  { 3, "⠀⠀⠀⠀⢀⣾⣿⡀⢀⣴⠿⠛⠛⢷⣦⡄⠀⢸⡟⠉⠛⠛⠻⢶⣤⡀⠀⠀⠀⢰⣾⠛⠛⠉⠉⠀⣶⠀⠀⠙⢿⣄⠀⠙⢿⣦⣀⣿⡇" },
  { 3, "⠀⠀⠀⢀⣾⠃⠙⣿⡿⠋⠀⠀⠀⠀⢈⣠⣴⣿⡇⣀⣀⡀⠀⠀⠙⢿⣆⠀⠀⠀⣿⠀⠀⢶⣦⡘⠿⢷⣦⣀⣼⣿⣆⠀⠀⠙⠛⠋⠀" },
  { 3, "⠀⠀⢠⣿⡇⠀⣰⡿⠁⠀⢀⣴⡶⠟⢿⣏⣁⢸⣿⠟⠙⣿⣶⣦⡄⠀⠻⢷⣦⣾⣿⣤⣀⣠⣿⢿⣦⠀⠹⣿⡉⠀⠻⣧⡀⠀⠀⠀⠀" },
  { 3, "⢀⣴⡿⠋⠻⣶⡿⠁⢀⣴⡟⠁⠀⠀⣨⣿⠟⢹⡏⠀⣼⡏⠀⣸⡇⣀⣠⣴⡿⠋⣄⠈⠻⣿⡁⠀⠹⣷⠀⠙⣷⣄⢀⣽⣿⣦⣄⡀⠀" },
  { 4, "⣿⡉⢀⣠⣴⠟⠁⣠⡾⢿⣦⣀⡀⣸⣟⠁⢀⣼⣧⣤⣿⠀⢀⣿⢉⣟⣹⣿⠀⠀⣿⠀⠀⠘⣷⣴⡶⢿⡇⠀⠈⠻⣿⣏⠀⠈⠙⣿⡄" },
  { 4, "⠙⠛⠛⠋⠁⠀⣴⡟⠁⠀⣽⡿⠋⣿⠛⠻⣿⠃⠈⠉⠻⢷⣾⠋⠈⢙⣿⣿⣴⣶⣿⠀⠀⠀⣿⡀⠀⠘⣷⠀⠀⠀⠈⠛⠿⠶⠶⠟⠀" },
  { 4, "⠀⠀⠀⠀⢀⣾⢿⣦⣠⣾⠋⠀⢀⣿⠀⢀⣿⠀⠀⠀⠀⣼⣧⣄⣠⡿⠉⣿⠀⠀⣿⡀⠀⠀⢸⣇⠀⠀⢻⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀" },
  { 5, "⠀⠀⠀⢠⣾⠃⠀⣸⡿⠁⠀⠀⣼⡿⠷⣾⠇⠀⠀⠀⠀⣿⠉⠉⣿⡇⠀⣿⣄⣤⣬⡀⠀⠀⠀⢿⣶⡶⠿⣿⡄⠀⠀⠀⠀⠀⠀⠀⠀" },
  { 5, "⠀⠀⢠⣿⣧⣄⣴⡟⠁⠀⠀⢸⣟⠀⣴⡟⠀⠀⠀⠀⠀⣿⣄⣀⣿⡇⠀⣿⡏⠉⢹⣇⠀⠀⠀⠘⣿⡄⠀⠹⣷⠀⠀⠀⠀⠀⠀⠀⠀" },
  { 5, "⠀⢠⣿⠁⠈⣽⠟⠀⠀⠀⠀⠈⠛⠟⠋⠀⠀⠀⠀⠀⠀⣿⡉⠉⢻⡇⠀⢸⣇⠀⠘⣿⡀⠀⠀⠀⠈⢿⣦⣴⡿⠀⠀⠀⠀⠀⠀⠀⠀" },
  { 5, "⠀⠘⠿⣦⣾⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⠷⡶⠿⠃⠀⠘⣿⣤⡶⢿⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀" },
  { 6, "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢿⡇⠀⠘⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀" },
  { 6, "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⡀⠀⣿⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀" },
  { 6, "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⢷⣶⠟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀" },
}

local function spider_header()
  local section = { padding = 1 }
  for _, row in ipairs(dashboard_spider) do
    table.insert(section, { text = { { row[2], hl = "DashSpider" .. row[1] } }, align = "center" })
  end
  return section
end

-- Claude Code keeps every conversation in ~/.claude/projects/<dir>/<id>.jsonl.
-- Files can be many MB, so only the start (title, folder, first prompts) and
-- the end (a later /rename) of each file are read.
local function read_head_tail(path, size)
  local fh = io.open(path, "r")
  if not fh then return "" end
  local head = fh:read(256 * 1024) or ""
  local tail = ""
  if size > 320 * 1024 then
    fh:seek("set", size - 64 * 1024)
    tail = fh:read("*a") or ""
  end
  fh:close()
  return head .. "\n" .. tail
end

local function first_prompts(data, max)
  local prompts = {}
  for line in data:gmatch("[^\n]+") do
    if #prompts >= max then break end
    if line:find('"type":"user"', 1, true) then
      local ok, d = pcall(vim.json.decode, line)
      local c = ok and type(d) == "table" and d.message and d.message.content
      local text = type(c) == "string" and c
        or (type(c) == "table" and c[1] and c[1].type == "text" and c[1].text)
      if text and not text:match("^%s*<") and not text:match("^%[Image")
        and not text:match("^%[Request interrupted") then
        table.insert(prompts, vim.trim(text))
      end
    end
  end
  return prompts
end

local function claude_sessions(limit)
  local files = vim.fn.glob(vim.fn.expand("~/.claude/projects") .. "/*/*.jsonl", false, true)
  local list = {}
  for _, f in ipairs(files) do
    local st = vim.uv.fs_stat(f)
    if st and st.size > 0 then table.insert(list, { path = f, mtime = st.mtime.sec, size = st.size }) end
  end
  table.sort(list, function(a, b) return a.mtime > b.mtime end)

  local out = {}
  for _, entry in ipairs(list) do
    if #out >= limit then break end
    local data = read_head_tail(entry.path, entry.size)
    -- Title priority: your /rename, then Claude's auto title, then the first prompt.
    local title
    for t in data:gmatch('"customTitle":"(.-)","') do title = t end
    if not title then for t in data:gmatch('"aiTitle":"(.-)","') do title = t end end
    local prompts = first_prompts(data, 5)
    title = title or prompts[1]
    local cwd = data:match('"cwd":"(.-)"')
    if title and cwd then
      title = title:gsub("\\n", " "):gsub('\\"', '"'):gsub("%s+", " ")
      table.insert(out, {
        id = vim.fn.fnamemodify(entry.path, ":t:r"),
        cwd = cwd,
        title = vim.trim(title),
        prompts = prompts,
        mtime = entry.mtime,
      })
    end
  end
  return out
end

local function time_ago(sec)
  local d = os.time() - sec
  if d < 3600 then return math.max(1, math.floor(d / 60)) .. "m ago" end
  if d < 86400 then return math.floor(d / 3600) .. "h ago" end
  return math.floor(d / 86400) .. "d ago"
end

-- Claude runs in a big floating terminal.
local function open_claude(args, cwd)
  local cmd = vim.list_extend({ "claude" }, args or {})
  Snacks.terminal.open(cmd, {
    cwd = cwd,
    win = { position = "float", width = 0.92, height = 0.9, border = "rounded", title = " Claude ", title_pos = "center" },
  })
end

-- Picker: recent Claude sessions from every folder. Enter resumes one.
local function pick_claude_sessions()
  local items = {}
  for i, s in ipairs(claude_sessions(40)) do
    local where = vim.fn.fnamemodify(s.cwd, ":~")
    local lines = {
      "# " .. s.title, "",
      "- **Folder:** `" .. where .. "`",
      "- **Last active:** " .. os.date("%a %b %d, %I:%M %p", s.mtime) .. " (" .. time_ago(s.mtime) .. ")",
      "- **Session:** `" .. s.id .. "`", "",
      "## First prompts", "",
    }
    for _, pr in ipairs(s.prompts) do
      table.insert(lines, "> " .. vim.fn.strcharpart(pr:gsub("\n", " "), 0, 300))
      table.insert(lines, "")
    end
    table.insert(items, {
      idx = i,
      text = s.title .. " " .. where,
      session = s,
      where = vim.fn.fnamemodify(s.cwd, ":t"),
      ago = time_ago(s.mtime),
      preview = { text = table.concat(lines, "\n"), ft = "markdown" },
    })
  end
  Snacks.picker.pick({
    title = "Claude Sessions",
    items = items,
    preview = "preview",
    format = function(item)
      return {
        { "\u{f06a9}  ", "SnacksDashboardIcon" },
        { vim.fn.strcharpart(item.session.title, 0, 60), "SnacksPickerFile" },
        { "  " .. item.where, "SnacksPickerDir" },
        { "  " .. item.ago, "SnacksPickerComment" },
      }
    end,
    confirm = function(picker, item)
      picker:close()
      if item then open_claude({ "--resume", item.session.id }, item.session.cwd) end
    end,
  })
end

-- Picker: folders in ~/Projects. Enter moves nvim into the project and
-- lists its files.
local function pick_projects()
  local root = vim.fn.expand("~/Projects")
  local items = {}
  for name, kind in vim.fs.dir(root) do
    if kind == "directory" and not name:match("^%.") then
      table.insert(items, { text = name, file = root .. "/" .. name, dir = true })
    end
  end
  table.sort(items, function(a, b) return a.text:lower() < b.text:lower() end)
  Snacks.picker.pick({
    title = "Projects",
    items = items,
    format = function(item)
      return { { "\u{f07b}  ", "Directory" }, { item.text, "SnacksPickerFile" } }
    end,
    confirm = function(picker, item)
      picker:close()
      if not item then return end
      vim.cmd.cd(item.file)
      Snacks.picker.files({ cwd = item.file })
    end,
  })
end

-- GitHub through the `gh` CLI. The top entries work from any folder; the
-- "this repo" ones only appear when nvim is inside a git repository.
local function gh_json(args)
  local res = vim.system(vim.list_extend({ "gh" }, args), { text = true }):wait()
  if res.code ~= 0 then
    vim.notify("gh " .. table.concat(args, " ") .. " failed:\n" .. (res.stderr or ""), vim.log.levels.ERROR)
    return {}
  end
  local ok, data = pcall(vim.json.decode, res.stdout)
  return ok and data or {}
end

local function pick_links(title, icon, rows)
  if #rows == 0 then
    vim.notify(title .. ": nothing found", vim.log.levels.INFO)
    return
  end
  Snacks.picker.pick({
    title = title,
    items = rows,
    layout = { preset = "select" },
    format = function(item)
      return { { icon .. "  ", "SnacksDashboardIcon" }, { item.text, "SnacksPickerFile" }, { "  " .. item.label, "SnacksPickerDir" } }
    end,
    confirm = function(picker, item)
      picker:close()
      if item then vim.ui.open(item.url) end
    end,
  })
end

local function gh_search(kind, filter, title, icon)
  local rows = {}
  for _, it in ipairs(gh_json({ "search", kind, filter, "--state=open", "--limit=50", "--json=title,number,repository,url" })) do
    table.insert(rows, { text = it.title, label = it.repository.nameWithOwner .. " #" .. it.number, url = it.url })
  end
  pick_links(title, icon, rows)
end

local function pick_github()
  local items = {
    { text = "My open pull requests", icon = "\u{f407}", run = function() gh_search("prs", "--author=@me", "My open pull requests", "\u{f407}") end },
    { text = "Pull requests to review", icon = "\u{f0cc}", run = function() gh_search("prs", "--review-requested=@me", "Review requested", "\u{f0cc}") end },
    { text = "Issues assigned to me", icon = "\u{f41b}", run = function() gh_search("issues", "--assignee=@me", "Assigned issues", "\u{f41b}") end },
    { text = "My repositories", icon = "\u{f401}", run = function()
      local rows = {}
      for _, r in ipairs(gh_json({ "repo", "list", "--limit=100", "--json=nameWithOwner,description,url" })) do
        table.insert(rows, { text = r.nameWithOwner, label = r.description or "", url = r.url })
      end
      pick_links("My repositories", "\u{f401}", rows)
    end },
    { text = "Notifications (browser)", icon = "\u{f0f3}", run = function() vim.ui.open("https://github.com/notifications") end },
  }
  if Snacks.git.get_root() then
    vim.list_extend(items, {
      { text = "This repo: pull requests", icon = "\u{f407}", run = function() Snacks.picker.gh_pr() end },
      { text = "This repo: issues", icon = "\u{f41b}", run = function() Snacks.picker.gh_issue() end },
      { text = "This repo: open in browser", icon = "\u{f0ac}", run = function() Snacks.gitbrowse() end },
    })
  end
  Snacks.picker.pick({
    title = "GitHub",
    items = items,
    layout = { preset = "select" },
    format = function(item) return { { item.icon .. "  ", "SnacksDashboardIcon" }, { item.text, "SnacksPickerFile" } } end,
    confirm = function(picker, item)
      picker:close()
      if item then vim.schedule(item.run) end
    end,
  })
end

-- The tab bar is just an empty strip on the start screen, so hide it there.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "snacks_dashboard",
  callback = function(ev)
    vim.o.showtabline = 0
    vim.api.nvim_create_autocmd("BufLeave", {
      buffer = ev.buf,
      once = true,
      callback = function() vim.o.showtabline = 2 end,
    })
  end,
})

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

local lsp_servers = {
  "lua_ls",
  "basedpyright",
  "ruff",
  "vtsls",
  "eslint",
  "jsonls",
  "yamlls",
  "html",
  "cssls",
  "tailwindcss",
  "bashls",
  "dockerls",
  "taplo",
  "marksman",
  "markdown_oxide",
  "gopls",
  "rust_analyzer",
  "clangd",
  "terraformls",
  "graphql",
  "prismals",
}

require("lazy").setup({
  -- Kanagawa: ink-wash colourway modelled on a Hokusai woodblock. Desaturated
  -- violet keywords, moss strings, chalk-blue functions, muted aqua types.
  --
  -- transparent = true is the point: Kanagawa never paints a background, so
  -- Ghostty's #0b0713 and its blur show through exactly as before. The
  -- bg = none overrides in apply_coding_highlights() cover the plugin
  -- surfaces Kanagawa's own transparency does not reach.
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 1100,
    config = function()
      require("kanagawa").setup({
        theme = "wave",
        background = { dark = "wave" },
        transparent = true,
        dimInactive = false,
        commitStyle    = { italic = true },
        keywordStyle   = { italic = false, bold = true },
        statementStyle = { bold = true },
        colors = {
          theme = {
            all = {
              ui = {
                bg_gutter = "none",  -- keep the sign column transparent too
              },
            },
          },
        },
      })
      vim.cmd.colorscheme("kanagawa")
      apply_coding_highlights()
    end,
  },

  -- Tooling installation
  { "mason-org/mason.nvim", build = ":MasonUpdate", opts = {} },
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
    opts = {
      ensure_installed = lsp_servers,
      automatic_enable = true,
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      ensure_installed = {
        "stylua",
        "prettier",
        "shfmt",
        "shellcheck",
        "eslint_d",
        "black",
        "isort",
        "goimports",
        "gofumpt",
        "markdownlint-cli2",
        "codelldb",
      },
    },
  },

  -- Language intelligence
  { "neovim/nvim-lspconfig" },
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {},
  },
  {
    "Saghen/blink.cmp",
    version = "1.*",
    opts = {
      keymap = { preset = "default" },
      appearance = { nerd_font_variant = "mono" },
      completion = { documentation = { auto_show = true } },
      signature = { enabled = true },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    opts = {
      ensure_installed = {
        "bash",
        "c",
        "cpp",
        "css",
        "dockerfile",
        "go",
        "html",
        "javascript",
        "json",
        "lua",
        "markdown",
        "markdown_inline",
        "python",
        "query",
        "rust",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
        "yaml",
      },
    },
    config = function(_, opts)
      local ts = require("nvim-treesitter")
      ts.install(opts.ensure_installed):wait(300000)

      vim.api.nvim_create_autocmd("FileType", {
        callback = function(event)
          local ok = pcall(vim.treesitter.start, event.buf)
          if ok then
            vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
  {
    "HiPhish/rainbow-delimiters.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      local rainbow_delimiters = require("rainbow-delimiters")
      vim.g.rainbow_delimiters = {
        strategy = {
          [""] = rainbow_delimiters.strategy["global"],
        },
        query = {
          [""] = "rainbow-delimiters",
          lua = "rainbow-blocks",
        },
        highlight = {
          "RainbowDelimiterRed",
          "RainbowDelimiterYellow",
          "RainbowDelimiterBlue",
          "RainbowDelimiterOrange",
          "RainbowDelimiterGreen",
          "RainbowDelimiterViolet",
          "RainbowDelimiterCyan",
        },
      }
      apply_coding_highlights()
    end,
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      indent = { char = "│", tab_char = "│" },
      scope = {
        enabled = true,
        show_start = false,
        show_end = false,
        highlight = { "IblScope" },
      },
    },
  },

  -- Formatting and linting
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        json = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        html = { "prettier" },
        css = { "prettier" },
        python = { "isort", "black" },
        sh = { "shfmt" },
        go = { "goimports", "gofumpt" },
        rust = { "rustfmt" },
      },
      format_on_save = {
        timeout_ms = 1500,
        lsp_format = "fallback",
      },
    },
    keys = {
      {
        "<leader>f",
        function()
          require("conform").format({ async = true, lsp_format = "fallback" })
        end,
        mode = { "n", "v" },
        desc = "Format buffer",
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        javascript = { "eslint_d" },
        javascriptreact = { "eslint_d" },
        typescript = { "eslint_d" },
        typescriptreact = { "eslint_d" },
        markdown = { "markdownlint-cli2" },
        sh = { "shellcheck" },
      }
      -- Disable MD013 (line length) for markdown -- common for long docs/notes
      lint.linters["markdownlint-cli2"] = {
        args = { "--disable", "MD013", "--" },
      }
      vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
        callback = function()
          lint.try_lint()
        end,
      })
    end,
  },

  -- Markdown rendering for nicer, Notion-like editing experience (2026 recommended)
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    ft = { "markdown" },
    opts = {
      heading = { enabled = true, sign = false },
      code = { enabled = true, style = "full" },
      bullet = { enabled = true },
      checkbox = { enabled = true },
    },
  },

  -- Navigation and UI
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false, -- the start screen has to exist before the first buffer
    opts = {
      picker = {},
      explorer = {},
      input = {},
      lazygit = {},
      notifier = {},
      terminal = {},
      bigfile = {},      -- turn heavy features off for huge files
      quickfile = {},    -- draw `nvim file` before plugins finish loading
      statuscolumn = {}, -- IDE gutter: signs, git, folds
      words = {},        -- highlight references under the cursor
      scroll = {},       -- smooth scrolling
      dashboard = {
        width = 50,
        preset = {
          -- stylua: ignore
          keys = {
            { icon = "\u{f06a9} ", key = "c", desc = "> Claude Sessions", action = function() pick_claude_sessions() end },
            { icon = "\u{f0c5} ", key = "r", desc = "> Recent Files", action = function() Snacks.picker.recent() end },
            { icon = "\u{f07b} ", key = "p", desc = "> Projects", action = function() pick_projects() end },
            { icon = "\u{f09b} ", key = "g", desc = "> GitHub", action = function() pick_github() end },
            { icon = "\u{f11c} ", key = "?", desc = "> Keymaps", action = function() Snacks.picker.keymaps() end },
            { icon = "\u{f021} ", key = "s", desc = "> Restore Session", action = function() require("persistence").load() end },
            { icon = "\u{f057} ", key = "q", desc = "> Quit", action = ":qa" },
          },
        },
        sections = {
          spider_header,
          { section = "keys", gap = 1, padding = 1 },
          { section = "startup" },
        },
      },
    },
    keys = {
      { "<leader>.", function() Snacks.explorer() end, desc = "File browser" },
      { "<leader>ac", function() pick_claude_sessions() end, desc = "Claude sessions" },
      { "<leader>P", function() pick_projects() end, desc = "Projects" },
      { "<leader>G", function() pick_github() end, desc = "GitHub" },
      { "<leader>K", function() Snacks.picker.keymaps() end, desc = "Search keymaps" },
      { "<leader>r", function() Snacks.picker.recent() end, desc = "Recent files" },
      { "<leader>u", function() Snacks.picker.undo() end, desc = "Undo tree" },
      { "]]", function() Snacks.words.jump(vim.v.count1) end, desc = "Next reference" },
      { "[[", function() Snacks.words.jump(-vim.v.count1) end, desc = "Previous reference" },
      { "<leader><space>", function() Snacks.picker.files() end, desc = "Find files" },
      { "<leader>/", function() Snacks.picker.grep() end, desc = "Grep" },
      { "<leader>,", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { "<leader>e", function() Snacks.explorer() end, desc = "Explorer" },
      { "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit" },
      { "<leader>gl", function() Snacks.lazygit.log() end, desc = "Git log" },
      { "<leader>gL", function() Snacks.lazygit.log_file() end, desc = "File git log" },
      { "<leader>sd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
      { "<leader>ss", function() Snacks.picker.lsp_symbols() end, desc = "Symbols" },
      { "<leader>tt", function() Snacks.terminal.toggle() end, desc = "Terminal" },
    },
  },
  {
    "stevearc/oil.nvim",
    opts = {},
    keys = {
      { "-", "<cmd>Oil<cr>", desc = "Open parent directory" },
    },
    dependencies = { { "nvim-mini/mini.icons", opts = {} } },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "classic", -- full-width panel along the bottom
      delay = 250,
      win = { border = "none", padding = { 1, 4 } },
      layout = { spacing = 6 },
      icons = { separator = "\u{2192}", group = "+", mappings = false },
      spec = {
        { "<leader>a", group = "AI" },
        { "<leader>b", group = "Buffers / tabs" },
        { "<leader>c", group = "Code" },
        { "<leader>d", group = "Debug" },
        { "<leader>g", group = "Git" },
        { "<leader>o", group = "GitHub (Octo)" },
        { "<leader>q", group = "Session" },
        { "<leader>s", group = "Search" },
        { "<leader>t", group = "Terminal" },
        { "<leader>x", group = "Trouble" },
      },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = function()
      local p = palette
      return {
        options = {
          theme = lualine_purple(),
          globalstatus = true,
          section_separators = { left = "", right = "" },
          component_separators = { left = "", right = "" },
        },
        sections = {
          lualine_a = {
            { "mode", icon = "", separator = { right = "" }, padding = { left = 1, right = 1 } },
          },
          lualine_b = {
            { "branch", icon = "", color = { fg = p.purple_lt } },
            {
              "diff",
              symbols = { added = " ", modified = " ", removed = " " },
              diff_color = {
                added    = { fg = p.green },
                modified = { fg = p.lavender },
                removed  = { fg = p.red },
              },
            },
          },
          lualine_c = {
            {
              "filename",
              path = 1,
              symbols = { modified = " ", readonly = " ", unnamed = "[No Name]" },
              color = { fg = p.fg_dim },
            },
            {
              "diagnostics",
              symbols = { error = " ", warn = " ", info = " ", hint = " " },
              diagnostics_color = {
                error = { fg = p.red },
                warn  = { fg = p.yellow },
                info  = { fg = p.cyan },
                hint  = { fg = p.lavender },
              },
            },
          },
          lualine_x = {
            { "filetype", icon_only = false, color = { fg = p.muted } },
          },
          lualine_y = {
            { "progress", color = { fg = p.lavender } },
          },
          lualine_z = {
            { "location", separator = { left = "" }, padding = { left = 1, right = 1 } },
          },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { { "filename", path = 1, color = { fg = p.muted } } },
          lualine_x = {},
          lualine_y = {},
          lualine_z = {},
        },
      }
    end,
  },
  {
    "folke/trouble.nvim",
    opts = {},
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix" },
      { "grr", "<cmd>Trouble lsp_references toggle<cr>", desc = "References" },
    },
  },

  -- IDE chrome: tab bar, breadcrumbs, outline, sessions, auto pairs
  {
    "akinsho/bufferline.nvim",
    version = "*",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local p = palette
      require("bufferline").setup({
        options = {
          mode = "buffers",
          diagnostics = "nvim_lsp",
          indicator = { style = "underline" },
          separator_style = { "", "" },
          show_buffer_close_icons = true,
          always_show_bufferline = true,
          close_command = function(n) Snacks.bufdelete(n) end,
          right_mouse_command = function(n) Snacks.bufdelete(n) end,
          diagnostics_indicator = function(_, _, diag)
            local out = {}
            if diag.error then table.insert(out, "\u{f057} " .. diag.error) end
            if diag.warning then table.insert(out, "\u{f071} " .. diag.warning) end
            return table.concat(out, " ")
          end,
          offsets = {
            { filetype = "snacks_layout_box", text = "\u{f07c}  Explorer", highlight = "Directory", separator = false },
            { filetype = "aerial", text = "\u{f0b1a}  Outline", highlight = "Directory", separator = false },
          },
        },
        highlights = {
          buffer_selected     = { fg = p.fg, bold = true, italic = false },
          indicator_selected  = { fg = p.purple, sp = p.purple },
          modified_selected   = { fg = p.magenta },
          close_button_selected = { fg = p.pink },
          pick_selected       = { fg = p.magenta, bold = true },
          pick_visible        = { fg = p.magenta, bold = true },
          pick                = { fg = p.magenta, bold = true },
        },
      })

      -- Keep the tab bar see-through like the rest of the UI: strip every
      -- BufferLine* background so Ghostty's blur shows behind it.
      local function clear_bg()
        for name in pairs(vim.api.nvim_get_hl(0, {})) do
          if name:find("^BufferLine") then
            local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
            hl.bg, hl.ctermbg = nil, nil
            vim.api.nvim_set_hl(0, name, hl)
          end
        end
      end
      clear_bg()
      vim.api.nvim_create_autocmd("ColorScheme", { callback = function() vim.schedule(clear_bg) end })
      if vim.bo.filetype == "snacks_dashboard" then vim.o.showtabline = 0 end
    end,
    keys = {
      { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Previous tab" },
      { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Next tab" },
      { "<leader>bp", "<cmd>BufferLineTogglePin<cr>", desc = "Pin tab" },
      { "<leader>bP", "<cmd>BufferLineGroupClose ungrouped<cr>", desc = "Close unpinned tabs" },
      { "<leader>bo", "<cmd>BufferLineCloseOthers<cr>", desc = "Close other tabs" },
      { "<leader>bl", "<cmd>BufferLineCloseLeft<cr>", desc = "Close tabs to the left" },
      { "<leader>br", "<cmd>BufferLineCloseRight<cr>", desc = "Close tabs to the right" },
      { "<leader>bb", "<cmd>BufferLinePick<cr>", desc = "Pick a tab" },
    },
  },
  {
    "Bekaboo/dropbar.nvim", -- VS Code-style breadcrumbs along the top of each window
    event = { "BufReadPost", "BufNewFile" },
    opts = {},
  },
  {
    "stevearc/aerial.nvim", -- code outline sidebar
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    cmd = { "AerialToggle", "AerialOpen" },
    opts = {
      backends = { "lsp", "treesitter", "markdown", "man" },
      layout = { default_direction = "right", min_width = 30 },
      show_guides = true,
      filter_kind = false,
    },
    keys = {
      { "<leader>cs", "<cmd>AerialToggle<cr>", desc = "Code outline" },
    },
  },
  {
    "folke/persistence.nvim", -- per-folder sessions (reopen your tabs and splits)
    event = "BufReadPre",
    opts = {},
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore session (this folder)" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore last session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Don't save this session" },
    },
  },
  {
    "nvim-mini/mini.pairs", -- auto-close brackets and quotes
    event = "InsertEnter",
    opts = {},
  },

  -- Git and code review
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      current_line_blame = true,
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local function bmap(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end
        bmap("n", "]h", function() gs.nav_hunk("next") end, "Next hunk")
        bmap("n", "[h", function() gs.nav_hunk("prev") end, "Previous hunk")
        bmap("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
        bmap("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
        bmap("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
        bmap("v", "<leader>hs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Stage hunk")
        bmap("v", "<leader>hr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Reset hunk")
      end,
    },
  },
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewRefresh",
      "DiffviewFileHistory",
    },
    keys = {
      {
        "<leader>ga",
        function()
          vim.cmd("silent! checktime")
          vim.cmd("DiffviewOpen")
          vim.schedule(function()
            vim.cmd("DiffviewFocusFiles")
          end)
        end,
        desc = "Live agent changes",
      },
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Open diff review" },
      { "<leader>gD", "<cmd>DiffviewOpen origin/main...HEAD<cr>", desc = "Review branch diff" },
      { "<leader>gc", "<cmd>DiffviewClose<cr>", desc = "Close diff review" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
    },
  },
  {
    "pwntester/octo.nvim",
    cmd = "Octo",
    opts = {
      picker = "snacks",
      enable_builtin = true,
    },
    keys = {
      { "<leader>op", "<cmd>Octo pr list<cr>", desc = "GitHub PRs" },
      { "<leader>oi", "<cmd>Octo issue list<cr>", desc = "GitHub issues" },
      { "<leader>or", "<cmd>Octo review<cr>", desc = "Review PR" },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "folke/snacks.nvim",
      "nvim-tree/nvim-web-devicons",
    },
  },
  -- Real Material Icon Theme assets (the VS Code one), rendered as actual
  -- images through Ghostty's graphics protocol rather than Nerd Font glyphs.
  -- `build` downloads the theme; needs ImageMagick for the SVG conversion.
  -- Integrations are opt-in, so only the three we actually use are on.
  {
    "Mirsmog/real-icons.nvim",
    build = ":RealIcons install",
    opts = {
      integrations = {
        oil = true,
        snacks_picker = true,
        lualine = true,
      },
    },
  },
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
    keys = {
      { "<leader>st", function() Snacks.picker.todo_comments() end, desc = "Todo comments" },
    },
  },

  -- Debugging
  { "mfussenegger/nvim-dap" },
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup()

      local mason_path = vim.fn.stdpath("data") .. "/mason/packages/codelldb"
      local codelldb = mason_path .. "/extension/adapter/codelldb"
      local liblldb = mason_path .. "/extension/lldb/lib/liblldb.dylib"

      if vim.fn.executable(codelldb) == 1 and vim.fn.filereadable(liblldb) == 1 then
        dap.adapters.codelldb = {
          type = "server",
          port = "${port}",
          executable = {
            command = codelldb,
            args = { "--liblldb", liblldb, "--port", "${port}" },
          },
        }

        dap.configurations.rust = {
          {
            name = "Debug Rust executable",
            type = "codelldb",
            request = "launch",
            program = function()
              return vim.fn.input("Executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
            end,
            cwd = "${workspaceFolder}",
            stopOnEntry = false,
          },
        }
      end

      dap.listeners.before.attach.dapui_config = function() dapui.open() end
      dap.listeners.before.launch.dapui_config = function() dapui.open() end
      dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
      dap.listeners.before.event_exited.dapui_config = function() dapui.close() end
    end,
    keys = {
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle breakpoint" },
      { "<leader>dc", function() require("dap").continue() end, desc = "Debug continue" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Step into" },
      { "<leader>do", function() require("dap").step_over() end, desc = "Step over" },
      { "<leader>dO", function() require("dap").step_out() end, desc = "Step out" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "Debug UI" },
      { "<leader>dr", function() require("dap").repl.open() end, desc = "Debug REPL" },
      { "<leader>dt", function() require("dap").terminate() end, desc = "Debug terminate" },
    },
  },
})

local ok_blink, blink = pcall(require, "blink.cmp")
if ok_blink then
  vim.lsp.config("*", {
    capabilities = blink.get_lsp_capabilities(),
  })
end

vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      diagnostics = { globals = { "vim" } },
      workspace = { checkThirdParty = false },
    },
  },
})

vim.lsp.config("rust_analyzer", {
  settings = {
    ["rust-analyzer"] = {
      cargo = {
        allTargets = true,
        buildScripts = { enable = true },
      },
      check = {
        command = "clippy",
        allTargets = true,
      },
      procMacro = { enable = true },
      inlayHints = {
        bindingModeHints = { enable = true },
        chainingHints = { enable = true },
        closureReturnTypeHints = { enable = "always" },
        lifetimeElisionHints = { enable = "skip_trivial" },
        parameterHints = { enable = true },
        typeHints = { enable = true },
      },
    },
  },
})

vim.lsp.config("marksman", {
  init_options = {
    config = {
      markdown = {
        validate = {
          enabled = true,
          unrecognized_links = "warning",
          fragment_links = "warning",
          file_links = "warning",
          ignored_links = {},
        },
      },
    },
  },
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.conceallevel = 2
    vim.opt_local.concealcursor = "nc"
  end,
})

vim.diagnostic.config({
  virtual_text = { spacing = 2, source = "if_many" },
  severity_sort = true,
  float = { border = "rounded", source = true },
})

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(event)
    local opts = { buffer = event.buf }
    map("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Go to definition" }))
    map("n", "gD", vim.lsp.buf.declaration, vim.tbl_extend("force", opts, { desc = "Go to declaration" }))
    map("n", "gi", vim.lsp.buf.implementation, vim.tbl_extend("force", opts, { desc = "Go to implementation" }))
    map("n", "grn", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "Rename symbol" }))
    map("n", "gra", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "Code action" }))
    map("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Hover docs" }))
    map("n", "<leader>ld", vim.diagnostic.open_float, vim.tbl_extend("force", opts, { desc = "Line diagnostics" }))
    map("n", "[d", vim.diagnostic.goto_prev, vim.tbl_extend("force", opts, { desc = "Previous diagnostic" }))
    map("n", "]d", vim.diagnostic.goto_next, vim.tbl_extend("force", opts, { desc = "Next diagnostic" }))

    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client.name == "rust_analyzer" and client:supports_method("textDocument/inlayHint") then
      vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
    end
  end,
})
