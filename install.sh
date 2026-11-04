#!/usr/bin/env bash
# shokunin: one-shot terminal setup for macOS and Linux.
#
#   Ghostty, tmux, zsh + powerlevel10k, Neovim and eza, themed as one set,
#   light by day and dark after hours, plus helpers for offsec engagements.
#
#   ./install.sh                 guided install (re-run any time to change things)
#   ./install.sh --yes           take the defaults, or your previous answers
#   ./install.sh --dry-run       show what would change, change nothing
#   ./install.sh --no-packages   configs only; install the software yourself
#   ./install.sh --theme         change only the light and dark themes
#   ./install.sh --uninstall     remove what shokunin made, restore your backups
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/ui.sh
source "$ROOT/lib/ui.sh"
# shellcheck source=lib/sys.sh
source "$ROOT/lib/sys.sh"
# shellcheck source=lib/themes.sh
source "$ROOT/lib/themes.sh"
# shellcheck source=lib/packages.sh
source "$ROOT/lib/packages.sh"

usage() { sed -n '2,/^set /{/^set /d;s/^# \{0,1\}//;p;}' "$0"; }

ASSUME_YES='' DRY_RUN='' PACKAGES=1 UNINSTALL='' THEME_ONLY=''
while (($#)); do
  case $1 in
    -y | --yes) ASSUME_YES=1 ;;
    -n | --dry-run) DRY_RUN=1 ;;
    --no-packages) PACKAGES='' ;;
    --theme) THEME_ONLY=1 ;;
    --uninstall) UNINSTALL=1 ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "unknown option: $1" ;;
  esac
  shift
done

# ─── questions ───────────────────────────────────────────────────────────────

index_of() {
  local needle=$1 i=0 item
  shift
  for item; do [[ $item == "$needle" ]] && { echo $i; return; }; i=$((i + 1)); done
  echo 0
}

# ask VAR "question" DEFAULT PREVIEW ITEM...   menu, starting on DEFAULT.
ask() {
  local var=$1 question=$2 def=$3 preview=$4
  shift 4
  ui_choose "$var" "$question" "$(index_of "$def" "$@")" "$preview" "$@"
}

# load_answers   previous answers, with defaults for any that are missing.
load_answers() {
  # shellcheck source=/dev/null
  [[ -r $CONFIG_DIR/config ]] && source "$CONFIG_DIR/config"
  : "${SHOKUNIN_LIGHT_THEME:=Shokunin}" "${SHOKUNIN_DARK_THEME:=Shokunin Night}"
  : "${SHOKUNIN_SCHEDULE:=time}" "${SHOKUNIN_LIGHT_FROM:=7}" "${SHOKUNIN_DARK_FROM:=17}"
  : "${SHOKUNIN_FONT:=Maple Mono}" "${SHOKUNIN_FONT_SIZE:=16}" "${SHOKUNIN_PROMPT:=pills}"
  : "${SHOKUNIN_ENGAGEMENT:=1}" "${SHOKUNIN_TMUX_AUTOSTART:=1}" "${SHOKUNIN_DOTNET:=1}" "${SHOKUNIN_OBSIDIAN:=1}"
  : "${SHOKUNIN_OBSIDIAN_SKIP=}"
}

# ask_themes   the light and dark pickers, over every usable theme. Only the
# ones the schedule actually shows are asked.
ask_themes() {
  load_themes
  [[ $SHOKUNIN_SCHEDULE != dark ]] &&
    ask SHOKUNIN_LIGHT_THEME "Light theme" "$SHOKUNIN_LIGHT_THEME" theme_preview "${LIGHT_THEMES[@]}"
  [[ $SHOKUNIN_SCHEDULE != light ]] &&
    ask SHOKUNIN_DARK_THEME "Dark theme" "$SHOKUNIN_DARK_THEME" theme_preview "${DARK_THEMES[@]}"
  return 0
}

