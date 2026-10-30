import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower

// Rei, upside down and slowly turning in braille dots, like the silhouette in
// the "Fly Me to the Moon" end credits. Sits on the desktop above the wallpaper,
// below windows. Drag her sideways to spin her yourself.
// Frames: ~/.config/eva/rei-frames.json, one braille frame per frame of the
// credits GIF (~/Downloads/fly.gif: 36 drawings, ~12 a second, its own pace;
// no made-up in-betweens; timed partly by how far she moves, so her arm swing
// doesn't read as a jump), lit by the moon on her left: dense dots on that
// side, thinning into shadow. Rebuild with ~/.config/eva/tools/fly2braille.py.
// Older versions: rei-frames-flat.json (unlit), rei-frames-interp.json,
// rei-frames-ascii.json. Animates
// only on AC, outside Low power mode, and while she's mostly visible;
// otherwise she holds still.
PanelWindow {
    id: rei

    // Where she hangs: the middle of the figure, in screen pixels. Right of
    // the moon, as in the credits (see Moon.qml).
    property int centerX: 2290
    property int centerY: 800
    readonly property int posX: centerX - Math.round(art.implicitWidth / 2)
    readonly property int posY: centerY - Math.round(art.implicitHeight / 2)
    readonly property int artHeight: art.implicitHeight
    readonly property int pad: 16   // room for the glow
    // Parallax: she drifts with the wallpaper but further (it moves 20 px),
    // being nearer. She moves inside her window, so the window stays put.
    readonly property int reach: 32
    readonly property int room: pad + reach

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property bool lowPower: monitor !== null && monitor.lastIpcObject !== null
        && (monitor.lastIpcObject.refreshRate ?? 999) <= 61
    property bool hidden: false
    readonly property bool animate: !UPower.onBattery && !lowPower && !hidden && visible && frames.length > 0

    // She's only there while the vinyl record sits in the moon: fades in when
    // it's dropped in, out when it's pulled out or goes away (closed, hidden,
    // faded with Spotify). The record reports "present"/"away"; at startup,
    // $XDG_RUNTIME_DIR/vinyl-docked says whether it's there. While she's gone
    // her window is unmapped, so she costs nothing.
    property bool summoned: false
    onSummonedChanged: Eva.recordInMoon = summoned
    visible: summoned || art.opacity > 0.01

    Connections {
        target: Eva
        function onMoonEvent(event) {
            if (event === "present") rei.summoned = true
            else if (event === "away" || event === "undock") rei.summoned = false
        }
    }
    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/vinyl-docked"
        printErrors: false
        onLoaded: rei.summoned = true
        onLoadFailed: rei.summoned = false
    }

    property var frames: []
    property var delays: []       // ms per frame (optional; she turns unevenly between drawings)
    property int interval: 100    // the average, when there are no per-frame delays
    property real pace: 1.0       // > 1 turns slower than the GIF (1: ~3.1 s a turn, 1.25: ~3.8 s)
    property real pos: 0          // fractional frame position
    property real speed: 1        // frames per tick; 1 = the GIF's own pace
    readonly property int frame: frames.length ? ((Math.floor(pos) % frames.length) + frames.length) % frames.length : 0

    anchors { left: true; top: true }
    margins { left: posX - room; top: posY - room }
    implicitWidth: art.implicitWidth + 2 * room
    implicitHeight: art.implicitHeight + 2 * room
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "eva-rei"
    mask: Region { item: drag }

    FileView {
        id: frameFile
        path: Quickshell.env("HOME") + "/.config/eva/rei-frames.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text())
                rei.frames = d.frames
                rei.delays = d.delays && d.delays.length === d.frames.length ? d.delays : []
                rei.interval = d.interval || 100
                retry.tries = 0
            } catch (e) {
                // most likely caught mid-write: look again shortly
                if (retry.tries++ < 5) retry.restart()
                else console.warn("eva: bad rei-frames.json:", e)
            }
        }
    }
    Timer {
        id: retry
        property int tries: 0
        interval: 400
        onTriggered: frameFile.reload()
    }

    Timer {
        running: rei.animate && !drag.pressed
        repeat: true
        interval: Math.round((rei.delays.length ? rei.delays[rei.frame] : rei.interval) * rei.pace)
        onTriggered: {
            rei.pos += rei.speed
            rei.speed += (1 - rei.speed) * 0.08   // ease back to her own pace after a fling
        }
    }

    Text {
        id: art
        x: rei.room + Math.round(Eva.parallaxX * rei.reach)
        y: rei.room + Math.round(Eva.parallaxY * rei.reach)
        opacity: rei.summoned ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: rei.summoned ? 1800 : 900; easing.type: Easing.InOutSine } }
        text: rei.frames.length ? rei.frames[rei.frame] : ""
        textFormat: Text.PlainText
        color: Qt.rgba(1, 1, 1, 0.82)
        // Braille needs a font that has it, so every dot sits on one grid
        // (JetBrains Mono has none and falls back glyph by glyph).
        font.family: "MesloLGS Nerd Font Mono"
        font.pixelSize: 15
        lineHeightMode: Text.ProportionalHeight
        lineHeight: 1.0
        renderType: Text.NativeRendering

        layer.enabled: true
        layer.effect: MultiEffect {   // soft white bloom, matching the wallpaper
            shadowEnabled: true
            shadowColor: "white"
            shadowBlur: 0.7
            shadowOpacity: 0.45
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }

    // Drag sideways to spin; let go mid-drag to fling. Hovering keeps the
    // parallax going (the wallpaper can't see the cursor while it's over her).
    MouseArea {
        id: drag
        anchors.fill: art
        hoverEnabled: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property real lastX: 0
        property real lastT: 0
        property real vel: 0
        // window coordinates: she may drift under the cursor mid-drag
        function winX(mouse) { return drag.mapToItem(null, mouse.x, mouse.y).x }
        onPressed: mouse => { lastX = winX(mouse); lastT = Date.now(); vel = 0 }
        onPositionChanged: mouse => {
            if (!pressed) {
                const w = drag.mapToItem(null, mouse.x, mouse.y)
                Eva.parallaxPoint(rei.posX - rei.room + w.x, rei.posY - rei.room + w.y)
                return
            }
            const x = winX(mouse), dx = x - lastX, now = Date.now()
            rei.pos += dx / 8                        // 8 px of drag per frame (~290 px a turn)
            vel = dx / 8 / Math.max(1, now - lastT) * rei.interval * rei.pace
            lastX = x
            lastT = now
        }
        onReleased: rei.speed = Math.max(-6, Math.min(6, vel || 1))
    }

    // Hold still while a window covers most of her (checked every 2 s).
    Timer {
        running: !UPower.onBattery && !rei.lowPower && rei.visible
        repeat: true
        triggeredOnStart: true
        interval: 2000
        onTriggered: Hyprland.refreshToplevels()
    }

    readonly property var coveringWindows: {
        const ws = Hyprland.focusedWorkspace
        if (!ws) return []
        const rx = rei.posX, ry = rei.posY, rw = art.implicitWidth, rh = art.implicitHeight
        return Hyprland.toplevels.values.filter(t => {
            const o = t.lastIpcObject
            if (!o || !o.at || !t.workspace || t.workspace.id !== ws.id) return false
            const ix = Math.max(0, Math.min(rx + rw, o.at[0] + o.size[0]) - Math.max(rx, o.at[0]))
            const iy = Math.max(0, Math.min(ry + rh, o.at[1] + o.size[1]) - Math.max(ry, o.at[1]))
            return ix * iy > 0.5 * rw * rh
        })
    }
    onCoveringWindowsChanged: hidden = coveringWindows.length > 0
}
