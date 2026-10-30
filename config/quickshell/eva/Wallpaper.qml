import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower

// Desktop wallpaper with a little parallax: while the cursor is over the
// wallpaper itself (or Rei, or the vinyl record in the moon), it drifts a few
// pixels against it, like the Persona rices, and Rei drifts along a little
// further (Eva.parallaxX/Y).
// Only on AC power and outside Low power mode. Every moving frame redraws the
// whole screen (~45% of this iGPU at 60 updates/s), so it stays still while
// you work in windows and updates at most 30 times a second. (Replaces swaybg.)
PanelWindow {
    id: wall

    property string source: Quickshell.env("HOME") + "/Pictures/wallpapers/eva01-mono-parallax-flipped.png"

    // The image is `margin` px larger than the screen on every side; it
    // slides up to `reach` px from center.
    readonly property int margin: 24
    readonly property real reach: 20

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property bool lowPower: monitor !== null && monitor.lastIpcObject !== null
        && (monitor.lastIpcObject.refreshRate ?? 999) <= 61
    readonly property bool active: !UPower.onBattery && !lowPower

    anchors { left: true; right: true; top: true; bottom: true }
    color: "black"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "eva-wallpaper"
    // Takes pointer input only to see the cursor over the bare desktop.

    property real targetX: 0
    property real targetY: 0
    property real offX: 0
    property real offY: 0

    onActiveChanged: if (!active) { targetX = 0; targetY = 0; ease.start() }

    // Rei sits on the first screen; that wallpaper leads her.
    readonly property bool leads: screen === Quickshell.screens[0]
    onOffXChanged: if (leads) Eva.parallaxX = offX / reach
    onOffYChanged: if (leads) Eva.parallaxY = offY / reach

    // x, y: the cursor in screen pixels
    function aim(x, y) {
        const nx = Math.max(-1, Math.min(1, (x - width / 2) / (width / 2)))
        const ny = Math.max(-1, Math.min(1, (y - height / 2) / (height / 2)))
        targetX = -nx * reach   // against the cursor
        targetY = -ny * reach
        if (!ease.running) ease.start()
    }

    HoverHandler {
        id: hover
        enabled: wall.active
        onPointChanged: wall.aim(point.position.x, point.position.y)
        // off the wallpaper while the record's in the moon: maybe onto it (the
        // first answer from Hyprland decides, see below)
        onHoveredChanged: if (!hovered && wall.leads && Eva.recordInMoon) cursorPoll.start()
    }

    // The record is its own window, so over it the wallpaper can't see the
    // cursor: it asks Hyprland where it is (~30 times a second) while the
    // cursor stays over the record (which takes the pointer up to 10% past
    // its rim, room to swell with the beat) and not over a window.
    function overRecord(x, y) {
        const m = Eva.moonArea
        return m !== null && Math.hypot(x - m.x, y - m.y) <= m.r * 1.1 + 2
    }
    function overWindow(x, y) {
        const ws = Hyprland.focusedWorkspace
        return ws !== null && Hyprland.toplevels.values.some(t => {
            const o = t.lastIpcObject
            return o && o.at && t.workspace && t.workspace.id === ws.id
                && x >= o.at[0] && x < o.at[0] + o.size[0] && y >= o.at[1] && y < o.at[1] + o.size[1]
        })
    }
    Timer {
        id: cursorPoll
        interval: 33
        repeat: true
        onTriggered: if (!cursorSock.connected) cursorSock.connected = true
    }
    Socket {
        id: cursorSock
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/hypr/" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "/.socket.sock"
        onConnectedChanged: if (connected) { write("cursorpos"); flush() }   // answers "x, y" and hangs up
        parser: SplitParser {
            splitMarker: ""   // the answer has no newline at the end
            onRead: data => {
                const m = data.match(/(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)/)
                if (!m) return
                const x = Number(m[1]), y = Number(m[2])
                if (hover.hovered || !wall.active || !Eva.recordInMoon || !wall.overRecord(x, y) || wall.overWindow(x, y)) {
                    cursorPoll.stop()
                    return
                }
                wall.aim(x, y)
            }
        }
    }

    Connections {
        target: Eva
        enabled: wall.active && wall.leads
        function onParallaxPoint(x, y) { wall.aim(x, y) }
    }

    // Eases toward the target at <= 30 updates/s, then stops on whole pixels
    // so the image is crisp at rest. Aims at those whole pixels from the
    // start: Qt re-sends the cursor position after every frame, and easing
    // toward a target between pixels, then rounding away from it, kept the
    // whole screen redrawing 30 times a second with the mouse standing still.
    Timer {
        id: ease
        interval: 33
        repeat: true
        onTriggered: {
            const gx = Math.round(wall.targetX), gy = Math.round(wall.targetY)
            const dx = gx - wall.offX, dy = gy - wall.offY
            if (Math.abs(dx) < 0.4 && Math.abs(dy) < 0.4) {
                wall.offX = gx
                wall.offY = gy
                stop()
                return
            }
            wall.offX += dx * 0.3
            wall.offY += dy * 0.3
        }
    }

    Image {
        x: -wall.margin + wall.offX
        y: -wall.margin + wall.offY
        width: wall.width + 2 * wall.margin
        height: wall.height + 2 * wall.margin
        source: "file://" + wall.source
        fillMode: Image.PreserveAspectCrop
        smooth: true
        cache: false
    }
}
