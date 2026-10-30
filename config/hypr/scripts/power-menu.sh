#!/bin/sh
# Power menu: Ctrl+Alt+Del, SUPER+SHIFT+E, or right-click the NERV button.
pkill -x fuzzel && exit 0

choice=$(printf '󰌾  Lock\n󰤄  Sleep\n󰍃  Log out\n󰜉  Restart\n󰐥  Shut down\n' |
    fuzzel --dmenu --prompt '' --placeholder 'Power' --lines 5 --width 20)

case "$choice" in
    *Lock)      loginctl lock-session ;;
    *Sleep)     systemctl suspend ;;
    *"Log out") hyprctl dispatch 'hl.dsp.exit()' ;;
    *Restart)   systemctl reboot ;;
    *"Shut down") systemctl poweroff ;;
esac
