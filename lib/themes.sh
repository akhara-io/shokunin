# shellcheck shell=bash
# Themes: find Ghostty theme files, preview them, and turn the light/dark pair
# into tmux colours, an nvim palette and a prompt pill text colour.

# Picks shown first in each list. load_themes adds every other theme after them.
LIGHT_PICKS=("Shokunin" "Modus Operandi Tinted" "Catppuccin Latte" "Rose Pine Dawn" "GitHub Light Default"
  "TokyoNight Day" "Everforest Light Med" "Gruvbox Light" "Flexoki Light" "Kanagawa Lotus")
DARK_PICKS=("Shokunin Night" "Modus Vivendi Tinted" "Catppuccin Mocha" "Rose Pine" "GitHub Dark Default"
  "TokyoNight" "Everforest Dark Hard" "Gruvbox Dark" "Flexoki Dark" "Kanagawa Wave" "Nord")
LIGHT_THEMES=("${LIGHT_PICKS[@]}")
DARK_THEMES=("${DARK_PICKS[@]}")

# Where themes live, in lookup order: shokunin's own, Ghostty's bundled
# collection (macOS, then Linux), then your own.
THEME_DIRS=("$ROOT/themes" /Applications/Ghostty.app/Contents/Resources/ghostty/themes
  /usr/share/ghostty/themes "$HOME/.config/ghostty/themes")

# Colour maths for awk: WCAG contrast and linear blends of #rrggbb.
COLOR_AWK='
function hx(h, i) { return index("0123456789abcdef", substr(tolower(h), i, 1)) - 1 }
function ch(h, i) { return hx(h, i) * 16 + hx(h, i + 1) }
function lin(v) { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ^ 2.4 }
function lum(h) { return 0.2126 * lin(ch(h, 2)) + 0.7152 * lin(ch(h, 4)) + 0.0722 * lin(ch(h, 6)) }
function contrast(a, b,   x, y) { x = lum(a) + 0.05; y = lum(b) + 0.05; return x > y ? x / y : y / x }
function blend(a, b, t,   i, out) {
  out = "#"
  for (i = 2; i <= 6; i += 2) out = out sprintf("%02x", int(ch(a, i) + (ch(b, i) - ch(a, i)) * t + 0.5))
  return out
}'

theme_file() {
  local dir
  for dir in "${THEME_DIRS[@]}"; do
    [[ -f $dir/$1 ]] && { printf '%s\n' "$dir/$1"; return; }
  done
  return 1
}

