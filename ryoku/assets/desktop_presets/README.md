# Ryoku Desktop Presets (user_edits overlay)

This folder stores per-wallpaper Quickshell desktop presets.
Because it resides in `~/.config/ryoku/user_edits/`, all presets are fully protected against `ryoku update`, `ryoku materialize`, or system reconciliations.

## Folder Structure

Each wallpaper has its own directory named after its file slug (e.g. `lance-asper--pSOAtdMVlk-unsplash`):

```
~/.config/ryoku/user_edits/desktop_presets/
├── README.md
├── _default/                      <- Baseline template for newly applied wallpapers
│   ├── preset.json
│   ├── widgets.json
│   ├── visualizer.json
│   └── stage.json
└── <wallpaper-slug>/               <- Preset for a specific wallpaper
    ├── preset.json                <- Metadata (wallpaper path, slug, timestamp)
    ├── widgets.json               <- Clock, calendar, music, notes, stats, weather, positions, colors
    ├── visualizer.json            <- Visualizer style, bars, colors, coordinates, extra instances
    └── stage.json                 <- Cutout front/depth layering and motion
```

## How It Works

1. **Automatic Switching**: Whenever the wallpaper changes (via `Super + W`, `Super + Shift + W`, or CLI), Quickshell immediately:
   - Saves the outgoing wallpaper's desktop state into its folder.
   - Loads the incoming wallpaper's preset from this folder.
   - If the new wallpaper has no preset yet, it initializes one using `_default/` or the current layout.
2. **Auto-Save on Edit**: Any widgets moved, visualizers adjusted, or colors changed while viewing a wallpaper automatically update that wallpaper's preset.
3. **Manual CLI Management**:
   ```bash
   ryoku-desktop-preset list                     # View all presets and active status
   ryoku-desktop-preset current                  # View active wallpaper and slug
   ryoku-desktop-preset save                     # Save active layout to current wallpaper
   ryoku-desktop-preset load                     # Reload preset for current wallpaper
   ryoku-desktop-preset copy <source> <target>   # Copy a layout between wallpapers
   ryoku-desktop-preset delete <slug>            # Delete a preset
   ```
