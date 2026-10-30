import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// A MAGI console filling the black space right of Unit-01, built around the
// moon. The moon slot holds the clock on a dial; above it the three MAGI cores
// (MELCHIOR CPU, BALTHASAR GPU, CASPER memory) with two minutes of history;
// to its right power, network, Bluetooth and audio; below, storage and system.
//
// It's there while the vinyl record isn't in the moon. Pick the record up and
// the dial clears out of the slot, leaving just the moon's dotted outline
// (Moon.qml) to drop it into, while the rest dims; drop it in and the console
// fades away for Rei. Drawn on the background: it drifts with the wallpaper's
// parallax, like Unit-01 (the dial is off the moon only while there's nothing
// to drop into it). Takes no clicks; refreshes every 2 s (5 s on battery).
PanelWindow {
    id: hud

    // ---- layout, in screen px, around the moon ----

    readonly property var moon: Eva.moonArea ?? { x: 1576, y: 831, r: 395 }
    readonly property int sw: screen ? screen.width : 2560
    readonly property int sh: screen ? screen.height : 1600
    readonly property int barTop: sh - 88
    // Clear of Unit-01 (its shoulder reaches x ~1040 beside the bottom row; both
    // drift together, so the gap holds).
    readonly property int bandLeft: Math.max(900, Math.round(moon.x - moon.r - 60))
    readonly property int bandRight: sw - 56
    readonly property int gap: 30
    readonly property int topY: 76
    readonly property int topH: Math.round(moon.y - moon.r - 40) - topY
    readonly property int sideX: Math.round(moon.x + moon.r * 1.08 + 46)
    readonly property int sideW: bandRight - sideX
    readonly property int bottomY: Math.round(moon.y + moon.r + 40)
    readonly property int bottomH: barTop - 28 - bottomY

    anchors { left: true; top: true }
    margins { left: hud.bandLeft - 24; top: 0 }
    implicitWidth: bandRight - bandLeft + 48
    implicitHeight: barTop
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "eva-hud"
    mask: Region {}

    // ---- when ----

    readonly property real shownTarget: Eva.recordInMoon ? 0 : Eva.moonOutline ? 0.5 : 1
    property real shown: shownTarget
    Behavior on shown { NumberAnimation { duration: Eva.recordInMoon ? 700 : 600; easing.type: Easing.InOutSine } }
    readonly property real dialTarget: Eva.moonOutline || Eva.recordInMoon ? 0 : 1
    property real dial: dialTarget
    Behavior on dial { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
    visible: shown > 0.01

    // ---- data ----

    readonly property int every: UPower.onBattery ? 5000 : 2000

    property var cpuHist: []
    property var gpuHist: []
    property var memHist: []
    property real cpu: 0
    property real gpu: 0
    property real cpuTemp: NaN
    property real gpuTemp: NaN
    property real memUsed: 0
    property real memTotal: 0
    property real swapUsed: 0
    property real power: NaN        // W: the processor package (CPU and graphics)
    property var powerHist: []
    readonly property real powerScale: Math.max(30, ...powerHist) * 1.1
    property real diskUsed: 0
    property real diskTotal: 0
    property real uptime: 0
    property string load: ""

    property var lastCpu: null
    property real gpuSum: 0
    property int gpuN: 0

    function push(list, v) {
        const out = list.slice(-59)
        out.push(v)
        return out
    }

    FileView { id: statFile; path: "/proc/stat"; printErrors: false }
    FileView { id: memFile; path: "/proc/meminfo"; printErrors: false }
    FileView { id: gpuFile; path: "/sys/class/drm/card0/device/gpu_busy_percent"; printErrors: false }
    FileView { id: cpuTempFile; path: ""; printErrors: false }
    FileView { id: gpuTempFile; path: ""; printErrors: false }
    FileView { id: powerFile; path: ""; printErrors: false }
    FileView { id: uptimeFile; path: "/proc/uptime"; printErrors: false }
    FileView { id: loadFile; path: "/proc/loadavg"; printErrors: false }
    FileView { id: kernelFile; path: "/proc/sys/kernel/osrelease"; printErrors: false }
    FileView { id: hostFile; path: "/proc/sys/kernel/hostname"; printErrors: false }

    // The sensors' hwmon numbers change between boots: look them up by name.
    Process {
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do echo \"$(cat $h/name) $h\"; done"]
        stdout: SplitParser {
            onRead: line => {
                const [name, dir] = line.split(" ")
                if (name === "k10temp") cpuTempFile.path = dir + "/temp1_input"
                else if (name === "amdgpu") {
                    gpuTempFile.path = dir + "/temp1_input"
                    powerFile.path = dir + "/power1_input"   // the whole APU package, not just graphics
                }
            }
        }
    }

    Process {
        id: df
        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: SplitParser {
            onRead: line => {
                const f = line.trim().split(/\s+/).map(Number)
                if (f.length === 2 && !isNaN(f[0])) { hud.diskUsed = f[0] / 1e9; hud.diskTotal = f[1] / 1e9 }
            }
        }
    }
    Timer {
        running: hud.visible
        repeat: true
        triggeredOnStart: true
        interval: 60000
        onTriggered: {
            df.running = true
            uptimeFile.reload()
            hud.uptime = parseFloat(uptimeFile.text())
        }
    }

    // The GPU's busy figure jumps around: average a few looks per refresh.
    Timer {
        running: hud.visible
        repeat: true
        interval: 500
        onTriggered: {
            gpuFile.reload()
            const v = parseInt(gpuFile.text())
            if (!isNaN(v)) { hud.gpuSum += v; hud.gpuN++ }
        }
    }

    Timer {
        running: hud.visible
        repeat: true
        triggeredOnStart: true
        interval: hud.every
        onTriggered: {
            statFile.reload()
            const f = statFile.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
            if (f.length >= 5) {
                const idle = f[3] + (f[4] || 0)
                const total = f.reduce((a, b) => a + b, 0)
                if (hud.lastCpu) {
                    const dt = total - hud.lastCpu.total
                    hud.cpu = dt > 0 ? Math.max(0, Math.min(1, 1 - (idle - hud.lastCpu.idle) / dt)) : 0
                    hud.cpuHist = hud.push(hud.cpuHist, hud.cpu)
                }
                hud.lastCpu = { idle: idle, total: total }
            }
            if (hud.gpuN > 0) {
                hud.gpu = hud.gpuSum / hud.gpuN / 100
                hud.gpuHist = hud.push(hud.gpuHist, hud.gpu)
                hud.gpuSum = 0; hud.gpuN = 0
            }
            memFile.reload()
            const m = memFile.text()
            const kb = key => { const r = m.match(new RegExp("^" + key + ":\\s+(\\d+)", "m")); return r ? Number(r[1]) : 0 }
            hud.memTotal = kb("MemTotal") / 1048576
            hud.memUsed = (kb("MemTotal") - kb("MemAvailable")) / 1048576
            hud.swapUsed = (kb("SwapTotal") - kb("SwapFree")) / 1048576
            if (hud.memTotal > 0) hud.memHist = hud.push(hud.memHist, hud.memUsed / hud.memTotal)
            if (cpuTempFile.path !== "") { cpuTempFile.reload(); hud.cpuTemp = parseInt(cpuTempFile.text()) / 1000 }
            if (gpuTempFile.path !== "") { gpuTempFile.reload(); hud.gpuTemp = parseInt(gpuTempFile.text()) / 1000 }
            loadFile.reload()
            hud.load = loadFile.text().split(" ").slice(0, 3).join("  ")
            if (powerFile.path !== "") {
                powerFile.reload()
                const w = parseInt(powerFile.text()) / 1e6
                if (!isNaN(w)) { hud.power = w; hud.powerHist = hud.push(hud.powerHist, w) }
            }
            if (hud.player) hud.player.positionChanged()   // not signalled on its own
        }
    }

    // clock: checks every few seconds, changes once a minute
    property date now: new Date()
    Timer {
        running: hud.visible
        repeat: true
        interval: 5000
        onTriggered: {
            const d = new Date()
            if (d.getMinutes() !== hud.now.getMinutes() || d.getHours() !== hud.now.getHours()) hud.now = d
        }
    }
    onVisibleChanged: if (visible) now = new Date()

    readonly property UPowerDevice battery: UPower.displayDevice
    // the battery's side of the power: charging, draining or full
    readonly property string batteryNote: {
        const d = battery
        if (!d || !d.isLaptopBattery) return ""
        if (d.state === UPowerDeviceState.Charging) return "BATTERY +" + Math.abs(d.changeRate).toFixed(1) + " W"
        if (d.state === UPowerDeviceState.Discharging) return "BATTERY −" + Math.abs(d.changeRate).toFixed(1) + " W"
        if (d.state === UPowerDeviceState.FullyCharged) return "BATTERY FULL"
        return "ON AC"
    }
    readonly property real batPct: battery ? (battery.percentage > 1 ? battery.percentage / 100 : battery.percentage) : 0
    function duration2(s) {   // m:ss
        s = Math.max(0, Math.floor(s || 0))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }
    function duration(s) {
        if (!s || s <= 0) return ""
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60)
        return h > 0 ? h + "h " + m + "m" : m + "m"
    }
    readonly property bool external: !UPower.onBattery
    readonly property string powerNote: !battery ? "" : external
        ? (battery.state === UPowerDeviceState.FullyCharged || batPct > 0.99 ? "FULLY CHARGED" : "CHARGING" + (battery.timeToFull > 0 ? " · " + duration(battery.timeToFull) : ""))
        : duration(battery.timeToEmpty) + " REMAINING"

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var network: wifi ? (wifi.networks.values.find(n => n.connected) ?? null) : null
    readonly property real signal: network ? (network.signalStrength > 1 ? network.signalStrength / 100 : network.signalStrength) : 0

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btDevices: adapter && adapter.enabled ? adapter.devices.values.filter(d => d.connected) : []
    function btBattery(d) { return Math.round(d.battery > 1 ? d.battery : d.battery * 100) }

    // what's playing: Spotify if it's there, else whatever is playing
    readonly property var player: {
        const ps = Mpris.players.values
        return ps.find(p => (p.identity || "").toLowerCase().includes("spotify"))
            ?? ps.find(p => p.playbackState === MprisPlaybackState.Playing) ?? null
    }

    readonly property PwNode sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [hud.sink] }
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    // ---- drawing ----

    readonly property color ink: Theme.textPrimary
    readonly property color ink2: Theme.textSecondary
    readonly property color ink3: Theme.textTertiary
    readonly property color hair: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.16)
    readonly property color faint: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07)

    // a frame: corner brackets, a title with its kanji, contents inside
    component Frame: Item {
        id: fr
        property string title
        property string kanji
        default property alias content: inner.data
        Repeater {
            model: 4
            Item {
                required property int index
                readonly property bool atRight: index % 2 === 1
                readonly property bool atBottom: index >= 2
                x: atRight ? fr.width - 16 : 0
                y: atBottom ? fr.height - 16 : 0
                width: 16; height: 16
                Rectangle { x: parent.atRight ? 15 : 0; width: 1; height: 16; color: hud.ink3 }
                Rectangle { y: parent.atBottom ? 15 : 0; width: 16; height: 1; color: hud.ink3 }
            }
        }
        Text {
            x: 22; y: 14
            text: fr.title
            font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 3
            color: hud.ink2
        }
        Text {
            anchors { right: parent.right; rightMargin: 22 }
            y: 10
            text: fr.kanji
            font.family: Theme.kanji; font.pixelSize: 15
            color: hud.ink3
        }
        Item { id: inner; x: 22; y: 44; width: fr.width - 44; height: fr.height - 62 }
    }

    // two minutes of history, 0..1, with a faint fill under it
    component Spark: Item {
        id: spark
        property var values: []
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: hud.hair }
        Repeater {
            model: 4
            Rectangle { required property int index; y: index * spark.height / 4; width: spark.width; height: 1; color: hud.faint }
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: hud.faint
                PathPolyline {
                    path: {
                        const v = spark.values, w = spark.width, h = spark.height
                        if (v.length < 2) return []
                        const pts = v.map((y, i) => Qt.point(w - (v.length - 1 - i) * w / 59, h - 1 - y * (h - 3)))
                        return pts.concat([Qt.point(w, h), Qt.point(pts[0].x, h)])
                    }
                }
            }
            ShapePath {
                strokeColor: hud.ink
                strokeWidth: 1.5
                fillColor: "transparent"
                joinStyle: ShapePath.RoundJoin
                PathPolyline {
                    path: spark.values.map((y, i) => Qt.point(spark.width - (spark.values.length - 1 - i) * spark.width / 59,
                                                             spark.height - 1 - y * (spark.height - 3)))
                }
            }
        }
    }

    // segments filled up to `value`
    component Segments: Row {
        id: seg
        property real value: 0
        property int count: 24
        spacing: 3
        Repeater {
            model: seg.count
            Rectangle {
                required property int index
                width: 8; height: 10; radius: 1
                color: index < Math.round(seg.value * seg.count) ? hud.ink : hud.hair
            }
        }
    }

    // one line: label (kanji over English) left, value and note right
    component Readout: Item {
        id: ro
        property string kanji
        property string name
        property string value
        property string note
        implicitHeight: 42
        Column {
            id: lbl
            spacing: 1
            Text { text: ro.kanji; font.family: Theme.kanji; font.pixelSize: 17; color: hud.ink2 }
            Text { text: ro.name; font.family: Theme.mono; font.pixelSize: 9; font.letterSpacing: 2.4; color: hud.ink3 }
        }
        Column {
            anchors { right: parent.right; verticalCenter: lbl.verticalCenter }
            spacing: 2
            Text {
                anchors.right: parent.right
                width: Math.min(implicitWidth, ro.width - 120)
                horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                text: ro.value
                font.family: Theme.mono; font.pixelSize: 17; font.weight: Font.Medium
                color: hud.ink
            }
            Text {
                anchors.right: parent.right
                width: Math.min(implicitWidth, ro.width - 120)
                horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                visible: text !== ""
                text: ro.note
                font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 1.6
                color: hud.ink3
            }
        }
    }

    // a MAGI core: big figure, history, a detail line
    component Core: Frame {
        id: core
        property string figure
        property string detail
        property var values: []
        Text {
            id: fig
            text: core.figure
            font.family: Theme.digits; font.pixelSize: 46
            color: hud.ink
        }
        Text {
            anchors { right: parent.right; baseline: fig.baseline }
            text: core.detail
            font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.6
            color: hud.ink3
        }
        Spark {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: fig.bottom; topMargin: 16 }
            values: core.values
        }
    }

    // everything is placed in screen px, moved with the wallpaper (it drifts
    // up to 20 px; the window has room for that on every side)
    Item {
        x: -(hud.bandLeft - 24) + Math.round(Eva.parallaxX * 20)
        y: Math.round(Eva.parallaxY * 20)
        width: hud.sw
        height: hud.barTop

        // ---- the three cores, over the moon ----
        Row {
            x: hud.bandLeft
            y: hud.topY
            spacing: hud.gap
            opacity: hud.shown
            readonly property int w: Math.floor((hud.bandRight - hud.bandLeft - 2 * hud.gap) / 3)

            Core {
                width: parent.w; height: hud.topH
                title: "MELCHIOR · 1"; kanji: "演算"
                figure: (Math.round(hud.cpu * 100) + "").padStart(3, "!") + "%"
                detail: "CPU" + (isNaN(hud.cpuTemp) ? "" : " · " + Math.round(hud.cpuTemp) + "°C")
                values: hud.cpuHist
            }
            Core {
                width: parent.w; height: hud.topH
                title: "BALTHASAR · 2"; kanji: "描画"
                figure: (Math.round(hud.gpu * 100) + "").padStart(3, "!") + "%"
                detail: "RADEON" + (isNaN(hud.gpuTemp) ? "" : " · " + Math.round(hud.gpuTemp) + "°C")
                values: hud.gpuHist
            }
            Core {
                width: parent.w; height: hud.topH
                title: "CASPER · 3"; kanji: "記憶"
                figure: hud.memUsed.toFixed(1)
                detail: "OF " + hud.memTotal.toFixed(0) + " GB" + (hud.swapUsed > 0.05 ? " · SWAP " + hud.swapUsed.toFixed(1) : "")
                values: hud.memHist
            }
        }

        // ---- the moon slot: a dial with the clock, cleared while the record's carried ----
        Item {
            x: hud.moon.x - hud.moon.r
            y: hud.moon.y - hud.moon.r
            width: 2 * hud.moon.r
            height: 2 * hud.moon.r
            opacity: hud.shown * hud.dial
            visible: opacity > 0.01

            Repeater {   // minute ticks around the rim, longer every five
                model: 60
                Rectangle {
                    required property int index
                    readonly property bool major: index % 5 === 0
                    readonly property real a: index / 60 * 2 * Math.PI
                    readonly property real rr: hud.moon.r - (major ? 26 : 16)
                    x: hud.moon.r + Math.sin(a) * rr - width / 2
                    y: hud.moon.r - Math.cos(a) * rr
                    width: major ? 2 : 1
                    height: major ? 18 : 9
                    rotation: index * 6
                    transformOrigin: Item.Top
                    color: major ? hud.ink3 : hud.hair
                    antialiasing: true
                }
            }
            Rectangle {   // the current minute, marked on the rim
                readonly property real a: hud.now.getMinutes() / 60 * 2 * Math.PI
                x: hud.moon.r + Math.sin(a) * (hud.moon.r - 30) - 3
                y: hud.moon.r - Math.cos(a) * (hud.moon.r - 30) - 3
                width: 6; height: 6; radius: 3
                color: hud.ink
            }

            Column {
                anchors.centerIn: parent
                spacing: 14
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "時刻 · LOCAL TIME"
                    font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 3.2
                    color: hud.ink3
                }
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: clock.implicitWidth
                    height: clock.implicitHeight
                    Text {
                        text: "88:88"
                        font.family: Theme.digits; font.pixelSize: 132
                        color: hud.faint
                    }
                    Text {
                        id: clock
                        text: Qt.formatTime(hud.now, "HH:mm")
                        font.family: Theme.digits; font.pixelSize: 132
                        color: hud.ink
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true; shadowColor: Theme.glow; shadowBlur: 0.7
                            shadowOpacity: 0.5; shadowHorizontalOffset: 0; shadowVerticalOffset: 0
                        }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(hud.now, "dddd · d MMMM yyyy").toUpperCase()
                    font.family: Theme.mono; font.pixelSize: 13; font.letterSpacing: 3.2
                    color: hud.ink2
                }
            }
        }

        // ---- right of the moon: power, links, sound ----
        Frame {
            x: hud.sideX
            y: hud.moon.y - hud.moon.r
            width: hud.sideW
            height: 2 * hud.moon.r
            title: "STATUS"; kanji: "状況"
            opacity: hud.shown

            Column {
                width: parent.width
                spacing: 22

                // power, EVA-style: internal/external with a big percentage
                Item {
                    width: parent.width
                    height: 118
                    Column {
                        spacing: 2
                        Text { text: "電源"; font.family: Theme.kanji; font.pixelSize: 17; color: hud.ink2 }
                        Text { text: "POWER"; font.family: Theme.mono; font.pixelSize: 9; font.letterSpacing: 2.4; color: hud.ink3 }
                        Item { width: 1; height: 8 }
                        Text {
                            text: hud.external ? "EXTERNAL" : "INTERNAL"
                            font.family: Theme.mono; font.pixelSize: 13; font.letterSpacing: 3
                            color: hud.ink
                        }
                        Text { text: hud.powerNote; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 1.6; color: hud.ink3 }
                    }
                    Text {
                        anchors { right: parent.right; top: parent.top }
                        visible: hud.battery !== null && hud.battery.isPresent
                        text: Math.round(hud.batPct * 100) + "%"
                        font.family: Theme.digits; font.pixelSize: 40
                        color: hud.ink
                    }
                    Segments {
                        anchors.bottom: parent.bottom
                        value: hud.batPct
                        count: Math.floor(parent.width / 11)
                    }
                }

                Rectangle { width: parent.width; height: 1; color: hud.hair }

                Readout {
                    width: parent.width
                    kanji: "通信"; name: "NETWORK"
                    value: hud.wired ? "Wired" : hud.network ? hud.network.name : !Networking.wifiEnabled ? "Off" : "Offline"
                    note: hud.network && !hud.wired ? "SIGNAL " + Math.round(hud.signal * 100) + "%" : ""
                }
                Row {   // signal
                    spacing: 3
                    visible: hud.network !== null && !hud.wired
                    Repeater {
                        model: 10
                        Rectangle {
                            required property int index
                            anchors.bottom: parent.bottom
                            width: 6; height: 4 + index * 1.6
                            color: hud.signal > index / 10 ? hud.ink : hud.hair
                        }
                    }
                }

                Readout {
                    width: parent.width
                    kanji: "無線"; name: "BLUETOOTH"
                    value: !hud.adapter || !hud.adapter.enabled ? "Off"
                        : hud.btDevices.length === 0 ? "No devices"
                        : hud.btDevices[0].name + (hud.btDevices.length > 1 ? " +" + (hud.btDevices.length - 1) : "")
                    note: hud.btDevices.length > 0 && hud.btDevices[0].batteryAvailable ? hud.btBattery(hud.btDevices[0]) + "% BATTERY" : ""
                }

                Readout {
                    width: parent.width
                    kanji: "音響"; name: "AUDIO"
                    value: hud.muted ? "Muted" : Math.round(hud.volume * 100) + "%"
                    note: hud.sink ? (hud.sink.description || hud.sink.nickname || hud.sink.name || "").toUpperCase() : ""
                }
                Item {
                    width: parent.width; height: 3
                    Rectangle { width: parent.width; height: 1; anchors.verticalCenter: parent.verticalCenter; color: hud.hair }
                    Rectangle { width: parent.width * Math.min(1, hud.volume); height: 3; color: hud.muted ? hud.ink3 : hud.ink }
                }
            }

            // what's playing, at the bottom of the column
            Column {
                anchors.bottom: parent.bottom
                width: parent.width
                spacing: 8
                visible: hud.player !== null && (hud.player.trackTitle || "") !== ""
                Rectangle { width: parent.width; height: 1; color: hud.hair }
                Item { width: 1; height: 6 }
                Item {
                    width: parent.width
                    height: 38
                    Column {
                        spacing: 1
                        Text { text: "再生"; font.family: Theme.kanji; font.pixelSize: 17; color: hud.ink2 }
                        Text {
                            text: hud.player && hud.player.playbackState === MprisPlaybackState.Playing ? "NOW PLAYING" : "PAUSED"
                            font.family: Theme.mono; font.pixelSize: 9; font.letterSpacing: 2.4; color: hud.ink3
                        }
                    }
                    Text {
                        anchors { right: parent.right; top: parent.top }
                        text: hud.player && hud.player.length > 0
                            ? hud.duration2(hud.player.position) + " / " + hud.duration2(hud.player.length) : ""
                        font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.2
                        color: hud.ink3
                    }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: hud.player ? hud.player.trackTitle : ""
                    font.family: Theme.font; font.pixelSize: 17; font.weight: Font.Medium
                    color: hud.ink
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: hud.player ? (hud.player.trackArtist || "").toUpperCase() : ""
                    font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 2
                    color: hud.ink2
                }
                Item {
                    width: parent.width; height: 3
                    Rectangle { width: parent.width; height: 1; anchors.verticalCenter: parent.verticalCenter; color: hud.hair }
                    Rectangle {
                        width: hud.player && hud.player.length > 0 ? parent.width * Math.min(1, hud.player.position / hud.player.length) : 0
                        height: 3
                        color: hud.ink
                    }
                }
            }
        }

        // ---- below the moon: storage and system ----
        Frame {
            x: hud.bandLeft
            y: hud.bottomY
            width: hud.bandRight - hud.bandLeft
            height: hud.bottomH
            title: "SYSTEM"; kanji: "基盤"
            opacity: hud.shown

            Row {
                width: parent.width
                spacing: hud.gap
                readonly property int w: Math.floor((width - 3 * hud.gap) / 4)

                Column {
                    width: parent.w
                    spacing: 10
                    Readout { width: parent.width; kanji: "保存"; name: "STORAGE"; value: hud.diskUsed.toFixed(0) + " / " + hud.diskTotal.toFixed(0) + " GB" }
                    Segments { value: hud.diskTotal > 0 ? hud.diskUsed / hud.diskTotal : 0; count: Math.floor(parent.width / 11) }
                }
                Readout {
                    width: parent.w
                    kanji: "稼働"; name: "UPTIME"
                    value: {
                        const d = Math.floor(hud.uptime / 86400), h = Math.floor(hud.uptime % 86400 / 3600), m = Math.floor(hud.uptime % 3600 / 60)
                        return (d > 0 ? d + "d " : "") + h + "h " + m + "m"
                    }
                }
                Readout {
                    width: parent.w
                    kanji: "負荷"; name: "LOAD"
                    value: hud.load
                    note: "1 · 5 · 15 MIN"
                }
                Readout {
                    width: parent.w
                    kanji: "端末"; name: "HOST"
                    value: hostFile.text().trim()
                    note: kernelFile.text().trim().toUpperCase()
                }
            }

            // power draw, with two minutes of history
            Item {
                y: 78
                width: parent.width
                height: parent.height - y
                Readout {
                    id: powerOut
                    width: Math.floor((parent.width - 3 * hud.gap) / 4)
                    kanji: "電力"; name: "POWER DRAW"
                    value: isNaN(hud.power) ? "—" : hud.power.toFixed(1) + " W"
                    note: hud.batteryNote
                }
                Spark {
                    anchors { left: powerOut.right; leftMargin: hud.gap; right: parent.right; top: parent.top; bottom: parent.bottom }
                    values: hud.powerHist.map(v => v / hud.powerScale)
                }
            }
        }
    }
}
