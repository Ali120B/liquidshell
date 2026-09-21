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

    // Lazy: only load RegionSelector when actually triggered (Super+Shift+S etc.)
    // Saves ~30ms startup and keeps idle 0% (no regionSelector bindings when closed)
    Loader {
        active: GlobalStates.regionSelectorOpen
        sourceComponent: RegionSelector {}
    }

    // Keep GlobalStates always alive for the active check
    GlobalStates { id: globalStates }
}