# load_themes   fill LIGHT_THEMES and DARK_THEMES with every usable theme: the
# picks first, then the rest A-Z. Usable means a background, a foreground and
# all 16 colours, which the tmux, Neovim and prompt colours are built from. A
# theme is light when its background is.
load_themes() {
  local dir kind name seen
  local files=()
  for dir in "${THEME_DIRS[@]}"; do
    [[ -d $dir ]] && for name in "$dir"/*; do [[ -f $name ]] && files+=("$name"); done
  done
  LIGHT_THEMES=("${LIGHT_PICKS[@]}") DARK_THEMES=("${DARK_PICKS[@]}")
  seen=$'\n'$(printf '%s\n' "${LIGHT_PICKS[@]}" "${DARK_PICKS[@]}")$'\n'
  ((${#files[@]})) || return 0
  while IFS=$'\t' read -r kind name; do
    [[ $seen == *$'\n'"$name"$'\n'* ]] && continue
    seen+="$name"$'\n'
    if [[ $kind == light ]]; then LIGHT_THEMES+=("$name"); else DARK_THEMES+=("$name"); fi
  done < <(awk -F' *= *' "$COLOR_AWK"'
    function flush(   name) {
      if (file == "") return
      name = file; sub(/.*\//, "", name)
      if (bg ~ /^#[0-9a-fA-F]{6}$/ && fg ~ /^#[0-9a-fA-F]{6}$/ && n >= 16)
        printf "%s\t%s\n", (lum(bg) > 0.25 ? "light" : "dark"), name
    }
    FNR == 1 { flush(); file = FILENAME; bg = fg = ""; n = 0; split("", got) }
    $1 == "background" { bg = $2 }
    $1 == "foreground" { fg = $2 }
    $1 == "palette" && $3 ~ /^#[0-9a-fA-F]{6}$/ && !($2 in got) { got[$2]; n++ }
    END { flush() }' "${files[@]}" | sort -f -t$'\t' -k2)
}

# theme_palette FILE   one line: bg fg selection ansi0 ... ansi15
theme_palette() {
  awk -F' *= *' '
    $1 == "background" { bg = $2 } $1 == "foreground" { fg = $2 }
    $1 == "selection-background" { sel = $2 }
    $1 == "palette" { pal[$2] = $3 }   # "palette = 4=#006fae" splits as palette, 4, #006fae
    END {
      printf "%s %s %s", bg, fg, (sel == "" ? "-" : sel)
      for (i = 0; i < 16; i++) printf " %s", pal[i]
      print ""
    }' "$1" | tr 'A-F' 'a-f'
}

_rgb() { printf '%d;%d;%d' "0x${1:1:2}" "0x${1:3:2}" "0x${1:5:2}"; }  # #rrggbb -> r;g;b

# theme_preview NAME   two lines of fake prompt in the theme's own colours.
theme_preview() {
  local file p
  file=$(theme_file "$1") || return 0
  if ! ui_truecolor; then ui_note "(previews need a truecolor terminal, like Ghostty)"; return; fi
  read -r -a p <<<"$(theme_palette "$file")"
  local bg fg i swatch=''
  bg=$(_rgb "${p[0]}") fg=$(_rgb "${p[1]}")
  for i in 4 5 6 7 8 9 12 13 14 15 16 17; do swatch+="\e[38;2;$(_rgb "${p[i]}")m■ "; done
  printf "\n      \e[48;2;%sm\e[38;2;%sm  \e[38;2;%sm~/work \e[38;2;%smmain \e[38;2;%sm❯\e[38;2;%sm nmap -sC 10.10.11.42   \e[0m\n" \
    "$bg" "$fg" "$(_rgb "${p[7]}")" "$(_rgb "${p[8]}")" "$(_rgb "${p[5]}")" "$fg"
  printf "      \e[48;2;%sm  $swatch           \e[0m" "$bg"
}

# theme_palettes LIGHT DARK   both palette lines, light first; dies if missing.
theme_palettes() {
  local name file
  for name in "$1" "$2"; do
    file=$(theme_file "$name") || die "theme not found: $name"
    theme_palette "$file"
  done
}

# tmux theme colours. Light themes use the normal accents, dark the brights,
# so text on a pill (the theme background) stays readable either way.
gen_tmux_theme() {
  theme_palettes "$1" "$2" | awk "$COLOR_AWK"'
    { mode = NR == 1 ? "light" : "dark"; off = NR == 1 ? 4 : 12
      v[mode, "black"] = $2; v[mode, "white"] = $1
      v[mode, "light-grey"] = blend($1, $2, 0.12); v[mode, "dark-grey"] = blend($1, $2, 0.55)
      split("red green yellow blue magenta cyan", names, " ")
      for (i = 1; i <= 6; i++) v[mode, names[i]] = $(off + i) }
    END {
      print "# Generated by shokunin from the themes you picked. Re-run install.sh to change."
      n = split("black white light-grey dark-grey red green yellow blue magenta cyan", keys, " ")
      for (i = 1; i <= n; i++)
        printf "set -g light-theme-%-10s %s ; set -g dark-theme-%-10s %s\n", keys[i], "\x27" v["light", keys[i]] "\x27", keys[i], "\x27" v["dark", keys[i]] "\x27"
    }'
}

# nvim palette: the raw theme colours; colors/shokunin.lua derives the rest.
gen_nvim_palette() {
  theme_palettes "$1" "$2" | awk -v light="$1" -v dark="$2" '
    { mode = NR == 1 ? "light" : "dark"; name = NR == 1 ? light : dark
      out = out sprintf("  %s = {\n    name = \"%s\", bg = \"%s\", fg = \"%s\",%s\n    ansi = {", mode, name, $1, $2,
        $3 == "-" ? "" : sprintf(" selection = \"%s\",", $3))
      for (i = 4; i <= 19; i++) out = out sprintf("%s\"%s\"", i == 4 ? " " : ", ", $i)
      out = out " },\n  },\n" }
    END { printf "-- Generated by shokunin from the themes you picked. Re-run install.sh to change.\nreturn {\n%s}\n", out }'
}

# Pill text colour for the prompt: ANSI 15 (white) or 0 (black), whichever
# keeps the worst pill (ANSI 1-6 in either theme) most readable.
pill_fg() {
  theme_palettes "$1" "$2" | awk "$COLOR_AWK"'
    { for (i = 5; i <= 10; i++) {
        w = contrast($19, $i); b = contrast($4, $i)
        if (NR == 1 && i == 5 || w < minw) minw = w
        if (NR == 1 && i == 5 || b < minb) minb = b } }
    END { print (minw >= minb ? 15 : 0) }'
}

# Obsidian CSS snippet: the same palette as Neovim, as Obsidian's theme
# variables, under .theme-light and .theme-dark; FONT for code blocks.
gen_obsidian_css() {
  theme_palettes "$1" "$2" | awk -v font="$3" "$COLOR_AWK"'
    function rgb(h) { return ch(h, 2) ", " ch(h, 4) ", " ch(h, 6) }
    function v(name, value) { printf "  --%s: %s;\n", name, value }
    BEGIN {
      print "/* Generated by shokunin from the themes you picked. Re-run install.sh to change. */"
      # A theme-level font: your own Obsidian font setting still wins.
      if (font != "") printf "\nbody {\n  --font-monospace-theme: \"%s\";\n}\n", font
    }
    {
      off = NR == 1 ? 4 : 12   # light themes: normal accents; dark: the brights
      bg = $1; fg = $2
      red = $(off + 1); green = $(off + 2); yellow = $(off + 3); blue = $(off + 4); magenta = $(off + 5); cyan = $(off + 6)
      alt = blend(bg, fg, 0.04); line = blend(bg, fg, 0.07); border = blend(bg, fg, 0.18)
      dim = blend(bg, fg, 0.6); faint = blend(bg, fg, 0.4); hover = blend(blue, fg, 0.15)

      printf "\n%s {\n", (NR == 1 ? ".theme-light" : ".theme-dark")
      v("background-primary", bg); v("background-primary-alt", alt)
      v("background-secondary", alt); v("background-secondary-alt", line)
      v("background-modifier-border", border); v("background-modifier-hover", line)
      v("background-modifier-form-field", bg); v("divider-color", border)
      v("titlebar-background", alt); v("titlebar-background-focused", line)
      v("text-normal", fg); v("text-muted", dim); v("text-faint", faint); v("text-on-accent", bg)
      v("text-selection", ($3 == "-" ? blend(bg, blue, 0.25) : $3))
      v("text-highlight-bg", blend(bg, yellow, 0.3))
      v("color-accent", blue); v("color-accent-1", hover); v("color-accent-2", hover)
      v("interactive-accent", blue); v("interactive-accent-hover", hover)
      v("text-accent", blue); v("text-accent-hover", hover)
      v("link-color", blue); v("link-color-hover", hover)
      v("link-external-color", cyan); v("link-unresolved-color", dim)
      v("h1-color", blue); v("h2-color", magenta); v("h3-color", cyan)
      v("h4-color", green); v("h5-color", yellow); v("h6-color", dim)
      v("tag-color", cyan); v("tag-background", blend(bg, cyan, 0.12))
      v("blockquote-border-color", border); v("checkbox-color", blue); v("checkbox-border-color", dim)
      v("indentation-guide-color", blend(bg, fg, 0.28)); v("indentation-guide-color-active", blend(bg, fg, 0.5))
      v("code-background", alt); v("code-normal", fg); v("code-comment", dim)
      v("code-keyword", red); v("code-function", blue); v("code-string", green)
      v("code-value", magenta); v("code-property", cyan); v("code-tag", blue)
      v("code-operator", dim); v("code-punctuation", dim); v("code-important", yellow)
      split("red green yellow orange blue cyan purple pink", names, " ")
      split(red " " green " " yellow " " yellow " " blue " " cyan " " magenta " " magenta, hexes, " ")
      for (i = 1; i <= 8; i++) { v("color-" names[i], hexes[i]); v("color-" names[i] "-rgb", rgb(hexes[i])) }
      print "}"
    }'
  # Structure is the same for every theme pair. body.theme-* outranks themes
  # (Maple, Minimal) that set these on plain body, without needing !important.
  cat <<'EOF'

