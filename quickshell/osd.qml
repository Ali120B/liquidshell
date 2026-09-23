import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtCore

// OSD — simple translucent bottom-center for brightness/volume, themed by matugen
// Listens to wpctl and brightnessctl via polling, shows on change
PanelWindow {
    id: osd
    property int value: 0 // 0-100
    property string icon: ""
    property string label: "Volume"
    property bool muted: false
    property bool visibleOsd: false
    property int hideDelay: 1500
    visible: visibleOsd
    color: "transparent"
    anchors { bottom: true; left: true; right: true }
    margins { bottom: 40 }
    implicitWidth: 200
    implicitHeight: 36
    // Small pill — bottom-center
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Auto-hide
    Timer {
        id: hideTimer
        interval: osd.hideDelay
        onTriggered: osd.visibleOsd = false
    }
    function show(v, ic, lb, m) {
        osd.value = v
        osd.icon = ic
        osd.label = lb
        osd.muted = !!m
        osd.visibleOsd = true
        hideTimer.restart()
    }
    // Volume icon follows level + mute state
    property string volIcon: osd.muted ? "" : osd.value <= 0 ? "" : osd.value <= 33 ? "" : osd.value <= 66 ? "" : ""

    // Poll for external changes (lightweight, 500ms when visible)
    Timer {
        interval: 500
        running: osd.visibleOsd
        repeat: true
        onTriggered: { volProc.running = true; brightProc.running = true }
    }

    Process {
        id: volProc
        command: ["bash", "-c", "out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); echo \"$out\" | grep -oP '\\d+\\.\\d+' | awk '{print int($1*100)}'; echo \"$out\" | grep -q MUTED && echo 1 || echo 0"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                const v = parseInt(lines[0])
                const m = lines.length > 1 && lines[1].trim() === "1"
                if (osd.label === "Volume") {
                    if (!isNaN(v) && Math.abs(v - osd.value) > 2) osd.value = v
                    osd.muted = m
                }
            }
        }
    }
    Process {
        id: brightProc
        command: ["bash", "-c", "brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%' | head -n1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let v = parseInt(this.text.trim())
                if (!isNaN(v) && Math.abs(v - osd.value) > 2 && osd.label === "Brightness") osd.value = v
            }
        }
    }

    // IPC for manual trigger from keybinds/scripts
    IpcHandler {
        target: "osd"
        function showVolume(v: int, m: int) { osd.show(v, "", "Volume", m === 1) }
        function showBrightness(v: int) { osd.show(v, "", "Brightness", false) }
        function hide() { osd.visibleOsd = false }
    }

    // Matugen palette (regenerated on every wallpaper change, watched live)
    FileView {
        path: String(StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace(/^file:\/\//, "") + "/.config/quickshell/matugen-colors.json"
        watchChanges: true
        onFileChanged: reload()
        JsonAdapter {
            id: theme
            property string primary: "#95cdf7"
            property string surface: "#101417"
            property string surface_container: "#1c2024"
            property string on_surface: "#e0e3e8"
            property string outline: "#8b9198"
        }
    }

    function withAlpha(hex: string, a: real): color {
        const r = parseInt(hex.slice(1, 3), 16) / 255
        const g = parseInt(hex.slice(3, 5), 16) / 255
        const b = parseInt(hex.slice(5, 7), 16) / 255
        return Qt.rgba(r, g, b, a)
    }

    Rectangle {
        anchors.centerIn: parent
        width: 200
        height: 34
        radius: 17
        color: withAlpha(theme.surface, 0.55)
        border.width: 0

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8
            Text {
                text: osd.label === "Volume" ? osd.volIcon : osd.icon
                color: osd.muted ? theme.outline : theme.on_surface
                font.pixelSize: 14
                font.family: "JetBrainsMono Nerd Font"
            }
            Rectangle {
                Layout.fillWidth: true
                height: 3
                radius: 2
                color: withAlpha(theme.surface_container, 0.65)
                Rectangle {
                    width: parent.width * (osd.value / 100)
                    height: parent.height
                    radius: parent.radius
                    color: osd.muted ? theme.outline : theme.primary
                }
            }
            Text {
                text: (osd.label === "Volume" && osd.muted) ? "muted" : osd.value + "%"
                color: osd.muted ? theme.outline : theme.on_surface
                font.pixelSize: 10
                font.weight: Font.DemiBold
                Layout.preferredWidth: 28
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
