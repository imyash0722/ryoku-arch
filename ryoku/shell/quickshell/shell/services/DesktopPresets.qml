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
        if (!root.ready || root.currentWallpaper === "" || root.suppressSave) return;
        saveProc.command = [root.bin, "save", root.currentWallpaper, "-q"];
        saveProc.running = false;
        saveProc.running = true;
    }

    function loadCurrent(): void {
        if (root.currentWallpaper === "") return;
        root.suppressSave = true;
        loadProc.command = [root.bin, "load", root.currentWallpaper, "-q"];
        loadProc.running = false;
        loadProc.running = true;
        suppressTimer.restart();
    }

    function cleanOrphans(): void {
        pruneProc.command = [root.bin, "prune", "-q"];
        pruneProc.running = false;
        pruneProc.running = true;
    }

    function onWallpaperChanged(newWall: string): void {
        const trimmed = (newWall || "").trim();
        if (trimmed.length === 0 || trimmed === root.currentWallpaper)
            return;

        // Save layout for outgoing wallpaper if initialized
        if (root.ready && root.currentWallpaper.length > 0 && !root.suppressSave) {
            Quickshell.execDetached([root.bin, "save", root.currentWallpaper, "-q"]);
        }

        root.currentWallpaper = trimmed;
        root.currentSlug = root.slugOf(trimmed);

        // Load preset for new wallpaper
        root.suppressSave = true;
        loadProc.command = [root.bin, "load", trimmed, "-q"];
        loadProc.running = false;
        loadProc.running = true;
        suppressTimer.restart();

        // Prune any stale presets for deleted wallpapers
        cleanOrphans();
    }

    Process {
        id: saveProc
    }

    Process {
        id: loadProc
        onExited: {
            suppressTimer.restart();
        }
    }

    Process {
        id: pruneProc
    }

    Timer {
        id: suppressTimer
        interval: 1200
        onTriggered: {
            root.suppressSave = false;
            root.ready = true;
        }
    }

    // Auto-save debounce timer when widgets or visualizer configs are edited
    Timer {
        id: autoSaveTimer
        interval: 1000
        onTriggered: {
            if (!root.suppressSave && root.ready && root.currentWallpaper.length > 0) {
                root.saveCurrent();
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
            if (!root.suppressSave && root.ready) {
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
            if (!root.suppressSave && root.ready) {
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
            if (!root.suppressSave && root.ready) {
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
