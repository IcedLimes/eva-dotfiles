import QtQuick
import QtQuick.Layouts

// A row in a Wi-Fi / Bluetooth popup: icon, name, status line, and optional
// trailing controls (e.g. a Disconnect button). `active` marks the connected one.
MouseArea {
    id: row

    property string icon
    property string title
    property string subtitle
    property bool active: false
    property bool dimmed: false
    default property alias trailing: tail.data

    Layout.fillWidth: true
    implicitHeight: 48
    hoverEnabled: true

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMedium - 2
        color: row.active ? Theme.selection : row.pressed ? Theme.pressed : row.containsMouse ? Theme.hover : "transparent"
        border.color: row.active ? Theme.selectionStroke : "transparent"
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
        spacing: 10

        Icon {
            Layout.preferredWidth: 22
            name: row.icon
            size: 18
            color: row.active ? Theme.textPrimary : row.dimmed ? Theme.textTertiary : Theme.textSecondary
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Label {
                Layout.fillWidth: true
                text: row.title
                elide: Text.ElideRight
                font.pixelSize: Theme.fontLabel
                font.weight: row.active ? Font.DemiBold : Font.Medium
                color: row.dimmed ? Theme.textSecondary : Theme.textPrimary
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: row.subtitle
                elide: Text.ElideRight
                font.pixelSize: Theme.fontCaption
                font.weight: Font.Normal
                color: Theme.textSecondary
            }
        }

        RowLayout {
            id: tail
            spacing: 4
        }
    }
}
