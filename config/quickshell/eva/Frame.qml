import QtQuick
import Quickshell
import Quickshell.Wayland

// A thin glass frame around the screen (Liquid.qml), as wide as Hyprland's
// gap around maximized windows, so no wallpaper shows past them. The dock
// grows out of its bottom edge and melts into it (Bar.qml). Whenever
// something pops up or down, its wave runs along the frame too.
// Four strip windows, one per edge, so Hyprland only blurs the strips: one
// screen-sized blurred layer cost ~40% of this iGPU whenever the wallpaper
// drifted. Under windows; takes no clicks; holding still it costs nothing.
Scope {
    id: frame

    property var screen
    readonly property int band: Eva.frameWidth
    readonly property int strip: 32     // the band, the room a wave bends it in, the dock's join
    readonly property var dock: screen ? (Eva.dockGlass[screen.name] ?? null) : null

    Variants {
        model: ["top", "bottom", "left", "right"]
        Edge {}
    }

    component Edge: PanelWindow {
        id: edge

        required property string modelData
        readonly property bool across: modelData === "top" || modelData === "bottom"
        readonly property real sw: frame.screen ? frame.screen.width : 0
        readonly property real sh: frame.screen ? frame.screen.height : 0
        // where this strip sits on the screen (the side strips fit between
        // the top and bottom ones)
        readonly property real ox: modelData === "right" ? sw - frame.strip : 0
        readonly property real oy: modelData === "bottom" ? sh - frame.strip : across ? 0 : frame.strip

        screen: frame.screen
        anchors {
            top: edge.modelData !== "bottom"
            bottom: edge.modelData !== "top"
            left: edge.modelData !== "right"
            right: edge.modelData !== "left"
        }
        margins {
            top: edge.across ? 0 : frame.strip
            bottom: edge.across ? 0 : frame.strip
        }
        implicitWidth: frame.strip
        implicitHeight: frame.strip
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "eva-frame"
        mask: Region {}

        Connections {
            target: Eva
            function onRipple(screenName, x, y, start) {
                if (frame.screen && screenName === frame.screen.name)
                    glass.rippleAt(x - frame.screen.x - edge.ox, y - frame.screen.y - edge.oy, start)
            }
        }

        Liquid {
            id: glass
            anchors.fill: parent
            glass: Theme.glassStrong   // the dock's glass, so where it melts in is one piece
            rimColor: Theme.alpha(Theme.text, 0.32)
            rimWidth: 1
            shadow: 0
            frameRect: Qt.rect(frame.band - edge.ox, frame.band - edge.oy, edge.sw - 2 * frame.band, edge.sh - 2 * frame.band)
            frameRadius: Eva.frameRadius
            // The dock melting into the bottom edge: we draw the band (its side
            // of the join); the dock's window draws the rest, around the dock.
            anchor: frame.dock ? Qt.rect(frame.dock.x - edge.ox, frame.dock.y - edge.oy, frame.dock.w, frame.dock.h)
                               : Qt.rect(0, 0, 0, 0)
            anchorRadius: frame.dock ? frame.dock.r : 0
            frameFillet: frame.dock ? frame.dock.fillet : 14
            exclude: frame.dock ? Qt.rect(frame.dock.x - 80 - edge.ox, frame.dock.stripTop - edge.oy, frame.dock.w + 160, edge.sh)
                                : Qt.rect(0, 0, 0, 0)
            rippleBulge: Eva.rippleBulge * 0.75   // the band is thin
        }
    }
}