/* Headings: GitHub's size steps. h1 sits on a hairline rule that starts with
   a short stroke in the heading's own colour. */
body.theme-light,
body.theme-dark {
  --h1-size: 2em;     --h1-weight: 600; --h1-line-height: 1.25;
  --h2-size: 1.5em;   --h2-weight: 600; --h2-line-height: 1.25;
  --h3-size: 1.25em;  --h3-weight: 600;
  --h4-size: 1em;     --h4-weight: 600;
  --h5-size: 0.875em; --h5-weight: 600;
  --h6-size: 0.85em;  --h6-weight: 600;

  --blockquote-border-thickness: 0.25em;
  --blockquote-color: var(--text-muted);
  --blockquote-font-style: normal;

  --table-border-width: 1px;
  --table-border-color: var(--background-modifier-border);
  --table-header-background: var(--background-primary-alt);
  --table-header-weight: 600;

  --checklist-done-decoration: line-through;
  --checklist-done-color: var(--text-muted);
  --checkbox-radius: 4px;

  --hr-thickness: 2px;
  --hr-color: var(--background-modifier-border);

  --tag-radius: 999px;
  --tag-padding-x: 0.55em;
  --tag-padding-y: 0.1em;
  --tag-size: 0.85em;

  --link-decoration-thickness: 1px;
}

