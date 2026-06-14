# Spec: Alacritty Terminal Integration (term.lua)

## Intent

Provide a Hammerspoon spoon (`jc.spoon/term`) that opens or focuses an Alacritty terminal window paired with the currently active Zed editor project. The pairing is based on the project directory basename. Two layout modes are supported: placing the terminal directly below the editor window (“below”), or pinning it to the bottom edge of the screen (“bottom”). The functionality is triggered by a global hotkey (`Cmd+Ctrl+Shift+T`).

## Code Design

### Module: `jc.spoon/term.lua`

The module depends on `jc.spoon.zed` for retrieving information about the active Zed workspace.

Core functions:

| Function                                         | Description                                                                                                  |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| `term.list_open_alacritty()`                     | Return all open Alacritty windows, each as `{ title, bounds, window_id }`.                                   |
| `term.find_terminal_by_basename(basename)`       | Return the first Alacritty window whose title matches `basename` exactly, or `nil`.                          |
| `term.get_active_zed_workspace()`                | Return `{ path, basename }` for the currently focused Zed window, or `nil`.                                  |
| `term.open_new_terminal(project_path, basename)` | Launch a new Alacritty window with `--working-directory` and `--title`.                                      |
| `term.position(zed_win, term_win, position)`      | Position terminal based on `position`: `"below"` (directly below Zed, sharing x/width) or `"bottom"` (bottom screen edge, full width). Both use 30% height. |
| `term.focus_or_open(zed_workspace, mode)`        | Orchestrate: find and focus a matching terminal, or open new and position.                                   |
| `term.open_terminal_for_active_project(mode)`    | Convenience for active Zed window: `get_active_zed_workspace()` + `focus_or_open`.                           |
| `term.bind_hotkey()`                             | Register global hotkey `Cmd+Ctrl+Shift+T` to trigger `open_terminal_for_active_project` with a default mode. |

### Data flow

1. Hotkey triggers `open_terminal_for_active_project`.
2. It calls `get_active_zed_workspace()` to obtain `path` and `basename` from the focused Zed window.
3. `focus_or_open` is called with the workspace and mode:
   - Call `find_terminal_by_basename(basename)`.
   - If found, focus that window (no repositioning).
   - If not found, call `open_new_terminal(path, basename)`, wait for the window to appear, then call `position(zed_win, term_win, mode)` where mode is `"below"` or `"bottom"`.

### Launch command

```bash
open -na Alacritty --args --working-directory "<path>" --title "<basename>"
```

Executed via `hs.execute`.

### Window management

Uses Hammerspoon’s `hs.window` module to find windows by application name (“Alacritty”) and to get/set frames. Frame calculations account for menu bar and available screen area.

## Design Considerations

- **Matching simplicity**: Uses exact basename match on the window title. No disambiguation for name collisions; the first match wins.
- **No environment sourcing**: The terminal opens directly in the project directory; no extra environment setup (nix-shell, direnv) is performed.
- **No repositioning on existing match**: When a matching terminal already exists, it is only focused (brought to front) without moving it, preserving any custom layout the user may have arranged.
- **Layout modes**: Two modes cover common workflows: “below” keeps the terminal attached to the editor window (moves with it if the editor is moved), while “bottom” always occupies the full width screen bottom, providing a consistent panel.
- **Hotkey isolation**: Using a separate, dedicated hotkey (`Cmd+Ctrl+Shift+T`) avoids interference with the existing Zed chooser workflow.
