# shellcheck shell=bash
# Terminal UI: colours, status lines, menus, prompts and a spinner.
# Plain bash 3.2 (macOS's /bin/bash), no dependencies.

if [[ -t 1 ]]; then
  BOLD=$'\e[1m' DIM=$'\e[2m' RESET=$'\e[0m'
  RED=$'\e[31m' GREEN=$'\e[32m' YELLOW=$'\e[33m' MAGENTA=$'\e[35m' CYAN=$'\e[36m'
else
  BOLD='' DIM='' RESET='' RED='' GREEN='' YELLOW='' MAGENTA='' CYAN=''
fi

# Prompts are interactive only with a terminal on both ends and no --yes.
ui_interactive() { [[ -t 0 && -t 1 && -z ${ASSUME_YES:-} ]]; }
ui_truecolor() { [[ ${COLORTERM:-} == truecolor || ${COLORTERM:-} == 24bit ]]; }

ui_banner() {
  printf '\n  %s%s職人  shokunin%s  %s%s%s\n' "${BOLD}" "${MAGENTA}" "${RESET}" "${DIM}" "$1" "${RESET}"
  printf '  %s%s%s\n' "${DIM}" "────────────────────────────────────────────────────────" "${RESET}"
}
ui_section() { printf '\n  %s%s▍%s%s%s\n' "${BOLD}" "${MAGENTA}" "${RESET}${BOLD}" "$1" "${RESET}"; }
ui_ok() { printf '  %s✓%s %s\n' "${GREEN}" "${RESET}" "$1"; }
ui_skip() { printf '  %s·%s %s%s%s\n' "${DIM}" "${RESET}" "${DIM}" "$1" "${RESET}"; }
ui_warn() { printf '  %s!%s %s\n' "${YELLOW}" "${RESET}" "$1" >&2; }
ui_err() { printf '  %s✗%s %s\n' "${RED}" "${RESET}" "$1" >&2; }
ui_note() { printf '    %s%s%s\n' "${DIM}" "$1" "${RESET}"; }
die() { ui_err "$1"; exit 1; }

# Settled answer line, shown once a question is done.
_ui_answered() { printf '  %s✓%s %s  %s%s%s\n' "${GREEN}" "${RESET}" "$1" "${CYAN}" "$2" "${RESET}"; }

_ui_cursor() { [[ -t 1 ]] && printf '\e[?25%s' "$1"; }  # h = show, l = hide
_ui_restore() { _ui_cursor h; stty echo 2>/dev/null; }

# Read one key into $1: up, down, enter, quit, or the character itself.
# _ui_key VAR [typing]   read one key: up, down, enter, quit, or the character.
# With "typing", letters stay letters (j/k/q don't move or quit), Backspace is
# "backspace" and a lone Esc is "escape".
_ui_key() {
  local k rest
  IFS= read -rsn1 k
  if [[ $k == $'\e' ]]; then
    IFS= read -rsn2 -t 1 rest
    case $rest in
      '[A' | OA) k=up ;;
      '[B' | OB) k=down ;;
      '') [[ -n ${2:-} ]] && k=escape || k=quit ;;
      *) k=quit ;;
    esac
  fi
  case $k in
    '') k=enter ;;
    $'\x03') k=quit ;;
    $'\x7f' | $'\b') k=backspace ;;
    k | j | q) [[ -z ${2:-} ]] && case $k in k) k=up ;; j) k=down ;; q) k=quit ;; esac ;;
  esac
  printf -v "$1" '%s' "$k"
}

