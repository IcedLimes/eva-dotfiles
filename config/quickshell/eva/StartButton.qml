import QtQuick

// NERV logo on an accent-tinted square. Left click: start menu.
// Right click: power menu.
Chip {
    implicitWidth: 36
    padding: 0
    tint: containsMouse ? Theme.alpha(Theme.primary, 0.34) : Theme.alpha(Theme.primary, 0.20)
    selected: false

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
            Eva.run("~/.config/hypr/scripts/power-menu.sh")
        else
            Eva.toggleLauncher()
    }

    Text {
        text: Theme.logo
        font.family: Theme.logoFont
        font.pixelSize: 22
        color: Theme.active
    }
}
