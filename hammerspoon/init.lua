-- ── TERMINAL TYPING LAYER ────────────────────────────────────
-- Hold the physical Ctrl key (next to Super) and tap a letter to move or
-- erase on the command line, vim-style. Since the modifier swap, that key
-- sends Globe/fn, which terminals can't see, so this translates it.
-- Only active in Ghostty; everywhere else the key behaves as before.
--
--   Ctrl+H / Ctrl+L     one letter left / right       (vim h / l)
--   Ctrl+B / Ctrl+W     one word back / forward       (vim b / w)
--   Ctrl+A / Ctrl+E     start / end of line
--   Ctrl+K / Ctrl+J     previous / next command       (vim k / j)
--   Ctrl+Backspace      erase word back
--   Ctrl+D              erase whole line              (vim dd)
--   Ctrl+X              erase from cursor to end      ("cut the rest")
--   Ctrl+U              undo                          (vim u)
--   Ctrl+P              paste back what you erased    (vim p)

local TERMINALS = { ["com.mitchellh.ghostty"] = true }

local masks = hs.eventtap.event.rawFlagMasks
-- Device-side bits matter: Ghostty only treats LEFT Option as Alt.
local CTRL = masks.control | masks.deviceLeftControl
local ALT = masks.alternate | masks.deviceLeftAlternate

-- Each entry is a list of keystrokes the shell already understands.
local layer = {
  h = { { "left" } },
  l = { { "right" } },
  b = { { "b", ALT } },          -- Option+B: backward-word
  w = { { "f", ALT } },          -- Option+F: forward-word
  a = { { "a", CTRL } },
  e = { { "e", CTRL } },
  k = { { "p", CTRL } },         -- history search, bound in .zshrc
  j = { { "n", CTRL } },
  delete = { { "w", CTRL } },
  d = { { "u", CTRL } },
  x = { { "x", CTRL }, { "k" } }, -- ^Xk -> kill-line, bound in .zshrc
  u = { { "o", CTRL } },         -- undo, bound in .zshrc
  p = { { "y", CTRL } },
}

local function press(key, flags)
  for _, down in ipairs({ true, false }) do
    local ev = hs.eventtap.event.newKeyEvent(key, down)
    ev:rawFlags(flags or 0)
    ev:post()
  end
end

typingLayer = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(ev)
  local f = ev:getFlags()
  if not f.fn or f.cmd or f.ctrl or f.alt then return false end
  local strokes = layer[hs.keycodes.map[ev:getKeyCode()]]
  if not strokes then return false end
  local app = hs.application.frontmostApplication()
  if not (app and TERMINALS[app:bundleID()]) then return false end
  for _, s in ipairs(strokes) do press(s[1], s[2]) end
  return true
end):start()

-- macOS silently disables event taps that stall; switch it back on.
typingLayerWatchdog = hs.timer.doEvery(5, function()
  if not typingLayer:isEnabled() then typingLayer:start() end
end)
