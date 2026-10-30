import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

// Start menu (tap SUPER or click the NERV button): search, categories,
// favorites grid or app list, power actions. Bottom-left, above the bar.
PanelWindow {
    id: menu

    // ---- data ----

    readonly property var categories: [
        { id: "favorites",   label: "Favorites",   icon: "star",    match: [] },
        { id: "all",         label: "All apps",    icon: "apps",    match: [] },
        { id: "development", label: "Development", icon: "code",    match: ["Development"] },
        { id: "games",       label: "Games",       icon: "game",    match: ["Game"] },
        { id: "graphics",    label: "Graphics",    icon: "palette", match: ["Graphics"] },
        { id: "internet",    label: "Internet",    icon: "web",     match: ["Network", "WebBrowser", "Email", "Chat"] },
        { id: "multimedia",  label: "Multimedia",  icon: "music",   match: ["AudioVideo", "Audio", "Video"] },
        { id: "office",      label: "Office",      icon: "doc",     match: ["Office"] },
        { id: "science",     label: "Science",     icon: "flask",   match: ["Science", "Education"] },
        { id: "settings",    label: "Settings",    icon: "cog",     match: ["Settings"] },
        { id: "system",      label: "System",      icon: "monitor", match: ["System"] },
        { id: "utilities",   label: "Utilities",   icon: "wrench",  match: ["Utility"] }
    ]

    readonly property var apps: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    property string category: "favorites"
    property string query: ""
    property int selected: 0
    property string armed: ""

    function inCategory(entry, cat) {
        const cats = entry.categories || []
        return cat.match.some(m => cats.indexOf(m) !== -1)
    }

    readonly property var visibleCategories: categories.filter(c =>
        c.match.length === 0 || apps.some(e => inCategory(e, c)))

    // Depends on `apps` so it recomputes once the app database has loaded
    // (byId() alone isn't reactive).
    readonly property var favoriteApps: {
        const loaded = apps.length
        return Eva.favorites
            .map(id => loaded ? DesktopEntries.byId(id) : null)
            .filter(e => e !== null && e !== undefined)
    }

    function matches(e, q) {
        const hay = [e.name, e.genericName, e.comment, e.id].concat(e.keywords || []).join(" ").toLowerCase()
        return q.split(/\s+/).every(w => hay.indexOf(w) !== -1)
    }

    readonly property var results: {
        const q = query.trim().toLowerCase()
        if (q !== "") {
            return apps.filter(e => matches(e, q)).sort((a, b) =>
                (b.name.toLowerCase().startsWith(q) ? 1 : 0) - (a.name.toLowerCase().startsWith(q) ? 1 : 0))
        }
        if (category === "favorites") return favoriteApps
        if (category === "all") return apps
        const cat = categories.find(c => c.id === category)
        return apps.filter(e => inCategory(e, cat))
    }

    readonly property bool gridMode: query.trim() === "" && category === "favorites"
    readonly property string userName: Quickshell.env("USER") || "pilot"

    function launch(entry) {
        if (!entry) return
        entry.execute()
        Eva.closeLauncher()
    }

    function reset() {
        query = ""
        search.text = ""
        category = Eva.favorites.length > 0 ? "favorites" : "all"
        selected = 0
        armed = ""
    }

    // ---- window: pops out of the dock above the start button, stuck to it
    // as it spreads, then pulls free and floats just above; it ripples as it
    // starts ----

    readonly property var dock: Eva.docks[screen ? screen.name : ""] ?? null
    readonly property int cardW: 720
    readonly property int cardH: 560
    readonly property int roomTop: 28
    readonly property int roomSide: 28
    readonly property int floatGap: 16     // between the dock and the menu, once free
    readonly property int dockH: dock ? dock.height : 52
    readonly property real dockLeft: dock ? dock.left : 10
    readonly property real startX: (dock ? dock.startX : 28) - margins.left   // in this window

    // a drop wells up out of the start button (bump), spreads into the menu
    // while still stuck to the dock (grow, overshoots a little), then the
    // menu lifts off it (free); the contents fade in as it comes free
    property real bump: 0
    property real grow: 0
    property real free: 0

    visible: Eva.launcherOpen || shrink.running
    anchors { left: true; bottom: true }
    margins {
        left: Math.max(0, Math.round(dockLeft) - roomSide)
        bottom: dock ? dock.height + dock.bottomGap : 62
    }
    implicitWidth: roomSide + cardW + roomSide
    implicitHeight: roomTop + cardH + floatGap
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "eva-menu"
    // OnDemand, not Exclusive: Hyprland still focuses it when it opens, but an
    // exclusive surface swallows clicks elsewhere, so the focus grab below
    // never saw the click outside that should close the menu.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    mask: Region { item: card }

    Connections {
        target: Eva
        function onLauncherOpenChanged() {
            if (Eva.launcherOpen) {
                menu.reset()
                shrink.stop()
                // opened with SUPER while the dock was hidden: let it rise first
                waitForDock.duration = menu.dock && menu.dock.up ? 0 : 200
                growIn.restart()
                search.forceActiveFocus()
            } else {
                growIn.stop()
                shrink.restart()
                menu.ripple()
            }
        }
    }

    // as it pops out (and back in): a wave from the start button through the
    // menu, the dock and the screen's frame, all lined up
    function ripple() {
        if (dock && screen)
            Eva.rippleFrom(screen, screen.x + dock.startX, screen.y + dock.top + dock.height / 2)
    }
    Connections {
        target: Eva
        function onRipple(screenName, x, y, start) {
            if (menu.screen && screenName === menu.screen.name && menu.visible)
                menuGlass.rippleAt(x - menu.screen.x - menu.margins.left,
                                   y - (menu.screen.y + menu.screen.height - menu.margins.bottom - menu.height), start)
        }
    }

    // One quick, overlapping motion: the drop wells up, spreads into the
    // menu while stuck to the dock, then pulls free easing out (the neck
    // snaps on the way); the contents fade in as it comes free.
    SequentialAnimation {
        id: growIn
        PropertyAction { target: card; property: "opacity"; value: 0 }
        PauseAnimation { id: waitForDock; duration: 0 }
        ScriptAction { script: menu.ripple() }
        ParallelAnimation {
            NumberAnimation { target: menu; property: "bump"; to: 1; duration: 90; easing.type: Easing.OutQuad }
            SequentialAnimation {
                PauseAnimation { duration: 50 }
                NumberAnimation { target: menu; property: "grow"; to: 1; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.5 }
            }
            SequentialAnimation {
                PauseAnimation { duration: 330 }
                NumberAnimation { target: menu; property: "free"; to: 1; duration: 220; easing.type: Easing.OutCubic }
            }
            SequentialAnimation {
                PauseAnimation { duration: 280 }
                NumberAnimation { target: card; property: "opacity"; to: 1; duration: 160 }
            }
        }
    }
    ParallelAnimation {
        id: shrink
        NumberAnimation { target: card; property: "opacity"; to: 0; duration: 70 }
        NumberAnimation { target: menu; property: "free"; to: 0; duration: 120; easing.type: Easing.InQuad }
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation { target: menu; property: "grow"; to: 0; duration: 200; easing.type: Easing.InOutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 230 }
            NumberAnimation { target: menu; property: "bump"; to: 0; duration: 90; easing.type: Easing.InQuad }
        }
    }

    HyprlandFocusGrab {
        windows: [menu]
        active: Eva.launcherOpen
        onCleared: Eva.closeLauncher()
    }

    // the dock draws its side of the join (Bar.qml)
    readonly property rect screenBox: Qt.rect(margins.left + menuGlass.box.x,
        (screen ? screen.height : 0) - margins.bottom - height + menuGlass.box.y,
        menuGlass.box.width, menuGlass.box.height)
    function publishBox() {
        Eva.launcherBox = visible && bump > 0.001 && screen
            ? { screen: screen.name, x: screenBox.x, y: screenBox.y, w: screenBox.width, h: screenBox.height,
                r: menuGlass.radius, fillet: menuGlass.fillet }
            : null
    }
    onScreenBoxChanged: publishBox()
    onVisibleChanged: publishBox()

    Liquid {
        id: menuGlass
        anchors.fill: parent
        visible: menu.bump > 0.001
        glass: Theme.glassStrong
        readonly property real bw: 68 * menu.bump
        readonly property real bh: 30 * menu.bump
        readonly property real g: menu.grow
        // stuck to the dock its bottom sits on the dock's top edge (this
        // window's bottom); free, it's floatGap higher
        readonly property real fullY: menu.roomTop + menu.floatGap * (1 - menu.free)
        box: Qt.rect(menu.startX - bw / 2 + (menu.roomSide - (menu.startX - bw / 2)) * g,
                     menu.height - bh + (fullY - (menu.height - bh)) * g,
                     bw + (menu.cardW - bw) * g,
                     bh + (menu.cardH - bh) * g)
        radius: Math.min(Theme.radiusLarge, box.height / 2)
        // the dock, just below this window: the menu melts into its top edge,
        // and the flare thins as it pulls away until it lets go
        anchor: menu.dock ? Qt.rect(menu.dock.left - menu.margins.left, menu.height,
                                    menu.dock.right - menu.dock.left, menu.dockH) : Qt.rect(0, 0, 0, 0)
        anchorRadius: Theme.radiusLarge
        fillet: Math.max(3, 22 - 18 * menu.free)
    }

    Item {
        id: card

        x: menu.roomSide
        y: menu.roomTop + menu.floatGap * (1 - Math.min(1, menu.free))
        width: menu.cardW
        height: menu.cardH
        opacity: 0

        ColumnLayout {
            anchors { fill: parent; margins: Theme.s4 }
            spacing: Theme.s3

            // ---- search ----
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 20
                color: Theme.fill
                border.color: search.activeFocus ? Theme.selectionStroke : "transparent"
                border.width: 1

                Icon {
                    id: searchIcon
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    name: "search"
                    size: 18
                    color: Theme.textSecondary
                }

                Label {
                    anchors { left: searchIcon.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    text: "Search apps"
                    color: Theme.textTertiary
                    font.weight: Font.Normal
                    visible: search.text === ""
                }

                TextInput {
                    id: search
                    anchors { left: searchIcon.right; leftMargin: 10; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    color: Theme.textPrimary
                    selectionColor: Theme.selection
                    font.family: Theme.font
                    font.pixelSize: Theme.fontBody
                    clip: true

                    onTextChanged: { menu.query = text; menu.selected = 0 }

                    Keys.onPressed: event => {
                        const n = menu.results.length
                        const step = menu.gridMode ? 4 : 1
                        if (event.key === Qt.Key_Escape) {
                            Eva.closeLauncher()
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            menu.launch(menu.results[menu.selected])
                        } else if (event.key === Qt.Key_Down) {
                            menu.selected = Math.min(n - 1, menu.selected + step)
                        } else if (event.key === Qt.Key_Up) {
                            menu.selected = Math.max(0, menu.selected - step)
                        } else if (event.key === Qt.Key_Right && menu.gridMode) {
                            menu.selected = Math.min(n - 1, menu.selected + 1)
                        } else if (event.key === Qt.Key_Left && menu.gridMode) {
                            menu.selected = Math.max(0, menu.selected - 1)
                        } else if (event.key === Qt.Key_Tab) {
                            const cats = menu.visibleCategories
                            const i = cats.findIndex(c => c.id === menu.category)
                            menu.category = cats[(i + 1) % cats.length].id
                            menu.selected = 0
                        } else {
                            return
                        }
                        event.accepted = true
                    }
                }
            }

            // ---- categories + apps ----
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.s3

                ListView {
                    id: cats
                    Layout.preferredWidth: 176
                    Layout.fillHeight: true
                    spacing: 2
                    clip: true
                    interactive: contentHeight > height
                    model: menu.visibleCategories

                    delegate: MouseArea {
                        id: catItem
                        required property var modelData
                        readonly property bool current: menu.query === "" && menu.category === modelData.id

                        width: cats.width
                        height: 36
                        hoverEnabled: true
                        onClicked: { menu.category = modelData.id; menu.selected = 0; search.text = "" }

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusSmall + 2
                            color: catItem.current ? Theme.selection : catItem.containsMouse ? Theme.hover : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            spacing: 10

                            Icon {
                                name: catItem.modelData.icon
                                size: 16
                                color: catItem.current ? Theme.active : Theme.textSecondary
                            }
                            Label {
                                Layout.fillWidth: true
                                text: catItem.modelData.label
                                font.pixelSize: Theme.fontLabel
                                color: catItem.current ? Theme.textPrimary : Theme.textSecondary
                            }
                        }
                    }
                }

                Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Theme.stroke }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Label {
                        anchors { left: parent.left; top: parent.top; leftMargin: 4 }
                        text: menu.query !== "" ? "Results" : (menu.visibleCategories.find(c => c.id === menu.category) || {}).label || ""
                        font.pixelSize: Theme.fontLabel
                        font.weight: Font.DemiBold
                        color: Theme.textSecondary
                    }

                    // Favorites: icon grid
                    GridView {
                        id: grid
                        anchors { fill: parent; topMargin: 28 }
                        visible: menu.gridMode
                        clip: true
                        cellWidth: Math.floor(width / 4)
                        cellHeight: 104
                        model: menu.gridMode ? menu.results : []
                        currentIndex: menu.selected

                        delegate: MouseArea {
                            id: tile
                            required property var modelData
                            required property int index
                            readonly property bool current: index === menu.selected

                            width: grid.cellWidth
                            height: grid.cellHeight
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onEntered: menu.selected = index
                            onClicked: mouse => mouse.button === Qt.RightButton
                                ? Eva.toggleFavorite(modelData.id) : menu.launch(modelData)

                            Rectangle {
                                anchors { fill: parent; margins: 3 }
                                radius: Theme.radiusMedium
                                color: tile.current ? Theme.selection : "transparent"
                                border.color: tile.current ? Theme.selectionStroke : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            }

                            IconImage {
                                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 14 }
                                implicitSize: 44
                                source: Quickshell.iconPath(tile.modelData.icon, "application-x-executable")
                            }

                            Label {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8; bottomMargin: 12 }
                                horizontalAlignment: Text.AlignHCenter
                                text: tile.modelData.name
                                font.pixelSize: Theme.fontLabel
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // Everything else: compact list
                    ListView {
                        id: list
                        anchors { fill: parent; topMargin: 28 }
                        visible: !menu.gridMode
                        spacing: 2
                        clip: true
                        model: menu.gridMode ? [] : menu.results
                        currentIndex: menu.selected
                        highlightMoveDuration: 0
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                        delegate: MouseArea {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool current: index === menu.selected
                            readonly property string detail: modelData.genericName || modelData.comment || ""

                            width: list.width - 8
                            height: 48
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onEntered: menu.selected = index
                            onClicked: mouse => mouse.button === Qt.RightButton
                                ? Eva.toggleFavorite(modelData.id) : menu.launch(modelData)

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusSmall + 2
                                color: row.current ? Theme.selection : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            }

                            IconImage {
                                id: appIcon
                                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                implicitSize: 30
                                source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                            }

                            ColumnLayout {
                                anchors { left: appIcon.right; leftMargin: 12; right: star.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                spacing: 1

                                Label {
                                    Layout.fillWidth: true
                                    text: row.modelData.name
                                    elide: Text.ElideRight
                                }
                                Label {
                                    Layout.fillWidth: true
                                    visible: row.detail !== ""
                                    text: row.detail
                                    font.pixelSize: Theme.fontCaption
                                    font.weight: Font.Normal
                                    color: Theme.textSecondary
                                    elide: Text.ElideRight
                                }
                            }

                            Icon {
                                id: star
                                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                name: "star"
                                size: 14
                                color: Theme.glow
                                visible: Eva.isFavorite(row.modelData.id)
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            width: 4
                            radius: 2
                            y: list.visibleArea.yPosition * list.height
                            height: list.visibleArea.heightRatio * list.height
                            color: Theme.strokeStrong
                            visible: list.visibleArea.heightRatio < 1
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        visible: menu.results.length === 0
                        text: menu.query !== "" ? "No apps match “" + menu.query + "”" : "Right-click any app to pin it here"
                        color: Theme.textTertiary
                        font.weight: Font.Normal
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.stroke }

            // ---- footer: user + power ----
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                spacing: Theme.s2

                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 15
                    color: Theme.alpha(Theme.primary, 0.85)

                    Label {
                        anchors.centerIn: parent
                        text: menu.userName.charAt(0).toUpperCase()
                        font.weight: Font.DemiBold
                        color: Theme.onPrimary
                    }
                }

                Label {
                    text: menu.userName
                    font.weight: Font.DemiBold
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: menu.armed === "logout" ? "Click again to log out"
                        : menu.armed === "reboot" ? "Click again to restart"
                        : menu.armed === "poweroff" ? "Click again to shut down" : ""
                    font.pixelSize: Theme.fontCaption
                    color: Theme.crit
                }

                Repeater {
                    model: [
                        { id: "lock",     icon: "lock",    cmd: "loginctl lock-session",            confirm: false },
                        { id: "sleep",    icon: "sleep",   cmd: "systemctl suspend",                confirm: false },
                        { id: "logout",   icon: "logout",  cmd: "hyprctl dispatch 'hl.dsp.exit()'", confirm: true },
                        { id: "reboot",   icon: "restart", cmd: "systemctl reboot",                 confirm: true },
                        { id: "poweroff", icon: "power",   cmd: "systemctl poweroff",               confirm: true }
                    ]

                    Chip {
                        id: power
                        required property var modelData
                        readonly property bool isArmed: menu.armed === modelData.id

                        implicitWidth: 34
                        implicitHeight: 34
                        padding: 0
                        tint: isArmed ? Theme.alpha(Theme.crit, 0.30) : "transparent"

                        onClicked: {
                            if (modelData.confirm && !isArmed) {
                                menu.armed = modelData.id
                                disarm.restart()
                                return
                            }
                            Eva.closeLauncher()
                            Eva.run(modelData.cmd)
                        }

                        Icon {
                            name: power.modelData.icon
                            size: 17
                            color: power.isArmed ? Theme.crit : Theme.textSecondary
                        }
                    }
                }
            }
        }
    }

    // Log out / restart / shut down need a second click within 3 s.
    Timer {
        id: disarm
        interval: 3000
        onTriggered: menu.armed = ""
    }
}
