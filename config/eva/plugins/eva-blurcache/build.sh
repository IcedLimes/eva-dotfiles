#!/bin/sh
# Build eva-blurcache for the installed Hyprland and (re)load it. Needs the
# Hyprland headers (the hyprland package ships them). Run after any Hyprland
# update, like ~/.config/eva/bin/rebuild-hyprbars.
set -e
cd "$(dirname "$0")"
g++ -O2 -shared -fPIC -std=c++2b -Wno-c++11-narrowing --no-gnu-unique \
    $(pkg-config --cflags pixman-1 libdrm hyprland libinput libudev wayland-server xkbcommon) \
    main.cpp -o eva-blurcache.so
dest="$HOME/.local/share/hyprland/plugins/eva-blurcache.so"
mkdir -p "$(dirname "$dest")"
# never overwrite a loaded plugin in place: write a new file and swap it in
cp eva-blurcache.so "$dest.tmp" && mv "$dest.tmp" "$dest"
if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    hyprctl plugin unload "$dest" >/dev/null 2>&1 || true
    hyprctl plugin load "$dest"
fi
echo "installed $dest"
