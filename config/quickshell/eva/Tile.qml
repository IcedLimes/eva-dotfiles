import QtQuick
import QtQuick.Layouts

// Control Center toggle tile: round icon badge (accent when on), title and
// a status line.
MouseArea {
    id: tile

    property string icon
    property string title
    property string subtitle
    property bool on: false

    Layout.fillWidth: true
    implicitHeight: 58
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMedium
        color: tile.pressed ? Theme.pressed : tile.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Theme.fill
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            radius: 17
            color: tile.on ? Theme.primary : Qt.rgba(1, 1, 1, 0.10)
            Behavior on color { ColorAnimation { duration: Theme.durMedium } }

            Icon {
                anchors.centerIn: parent
                name: tile.icon
                size: 17
                color: tile.on ? Theme.onPrimary : Theme.textPrimary
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Label {
                Layout.fillWidth: true
                text: tile.title
                font.pixelSize: Theme.fontLabel
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                text: tile.subtitle
                font.pixelSize: Theme.fontCaption
                font.weight: Font.Normal
                color: Theme.textSecondary
                elide: Text.ElideRight
            }
        }
    }
}
