import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Popup above the bar for a status icon (Wi-Fi, Bluetooth), like Plasma's
// tray popups: a glass card with a title, an on/off switch and a list.
// Click outside or press Esc to close.
PanelWindow {
    id: popup

    required property string name   // the Eva.trayPopup value that opens it
    property string title
    property bool switchOn: false
    property bool switchVisible: true
    signal switchToggled()
    default property alias content: body.data
    property int cardWidth: 360

    // Extra room around the card so its shadow isn't clipped.
    readonly property int roomTop: 28
    readonly property int roomSide: 28
    readonly property int roomBottom: 36

    visible: Eva.trayPopup === name
    // above the dock's right end, where its status icons are (Bar.qml)
    readonly property var dock: Eva.docks[screen ? screen.name : ""] ?? null
    anchors { right: true; bottom: true }
    margins {
        right: dock && screen ? Math.max(0, Math.round(screen.width - dock.right) - 10) : 0
        bottom: (dock ? dock.height + dock.bottomGap + 12 : 74) - roomBottom
    }
    implicitWidth: roomSide + cardWidth + 10
    implicitHeight: roomTop + column.implicitHeight + 32 + roomBottom
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "eva-control"   // same glass blur as the Control Center
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    mask: Region { item: card }

    onVisibleChanged: {
        if (visible) {
            openAnim.restart()
            keys.forceActiveFocus()
        }
    }

    HyprlandFocusGrab {
        windows: [popup].concat(Eva.barWindows)
        active: popup.visible
        // Only close if still ours: clicking another popup's icon switches to it.
        onCleared: if (Eva.trayPopup === popup.name) Eva.closeTrayPopup()
    }

    Glass {
        id: card

        anchors { right: parent.right; bottom: parent.bottom; rightMargin: 10; bottomMargin: popup.roomBottom }
        width: popup.cardWidth
        height: column.implicitHeight + 32

        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: card; property: "anchors.bottomMargin"; from: popup.roomBottom - 12; to: popup.roomBottom; duration: Theme.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecel }
            NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: Theme.durMedium }
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Eva.closeTrayPopup()
        }

        ColumnLayout {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.s4 }
            spacing: Theme.s3

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4

                Label {
                    Layout.fillWidth: true
                    text: popup.title
                    font.pixelSize: Theme.fontTitle
                    font.weight: Font.DemiBold
                }
                Toggle {
                    visible: popup.switchVisible
                    checked: popup.switchOn
                    onToggled: popup.switchToggled()
                }
            }

            ColumnLayout {
                id: body
                Layout.fillWidth: true
                spacing: 2
            }
        }
    }
}