ask_everything() {
  load_answers   # previous answers become the defaults

  ui_section "Look"
  local schedules=("Light by day, dark after hours" "Follow the system setting" "Always light" "Always dark")
  local keys=(time system light dark) choice
  ask choice "Light and dark" "${schedules[$(index_of "$SHOKUNIN_SCHEDULE" "${keys[@]}")]}" '' "${schedules[@]}"
  SHOKUNIN_SCHEDULE=${keys[$(index_of "$choice" "${schedules[@]}")]}
  if [[ $SHOKUNIN_SCHEDULE == time ]]; then
    local hour='^([0-9]|1[0-9]|2[0-3])$'
    ui_input SHOKUNIN_LIGHT_FROM "Light from (hour, 0-23)" "$SHOKUNIN_LIGHT_FROM" "$hour"
    ui_input SHOKUNIN_DARK_FROM "Dark from (hour, 0-23)" "$SHOKUNIN_DARK_FROM" "$hour"
    [[ $OS == linux ]] && ui_note "Switching uses GNOME's light/dark setting."
  fi

  # Only open the pickers on request, and only for the themes actually shown.
  local current="$SHOKUNIN_LIGHT_THEME / $SHOKUNIN_DARK_THEME"
  [[ $SHOKUNIN_SCHEDULE == light ]] && current=$SHOKUNIN_LIGHT_THEME
  [[ $SHOKUNIN_SCHEDULE == dark ]] && current=$SHOKUNIN_DARK_THEME
  ask choice "Themes" "Use $current" '' "Use $current" "Choose themes"
  [[ $choice == "Choose themes" ]] && ask_themes

  local fonts=()
  while IFS= read -r choice; do fonts+=("$choice"); done < <(font_names)
  ask SHOKUNIN_FONT "Font" "$SHOKUNIN_FONT" '' "${fonts[@]}"
  ui_input SHOKUNIN_FONT_SIZE "Font size" "$SHOKUNIN_FONT_SIZE" '^[0-9]{1,2}(\.[0-9])?$'

  local prompts=("Pills (colourful segments)" "Lean (coloured text only)")
  ask choice "Prompt style" "${prompts[$([[ $SHOKUNIN_PROMPT == lean ]] && echo 1 || echo 0)]}" '' "${prompts[@]}"
  [[ $choice == Lean* ]] && SHOKUNIN_PROMPT=lean || SHOKUNIN_PROMPT=pills

  ui_section "Behaviour"
  ui_confirm SHOKUNIN_TMUX_AUTOSTART "Start tmux in every new Ghostty tab" "$( ((SHOKUNIN_TMUX_AUTOSTART)) && echo y || echo n)"
  ui_confirm SHOKUNIN_ENGAGEMENT "Engagement helpers (target, lhost, VPN pill, clip)" "$( ((SHOKUNIN_ENGAGEMENT)) && echo y || echo n)"
  ui_confirm SHOKUNIN_DOTNET "C# and PowerShell support in Neovim (.NET + pwsh, ~770 MB)" "$( ((SHOKUNIN_DOTNET)) && echo y || echo n)"
  if [[ -n $(obsidian_vaults) ]]; then
    ui_confirm SHOKUNIN_OBSIDIAN "Theme your Obsidian vaults to match and add Iconize, Calendar and Recent Files" "$( ((SHOKUNIN_OBSIDIAN)) && echo y || echo n)"
    ((SHOKUNIN_OBSIDIAN)) && ask_vaults
  else
    SHOKUNIN_OBSIDIAN=0
  fi
}

# vault_skipped PATH   true for a vault you've said to leave alone.
vault_skipped() { [[ $'\n'$SHOKUNIN_OBSIDIAN_SKIP == *$'\n'"$1"$'\n'* ]]; }

