-- JC Spoon: quickly switch to a Zed editor window.
-- Press Ctrl+Shift+Cmd+o to open the Zed window chooser.
hs.application.enableSpotlightForNameSearches(true)

-- --- Init Function
local spoonPath = hs.spoons.resourcePath("")

local function init()
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
