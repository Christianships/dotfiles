# dotfiles

My `~/.config`: the configuration side of **MACH**, my macOS desktop setup.
It's a tiling setup (AeroSpace) with a glass SketchyBar and Ghostty, all in one
purple theme (`#0b0713` background, `#a855f7` violet), plus a handful of small
apps of my own that live in the menu bar.

**Key naming:** *Super* is the corner key, remapped to Ctrl, and it drives
AeroSpace. The physical Ctrl key sends Globe, which Hammerspoon turns into a
vim-style typing layer inside Ghostty.

## What's here

| Folder | What it is |
|---|---|
| `aerospace/` | Tiling window manager: bindings, a dwindle layout, home workspaces, the keybinding overlay (`keys.sh`), the agent grid, and float rules for the MouseSkins and Mach Saver panels |
| `sketchybar/` | The bar: AeroSpace workspaces, current calendar event, clock, battery, CPU/GPU/RAM pills (click for Instances), Claude Code usage and cost, and OBS status |
| `ghostty/` | Terminal config, shaders and themes |
| `fastfetch/` | System info with the braille jet logo (the same art as the Mach Saver screensaver). `scripts/jet-spin.py` animates it; the spider and strawberry logos are still there to switch to |
| `zsh/.zshrc` | Shell setup, including the animated fastfetch jet in the first Ghostty shell |
| `nvim/` | Neovim; the start screen shows the jet or the spider (`:Logo`, or `l` on the start screen) |
| `hammerspoon/` | The Globe typing layer: move and erase on the command line with h/l, b/w, a/e, k/j |
| `starship.toml`, `tmux/`, `btop/`, `git/`, `yazi/`, `zed/` | Prompt, tmux, btop, global gitignore, file manager, editor prompts |
| `obs/` | Stream overlays and scripts used by Director, my OBS toolkit |
| `mousecape/` | Cursor tools: `win2cape.py` turns Windows `.cur`/`.ani` packs into `.cape` files (which MouseSkins loads), `make_netherite.py` builds the Minecraft Netherite skin |
| `helium-geo/` | A browser extension that spoofs geolocation in Helium |
| `DayBar.js` | A Scriptable widget for the day's calendar |
| `dev-help/` | Notes |

## Keys worth knowing

| Keys | Does |
|---|---|
| Super + Enter | New Ghostty window |
| Super + B | New Search (browser) window |
| Super + H/J/K/L (or arrows) | Focus; add Shift to move the window |
| Super + F | Fullscreen |
| Super + / and Super + , | Tiles / accordion layout |
| Super + Shift + / | Keybinding overlay |
| Super + Shift + T | Grid of agent terminals |
| **Super + \|** | **Show the Mach Saver screensaver** |
| Super + Alt + … | OBS scenes, recording and streaming (Director) |

The full list is in `aerospace/aerospace.toml`, or press Super + Shift + /.

## The MACH apps

Small apps of my own that go with this config:

| App | What it does |
|---|---|
| [mach-boot](https://github.com/Christianships/mach-boot) | Boot screens that play once at login |
| [mach-saver](https://github.com/Christianships/mach-saver) | Keeps the Mac awake only while an agent is working, and shows a screensaver (MACH over the jet, with Omarchy-style text effects) when I step away. Super + \| shows it on demand |
| [MouseSkins](https://github.com/Christianships/MouseSkins) | System-wide cursor skins (I use Minecraft Netherite), with a Minecraft sword swing on every click |
| [Cream](https://github.com/Christianships/Cream) | Mechanical-keyboard and mouse click sounds (NK Cream) |
| Instances (private) | Running apps and processes, with quit/kill. Opens from the SketchyBar system pills |
| Director (private) | OBS scenes, overlays and camera control, driven by the Super + Alt bindings |

## Changes on 2026-09-27 → 28

**These dotfiles**
- AeroSpace: floats the MouseSkins panel and the Mach Saver panel; **Super + |**
  shows the Mach Saver screensaver.
- fastfetch: the logo is now the purple braille jet, with square box corners
  and headers. `jet-spin.py` animates it: it can spin the jet like a 3D
  viewport or fly jets in circles. As a fastfetch logo it holds still, centred
  on the info boxes, with only speed lines moving, behind a live prompt.
- zsh: `.zshrc` is tracked here now.
- Neovim: `:Logo` switches the start screen between the spider and the jet.

**[MouseSkins](https://github.com/Christianships/MouseSkins)**: new tonight,
replacing Mousecape (it started as `msig`). A menu bar app and CLI with a
floating panel (Home, Skins, Edit, Settings), skins downloaded from GitHub,
an app icon, and **Swing on click**: every click swings the sword cursor
like Minecraft.

**[mach-saver](https://github.com/Christianships/mach-saver)**: new tonight.
The Afterburner screensaver (a big centred jet with MACH animated like
Omarchy's screensaver, in Purple, Military, Classic Fire or Mono). It keeps
the Mac awake only while an agent is working, uses little in the background,
and has an app icon, a jet menu bar icon with a quick menu, and a sidebar
panel for saved screensavers, custom colourways and settings.

**[Cream](https://github.com/Christianships/Cream)**: a white mechanical
keycap app icon and menu bar icon, and a fix for the menu bar icon that
never showed.
