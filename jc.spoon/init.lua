-- JC Spoon: quickly switch to a Zed editor window.
-- Press Ctrl+Shift+Cmd+o to open the Zed window chooser.
hs.application.enableSpotlightForNameSearches(true)

-- --- Init Function
local spoonPath = hs.spoons.resourcePath("")

-- --- Initialize .user/ directory with default files if not present
local function init_user_dir(spoonPath)
	local userDir = spoonPath .. "/.user"
	-- Create .user directory if it doesn't exist
	if hs.fs.attributes(userDir) == nil then
		hs.fs.mkdir(userDir)
	end

	-- Helper to copy file only if destination does not exist
	local function copyIfNotExists(src, dest)
		if hs.fs.attributes(dest) == nil then
			-- hs.fs.copy does not exist; use io to copy file contents
			local f_in = io.open(src, "rb")
			if f_in then
				local content = f_in:read("*a")
				f_in:close()
				local f_out = io.open(dest, "wb")
				if f_out then
					f_out:write(content)
					f_out:close()
				end
			end
		end
	end

	-- Copy config_default.lua to .user/config_user.lua
	local configDefaultPath = spoonPath .. "/config_default.lua"
	local configUserPath = userDir .. "/config_user.lua"
	copyIfNotExists(configDefaultPath, configUserPath)

	-- Copy templates/profiles.json to .user/profiles.json
	local profilesTemplatePath = spoonPath .. "/templates/profiles.json"
	local profilesUserPath = userDir .. "/profiles.json"
	copyIfNotExists(profilesTemplatePath, profilesUserPath)

	-- Copy templates/profile_current.json to .user/profile_current.json
	local currentProfileTemplatePath = spoonPath .. "/templates/profile_current.json"
	local currentProfileUserPath = userDir .. "/profile_current.json"
	copyIfNotExists(currentProfileTemplatePath, currentProfileUserPath)
end

local function init()
	-- Initialize .user/ directory with default files
	init_user_dir(spoonPath)

	-- Load configuration (user or default)
	local utils = dofile(spoonPath .. "/utils.lua")
	local config = utils.load_config(spoonPath)

	-- The "meh" modifier combo. Change this if you want a different chord.
	local meh = { "ctrl", "shift", "cmd" }

	-- Chooser that pick a currently open zed window and get the focus to it.
	hs.hotkey.bind(meh, "o", function()
		local cmd_zed_picker = dofile(spoonPath .. "/cmd_zed_picker.lua")
		cmd_zed_picker.show_zed_picker(config)
	end)

	-- Terminal positioning hotkeys (below / bottom) when enabled in config.
	if config.term then
		local cmd_term = dofile(spoonPath .. "/cmd_term.lua")
		hs.hotkey.bind({ "ctrl", "shift", "cmd" }, "p", function()
			cmd_term.term_position({ mode = "below" })
		end)
		hs.hotkey.bind({ "ctrl", "shift", "cmd", "alt" }, "P", function()
			cmd_term.term_position({ mode = "bottom" })
		end)
	end
end

-- --- /Init Function

-- --- Spoon Definition

local obj = {}
obj.__index = obj

obj.name = "jc"
obj.version = "0.1"

-- Delegate setup to the init() function defined above.
function obj:init()
	init()
end

-- --- /Spoon Definition

return obj
