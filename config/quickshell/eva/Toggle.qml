import QtQuick

// On/off switch.
MouseArea {
    id: sw

    property bool checked: false
    signal toggled()

    implicitWidth: 40
    implicitHeight: 22
    hoverEnabled: true
    onClicked: toggled()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? Theme.primary : Theme.fill
        border.color: sw.checked ? "transparent" : Theme.strokeStrong
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.durFast } }

        Rectangle {
            width: parent.height - 6
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: sw.checked ? parent.width - width - 3 : 3
            color: sw.checked ? Theme.onPrimary : Theme.textSecondary
            Behavior on x { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
        }
    }
}
