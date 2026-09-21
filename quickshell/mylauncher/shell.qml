import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtCore

// mylauncher: one-shot wofi/rofi clone. Run -> pick -> quit. No daemon, no animations.
ShellRoot {
  id: root
  property string query: ""
  property var filtered: []
  property int selected: 0
  property bool open: false

  // Resident daemon, instant toggle:
  //   quickshell ipc -p ~/.config/quickshell/mylauncher call mylauncher toggle
  IpcHandler {
    target: "mylauncher"

    function toggle() { root.open = !root.open }
    function open() { root.open = true }
    function hide() { root.open = false }
    function isVisible() { return root.open }
  }

  onOpenChanged: {
    if (open) {
      filterTimer.stop()
      input.text = ""
      root.query = ""
      applyFilter()
      Qt.callLater(function () { input.forceActiveFocus() })
    } else {
      input.focus = false
    }
  }

  AppProvider {
    id: appProvider
    onLoadedChanged: { if (loaded) root.applyFilter() }
    onAppsChanged: root.applyFilter()
    onHistoryReady: root.applyFilter()
  }

  function applyFilter() {
    root.filtered = appProvider.search(root.query)
    root.selected = 0
    appList.currentIndex = 0
    if (appList.count > 0)
      appList.positionViewAtBeginning()
  }

  onQueryChanged: filterTimer.restart()

  // One filter pass per typing burst, not per keystroke.
  Timer {
    id: filterTimer
    interval: 80
    repeat: false
    onTriggered: root.applyFilter()
  }
  onSelectedChanged: {
    if (selected >= 0 && selected < appList.count)
      appList.currentIndex = selected
  }

  function launch(entry) {
    if (!entry)
      return
    appProvider.recordLaunch(entry)
    entry.execute()
    root.open = false
  }

  function launchSelected() {
    // Type-then-Enter in one motion: flush the pending filter first.
    if (filterTimer.running) {
      filterTimer.stop()
      applyFilter()
    }
    if (selected >= 0 && selected < filtered.length)
      launch(filtered[selected])
  }

  // Icon resolution: gate theme names behind hasThemeIcon
  // (missing ones render a placeholder, not an error).
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

  property var _iconChainCache: ({})

  function iconChain(entry) {
    var name = (entry && entry.icon) || ""
    if (name !== "" && _iconChainCache[name] !== undefined)
      return _iconChainCache[name]
    var out = []
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
    if (name !== "")
      _iconChainCache[name] = out
    return out
  }

  PanelWindow {
    id: win
    implicitWidth: 360
    implicitHeight: 470
    color: "transparent"
    visible: root.open

    // No anchors = floating, centered on screen (rofi-style).
    focusable: true
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell:mylauncher"

    HyprlandFocusGrab {
      active: true
      windows: [win]
      onCleared: root.open = false
    }

    // Backup: Esc quits even if the input somehow loses focus.
    Shortcut {
      sequence: "Escape"
      context: Qt.WindowShortcut
      onActivated: root.open = false
    }

    Rectangle {
      anchors.fill: parent
      radius: 14
      color: "#A8141414"
      border.width: 1
      border.color: "#14FFFFFF"

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 40
          radius: 12
          color: "#14FFFFFF"
          border.width: 1
          border.color: "#1FFFFFFF"

          TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            verticalAlignment: TextInput.AlignVCenter
            color: "#8AB4FF"
            font.pixelSize: 15
            focus: true
            cursorVisible: true
            clip: true
            onTextChanged: root.query = text
            Component.onCompleted: forceActiveFocus()
            Keys.onPressed: function (event) {
              var last = Math.max(root.filtered.length - 1, 0)
            if (event.key === Qt.Key_Escape) {
              root.open = false
              event.accepted = true
              } else if (event.key === Qt.Key_Down) {
                root.selected = Math.min(root.selected + 1, last)
                event.accepted = true
              } else if (event.key === Qt.Key_Up) {
                root.selected = Math.max(root.selected - 1, 0)
                event.accepted = true
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.launchSelected()
                event.accepted = true
              }
            }

            Text {
              anchors.fill: parent
              verticalAlignment: Text.AlignVCenter
              text: "search"
              color: "#55FFFFFF"
              font.pixelSize: 15
              visible: input.text.length === 0
            }
          }
        }

        ListView {
          id: appList
          Layout.fillWidth: true
          Layout.fillHeight: true
          model: root.filtered
          boundsBehavior: Flickable.StopAtBounds
          // Lean list: no offscreen delegate hoard, pooled delegates.
          cacheBuffer: 0
          reuseItems: true
          // No momentum: wheel/drag stops dead instead of gliding.
          flickDeceleration: 15000
          maximumFlickVelocity: 800
          pixelAligned: true
          clip: true
          highlightFollowsCurrentItem: true
          // Tight tracking: no trailing glide after key release.
          highlightMoveDuration: 120
          highlight: Rectangle { radius: 8; color: "#2AFFFFFF" }

          delegate: Item {
            required property var modelData
            required property int index
            width: appList.width
            height: 44

            property bool isCurrent: index === root.selected
            // Hover is visual-only: it never moves keyboard selection,
            // so a parked cursor can't fight arrow-key nav.
            Rectangle {
              anchors.fill: parent
              radius: 8
              color: "#14FFFFFF"
              visible: rowMouse.containsMouse && !isCurrent
            }
            property var iconCandidates: root.iconChain(modelData)
            property int iconIdx: 0
            property bool iconExhausted: iconCandidates.length === 0

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 16
              anchors.rightMargin: 12
              spacing: 10

              IconImage {
                id: appIcon
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                asynchronous: true
                source: iconCandidates.length > 0 ? iconCandidates[0] : ""
                visible: !iconExhausted
                onStatusChanged: {
                  if (status === Image.Error) {
                    var next = iconIdx + 1
                    if (next < iconCandidates.length) {
                      iconIdx = next
                      source = iconCandidates[next]
                    } else {
                      iconExhausted = true
                    }
                  }
                }
              }
              Text {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: ((modelData.name || "?").charAt(0) || "?").toUpperCase()
                color: "#70FFFFFF"
                font.pixelSize: 15
                font.bold: true
                visible: iconExhausted
              }

              Text {
                Layout.fillWidth: true
                text: modelData.name
                color: "#FFFFFF"
                font.pixelSize: 14
                elide: Text.ElideRight
              }
            }

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.launch(modelData)
            }
          }
        }
      }
    }
  }
}
