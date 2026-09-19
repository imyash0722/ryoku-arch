pragma ComponentBehavior: Bound;
pragma Singleton;
import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Ui.Singletons

/**
 * DesktopPresets: Automatically saves and restores per-wallpaper desktop presets
 * (widgets, visualizer, stage layering, colors, anchors, and positions).
 *
 * Stored in ~/.config/ryoku/user_edits/desktop_presets/<wallpaper-slug>/
 * Uses the internal ryoku-desktop-preset engine for atomic disk transactions.
 */
Singleton {
    id: root

    readonly property string bin: "ryoku-desktop-preset"
    property string currentWallpaper: ""
    property string currentSlug: ""
    property string switchingTo: ""
    property string pendingWallpaper: ""
    property bool ready: false
    property bool suppressSave: false

    function slugOf(path: string): string {
        if (!path || path.length === 0) return "default";
        const parts = path.split("/");
        const filename = parts[parts.length - 1];
        const dot = filename.lastIndexOf(".");
        const stem = dot > 0 ? filename.substring(0, dot) : filename;
        return stem.replace(/[^\w\-\.]+/g, "-").replace(/-+/g, "-").replace(/^-+|-+$/g, "") || "wallpaper";
    }

    function saveCurrent(): void {
        if (!root.ready || root.currentWallpaper === "" || root.suppressSave || switchProc.running) return;
        if (saveProc.running) return;
        saveProc.command = [root.bin, "save", root.currentWallpaper, "-q"];
        saveProc.running = true;
    }

    function loadCurrent(): void {
        if (root.currentWallpaper.length === 0 || switchProc.running) return;
        autoSaveTimer.stop();
        root.suppressSave = true;
        startSwitch(root.currentWallpaper);
    }

    function resetCurrent(): void {
        if (root.currentWallpaper.length === 0 || switchProc.running) return;
        autoSaveTimer.stop();
        root.suppressSave = true;
        root.switchingTo = root.currentWallpaper;
        root.pendingWallpaper = "";
        switchProc.command = [root.bin, "reset", root.currentWallpaper, "-q"];
        switchProc.running = true;
    }

    function onWallpaperChanged(newWall: string): void {
        const trimmed = (newWall || "").trim();
        if (trimmed.length === 0 || trimmed === root.currentWallpaper)
            return;

        // Immediately cancel any pending auto-save and suppress saves during transition
        autoSaveTimer.stop();
        root.suppressSave = true;

        if (switchProc.running) {
            // A switch is already in flight; queue the latest selection
            root.pendingWallpaper = trimmed;
            return;
        }

        startSwitch(trimmed);
    }

    function startSwitch(targetWall: string): void {
        root.switchingTo = targetWall;
        root.pendingWallpaper = "";
        root.suppressSave = true;

        // If first run or manual reload of current, load directly; otherwise atomically switch outgoing and incoming
        if (root.currentWallpaper.length === 0 || targetWall === root.currentWallpaper) {
            switchProc.command = [root.bin, "load", targetWall, "-q"];
        } else {
            switchProc.command = [root.bin, "switch", root.currentWallpaper, targetWall, "-q"];
        }
        switchProc.running = true;
    }

    function cleanOrphans(): void {
        if (pruneProc.running) return;
        pruneProc.command = [root.bin, "prune", "-q"];
        pruneProc.running = true;
    }

    Process {
        id: switchProc
        onExited: {
            root.currentWallpaper = root.switchingTo;
            root.currentSlug = root.slugOf(root.switchingTo);
            root.switchingTo = "";

            if (root.pendingWallpaper.length > 0 && root.pendingWallpaper !== root.currentWallpaper) {
                const next = root.pendingWallpaper;
                root.pendingWallpaper = "";
                root.startSwitch(next);
            } else {
                root.pendingWallpaper = "";
                suppressTimer.restart();
                pruneTimer.restart();
            }
        }
    }

    Process {
        id: saveProc
    }

    Process {
        id: pruneProc
    }

    Timer {
        id: suppressTimer
        interval: 3000
        onTriggered: {
            root.suppressSave = false;
            root.ready = true;
        }
    }

    Timer {
        id: pruneTimer
        interval: 4000
        onTriggered: {
            root.cleanOrphans();
        }
    }

    // Auto-save debounce timer when widgets or visualizer configs are edited
    Timer {
        id: autoSaveTimer
        interval: 2000
        onTriggered: {
            if (!root.suppressSave && root.ready && !switchProc.running && root.pendingWallpaper.length === 0) {
                const activeWall = (wallFile.text() || "").trim();
                if (activeWall.length > 0 && activeWall === root.currentWallpaper) {
                    root.saveCurrent();
                }
            }
        }
    }

    // Watch active wallpaper file from ryoku/ryogami
    FileView {
        id: wallFile
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku-wallpaper"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const w = (wallFile.text() || "").trim();
            if (w.length > 0) {
                root.onWallpaperChanged(w);
            }
        }
    }

    // Watch widgets.json for live adjustments (drag, color changes, toggles)
    FileView {
        id: widgetsFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/widgets.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: {
            if (!root.suppressSave && root.ready && !switchProc.running && root.pendingWallpaper.length === 0) {
                autoSaveTimer.restart();
            }
        }
    }

    // Watch visualizer.json for live adjustments (bars, styling, placement)
    FileView {
        id: vizFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/visualizer.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: {
            if (!root.suppressSave && root.ready && !switchProc.running && root.pendingWallpaper.length === 0) {
                autoSaveTimer.restart();
            }
        }
    }

    // Watch stage.json for cut-out/depth adjustments
    FileView {
        id: stageFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/stage.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: {
            if (!root.suppressSave && root.ready && !switchProc.running && root.pendingWallpaper.length === 0) {
                autoSaveTimer.restart();
            }
        }
    }

    Component.onCompleted: {
        const w = (wallFile.text() || "").trim();
        if (w.length > 0) {
            root.currentWallpaper = w;
            root.currentSlug = root.slugOf(w);
            root.ready = true;
        }
        cleanOrphans();
    }
}