.markdown-rendered h1,
.markdown-source-view.mod-cm6.is-live-preview .HyperMD-header-1 {
  padding-bottom: 0.3em;
  border-bottom: 1px solid var(--background-modifier-border);
  background: linear-gradient(var(--h1-color), var(--h1-color)) left bottom / 3em 3px no-repeat;
}
.markdown-rendered :is(h1, h2, h3, h4, h5, h6) {
  margin-top: 1.5em;
  margin-bottom: 0.75em;
}

/* Quotes line up with callouts: the same bar and the same indent. */
.markdown-rendered blockquote {
  padding-inline-start: 1em;
}

/* Code: inline code gets a frame in reading view; blocks get a ruled box. */
.markdown-rendered :not(pre) > code {
  padding: 0.1em 0.35em;
  border: 1px solid var(--background-modifier-border);
  border-radius: 4px;
}
.markdown-rendered pre {
  padding: 0.9em 1.1em;
  border: 1px solid var(--background-modifier-border);
  border-radius: 0;
}
.markdown-rendered li > pre {
  margin-block: 0.5em 0.75em;
}
body.theme-light,
body.theme-dark {
  --code-radius: 0;
}

/* Code blocks inside a list, in live preview. Each line starts with the
   list's tabs, and Obsidian paints the background from the page edge and runs
   the list's guides through the block. Instead: no guides, and the background
   starts where the code does (one tab per level), less a little padding.
   Tabs on these lines are widened by that padding so the code isn't flush
   against the edge, with the cursor in the block or out of it. */
.markdown-source-view.mod-cm6 .cm-line.HyperMD-codeblock.HyperMD-list-line {
  --shokunin-code-pad: 0.75em;
  --shokunin-code-tab: calc(var(--list-indent) + var(--shokunin-code-pad));
  --shokunin-code-depth: 1;
  tab-size: var(--shokunin-code-tab);
}
.markdown-source-view.mod-cm6 .cm-line.HyperMD-codeblock.HyperMD-list-line:has(.cm-indent + .cm-indent) {
  --shokunin-code-depth: 2;
}
.markdown-source-view.mod-cm6 .cm-line.HyperMD-codeblock.HyperMD-list-line:has(.cm-indent + .cm-indent + .cm-indent) {
  --shokunin-code-depth: 3;
}
.markdown-source-view.mod-cm6 .cm-line.HyperMD-codeblock.HyperMD-codeblock-bg.HyperMD-list-line {
  --shokunin-code-start: calc(var(--shokunin-code-depth) * var(--shokunin-code-tab) - var(--shokunin-code-pad));
  background-color: transparent;
  background-image: linear-gradient(to right,
    transparent var(--shokunin-code-start), var(--code-background) var(--shokunin-code-start));
}
.markdown-source-view.mod-cm6 .cm-line.HyperMD-codeblock.HyperMD-list-line .cm-indent {
  min-width: var(--shokunin-code-tab);
}
.markdown-source-view.mod-cm6 .cm-line.HyperMD-codeblock.HyperMD-list-line .cm-indent::before {
  display: none;
}

