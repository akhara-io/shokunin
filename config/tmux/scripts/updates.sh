#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
#  tmux status pill: how many Homebrew packages are out of date.
#
#  updates.sh             the pill (nothing when everything's current)
#  updates.sh --upgrade   brew upgrade, then recount (the pill's click, prefix + U)
#
#  `brew update` is slow and hits the network, so it runs in the background at
#  most every 6 hours; the status bar only ever reads the cached count.
# ─────────────────────────────────────────────────────────────────────────────

PATH=/opt/homebrew/bin:/usr/local/bin:/home/linuxbrew/.linuxbrew/bin:$PATH
command -v brew >/dev/null 2>&1 || exit 0
CACHE=${XDG_CACHE_HOME:-$HOME/.cache}/shokunin/outdated
mkdir -p "${CACHE%/*}"

count() { brew outdated --quiet 2>/dev/null | wc -l | tr -d ' ' >"$CACHE.tmp" && mv "$CACHE.tmp" "$CACHE"; }

if [ "${1:-}" = --upgrade ]; then
  brew upgrade
  count
  printf '\n  Done. Press Enter to close.'
  read -r _
  exit 0
fi

# Stale cache: refresh in the background, one at a time (the lock is a dir).
find "$CACHE.lock" -maxdepth 0 -mmin +60 -exec rmdir {} \; 2>/dev/null
if [ -z "$(find "$CACHE" -mmin -360 2>/dev/null)" ] && mkdir "$CACHE.lock" 2>/dev/null; then
  (brew update --quiet; count; rmdir "$CACHE.lock") >/dev/null 2>&1 &
fi

n=$(cat "$CACHE" 2>/dev/null)
[ "${n:-0}" -gt 0 ] 2>/dev/null || exit 0
CAP_L=$(printf '\356\202\266')   # U+E0B6  rounded left cap
CAP_R=$(printf '\356\202\264')   # U+E0B4  rounded right cap
BOX=$(printf '\357\222\207')     # U+F487  nf-oct-package
printf '#[fg=themelightgrey]#[bg=default]%s#[range=user|updates]#[fg=themeyellow]#[bg=themelightgrey] %s #[fg=themeblack]%s #[norange]#[fg=themelightgrey]#[bg=default]%s ' \
  "$CAP_L" "$BOX" "$n" "$CAP_R"
