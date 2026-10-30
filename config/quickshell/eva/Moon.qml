import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// The moon from the "Fly Me to the Moon" end credits, beside Rei, as a dotted
// outline that the vinyl record (~/vinyl-visualizer) can be dropped into.
// Hidden until you pick up the record; it brightens while the record is over
// it, and dropping the record in plays Fly Me to the Moon (the record's dock
// code does the snapping and the playing; this only draws and describes it).
//
// The record learns where the moon is from $XDG_RUNTIME_DIR/vinyl-dock.json,
// written here, and reports back through `quickshell ipc call eva moon EVENT`.
PanelWindow {
    id: moon

    required property var rei

    // Sized like the moon in the credits GIF, relative to Rei (moon 101 px
    // across, she is 119 px tall), 4 px lower than her middle. In the GIF it
    // nearly touches her; here it's moved left, to sit midway between her
    // and Unit-01 so the record doesn't overlap her.
    readonly property real gifScale: rei.artHeight / 119
    property int shiftLeft: 190
    readonly property int cx: Math.round(rei.centerX - 67 * gifScale) - shiftLeft
    readonly property int cy: Math.round(rei.centerY + 4 * gifScale)
    readonly property int radius: Math.round(50.5 * gifScale)
    readonly property int room: 48   // for the hover swell and glow

    // FLY ME TO THE MOON - 2020 Version, Yoko Takahashi (Evangelion Finally).
    property string track: "spotify:track:56dvEv8PIWFuc5vJQLPM0L"

    // "hidden", "shown" (record picked up), "hover", "docked"
    property string state_: "hidden"
    onState_Changed: Eva.moonOutline = state_ === "shown" || state_ === "hover"

    anchors { left: true; top: true }
    margins { left: cx - radius - room; top: cy - radius - room }
    implicitWidth: 2 * (radius + room)
    implicitHeight: 2 * (radius + room)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "eva-moon"
    mask: Region {}   // the record does the dragging

    Connections {
        target: Eva
        function onMoonEvent(event) {
            if (event === "grab") Hyprland.refreshToplevels()
            if (event === "grab" || event === "leave" || event === "undock") moon.state_ = "shown"
            else if (event === "hover") moon.state_ = "hover"
            else if (event === "dock") moon.state_ = "docked"
            else if (event === "release") moon.state_ = "hidden"
        }
    }

    // ---- tell the record where the moon is ----

    FileView {
        id: dockFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/vinyl-dock.json"
        printErrors: false
    }

    function writeDock() {
        if (moon.radius <= 0 || !moon.screen) return
        dockFile.setText(JSON.stringify({
            monitor: moon.screen.name, cx: moon.cx, cy: moon.cy, r: moon.radius,
            uri: moon.track,
            open: !moon.covered,
            notify: ["quickshell", "-c", "eva", "ipc", "call", "eva", "moon"]
        }, null, 2) + "\n")
    }

    function publish() {
        writeDock()
        Eva.moonArea = { x: moon.cx, y: moon.cy, r: moon.radius }
    }
    // A window hiding the moon (maximized, fullscreen, or just big enough):
    // the record only docks while you can actually see it. Ordinary windows
    // over part of it don't count. Window positions are fetched as you pick
    // the record up.
    readonly property bool covered: {
        const mon = Hyprland.monitorFor(moon.screen)
        const ws = mon ? mon.activeWorkspace : Hyprland.focusedWorkspace
        if (!ws || !moon.screen) return false
        const x0 = moon.screen.x + moon.cx - moon.radius, y0 = moon.screen.y + moon.cy - moon.radius
        const side = 2 * moon.radius
        return Hyprland.toplevels.values.some(t => {
            const o = t.lastIpcObject
            if (!o || !o.at || !t.workspace || t.workspace.id !== ws.id) return false
            const ix = Math.max(0, Math.min(x0 + side, o.at[0] + o.size[0]) - Math.max(x0, o.at[0]))
            const iy = Math.max(0, Math.min(y0 + side, o.at[1] + o.size[1]) - Math.max(y0, o.at[1]))
            return ix * iy >= 0.9 * side * side
        })
    }
    onCoveredChanged: writeDock()

    onCxChanged: publish()
    onCyChanged: publish()
    onRadiusChanged: publish()
    Component.onCompleted: publish()

    // ---- drawing ----

    Item {
        id: ring
        anchors.centerIn: parent
        width: 2 * moon.radius
        height: 2 * moon.radius

        opacity: moon.state_ === "hidden" ? 0 : moon.state_ === "docked" ? 0 : moon.state_ === "hover" ? 1 : 0.55
        scale: moon.state_ === "hidden" ? 0.96 : moon.state_ === "docked" ? 1.08 : moon.state_ === "hover" ? 1.035 : 1
        Behavior on opacity { NumberAnimation { duration: moon.state_ === "docked" ? 600 : 280; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: moon.state_ === "docked" ? 600 : 320; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

        // Faint glow inside while the record is over it.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            opacity: moon.state_ === "hover" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.07) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.02) }
            }
        }

        // The dotted outline, slowly turning while it's visible.
        Shape {
            id: dots
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            rotation: 0

            ShapePath {
                strokeColor: "white"
                strokeWidth: moon.state_ === "hover" ? 3.2 : 2.2
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                strokeStyle: ShapePath.DashLine
                dashPattern: [0.01, 5]   // round dots: zero-length dashes with round caps
                Behavior on strokeWidth { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                PathAngleArc {
                    centerX: moon.radius
                    centerY: moon.radius
                    radiusX: moon.radius - 4
                    radiusY: moon.radius - 4
                    startAngle: 0
                    sweepAngle: 360
                }
            }

            RotationAnimation on rotation {
                running: ring.opacity > 0.01
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 48000
            }
        }
    }
}
