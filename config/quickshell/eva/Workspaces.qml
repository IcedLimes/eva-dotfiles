import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

// Workspace pills: the current one stretches into an accent capsule.
Chip {
    id: root

    property HyprlandWorkspace current
    readonly property var list: Hyprland.workspaces.values.filter(w => w.id > 0).sort((a, b) => a.id - b.id)

    padding: Theme.s3
    spacing: 6
    hoverEnabled: false
    onWheel: wheel => Eva.dispatch(`hl.dsp.focus({ workspace = "${wheel.angleDelta.y > 0 ? "e-1" : "e+1"}" })`)

    Repeater {
        model: root.list

        MouseArea {
            id: pill

            required property HyprlandWorkspace modelData
            readonly property bool isCurrent: root.current !== null && modelData.id === root.current.id

            implicitWidth: isCurrent ? 22 : 8
            implicitHeight: 8
            hoverEnabled: true
            onClicked: modelData.activate()

            Behavior on implicitWidth { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecel } }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: pill.isCurrent ? Theme.active
                     : pill.containsMouse ? Theme.textSecondary : Theme.textTertiary
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
            }
        }
    }
}
