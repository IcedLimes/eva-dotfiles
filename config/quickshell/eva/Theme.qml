pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Design tokens. Colors come from ~/.config/eva/current/theme.json (written
// by eva-theme, watched for live theme switches); everything else follows a
// macOS / Liquid Glass-style system: Inter, an 8pt grid, continuous corners,
// glass only on navigation surfaces, accent used sparingly.
Singleton {
    id: root

    property var t: ({
        name: "crimson", label: "CRIMSON", unit: "暴走",
        bg: "#121010", surface: "#1c1616", surface2: "#2a1313", line: "#4b1616",
        primary: "#b5393a", border: "#9c4a47", active: "#e04a42", glow: "#f4d58d",
        warn: "#e0913a", crit: "#ff4d3d", text: "#e8ddd0", dim: "#7d6b68"
    })

    // ---- palette ----
    readonly property color bg: t.bg
    readonly property color surface: t.surface
    readonly property color surface2: t.surface2
    readonly property color line: t.line
    readonly property color primary: t.primary
    readonly property color border: t.border ?? t.primary
    readonly property color active: t.active
    readonly property color glow: t.glow
    readonly property color warn: t.warn
    readonly property color crit: t.crit
    readonly property color text: t.text
    readonly property color dim: t.dim
    readonly property string unit: t.unit
    readonly property string label: t.label

    // Text hierarchy (primary / secondary / tertiary), like system labels.
    readonly property color textPrimary: text
    readonly property color textSecondary: alpha(text, 0.68)
    readonly property color textTertiary: alpha(text, 0.42)

    // Glass and overlays.
    readonly property color glass: alpha(bg, 0.62)         // bar
    readonly property color glassStrong: alpha(bg, 0.80)   // menus, popups
    readonly property color stroke: Qt.rgba(1, 1, 1, 0.09) // light edge on glass
    readonly property color strokeStrong: Qt.rgba(1, 1, 1, 0.16)
    readonly property color hover: Qt.rgba(1, 1, 1, 0.06)
    readonly property color pressed: Qt.rgba(1, 1, 1, 0.10)
    readonly property color fill: Qt.rgba(1, 1, 1, 0.07)   // inactive controls, tracks
    readonly property color selection: alpha(primary, 0.20)
    // Text and icons drawn on the accent: dark on a light accent (MONO).
    readonly property color onPrimary: 0.2126 * primary.r + 0.7152 * primary.g + 0.0722 * primary.b > 0.6 ? bg : "#ffffff"
    readonly property color selectionStroke: alpha(primary, 0.45)
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.45)

    // ---- type ----
    readonly property string font: "Inter"
    readonly property string mono: "JetBrains Mono"
    readonly property string iconFont: "Symbols Nerd Font"
    readonly property string kanji: "Noto Serif CJK JP"
    readonly property string digits: "DSEG7 Classic"
    readonly property string logoFont: "nerv"
    readonly property string logo: ""

    readonly property int fontCaption: 12
    readonly property int fontLabel: 13
    readonly property int fontBody: 14
    readonly property int fontTitle: 15
    readonly property int fontLarge: 20
    readonly property int fontDisplay: 26

    // ---- shape (continuous corners; inner = outer - padding) ----
    readonly property int radiusSmall: 8
    readonly property int radiusMedium: 12
    readonly property int radiusLarge: 18

    // ---- spacing (8pt grid) ----
    readonly property int s1: 4
    readonly property int s2: 8
    readonly property int s3: 12
    readonly property int s4: 16
    readonly property int s5: 24
    readonly property int s6: 32

    // ---- motion ----
    readonly property int durFast: 150
    readonly property int durMedium: 250
    readonly property int durSlow: 350
    readonly property var emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var standard: [0.2, 0, 0, 1, 1, 1]

    // ---- icons (Nerd Font Material Design glyphs) ----
    readonly property var glyphs: ({
        search: 0xF0349, apps: 0xF003B, star: 0xF04CE, cog: 0xF0493,
        lock: 0xF033E, sleep: 0xF0904, logout: 0xF0343, restart: 0xF0709, power: 0xF0425,
        wifi0: 0xF092F, wifi1: 0xF091F, wifi2: 0xF0922, wifi3: 0xF0925, wifi4: 0xF0928,
        wifiOff: 0xF092D, ethernet: 0xF0200,
        volHigh: 0xF057E, volMid: 0xF0580, volLow: 0xF057F, volMute: 0xF0581,
        mic: 0xF036C, micOff: 0xF036D,
        brightness: 0xF00E0, night: 0xF0594, coffee: 0xF0176, bellOff: 0xF009B, bell: 0xF009A,
        leaf: 0xF032A, gauge: 0xF029A, rocket: 0xF0463, palette: 0xF03D8, lowPower: 0xF0F86,
        charging: 0xF0084, plug: 0xF06A5,
        bat10: 0xF007A, bat20: 0xF007B, bat30: 0xF007C, bat40: 0xF007D, bat50: 0xF007E,
        bat60: 0xF007F, bat70: 0xF0080, bat80: 0xF0081, bat90: 0xF0082, bat100: 0xF0079,
        code: 0xF0169, game: 0xF0297, web: 0xF059F, music: 0xF075A, doc: 0xF0219,
        flask: 0xF0668, monitor: 0xF0379, wrench: 0xF05B7, chevronRight: 0xF0142,
        bluetooth: 0xF00AF, btConnected: 0xF00B1, btOff: 0xF00B2, headphones: 0xF02CB,
        speaker: 0xF04C3, phone: 0xF011C, keyboard: 0xF030C, mouse: 0xF037D, gamepad: 0xF0296,
        devices: 0xF0FB0, check: 0xF012C, close: 0xF0156, refresh: 0xF0450
    })

    function icon(name) { return String.fromCodePoint(glyphs[name] ?? 0x3F) }

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    FileView {
        path: Quickshell.env("HOME") + "/.config/eva/current/theme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.t = JSON.parse(text())
            } catch (e) {
                console.warn("eva: bad theme.json:", e)
            }
        }
    }
}
