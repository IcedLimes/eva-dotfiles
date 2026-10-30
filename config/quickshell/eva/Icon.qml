import QtQuick

// A Nerd Font glyph by name, e.g. Icon { name: "wifi4" }.
Text {
    property string name
    property int size: 18

    text: Theme.icon(name)
    color: Theme.textPrimary
    font.family: Theme.iconFont
    font.pixelSize: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
