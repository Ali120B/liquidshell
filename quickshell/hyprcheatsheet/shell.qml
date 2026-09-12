//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root

    property bool shown: false
    // 1 = open, 0 = dismissed. Opens instantly, quick fade on close.
    property real openT: shown ? 1 : 0

    Behavior on openT {
        enabled: !root.shown
        NumberAnimation {
            duration: 100
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: quitTimer
        interval: 110
        repeat: false
        onTriggered: Qt.quit()
    }

    function close() {
        root.shown = false
        quitTimer.start()
    }

    Component.onCompleted: root.shown = true

    // section, keys, label
    property var entries: [
        { section: "Apps", keys: "SUPER", label: "Superlauncher" },
        { section: "Apps", keys: "SUPER + .", label: "Emoji Menu" },
        { section: "Apps", keys: "SUPER + T", label: "Terminal" },
        { section: "Apps", keys: "SUPER + E", label: "File Manager (spf)" },
        { section: "Apps", keys: "SUPER + B", label: "Browser (zen)" },
        { section: "Apps", keys: "SUPER + SHIFT + F", label: "File Search (fzf)" },
        { section: "Windows", keys: "SUPER + Q", label: "Close Window" },
        { section: "Windows", keys: "SUPER + F", label: "Fullscreen" },
        { section: "Windows", keys: "SUPER + Space", label: "Toggle Floating" },
        { section: "Windows", keys: "SUPER + O", label: "Opacity Menu" },
        { section: "Windows", keys: "SUPER + drag", label: "Move / Resize (LMB/RMB)" },
        { section: "Focus / Move", keys: "SUPER + arrows", label: "Focus window" },
        { section: "Focus / Move", keys: "SUPER + H J K L", label: "Focus (vim)" },
        { section: "Focus / Move", keys: "SUPER + SHIFT + arrows", label: "Move / rearrange tile" },
        { section: "Focus / Move", keys: "SUPER + CTRL + arrows", label: "Resize" },
        { section: "Workspaces", keys: "SUPER + 1..0", label: "Switch workspace" },
        { section: "Workspaces", keys: "SUPER + ALT + 1..0", label: "Move window to" },
        { section: "Shots / Record", keys: "SUPER + SHIFT + S", label: "Region Screenshot" },
        { section: "Shots / Record", keys: "SUPER + SHIFT + A", label: "Region Search" },
        { section: "Shots / Record", keys: "SUPER + SHIFT + X", label: "OCR (text recognition)" },
        { section: "Shots / Record", keys: "SUPER + SHIFT + C", label: "Color Picker" },
        { section: "Shots / Record", keys: "SUPER + R", label: "Screen Record" },
        { section: "Shots / Record", keys: "SUPER + SHIFT + R", label: "Record w/ Audio" },
        { section: "Shots / Record", keys: "Print", label: "Screenshot to clipboard" },
        { section: "System", keys: "SUPER + Tab", label: "Lock Screen" },
        { section: "System", keys: "SUPER + Esc", label: "Logout Menu" },
        { section: "System", keys: "SUPER + SHIFT + E", label: "Exit Hyprland" },
        { section: "System", keys: "SUPER + Z", label: "Keyboard Layout" },
        { section: "System", keys: "XF86 Audio", label: "Volume / Media" },
        { section: "System", keys: "XF86 Brightness", label: "Screen Brightness" },
        { section: "Other", keys: "SUPER + W", label: "Wallpaper Picker" },
        { section: "Other", keys: "SUPER + SHIFT + W", label: "Live Wallpaper Picker" },
        { section: "Other", keys: "SUPER + CTRL + W", label: "Toggle Waybar" },
        { section: "Other", keys: "SUPER + V", label: "Clipboard (clipse)" },
        { section: "Other", keys: "SUPER + N", label: "Notification History" },
        { section: "Other", keys: "SUPER + SHIFT + N", label: "Test Notification" },
        { section: "Other", keys: "F1", label: "This Cheatsheet" }
    ]

    property string query: ""
    property var filtered: root.entries

    function applyFilter() {
        const q = root.query.toLowerCase().trim()
        if (q.length === 0) {
            root.filtered = root.entries
            return
        }
        root.filtered = root.entries.filter(e =>
            e.keys.toLowerCase().includes(q) || e.label.toLowerCase().includes(q))
    }

    onQueryChanged: applyFilter()

    PanelWindow {
        id: panel
        visible: root.openT > 0
        implicitWidth: 780
        implicitHeight: 640
        color: "transparent"

        aboveWindows: true
        focusable: true
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell:hyprcheatsheet"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Blurred + dimmed backdrop with frosted card on top.
        // Clicking outside the card closes.
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: root.openT * 0.35
            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }

        // Centered glass card
        Item {
            anchors.centerIn: parent
            width: 720
            height: 600
            opacity: root.openT
            scale: 0.94 + 0.06 * root.openT
            transformOrigin: Item.Center

            transform: Translate {
                y: (1 - root.openT) * 26
            }

            Rectangle {
                anchors.fill: parent
                radius: 24
                color: "#8C151820"
                border.width: 1
                border.color: "#18FFFFFF"

                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#25FFFFFF" }
                    GradientStop { position: 0.4; color: "#08FFFFFF" }
                    GradientStop { position: 1.0; color: "#10000000" }
                }
            }

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

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 12

                // Title
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Keybinds"
                        color: "#FFFFFF"
                        font.family: "Iosevka"
                        font.pixelSize: 20
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "esc to close"
                        color: "#50FFFFFF"
                        font.family: "Iosevka"
                        font.pixelSize: 11
                    }
                }

                // Search
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 14
                    color: "#18FFFFFF"
                    border.width: 1
                    border.color: searchInput.activeFocus ? "#407AA2F7" : "#12FFFFFF"

                    Behavior on border.color {
                        ColorAnimation { duration: 150 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10
                        Text {
                            text: ""
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            color: "#80FFFFFF"
                        }
                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            color: "#FFFFFF"
                            font.family: "Iosevka"
                            font.pixelSize: 15
                            clip: true
                            focus: true
                            cursorVisible: true
                            selectionColor: "#507AA2F7"
                            onTextChanged: root.query = text
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Filter..."
                                color: "#50FFFFFF"
                                font: searchInput.font
                                visible: searchInput.text.length === 0
                            }
                            Keys.onPressed: function (event) {
                                if (event.key === Qt.Key_Escape) {
                                    root.close()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Down) {
                                    cheatList.incrementCurrentIndex()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Up) {
                                    cheatList.decrementCurrentIndex()
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }

                // List
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 18
                    color: "#12FFFFFF"
                    clip: true

                    ListView {
                        id: cheatList
                        anchors.fill: parent
                        anchors.margins: 8
                        model: root.filtered
                        currentIndex: 0
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        cacheBuffer: 300
                        spacing: 2
                        highlightMoveDuration: 0
                        highlightResizeDuration: 0

                        section.property: "section"
                        section.delegate: Text {
                            required property string section
                            text: section
                            color: "#7AA2F7"
                            font.family: "Iosevka"
                            font.pixelSize: 16
                            font.bold: true
                        }

                        highlight: Rectangle {
                            radius: 10
                            color: "#22FFFFFF"
                        }
                        highlightFollowsCurrentItem: true

                        delegate: Item {
                            required property var modelData
                            width: cheatList.width
                            height: 34
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 12
                                Rectangle {
                                    radius: 6
                                    color: "#10FFFFFF"
                                    border.width: 1
                                    border.color: "#14FFFFFF"
                                    implicitWidth: keyLabel.implicitWidth + 14
                                    implicitHeight: keyLabel.implicitHeight + 8
                                    Text {
                                        id: keyLabel
                                        anchors.centerIn: parent
                                        text: modelData.keys
                                        font.family: "Iosevka"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: "#7AA2F7"
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.label
                                    color: "#C0FFFFFF"
                                    font.family: "Iosevka"
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: cheatList.currentIndex = index
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: root.filtered.length === 0
                            text: "No matches"
                            color: "#50FFFFFF"
                            font.family: "Iosevka"
                            font.pixelSize: 14
                        }
                    }
                }

                // Footer
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Text {
                        text: root.filtered.length + " binds"
                        font.family: "Iosevka"
                        font.pixelSize: 10
                        color: "#30FFFFFF"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "↑↓ nav · esc close"
                        font.family: "Iosevka"
                        font.pixelSize: 10
                        color: "#40FFFFFF"
                    }
                }
            }
        }

        // Global esc (when search isn't focused)
        Shortcut {
            sequence: "Escape"
            onActivated: root.close()
        }
    }
}
