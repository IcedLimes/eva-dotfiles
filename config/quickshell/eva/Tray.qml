import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

RowLayout {
    spacing: 2

    Repeater {
        // nm-applet keeps running for VPN and login prompts, but the Wi-Fi
        // icon (WifiChip) replaces its tray icon.
        model: SystemTray.items.values.filter(i => i.id !== "nm-applet")

        Chip {
            id: item

            required property SystemTrayItem modelData

            implicitWidth: 32
            padding: 0

            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton && !modelData.onlyMenu)
                    modelData.activate()
                else if (modelData.hasMenu)
                    menu.open()
            }

            IconImage {
                implicitSize: 18
                source: item.modelData.icon
            }

            QsMenuAnchor {
                id: menu
                menu: item.modelData.menu
                anchor.item: item
                anchor.edges: Edges.Top
                anchor.gravity: Edges.Top
                onOpened: Eva.menuOpen = true
                onClosed: Eva.menuOpen = false
            }
        }
    }
}
