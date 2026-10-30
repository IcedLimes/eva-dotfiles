import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Volume and battery at a glance. Click: Control Center. (Wi-Fi and
// Bluetooth have their own icons and popups: WifiChip, BluetoothChip.)
Chip {
    id: chip

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property real vol: sink && sink.audio ? sink.audio.volume : 0

    readonly property UPowerDevice dev: UPower.displayDevice
    readonly property real pct: dev ? (dev.percentage > 1 ? dev.percentage : dev.percentage * 100) : 0
    readonly property bool hasBattery: dev !== null && dev.isPresent
    readonly property bool charging: dev !== null && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged || !UPower.onBattery)

    selected: Eva.controlOpen
    spacing: 10
    onClicked: Eva.controlOpen = !Eva.controlOpen

    PwObjectTracker { objects: [chip.sink] }

    Icon {
        name: chip.muted || chip.vol === 0 ? "volMute" : chip.vol < 0.34 ? "volLow" : chip.vol < 0.67 ? "volMid" : "volHigh"
        size: 17
        color: chip.muted ? Theme.textTertiary : Theme.textPrimary
    }

    RowLayout {
        visible: chip.hasBattery
        spacing: 4

        Icon {
            name: chip.charging ? "charging" : "bat" + Math.max(10, Math.min(100, Math.round(chip.pct / 10) * 10))
            size: 17
            color: !chip.charging && chip.pct < 15 ? Theme.crit : !chip.charging && chip.pct < 30 ? Theme.warn : Theme.textPrimary
        }
        Label {
            text: Math.round(chip.pct) + "%"
            font.pixelSize: Theme.fontLabel
        }
    }
}
