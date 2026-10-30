import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

// One app on the taskbar (icons only, like Plasma's icon task manager).
// modelData: { id, entry, pinned, windows: [HyprlandToplevel], appId }
//   left click   launch if not running; otherwise focus / minimize / restore,
//                or cycle through its windows
//   middle click new window
//   right click  menu: pin/unpin, new window, close
MouseArea {
    id: btn

    required property var modelData
    readonly property var entry: modelData.entry
    readonly property var wins: modelData.windows
    readonly property bool running: wins.length > 0
    readonly property bool active: wins.some(w => w.activated)
    readonly property bool allMinimized: running && wins.every(w => isMin(w))
    readonly property string name: entry ? entry.name : (modelData.appId || "Window")

    function isMin(w) { return w.workspace !== null && w.workspace.name === "special:minimized" }

    function launch() {
        if (entry) entry.execute()
    }

    function focusWin(w) { Eva.activateWindow(w) }
    function minimize(w) { Eva.minimizeWindow(w) }

    implicitWidth: 40
    implicitHeight: 36
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

    onClicked: mouse => {
        tip.visible = false
        Eva.closeTrayPopup()
        Eva.closeControl()
        if (mouse.button === Qt.MiddleButton) { launch(); return }
        if (mouse.button === Qt.RightButton) { menu.visible = true; return }
        if (!running) { launch(); return }
        if (wins.length === 1) {
            const w = wins[0]
            if (isMin(w)) focusWin(w)
            else if (w.activated) minimize(w)
            else focusWin(w)
        } else {
            const i = wins.findIndex(w => w.activated)
            focusWin(wins[i === -1 ? 0 : (i + 1) % wins.length])
        }
    }

    onContainsMouseChanged: {
        if (containsMouse && !menu.visible) tipDelay.restart()
        else { tipDelay.stop(); tip.visible = false }
    }

    Timer {
        id: tipDelay
        interval: 500
        onTriggered: tip.visible = true
    }

    // Lights up under the pointer: a soft glow behind brighter glass, and the
    // icon lifts a little and brightens.
    property real lit: containsMouse && !pressed ? 1 : 0
    Behavior on lit { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Theme.radiusMedium
        color: Theme.glow
        opacity: 0.22 * btn.lit
        visible: btn.lit > 0.01
        layer.enabled: visible
        layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 20 }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMedium - 2
        color: btn.active ? Theme.selection : btn.pressed ? Theme.pressed : "transparent"
        border.color: btn.active ? Theme.selectionStroke : "transparent"
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.durFast } }

        Rectangle {   // the lit glass on top
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(1, 1, 1, 0.12)
            border.color: Theme.alpha(Theme.glow, 0.4)
            border.width: 1
            opacity: btn.lit
        }
    }

    IconImage {
        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: -2 - 1.5 * btn.lit }
        implicitSize: 24
        scale: 1 + 0.1 * btn.lit
        opacity: btn.allMinimized ? 0.6 + 0.4 * btn.lit : 1
        source: Quickshell.iconPath(btn.entry ? btn.entry.icon : btn.modelData.appId, "application-x-executable")
        layer.enabled: btn.lit > 0.01
        layer.effect: MultiEffect { brightness: 0.14 * btn.lit }
    }

    // Running indicator: accent line when focused, one dot per window otherwise.
    Row {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 3 }
        spacing: 3
        visible: btn.running

        Repeater {
            model: btn.active ? 1 : Math.min(btn.wins.length, 3)
            Rectangle {
                width: btn.active ? 14 : 4
                height: 3
                radius: 1.5
                color: btn.active ? Theme.active : btn.allMinimized ? Theme.textTertiary : Theme.textSecondary
            }
        }
    }

    // ---- hover tooltip ----
    PopupWindow {
        id: tip

        anchor.item: btn
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.margins.top: -8
        implicitWidth: tipCol.implicitWidth + 24
        implicitHeight: tipCol.implicitHeight + 16
        color: "transparent"
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall + 2
            color: Theme.glassStrong
            border.color: Theme.stroke
            border.width: 1

            ColumnLayout {
                id: tipCol
                anchors.centerIn: parent
                spacing: 1

                Label {
                    text: btn.name
                    font.pixelSize: Theme.fontLabel
                    font.weight: Font.DemiBold
                }
                Label {
                    visible: btn.wins.length > 0
                    Layout.maximumWidth: 360
                    elide: Text.ElideRight
                    text: btn.wins.length === 1 ? btn.wins[0].title : btn.wins.length + " windows"
                    font.pixelSize: Theme.fontCaption
                    font.weight: Font.Normal
                    color: Theme.textSecondary
                }
            }
        }
    }

    // ---- right-click menu ----
    PopupWindow {
        id: menu

        anchor.item: btn
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.margins.top: -8
        grabFocus: true
        implicitWidth: 220
        implicitHeight: menuCol.implicitHeight + 12
        color: "transparent"
        visible: false

        onVisibleChanged: Eva.menuOpen = visible

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusMedium
            color: Theme.glassStrong
            border.color: Theme.stroke
            border.width: 1

            ColumnLayout {
                id: menuCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                spacing: 2

                MenuRow {
                    visible: btn.entry !== null && btn.entry !== undefined
                    icon: "star"
                    text: Eva.isPinned(btn.modelData.id) ? "Unpin from taskbar" : "Pin to taskbar"
                    onClicked: { menu.visible = false; Eva.togglePin(btn.entry.id) }
                }
                MenuRow {
                    visible: btn.entry !== null && btn.entry !== undefined
                    icon: "apps"
                    text: "New window"
                    onClicked: { menu.visible = false; btn.launch() }
                }
                MenuRow {
                    visible: btn.running
                    icon: "power"
                    text: btn.wins.length > 1 ? "Close all windows" : "Close window"
                    onClicked: {
                        menu.visible = false
                        for (const w of btn.wins)
                            Eva.dispatch(`hl.dsp.window.close({ window = "${Eva.windowSelector(w)}" })`)
                    }
                }
            }
        }
    }

    component MenuRow: MouseArea {
        id: row

        property string icon
        property string text

        Layout.fillWidth: true
        implicitHeight: visible ? 34 : 0
        hoverEnabled: true

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall
            color: row.containsMouse ? Theme.hover : "transparent"
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 10
            Icon { name: row.icon; size: 15; color: Theme.textSecondary }
            Label { Layout.fillWidth: true; text: row.text; font.pixelSize: Theme.fontLabel }
        }
    }
}
