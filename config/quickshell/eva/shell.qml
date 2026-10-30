//@ pragma UseQApplication
// EVA bottom bar. Started by Hyprland: `quickshell -c eva`.
// Needs QApplication for system tray menus.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: root

    // Wallpaper (with parallax) on every screen, under everything.
    Variants {
        model: Quickshell.screens

        Wallpaper {
            required property var modelData
            screen: modelData
        }
    }

    // A thin glass frame around every screen; the dock grows out of it.
    Variants {
        model: Quickshell.screens

        Frame {
            required property var modelData
            screen: modelData
        }
    }

    // The night sky behind Unit-01 while the record sits in the moon.
    Stars { screen: Quickshell.screens[0] }

    // ASCII Rei turning beside the moon, like the "Fly Me to the Moon" end
    // credits (main screen). The moon is a dotted outline the vinyl record
    // (~/vinyl-visualizer) can be dropped into.
    Rei { id: rei; screen: Quickshell.screens[0] }
    Moon { screen: Quickshell.screens[0]; rei: rei }
    Hud { screen: Quickshell.screens[0] }

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }

    // Start menu, Alt+Tab switcher and volume/brightness pop-up appear on
    // whichever screen has focus.
    readonly property var focusedScreen: Quickshell.screens.find(s =>
        Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]

    Launcher { screen: focusedScreen }
    ControlCenter { screen: focusedScreen }
    WifiPopup { screen: focusedScreen }
    BluetoothPopup { screen: focusedScreen }
    Switcher { screen: focusedScreen }
    Osd { screen: focusedScreen }

    IpcHandler {
        target: "eva"

        // After the refresh rate changes (battery mode).
        function sync(): void {
            Hyprland.refreshMonitors()
        }

        // Tap SUPER / SUPER+Space.
        function menu(): void {
            Eva.toggleLauncher()
        }

        // Control Center (also: click the status chip).
        function control(): void { Eva.toggleControl() }
        function battery(): void { Eva.toggleControl() }

        // ALT+Tab / ALT+SHIFT+Tab, and Alt released.
        function switchNext(): void { Eva.switcherStep(1) }
        function switchPrev(): void { Eva.switcherStep(-1) }
        function switchCommit(): void { Eva.switcherCommit() }

        // Media / brightness keys: "volume", "mic" or "brightness".
        function osd(kind: string): void { Eva.showOsd(kind) }

        function nightLight(): void { Eva.setNightLight(!Eva.nightLight) }

        // From the vinyl record while it's dragged: grab, hover, leave,
        // release, dock, undock (see Moon.qml).
        function moon(event: string): void { Eva.moonEvent(event) }
    }

    Component.onCompleted: Hyprland.refreshMonitors()
}
