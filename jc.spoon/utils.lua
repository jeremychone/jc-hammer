-- jc.lua – helper functions for the JC Spoon.
-- Provides tools for interacting with applications.

-- Parse a timestamp string "YYYY-MM-DD HH:MM:SS" to seconds since epoch.
local function parse_timestamp(ts)
	if not ts then return nil end
	-- Timestamp may be an integer (epoch seconds) or a formatted string.
	if type(ts) == "number" then
		return ts
	end
	if type(ts) ~= "string" then
		return nil
	end
	local year, month, day, hour, min, sec = ts:match("^(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)$")
	if not year then return nil end
	return os.time({
		year = tonumber(year) or 0,
		month = tonumber(month) or 0,
		day = tonumber(day) or 0,
		hour = tonumber(hour),
		min = tonumber(min),
		sec = tonumber(sec)
	})
end

-- Normalize a workspace path into a stable match key. Strips a trailing
-- slash and returns the directory basename so open and recent entries can be
-- compared on the same footing.
local function normalize_match_key(path)
	if not path or path == "" then return nil end
	local trimmed = path:gsub("/+$", "")
	local basename = trimmed:match("[^/]+$") or trimmed
	return basename
end

return {
	parse_timestamp = parse_timestamp,
	normalize_match_key = normalize_match_key,
}
