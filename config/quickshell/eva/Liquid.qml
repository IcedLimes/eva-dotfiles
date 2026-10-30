import QtQuick

// Liquid glass (shaders/liquid.frag): a rounded box melted into what it grows
// out of, so the joins flare like a drop of water. Animate `box` to make it
// well up and spread. Ripples (Eva.ripple) are waves spreading from a point:
// a ring of light that also pushes the glass edge out as it passes. Every
// surface times the same ripple from the same start, so where the dock, the
// start menu and the screen's frame meet, their rings line up.
// Coordinates are this item's pixels. Hyprland blurs behind the glass (the
// layer's blur rule); the outline, shadow and ripple stay under its alpha cutoff.
ShaderEffect {
    id: liquid

    property rect box: Qt.rect(0, 0, 0, 0)
    property real radius: Theme.radiusLarge
    property rect anchor: Qt.rect(0, 0, 0, 0)     // width 0: free-standing
    property real anchorRadius: 0
    property real fillet: 18
    property rect anchor2: Qt.rect(0, 0, 0, 0)    // a second shape, e.g. the start menu
    property real anchor2Radius: 0
    property real fillet2: 18
    property rect frameRect: Qt.rect(0, 0, 0, 0)  // the screen frame's inside edge (Frame.qml); width 0: none
    property real frameRadius: 0
    property real frameFillet: 14
    property real clipTop: -100000                // no glass above this y
    property real insideOnly: 0                   // 1: glass only inside the frame
    property rect exclude: Qt.rect(0, 0, 0, 0)    // no glass here inside the frame
    property color glass: Theme.glass
    property color rimColor: Theme.alpha(Theme.text, 0.5)   // the outline: clear against the desktop
    property real rimWidth: 1.5
    property real shadow: 1

    property real rippleX: 0
    property real rippleY: 0
    property real rippleT: 0
    property real rippleStrength: 1
    property real rippleBulge: Eva.rippleBulge    // px it pushes the edge out

    // A wave from (x, y) in this item, timed from `start` (Date.now() when it
    // began, shared by every surface it runs through).
    function rippleAt(x, y, start) {
        rippleX = x
        rippleY = y
        rippleStart = start || Date.now()
        rippleT = 0.001
        rippleTick.restart()
    }

    // uniforms
    readonly property point px: Qt.point(width, height)
    readonly property vector4d tint: Qt.vector4d(glass.r, glass.g, glass.b, glass.a)
    readonly property vector4d edge: Qt.vector4d(rimColor.r, rimColor.g, rimColor.b, rimColor.a)
    readonly property vector4d ripple: Qt.vector4d(rippleX, rippleY, rippleT, rippleTick.running ? rippleStrength : 0)
    readonly property point rippleShape: Qt.point(Eva.rippleReach, rippleBulge)

    fragmentShader: Qt.resolvedUrl("shaders/liquid.frag.qsb")

    // 60 steps a second (not the display's 240), from the shared start
    property real rippleStart: 0
    Timer {
        id: rippleTick
        interval: 16
        repeat: true
        onTriggered: {
            liquid.rippleT = Math.max(0.001, Math.min(1, (Date.now() - liquid.rippleStart) / Eva.rippleDuration))
            if (liquid.rippleT >= 1) stop()
        }
    }
}
