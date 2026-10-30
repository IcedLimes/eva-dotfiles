import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Control Center (click the status chip): battery, quick toggles, volume and
// brightness sliders, power mode. Bottom-right, above the bar.
PanelWindow {
    id: cc

    readonly property UPowerDevice dev: UPower.displayDevice
    readonly property real pct: dev ? (dev.percentage > 1 ? dev.percentage : dev.percentage * 100) : 0
    readonly property bool onBattery: UPower.onBattery

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var network: wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null

    readonly property var panelMonitor: Hyprland.monitors.values.find(m => m.name === "eDP-1") ?? null
    readonly property real refresh: panelMonitor && panelMonitor.lastIpcObject ? (panelMonitor.lastIpcObject.refreshRate ?? 0) : 0

    function hm(secs) {
        const h = Math.floor(secs / 3600), m = Math.floor(secs % 3600 / 60)
        return h > 0 ? `${h} h ${m} min` : `${m} min`
    }

    readonly property string batteryStatus: {
        const d = dev
        if (!d) return ""
        if (d.state === UPowerDeviceState.Charging)
            return d.timeToFull > 0 ? `Charging · full in ${hm(d.timeToFull)}` : "Charging"
        if (d.state === UPowerDeviceState.Discharging)
            return d.timeToEmpty > 0 ? `${hm(d.timeToEmpty)} remaining` : "On battery"
        if (d.state === UPowerDeviceState.FullyCharged) return "Fully charged"
        return "Plugged in · not charging"
    }

    // Extra room around the card so its shadow isn't clipped.
    readonly property int roomTop: 28
    readonly property int roomSide: 28
    readonly property int roomBottom: 36

    visible: Eva.controlOpen
    // above the dock's right end, where its status icons are (Bar.qml)
    readonly property var dock: Eva.docks[screen ? screen.name : ""] ?? null
    anchors { right: true; bottom: true }
    margins {
        right: dock && screen ? Math.max(0, Math.round(screen.width - dock.right) - 10) : 0
        bottom: (dock ? dock.height + dock.bottomGap + 12 : 74) - roomBottom
    }
    implicitWidth: roomSide + 380 + 10
    implicitHeight: roomTop + body.implicitHeight + 32 + roomBottom
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "eva-control"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    mask: Region { item: card }

    onVisibleChanged: {
        if (visible) {
            openAnim.restart()
            Eva.readBrightness()
            Hyprland.refreshMonitors()
            keys.forceActiveFocus()
        }
    }

    HyprlandFocusGrab {
        windows: [cc].concat(Eva.barWindows)
        active: cc.visible
        onCleared: Eva.closeControl()
    }

    PwObjectTracker { objects: [cc.sink] }

    Glass {
        id: card

        anchors { right: parent.right; bottom: parent.bottom; rightMargin: 10; bottomMargin: cc.roomBottom }
        width: 380
        height: body.implicitHeight + 32

        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: card; property: "anchors.bottomMargin"; from: cc.roomBottom - 12; to: cc.roomBottom; duration: Theme.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecel }
            NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: Theme.durMedium }
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Eva.closeControl()
        }

        ColumnLayout {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.s4 }
            spacing: Theme.s3

            // ---- battery ----
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s3

                Icon {
                    name: !cc.onBattery ? "charging" : "bat" + Math.max(10, Math.min(100, Math.round(cc.pct / 10) * 10))
                    size: 30
                    color: cc.onBattery && cc.pct < 15 ? Theme.crit : cc.onBattery && cc.pct < 30 ? Theme.warn : Theme.active
                }

                ColumnLayout {
                    spacing: 0
                    Label {
                        text: Math.round(cc.pct) + "%"
                        font.pixelSize: Theme.fontDisplay
                        font.weight: Font.DemiBold
                    }
                    Label {
                        text: cc.batteryStatus
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Normal
                        color: Theme.textSecondary
                    }
                }

                Item { Layout.fillWidth: true }

                // EVA touch: internal vs. external (umbilical) power
                Label {
                    Layout.alignment: Qt.AlignTop
                    text: cc.onBattery ? "内部電源" : "外部電源"
                    font.family: Theme.kanji
                    font.pixelSize: Theme.fontCaption
                    color: Theme.textTertiary
                }
            }

            // ---- quick toggles ----
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: Theme.s2
                columnSpacing: Theme.s2

                Tile {
                    icon: cc.network ? "wifi4" : "wifiOff"
                    title: "Wi-Fi"
                    subtitle: !Networking.wifiEnabled ? "Off" : cc.network ? cc.network.name : "Not connected"
                    on: Networking.wifiEnabled && cc.network !== null
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) { Eva.closeControl(); Eva.run("nm-connection-editor") }
                        else Networking.wifiEnabled = !Networking.wifiEnabled
                    }
                }
                Tile {
                    icon: "night"
                    title: "Night light"
                    subtitle: Eva.nightLight ? Eva.nightTemperature + " K" : "Off"
                    on: Eva.nightLight
                    onClicked: Eva.setNightLight(!Eva.nightLight)
                }
                Tile {
                    icon: "coffee"
                    title: "Keep awake"
                    subtitle: Eva.sleepBlocked ? "No idle sleep or lock" : "Off"
                    on: Eva.sleepBlocked
                    onClicked: Eva.setSleepBlocked(!Eva.sleepBlocked)
                }
                Tile {
                    icon: Eva.dnd ? "bellOff" : "bell"
                    title: "Do not disturb"
                    subtitle: Eva.dnd ? "Notifications hidden" : "Off"
                    on: Eva.dnd
                    onClicked: Eva.toggleDnd()
                }
                Tile {
                    icon: "lowPower"
                    title: "Low power"
                    subtitle: cc.refresh > 0 && cc.refresh <= 61 ? "60 Hz, effects off" : "Off"
                    on: cc.refresh > 0 && cc.refresh <= 61
                    onClicked: Eva.run("hyprctl eval 'eva.toggle_battery_mode()'")
                }
                Tile {
                    icon: "palette"
                    title: "Theme"
                    subtitle: Theme.label.charAt(0) + Theme.label.slice(1).toLowerCase()
                    on: false
                    onClicked: Eva.run("~/.config/eva/bin/eva-theme next")
                }
            }

            // ---- sliders ----
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s2

                Chip {
                    implicitWidth: 32
                    implicitHeight: 32
                    padding: 0
                    onClicked: if (cc.sink && cc.sink.audio) cc.sink.audio.muted = !cc.sink.audio.muted
                    Icon {
                        name: cc.sink && cc.sink.audio && cc.sink.audio.muted ? "volMute" : "volHigh"
                        size: 18
                    }
                }
                Slider {
                    Layout.fillWidth: true
                    value: cc.sink && cc.sink.audio ? cc.sink.audio.volume : 0
                    onMoved: v => { if (cc.sink && cc.sink.audio) { cc.sink.audio.muted = false; cc.sink.audio.volume = v } }
                }
                Label {
                    Layout.preferredWidth: 38
                    horizontalAlignment: Text.AlignRight
                    text: cc.sink && cc.sink.audio ? Math.round(cc.sink.audio.volume * 100) + "%" : "–"
                    font.pixelSize: Theme.fontLabel
                    color: Theme.textSecondary
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s2

                Item {
                    implicitWidth: 32
                    implicitHeight: 32
                    Icon { anchors.centerIn: parent; name: "brightness"; size: 18 }
                }
                Slider {
                    Layout.fillWidth: true
                    value: Eva.brightness / 100
                    onMoved: v => Eva.setBrightness(Math.max(1, Math.round(v * 100)))
                }
                Label {
                    Layout.preferredWidth: 38
                    horizontalAlignment: Text.AlignRight
                    text: Eva.brightness + "%"
                    font.pixelSize: Theme.fontLabel
                    color: Theme.textSecondary
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.stroke }

            // ---- power mode ----
            Label {
                text: "Power mode"
                font.pixelSize: Theme.fontLabel
                font.weight: Font.DemiBold
                color: Theme.textSecondary
            }

            ProfileSlider { Layout.fillWidth: true }

            // ---- settings shortcuts ----
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s2

                Chip {
                    Layout.fillWidth: true
                    tint: Theme.fill
                    onClicked: { Eva.closeControl(); Eva.run("~/.config/eva/bin/eva-display") }
                    Icon { name: "monitor"; size: 16 }
                    Label { text: "Display settings"; font.pixelSize: Theme.fontLabel }
                }
                Chip {
                    Layout.fillWidth: true
                    tint: Theme.fill
                    onClicked: { Eva.closeControl(); Eva.run("systemsettings") }
                    Icon { name: "cog"; size: 16 }
                    Label { text: "System settings"; font.pixelSize: Theme.fontLabel }
                }
            }

            Label {
                visible: PowerProfiles.degradationReason !== PerformanceDegradationReason.None
                text: PowerProfiles.degradationReason === PerformanceDegradationReason.HighTemperature
                      ? "Performance limited: high temperature" : "Performance limited: on your lap"
                font.pixelSize: Theme.fontCaption
                color: Theme.warn
            }
        }
    }

    // Three-stop slider: Eco / Balanced / Performance.
    component ProfileSlider: Item {
        id: slider

        readonly property var stops: PowerProfiles.hasPerformanceProfile
            ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
            : [PowerProfile.PowerSaver, PowerProfile.Balanced]
        readonly property var names: ["Eco", "Balanced", "Performance"]
        readonly property int index: Math.max(0, stops.indexOf(PowerProfiles.profile))

        implicitHeight: 48

        function stopX(i) { return 8 + i * (track.width - 16) / (stops.length - 1) }

        function pick(x) {
            let best = 0
            for (let i = 1; i < stops.length; i++)
                if (Math.abs(x - stopX(i)) < Math.abs(x - stopX(best))) best = i
            if (stops[best] !== PowerProfiles.profile)
                PowerProfiles.profile = stops[best]
        }

        Item {
            id: track
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 22

            Rectangle {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8 }
                height: 6
                radius: 3
                color: Theme.fill
            }

            Rectangle {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 8 }
                width: Math.max(6, slider.stopX(slider.index) - 8)
                height: 6
                radius: 3
                color: Theme.active
                Behavior on width { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecel } }
            }

            Rectangle {
                width: 16
                height: 16
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: slider.stopX(slider.index) - 8
                color: Theme.textPrimary
                border.color: Qt.rgba(0, 0, 0, 0.25)
                border.width: 1
                Behavior on x { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecel } }
            }

            MouseArea {
                anchors.fill: parent
                onPressed: mouse => slider.pick(mouse.x)
                onPositionChanged: mouse => { if (pressed) slider.pick(mouse.x) }
            }
        }

        Repeater {
            model: slider.stops.length
            Label {
                required property int index
                y: track.height + 6
                x: Math.max(0, Math.min(slider.width - width, slider.stopX(index) - width / 2))
                text: slider.names[index]
                font.pixelSize: Theme.fontCaption
                font.weight: index === slider.index ? Font.DemiBold : Font.Normal
                color: index === slider.index ? Theme.textPrimary : Theme.textTertiary
            }
        }
    }
}
