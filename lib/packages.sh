# shellcheck shell=bash
# Software: Homebrew on both platforms (so every machine gets the same tmux,
# Neovim and friends), fonts, oh-my-zsh, and Ghostty itself on macOS.

FORMULAS=(zsh tmux neovim eza git powerlevel10k zsh-autosuggestions zsh-syntax-highlighting zsh-completions
  node tree-sitter-cli asm-lsp  # Neovim's language servers and parsers
  jq                            # Obsidian's settings are JSON
  ripgrep fd lazygit)           # search, file finding, git UI
DOTNET_FORMULAS=(dotnet powershell)  # C# and PowerShell language servers need these

# name|Ghostty font-family|macOS cask|Linux download (all Nerd Font builds)
NERD=https://github.com/ryanoasis/nerd-fonts/releases/latest/download
FONTS=(
  "Maple Mono|Maple Mono NF|font-maple-mono-nf|https://github.com/subframe7536/maple-font/releases/latest/download/MapleMono-NF.zip"
  "JetBrains Mono|JetBrainsMono Nerd Font|font-jetbrains-mono-nerd-font|$NERD/JetBrainsMono.zip"
  "Fira Code|FiraCode Nerd Font|font-fira-code-nerd-font|$NERD/FiraCode.zip"
  "Iosevka|Iosevka Nerd Font|font-iosevka-nerd-font|$NERD/Iosevka.zip"
  "Cascadia Code|CaskaydiaCove Nerd Font|font-caskaydia-cove-nerd-font|$NERD/CascadiaCode.zip"
  "Geist Mono|GeistMono Nerd Font|font-geist-mono-nerd-font|$NERD/GeistMono.zip"
  "IBM Plex Mono|BlexMono Nerd Font|font-blex-mono-nerd-font|$NERD/IBMPlexMono.zip"
)

font_names() { local f; for f in "${FONTS[@]}"; do printf '%s\n' "${f%%|*}"; done; }

# font_field NAME N   field N (1-4) of NAME's FONTS entry.
font_field() {
  local f
  for f in "${FONTS[@]}"; do
    [[ ${f%%|*} == "$1" ]] && { printf '%s\n' "$f" | cut -d'|' -f"$2"; return; }
  done
  return 1
}

brew_path() {
  local b
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
    [[ -x $b ]] && { printf '%s\n' "$b"; return; }
  done
  return 1
}

# Compilers and basics Homebrew needs on Linux, plus a system zsh for chsh.
linux_prereqs() {
  if have apt-get; then
    sudo apt-get update -qq && sudo apt-get install -y -qq build-essential procps curl file git zsh unzip fontconfig
  elif have dnf; then
    sudo dnf install -y -q gcc gcc-c++ make procps-ng curl file git zsh unzip fontconfig
  elif have pacman; then
    sudo pacman -S --needed --noconfirm base-devel procps-ng curl file git zsh unzip fontconfig
  elif have zypper; then
    sudo zypper -q install -y gcc make procps curl file git zsh unzip fontconfig
  else
    echo "no supported package manager (apt, dnf, pacman, zypper)" >&2
    return 1
  fi
}

brew_install_self() {
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

# Make brew usable now and in every future login shell.
brew_activate() {
  local brew line
  brew=$(brew_path) || return 1
  eval "$("$brew" shellenv)"
  line="eval \"\$($brew shellenv)\"  # shokunin"
  [[ -n ${DRY_RUN:-} ]] || grep -qF "$line" "$HOME/.zprofile" 2>/dev/null || printf '%s\n' "$line" >>"$HOME/.zprofile"
}

# brew_missing formula|cask NAME...   print the ones not installed yet.
brew_missing() {
  local kind=$1 installed name
  shift
  installed=$(brew list --"$kind" -1 2>/dev/null)
  for name; do grep -qxF "${name##*/}" <<<"$installed" || printf '%s\n' "$name"; done
}

font_install_linux() {
  local family=$1 url=$2 dir zip
  fc-list 2>/dev/null | grep -qiF "$family" && return 0
  dir=$HOME/.local/share/fonts/shokunin/${family// /}
  zip=$(mktemp)
  curl -fsSL "$url" -o "$zip" && mkdir -p "$dir" && unzip -oq "$zip" '*.ttf' -d "$dir"
  local status=$?
  rm -f "$zip"
  ((status == 0)) && fc-cache -f "$dir"
}

ohmyzsh_install() {
  git clone --depth 1 -q https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
}

# install_software   everything above, in order, behind spinners.
install_software() {
  local missing cask font_cask

  if [[ $OS == linux ]]; then
    ui_note "Homebrew needs a few system packages; sudo may ask for your password."
    run sudo -v || die "sudo is required on Linux"
    ui_spin "System packages (compilers, git, zsh, fontconfig)" linux_prereqs || die "couldn't install system packages"
  fi

  if brew_path >/dev/null; then
    ui_ok "Homebrew"
  else
    [[ $OS == macos ]] && { ui_note "Installing Homebrew; macOS may ask for your password."; run sudo -v; }
    ui_spin "Homebrew" brew_install_self || die "Homebrew install failed"
  fi
  [[ -n ${DRY_RUN:-} ]] && ! brew_path >/dev/null && return 0
  brew_activate || die "can't find brew after installing it"
  # zsh refuses completions under a group-writable share/ (Homebrew's own advice)
  run chmod go-w "$HOMEBREW_PREFIX/share"

  local formulas=("${FORMULAS[@]}")
  ((SHOKUNIN_DOTNET)) && formulas+=("${DOTNET_FORMULAS[@]}")
  missing=$(brew_missing formula "${formulas[@]}")
  if [[ -n $missing ]]; then
    # shellcheck disable=SC2086  # one formula per word
    ui_spin "tmux, Neovim, zsh plugins, eza ($(echo $missing | tr ' ' ','))" brew install $missing || die "brew install failed"
  else
    ui_ok "tmux, Neovim, zsh plugins, eza"
  fi

  if [[ $OS == macos ]]; then
    font_cask=$(font_field "$SHOKUNIN_FONT" 3)
    for cask in ghostty "$font_cask"; do
      if [[ -n $(brew_missing cask "$cask") ]]; then
        ui_spin "$cask" brew install --cask "$cask" || ui_warn "couldn't install $cask"
      else
        ui_ok "$cask"
      fi
    done
  else
    ui_spin "Font: $SHOKUNIN_FONT" font_install_linux "$(font_field "$SHOKUNIN_FONT" 2)" "$(font_field "$SHOKUNIN_FONT" 4)" ||
      ui_warn "couldn't install the font; Ghostty will fall back to its default"
    if have ghostty; then
      ui_ok "Ghostty"
    else
      ui_warn "Ghostty isn't installed. Most distros package it: https://ghostty.org/docs/install/binary"
      ui_note "Its config is set up already, so it'll look right the first time it opens."
    fi
  fi

  if [[ -d $HOME/.oh-my-zsh ]]; then
    ui_ok "oh-my-zsh"
  else
    ui_spin "oh-my-zsh" ohmyzsh_install && _record "$HOME/.oh-my-zsh"
  fi
}
