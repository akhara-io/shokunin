# 職人 shokunin

One command sets up a terminal on macOS or Linux: Ghostty, tmux, zsh with
powerlevel10k, Neovim and eza. Everything shares one theme, it's light by day
and dark after hours, and it includes a few helpers for offsec-related engagements.

```sh
git clone https://github.com/akhara-io/shokunin ~/.local/share/shokunin
~/.local/share/shokunin/install.sh
```

The installer asks a few questions:

- a theme for the day and one for the evening, with a live preview of each
- when to switch between them
- a font and its size
- the prompt style
- whether to auto-start tmux and turn on the engagement helpers

Then it installs the software and sets everything up. Run it again at any time
to change your answers. It starts from your previous ones.

| Flag            | What it does                                                |
| --------------- | ----------------------------------------------------------- |
| `--yes`         | Take the defaults (or your previous answers) without asking |
| `--dry-run`     | Show what would change, change nothing                      |
| `--no-packages` | Configs only; you install the software                      |
| `--uninstall`   | Remove what shokunin made and restore your old files        |

## What you get

- `Ghostty` with your font and theme pair. It uses a block cursor, left
  Option acts as Alt, and Cmd+/ opens the cheatsheet.
- `tmux`: the prefix is Ctrl+Space, and Alt+h/j/k/l moves between panes and
  Neovim splits. The status bar shows your VPN/HTB address, the current
  target, and a sun or moon for day or night. `prefix + h` lists every key.
  A yellow pill shows outdated Homebrew packages (checked every 6 hours); click
  it or press `prefix + U` to upgrade.
- `zsh`: oh-my-zsh, powerlevel10k (pills or lean), autosuggestions and syntax
  highlighting, with a blank line before and after each command's output.
- `Neovim` 0.12 on its built-in plugin manager, with a colorscheme built from
  your themes:
  - File tree: nvim-tree. Cmd+E opens and closes it.
  - Find and search: Cmd+P finds files and Cmd+Shift+F searches inside them
    (or Space ff / Space fg).
  - `Git:` lazygit in a popup, with Space gg in Neovim or prefix + g in tmux.
  - Your Obsidian vaults: obsidian.nvim, so you can follow `[[links]]` and
    search notes (Space oo, os, on, ob, ot).
  - Syntax highlighting: `treesitter`.
  - Language servers and linting: clangd with clang-tidy, OmniSharp,
    PowerShell Editor Services, pyright and ruff, ruby-lsp, and asm-lsp, all
    installed by Mason.
  - Completion: only when you ask. Tab opens the list or moves down it,
    Shift+Tab moves up, and Enter accepts. There are no snippets and nothing
    pops up while you type.
  - No formatting, ever: nothing reformats your code, and saving doesn't
    trim whitespace or add newlines.
- `Obsidian`: every vault gets a CSS snippet in the same colours and font,
  set to follow the system's light/dark mode.
- `eza` with icons and git status: `l`, `ll`, `lS` (by size), `lm` (by date),
  `lt` (tree).
- Engagement helpers:
  - `target <ip>` sets `$ip` and shows it in the prompt and the tmux bar.
  - `lhost` prints your VPN address and copies it.
  - `clip` and `fixclip` copy text cleaned up for notes.

### Light and dark

The system appearance is the single switch. With "by time of day", a
LaunchAgent (macOS) or systemd timer (Linux, GNOME) runs `daynight` at your
two hours and at login. Ghostty, tmux, Neovim, the prompt and eza all follow
the system setting. Run `daynight dark` or `daynight light` to flip it by hand.

Colours come from the two Ghostty themes you pick:

- `tmux`: its built-in light/dark theme colours.
- `Neovim`: a palette, with UI shades blended from the theme.
- `Prompt` and `eza`: ANSI palette slots, so they change along with Ghostty.
- `Prompt pills`: the text colour is picked by contrast across both themes.

## Layout

```
install.sh        entry point
lib/              ui (menus, spinner), sys (links, backups), themes, packages
config/           zsh, tmux, nvim, eza; symlinked into ~/.config
bin/              appearance, daynight; symlinked into ~/.local/bin
themes/           curated Ghostty themes (+ Shokunin Night)
```

Static config is symlinked from the checkout, so `git pull` updates it.

- Your choices and the files generated from them live in
  `~/.config/shokunin/`.
- Anything the installer replaces is moved to
  `~/.local/state/shokunin/backups/`.
- Your own shell additions go at the bottom of `~/.zshrc`.

Homebrew installs the software on both platforms, so every machine gets the
same versions. Most distros ship a tmux too old for theme colours, and a
Neovim too old for `vim.pack`.

## Credits

The theme files come from Ghostty's bundled collection (iTerm2-Color-Schemes,
MIT). Shokunin Night is this project's dark companion to Shokunin.
