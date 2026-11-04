#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
#  Split the current pane. prefix + o, M-Enter, or the split buttons at the
#  right-hand end of the tmux status bar.
#
#      split.sh vertical     panes side by side  (tmux -h, vim :vsplit)
#      split.sh horizontal   panes stacked       (tmux -v, vim :split)
#      split.sh auto         along the pane's longer visual side, bspwm-style
#
#  Cells are about twice as tall as they are wide, so a pane's visual height is
#  roughly pane_height * ASPECT. Raise ASPECT if auto stacks too eagerly.
# ─────────────────────────────────────────────────────────────────────────────

ASPECT=2
dir=${1:-auto}

if [ "$dir" = auto ]; then
  # shellcheck disable=SC2046  # width and height, split on purpose
  set -- $(tmux display-message -p '#{pane_width} #{pane_height}')
  if [ "$1" -gt $(($2 * ASPECT)) ]; then dir=vertical; else dir=horizontal; fi
fi

case $dir in
  vertical|v|-h)   flag=-h ;;
  horizontal|h|-v) flag=-v ;;
  *) tmux display-message " split: unknown direction '$dir'"; exit 1 ;;
esac

tmux split-window "$flag" -c '#{pane_current_path}'
