import Quickshell
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell.Wayland

PanelWindow {
    id: main

    // ---- Easy-to-edit settings ----
    property int animDuration: 100    // ms for scroll animation
    property real zoomScale: 0.8        // scale of the tile at screen center (peak)
    property real edgeScale: 0.3      // scale of tiles at the screen edges (trough)
    property real skewFactor: 0   // italic-style shear on tiles
    property int baseSpacing: 8       // resting gap between tiles (grows automatically as tiles magnify)
    // --------------------------------

    implicitHeight: 500
    implicitWidth: Screen.width
    color: "transparent"

    aboveWindows: true
    exclusionMode: "Ignore"
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Clicking outside the strip closes the picker
    MouseArea {
        anchors.fill: parent
        onClicked: Qt.quit()
    }

    Item {
        id: strip
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        height: 500
    }

    Component.onCompleted: {
        Quickshell.execDetached(["bash", Quickshell.shellPath("cache.sh"), Quickshell.shellDir])
    }

    FileView {
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: configs
            property string wallpaper_path
            property string cache_path
            property int number_of_pictures
            property string border_color
        }
    }

    FolderListModel {
        id: folderModel
        folder: "file://" + configs.wallpaper_path
        showDirs: false
        nameFilters: ["*.mp4", "*.webm", "*.mkv", "*.mov", "*.gif", "*.png", "*.jpg", "*.jpeg"]
        sortField: FolderListModel.Name
    }

    ListView {
        id: list
        anchors.fill: strip
        focus: true

        model: folderModel
        orientation: ListView.Horizontal
        spacing: main.baseSpacing
        clip: true
        cacheBuffer: 400

        // Selection-centered carousel: the current item is pinned to the
        // screen center, so the dock-zoom peak and the selection always
        // agree - even when the whole row fits on screen and there is
        // nothing to free-scroll.
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: centerLead
        preferredHighlightEnd: centerLead
        highlightMoveDuration: main.animDuration

        // ponytail: fixed-width spacers (no contentWidth feedback) so the
        // first/last items can reach screen center too.
        header: Item { width: list.centerLead + 40; height: 1 }
        footer: Item { width: list.centerLead + 40; height: 1 }

        property real tileWidth: width / configs.number_of_pictures - 10
        property real viewportCenterX: width / 2
        // Leading space that puts an item at screen center when pinned.
        property real centerLead: width / 2 - tileWidth * main.zoomScale / 2

        function clampIndex(i) {
            return Math.max(0, Math.min(i, count - 1))
        }

        function activateCurrent() {
            const path = folderModel.get(currentIndex, "filePath")
            Quickshell.execDetached(["bash", Quickshell.shellPath("commands.sh"), path])
            Qt.quit()
        }

        // Moves the selection by `delta` tiles; the view glides the new
        // current item to the center automatically.
        function moveSelection(delta) {
            currentIndex = clampIndex(currentIndex + delta)
        }

        delegate: Item {
            id: delegateItem
            height: 500
            property bool active: index === list.currentIndex

            // Base (unscaled) slot width. Used to work out where this tile currently sits
            // on screen for the magnification curve below. Deliberately NOT derived from
            // this item's own (dynamic) width - if it were, width would depend on position
            // which would depend on width, i.e. a binding loop.
            readonly property real baseWidth: list.tileWidth

            // --- Dock-style magnification: scale depends on on-screen position ---
            // One binding instead of several chained ones - list.contentX already animates
            // smoothly (SmoothedAnimation below), so this recomputes every frame during
            // scroll anyway; no need for extra Behavior/NumberAnimation layered on top of
            // it (that was two animations fighting over the same value, which is what was
            // causing the sluggish feel).
            property real scaleFactor: {
                const centerX = x - list.contentX + baseWidth / 2
                const frac = Math.min(1, Math.abs(centerX - list.viewportCenterX) / list.viewportCenterX)
                const t = 1 - frac * frac * (3 - 2 * frac) // smoothstep falloff
                return main.edgeScale + (main.zoomScale - main.edgeScale) * t
            }

            // This IS the delegate's real layout width, so as it grows, ListView pushes
            // every following tile further along - real spacing, not an overlapping overlay.
            // No Behavior here: it already tracks contentX's smooth animation 1:1, and tiles
            // never overlap in this layout, so there's nothing to visually smooth over.
            width: baseWidth * scaleFactor

            Item {
                id: content
                anchors.centerIn: parent
                width: parent.width
                // Height scale uses the same factor but caps at 1.0 - the row is already
                // full window height, so growing past that would just get clipped.
                height: delegateItem.height * Math.min(1, delegateItem.scaleFactor)

                Text {
                    id: alt
                    text: ""
                    color: configs.border_color
                    anchors.centerIn: parent
                    font.pixelSize: 16
                    transform: Shear { xFactor: main.skewFactor }
                }

                Image {
                    id: img
                    anchors.fill: parent
                    opacity: 0.8
                    fillMode: Image.PreserveAspectCrop

                    asynchronous: true
                    cache: false
                    smooth: true

                    source: "file://" + configs.cache_path + fileName + ".jpg"

                    // Decode once at the largest size this image will ever be shown at
                    // (the active/zoomed size), rather than tracking the animating
                    // width/height - that would re-decode on every animation frame
                    // and cause a visible blink.
                    sourceSize.width: delegateItem.baseWidth * main.zoomScale
                    sourceSize.height: delegateItem.height

                    transform: Shear { xFactor: main.skewFactor }

                    Timer {
                        id: retryTimer
                        interval: 1000
                        repeat: false
                        onTriggered: {
                            const s = img.source
                            img.source = ""
                            img.source = s
                        }
                    }

                    onStatusChanged: {
                        if (status === Image.Error) {
                            alt.text = "Caching"
                            retryTimer.start()
                        }
                    }
                }

                Rectangle {
                    id: border
                    z: 10
                    anchors.fill: parent
                    visible: delegateItem.active
                    color: "transparent"

                    border.width: 2
                    border.color: configs.border_color

                    transform: Shear { xFactor: main.skewFactor }
                }

                // Video badge so live videos are distinguishable in the grid
                Text {
                    z: 11
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 10
                    text: "▶"
                    color: "#B0FFFFFF"
                    font.pixelSize: 18
                    visible: /\.(mp4|webm|mkv|mov)$/i.test(fileName)
                }
            }

            MouseArea {
                anchors.fill: parent

                onClicked: {
                    list.currentIndex = index
                    list.activateCurrent()
                }

                onWheel: function(wheel) {
                    list.moveSelection(wheel.angleDelta.y < 0 ? 1 : -1)
                    wheel.accepted = true
                }
            }
        }

        Keys.onPressed: function(event) {
            const big = configs.number_of_pictures

            switch (event.key) {
            case Qt.Key_J:
                moveSelection(1)
                break
            case Qt.Key_K:
                moveSelection(-1)
                break
            case Qt.Key_D:
                moveSelection(big)
                break
            case Qt.Key_U:
                moveSelection(-big)
                break
            case Qt.Key_Space:
            case Qt.Key_Return:
                activateCurrent()
                break
            case Qt.Key_Escape:
                Qt.quit()
                break
            default:
                return
            }

            event.accepted = true
        }
    }
}