# ui_choose VAR "question" DEFAULT_INDEX PREVIEW_FN ITEM...
#   Arrow-key menu; stores the chosen item in VAR. PREVIEW_FN (or '') is
#   called with the highlighted item and prints lines shown under the list.
#   A list longer than UI_ROWS scrolls, and typing narrows it down.
UI_ROWS=12
ui_choose() {
  local __var=$1 question=$2 sel=$3 preview=$4
  shift 4
  local items=("$@") n=$# i key out extra nl
  local search=$((n > UI_ROWS)) filter='' current top=0 rows lines nocase=''
  local shown=()

  if ! ui_interactive; then
    printf -v "$__var" '%s' "${items[sel]}"
    _ui_answered "$question" "${items[sel]}"
    return
  fi

  if ((search)); then
    printf '  %s?%s %s%s%s  %stype to search · ↑↓ move · enter select%s\n' "${CYAN}" "${RESET}" "${BOLD}" "$question" "${RESET}" "${DIM}" "${RESET}"
  else
    printf '  %s?%s %s%s%s  %s↑↓ move · enter select%s\n' "${CYAN}" "${RESET}" "${BOLD}" "$question" "${RESET}" "${DIM}" "${RESET}"
  fi
  shopt -q nocasematch && nocase=1
  shopt -s nocasematch
  current=${items[sel]}
  _ui_cursor l
  trap '_ui_restore; exit 130' INT
  while :; do
    # The items matching what's typed, keeping the highlight on the same one.
    shown=() sel=0
    for ((i = 0; i < n; i++)); do
      [[ -z $filter || ${items[i]} == *"$filter"* ]] || continue
      [[ ${items[i]} == "$current" ]] && sel=${#shown[@]}
      shown+=("${items[i]}")
    done
    rows=${#shown[@]}
    ((rows > UI_ROWS)) && rows=$UI_ROWS
    ((sel < top)) && top=$sel
    ((sel >= top + rows)) && top=$((sel - rows + 1))
    ((top > ${#shown[@]} - rows)) && top=$((${#shown[@]} - rows))
    ((top < 0)) && top=0

    out='' lines=0
    if ((search)); then
      out+="    ${DIM}search${RESET} ${filter}${DIM}▏ ${#shown[@]} of $n${RESET}"$'\n'
      lines=1
    fi
    for ((i = top; i < top + rows; i++)); do
      if ((i == sel)); then out+="    ${CYAN}❯ ${BOLD}${shown[i]}${RESET}"$'\n'
      else out+="      ${shown[i]}"$'\n'; fi
      lines=$((lines + 1))
    done
    if ((${#shown[@]} == 0)); then
      out+="      ${DIM}nothing matches; Backspace to widen${RESET}"$'\n'
      lines=$((lines + 1))
    fi
    extra=''
    ((${#shown[@]})) && [[ -n $preview ]] && extra=$("$preview" "${shown[sel]}")$'\n'
    printf '%s%s' "$out" "$extra"
    nl=${extra//[^$'\n']/}

    if ((search)); then _ui_key key typing; else _ui_key key; fi
    case $key in
      up) ((${#shown[@]})) && current=${shown[(sel - 1 + ${#shown[@]}) % ${#shown[@]}]} ;;
      down) ((${#shown[@]})) && current=${shown[(sel + 1) % ${#shown[@]}]} ;;
      enter) ((${#shown[@]})) && { current=${shown[sel]}; break; } ;;
      backspace) filter=${filter%?} ;;
      escape) if [[ -n $filter ]]; then filter=''; else _ui_restore; printf '\n'; exit 130; fi ;;
      quit) _ui_restore; printf '\n'; exit 130 ;;
      *) ((search)) && [[ ${#key} == 1 && $key == [[:print:]] ]] && filter+=$key ;;
    esac
    printf '\e[%dA\e[J' $((lines + ${#nl}))
  done
  printf '\e[%dA\e[J' $((lines + ${#nl} + 1))
  [[ -z $nocase ]] && shopt -u nocasematch
  trap - INT
  _ui_cursor h
  printf -v "$__var" '%s' "$current"
  _ui_answered "$question" "$current"
}

# ui_confirm VAR "question" y|n   stores 1 or 0 in VAR.
ui_confirm() {
  local __var=$1 question=$2 def=$3 key answer hint='y/N'
  [[ $def == y ]] && hint='Y/n'
  if ui_interactive; then
    printf '  %s?%s %s%s%s %s(%s)%s ' "${CYAN}" "${RESET}" "${BOLD}" "$question" "${RESET}" "${DIM}" "$hint" "${RESET}"
    while :; do
      IFS= read -rsn1 key
      case $key in y | Y) answer=y; break ;; n | N) answer=n; break ;; '') answer=$def; break ;; esac
    done
    printf '\r\e[K'
  else
    answer=$def
  fi
  [[ $answer == y ]] && printf -v "$__var" 1 || printf -v "$__var" 0
  _ui_answered "$question" "$([[ $answer == y ]] && echo yes || echo no)"
}

# ui_input VAR "question" DEFAULT [REGEX]   free text, re-asked until it matches.
ui_input() {
  local __var=$1 question=$2 def=$3 re=${4:-} value
  if ui_interactive; then
    while :; do
      printf '  %s?%s %s%s%s %s(%s)%s ' "${CYAN}" "${RESET}" "${BOLD}" "$question" "${RESET}" "${DIM}" "$def" "${RESET}"
      IFS= read -r value
      value=${value:-$def}
      printf '\e[1A\e[K'
      [[ -z $re || $value =~ $re ]] && break
      ui_warn "\"$value\" doesn't look right"
    done
  else
    value=$def
  fi
  printf -v "$__var" '%s' "$value"
  _ui_answered "$question" "$value"
}

# ui_spin "label" CMD...   run CMD with its output in $LOG, behind a spinner.
#   On failure, shows the end of the log and returns CMD's status.
ui_spin() {
  local label=$1 pid status frame=0
  shift
  local frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  if [[ -n ${DRY_RUN:-} ]]; then ui_skip "would: $label"; return; fi

  printf '\n== %s\n' "$label" >>"$LOG"
  "$@" >>"$LOG" 2>&1 &
  pid=$!
  if [[ -t 1 ]]; then
    _ui_cursor l
    while kill -0 "$pid" 2>/dev/null; do
      printf '\r  %s%s%s %s' "${MAGENTA}" "${frames[frame]}" "${RESET}" "$label"
      frame=$(((frame + 1) % ${#frames[@]}))
      sleep 0.08
    done
    printf '\r\e[K'
    _ui_cursor h
  fi
  wait "$pid"
  status=$?
  if ((status == 0)); then
    ui_ok "$label"
  else
    ui_err "$label"
    tail -n 15 "$LOG" | sed "s/^/      ${DIM}/;s/\$/${RESET}/" >&2
    ui_note "full log: $LOG"
  fi
  return $status
}
