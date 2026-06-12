-- zed.lua – Zed workspace management module.
-- Provides functions to list currently open Zed windows and recent workspaces from the database.

--- ZedWorkspace table structure:
--- {
---   path        = string   -- workspace path on disk (or project name for open windows)
---   display_name = string  -- human-readable name for the chooser
---   active_file = string   -- currently focused file (if deducible from title)
---   is_open     = boolean  -- whether this workspace is currently open
---   timestamp   = number   -- last active time (seconds since epoch, optional)
---   window_id   = number   -- Hammerspoon window id (for open windows, nil otherwise)
--- }

local zed = {}

local spoonPath = hs.spoons.resourcePath("")
local utils = dofile(spoonPath .. "/utils.lua")

-- List currently open Zed windows and return ZedWorkspace entries.
function zed.list_open_zed()
	local app = hs.application.get("Zed")
	if not app then return {} end

	local workspaces = {}
	for _, win in ipairs(app:allWindows()) do
		local title = win:title() or ""

		-- Parse typical "Project — file" format.
		-- Support the em-dash separator, a plain hyphen separator, and titles
		-- that are just a folder name. Fall back to the whole title when no
		-- separator is present so we always get a usable name.
		local project, file = title:match("^(.-)%s+—%s+(.+)$")
		if not project then
			project, file = title:match("^(.-)%s+%-%s+(.+)$")
		end
		if not project then
			project = title
			file = nil
		end

		-- The directory basename is the project folder name (e.g. "jc-hammer"),
		-- not the active file.
		local name = project:match("[^/]+$") or project
		local display = name

		local ws = {
			path         = project,
			name         = name,
			display_name = display,
			active_file  = file,
			is_open      = true,
			timestamp    = nil,
			window_id    = win:id(),
		}
		table.insert(workspaces, ws)
	end
	return workspaces
end

-- List recent Zed projects from the SQLite database.
function zed.list_recent_zed_projects()
	local home = os.getenv("HOME")
	if not home then return {} end
	local db_dir = home .. "/Library/Application Support/Zed/db"
	-- Try to locate the first channel subdir with a db.sqlite file.
	local db_path = nil
	-- hs.fs.dir returns an iterator function AND a directory object (state).
	-- Both must be captured and passed to the generic for loop so the state
	-- object stays alive during iteration.  pcall guards against a missing
	-- or unreadable directory.
	local ok = pcall(function()
		local dir_iter, dir_obj = hs.fs.dir(db_dir)
		for entry in dir_iter, dir_obj do
			if entry:sub(1, 2) == "0-" then -- channel directories like 0-stable, 0-preview
				local candidate = db_dir .. "/" .. entry .. "/db.sqlite"
				local attr = hs.fs.attributes(candidate)
				if attr and attr.mode == "file" then
					db_path = candidate
					break
				end
			end
		end
	end)
	if not ok then
		return {}
	end
	if not db_path then
		return {}
	end

	local sqlite3 = require("hs.sqlite3")
	if not sqlite3 then
		hs.printf("zed: hs.sqlite3 not available")
		return {}
	end

	local db = sqlite3.open(db_path)
	if not db then
		hs.printf("zed: unable to open DB: %s", db_path)
		return {}
	end

	local query = [[
		SELECT
			w.workspace_id,
			w.timestamp,
			w.paths AS workspace_path,
			e.buffer_path AS active_file
		FROM workspaces w
		LEFT JOIN panes p ON p.workspace_id = w.workspace_id
		LEFT JOIN items i ON i.workspace_id = w.workspace_id AND i.pane_id = p.pane_id AND i.active = 1
		LEFT JOIN editors e ON e.workspace_id = i.workspace_id AND e.item_id = i.item_id
		WHERE w.paths IS NOT NULL AND w.paths != ''
		ORDER BY w.timestamp DESC
	]]

	-- Use nrows() so each result row is a table keyed by column name.
	-- db:exec() can yield a non-table result that breaks ipairs/table indexing,
	-- which caused "attempt to index a number value" during iteration.
	local rows = {}
	local ok_query = pcall(function()
		for row in db:nrows(query) do
			table.insert(rows, row)
		end
	end)
	db:close()

	if not ok_query then
		hs.printf("zed: DB query error")
		return {}
	end

	-- Deduplicate by workspace_path, keeping first (most recent) entry.
	local seen = {}
	local workspaces = {}

	for _, row in ipairs(rows) do
		local path = row.workspace_path
		if type(path) == "string" and path ~= "" and not seen[path] then
			seen[path] = true
			-- Strip a trailing slash before deriving the basename so paths like
			-- "/Users/jc/dev/jc-hammer/" still yield "jc-hammer".
			local trimmed_path = path:gsub("/+$", "")
			local basename = trimmed_path:match("[^/]+$") or trimmed_path
			local active_file = row.active_file
			local active_basename = (type(active_file) == "string" and active_file:match("[^/]+$")) or nil
			local ts = utils.parse_timestamp(row.timestamp)
			local ws = {
				path         = path,
				name         = basename,
				display_name = basename,
				active_file  = active_basename,
				is_open      = false,
				timestamp    = ts,
				window_id    = nil,
				match_key    = utils.normalize_match_key(path),
			}
			table.insert(workspaces, ws)
		end
	end

	return workspaces
