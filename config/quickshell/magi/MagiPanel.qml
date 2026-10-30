import QtQuick
import QtQuick.Shapes

// One MAGI computer: a chamfered outline with its name, deliberating (審議中)
// until it votes, then lit white with 承認 (approved). Drawn like the desktop's
// MAGI console (eva/Hud.qml): hairlines, letter-spaced mono captions.
Item {
    id: root

    property string name
    property bool shown: false
    property bool approved: false

    readonly property color ink: Theme.textPrimary
    readonly property real cut: 28

    width: 460
    height: 210
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.96

    Behavior on opacity { NumberAnimation { duration: 220 } }
    Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.approved ? root.ink : Theme.textTertiary
            strokeWidth: 1.5
            fillColor: root.approved ? Theme.alpha(root.ink, 0.92) : Theme.alpha(root.ink, 0.04)
            Behavior on fillColor { ColorAnimation { duration: 140 } }
            Behavior on strokeColor { ColorAnimation { duration: 140 } }

            startX: root.cut; startY: 0
            PathLine { x: root.width - root.cut; y: 0 }
            PathLine { x: root.width; y: root.cut }
            PathLine { x: root.width; y: root.height - root.cut }
            PathLine { x: root.width - root.cut; y: root.height }
            PathLine { x: root.cut; y: root.height }
            PathLine { x: 0; y: root.height - root.cut }
            PathLine { x: 0; y: root.cut }
            PathLine { x: root.cut; y: 0 }
        }
    }

    Text {
        x: 34; y: 26
        text: root.name
        color: root.approved ? Theme.bg : Theme.textSecondary
        font.family: Theme.mono
        font.pixelSize: 17
        font.letterSpacing: 5
    }

    Text {
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: 38; bottomMargin: 18 }
        text: root.approved ? "承認" : "審議中"
        color: root.approved ? Theme.bg : Theme.textTertiary
        font.family: Theme.kanji
        font.weight: root.approved ? Font.Black : Font.Normal
        font.pixelSize: root.approved ? 76 : 48
    }
}