/* Keys look like keys: <kbd>Cmd</kbd>+<kbd>P</kbd>. */
body .markdown-rendered kbd,
body .markdown-source-view kbd {
  padding: 0.2em 0.45em;
  font-family: var(--font-monospace);
  font-size: 0.8em;
  line-height: 1;
  vertical-align: 0.1em;
  color: var(--text-normal);
  background-color: var(--background-primary-alt);
  border: 1px solid var(--background-modifier-border);
  border-radius: 4px;
  box-shadow: inset 0 -2px 0 var(--background-modifier-border);
}

/* Callouts: drawn like a tmux pane, a thin frame with the title set into its
   top border. Frame and title take the callout's colour; the body is plain
   text. --callout-color is a full colour (not an r, g, b list), so Obsidian's
   own variables do most of the work. */
body.theme-light,
body.theme-dark {
  --callout-border-width: 1px;
  --callout-border-opacity: 0.55;
  --callout-radius: 0;
  --callout-padding: 0 1em 0.75em;
  --callout-blend-mode: normal;
  --callout-title-weight: 600;
  --callout-quote: var(--text-muted);
}
body .callout {
  overflow: visible; /* the title sits half outside the frame */
  margin-block: 1.75em 1.25em;
  background-color: transparent;
}
body .callout.is-collapsed {
  padding-bottom: 0.3em;
}
/* Live preview paints each embed only inside its own box (contain: paint), and
   the callout's top margin collapses out of that box, so the title's top half
   was cut off. Pad the box instead, so the title sits inside it. */
body .markdown-source-view.mod-cm6 .cm-embed-block.cm-callout {
  padding-top: 0.9em;
}
body .markdown-source-view.mod-cm6 .cm-embed-block.cm-callout .callout {
  margin-top: 0;
}
/* Pull the title up onto the border and paint the page behind it, so the
   frame breaks around the label. */
body .callout-title {
  width: fit-content;
  margin-top: calc(var(--line-height-tight) * -0.5em);
  margin-inline-start: -0.4em;
  padding: 0 0.4em;
  align-items: center;
  background-color: var(--background-primary);
}
body .callout-content > :first-child {
  margin-top: 0.4em;
}
body .callout-content > :last-child {
  margin-bottom: 0;
}

/* Lists: in reading view, nested items hang off a line from their parent's
   bullet and branch into their own (├ ╰), like a tree. It follows Obsidian's
   "Indentation guides" setting. Live preview keeps Obsidian's straight guides.
   Positions come from Obsidian's list layout: bullets sit 0.8em before their
   item, and its own guide sits at --indentation-guide-reading-indent. */