# ask_vaults   which vaults to theme. A no is remembered in
# SHOKUNIN_OBSIDIAN_SKIP (one path per line), so later runs, --yes and
# --theme leave that vault alone too.
ask_vaults() {
  local vault ok vaults=()
  while IFS= read -r vault; do [[ -d $vault/.obsidian ]] && vaults+=("$vault"); done < <(obsidian_vaults)
  for vault in "${vaults[@]}"; do
    ui_confirm ok "  Theme the \"${vault##*/}\" vault ($(pretty "$vault"))" "$(vault_skipped "$vault" && echo n || echo y)"
    if ((ok)); then
      vault_skipped "$vault" && SHOKUNIN_OBSIDIAN_SKIP=$(printf '%s' "$SHOKUNIN_OBSIDIAN_SKIP" | grep -vxF "$vault")$'\n'
    else
      vault_skipped "$vault" || SHOKUNIN_OBSIDIAN_SKIP+="$vault"$'\n'
    fi
  done
  SHOKUNIN_OBSIDIAN_SKIP=$(printf '%s' "$SHOKUNIN_OBSIDIAN_SKIP" | grep -v '^$')$'\n'
  [[ $SHOKUNIN_OBSIDIAN_SKIP == $'\n' ]] && SHOKUNIN_OBSIDIAN_SKIP=''
  return 0
}

# ─── setup steps ─────────────────────────────────────────────────────────────

ghostty_config() {
  local theme="light:$SHOKUNIN_LIGHT_THEME,dark:$SHOKUNIN_DARK_THEME"
  [[ $SHOKUNIN_SCHEDULE == light ]] && theme=$SHOKUNIN_LIGHT_THEME
  [[ $SHOKUNIN_SCHEDULE == dark ]] && theme=$SHOKUNIN_DARK_THEME
  cat <<EOF
# Generated by shokunin. Re-run install.sh to change; edits here are replaced.
font-family          = $(font_field "$SHOKUNIN_FONT" 2)
font-size            = $SHOKUNIN_FONT_SIZE
theme                = $theme
window-padding-x     = 32
window-padding-y     = 32
cursor-style         = block
# Shell integration would thin the cursor to a bar at the prompt
shell-integration-features = no-cursor
# Left Option is Alt (tmux/nvim M- keys); right Option still types special characters
macos-option-as-alt  = left
# Cmd+/ and Cmd+? send Alt+?, which opens the tmux cheatsheet
keybind              = super+slash=esc:?
keybind              = super+shift+slash=esc:?
# Cmd+E sends Alt+e: toggles Neovim's file tree
keybind              = super+e=esc:e
# Cmd+h/j/k/l move between tmux panes and nvim splits (sent as Alt+h/j/k/l;
# replaces macOS's Cmd+H hide and Ghostty's Cmd+K clear)
keybind              = super+h=esc:h
keybind              = super+j=esc:j
keybind              = super+k=esc:k
keybind              = super+l=esc:l
# Cmd+Shift+h/j/k/l resize the tmux pane (sent as Alt+H/J/K/L)
keybind              = super+shift+h=esc:H
keybind              = super+shift+j=esc:J
keybind              = super+shift+k=esc:K
keybind              = super+shift+l=esc:L
# Cmd+P finds files, Cmd+Shift+F searches them, in Neovim (sent as Alt+P / Alt+F)
keybind              = super+p=esc:P
keybind              = super+shift+f=esc:F
# Cmd+D / Cmd+Shift+D split the tmux pane right / down (instead of Ghostty splits)
keybind              = super+d=esc:|
keybind              = super+shift+d=esc:_
EOF
}

