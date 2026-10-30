# StarryNight, quieter

Spotify's StarryNight theme (spicetify) animates its stars and the spinning
cover every frame, which kept about half of a laptop iGPU busy even with
Spotify paused and minimized. This patch makes them hold still whenever
Spotify doesn't have focus, and recolors the theme to match EVA.

    cd ~/.config/spicetify/Themes   # with StarryNight installed
    patch -p1 < /path/to/eva-dotfiles/extras/spicetify/starrynight-eva.patch
    spicetify apply
