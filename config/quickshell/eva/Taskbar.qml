import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

// Taskbar like Plasma's icon task manager: pinned apps first (imported from
// Plasma by eva-import-pins; right-click to pin/unpin), then other running
// apps. One button per app; windows on this workspace plus minimized ones.
RowLayout {
    id: root

    property HyprlandWorkspace current

    Layout.fillHeight: true
    spacing: 2

    // Window IDs that don't match their app's desktop file name.
    readonly property var aliases: ({
        "kdesystemsettings": "systemsettings",
        "org.kde.systemsettings": "systemsettings"
    })

    function isMin(t) { return t.workspace !== null && t.workspace.name === "special:minimized" }
    function appIdOf(t) { return t.wayland ? t.wayland.appId : (t.lastIpcObject["class"] ?? "") }

    function entryFor(appId) {
        if (appId === "") return null
        return DesktopEntries.byId(aliases[appId] ?? appId) ?? DesktopEntries.heuristicLookup(appId)
    }

    readonly property var groups: {
        const ready = DesktopEntries.applications.values.length > 0   // recompute once apps load
        const out = []

        for (const pid of Eva.pinned) {
            const e = ready ? DesktopEntries.byId(pid) : null
            if (e) out.push({ id: e.id, entry: e, pinned: true, windows: [], appId: pid })
        }

        for (const t of Hyprland.toplevels.values) {
            const ws = t.workspace
            if (ws === null) continue
            const here = root.current !== null && ws.id === root.current.id
            if (!here && !isMin(t)) continue

            const appId = appIdOf(t)
            const e = ready ? entryFor(appId) : null
            const id = e ? e.id : "window:" + appId
            let g = out.find(x => x.id === id)
            if (!g) {
                g = { id: id, entry: e, pinned: false, windows: [], appId: appId }
                out.push(g)
            }
            g.windows.push(t)
        }
        return out
    }

    Repeater {
        model: root.groups
        TaskButton {}
    }

    Item { Layout.fillWidth: true }
}
