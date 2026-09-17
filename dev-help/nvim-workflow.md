# Quick reference: Neovim Controls

Open this popup with `Space ?`. Search with `/AeroSpace controls`, `/Neovim controls`, `/Files`, `/Search`, `/Terminal`, `/Git`, `/Troubleshooting`, or the index tags below.

## Directory / jump index

- `[A] AeroSpace controls` — whole macOS app windows and workspaces
- `[N] Neovim controls` — panes, buffers, splits, and core movement
- `[F] Files` — explorer, files, buffers, and project search
- `[T] Terminal controls` — terminal split behavior inside Neovim
- `[C] Code controls` — LSP, diagnostics, autocomplete, and AI definition
- `[G] Git controls` — lazygit, hunks, logs, and review
- `[Q] Troubleshooting` — what to press when something feels stuck

## [A] AeroSpace controls

AeroSpace controls whole app windows, not Neovim panes.

- `Ctrl-h/j/k/l` focus app window left/down/up/right
- `Ctrl-1..0` switch workspace
- `Ctrl-Shift-1..0` move window to workspace and follow it
- `Ctrl-Enter` open Ghostty
- `Ctrl-b` open Safari
- `Ctrl-q` close the current app window
- `Ctrl-r` enter resize mode
- resize mode: `h/j/k/l` resize, `Enter` or `Esc` exits

Note: AeroSpace owns many `Ctrl-*` keys globally, so Neovim may never receive them.

## [N] Neovim controls

Leader key is `Space`: press and release Space, then press the next key.

### Popup controls

- `Space ?` open this cheat sheet
- `:Controls` open this cheat sheet from command mode
- `q` or `Esc` close this popup
- `m` or `Enter` expand/collapse this popup
- `Ctrl-d/u` scroll down/up
- `/text` search inside this popup
- `n` / `N` next / previous search match

### Move around text

- `h/j/k/l` left/down/up/right
- `w` / `b` next / previous word
- `gg` / `G` top / bottom of file
- `/text` search current file
- `n` / `N` next / previous search match

### Move between Neovim panes

- `Space h` focus left pane
- `Space j` focus lower pane
- `Space k` focus upper pane
- `Space l` focus right pane
- `Ctrl-w h/j/k/l` built-in backup

Use `Space h/j/k/l` for Neovim panes because AeroSpace captures `Ctrl-h/j/k/l`.

### Splits and buffers

- `Space |` vertical split
- `Space -` horizontal split
- `Space w` close current Neovim pane/window
- `Space x` close current buffer
- `Space ,` switch/open buffers

### Editing basics

- `i` insert mode
- `Esc` normal mode
- `v` visual selection
- `V` select whole lines
- `:` command mode
- `Ctrl-s` save
- `u` undo
- `Ctrl-r` redo
- `dd` delete line
- `yy` copy line
- `p` paste
- `ciw` change inner word
- `.` repeat last edit
- `<` / `>` indent visual selection
- `Alt-j/k` move selected lines down/up

## [F] Files

### File explorer

- `Space e` open/focus file explorer
- `q` close explorer when cursor is inside it
- `Space w` close explorer pane if focused
- `l` or `Enter` open selected file/directory
- `h` close selected directory
- `Backspace` go up one directory
- `a` add file or directory
- `r` rename
- `d` delete
- `y` yank/copy path
- `p` paste
- `H` toggle hidden files
- `I` toggle ignored files

### Search and grep

- `Space Space` find files
- `Space /` grep/search text across project
- `Space ,` open buffers
- `Space sd` project diagnostics
- `Space ss` symbols
- `Space st` TODO comments

Picker controls:

- `Esc` or `q` close picker
- `Enter` open selected result
- `j/k` move selection in normal picker mode
- `Ctrl-j/k` move selection if AeroSpace lets it through
- `Alt-p` toggle preview
- `Alt-h` toggle hidden files
- `Alt-i` toggle ignored files

## [T] Terminal controls

- `Space tt` toggle Neovim terminal
- double `Esc` leave terminal typing mode
- `q` hide terminal when terminal pane is in normal mode
- `Space w` close terminal pane if focused

If terminal text captures keys: press `Esc` twice, then use `Space h/j/k/l` or `Space w`.

## [C] Code controls

### Code intelligence

- `gd` go to definition
- `gD` go to declaration
- `gi` go to implementation
- `grr` references
- `grn` rename symbol
- `gra` code action
- `K` hover docs
- `Space ld` line diagnostics
- `[d` / `]d` previous / next diagnostic
- `Space sd` project diagnostics
- `Space ss` symbols

### Autocomplete

- `Ctrl-space` show completion and docs
- `Ctrl-n/p` next / previous completion
- `Ctrl-y` accept completion
- `Ctrl-e` close completion
- `Ctrl-k` signature help

### AI Definition

- select code with `v` or `V`
- `Space ad` explain selected code
- type a question or press `Enter`
- close the `AI Definition` split with `Space w` or `q`

### Debugging

- `Space db` toggle debugger breakpoint
- `Space dc` start/continue debugger
- `Space di/do/dO` step into/over/out
- `Space du` toggle debugger UI
- `Space dr` open debugger REPL
- `Space dt` terminate debugging
- `:LspInfo` confirm `rust_analyzer` is attached
- `:Mason` inspect installed language/debug tools

## [G] Git controls

- `Space gg` lazygit
- `Space gl` git log
- `Space gL` current file git log
- `]h` / `[h` next / previous hunk
- `Space hp` preview hunk
- `Space hs` stage hunk
- `Space hr` reset hunk
- `Space ga` open live agent changes
- `Space gd` open diff review
- `Space gc` close diff review
- `Space gh` file history

Inside the live agent changes view:

- changed files stay visible in the left panel
- `Tab` / `Shift-Tab` move through changed files
- `Enter` opens the selected file diff
- `R` forces an immediate refresh
- `Space gc` closes the review
- external agent edits refresh automatically about once per second

## [Q] Troubleshooting

If `Ctrl-h/j/k/l` does nothing inside Neovim:

- expected on this setup; AeroSpace owns those keys globally
- use `Space h/j/k/l`

If the file explorer will not close:

- move focus into it with `Space h`
- press `q` or `Space w`

If terminal text keeps capturing keys:

- press `Esc` twice
- then use `Space h/j/k/l` or `Space w`

If a picker or grep window is open:

- press `Esc` or `q`

If too many files are open:

- `Space ,` shows buffers
- `Space x` closes the current buffer

If Neovim feels stuck:

- press `Esc`
- press `Space ?`
- search this popup with `/Troubleshooting` or `/Neovim controls`
