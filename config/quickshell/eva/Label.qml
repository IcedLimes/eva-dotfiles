import QtQuick

// Body text in Inter. Use size/weight for hierarchy, sentence case.
Text {
    color: Theme.textPrimary
    font.family: Theme.font
    font.pixelSize: Theme.fontBody
    font.weight: Font.Medium
    font.features: { "tnum": 1 }   // tabular numbers, so values don't jitter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
