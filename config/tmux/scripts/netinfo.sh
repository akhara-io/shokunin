#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
#  The IP that actually matters right now:
#    1. HTB VPN   -- a tunnel interface in HackTheBox's 10.10.x.x space
#    2. other VPN -- any other tunnel with an address
#    3. LAN       -- first physical interface with an address
#
#  netinfo.sh           the tmux status pill, styling included
#  netinfo.sh --plain   the bare address (exit 1 when offline) -- `lhost` uses it
# ─────────────────────────────────────────────────────────────────────────────

# "interface address" pairs: ifconfig on macOS, ip on Linux
if [ "$(uname)" = Darwin ]; then
  pairs=$(ifconfig 2>/dev/null | awk '/^[^ \t]/ { ifn = $1; sub(/:$/, "", ifn) } $1 == "inet" { print ifn, $2 }')
else
  pairs=$(ip -4 -o addr show 2>/dev/null | awk '{ sub(/\/.*/, "", $4); print $2, $4 }')
fi

# shellcheck disable=SC2046  # kind and address, split on purpose
set -- "${1:-}" $(printf '%s\n' "$pairs" | awk '
  $2 !~ /^(127|169\.254)\./ {
    if ($1 ~ /^(utun|tun|tap|ppp|ipsec|wg)/) {
      if ($2 ~ /^10\.10\./) { if (!htb) htb = $2 } else if (!vpn) vpn = $2
    } else if ($1 ~ /^(en|eth|wl)/ && !lan) lan = $2
  }
  END { if (htb) print "htb", htb; else if (vpn) print "vpn", vpn; else if (lan) print "lan", lan }')
kind=$2 addr=$3

if [ "$1" = --plain ]; then
  [ -n "$addr" ] && echo "$addr"
  exit
fi

SHIELD=$(printf '\357\204\262')  # U+F132  nf-fa-shield  -- VPN
GLOBE=$(printf '\357\202\254')   # U+F0AC  nf-fa-globe   -- LAN
TIMES=$(printf '\357\200\215')   # U+F00D  nf-fa-times   -- offline
case $kind in
  htb) colour=themegreen    icon=$SHIELD ;;
  vpn) colour=themecyan     icon=$SHIELD ;;
  lan) colour=themedarkgrey icon=$GLOBE ;;
  *)   colour=themered      icon=$TIMES addr=offline ;;
esac

CAP_L=$(printf '\356\202\266')   # U+E0B6  rounded left cap
CAP_R=$(printf '\356\202\264')   # U+E0B4  rounded right cap
printf '#[fg=themelightgrey]#[bg=default]%s#[fg=%s]#[bg=themelightgrey] %s #[fg=themeblack]%s #[fg=themelightgrey]#[bg=default]%s' \
  "$CAP_L" "$colour" "$icon" "$addr" "$CAP_R"
