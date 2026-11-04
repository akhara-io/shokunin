# shokunin zsh setup. Sourced first thing from ~/.zshrc; choices made in
# install.sh live in ~/.config/shokunin/config.

[[ -r ~/.config/shokunin/config ]] && source ~/.config/shokunin/config

# Homebrew (login shells get this from ~/.zprofile; cover the rest)
if [[ -z $HOMEBREW_PREFIX ]]; then
  for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    [[ -x $_brew ]] && { eval "$($_brew shellenv)"; break; }
  done
  unset _brew
fi

# Auto-start tmux in Ghostty: every tab gets its own session, marked with its
# tab (@tab) so tmux removes it when the tab closes (see tmux.conf); tabs never
# share or inherit one. When tmux returns the tab closes, like any shell; if tmux can't
# start you keep a plain shell. Skipped inside tmux, nvim's :terminal, Claude
# Code, and other terminals.
if [[ ${SHOKUNIN_TMUX_AUTOSTART:-1} == 1 && -o interactive && -z $TMUX$NVIM$CLAUDECODE &&
      $TERM_PROGRAM == ghostty ]] && (( $+commands[tmux] )); then
  tmux new \; set -F @tab '#{client_tty}' && exit
fi

# p10k instant prompt. Anything that needs console input must go above this.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# oh-my-zsh
export ZSH=~/.oh-my-zsh
ZSH_THEME=""  # powerlevel10k is sourced below
plugins=(git colored-man-pages sudo extract)
fpath=($HOMEBREW_PREFIX/share/zsh-completions $fpath)  # before compinit
source $ZSH/oh-my-zsh.sh

export EDITOR=nvim
path=(~/.local/bin $path)

# History
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE SHARE_HISTORY

# A blank line between a command and its output, matching the one p10k puts
# before each prompt, so every block is spaced the same.
autoload -Uz add-zsh-hook
_gap_before_output() { print }
add-zsh-hook preexec _gap_before_output

# Keys. Ghostty maps Opt+arrows to word motion and Cmd+arrows to ^A/^E.
WORDCHARS=${WORDCHARS//[\/.=-]}  # word motion stops at / . = -
bindkey '^U' backward-kill-line   # Cmd+Backspace: delete to start of line

# eza: icons, git status, dirs first. Theme: ~/.config/eza/theme.yml, which
# oh-my-zsh's LS_COLORS would override (completion has already read it).
unset LS_COLORS
export EZA_CONFIG_DIR=~/.config/eza
_eza="eza --icons=auto --group-directories-first --hyperlink --color-scale=all --color-scale-mode=fixed"
_eza_long="$_eza --long --all --header --git --time-style='+%d %b %y  %H:%M'"
_eza_tree="$_eza --tree --all --git-ignore --ignore-glob='.git|node_modules|.DS_Store'"
alias ls="$_eza"                                                           # plain grid
alias la="$_eza --all"                                                     # grid, with hidden
alias l="$_eza_long --no-permissions --no-user"                            # long: size, date, git
alias ll="$_eza_long --octal-permissions"                                  # long + permissions/owner
alias lS="$_eza_long --no-permissions --no-user --sort=size --total-size"  # by size, biggest at the bottom
alias lm="$_eza_long --no-permissions --no-user --sort=modified"           # by date, newest at the bottom
alias lt="$_eza_tree --level=2"                                            # tree, 2 deep
alias ltt="$_eza_tree --level=4"                                           # tree, 4 deep
unset _eza _eza_long _eza_tree

[[ ${SHOKUNIN_ENGAGEMENT:-1} == 1 ]] && source ~/.config/zsh/engagement.zsh

# Homebrew: suggest the formula for a missing command
[[ -r $HOMEBREW_REPOSITORY/Library/Homebrew/command-not-found/handler.sh ]] &&
  source $HOMEBREW_REPOSITORY/Library/Homebrew/command-not-found/handler.sh

# Prompt
source $HOMEBREW_PREFIX/share/powerlevel10k/powerlevel10k.zsh-theme
[[ -r ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Plugins that wrap ZLE widgets. Syntax highlighting must be last.
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
