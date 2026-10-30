import QtQuick

// Small text button for popups ("Disconnect", "Forget", "Settings…").
MouseArea {
    id: btn

    property string text

    implicitWidth: label.implicitWidth + 20
    implicitHeight: 28
    hoverEnabled: true

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: btn.pressed ? Theme.pressed : btn.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Theme.fill
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    Label {
        id: label
        anchors.centerIn: parent
        text: btn.text
        font.pixelSize: Theme.fontCaption
        font.weight: Font.DemiBold
    }
}
