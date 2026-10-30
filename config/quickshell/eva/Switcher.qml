import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

// Alt+Tab switcher like Plasma's: thumbnails of the windows on this workspace
// (plus minimized ones), most recently used first. Tab moves the selection,
// releasing Alt switches. Esc cancels; clicking a thumbnail switches to it.
// The X on a thumbnail (selected or hovered) closes that window and keeps the
// switcher open, so you can close a few in a row.
PanelWindow {
    id: switcher

    property var shown: []     // snapshot taken when the switcher opens
    property int selected: 0
    property real earlyRelease: 0   // Alt released before the open request arrived

    readonly property int tileW: 280
    readonly property int tileH: 232

    function snapshot() {
        const ws = Hyprland.focusedWorkspace
        const mru = Eva.mru
        // Our live MRU list first; windows not focused since the bar started
        // fall back to Hyprland's own focus history.
        const rank = t => {
            const i = mru.indexOf(String(t.address))
            if (i !== -1) return i
            const f = t.lastIpcObject ? t.lastIpcObject.focusHistoryID : undefined
            return typeof f === "number" ? 1000 + f : 1e6
        }
        return Hyprland.toplevels.values
            .filter(t => t.workspace !== null && ((ws !== null && t.workspace.id === ws.id) || t.workspace.name === "special:minimized"))
            .sort((a, b) => rank(a) - rank(b))
    }

    function step(delta) {
        if (!visible) {
            shown = snapshot()
            Hyprland.refreshToplevels()   // fresher focus history for next time
            if (shown.length === 0) return
            // Only one popup holds the keyboard at a time.
            Eva.closeLauncher()
            Eva.closeControl()
            Eva.closeTrayPopup()
            // First Alt+Tab goes to the previous window, like Plasma.
            selected = delta > 0 ? Math.min(1, shown.length - 1) : shown.length - 1
            Eva.switcherOpen = true
            // A quick Alt+Tab tap: just switch to the previous window.
            if (Date.now() - earlyRelease < 400)
                commit()
            return
        }
        if (shown.length > 0)
            selected = (selected + delta + shown.length) % shown.length
    }

    function commit() {
        if (!visible) {
            earlyRelease = Date.now()
            return
        }
        earlyRelease = 0
        target = shown[selected] ?? null
        close()
        // Focus only after our keyboard grab is gone; otherwise Hyprland hands
        // focus back to the previously focused window when the switcher unmaps.
        if (target) focusLater.restart()
    }

    property var target: null

    Timer {
        id: focusLater
        interval: 80
        onTriggered: {
            const t = switcher.target
            switcher.target = null
            if (t) Eva.activateWindow(t)
        }
    }

    function close() {
        Eva.switcherOpen = false
        shown = []
    }

    // The strip re-centers after a close, which can put the next tile's X
    // under the cursor: a quick double click shouldn't close that one too.
    property real closedAt: 0

    function closeWindow(t) {
        if (Date.now() - closedAt < 400) return
        closedAt = Date.now()
        Eva.dispatch(`hl.dsp.window.close({ window = "${Eva.windowSelector(t)}" })`)
    }

    // A window's tile goes once the window is really gone (one asking to save
    // first stays until you answer).
    function prune() {
        const alive = Hyprland.toplevels.values
        const left = shown.filter(t => alive.indexOf(t) !== -1)
        if (left.length === shown.length) return
        const cur = shown[selected]
        shown = left
        if (left.length === 0) { close(); return }
        const i = left.indexOf(cur)
        selected = i !== -1 ? i : Math.min(selected, left.length - 1)
    }

    Connections {
        target: Hyprland.toplevels
        enabled: switcher.visible
        function onValuesChanged() { switcher.prune() }
    }

    Connections {
        target: Eva
        function onSwitcherStep(delta) { switcher.step(delta) }
        function onSwitcherCommit() { switcher.commit() }
    }

    // ---- window ----

    readonly property int room: 32   // shadow room around the card

    visible: Eva.switcherOpen
    // No anchors: layer-shell centers the surface on the screen.
    implicitWidth: Math.min(screen ? screen.width - 160 : 1600, Math.max(1, shown.length) * tileW + 32) + room * 2
    implicitHeight: tileH + 72 + room * 2
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "eva-switcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: if (visible) keys.forceActiveFocus()

    HyprlandFocusGrab {
        windows: [switcher]
        active: switcher.visible
        onCleared: switcher.close()
    }

    Glass {
        anchors { fill: parent; margins: switcher.room }

        Item {
            id: keys
            anchors.fill: parent
            focus: true

            // Backup for the Hyprland Alt-release bind: we have keyboard focus
            // while open, so Alt's release arrives here too.
            Keys.onReleased: event => {
                if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta || !(event.modifiers & Qt.AltModifier))
                    switcher.commit()
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) switcher.close()
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) switcher.commit()
                else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) switcher.step(1)
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) switcher.step(-1)
                else return
                event.accepted = true
            }
        }

        Label {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 16 }
            width: parent.width - 48
            horizontalAlignment: Text.AlignHCenter
            text: switcher.shown[switcher.selected] ? switcher.shown[switcher.selected].title : ""
            elide: Text.ElideMiddle
            font.pixelSize: Theme.fontLabel
            font.weight: Font.Normal
            color: Theme.textSecondary
        }

        ListView {
            id: strip
            anchors { fill: parent; margins: 16; bottomMargin: 44 }
            orientation: ListView.Horizontal
            interactive: false
            clip: true
            model: switcher.shown
            currentIndex: switcher.selected
            highlightMoveDuration: 0
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: MouseArea {
                id: tile

                required property var modelData
                required property int index
                readonly property bool current: index === switcher.selected
                readonly property bool minimized: modelData.workspace !== null && modelData.workspace.name === "special:minimized"
                readonly property string appId: modelData.wayland ? modelData.wayland.appId : (modelData.lastIpcObject["class"] ?? "")
                readonly property var entry: appId !== "" ? DesktopEntries.heuristicLookup(appId) : null

                width: switcher.tileW
                height: strip.height
                hoverEnabled: true
                onEntered: switcher.selected = index
                onClicked: { switcher.selected = index; switcher.commit() }

                Rectangle {
                    anchors { fill: parent; margins: 4 }
                    radius: Theme.radiusMedium + 2
                    color: tile.current ? Theme.selection : tile.containsMouse ? Theme.hover : "transparent"
                    border.color: tile.current ? Theme.selectionStroke : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                }

                // Captured once per open, not continuously.
                ClippingRectangle {
                    id: thumbBox
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    height: parent.height - 64
                    radius: Theme.radiusSmall + 2
                    color: Theme.fill

                    ScreencopyView {
                        id: thumb
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height * (sourceSize.width / Math.max(1, sourceSize.height)))
                        height: Math.min(parent.height, parent.width * (sourceSize.height / Math.max(1, sourceSize.width)))
                        captureSource: tile.minimized ? null : tile.modelData.wayland
                        live: false
                        paintCursor: false
                    }

                    IconImage {
                        anchors.centerIn: parent
                        visible: !thumb.hasContent
                        implicitSize: 64
                        opacity: tile.minimized ? 0.5 : 1
                        source: Quickshell.iconPath(tile.entry ? tile.entry.icon : tile.appId, "application-x-executable")
                    }
                }

                // Close, lit red under the cursor like the title bar's.
                MouseArea {
                    id: closeBtn
                    anchors { top: thumbBox.top; right: thumbBox.right; margins: 6 }
                    width: 26
                    height: 26
                    visible: tile.current || tile.containsMouse || containsMouse
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: switcher.closeWindow(tile.modelData)

                    Rectangle {   // halo
                        anchors.centerIn: parent
                        width: parent.width + 10
                        height: width
                        radius: width / 2
                        color: Qt.rgba(0.90, 0.33, 0.29, 0.25)
                        opacity: closeBtn.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: closeBtn.containsMouse ? Qt.rgba(0.90, 0.33, 0.29, closeBtn.pressed ? 1 : 0.85) : Qt.rgba(0, 0, 0, 0.55)
                        border.color: closeBtn.containsMouse ? "transparent" : Qt.rgba(1, 1, 1, 0.18)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    }
                    Icon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 16
                        color: "white"
                    }
                }

                RowLayout {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 16; rightMargin: 16; bottomMargin: 14 }
                    spacing: 8

                    IconImage {
                        implicitSize: 20
                        source: Quickshell.iconPath(tile.entry ? tile.entry.icon : tile.appId, "application-x-executable")
                    }

                    Label {
                        Layout.fillWidth: true
                        text: tile.entry ? tile.entry.name : (tile.appId || tile.modelData.title)
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontLabel
                        font.weight: tile.current ? Font.DemiBold : Font.Medium
                        color: tile.current ? Theme.textPrimary : Theme.textSecondary
                    }
                }
            }
        }
    }
}
