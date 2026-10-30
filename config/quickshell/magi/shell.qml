// MAGI vote: plays once at login (~3 s), then the process exits.
// Click or press any key to skip. Drawn like the desktop's MAGI console
// (eva/Hud.qml): monochrome hairlines, corner brackets, letter-spaced captions.

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

ShellRoot {
    PanelWindow {
        id: win

        property int step: 0
        readonly property color ink: Theme.textPrimary
        readonly property color ink2: Theme.textSecondary
        readonly property color ink3: Theme.textTertiary

        screen: Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "eva-magi"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"

        // 150 ms per step: panels appear (1-3), vote (6-8), verdict (10),
        // fade (18), exit (21).
        Timer {
            interval: 150
            running: true
            repeat: true
            onTriggered: {
                win.step++
                if (win.step >= 21) Qt.quit()
            }
        }

        Rectangle {
            id: stage
            anchors.fill: parent
            color: Theme.alpha(Theme.bg, 0.92)
            opacity: win.step >= 18 ? 0 : 1
            focus: true

            Behavior on opacity { NumberAnimation { duration: 420 } }

            Keys.onPressed: Qt.quit()

            MouseArea {
                anchors.fill: parent
                onClicked: Qt.quit()
            }

            // corner brackets around the whole screen
            Repeater {
                model: 4
                Item {
                    required property int index
                    readonly property bool atRight: index % 2 === 1
                    readonly property bool atBottom: index >= 2
                    x: atRight ? stage.width - 56 - width : 56
                    y: atBottom ? stage.height - 56 - height : 56
                    width: 28; height: 28
                    Rectangle { x: parent.atRight ? 27 : 0; width: 1; height: 28; color: win.ink3 }
                    Rectangle { y: parent.atBottom ? 27 : 0; width: 28; height: 1; color: win.ink3 }
                }
            }

            // 起動: start-up
            Column {
                x: 104; y: 96
                spacing: 10
                opacity: win.step >= 1 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 300 } }

                Text {
                    text: "起動"
                    color: win.ink
                    font.family: Theme.kanji
                    font.weight: Font.Bold
                    font.pixelSize: 104
                }
                Text {
                    text: "MAGI SYSTEM · USER SESSION"
                    color: win.ink2
                    font.family: Theme.mono
                    font.pixelSize: 17
                    font.letterSpacing: 6
                }
                Text {
                    text: "OPERATOR  " + (Quickshell.env("USER") || "UNKNOWN").toUpperCase()
                          + "      " + Qt.formatDateTime(new Date(), "yyyy.MM.dd  HH:mm")
                    color: win.ink3
                    font.family: Theme.mono
                    font.pixelSize: 14
                    font.letterSpacing: 4
                }
            }

            Item {
                id: board
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -30
                width: 1180
                height: 600

                // hub and the lines from each computer to it
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    opacity: win.step >= 3 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }

                    ShapePath {
                        strokeColor: win.ink3
                        strokeWidth: 1
                        fillColor: "transparent"
                        startX: board.width / 2; startY: balthasar.height
                        PathLine { x: board.width / 2; y: board.height / 2 - 34 }
                        PathMove { x: casper.width; y: board.height - casper.height / 2 }
                        PathLine { x: board.width / 2 - 92; y: board.height / 2 + 30 }
                        PathMove { x: board.width - melchior.width; y: board.height - melchior.height / 2 }
                        PathLine { x: board.width / 2 + 92; y: board.height / 2 + 30 }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: "MAGI"
                    color: win.ink2
                    font.family: Theme.mono
                    font.pixelSize: 30
                    font.letterSpacing: 14
                    opacity: win.step >= 3 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }

                MagiPanel {
                    id: balthasar
                    name: "BALTHASAR · 2"
                    x: (board.width - width) / 2
                    y: 0
                    shown: win.step >= 1
                    approved: win.step >= 7
                }
                MagiPanel {
                    id: casper
                    name: "CASPER · 3"
                    x: 0
                    y: board.height - height
                    shown: win.step >= 2
                    approved: win.step >= 8
                }
                MagiPanel {
                    id: melchior
                    name: "MELCHIOR · 1"
                    x: board.width - width
                    y: board.height - height
                    shown: win.step >= 3
                    approved: win.step >= 6
                }
            }

            // 可決: the motion is carried
            Column {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 96 }
                spacing: 14
                opacity: win.step >= 10 ? 1 : 0
                scale: win.step >= 10 ? 1 : 1.08
                Behavior on opacity { NumberAnimation { duration: 160 } }
                Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: verdict.implicitWidth + 96
                    height: verdict.implicitHeight + 16
                    color: "transparent"
                    border.color: win.ink
                    border.width: 1.5

                    Text {
                        id: verdict
                        anchors.centerIn: parent
                        text: "可決"
                        color: win.ink
                        font.family: Theme.kanji
                        font.weight: Font.Black
                        font.pixelSize: 104
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "RESOLUTION CARRIED · 3 / 3"
                    color: win.ink2
                    font.family: Theme.mono
                    font.pixelSize: 15
                    font.letterSpacing: 6
                }
            }
        }
    }
}