setup_configs() {
  local name dir

  link "$ROOT/config/zsh" "$HOME/.config/zsh"
  link "$ROOT/config/tmux" "$HOME/.config/tmux"
  link "$ROOT/config/nvim" "$HOME/.config/nvim"
  link "$ROOT/config/eza" "$HOME/.config/eza"
  link "$ROOT/bin/appearance" "$HOME/.local/bin/appearance"
  link "$ROOT/bin/daynight" "$HOME/.local/bin/daynight"
  ui_ok "zsh, tmux, Neovim and eza configs linked from $(pretty "$ROOT")"

  put "$HOME/.zshrc" <<'EOF'
# Set up by shokunin; the shared config lives in ~/.config/zsh.
source ~/.config/zsh/init.zsh

# Your own additions go below.
EOF
  # Pills take their text colour from the themes, so setup_theme writes them.
  [[ $SHOKUNIN_PROMPT == pills ]] || put "$HOME/.p10k.zsh" <"$ROOT/config/zsh/p10k-lean.zsh"
  ui_ok ".zshrc and a $SHOKUNIN_PROMPT prompt"

  # macOS Ghostty also reads Application Support, which would override ours.
  if [[ $OS == macos ]]; then
    for name in config config.ghostty; do
      dir="$HOME/Library/Application Support/com.mitchellh.ghostty"
      if [[ -f $dir/$name && -z ${DRY_RUN:-} ]]; then
        _backup "$dir/$name"
        ui_note "moved Ghostty's $name from Application Support into the backup"
      fi
    done
  fi
  setup_theme
  config_write
  setup_obsidian
}

