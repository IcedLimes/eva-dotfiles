import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Liquid glass dock, centered at the bottom (Liquid.qml). Hidden until the
// pointer touches the bottom edge: in one smooth motion it wells up out of
// the screen's glass frame (Frame.qml) as a drop, spreads to its width and
// lifts off (the neck stretches and snaps) to float just above it, sending a
// ripple through itself and a wave along the frame as it starts. It
// reattaches and sinks back the same way. Stays out while a menu or popup is open. Tells Eva
// where it is, for the start menu to grow out of.
PanelWindow {
    id: bar

    readonly property int dockHeight: 52
    readonly property int pad: 8
    readonly property int band: Eva.frameWidth   // the screen's glass frame
    readonly property int floatGap: 10      // how far it lifts off the frame
    readonly property int room: 76          // above the dock: shadow, the start menu's join
    readonly property int bumpW: 84         // the drop it wells up as
    readonly property int bumpH: 30
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property HyprlandWorkspace workspace: monitor ? monitor.activeWorkspace : null
    readonly property bool revealed: hover.hovered || hideDelay.running || Eva.holdBar

    // the dock, at rest (floating), in window pixels
    readonly property real dockW: row.implicitWidth + 2 * pad
    readonly property real dockX: Math.round((width - dockW) / 2)
    readonly property real dockY: height - band - floatGap - dockHeight

    // well up (0..1), spread (0..1, overshoots), lift off the edge (0..1)
    property real bump: 0
    property real spread: 0
    property real lift: 0
    property real pointerX: width / 2       // where the pointer last was over us
    readonly property real shapeW: bump * bumpW + spread * (dockW - bumpW)
    readonly property real shapeH: bump * bumpH + spread * (dockHeight - bumpH)

    anchors { left: true; right: true; bottom: true }
    implicitHeight: band + floatGap + dockHeight + room
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "eva-bar"

    Component.onCompleted: Eva.barWindows = Eva.barWindows.concat([bar])
    Component.onDestruction: Eva.barWindows = Eva.barWindows.filter(w => w !== bar)

    // While hidden, only a 2 px strip along the bottom edge takes input; while
    // out, the dock and that strip, so a pointer resting on the edge beside
    // the dock keeps it out instead of making it bob up and down.
    mask: Region {
        item: bar.revealed ? hit : sensor
        Region { item: sensor }
    }

    onRevealedChanged: {
        if (revealed) {
            sink.stop()
            rise.restart()
        } else {
            rise.stop()
            sink.restart()
        }
        // a wave from where the pointer met the edge, through the dock and the frame
        const px = hover.hovered ? hover.point.position.x : pointerX
        if (screen) Eva.rippleFrom(screen, screen.x + px, screen.y + screen.height - band / 2)
        publish()
        publishGlass()
    }

    // The dock's glass for the frame to melt into (screen px), at most 60
    // times a second while it moves; gone while it's away.
    function publishGlass() {
        if (!screen) return
        const g = Object.assign({}, Eva.dockGlass)
        if (bump < 0.001) {
            delete g[screen.name]
        } else {
            const top = screen.height - height
            g[screen.name] = {
                x: liquid.box.x, y: top + liquid.box.y, w: liquid.box.width, h: liquid.box.height,
                r: liquid.radius, fillet: liquid.frameFillet, stripTop: top
            }
        }
        Eva.dockGlass = g
    }
    Timer {
        interval: 16
        repeat: true
        running: rise.running || sink.running
        onRunningChanged: if (!running) bar.publishGlass()
        onTriggered: bar.publishGlass()
    }

    // where the dock is on screen, for the start menu and popups
    function publish() {
        if (!screen) return
        const d = Object.assign({}, Eva.docks)
        d[screen.name] = {
            left: dockX, right: dockX + dockW, top: screen.height - floatGap - dockHeight, height: dockHeight,
            bottomGap: band + floatGap, startX: dockX + pad + start.width / 2, startW: start.width,
            up: revealed && !rise.running && lift > 0.95
        }
        Eva.docks = d
    }
    onDockWChanged: publish()
    onWidthChanged: publish()

    Connections {
        target: Eva
        function onRipple(screenName, x, y, start) {
            if (bar.screen && screenName === bar.screen.name)
                liquid.rippleAt(x - bar.screen.x, y - (bar.screen.y + bar.screen.height - bar.height), start)
        }
    }

    // One smooth motion: the drop wells up, spreads and lifts off together,
    // easing out at the end; the neck snaps (and ripples) partway through.
    ParallelAnimation {
        id: rise
        onFinished: bar.publish()
        NumberAnimation { target: bar; property: "bump"; to: 1; duration: 110; easing.type: Easing.OutQuad }
        SequentialAnimation {
            PauseAnimation { duration: 50 }
            NumberAnimation { target: bar; property: "spread"; to: 1; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 0.7 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 200 }
            NumberAnimation { target: bar; property: "lift"; to: 1; duration: 260; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 160 }
            ParallelAnimation {
                NumberAnimation { target: row; property: "opacity"; to: 1; duration: 200 }
                NumberAnimation { target: row; property: "scale"; from: 0.96; to: 1; duration: 260; easing.type: Easing.OutCubic }
            }
        }
    }
    ParallelAnimation {
        id: sink
        NumberAnimation { target: row; property: "opacity"; to: 0; duration: 70 }
        NumberAnimation { target: bar; property: "lift"; to: 0; duration: 120; easing.type: Easing.InQuad }
        SequentialAnimation {
            PauseAnimation { duration: 40 }
            NumberAnimation { target: bar; property: "spread"; to: 0; duration: 200; easing.type: Easing.InOutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 200 }
            NumberAnimation { target: bar; property: "bump"; to: 0; duration: 110; easing.type: Easing.InQuad }
        }
    }

    Item {
        anchors.fill: parent

        HoverHandler {
            id: hover
            onHoveredChanged: if (!hovered) hideDelay.restart()
            onPointChanged: if (hovered) bar.pointerX = point.position.x
        }

        Timer { id: hideDelay; interval: 600 }

        Item {
            id: sensor
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 2
        }

        Item {
            id: hit
            x: bar.dockX - 4
            y: bar.dockY - 4
            width: bar.dockW + 8
            height: bar.dockHeight + bar.floatGap + bar.band + 4
        }

        Liquid {
            id: liquid
            anchors.fill: parent
            visible: bar.bump > 0.001
            glass: Theme.glassStrong   // same as the start menu, so their join is one piece
            radius: Math.min(Theme.radiusLarge, bar.shapeH / 2)
            // Grows out of the frame's bottom band, then lifts off it: while
            // attached the box runs down into the band so only its top is
            // rounded; as it lifts, its bottom comes up and the flare to the
            // band thins until it lets go. We draw inside the frame; the
            // frame's window draws the band.
            readonly property real up: bar.lift * bar.floatGap
            box: Qt.rect(bar.width / 2 - bar.shapeW / 2, bar.height - bar.band - bar.shapeH - up,
                         Math.max(0, bar.shapeW),
                         bar.shapeH > 0.5 ? bar.shapeH + (1 - Math.min(1, bar.lift)) * 40 : 0)
            frameRect: bar.screen ? Qt.rect(bar.band, bar.band - (bar.screen.height - bar.height),
                                            bar.width - 2 * bar.band, bar.screen.height - 2 * bar.band)
                                  : Qt.rect(0, 0, 0, 0)
            frameRadius: Eva.frameRadius
            frameFillet: Math.max(2, 14 - 11 * bar.lift)
            insideOnly: 1
            // the start menu growing out of the dock: draw our side of the
            // join (below the dock's top edge; the menu draws above it)
            readonly property var menuBox: Eva.launcherBox && bar.screen && Eva.launcherBox.screen === bar.screen.name
                ? Eva.launcherBox : null
            anchor2: menuBox ? Qt.rect(menuBox.x, menuBox.y - (bar.screen.height - bar.height), menuBox.w, menuBox.h)
                             : Qt.rect(0, 0, 0, 0)
            anchor2Radius: menuBox ? menuBox.r : 0
            fillet2: menuBox ? menuBox.fillet : 22
            clipTop: menuBox ? bar.dockY : -100000
        }

        RowLayout {
            id: row
            x: bar.dockX + bar.pad
            y: bar.dockY + (bar.dockHeight - height) / 2 + (1 - Math.min(1, bar.lift)) * bar.floatGap
            height: bar.dockHeight - 2 * bar.pad
            spacing: 6
            enabled: bar.revealed
            opacity: 0   // the rise/sink fade it

            StartButton { id: start }
            Workspaces { current: bar.workspace }
            Separator {}
            Taskbar { current: bar.workspace }
            Separator {}
            Tray {}
            WifiChip {}
            BluetoothChip {}
            StatusChip {}
            ClockChip {}
        }
    }

    component Separator: Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 20
        Layout.alignment: Qt.AlignVCenter
        color: Theme.stroke
    }
}
