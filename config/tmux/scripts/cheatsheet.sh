#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
#  tmux cheatsheet -- the hand-written one. prefix + h.
#
#  Two columns of 42 cells, so the whole sheet lands in an 88-column popup
#  without wrapping. `prefix + ?` still dumps the real `list-keys` output when
#  you want the machine's version, defaults included.
#
#  This file does NOT read tmux.conf -- it is a description of it. Add a binding
#  over there, add its line down here, or it won't show up.
#
#  Records are `;`-separated, because `|` and `\` are themselves bound keys:
#      S;section name
#      K;key;what it does
#      (empty line)  -- vertical gap
#      ===           -- everything after this goes in the right-hand column
#
#  Colours are ANSI palette slots, so they follow Ghostty light/dark. The only
#  non-ASCII glyph is ─; keys and descriptions stay ASCII on purpose, since awk's
#  length() counts bytes and the columns would go crooked otherwise.
# ─────────────────────────────────────────────────────────────────────────────

awk -F';' '
function sp(n,   s) { s = ""; while (n-- > 0) s = s " ";  return s }
function dash(n,   s) { s = ""; while (n-- > 0) s = s "─"; return s }

function cell(rec,   f, k, d, gap, tail) {
  if (rec == "") return sp(W)
  split(rec, f, ";")
  if (f[1] == "S") return PURP "─── " f[2] " " dash(W - 5 - length(f[2])) RST
  k = f[2]; d = f[3]
  gap  = KW - length(k);          if (gap  < 1) gap  = 1
  tail = W - 2 - KW - length(d);  if (tail < 0) tail = 0
  return "  " PINK k sp(gap) WHIT d RST sp(tail)
}

BEGIN {
  W = 42; KW = 12
  ESC  = sprintf("%c", 27)
  PINK = ESC "[35m"
  PURP = ESC "[1;34m"
  WHIT = ESC "[39m"
  GREY = ESC "[90m"
  CYAN = ESC "[36m"
  RST  = ESC "[0m"
  side = 1
}

/^===$/ { side = 2; next }
        { if (side == 1) L[++nl] = $0; else R[++nr] = $0 }

END {
  print ""
  print "  " PURP "tmux" RST GREY " · " WHIT "Shokunin" GREY " · prefix is " CYAN "C-Space" GREY " (or M-Space)" RST
  print "  " GREY dash(2 * W + 2) RST
  print ""
  n = (nl > nr ? nl : nr)
  for (i = 1; i <= n; i++) print cell(L[i]) "  " cell(R[i])
  print ""
  print "  " GREY dash(2 * W + 2) RST
  print "  " GREY "q" WHIT " closes this" GREY "  ·  " RST GREY "prefix + ?" WHIT " for the full list-keys dump" RST
  print ""
}
' <<'KEYS'
S;prefix
K;C-Space;prefix, twice = last window
K;a;send prefix to nested tmux

S;panes
K;M-h j k l;focus, also across nvim splits
K;C-h j k l;focus, repeatable
K;H J K L;resize
K;| \ v;split right (vertical)
K;- s;split down (horizontal)
K;o M-Enter;auto split, longer side
K;_ +;split full width / height
K;Space;next layout
K;x;swap pane down
K;X;kill pane
K;z;zoom / unzoom
K;q;show pane numbers
K;!;break pane out to a window
K;@;join the last pane back in
K;P;pane border titles

S;windows
K;c;new window, same directory
K;M-1 .. M-9;jump to window N
K;M-n M-p;next / previous
K;< >;move this window along
K;w;window picker
K;,;rename window
K;&;kill window

S;sessions
K;f;session picker
K;N;new session
K;R;rename session
K;Q;kill session
K;d;detach (closes the tab)

S;ghostty (no prefix)
K;Cmd /;this cheatsheet
K;Cmd E;file tree (in nvim)
K;Cmd P;find files (nvim)
K;Cmd Shift F;search files (nvim)
K;Cmd T W;new tab / close it
K;Cmd 1..9;jump to tab N
K;Cmd = - 0;font size up / down / reset
K;Cmd h j k l;move between panes
K;Cmd S-hjkl;resize the pane
K;Cmd D;split right
K;Cmd Shift D;split down
K;Cmd Enter;fullscreen
K;Cmd Shift ,;reload ghostty config
K;Left Opt;acts as Alt (M- keys)
K;Ctrl V;paste image into Claude
===
S;copy and paste
K;Escape;enter copy mode
K;/;copy mode, search backwards
K;p;paste
K;C-p;choose from the buffers

S;inside copy mode
K;v V C-v;select char / line / block
K;y;copy selection
K;Y;copy to end of line
K;Enter;copy and exit
K;H L;start / end of line
K;C-n;line numbers on / off
K;q Escape;leave copy mode
K;drag;mouse select copies too
K;2x 3x click;copy word / line

S;the target box
K;t;set target (the pink pill)
K;T;clear it

S;status bar
K;I;IP pill on / off
K;D;date on / off
K;Y;hostname on / off
K;B;whole bar on / off
K;bar buttons;split v / split h / close

S;the rest
K;r;reload tmux.conf
K;e;edit tmux.conf in a popup
K;m;mouse on / off
K;S;synchronize panes
K;C-l;clear screen and scrollback
K;Enter;shell popup, same directory
K;g;lazygit
K;U;upgrade packages (or click)
K;h;this cheatsheet
K;?;full list-keys dump

S;shell commands
K;target IP;set $ip; no IP clears it
K;lhost;print + copy your VPN IP
K;clip FILE;copy, cleaned for notes
K;fixclip -p;clean clipboard, -p prompts
K;l lS lm;list / by size / by date
K;lt ltt;tree, 2 / 4 deep
K;daynight;light/dark by time of day
KEYS
