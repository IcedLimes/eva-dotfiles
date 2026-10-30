import QtQuick
import Quickshell
import Quickshell.Wayland

// The night sky behind Unit-01 while the vinyl record sits in the moon: one
// star comes out, then a few, then hundreds. Drawn just above the wallpaper
// and moving with it; only over the black sky, so Unit-01 stands in front of
// it. Stars: ~/.config/eva/stars.png, baked by ~/.config/eva/tools/make-stars.py
// (where they sit and when each comes out). Shader: shaders/stars.frag.
// It redraws only while the stars come out or fade (and with the wallpaper's
// parallax), so a still sky costs nothing. (Shooting stars were tried: on this
// iGPU every frame of motion costs Hyprland a full pass, so smooth ones cost
// ~14% of it while falling and cheap ones were choppy.)
// Unmapped while the record is out of the moon.
PanelWindow {
    id: sky

    readonly property int margin: 24      // the wallpaper's overhang (Wallpaper.qml)
    readonly property real reach: 20      // and how far it drifts
    readonly property real span: 4.6      // make-stars.py: SPAN
    readonly property real allOut: 5.2    // s after docking: the last star is fully out

    property bool shown: false    // mapped
    property real shownAt: 0      // Date.now() when the record docked
    property real goneAt: 0       // and when it left
    property real clock: 0        // s since it docked
    property real fade: 0

    anchors { left: true; right: true; top: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background   // mapped after the wallpaper, so just above it
    WlrLayershell.namespace: "eva-stars"
    mask: Region {}
    visible: shown

    Connections {
        target: Eva
        function onRecordInMoonChanged() { sky.follow() }
    }
    Component.onCompleted: follow()

    function follow() {
        const now = Date.now()
        if (Eva.recordInMoon) {
            // a fresh sky each time (or pick up where a fade-out left it)
            if (!shown) shownAt = now
            fade = 1
            shown = true
        } else {
            if (!shown) return
            goneAt = now
        }
        tick.restart()
    }

    function step() {
        const now = Date.now()
        clock = (now - shownAt) / 1000
        if (!Eva.recordInMoon) {
            fade = Math.max(0, 1 - (now - goneAt) / 900)
            if (fade === 0) {
                shown = false
                tick.stop()
            }
        } else if (clock > allOut) {
            tick.stop()   // all out: hold still
        }
    }

    // ~30 updates a second while the stars come out or fade (never the
    // display's 240).
    Timer {
        id: tick
        repeat: true
        interval: 33
        onTriggered: sky.step()
    }

    Image {
        id: starMap
        source: sky.visible ? "file://" + Quickshell.env("HOME") + "/.config/eva/stars.png" : ""
        visible: false
        smooth: false       // one texel per pixel: R, G, A are data
        cache: false
        asynchronous: true
    }

    ShaderEffect {
        x: -sky.margin + Eva.parallaxX * sky.reach
        y: -sky.margin + Eva.parallaxY * sky.reach
        width: sky.width + 2 * sky.margin
        height: sky.height + 2 * sky.margin
        visible: starMap.status === Image.Ready

        property variant field: starMap
        property real clock: Math.min(sky.clock, sky.allOut)
        property real span: sky.span
        property real fade: sky.fade

        fragmentShader: Qt.resolvedUrl("shaders/stars.frag.qsb")
    }
}
