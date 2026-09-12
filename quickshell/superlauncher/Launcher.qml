import QtQuick
import QtQuick.Layouts
import QtCore
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    property bool isOpen: false
    // Caelestia-style reveal scalar: 1 = open, 0 = dismissed. A single
    // Behavior drives it; slide, scale and fades all bind to it, so
    // interruptions reverse smoothly. Fed by shell as 1 - offsetScale.
    property real openT: isOpen ? 1 : 0

    Behavior on openT {
        NumberAnimation {
            duration: 100
            easing.type: Easing.Bezier
            easing.bezierCurve: [0.05, 0.7, 0.1, 1.0]
        }
    }

    property string query: ""
    property var filteredApps: []
    property int selectedIndex: 0

    // Snaps the selector instantly on open; gliding only after settle.
    property bool settled: false
    Timer {
        id: settleTimer
        interval: 250
        repeat: false
        onTriggered: root.settled = true
    }

    // Asked to close (Esc / launch). Shell flips isOpen -> false and
    // openT glides back to 0; the window unmaps when fully dismissed.
    signal requestClose()

    property alias maskItem: glassBg

    AppProvider {
        id: appProvider
        onLoadedChanged: {
            if (loaded && root.isOpen)
                root.applyFilter()
        }
        onAppsChanged: {
            if (root.isOpen)
                root.applyFilter()
        }
        onHistoryReady: {
            if (root.isOpen)
                root.applyFilter()
        }
    }

    function applyFilter() {
        filteredApps = appProvider.search(query)
        selectedIndex = 0
        // ListView may clamp currentIndex internally on model swaps,
        // so drive it explicitly instead of relying on a binding that
        // such internal writes would silently break.
        appList.currentIndex = 0
        if (appList.count > 0)
            appList.positionViewAtBeginning()
    }

    onQueryChanged: applyFilter()

    onSelectedIndexChanged: {
        if (appList.count > 0 && selectedIndex >= 0 && selectedIndex < appList.count) {
            appList.currentIndex = selectedIndex
            // No manual positionViewAtIndex here: StrictlyEnforceRange
            // glides the content smoothly instead of snapping.
        }
    }

    onIsOpenChanged: {
        if (isOpen) {
            root.settled = false
            settleTimer.restart()
            searchInput.text = ""
            query = ""
            filteredApps = appProvider.search("")
            selectedIndex = 0
            appList.currentIndex = 0
            if (appList.count > 0)
                appList.positionViewAtBeginning()
            // Window just mapped; defer focus a frame so Exclusive
            // keyboard focus is active before we grab it.
            Qt.callLater(function () {
                searchInput.forceActiveFocus()
            })
        } else {
            root.settled = false
            settleTimer.stop()
            searchInput.focus = false
        }
    }

    // ─── Reveal: everything binds to openT (Caelestia-style) ──────
    // Slide (Translate) avoids fighting anchors.bottom like animating
    // `y` does. Scale pivots at the bottom edge so the card feels like
    // it breaks outward from the screen edge. No overshoot — the M3
    // emphasized curve on openT carries the motion, same as Caelestia.

    // ─── Content wrapper (animated via transforms, not anchors) ──
    Item {
        id: panelContent
        anchors.fill: parent
        opacity: root.openT
        scale: 0.93 + 0.07 * root.openT
        transformOrigin: Item.Bottom

        transform: Translate {
            id: rise
            y: (1 - root.openT) * 170
        }

        // ─── Liquid Glass Background ──────────────────────────
        Rectangle {
            id: glassBg
            anchors.fill: parent
            anchors.margins: 10
            radius: 24
            color: "#8C151820"
            border.width: 1
            border.color: "#18FFFFFF"

            Rectangle {
                anchors.fill: parent
                radius: 24
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#25FFFFFF" }
                    GradientStop { position: 0.4; color: "#08FFFFFF" }
                    GradientStop { position: 1.0; color: "#10000000" }
                }
            }

            // Top-edge highlight. Inset by the corner radius so its
            // ends never poke past the rounded corners (that showed
            // up as a stray floating line above the card), and placed
            // just inside the border.
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 26
                anchors.rightMargin: 26
                height: 1
                color: "#30FFFFFF"
            }
        }

        // ─── Column Content (parallax layer) ──────────────────
        ColumnLayout {
            id: innerFade
            anchors.fill: parent
            anchors.margins: 24
            anchors.topMargin: 20
            spacing: 12
            opacity: root.openT

            transform: Translate {
                id: contentShift
                y: (1 - root.openT) * 28
            }

            // ─── Search Bar ──────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: 14
                color: "#18FFFFFF"
                border.width: 1
                border.color: searchInput.activeFocus ? "#407AA2F7" : "#12FFFFFF"

                Behavior on border.color {
                    ColorAnimation { duration: 200 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Text {
                        text: ""
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        color: "#80FFFFFF"
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: "#FFFFFF"
                        font.family: "Iosevka"
                        font.pixelSize: 16
                        clip: true
                        focus: true
                        cursorVisible: true
                        selectionColor: "#507AA2F7"
                        onTextChanged: root.query = text

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Search apps..."
                            color: "#50FFFFFF"
                            font: searchInput.font
                            // Keep the hint while focused-but-empty; it
                            // previously vanished the moment focus landed.
                            visible: searchInput.text.length === 0
                        }

                        Keys.onPressed: function (event) {
                            var last = Math.max(root.filteredApps.length - 1, 0)
                            switch (event.key) {
                            case Qt.Key_Escape:
                                root.requestClose()
                                event.accepted = true
                                break
                            case Qt.Key_Down:
                                // Clamp at the ends — no wrapping.
                                root.selectedIndex = Math.min(root.selectedIndex + 1, last)
                                event.accepted = true
                                break
                            case Qt.Key_Up:
                                root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                                event.accepted = true
                                break
                            case Qt.Key_PageDown:
                                root.selectedIndex = Math.min(root.selectedIndex + 5, last)
                                event.accepted = true
                                break
                            case Qt.Key_PageUp:
                                root.selectedIndex = Math.max(root.selectedIndex - 5, 0)
                                event.accepted = true
                                break
                            case Qt.Key_Home:
                                root.selectedIndex = 0
                                event.accepted = true
                                break
                            case Qt.Key_End:
                                root.selectedIndex = last
                                event.accepted = true
                                break
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                root.launchSelected()
                                event.accepted = true
                                break
                            }
                        }
                    }

                    Rectangle {
                        radius: 6
                        color: "#10FFFFFF"
                        implicitWidth: escLabel.implicitWidth + 8
                        implicitHeight: escLabel.implicitHeight + 4
                        Text {
                            id: escLabel
                            anchors.centerIn: parent
                            text: "esc"
                            font.family: "Iosevka"
                            font.pixelSize: 11
                            color: "#40FFFFFF"
                        }
                    }
                }
            }

            // ─── Results ─────────────────────────────────────
            Rectangle {
                id: resultsContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 18
                color: "#12FFFFFF"
                clip: true

                ListView {
                    id: appList
                    anchors.fill: parent
                    anchors.margins: 8
                    model: root.filteredApps
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    cacheBuffer: 240

                    // Sliding pill, Caelestia-style: it tracks the current
                    // item directly and glides via a Behavior instead of
                    // highlightFollowsCurrentItem, so keyboard nav and
                    // mouse clicks can never desync it. Hover never moves
                    // selection (Caelestia's StateLayer is click-only) —
                    // hover just shows a faint background. That kills both
                    // hover-steal during keyboard nav and the reselect →
                    // scroll → reselect runaway loop by construction.
                    highlight: Rectangle {
                        radius: 12
                        color: "#22FFFFFF"
                        border.width: 1
                        border.color: "#14FFFFFF"
                        y: appList.currentItem ? appList.currentItem.y : 0
                        width: appList.width
                        height: appList.currentItem ? appList.currentItem.height : 48

                        Behavior on y {
                            enabled: root.settled
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.Bezier
                                easing.bezierCurve: [0.05, 0.7, 0.1, 1.0]
                            }
                        }
                    }
                    highlightFollowsCurrentItem: false

                    // Keep the selected row inside a centered band and
                    // glide the content when it would leave it. (Strict
                    // enforcement would also pin row 0 to the center and
                    // leave a dead gap at the top of a fresh list.)
                    highlightRangeMode: ListView.ApplyRange
                    preferredHighlightBegin: height / 2 - 28
                    preferredHighlightEnd: height / 2 + 28

                    delegate: Item {
                        id: delegate
                        required property var modelData
                        required property int index
                        width: appList.width
                        height: 48

                        property bool isCurrent: index === root.selectedIndex
                        property var iconCandidates: root.iconChain(modelData)
                        property int iconIdx: 0
                        property bool iconExhausted: iconCandidates.length === 0

                        onModelDataChanged: {
                            iconIdx = 0
                            iconExhausted = iconCandidates.length === 0
                            appIcon.source = iconCandidates.length > 0 ? iconCandidates[0] : ""
                        }

                        // Faint hover background only — it never touches
                        // selection. Hidden on the selected row where the
                        // pill already sits.
                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: "#14FFFFFF"
                            opacity: (rowMouse.containsMouse && !delegate.isCurrent) ? 1 : 0
                            visible: opacity > 0

                            Behavior on opacity {
                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: 8
                                color: delegate.isCurrent ? "#22FFFFFF" : "#12FFFFFF"

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                IconImage {
                                    id: appIcon
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    implicitSize: 28
                                    source: delegate.iconCandidates.length > 0 ? delegate.iconCandidates[0] : ""
                                    visible: !delegate.iconExhausted
                                    onStatusChanged: {
                                        if (status === Image.Error) {
                                            var next = delegate.iconIdx + 1
                                            if (next < delegate.iconCandidates.length) {
                                                delegate.iconIdx = next
                                                source = delegate.iconCandidates[next]
                                            } else {
                                                delegate.iconExhausted = true
                                            }
                                        }
                                    }
                                }

                                // Last resort when nothing resolves: app initial.
                                Text {
                                    anchors.centerIn: parent
                                    text: ((modelData.name || "?").charAt(0) || "?").toUpperCase()
                                    color: "#70FFFFFF"
                                    font.family: "Iosevka"
                                    font.pixelSize: 15
                                    font.bold: true
                                    visible: delegate.iconExhausted
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: delegate.isCurrent ? "#FFFFFF" : "#C0FFFFFF"
                                    font.family: "Iosevka"
                                    font.pixelSize: 14
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.comment || modelData.genericName || ""
                                    color: "#45FFFFFF"
                                    font.family: "Iosevka"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    visible: text.length > 0
                                }
                            }

                            Text {
                                text: "⏎"
                                color: "#60FFFFFF"
                                font.pixelSize: 13
                                // Fade with the gliding pill instead of
                                // popping instantly (which made it appear
                                // before the selector arrived).
                                opacity: delegate.isCurrent ? 1 : 0
                                visible: opacity > 0

                                Behavior on opacity {
                                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // Click-only, like Caelestia: hover highlights
                            // via the background above but never moves the
                            // keyboard selection, so parked cursors and
                            // scrolling lists can't fight arrow keys.
                            onClicked: root.launchApp(modelData)
                        }
                    }

                    add: Transition {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
                    }

                    remove: Transition {
                        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Easing.OutCubic }
                    }

                    move: Transition {
                        NumberAnimation { property: "y"; duration: 250; easing.type: Easing.Bezier; easing.bezierCurve: [0.05, 0.7, 0.1, 1.0] }
                        NumberAnimation { property: "opacity"; duration: 200; easing.type: Easing.OutCubic }
                    }

                    addDisplaced: Transition {
                        NumberAnimation { property: "y"; duration: 250; easing.type: Easing.Bezier; easing.bezierCurve: [0.05, 0.7, 0.1, 1.0] }
                        NumberAnimation { property: "opacity"; duration: 200; easing.type: Easing.OutCubic }
                    }

                    displaced: Transition {
                        NumberAnimation { property: "y"; duration: 250; easing.type: Easing.Bezier; easing.bezierCurve: [0.05, 0.7, 0.1, 1.0] }
                        NumberAnimation { property: "opacity"; duration: 200; easing.type: Easing.OutCubic }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.filteredApps.length === 0
                    text: root.query.length > 0 ? "No apps found" : (appProvider.loaded ? "No applications" : "Loading apps...")
                    color: "#50FFFFFF"
                    font.family: "Iosevka"
                    font.pixelSize: 14
                }
            }

            // ─── Footer ──────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Repeater {
                    model: [
                        { keys: "↑↓", label: "nav" },
                        { keys: "enter", label: "launch" },
                        { keys: "esc", label: "close" }
                    ]

                    RowLayout {
                        required property var modelData
                        spacing: 4
                        Rectangle {
                            radius: 4
                            color: "#10FFFFFF"
                            implicitWidth: fLabel.implicitWidth + 6
                            implicitHeight: fLabel.implicitHeight + 4
                            Text {
                                id: fLabel
                                anchors.centerIn: parent
                                text: modelData.keys
                                font.family: "Iosevka"
                                font.pixelSize: 10
                                color: "#50FFFFFF"
                            }
                        }
                        Text {
                            text: modelData.label
                            font.family: "Iosevka"
                            font.pixelSize: 10
                            color: "#40FFFFFF"
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.filteredApps.length + " apps"
                    font.family: "Iosevka"
                    font.pixelSize: 10
                    color: "#30FFFFFF"
                }
            }
        }
    }

    // ─── Actions ────────────────────────────────────────────────
    // First usable generic icon in the active theme (cached). Probed
    // because this theme lacks even image-missing.
    property string _genericIconUrl: ""
    function genericIconUrl() {
        if (_genericIconUrl !== "")
            return _genericIconUrl
        var names = ["image-missing", "application-x-executable", "exec", "application-default-icon", "system-run"]
        for (var i = 0; i < names.length; i++) {
            if (Quickshell.hasThemeIcon(names[i])) {
                _genericIconUrl = Quickshell.iconPath(names[i])
                break
            }
        }
        return _genericIconUrl
    }

    // Ordered icon candidates for an entry. Theme names are gated by
    // hasThemeIcon because the icon provider renders its own broken
    // placeholder (Ready, not Error) for missing theme icons, which
    // load-failure chaining cannot catch. Plain file:// fallbacks do
    // report real errors, so the delegate can still walk past those.
    function iconChain(entry) {
        var out = []
        var name = (entry && entry.icon) || ""
        if (name !== "") {
            if (name.charAt(0) === "/") {
                out.push("file://" + name)
            } else if (Quickshell.hasThemeIcon(name)) {
                out.push(Quickshell.iconPath(name))
            } else {
                var dot = name.lastIndexOf(".")
                var stripped = ""
                if (dot > 0) {
                    var ext = name.substring(dot).toLowerCase()
                    if (ext === ".png" || ext === ".svg" || ext === ".xpm")
                        stripped = name.substring(0, dot)
                }
                if (stripped !== "" && Quickshell.hasThemeIcon(stripped)) {
                    out.push(Quickshell.iconPath(stripped))
                } else {
                    var home = String(StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace(/^file:\/\//, "")
                    var dirs = [home + "/.local/share/icons", "/usr/share/pixmaps"]
                    var bases = stripped !== "" ? [name, stripped] : [name]
                    for (var d = 0; d < dirs.length; d++) {
                        for (var b = 0; b < bases.length; b++) {
                            var cand = bases[b]
                            if (cand.toLowerCase().match(/\.(png|svg|xpm)$/)) {
                                out.push("file://" + dirs[d] + "/" + cand)
                            } else {
                                out.push("file://" + dirs[d] + "/" + cand + ".png")
                                out.push("file://" + dirs[d] + "/" + cand + ".svg")
                                out.push("file://" + dirs[d] + "/" + cand + ".xpm")
                            }
                        }
                    }
                }
            }
        }
        var generic = genericIconUrl()
        if (generic !== "")
            out.push(generic)
        return out
    }

    function launchSelected() {
        if (root.selectedIndex >= 0 && root.selectedIndex < root.filteredApps.length) {
            launchApp(root.filteredApps[root.selectedIndex])
        }
    }

    function launchApp(entry) {
        if (!entry)
            return
        // Count it before launching so next open ranks it higher.
        appProvider.recordLaunch(entry)
        // DesktopEntry.execute() handles Exec field codes, working
        // directory and Terminal=true correctly — far more robust
        // than splitting the exec string by hand.
        entry.execute()
        root.requestClose()
    }

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape) {
            root.requestClose()
            event.accepted = true
        }
    }
}