body {
  --shokunin-tree-x: calc(var(--indentation-guide-reading-indent) - var(--list-indent));
  --shokunin-tree-y: calc(var(--list-spacing) + var(--line-height-normal) * 0.5em);
  --shokunin-tree-curve: 0.45em;
}
body .markdown-rendered.show-indentation-guide li > :is(ul, ol)::before {
  border-inline-end: none;
}
.markdown-rendered.show-indentation-guide li > :is(ul, ol) > li {
  --shokunin-trunk-top: 0px;
  --shokunin-tree-gap: 1.15em; /* where a branch stops, measured back from the item */
  --shokunin-tree-shift: 0px;  /* moves the trunk left to centre it under the parent's marker */
  margin-inline-start: var(--list-indent);
}
.markdown-rendered.show-indentation-guide ol > li > :is(ul, ol) > li {
  --shokunin-tree-shift: 0.45em; /* under the number, not its full stop */
}
.markdown-rendered.show-indentation-guide li.task-list-item > :is(ul, ol) > li {
  --shokunin-tree-shift: 0.15em; /* under the middle of the checkbox */
}
.markdown-rendered.show-indentation-guide li > :is(ul, ol) > li:first-child {
  /* Reach back up to the parent's bullet. */
  --shokunin-trunk-top: calc(var(--line-height-normal) * -0.5em + 0.35em);
}
.markdown-rendered.show-indentation-guide li > ol > li {
  --shokunin-tree-gap: 1.75em; /* stop short of the number */
}
.markdown-rendered.show-indentation-guide li > :is(ul, ol) > li.task-list-item {
  --shokunin-tree-gap: 1.7em; /* stop short of the checkbox */
}
.markdown-rendered.show-indentation-guide li > :is(ul, ol) > li::before,
.markdown-rendered.show-indentation-guide li > :is(ul, ol) > li::after {
  content: "";
  position: absolute;
  pointer-events: none;
  border: 0 solid var(--indentation-guide-color);
}
/* The trunk runs the whole item, so it meets the next sibling's. */
.markdown-rendered.show-indentation-guide li > :is(ul, ol) > li::before {
  inset-inline-start: calc(var(--shokunin-tree-x) - var(--shokunin-tree-shift));
  top: var(--shokunin-trunk-top);
  bottom: 0;
  border-inline-start-width: var(--indentation-guide-width);
}
/* The branch into the bullet. */
.markdown-rendered.show-indentation-guide li > :is(ul, ol) > li::after {
  inset-inline-start: calc(var(--shokunin-tree-x) - var(--shokunin-tree-shift));
  top: calc(var(--shokunin-tree-y) - var(--indentation-guide-width));
  width: calc(var(--list-indent) - var(--indentation-guide-reading-indent) - var(--shokunin-tree-gap) + var(--shokunin-tree-shift));
  border-top-width: var(--indentation-guide-width);
}
/* The last item's trunk stops at its bullet and curves into the branch. */
.markdown-rendered.show-indentation-guide li > :is(ul, ol) > li:last-child::before {
  bottom: auto;
  width: var(--shokunin-tree-curve);
  height: calc(var(--shokunin-tree-y) - var(--shokunin-trunk-top));
  border-bottom-width: var(--indentation-guide-width);
  border-end-start-radius: var(--shokunin-tree-curve);
}
.markdown-rendered.show-indentation-guide li > :is(ul, ol) > li:last-child::after {
  inset-inline-start: calc(var(--shokunin-tree-x) - var(--shokunin-tree-shift) + var(--shokunin-tree-curve));
  width: calc(var(--list-indent) - var(--indentation-guide-reading-indent) - var(--shokunin-tree-gap) + var(--shokunin-tree-shift) - var(--shokunin-tree-curve));
}

/* Tables: ruled cells, a shaded header and alternate rows. */
.markdown-rendered tbody tr:nth-child(2n),
.markdown-source-view .cm-table-widget tbody tr:nth-child(2n) {
  background-color: var(--background-primary-alt);
}

/* Pills for finding severity and status. A Bases formula wraps the value in
   <span class="shokunin-pill" data-value="critical">; the colour comes from
   the value. The most urgent value is filled, the rest are tinted. */
.shokunin-pill {
  --pill: var(--text-muted);
  display: inline-block;
  padding: 0.05em 0.65em;
  font-size: 0.85em;
  font-weight: 600;
  line-height: 1.5;
  white-space: nowrap;
  color: var(--pill);
  background-color: color-mix(in oklch, var(--pill) 14%, transparent);
  border: 1px solid color-mix(in oklch, var(--pill) 40%, transparent);
  border-radius: 999px;
}
.shokunin-pill[data-value="critical"] {
  --pill: var(--color-red);
  color: var(--background-primary);
  background-color: var(--pill);
  border-color: var(--pill);
}
.shokunin-pill:is([data-value="high"], [data-value="needs action"]) { --pill: var(--color-red); }
.shokunin-pill:is([data-value="medium"], [data-value="retesting"]) { --pill: var(--color-yellow); }
.shokunin-pill:is([data-value="low"], [data-value="resolved"]) { --pill: var(--color-green); }
.shokunin-pill[data-value="open"] { --pill: var(--color-blue); }
EOF
}
