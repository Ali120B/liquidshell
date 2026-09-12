import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    // Target state (what the user wants). Caelestia-style single scalar
    // (mechanics borrowed from Caelestia's launcher Wrapper.qml):
    // 0 = open, 1 = dismissed. One Behavior animates it, and the window
    // slide, content reveal and visibility all follow it, so a rapid
    // re-toggle mid-flight reverses seamlessly instead of jumping.
    property bool launcherVisible: false
    property real offsetScale: launcherVisible ? 0 : 1

    Behavior on offsetScale {
        NumberAnimation {
            duration: 100
            easing.type: Easing.Bezier
            easing.bezierCurve: [0.05, 0.7, 0.1, 1.0]
        }
    }

    // Terminal control (bound to SUPER-tap in ~/.config/hypr/keybinds.lua):
    //   quickshell ipc -p ~/.config/quickshell/superlauncher call superlauncher toggle
    //   quickshell ipc -p ~/.config/quickshell/superlauncher call superlauncher open
    //   quickshell ipc -p ~/.config/quickshell/superlauncher call superlauncher hide
    //   quickshell ipc -p ~/.config/quickshell/superlauncher call superlauncher isVisible
    // NOTE: the "show" name is avoided because `call superlauncher show`
    // is intercepted by the CLI's own `ipc show` listing. `open`
    // does the same job.
    IpcHandler {
        target: "superlauncher"

        function toggle(): void {
            root.launcherVisible = !root.launcherVisible
        }
        function open(): void {
            root.launcherVisible = true
        }
        function hide(): void {
            root.launcherVisible = false
        }
        function isVisible(): bool {
            return root.launcherVisible
        }
    }

    PanelWindow {
        id: panel

        visible: root.offsetScale < 1
        implicitWidth: 620
        implicitHeight: 640
        color: "transparent"

        aboveWindows: true
        focusable: true
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell:superlauncher"

        anchors {
            bottom: true
        }
        // Slide down beyond the bottom edge when dismissed, like
        // Caelestia's `anchors.bottomMargin: (-implicitHeight - 5) * offsetScale`.
        margins {
            bottom: 16 - (implicitHeight + 48) * root.offsetScale
        }

        // Card-sized window: Hyprland blurs only behind the card (true
        // frosted glass) instead of the whole desktop. Clicking anywhere
        // else clears the grab and dismisses.
        HyprlandFocusGrab {
            active: root.launcherVisible
            windows: [panel]
            onCleared: root.launcherVisible = false
        }

        Launcher {
            id: launcher
            anchors.fill: parent
            isOpen: root.launcherVisible
            openT: 1 - root.offsetScale
            onRequestClose: root.launcherVisible = false
        }
    }
}
