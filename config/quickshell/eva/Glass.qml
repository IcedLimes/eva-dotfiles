import QtQuick
import QtQuick.Effects

// Glass surface: translucent tint (Hyprland blurs what's behind it), a faint
// light edge, and a soft, large shadow for depth. Navigation surfaces only.
Item {
    id: root

    default property alias content: inner.data
    property color color: Theme.glassStrong
    property int radius: Theme.radiusLarge
    property bool shadow: true

    RectangularShadow {
        anchors.fill: base
        visible: root.shadow
        radius: root.radius
        blur: 28
        spread: 0
        offset: Qt.vector2d(0, 8)
        color: Theme.shadow
        cached: true
    }

    Rectangle {
        id: base
        anchors.fill: parent
        radius: root.radius
        color: root.color
        border.color: Theme.alpha(Theme.text, 0.4)   // a clear outline against the desktop
        border.width: 1.5
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
