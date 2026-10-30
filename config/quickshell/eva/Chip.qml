import QtQuick
import QtQuick.Layouts

// Rounded, hoverable control used across the bar and popups.
// `selected` shows an accent tint with a soft accent edge.
MouseArea {
    id: chip

    default property alias items: row.data
    property bool selected: false
    property color tint: "transparent"
    property int radius: Theme.radiusMedium - 2
    property int padding: Theme.s3
    property alias spacing: row.spacing

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: 36
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    Rectangle {
        anchors.fill: parent
        radius: chip.radius
        color: chip.selected ? Theme.selection
             : chip.tint.a > 0 ? chip.tint
             : chip.pressed ? Theme.pressed
             : chip.containsMouse ? Theme.hover : "transparent"
        border.color: chip.selected ? Theme.selectionStroke : "transparent"
        border.width: 1

        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Theme.s2
    }
}
