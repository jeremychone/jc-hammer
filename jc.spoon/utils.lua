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

-- Execute a shell command with a configured PATH environment.
local function util_cmd_exec(cmd, args)
	local full_cmd = cmd
	if type(args) == "table" then
		local parts = {}
		for _, arg in ipairs(args) do
			table.insert(parts, string.format("%q", tostring(arg)))
		end
		if #parts > 0 then
			full_cmd = full_cmd .. " " .. table.concat(parts, " ")
		end
	elseif type(args) == "string" and args ~= "" then
		full_cmd = full_cmd .. " " .. args
	end
	local env_prefix = "export PATH=\"$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH\"; "
	return hs.execute(env_prefix .. full_cmd)
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

-- Load user config if present, otherwise default config.
local function load_config(spoonPath)
	local user_path = spoonPath .. "/.user/config_user.lua"
	local default_path = spoonPath .. "/config_default.lua"
	local ok, result = pcall(dofile, user_path)
	if ok and result then
		return result
	end
	return dofile(default_path)
end

return {
	parse_timestamp = parse_timestamp,
	normalize_match_key = normalize_match_key,
	load_config = load_config,
	util_cmd_exec = util_cmd_exec,
	cmd_exec = util_cmd_exec,
}
