import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// OSD — simple translucent bottom-center for brightness/volume, themed by matugen
// Listens to wpctl and brightnessctl via polling, shows on change
PanelWindow {
    id: osd
    property int value: 0 // 0-100
    property string icon: ""
    property string label: "Volume"
    property bool visibleOsd: false
    property int hideDelay: 1500
    visible: visibleOsd
    color: "transparent"
    anchors { bottom: true; left: true; right: true }
    margins { bottom: 40 }
    implicitWidth: 260
    implicitHeight: 48
    // Center the OSD horizontally — small bottom-center
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
    function show(v, ic, lb) {
        osd.value = v
        osd.icon = ic
        osd.label = lb
        osd.visibleOsd = true
        hideTimer.restart()
    }

    // Poll for external changes (lightweight, 500ms when visible)
    Timer {
        interval: 500
        running: osd.visibleOsd
        repeat: true
        onTriggered: { volProc.running = true; brightProc.running = true }
    }

    Process {
        id: volProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -oP '\\d+\\.\\d+' | awk '{print int($1*100)}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let v = parseInt(this.text.trim())
                if (!isNaN(v) && Math.abs(v - osd.value) > 2 && osd.label === "Volume") osd.value = v
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
        function showVolume(v: int) { osd.show(v, "", "Volume") }
        function showBrightness(v: int) { osd.show(v, "", "Brightness") }
        function hide() { osd.visibleOsd = false }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 16
        height: 42
        radius: 14
        color: "#1e1e2eCC"
        border.color: "#ffffff0F"
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10
            Text {
                text: osd.icon
                color: "#cdd6f4"
                font.pixelSize: 16
                font.family: "JetBrainsMono Nerd Font"
            }
            Rectangle {
                Layout.fillWidth: true
                height: 4
                radius: 2
                color: "#313244"
                Rectangle {
                    width: parent.width * (osd.value / 100)
                    height: parent.height
                    radius: parent.radius
                    color: "#cdd6f4"
                }
            }
            Text {
                text: osd.value + "%"
                color: "#cdd6f4"
                font.pixelSize: 11
                font.weight: Font.Medium
                Layout.preferredWidth: 32
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
