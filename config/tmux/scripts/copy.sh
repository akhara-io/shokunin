#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
#  tmux copy filter, also behind `clip` in ~/.config/zsh/engagement.zsh, so
#  anything yanked pastes into notes without doubled or blank lines:
#  CRLF/CR -> LF, trailing whitespace stripped, one trailing newline.
# ─────────────────────────────────────────────────────────────────────────────

if command -v pbcopy >/dev/null 2>&1; then set -- pbcopy
elif [ -n "$WAYLAND_DISPLAY" ] && command -v wl-copy >/dev/null 2>&1; then set -- wl-copy
elif command -v xclip >/dev/null 2>&1; then set -- xclip -selection clipboard
else set -- tmux load-buffer -w -   # OSC 52, via set-clipboard
fi

perl -0777 -pe 's/\r\n?/\n/g; s/[ \t]+$//mg; s/\n+\z/\n/' | "$@"
