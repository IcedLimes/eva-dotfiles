#!/bin/sh
# Install the EVA Hyprland setup into ~/.config.
#
#   ./install.sh             configs (anything they'd replace is backed up
#                            first), the clock font, the wallpapers, and every
#                            app's colors from the theme
#   ./install.sh --plugins   the same, then build the two Hyprland plugins
#                            (title bars, blur cache) for your Hyprland
#
# It doesn't install packages; it tells you what's missing. See README.md.
set -e
repo=$(cd "$(dirname "$0")" && pwd)
dst="${XDG_CONFIG_HOME:-$HOME/.config}"
backup="$dst/eva-backup-$(date +%Y%m%d-%H%M%S)"

# ---- what's missing -------------------------------------------------------

missing=""
for c in Hyprland hyprctl quickshell hypridle hyprlock hyprsunset mako makoctl fuzzel kitty \
         grim slurp satty wl-copy wl-paste cliphist brightnessctl playerctl wpctl jq python3; do
    command -v "$c" >/dev/null 2>&1 || missing="$missing $c"
done
if [ -n "$missing" ]; then
    echo "not installed:$missing"
    echo "(the setup still installs; those parts won't work until they are, see README.md)"
fi

# ---- back up, then copy ---------------------------------------------------

for p in hypr quickshell/eva quickshell/magi eva kitty mako fuzzel satty; do
    if [ -e "$dst/$p" ]; then
        mkdir -p "$backup/$(dirname "$p")"
        cp -a "$dst/$p" "$backup/$p"
    fi
done
[ -d "$backup" ] && echo "backed up your current configs to $backup"

mkdir -p "$dst"
cp -a "$repo/config/." "$dst/"
grep -rlI --null __HOME__ "$dst/hypr" "$dst/quickshell/eva" "$dst/quickshell/magi" "$dst/eva" \
    "$dst/kitty" "$dst/mako" "$dst/fuzzel" "$dst/satty" 2>/dev/null | xargs -0 -r sed -i "s|__HOME__|$HOME|g"
chmod +x "$dst"/eva/bin/* "$dst"/eva/tools/*.py "$dst"/hypr/scripts/* "$dst/eva/plugins/eva-blurcache/build.sh"
mkdir -p "$HOME/Pictures/Screenshots"

# ---- fonts and wallpapers -------------------------------------------------

fonts="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/eva"
mkdir -p "$fonts"
cp "$repo"/assets/fonts/*.ttf "$fonts/"
fc-cache -f "$fonts" >/dev/null 2>&1 || true

mkdir -p "$HOME/Pictures/wallpapers"
for w in "$repo"/assets/wallpapers/*; do
    [ -e "$HOME/Pictures/wallpapers/$(basename "$w")" ] || cp "$w" "$HOME/Pictures/wallpapers/"
done

# ---- colors for every app, from the theme (MONO to start; SUPER+SHIFT+T cycles)

mkdir -p "$dst/eva/current"
[ -f "$dst/eva/current/name" ] || echo mono > "$dst/eva/current/name"
"$dst/eva/bin/eva-theme" --render

# ---- plugins --------------------------------------------------------------

if [ "$1" = "--plugins" ]; then
    "$dst/eva/bin/rebuild-hyprbars"
    "$dst/eva/plugins/eva-blurcache/build.sh"
fi

cat <<EOF

Installed. Log into Hyprland (or run: hyprctl reload) and:
  - tap SUPER for the start menu; Super + / lists the shortcuts
  - SUPER+SHIFT+T cycles the color themes
EOF
[ "$1" = "--plugins" ] || echo "  - run ./install.sh --plugins (or the two build scripts) for title bars and the blur cache"
echo "  - extras/ has optional bits: Spotify theme tweak, boot splash, laptop lid"
