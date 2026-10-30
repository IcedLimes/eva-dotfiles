import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

// Bluetooth popup (click the Bluetooth icon on the bar): on/off, your paired
// devices (click to connect or disconnect), and nearby ones while scanning.
// New phones and PCs that need a PIN: pair them in Bluetooth settings.
TrayPopup {
    id: popup

    name: "bluetooth"
    title: "Bluetooth"

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: adapter !== null && adapter.enabled

    switchOn: btOn
    switchVisible: adapter !== null
    onSwitchToggled: if (adapter) adapter.enabled = !adapter.enabled

    function battery(d) { return d.battery > 1 ? d.battery : d.battery * 100 }

    function deviceIcon(d) {
        const i = d.icon || ""
        return i.indexOf("headset") !== -1 || i.indexOf("headphone") !== -1 ? "headphones"
             : i.indexOf("audio") !== -1 ? "speaker"
             : i.indexOf("phone") !== -1 ? "phone"
             : i.indexOf("keyboard") !== -1 ? "keyboard"
             : i.indexOf("mouse") !== -1 || i.indexOf("tablet") !== -1 ? "mouse"
             : i.indexOf("gaming") !== -1 || i.indexOf("joystick") !== -1 ? "gamepad"
             : i.indexOf("computer") !== -1 ? "monitor"
             : "bluetooth"
    }

    function status(d) {
        if (d.pairing) return "Pairing…"
        if (d.state === BluetoothDeviceState.Connecting) return "Connecting…"
        if (d.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…"
        if (d.connected) return d.batteryAvailable ? `Connected · ${Math.round(battery(d))}% battery` : "Connected"
        return d.paired ? "Not connected" : "Click to pair"
    }

    // Paired devices (connected first), then nearby ones found by a scan.
    readonly property var devices: {
        if (!btOn) return []
        const list = adapter.devices.values.filter(d => d.paired || (adapter.discovering && d.name !== "" && d.name !== d.address)).slice()
        list.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
        return list
    }

    function activate(d) {
        if (d.connected) d.disconnect()
        else if (d.paired) d.connect()
        else { d.trusted = true; d.pair() }
    }

    // Stop scanning when the popup closes.
    Connections {
        target: popup
        function onVisibleChanged() {
            if (!popup.visible && popup.adapter && popup.adapter.discovering) popup.adapter.discovering = false
        }
    }

    Label {
        Layout.fillWidth: true
        Layout.margins: 6
        visible: popup.devices.length === 0
        text: popup.adapter === null ? "No Bluetooth adapter found"
            : popup.adapter.state === BluetoothAdapterState.Blocked ? "Bluetooth is blocked (airplane mode?)"
            : !popup.btOn ? "Bluetooth is off"
            : popup.adapter.discovering ? "Looking for devices…"
            : "No paired devices"
        font.pixelSize: Theme.fontLabel
        font.weight: Font.Normal
        color: Theme.textSecondary
    }

    Repeater {
        model: popup.devices

        ListRow {
            required property var modelData
            readonly property var dev: modelData

            icon: popup.deviceIcon(dev)
            title: dev.name || dev.address
            subtitle: popup.status(dev)
            active: dev.connected
            dimmed: !dev.paired
            onClicked: popup.activate(dev)
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 4
        Layout.bottomMargin: 2
        implicitHeight: 1
        color: Theme.stroke
    }

    RowLayout {
        Layout.fillWidth: true

        TextButton {
            visible: popup.btOn
            text: popup.adapter && popup.adapter.discovering ? "Stop scanning" : "Scan for devices"
            onClicked: popup.adapter.discovering = !popup.adapter.discovering
        }
        Item { Layout.fillWidth: true }
        TextButton {
            text: "Bluetooth settings…"
            onClicked: { Eva.closeTrayPopup(); Eva.run("systemsettings kcm_bluetooth") }
        }
    }
}
