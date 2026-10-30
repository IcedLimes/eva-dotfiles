pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Shared state and helpers for the bar, start menu and popups.
Singleton {
    id: root

    // Anything that should keep the bar from sliding away while it is open.
    property bool menuOpen: false      // tray menu
    property bool controlOpen: false   // Control Center
    property bool launcherOpen: false  // start menu
    property string trayPopup: ""      // "wifi" or "bluetooth" popup
    readonly property bool holdBar: menuOpen || controlOpen || launcherOpen || trayPopup !== ""

    // ---- Control Center ----

    property real controlClosedAt: 0

    function toggleControl() {
        if (!controlOpen && Date.now() - controlClosedAt < 250)
            return
        closeTrayPopup()
        controlOpen = !controlOpen
    }

    function closeControl() {
        if (controlOpen) {
            controlOpen = false
            controlClosedAt = Date.now()
        }
    }

    // ---- Wi-Fi / Bluetooth popups (click their icons on the bar) ----

    // Bar windows (one per screen). The popups' focus grabs include them, so
    // clicking another icon on the bar switches popups instead of only
    // closing the open one.
    property var barWindows: []
    // Where each screen's dock sits (Bar.qml), by screen name: left, right,
    // top (screen px), height, startX (the start button's middle), startW.
    // The start menu grows out of it; the popups line up with its right end.
    property var docks: ({})
    // The start menu's glass on screen while it shows (Launcher.qml): screen,
    // x, y, w, h, r. The dock draws its side of the join from it.
    property var launcherBox: null

    // The glass frame around each screen (Frame.qml): as wide as Hyprland's
    // gap around maximized windows, so no wallpaper shows past them.
    readonly property int frameWidth: 12
    readonly property int frameRadius: 14             // Hyprland's window rounding

    // Something popped up or down at (x, y) (screen px, from Date.now() =
    // start): a wave spreads from there through every liquid surface on that
    // screen (the dock, the start menu, the frame), all lined up.
    signal ripple(string screenName, real x, real y, real start)
    readonly property real rippleReach: 460           // px it spreads
    readonly property int rippleDuration: 1600        // ms
    readonly property real rippleBulge: 12            // px it pushes the glass edge out
    function rippleFrom(screen, x, y) {
        if (screen) ripple(screen.name, x, y, Date.now())
    }
    // The dock's glass while it's out (Bar.qml), by screen name: x, y, w, h,
    // r, fillet (screen px); the frame melts into it.
    property var dockGlass: ({})

    property string trayPopupClosed: ""
    property real trayPopupClosedAt: 0

    function toggleTrayPopup(name) {
        if (trayPopup === name) { closeTrayPopup(); return }
        // Clicking the icon of the open popup first closes it via the focus
        // grab; don't reopen it on the same click.
        if (trayPopupClosed === name && Date.now() - trayPopupClosedAt < 250)
            return
        closeControl()
        trayPopup = name
    }

    function closeTrayPopup() {
        if (trayPopup !== "") {
            trayPopupClosed = trayPopup
            trayPopupClosedAt = Date.now()
            trayPopup = ""
        }
    }

    // Do not disturb: a mako mode that hides notifications.
    property bool dnd: false

    function toggleDnd() {
        dnd = !dnd
        run("makoctl mode " + (dnd ? "-a" : "-r") + " do-not-disturb")
    }

    // Screen brightness (0..100) for the Control Center slider.
    property int brightness: 50
    property int pendingBrightness: -1

    function readBrightness() { brightnessReader.running = true }

    function setBrightness(v) {
        brightness = v
        pendingBrightness = v
        if (!brightnessWriter.running) brightnessWriter.flush()
    }

    Process {
        id: brightnessWriter
        function flush() {
            if (root.pendingBrightness < 0) return
            command = ["brightnessctl", "-q", "set", root.pendingBrightness + "%"]
            root.pendingBrightness = -1
            running = true
        }
        onExited: flush()   // coalesce drags into one write at a time
    }

    // ---- start menu ----

    property real launcherClosedAt: 0

    function toggleLauncher() {
        // A click on the start button first dismisses the menu via the focus
        // grab; don't immediately reopen it on the same click.
        if (!launcherOpen && Date.now() - launcherClosedAt < 250)
            return
        closeTrayPopup()
        closeControl()
        launcherOpen = !launcherOpen
    }

    function closeLauncher() {
        if (launcherOpen) {
            launcherOpen = false
            launcherClosedAt = Date.now()
        }
    }

    // ---- favorites (right-click an app in the start menu) ----

    readonly property var defaultFavorites: [
        "firefox", "org.kde.konsole", "org.kde.dolphin", "systemsettings",
        "spotify", "org.kde.kate", "steam", "org.kde.spectacle"
    ]
    property var favorites: defaultFavorites

    function isFavorite(id) { return favorites.indexOf(id) !== -1 }

    function toggleFavorite(id) {
        const list = favorites.slice()
        const i = list.indexOf(id)
        if (i === -1) list.push(id)
        else list.splice(i, 1)
        favorites = list
        favoritesFile.setText(JSON.stringify(list, null, 2) + "\n")
    }

    FileView {
        id: favoritesFile
        path: Quickshell.env("HOME") + "/.config/eva/favorites.json"
        printErrors: false
        onLoaded: {
            try {
                const list = JSON.parse(text())
                if (Array.isArray(list)) root.favorites = list
            } catch (e) {
                console.warn("eva: bad favorites.json:", e)
            }
        }
    }

    // ---- pinned taskbar apps (imported from Plasma by eva-import-pins) ----

    property var pinned: []

    function isPinned(id) { return pinned.indexOf(id) !== -1 }

    function togglePin(id) {
        const list = pinned.slice()
        const i = list.indexOf(id)
        if (i === -1) list.push(id)
        else list.splice(i, 1)
        pinned = list
        pinnedFile.setText(JSON.stringify(list, null, 2) + "\n")
    }

    FileView {
        id: pinnedFile
        path: Quickshell.env("HOME") + "/.config/eva/pinned.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const list = JSON.parse(text())
                if (Array.isArray(list)) root.pinned = list
            } catch (e) {
                console.warn("eva: bad pinned.json:", e)
            }
        }
    }

    // ---- keep awake (Control Center tile) ----

    // A logind inhibitor: hypridle honors the idle lock (no dim, lock, screen
    // off or idle suspend) and the sleep lock stops other automatic suspends.
    // Closing the lid still suspends: logind ignores these locks for the lid
    // (LidSwitchIgnoreInhibited), which is what we want when traveling.
    // Released as soon as the toggle is turned off.
    property bool sleepBlocked: false

    function setSleepBlocked(on) {
        sleepBlocked = on
        keepAwakeFile.setText(on ? "1\n" : "0\n")
    }

    Process {
        running: root.sleepBlocked
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=EVA",
                  "--why=Keep awake (Control Center)", "--mode=block", "sleep", "infinity"]
    }

    // Survives bar reloads; cleared at logout with the runtime dir, like Plasma.
    FileView {
        id: keepAwakeFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/eva-keep-awake"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.sleepBlocked = text().trim() === "1"
    }

    // ---- Alt+Tab: windows in most-recently-used order ----

    property var mru: []   // window addresses, most recent first

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            const t = Hyprland.activeToplevel
            if (!t) return
            const a = String(t.address)
            root.mru = [a].concat(root.mru.filter(x => x !== a)).slice(0, 64)
        }
    }

    // Seed focus history (lastIpcObject.focusHistoryID) for the switcher.
    Component.onCompleted: Hyprland.refreshToplevels()

    signal moonEvent(string event)   // the vinyl record and the moon (Moon.qml)

    // Desktop parallax. The wallpaper eases toward the cursor and publishes how
    // far it has drifted, -1..1 of its reach; Rei follows (Wallpaper.qml,
    // Rei.qml). Decorations above the wallpaper report the cursor through
    // parallaxPoint (screen pixels), so it keeps moving while you hover them.
    property real parallaxX: 0
    property real parallaxY: 0
    signal parallaxPoint(real x, real y)
    // The vinyl record sitting in the moon (Rei.qml knows) and where the moon
    // is, {x, y, r} in screen px (Moon.qml): the wallpaper follows the cursor
    // over the record too.
    property bool recordInMoon: false
    property var moonArea: null
    property bool moonOutline: false   // the outline is showing: the record's being dragged

    signal switcherStep(int delta)   // ALT+Tab / ALT+SHIFT+Tab
    signal switcherCommit()          // Alt released
    property bool switcherOpen: false

    // ---- on-screen display for volume / brightness keys ----

    property string osdKind: ""      // "volume", "mic", "brightness"
    property int osdBrightness: 0
    signal osdShow()
    property bool osdPending: false

    Process {
        id: brightnessReader
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                // amdgpu_bl0,backlight,123,48%,255
                const m = text.match(/,(\d+)%/)
                if (m) {
                    root.osdBrightness = parseInt(m[1])
                    root.brightness = root.osdBrightness
                }
                if (root.osdPending) {
                    root.osdPending = false
                    root.osdShow()
                }
            }
        }
    }

    function showOsd(kind) {
        osdKind = kind
        if (kind === "brightness") {
            osdPending = true
            brightnessReader.running = true
        } else {
            osdShow()
        }
    }

    // ---- night light (hyprsunset), mirrors Plasma's Night Light ----

    property bool nightLight: true
    property int nightTemperature: 2600

    function setNightLight(on) {
        nightLight = on
        saveSettings()
    }

    Process {
        running: root.nightLight
        command: ["hyprsunset", "-t", String(root.nightTemperature)]
    }

    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/eva/settings.json"
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text())
                if (typeof s.nightLight === "boolean") root.nightLight = s.nightLight
                if (typeof s.nightTemperature === "number") root.nightTemperature = s.nightTemperature
            } catch (e) {
                console.warn("eva: bad settings.json:", e)
            }
        }
    }

    function saveSettings() {
        settingsFile.setText(JSON.stringify({
            nightLight: nightLight,
            nightTemperature: nightTemperature
        }, null, 2) + "\n")
    }

    // ---- helpers ----

    function run(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd])
    }

    // Hyprland 0.56 takes Lua dispatchers, e.g. 'hl.dsp.focus({ workspace = 2 })'.
    function dispatch(lua) {
        Hyprland.dispatch(lua)
    }

    // Restore if minimized, focus and raise, in order, in one call (see
    // eva.activate in hyprland.lua). Separate dispatches can arrive out of
    // order, which raised the previously focused window instead.
    function activateWindow(toplevel) {
        run(`hyprctl eval "eva.activate('${addressOf(toplevel)}')"`)
    }

    function minimizeWindow(toplevel) {
        run(`hyprctl eval "eva.minimize('${addressOf(toplevel)}')"`)
    }

    function addressOf(toplevel) {
        const a = String(toplevel.address)
        return a.startsWith("0x") ? a : "0x" + a
    }

    function windowSelector(toplevel) {
        const a = String(toplevel.address)
        return "address:" + (a.startsWith("0x") ? a : "0x" + a)
    }
}
