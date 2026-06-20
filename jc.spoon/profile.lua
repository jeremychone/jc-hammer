-- profile.lua – profile management for the JC Spoon.
-- Loads the current terminal profile dimensions from user configuration.

-- Read and decode a JSON file, returning the decoded table or nil on error.
local function read_json(path)
	local file = io.open(path, "r")
	if not file then return nil end
	local content = file:read("*a")
	file:close()
	if not content then return nil end
	local ok, result = pcall(hs.json.decode, content)
	if not ok then return nil end
	return result
end

-- Load the terminal dimensions for the active profile.
-- Returns { width = ..., height = ... } or nil if the profile cannot be loaded.
local function load_profile(spoon_path)
	local profiles = read_json(spoon_path .. "/.user/profiles.json")
	if not profiles then return nil end
	local current = read_json(spoon_path .. "/.user/profile_current.json")
	if not current or not current.current_profile then return nil end
	local profile_name = current.current_profile
	local profile = profiles[profile_name]
	if not profile or not profile.terminal_dims then return nil end
	return {
		width = profile.terminal_dims.width,
		height = profile.terminal_dims.height
	}
end

return {
	load_profile = load_profile,
}