# setup_theme   everything coloured by the two themes: Ghostty, the prompt
# pills, tmux and Neovim.
setup_theme() {
  local name fg='' theme moved
  if [[ $SHOKUNIN_PROMPT == pills ]]; then
    fg=$(pill_fg "$SHOKUNIN_LIGHT_THEME" "$SHOKUNIN_DARK_THEME")
    sed "s/@PILL_FG@/$fg/g" "$ROOT/config/zsh/p10k-pills.zsh" | put "$HOME/.p10k.zsh"
  fi
  ghostty_config | put "$HOME/.config/ghostty/config"
  # Ghostty prefers these copies to its own. With pills, any colour that would
  # make a pill hard to read is nudged until it isn't (see readable_theme).
  for name in "$SHOKUNIN_LIGHT_THEME" "$SHOKUNIN_DARK_THEME"; do
    if [[ -n $fg ]]; then theme=$(readable_theme "$name" "$fg"); else theme=$(cat "$(theme_file "$name")"); fi
    printf '%s\n' "$theme" | put "$HOME/.config/ghostty/themes/$name"
    if [[ $theme == "# shokunin:"* ]]; then
      moved=${theme%%$'\n'*}; moved=${moved//[^>]/}
      ui_note "$name: adjusted ${#moved} colour(s) so the prompt pills stay readable"
    fi
  done
  ui_ok "Ghostty: $SHOKUNIN_FONT $SHOKUNIN_FONT_SIZE, $SHOKUNIN_LIGHT_THEME / $SHOKUNIN_DARK_THEME"
  gen_tmux_theme "$SHOKUNIN_LIGHT_THEME" "$SHOKUNIN_DARK_THEME" | put "$CONFIG_DIR/tmux-theme.conf"
  gen_nvim_palette "$SHOKUNIN_LIGHT_THEME" "$SHOKUNIN_DARK_THEME" | put "$CONFIG_DIR/palette.lua"
  ui_ok "tmux, Neovim and prompt colours generated from your themes"
}

# obsidian_recolour   rewrite the snippet in the vaults that already have it,
# so vaults you've kept shokunin out of stay that way.
obsidian_recolour() {
  local vault css count=0
  ((SHOKUNIN_OBSIDIAN)) || return 0
  css=$(gen_obsidian_css "$SHOKUNIN_LIGHT_THEME" "$SHOKUNIN_DARK_THEME" "$(font_field "$SHOKUNIN_FONT" 2)")
  while IFS= read -r vault; do
    [[ -f $vault/.obsidian/snippets/shokunin.css ]] || continue
    vault_skipped "$vault" && continue
    printf '%s\n' "$css" | put "$vault/.obsidian/snippets/shokunin.css"
    count=$((count + 1))
  done < <(obsidian_vaults)
  ((count)) && ui_ok "Obsidian: $count vault(s) recoloured"
  return 0
}

# change_theme   --theme: pick new light and dark themes and recolour what
# follows them, leaving everything else as it is.
change_theme() {
  [[ -r $CONFIG_DIR/config ]] || die "shokunin isn't set up here yet; run ./install.sh first"
  load_answers
  ui_section "Themes"
  ask_themes
  if ui_interactive; then
    local ok
    printf '\n'
    ui_confirm ok "Switch to these themes" y
    ((ok)) || { ui_note "Nothing changed."; exit 0; }
  fi
  ui_section "Colours"
  setup_theme
  obsidian_recolour
  config_write
  if [[ -z ${DRY_RUN:-} ]] && tmux info >/dev/null 2>&1; then
    tmux source-file "$HOME/.config/tmux/tmux.conf" >/dev/null 2>&1 && ui_ok "Reloaded the running tmux"
  fi
  printf '\n  %s%sThemes changed.%s\n\n' "${BOLD}" "${GREEN}" "${RESET}"
  ui_note "Ghostty: press Cmd+Shift+, to reload, or open a new window. Neovim picks it up on restart."
  printf '\n'
}

# Every vault Obsidian knows about (macOS, Linux, Flatpak).
obsidian_vaults() {
  local reg
  have jq || return 0
  for reg in "$HOME/Library/Application Support/obsidian/obsidian.json" "$HOME/.config/obsidian/obsidian.json" \
    "$HOME/.var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json"; do
    [[ -f $reg ]] && jq -r '.vaults[].path' "$reg" 2>/dev/null
  done
}

# Community plugins every vault gets: id, GitHub repo, and the release that's
# been tested with this setup. Default settings live in obsidian/plugins/<id>/.
OBSIDIAN_PLUGINS=(
  "obsidian-icon-folder FlorianWoelki/obsidian-iconize 2.14.7"
  "calendar liamcain/obsidian-calendar-plugin 1.5.10"
  "recent-files-obsidian tgrosinger/recent-files-obsidian 1.7.10"
)

# obsidian_plugins VAULT   install the plugins the vault doesn't have yet.
# A plugin that's already there keeps its own version and settings.
obsidian_plugins() {
  local vault=$1 spec id repo version dir file tmp defaults
  for spec in "${OBSIDIAN_PLUGINS[@]}"; do
    read -r id repo version <<<"$spec"
    dir=$vault/.obsidian/plugins/$id
    [[ -f $dir/manifest.json ]] && continue
    if [[ -n ${DRY_RUN:-} ]]; then ui_skip "would install $id $version into $(pretty "$vault")"; continue; fi
    tmp=$(mktemp -d)
    for file in main.js manifest.json styles.css; do
      curl -fsL -o "$tmp/$file" "https://github.com/$repo/releases/download/$version/$file" ||
        [[ $file == styles.css ]] || { ui_warn "couldn't download $id $version; skipped"; rm -rf "$tmp"; continue 2; }
    done
    for file in main.js manifest.json styles.css; do
      [[ -s $tmp/$file ]] && put "$dir/$file" <"$tmp/$file"
    done
    rm -rf "$tmp"
    defaults=$ROOT/obsidian/plugins/$id/data.json
    [[ -f $defaults ]] && put "$dir/data.json" <"$defaults"
  done
}

# A CSS snippet and the plugins in each vault, switched on with "Adapt to
# system" so Obsidian goes light and dark with everything else. A running
# Obsidian rewrites its settings from memory, so then it's a few clicks instead.
setup_obsidian() {
  local vault css settings ids running='' count=0
  ((SHOKUNIN_OBSIDIAN)) || return 0
  css=$(gen_obsidian_css "$SHOKUNIN_LIGHT_THEME" "$SHOKUNIN_DARK_THEME" "$(font_field "$SHOKUNIN_FONT" 2)")
  ids=$(printf '%s\n' "${OBSIDIAN_PLUGINS[@]}" | awk '{print $1}' | jq -R . | jq -sc .)
  pgrep -xi obsidian >/dev/null && running=1
  while IFS= read -r vault; do
    [[ -d $vault/.obsidian ]] || continue
    vault_skipped "$vault" && continue
    printf '%s\n' "$css" | put "$vault/.obsidian/snippets/shokunin.css"
    obsidian_plugins "$vault"
    if [[ -z $running ]]; then
      settings=$vault/.obsidian/appearance.json
      { cat "$settings" 2>/dev/null || echo '{}'; } |
        jq '.theme = "system" | .enabledCssSnippets = ((.enabledCssSnippets // []) + ["shokunin"] | unique)' |
        put "$settings"
      settings=$vault/.obsidian/community-plugins.json
      { cat "$settings" 2>/dev/null || echo '[]'; } | jq --argjson ids "$ids" '. + ($ids - .)' | put "$settings"
    fi
    count=$((count + 1))
  done < <(obsidian_vaults)
  ui_ok "Obsidian: $count vault(s) themed, with Iconize, Calendar and Recent Files"
  if [[ -n $running ]]; then
    ui_note "Obsidian is open, so switch it on there: Settings → Appearance → turn on the"
    ui_note "\"shokunin\" CSS snippet, and set Base color scheme to \"Adapt to system\"."
    ui_note "Then Settings → Community plugins → turn on Iconize, Calendar and Recent Files."
  fi
}

LAUNCH_AGENT=$HOME/Library/LaunchAgents/io.shokunin.daynight.plist
SYSTEMD_DIR=$HOME/.config/systemd/user

scheduler_off() {
  if [[ $OS == macos ]]; then
    [[ -f $LAUNCH_AGENT ]] || return 0
    run launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT" 2>/dev/null
    run rm -f "$LAUNCH_AGENT"
  else
    [[ -f $SYSTEMD_DIR/shokunin-daynight.timer ]] || return 0
    run systemctl --user disable --now shokunin-daynight.timer 2>/dev/null
    run rm -f "$SYSTEMD_DIR"/shokunin-daynight.{service,timer}
  fi
}

setup_schedule() {
  if [[ $SHOKUNIN_SCHEDULE != time ]]; then
    scheduler_off
    local what="always $SHOKUNIN_SCHEDULE"
    [[ $SHOKUNIN_SCHEDULE == system ]] && what="follows the system"
    ui_ok "Appearance: $what"
    return
  fi

  if [[ $OS == macos ]]; then
    put "$LAUNCH_AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>io.shokunin.daynight</string>
  <key>ProgramArguments</key><array><string>$HOME/.local/bin/daynight</string></array>
  <key>StartCalendarInterval</key>
  <array>
    <dict><key>Hour</key><integer>$SHOKUNIN_LIGHT_FROM</integer><key>Minute</key><integer>0</integer></dict>
    <dict><key>Hour</key><integer>$SHOKUNIN_DARK_FROM</integer><key>Minute</key><integer>0</integer></dict>
  </array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
EOF
    run launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT" 2>/dev/null
    run launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT" || { ui_warn "couldn't load the day/night LaunchAgent"; return; }
    ui_note "macOS may ask once to let daynight control System Events; allow it."
  else
    if ! have systemctl || ! have gsettings; then
      ui_warn "day/night switching needs systemd and GNOME; skipped"
      return
    fi
    put "$SYSTEMD_DIR/shokunin-daynight.service" <<EOF
[Unit]
Description=shokunin: light or dark by time of day

[Service]
Type=oneshot
ExecStart=%h/.local/bin/daynight

[Install]
WantedBy=default.target
EOF
    put "$SYSTEMD_DIR/shokunin-daynight.timer" <<EOF
[Unit]
Description=shokunin: switch light/dark at $SHOKUNIN_LIGHT_FROM:00 and $SHOKUNIN_DARK_FROM:00

[Timer]
OnCalendar=*-*-* $SHOKUNIN_LIGHT_FROM:00:00
OnCalendar=*-*-* $SHOKUNIN_DARK_FROM:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
    if ! run systemctl --user daemon-reload ||
      ! run systemctl --user enable --now shokunin-daynight.timer shokunin-daynight.service >/dev/null 2>&1; then
      ui_warn "couldn't enable the day/night timer"
      return
    fi
  fi
  ui_ok "Appearance: light from $SHOKUNIN_LIGHT_FROM:00, dark from $SHOKUNIN_DARK_FROM:00"
}

finish() {
  local zsh_path ok

  if have nvim && [[ -z ${DRY_RUN:-} ]]; then
    ui_spin "Neovim plugins" nvim --headless +qa
  fi

  if [[ ${SHELL##*/} != zsh ]]; then
    zsh_path=$(grep -m1 '/zsh$' /etc/shells 2>/dev/null || command -v zsh)
    ui_confirm ok "Make zsh your login shell ($zsh_path)" y
    ((ok)) && { run chsh -s "$zsh_path" || ui_warn "chsh failed; run: chsh -s $zsh_path"; }
  fi

  # A running tmux picks up the new config straight away.
  if [[ -z ${DRY_RUN:-} ]] && tmux info >/dev/null 2>&1; then
    tmux source-file "$HOME/.config/tmux/tmux.conf" >/dev/null 2>&1 && ui_ok "Reloaded the running tmux"
  fi
}

# ─── uninstall ───────────────────────────────────────────────────────────────

uninstall() {
  local ok path dir
  [[ -f $MANIFEST ]] || die "nothing to uninstall: $(pretty "$MANIFEST") doesn't exist"
  ui_confirm ok "Remove everything shokunin set up and restore your backups" "$([[ -n $ASSUME_YES ]] && echo y || echo n)"
  ((ok)) || exit 0

  scheduler_off
  while IFS= read -r path; do run rm -rf "$path"; done <"$MANIFEST"
  ui_ok "Removed $(wc -l <"$MANIFEST" | tr -d ' ') links and generated files"

  # Oldest backup first: it holds what was there before shokunin.
  for dir in "$STATE_DIR"/backups/*/; do
    [[ -d $dir ]] || continue
    (cd "$dir" && find . \( -type f -o -type l \) -print) | while IFS= read -r path; do
      path=${path#./}
      [[ -e $HOME/$path || -L $HOME/$path ]] && continue
      run mkdir -p "$(dirname "$HOME/$path")"
      run cp -P "$dir$path" "$HOME/$path"
    done
  done
  ui_ok "Restored your previous files"

  [[ -f $HOME/.zprofile && -z ${DRY_RUN:-} ]] && sed -i.bak '/# shokunin$/d' "$HOME/.zprofile" && rm -f "$HOME/.zprofile.bak"
  run rm -f "$MANIFEST"
  ui_note "Homebrew packages and fonts are left installed; brew uninstall what you don't want."
}

# ─── main ────────────────────────────────────────────────────────────────────

main() {
  ui_banner "terminal setup · $OS $(uname -m)${DRY_RUN:+ · dry run}"
  mkdir -p "$STATE_DIR"

  if [[ -n $UNINSTALL ]]; then uninstall; return; fi
  if [[ -n $THEME_ONLY ]]; then change_theme; return; fi

  ask_everything

  if ui_interactive; then
    local ok
    printf '\n'
    ui_confirm ok "Set it all up" y
    ((ok)) || { ui_note "Nothing changed."; exit 0; }
  fi

  if [[ -n $PACKAGES ]]; then
    ui_section "Software"
    install_software
  fi
  ui_section "Configuration"
  setup_configs
  ui_section "Day and night"
  setup_schedule
  ui_section "Finishing up"
  finish

  printf '\n  %s%sAll set.%s Open a new Ghostty window to start.\n\n' "${BOLD}" "${GREEN}" "${RESET}"
  ui_note "Cmd+/ (or prefix + h) in tmux shows every shortcut. The prefix is Ctrl+Space."
  ui_note "Try the evening look now with: daynight dark   (daynight light to go back)"
  [[ -d $BACKUP_DIR ]] && ui_note "Anything replaced was saved in $(pretty "$BACKUP_DIR")"
  ui_note "Log: $(pretty "$LOG")"
  printf '\n'
}

main