end

function zed.categorize_workspaces(open_workspaces, recent_entries)
	-- Open windows are first-class: every open window is always included in
	-- the matched_open list, carrying its live window_id for focusing. Recent
	-- DB entries are then merged in, enriching matched open entries (e.g. with
	-- a timestamp) and contributing unmatched entries to remaining_recent.
	local matched_open = {}
	local remaining_recent = {}
	local open_by_key = {}
	local seen_open_keys = {}
	local seen_recent_keys = {}

	-- Build the open entries first, keyed by normalized basename so recent
	-- entries can be matched against them on the same footing.
	for _, open_ws in ipairs(open_workspaces or {}) do
		local key = utils.normalize_match_key(open_ws.path) or open_ws.name or open_ws.display_name
		local ws = {
			path         = open_ws.path,
			name         = open_ws.name or open_ws.display_name,
			display_name = open_ws.display_name,
			active_file  = open_ws.active_file,
			is_open      = true,
			timestamp    = open_ws.timestamp,
			window_id    = open_ws.window_id,
			match_key    = key,
		}

		if key and not seen_open_keys[key] then
			seen_open_keys[key] = true
			open_by_key[key] = ws
			table.insert(matched_open, ws)
		elseif not key then
			-- No usable key; still include so the open window is not lost.
			table.insert(matched_open, ws)
		end
	end

	-- Merge recent entries. If a recent entry matches an open entry by key,
	-- enrich the open entry (notably its timestamp) rather than duplicating.
	for _, recent in ipairs(recent_entries or {}) do
		local key = recent.match_key or utils.normalize_match_key(recent.path)
		local open_match = key and open_by_key[key] or nil

		if open_match then
			-- Carry over a timestamp so open entries can sort by recency.
			if not open_match.timestamp and recent.timestamp then
				open_match.timestamp = recent.timestamp
			end
			-- Prefer a real disk path from the DB over a title-derived one.
			if recent.path and recent.path ~= "" then
				open_match.path = recent.path
			end
			if not open_match.active_file and recent.active_file then
				open_match.active_file = recent.active_file
			end
		else
			if key and not seen_recent_keys[key] then
				seen_recent_keys[key] = true
				local ws = {
					path         = recent.path,
					name         = recent.name or recent.display_name,
					display_name = recent.display_name,
					active_file  = recent.active_file,
					is_open      = false,
					timestamp    = recent.timestamp,
					window_id    = nil,
					match_key    = key,
				}
				table.insert(remaining_recent, ws)
			end
		end
	end

	-- Sort both lists by timestamp descending.
	local function ts_desc(a, b)
		local ta = a.timestamp or 0
		local tb = b.timestamp or 0
		return ta > tb
	end
	table.sort(matched_open, ts_desc)
	table.sort(remaining_recent, ts_desc)

	return matched_open, remaining_recent
end

return zed
