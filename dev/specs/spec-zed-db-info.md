Goal: Update the Hammerspoon/Zed project picker list.

Need two groups:
1. Open/current Zed workspaces first.
2. Other recent Zed workspaces after that.

Zed app state database path on macOS:

~/Library/Application Support/Zed/db/0-stable/db.sqlite

Relevant tables and schemas discovered:

workspaces:

```sql
CREATE TABLE IF NOT EXISTS "workspaces" (
  workspace_id INTEGER PRIMARY KEY,
  paths TEXT,
  paths_order TEXT,
  remote_connection_id INTEGER REFERENCES remote_connections (id),
  timestamp TEXT DEFAULT CURRENT_TIMESTAMP NOT NULL,
  window_state TEXT,
  window_x REAL,
  window_y REAL,
  window_width REAL,
  window_height REAL,
  display BLOB,
  left_dock_visible INTEGER,
  left_dock_active_panel TEXT,
  right_dock_visible INTEGER,
  right_dock_active_panel TEXT,
  bottom_dock_visible INTEGER,
  bottom_dock_active_panel TEXT,
  left_dock_zoom INTEGER,
  right_dock_zoom INTEGER,
  bottom_dock_zoom INTEGER,
  fullscreen INTEGER,
  centered_layout INTEGER,
  session_id TEXT,
  window_id INTEGER,
  identity_paths TEXT,
  identity_paths_order TEXT
) STRICT;
```

panes:

```sql
CREATE TABLE panes (
  pane_id INTEGER PRIMARY KEY,
  workspace_id INTEGER NOT NULL,
  active INTEGER NOT NULL,
  pinned_count INTEGER DEFAULT 0,
  FOREIGN KEY (workspace_id) REFERENCES workspaces (workspace_id) ON DELETE CASCADE ON UPDATE CASCADE
) STRICT;
```

items:

```sql
CREATE TABLE items (
  item_id INTEGER NOT NULL,
  workspace_id INTEGER NOT NULL,
  pane_id INTEGER NOT NULL,
  kind TEXT NOT NULL,
  position INTEGER NOT NULL,
  active INTEGER NOT NULL,
  preview INTEGER,
  FOREIGN KEY (workspace_id) REFERENCES workspaces (workspace_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (pane_id) REFERENCES panes (pane_id) ON DELETE CASCADE,
  PRIMARY KEY (item_id, workspace_id)
) STRICT;
```

editors:

```sql
CREATE TABLE IF NOT EXISTS "editors" (
  item_id INTEGER NOT NULL,
  workspace_id INTEGER NOT NULL,
  path BLOB,
  scroll_top_row INTEGER NOT NULL DEFAULT 0,
  scroll_horizontal_offset REAL NOT NULL DEFAULT 0,
  scroll_vertical_offset REAL NOT NULL DEFAULT 0,
  contents TEXT,
  language TEXT,
  mtime_seconds INTEGER DEFAULT NULL,
  mtime_nanos INTEGER DEFAULT NULL,
  buffer_path TEXT,
  PRIMARY KEY (item_id, workspace_id),
  FOREIGN KEY (workspace_id) REFERENCES workspaces (workspace_id) ON DELETE CASCADE ON UPDATE CASCADE
) STRICT;
```

Useful query for recent workspaces and active files:

```sql
SELECT
  w.workspace_id,
  w.window_id,
  w.timestamp,
  w.paths AS workspace_path,
  p.pane_id,
  i.item_id,
  i.kind,
  i.active,
  e.buffer_path AS active_file,
  e.language
FROM workspaces w
JOIN panes p ON p.workspace_id = w.workspace_id
JOIN items i ON i.workspace_id = w.workspace_id AND i.pane_id = p.pane_id
LEFT JOIN editors e ON e.workspace_id = i.workspace_id AND e.item_id = i.item_id
WHERE i.active = 1
  AND w.paths IS NOT NULL
  AND w.paths != ''
ORDER BY w.timestamp DESC;
```

Meaning:

- workspaces.paths is the Zed workspace/project path.
- workspaces.timestamp is the last-used timestamp.
- workspaces.window_id is Zed's internal window id, not necessarily the macOS window id.
- editors.buffer_path is the active file path for that workspace/pane.
- Zed does not appear to store a direct "window name" in the DB.
- The visible Zed window title is likely generated dynamically from workspace path + active file.
- Rows with empty paths/buffer_path are probably empty windows or stale records.

Open vs not-open detection:

The SQLite DB alone probably does not reliably say whether a workspace is currently open.
Use Hammerspoon to get currently open Zed windows:

- hs.application.get("Zed")
- app:allWindows()
- each window has win:title(), win:id(), win:isVisible(), win:isMinimized()

Since Zed DB window_id is probably internal and not the same as hs.window:id(), match open windows by title/path heuristics:

1. Query DB rows ordered by timestamp DESC.
2. Get all current Zed window titles from Hammerspoon.
3. For each DB workspace:
   - project_name = basename(workspace_path)
   - active_file_name = basename(active_file), if active_file exists
4. Treat a workspace as open if a Zed window title contains:
   - project_name, or
   - active_file_name, or
   - both project_name and active_file_name
5. Put matched rows in the "open" group.
6. Put remaining rows in the "recent/not open" group.
7. Deduplicate by workspace_path.
8. Sort each group by timestamp DESC.

Example DB result observed:

```
workspace_id  window_id     timestamp            workspace_path                              active_file
14            21474836484   2026-06-12 22:57:01  /Users/user/code/my-project                 /Users/user/code/my-project/.gitignore
10            12884901890   2026-06-12 22:52:35  /Users/user/notes                           /Users/user/notes/.ssh/config
9             12884901889   2026-06-12 22:43:55  /Users/user/code/my-sandbox                 /Users/user/code/my-sandbox/.prompt/proof-prompt.md
```

Desired picker structure:

Open Zed windows:
- my-project — .gitignore
- notes — config
- my-sandbox — proof-prompt.md

Recent Zed projects:
- any remaining workspace paths from the DB not detected as currently open

Important caveats:

- Do not rely on workspaces.window_id matching Hammerspoon/macOS window ids.
- Do not rely on a direct window title column; none was found.
- Use timestamp for recency.
- Use workspace_path as the stable unique project key.
- Use active_file only as display/helpful context.
