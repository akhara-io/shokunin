# Engagement helpers: the box you're on, your VPN address, notes-clean clipboard.
# clipcopy / clippaste come from oh-my-zsh and work on macOS, X11 and Wayland.

# target [ip|host]   set the current box, or clear it with no argument.
#   Exports $ip/$target for commands (nmap -sC $ip) and mirrors it to the tmux
#   bar's pill, so every pane sees it.
target() {
  if (( $# )); then export ip=$1 target=$1; else unset ip target; fi
  [[ -n $TMUX ]] && tmux set -g @target "${ip-}"
}

# New panes pick up a target set elsewhere (prefix + t, or another pane).
[[ -n $TMUX && -z $ip ]] && () {
  local t=$(tmux show -gqv @target)
  [[ -n $t ]] && export ip=$t target=$t
}

# lhost   print your VPN address (HTB first) and copy it, for reverse shells.
lhost() {
  local a
  a=$(~/.config/tmux/scripts/netinfo.sh --plain) || { print -u2 'lhost: no address'; return 1 }
  print -r -- $a
  print -rn -- $a | clipcopy
}

# clip [file...]   copy files (or stdin) to the clipboard, cleaned for notes:
#   LF line endings, no trailing whitespace, a single trailing newline.
clip() { command cat -- "$@" | ~/.config/tmux/scripts/copy.sh }

# fixclip [-p]   clean whatever is already on the clipboard, collapsing runs of
#   blank lines. -p also strips the `❯ ` prompt marker from each line.
fixclip() {
  local strip=; [[ $1 == -p ]] && strip='s/^\x{276F} ?//mg;'
  clippaste | perl -CSD -0777 -pe "$strip"'s/\r\n?/\n/g; s/[ \t]+$//mg; s/\n{3,}/\n\n/g; s/\n+\z/\n/' | clipcopy
}

# p10k segment for the target; colours come from POWERLEVEL9K_TARGET_* in ~/.p10k.zsh
prompt_target() {
  [[ -n $ip ]] && p10k segment -i $'' -t "${ip//\%/%%}"
}
