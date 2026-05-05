#!/usr/bin/env bash
set -u

AEROSPACE="/opt/homebrew/bin/aerospace"
GHOSTTY="Ghostty"
WORKSPACE="2"
AGENT_DIR="$HOME"

run_agent_window() {
    local title="$1"
    local command="$2"
    local quoted_dir=""

    printf -v quoted_dir "%q" "$AGENT_DIR"

    open -na "$GHOSTTY" --args -e /bin/zsh -lc \
        "cd ${quoted_dir}; printf '\033]0;${title}\007'; ${command}; exec /bin/zsh -l"
}

wait_for_windows() {
    local wanted="$1"
    local count="0"

    for _ in {1..80}; do
        count="$("$AEROSPACE" list-windows --workspace "$WORKSPACE" --count 2>/dev/null || printf '0')"
        if [[ "$count" =~ ^[0-9]+$ ]] && (( count >= wanted )); then
            return 0
        fi
        sleep 0.25
    done

    return 1
}

arrange_three_by_two() {
    "$AEROSPACE" workspace "$WORKSPACE" || return 0
    "$AEROSPACE" layout tiles horizontal 2>/dev/null || true
    "$AEROSPACE" flatten-workspace-tree --workspace "$WORKSPACE" 2>/dev/null || true
    sleep 0.2

    "$AEROSPACE" focus --dfs-index 0 2>/dev/null && "$AEROSPACE" join-with right 2>/dev/null || true
    "$AEROSPACE" focus --dfs-index 2 2>/dev/null && "$AEROSPACE" join-with right 2>/dev/null || true
    "$AEROSPACE" focus --dfs-index 4 2>/dev/null && "$AEROSPACE" join-with right 2>/dev/null || true
    "$AEROSPACE" balance-sizes --workspace "$WORKSPACE" 2>/dev/null || true
}

"$AEROSPACE" workspace "$WORKSPACE" || exit 0
"$AEROSPACE" layout tiles horizontal 2>/dev/null || true

for index in 1 2 3 4 5; do
    run_agent_window "Codex ${index}" "/opt/homebrew/bin/codex"
    sleep 0.15
done

run_agent_window "Claude Code" "/opt/homebrew/bin/claude"

wait_for_windows 6
arrange_three_by_two
