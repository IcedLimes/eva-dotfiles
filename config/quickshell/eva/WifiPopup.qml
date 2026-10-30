import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking

// Wi-Fi popup (click the network icon on the bar): on/off, nearby networks,
// connect (with a password for new secured networks), disconnect, forget.
// nm-applet still runs hidden to answer VPN and enterprise-login prompts.
TrayPopup {
    id: popup

    name: "wifi"
    title: "Wi-Fi"
    switchOn: Networking.wifiEnabled
    switchVisible: Networking.wifiHardwareEnabled
    onSwitchToggled: Networking.wifiEnabled = !Networking.wifiEnabled

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) ?? null

    property string askingFor: ""   // network waiting for a password
    property string failedFor: ""   // network whose last attempt failed

    function strength(n) { return n.signalStrength > 1 ? n.signalStrength / 100 : n.signalStrength }
    function signalIcon(s) { return s < 0.25 ? "wifi1" : s < 0.5 ? "wifi2" : s < 0.75 ? "wifi3" : "wifi4" }
    function isOpen(n) { return n.security === WifiSecurityType.Open || n.security === WifiSecurityType.Owe }
    function usesPsk(n) {
        return [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].indexOf(n.security) !== -1
    }

    // One row per network name, connected first, then saved, then by signal.
    readonly property var networks: {
        if (!wifiDevice || !Networking.wifiEnabled) return []
        const list = wifiDevice.networks.values.filter(n => n.name !== "").slice()
        list.sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (strength(b) - strength(a)))
        const seen = {}
        return list.filter(n => seen[n.name] ? false : (seen[n.name] = true)).slice(0, 10)
    }

    function activate(n) {
        failedFor = ""
        if (n.connected) return
        if (n.known || isOpen(n)) {
            askingFor = ""
            n.connect()
        } else if (usesPsk(n)) {
            askingFor = askingFor === n.name ? "" : n.name
        } else {
            n.connect()   // WEP / enterprise: nm-applet asks for the details
        }
    }

    // Scan for networks only while the popup is open.
    Connections {
        target: popup
        function onVisibleChanged() {
            if (popup.wifiDevice) popup.wifiDevice.scannerEnabled = popup.visible
            if (!popup.visible) { popup.askingFor = ""; popup.failedFor = "" }
        }
    }

    ListRow {
        visible: popup.wired !== null
        icon: "ethernet"
        title: "Ethernet"
        subtitle: "Connected"
        active: true
    }

    Label {
        Layout.fillWidth: true
        Layout.margins: 6
        visible: popup.networks.length === 0
        text: !Networking.wifiHardwareEnabled ? "Wi-Fi is turned off by a hardware switch"
            : !Networking.wifiEnabled ? "Wi-Fi is off"
            : "Searching for networks…"
        font.pixelSize: Theme.fontLabel
        font.weight: Font.Normal
        color: Theme.textSecondary
    }

    Repeater {
        model: popup.networks

        ColumnLayout {
            id: entry

            required property var modelData
            readonly property var net: modelData
            readonly property bool asking: popup.askingFor === net.name

            Layout.fillWidth: true
            spacing: 4

            ListRow {
                id: row
                icon: popup.signalIcon(popup.strength(entry.net))
                title: entry.net.name
                active: entry.net.connected
                subtitle: entry.net.stateChanging ? (entry.net.connected ? "Disconnecting…" : "Connecting…")
                        : entry.net.connected ? "Connected"
                        : popup.failedFor === entry.net.name ? "Couldn't connect"
                        : entry.net.known ? "Saved"
                        : popup.isOpen(entry.net) ? "Open" : "Secured"
                onClicked: popup.activate(entry.net)

                Icon {
                    visible: !popup.isOpen(entry.net) && !entry.net.connected
                    name: "lock"
                    size: 13
                    color: Theme.textTertiary
                }
                TextButton {
                    visible: entry.net.connected
                    text: "Disconnect"
                    onClicked: entry.net.disconnect()
                }
                TextButton {
                    visible: entry.net.known && !entry.net.connected && row.containsMouse
                    text: "Forget"
                    onClicked: entry.net.forget()
                }
            }

            // Password for a new secured network.
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 42
                Layout.rightMargin: 8
                Layout.bottomMargin: 4
                visible: entry.asking
                implicitHeight: 34
                radius: Theme.radiusSmall + 2
                color: Theme.alpha(Theme.bg, 0.6)
                border.color: password.activeFocus ? Theme.selectionStroke : Theme.stroke
                border.width: 1

                TextInput {
                    id: password
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: Theme.textPrimary
                    selectionColor: Theme.selection
                    font.family: Theme.font
                    font.pixelSize: Theme.fontLabel
                    clip: true
                    onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                    Keys.onReturnPressed: { entry.net.connectWithPsk(text); popup.askingFor = "" }
                    Keys.onEnterPressed: { entry.net.connectWithPsk(text); popup.askingFor = "" }
                    Keys.onEscapePressed: popup.askingFor = ""
                }

                Label {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    visible: password.text === ""
                    text: "Password, then Enter"
                    font.pixelSize: Theme.fontLabel
                    font.weight: Font.Normal
                    color: Theme.textTertiary
                }
            }

            Connections {
                target: entry.net
                function onConnectionFailed(reason) {
                    popup.failedFor = entry.net.name
                    // Wrong or missing password: ask (again).
                    if (reason === ConnectionFailReason.NoSecrets && popup.usesPsk(entry.net))
                        popup.askingFor = entry.net.name
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 4
        Layout.bottomMargin: 2
        implicitHeight: 1
        color: Theme.stroke
    }

    TextButton {
        Layout.alignment: Qt.AlignRight
        text: "Network settings…"
        onClicked: { Eva.closeTrayPopup(); Eva.run("nm-connection-editor") }
    }
}
