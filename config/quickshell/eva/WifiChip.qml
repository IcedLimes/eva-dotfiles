import QtQuick
import Quickshell
import Quickshell.Networking

// Network icon on the bar; click for the Wi-Fi popup.
Chip {
    id: chip

    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var network: wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null
    readonly property real strength: network ? (network.signalStrength > 1 ? network.signalStrength / 100 : network.signalStrength) : 0

    implicitWidth: 34
    padding: 0
    selected: Eva.trayPopup === "wifi"
    onClicked: Eva.toggleTrayPopup("wifi")

    Icon {
        name: chip.wired ? "ethernet"
            : !chip.network ? "wifiOff"
            : chip.strength < 0.25 ? "wifi1" : chip.strength < 0.5 ? "wifi2" : chip.strength < 0.75 ? "wifi3" : "wifi4"
        size: 17
        color: chip.wired || chip.network ? Theme.textPrimary : Theme.textTertiary
    }
}
