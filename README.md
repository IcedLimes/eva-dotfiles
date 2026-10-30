# EVA — an Evangelion Hyprland setup

A NERV / MAGI themed desktop for Hyprland 0.56 (Lua config) with a Quickshell
shell. Black and white by default (MONO), with CRIMSON and MAGI palettes a
key press away.

## What's in it

- **Liquid glass dock and start menu.** The dock wells up out of the bottom
  edge when the pointer touches it and floats just above; the start menu pops
  out of the dock, clings to it, then pulls free. A ripple runs through the
  glass (and bends its edges) whenever something pops up or down.
- **Glass screen frame.** A thin blurred band around the screen fills the gap
  around maximized windows; the dock grows out of it and its waves run along it.
- **MAGI console on the desktop.** CPU (MELCHIOR), GPU (BALTHASAR) and memory
  (CASPER) with two minutes of history, a clock on a dial around the moon,
  power, network, Bluetooth, audio, now playing, storage, uptime, load and
  power draw. It drifts with the wallpaper's parallax.
- **The moon, Rei and a night sky.** A dotted moon you can drop the vinyl record
  into (see *Optional* below); then Rei turns beside it in braille, like the
  *Fly Me to the Moon* credits, and the stars come out behind Unit-01.
- **Wallpaper parallax**, a **MAGI vote** at login, an **Alt+Tab switcher** with
  thumbnails and close buttons, a **Control Center**, Wi-Fi and Bluetooth
  popups, title bars with hover feedback, and screenshots that land on the
  clipboard and open an editor (satty).
- **Three themes** (`eva-theme`): every app's colors come from
  `~/.config/eva/themes.json`; SUPER+SHIFT+T cycles them.
- **Plays well with Plasma** on the same account: `eva-session` saves Plasma's
  colors before recoloring KDE/GTK apps for Hyprland, and puts them back.

Shortcuts are in `config/hypr/keys.txt` (Super + / shows them).

## Requirements

Arch package names; other distros have the same programs.

- `hyprland` **0.56 or newer** (the config is Lua), `quickshell` 0.3+
- `hypridle hyprlock hyprsunset mako fuzzel kitty`
- `grim slurp satty wl-clipboard cliphist`
- `brightnessctl playerctl wireplumber jq python`
- `network-manager-applet polkit-kde-agent` (or swap in your own polkit agent)
- Fonts: `inter-font ttf-jetbrains-mono noto-fonts-cjk ttf-nerd-fonts-symbols ttf-meslo-nerd`
  (DSEG7, for the clock, is included)
- Cursor: Bibata Modern Ice (`bibata-cursor-theme`)
- For the plugins: `git`, a C++ compiler, `pkgconf`, and the Hyprland headers
  (shipped with the `hyprland` package)
- Optional: `python-numpy` and `imagemagick` to bake the night sky for another
  wallpaper (`config/eva/tools/make-stars.py`)

## Install

```sh
git clone https://github.com/IcedLimes/eva-dotfiles && cd eva-dotfiles
./install.sh --plugins
```

`install.sh` backs up anything it would replace to `~/.config/eva-backup-<date>/`,
copies the configs, installs the clock font and the wallpapers, and writes every
app's colors for the MONO theme. `--plugins` also builds:

- **hyprbars** (title bars), from hyprland-plugins with a small patch: grabbing
  a maximized window keeps the spot you grabbed, buttons light up on hover, and
  a click only drags after 8 px.
- **eva-blurcache**, which keeps Hyprland's cached blur while the desktop
  decorations animate. Without it, Rei and the record repaint and re-blur the
  whole screen every frame.

Both must be rebuilt after every Hyprland update (`~/.config/eva/bin/rebuild-hyprbars`,
`~/.config/eva/plugins/eva-blurcache/build.sh`); until then the desktop works,
just without title bars or with a busier GPU.

Then log into Hyprland.

## Things you'll want to change

It was built on one laptop (2560×1600 @ 240 Hz, Radeon iGPU + an RTX), so:

- **Monitor**: the MONITORS section of `hypr/hyprland.lua` assumes `eDP-1` at
  2560×1600@240. Layouts saved with *Display settings* (`eva-display`,
  `eva-display-save`) go to `~/.config/eva/monitors.lua`.
- **The moon, Rei, the console** are placed in screen pixels for 2560×1600
  (`quickshell/eva/Rei.qml`, `Moon.qml`, `Hud.qml`).
- **Night sky**: `config/eva/stars.png` is baked for the included wallpaper.
  For another wallpaper or screen, edit the constants at the top of
  `eva/tools/make-stars.py` and run it.
- **Sensors**: the console reads `/sys/class/drm/card0` and the `amdgpu`/`k10temp`
  hwmon sensors; `eva/bin/activity-limit` (lock screen) reads `BAT1`/`ADP1`.
- **Low power mode** drops the panel to 60 Hz; the decorations hold still on
  battery.

## Optional

- **[vinyl-visualizer]** — the turntable overlay that docks into the moon
  ("moon form"): Rei, the night sky and the moon outline react to it. Moon form
  needs a version from October 29, 2026 or later (docking arrived in commit
  `4bf3ce1`); its installer sets it up. Without it the rest works; the moon
  simply never fills.
- `extras/spicetify/` — a patch for Spotify's StarryNight theme so its stars only
  animate while Spotify has focus (they kept the GPU busy otherwise).
- `extras/plymouth/` — the grey NERV boot / shutdown logo.
- `extras/logind/` — lid always suspends, even when an external display is
  detected.

## Credits

The wallpaper is a Unit-01 piece by an artist I couldn't identify; where it was
found, what was changed, and the rest of the credits (Rei, fonts, software) are
in [CREDITS.md](CREDITS.md). If the wallpaper is yours, open an issue.

[vinyl-visualizer]: https://github.com/IcedLimes/vinyl-visualizer
