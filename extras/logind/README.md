# Lid always suspends

logind ignores the lid while it thinks the laptop is docked, and with some
dGPU drivers loaded it can think so with nothing plugged in. This drop-in makes
closing the lid suspend regardless (no clamshell mode with an external screen).

    sudo install -Dm644 10-lid-suspend.conf /etc/systemd/logind.conf.d/10-lid-suspend.conf
    sudo systemctl reload systemd-logind
