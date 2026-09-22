//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import "./hypr-lens"
import "./hypr-lens/modules/common"
import "./hypr-lens/modules/common/functions"
import "./hypr-lens/modules/common/widgets"
import "./hypr-lens/modules/regionSelector"
import "./hypr-lens/services"

import QtQuick
import Quickshell
import Quickshell.Hyprland

ShellRoot {
    id: root

    RegionSelector {
        id: regionSelector
    }

    // Bottom-center translucent OSD for volume/brightness (matugen-themed)
    // Trigger: quickshell ipc -p ~/.config/quickshell call osd showVolume 42
    Loader {
        source: "./osd.qml"
        active: true
    }
}
