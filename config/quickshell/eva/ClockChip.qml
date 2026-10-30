import QtQuick
import Quickshell

Chip {
    spacing: 8
    hoverEnabled: false

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Label {
        text: Qt.formatDateTime(clock.date, "ddd d MMM")
        font.pixelSize: Theme.fontLabel
        color: Theme.textSecondary
    }

    Label {
        text: Qt.formatDateTime(clock.date, "HH:mm")
        font.pixelSize: Theme.fontBody
        font.weight: Font.DemiBold
    }
}
