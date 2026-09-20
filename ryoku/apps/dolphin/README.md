# dolphin

The default graphical file manager for Ryoku.

Dolphin provides native Qt/KDE integration, Matugen theming via `~/.config/dolphin/dolphin.qss`, KIO protocol support (including `admin://` via `kio-admin` and `sftp://`), and KDE Service Menus for right-click actions.

## Context Menus (Service Menus)

Ryoku ships two Dolphin service menus installed under `/usr/share/kio/servicemenus/` (or `~/.local/share/kio/servicemenus/`):
- `ryoku-stash-install.desktop`: Right-click installer for AppImages, Flatpak bundles, Debian packages, and archives.
- `ryoku-stash-compress.desktop`: Right-click media compressor for videos and images.
