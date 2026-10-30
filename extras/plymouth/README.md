# Grey NERV splash

The `nerv` Plymouth theme shows a bright red NERV logo at boot and shutdown.
To make it light grey and a little dimmer (keeping the glow), with the
theme installed:

    cd /usr/share/plymouth/themes/nerv/img
    sudo cp animation-1.png animation-1.png.orig-red
    sudo magick animation-1.png.orig-red -alpha off -channel R -separate +channel \
        -evaluate multiply 0.70 -define png:color-type=2 PNG24:animation-1.png

Shutdown picks it up right away. The boot splash comes from the initramfs, so
it changes the next time that's rebuilt (e.g. `sudo mkinitcpio -P`).
