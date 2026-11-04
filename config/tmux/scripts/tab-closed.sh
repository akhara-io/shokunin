#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
#  A tab closed or detached. Every tab session records its tab's terminal in
#  @tab (set in ~/.config/zsh/init.zsh); remove the ones whose tab is gone and
#  that nobody is looking at. Sessions belonging to open tabs are always kept,
#  even ones switched away from, so prefix + f can still reach them.
# ─────────────────────────────────────────────────────────────────────────────

clients=$(tmux list-clients -F '#{client_tty}')
tmux list-sessions -F '#{session_attached}|#{session_name}|#{@tab}' |
  while IFS='|' read -r attached name owner; do
    [ "$attached" = 0 ] && [ -n "$owner" ] || continue
    printf '%s\n' "$clients" | grep -qxF "$owner" && continue  # its tab is still open
    tmux kill-session -t "=$name"
  done
