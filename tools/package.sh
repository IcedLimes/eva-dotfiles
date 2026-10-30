#!/bin/sh
# Copy the live EVA setup from ~/.config into this repo. Run it again after
# changing anything. Leaves out personal state (pinned apps, favorites,
# settings, the Plasma color backup), machine-specific files (saved monitor
# layout), generated files (the current theme's colors) and build output.
# Your home folder becomes __HOME__, which install.sh fills back in.
set -e
repo=$(cd "$(dirname "$0")/.." && pwd)
src="${XDG_CONFIG_HOME:-$HOME/.config}"
cfg="$repo/config"
rm -rf "$cfg"
mkdir -p "$cfg"

copy() {
    mkdir -p "$cfg/$(dirname "$1")"
    cp -a "$src/$1" "$cfg/$1"
}

copy hypr/hyprland.lua
copy hypr/hypridle.conf
copy hypr/hyprlock.conf
copy hypr/keys.txt
copy hypr/scripts
copy quickshell/eva
copy quickshell/magi
for f in bin tools patches themes.json rei-frames.json stars.png; do copy "eva/$f"; done
mkdir -p "$cfg/eva/plugins/eva-blurcache"
cp -a "$src/eva/plugins/eva-blurcache/main.cpp" "$src/eva/plugins/eva-blurcache/build.sh" "$cfg/eva/plugins/eva-blurcache/"
copy kitty/kitty.conf
copy mako/config
copy fuzzel/fuzzel.ini
copy satty/config.toml

find "$cfg" \( -name __pycache__ -o -name '*.pyc' -o -name '*.so' -o -name '*.orig' -o -name '*.bak*' \) -prune -exec rm -rf {} +
grep -rlI --null "$HOME" "$cfg" | xargs -0 -r sed -i "s|$HOME|__HOME__|g"
echo "packaged into $cfg"
