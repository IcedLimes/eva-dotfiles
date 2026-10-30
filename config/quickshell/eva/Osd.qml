import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// Volume / brightness capsule shown by the media and brightness keys.
// Bottom-center, above the bar; fades out after 1.5 s.
PanelWindow {
    id: osd

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool isMic: Eva.osdKind === "mic"
    readonly property bool isBrightness: Eva.osdKind === "brightness"
    readonly property bool muted: isBrightness ? false
                                : isMic ? (source && source.audio ? source.audio.muted : false)
                                : (sink && sink.audio ? sink.audio.muted : false)
    readonly property real level: isBrightness ? Eva.osdBrightness / 100
                                : isMic ? (source && source.audio ? source.audio.volume : 0)
                                : (sink && sink.audio ? sink.audio.volume : 0)
    readonly property string iconName: isBrightness ? "brightness"
                                     : isMic ? (muted ? "micOff" : "mic")
                                     : muted || level === 0 ? "volMute" : level < 0.34 ? "volLow" : level < 0.67 ? "volMid" : "volHigh"

    property bool shown: false

    PwObjectTracker { objects: [osd.sink, osd.source] }

    Connections {
        target: Eva
        function onOsdShow() {
            osd.shown = true
            hide.restart()
        }
    }

    Timer {
        id: hide
        interval: 1500
        onTriggered: osd.shown = false
    }

    visible: shown || card.opacity > 0
    anchors.bottom: true
    margins.bottom: 80
    implicitWidth: 320 + 64
    implicitHeight: 52 + 64
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "eva-osd"
    mask: Region {}   // never takes input

    Glass {
        id: card

        anchors { fill: parent; margins: 32 }
        radius: height / 2
        opacity: osd.shown ? 1 : 0
        scale: osd.shown ? 1 : 0.96

        Behavior on opacity { NumberAnimation { duration: osd.shown ? Theme.durFast : Theme.durMedium } }
        Behavior on scale { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecel } }

        RowLayout {
            anchors { fill: parent; leftMargin: 20; rightMargin: 20 }
            spacing: 14

            Icon {
                name: osd.iconName
                size: 20
                color: osd.muted ? Theme.textTertiary : Theme.textPrimary
            }

            Rectangle {
                Layout.fillWidth: true
                height: 6
                radius: 3
                color: Theme.fill

                Rectangle {
                    width: osd.muted ? 0 : Math.max(height, parent.width * Math.min(1, osd.level))
                    height: parent.height
                    radius: 3
                    color: Theme.textPrimary
                    Behavior on width { NumberAnimation { duration: Theme.durFast } }
                }
            }

            Label {
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
                text: osd.muted ? "Off" : Math.round(osd.level * 100)
                font.pixelSize: Theme.fontLabel
                color: Theme.textSecondary
            }
        }
    }
}
