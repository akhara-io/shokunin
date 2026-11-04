# shellcheck shell=bash
# Platform detection and file operations. Everything that touches $HOME goes
# through link / put, which back up what they replace and record what they
# made, so --uninstall can put the machine back.

case $(uname -s) in
  Darwin) OS=macos ;;
  Linux) OS=linux ;;
  *) die "unsupported system: $(uname -s)" ;;
esac

CONFIG_DIR=$HOME/.config/shokunin                  # choices + generated theme files
STATE_DIR=$HOME/.local/state/shokunin
MANIFEST=$STATE_DIR/installed                      # paths we created, one per line
BACKUP_DIR=$STATE_DIR/backups/$(date +%Y%m%d-%H%M%S)
LOG=$STATE_DIR/install.log

# run CMD...   do it, or just say it under --dry-run.
run() {
  if [[ -n ${DRY_RUN:-} ]]; then ui_skip "would run: $*"; else "$@"; fi
}

have() { command -v "$1" >/dev/null 2>&1; }
pretty() { if [[ $1 == "$HOME"/* ]]; then printf '~%s' "${1#"$HOME"}"; else printf '%s' "$1"; fi; }

_record() {
  [[ -n ${DRY_RUN:-} ]] && return
  grep -qxF "$1" "$MANIFEST" 2>/dev/null || printf '%s\n' "$1" >>"$MANIFEST"
}

# Move an existing path aside, keeping its place relative to $HOME.
_backup() {
  local path=$1 rel=${1#"$HOME"/}
  [[ -e $path || -L $path ]] || return 0
  mkdir -p "$(dirname "$BACKUP_DIR/$rel")"
  mv "$path" "$BACKUP_DIR/$rel"
}

# link SRC DEST   symlink DEST -> SRC, backing up whatever was there.
link() {
  local src=$1 dest=$2
  [[ -L $dest && $(readlink "$dest") == "$src" ]] && return 0
  if [[ -n ${DRY_RUN:-} ]]; then ui_skip "would link $(pretty "$dest")"; return; fi
  mkdir -p "$(dirname "$dest")"
  _backup "$dest"
  ln -s "$src" "$dest"
  _record "$dest"
}

# put DEST < content   write a generated file, backing up a different one.
put() {
  local dest=$1 tmp
  tmp=$(mktemp)
  cat >"$tmp"
  if [[ -f $dest && ! -L $dest ]] && cmp -s "$tmp" "$dest"; then rm -f "$tmp"; return 0; fi
  if [[ -n ${DRY_RUN:-} ]]; then ui_skip "would write $(pretty "$dest")"; rm -f "$tmp"; return; fi
  mkdir -p "$(dirname "$dest")"
  grep -qxF "$dest" "$MANIFEST" 2>/dev/null || _backup "$dest"   # ours already: just replace
  mv "$tmp" "$dest"
  _record "$dest"
}

# config_write   persist the SHOKUNIN_* choices as a POSIX-sourceable file.
config_write() {
  local var
  {
    echo "# shokunin choices. Re-run install.sh to change them."
    for var in SCHEDULE LIGHT_FROM DARK_FROM LIGHT_THEME DARK_THEME FONT FONT_SIZE PROMPT ENGAGEMENT TMUX_AUTOSTART DOTNET OBSIDIAN OBSIDIAN_SKIP; do
      var=SHOKUNIN_$var
      printf "%s='%s'\n" "$var" "$(printf '%s' "${!var}" | sed "s/'/'\\\\''/g")"
    done
  } | put "$CONFIG_DIR/config"
}
