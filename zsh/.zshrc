# Keystrokes typed while the shell is still loading would otherwise be echoed
# by the tty as stray text above the first prompt (the "cd %" ghost). Turn tty
# echo off for startup; the keys stay buffered and ZLE reads them into the real
# command line. Echo comes back right before the first prompt draws.
if [[ -o interactive && -t 0 ]]; then
  stty -echo
  _typeahead_echo_on() {
    stty echo
    precmd_functions=(${precmd_functions:#_typeahead_echo_on})
    unfunction _typeahead_echo_on
  }
  precmd_functions+=(_typeahead_echo_on)
fi

autoload -U colors && colors
PS1="%{$fg[magenta]%}%n@%m %~%{$reset_color%}$ "

eval "$(starship init zsh)"
# fastfetch, with the jet logo doing one 3D spin before it settles
# (~/.config/fastfetch/scripts/jet-spin.py). Falls back to plain fastfetch.
_fetch() { python3 ~/.config/fastfetch/scripts/jet-spin.py --fetch 2>/dev/null || fastfetch; }
# fastfetch only in the first Ghostty shell of each Ghostty launch. Ghostty is
# one process for all windows/tabs, so its PID identifies the launch; mkdir is
# atomic, so only one shell can claim it even when windows open simultaneously.
# Other terminals (Zed, etc.) are unaffected.
if [[ $TERM_PROGRAM == ghostty ]]; then
  _gpid=$(ps -axo pid=,comm= | awk '$2 ~ /\/ghostty$/ {print $1; exit}')
  if [[ -n $_gpid ]] && mkdir "${TMPDIR:-/tmp}/fastfetch-ghostty-$_gpid" 2>/dev/null; then
    # A new window opens small and AeroSpace resizes it a moment later. fastfetch
    # turns off line wrap, so anything printed before the resize gets clipped.
    # Wait until the size has held for ~0.2s (at most ~1s) before printing.
    _ffsize=$(stty size 2>/dev/null); _ffsame=0
    for _ in {1..20}; do
      sleep 0.05
      if [[ $(stty size 2>/dev/null) == $_ffsize ]]; then
        (( ++_ffsame >= 4 )) && break
      else
        _ffsize=$(stty size 2>/dev/null); _ffsame=0
      fi
    done
    unset _ffsize _ffsame
    _fetch
  fi
  unset _gpid
else
  _fetch
fi
unfunction _fetch

source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# Everything you type at the prompt renders in strong purple (#A855F7, the
# same violet as palette 5 in the Ghostty config). Looping over the token
# types keeps paths, flags, quotes, etc. from falling back to the plugin's
# default green/yellow/underline theme.
_input_purple='fg=#A855F7'
for _tok in default unknown-token reserved-word alias suffix-alias global-alias \
            builtin function command precommand commandseparator hashed-command \
            globbing history-expansion command-substitution-delimiter \
            process-substitution-delimiter arithmetic-expansion \
            single-hyphen-option double-hyphen-option back-quoted-argument \
            single-quoted-argument double-quoted-argument dollar-quoted-argument \
            rc-quote dollar-double-quoted-argument back-double-quoted-argument \
            back-dollar-quoted-argument assign redirection comment named-fd \
            numeric-fd arg0; do
  ZSH_HIGHLIGHT_STYLES[$_tok]=$_input_purple
done
# Paths stay white so they stand out against the purple.
for _tok in path path_pathseparator path_prefix path_prefix_pathseparator autodirectory; do
  ZSH_HIGHLIGHT_STYLES[$_tok]='fg=#FFFFFF'
done
# Comments in bright orange, matching nvim's comment colour.
ZSH_HIGHLIGHT_STYLES[comment]='fg=#FF9500'
unset _tok _input_purple

# Tokens and other secrets live in ~/.zsh_secrets, outside the dotfiles repo.
[[ -f ~/.zsh_secrets ]] && source ~/.zsh_secrets
export PATH="$HOME/.local/bin:$PATH"

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
# <<< grok installer <<<
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

# Zed as the terminal editor (git commits, crontab -e, etc.); --wait blocks until the tab closes
export EDITOR="zed --wait"
export VISUAL="$EDITOR"

# ── FZF ──────────────────────────────────────────────────────
# Ctrl-T = fuzzy-pick a file into the command line, Ctrl-R = search history,
# Alt-C = cd into a directory. fd backs the file/dir sources: it respects
# .gitignore and skips .git, so results are the files you actually care about.
if [[ -o interactive && -t 0 ]]; then
  source <(fzf --zsh)
fi
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS="
  --height 60% --layout=reverse --border=rounded --info=inline
  --color=fg:#ece4fb,bg:-1,hl:#a855f7
  --color=fg+:#ffffff,bg+:#3a2a5c,hl+:#e879f9
  --color=info:#ff9500,prompt:#a855f7,pointer:#e879f9
  --color=marker:#6ee7a0,spinner:#c9a4ff,header:#7c6a9c"
# Preview pane: syntax-highlighted file contents on Ctrl-T, tree on Alt-C.
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :300 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always {}'"

# ── ZOXIDE ───────────────────────────────────────────────────
# `z <partial>` jumps to a directory you've visited before, ranked by
# frequency+recency. `zi` picks interactively through fzf.
eval "$(zoxide init zsh)"

# ── BETTER DEFAULTS ──────────────────────────────────────────
# eza for listings, bat for `cat`. bat detects a non-tty and passes bytes
# through unchanged, so pipes and scripts still behave -- and `catp` is the
# real cat for the cases where you want zero chance of interference.
alias ls='eza --group-directories-first --icons'
alias ll='eza -l --group-directories-first --icons --git --time-style=relative'
alias la='eza -la --group-directories-first --icons --git'
alias lt='eza --tree --level=3 --icons --git-ignore'
alias cat='bat --paging=never'
alias catp='command cat'

# ── LINE EDITING KEYS ────────────────────────────────────────
# "Super" = the bottom-left corner key; the terminal reads it as Ctrl.
# Super = lines, history, control.   Left Option = words.
#
#   Super+A / Super+E   start / end of line        (zsh default)
#   Super+U             erase whole line           (zsh default)
#   Super+W             erase word back            (zsh default)
#   Super+Y             paste back what you erased (zsh default)
#   Super+O             undo              ("Oops")
#   Super+P / Super+N   prev / next command starting with what you've typed
#   Super+R / Super+T   fzf history / fzf file picker  (bound by fzf above)
#   Super+S             stash the line; it returns at the next prompt
#   Super+X Super+E     open the line in $EDITOR, runs when you save + close
#   Option+B / Option+F back / forward a word      (zsh default)
#   Option+Backspace    erase word back            (zsh default)
#   Option+.            insert the previous command's last argument
if [[ -o interactive && -t 0 ]]; then
  # Super+S used to be terminal flow control (the "frozen terminal" trap).
  stty -ixon

  autoload -Uz up-line-or-beginning-search down-line-or-beginning-search edit-command-line
  zle -N up-line-or-beginning-search
  zle -N down-line-or-beginning-search
  zle -N edit-command-line

  bindkey '^O' undo
  bindkey '^P' up-line-or-beginning-search
  bindkey '^N' down-line-or-beginning-search
  bindkey '^S' push-line
  bindkey '^X^E' edit-command-line
  # Ctrl+X in the Hammerspoon typing layer (~/.config/hammerspoon/init.lua)
  # sends ^Xk; plain Super+K is taken by AeroSpace.
  bindkey '^Xk' kill-line
fi

# Unity CLI
. "/Users/christianaguilar/.unity/env"
