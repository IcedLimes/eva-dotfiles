import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bluetooth icon on the bar (when there is an adapter); click for its popup.
Chip {
    id: chip

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter !== null && adapter.enabled
    readonly property bool anyConnected: on && adapter.devices.values.some(d => d.connected)

    visible: adapter !== null
    implicitWidth: 34
    padding: 0
    selected: Eva.trayPopup === "bluetooth"
    onClicked: Eva.toggleTrayPopup("bluetooth")

    Icon {
        name: chip.anyConnected ? "btConnected" : chip.on ? "bluetooth" : "btOff"
        size: 17
        color: chip.on ? Theme.textPrimary : Theme.textTertiary
    }
}
