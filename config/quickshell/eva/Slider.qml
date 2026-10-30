import QtQuick

// Continuous slider: rounded track, accent fill, round knob. value: 0..1
Item {
    id: root

    property real value: 0
    signal moved(real value)

    implicitHeight: 22
    implicitWidth: 200

    function setFrom(x) {
        const v = Math.max(0, Math.min(1, (x - 8) / (width - 16)))
        root.moved(v)
    }

    Rectangle {
        id: track
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8 }
        height: 6
        radius: 3
        color: Theme.fill

        Rectangle {
            width: Math.max(height, parent.width * Math.max(0, Math.min(1, root.value)))
            height: parent.height
            radius: 3
            color: Theme.active
        }
    }

    Rectangle {
        width: 16
        height: 16
        radius: 8
        anchors.verticalCenter: parent.verticalCenter
        x: 8 + track.width * Math.max(0, Math.min(1, root.value)) - width / 2
        color: Theme.textPrimary
        border.color: Qt.rgba(0, 0, 0, 0.25)
        border.width: 1
        scale: drag.pressed ? 1.15 : drag.containsMouse ? 1.06 : 1
        Behavior on scale { NumberAnimation { duration: Theme.durFast } }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        hoverEnabled: true
        onPressed: mouse => root.setFrom(mouse.x)
        onPositionChanged: mouse => { if (pressed) root.setFrom(mouse.x) }
        onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
