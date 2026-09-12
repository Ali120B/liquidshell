import QtQuick
import Quickshell
import Quickshell.Io

// Thin index over Quickshell's native desktop-entry database.
// DesktopEntries.applications is already filtered to Type=Application
// entries that are not Hidden / NoDisplay, and DesktopEntry.execute()
// launches them correctly (Exec codes, CWD, Terminal=true).
Item {
    id: root

    property var apps: []
    property bool loaded: false

    // desktop-entry id -> times launched from here. Drives the
    // most-used-first ordering (count desc, name asc).
    property var openCounts: ({})

    signal historyReady()

    Component.onCompleted: refresh()

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            root.refresh()
        }
    }

    FileView {
        id: historyFile
        path: Quickshell.statePath("superlauncher/history.json")
        printErrors: false
        onLoadedChanged: {
            if (loaded)
                root.loadHistory()
        }
    }

    function loadHistory() {
        var counts = {}
        try {
            var obj = JSON.parse(historyFile.text())
            if (obj && typeof obj === "object")
                counts = obj
        } catch (e) {
            counts = {}
        }
        root.openCounts = counts
        root.historyReady()
    }

    function recordLaunch(entry) {
        if (!entry || !entry.id)
            return
        var next = Object.assign({}, openCounts)
        next[entry.id] = (next[entry.id] || 0) + 1
        root.openCounts = next
        try {
            historyFile.setText(JSON.stringify(next))
        } catch (e) {
            console.warn("[Superlauncher] Failed to save history:", e)
        }
    }

    function useCount(entry) {
        return (entry && entry.id && openCounts[entry.id]) || 0
    }

    function compareUsage(a, b) {
        var d = useCount(b) - useCount(a)
        if (d !== 0)
            return d
        return a.name.localeCompare(b.name)
    }

    function refresh() {
        var src = DesktopEntries.applications.values
        var out = []
        for (var i = 0; i < src.length; i++) {
            var e = src[i]
            if (!e || e.noDisplay)
                continue
            if (!e.name || e.name.length === 0)
                continue
            out.push(e)
        }
        out.sort(function (a, b) {
            return a.name.localeCompare(b.name)
        })
        root.apps = out
        root.loaded = true
    }

    function fuzzyMatch(query, text) {
        query = query.toLowerCase()
        text = text.toLowerCase()
        if (text.indexOf(query) >= 0)
            return true
        var qi = 0
        for (var ti = 0; ti < text.length && qi < query.length; ti++) {
            if (text[ti] === query[qi])
                qi++
        }
        return qi === query.length
    }

    function score(query, entry) {
        var q = query.toLowerCase().trim()
        if (q.length === 0)
            return 50
        var name = (entry.name || "").toLowerCase()
        if (name === q)
            return 100
        if (name.indexOf(q) === 0)
            return 80
        if (name.indexOf(q) >= 0)
            return 60
        var generic = (entry.genericName || "").toLowerCase()
        if (generic && generic.indexOf(q) >= 0)
            return 45
        var comment = (entry.comment || "").toLowerCase()
        if (comment && comment.indexOf(q) >= 0)
            return 35
        var exec = (entry.execString || "").toLowerCase()
        if (exec && exec.indexOf(q) >= 0)
            return 25
        var kw = entry.keywords
        if (kw) {
            for (var i = 0; i < kw.length; i++) {
                if ((kw[i] || "").toLowerCase().indexOf(q) >= 0)
                    return 20
            }
        }
        if (fuzzyMatch(q, name))
            return 10
        return -1
    }

    function search(query) {
        if (!loaded)
            return []
        if (!query || query.length === 0)
            return apps.slice().sort(compareUsage)
        var scored = []
        for (var i = 0; i < apps.length; i++) {
            var s = score(query, apps[i])
            if (s >= 0)
                scored.push({ entry: apps[i], score: s })
        }
        scored.sort(function (a, b) {
            if (b.score !== a.score)
                return b.score - a.score
            var d = useCount(b.entry) - useCount(a.entry)
            if (d !== 0)
                return d
            return a.entry.name.localeCompare(b.entry.name)
        })
        var result = []
        for (var j = 0; j < scored.length; j++)
            result.push(scored[j].entry)
        return result
    }
}
