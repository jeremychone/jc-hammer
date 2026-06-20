-- JC Spoon: quickly switch to a Zed editor window.
-- Press Ctrl+Shift+Cmd+o to open the Zed window chooser.
hs.application.enableSpotlightForNameSearches(true)

-- --- Init Function
local spoon_path = hs.spoons.resourcePath("")

local function init()
	-- Setup .user/ directory with default files
	-- (note: might do it on key press to be more resilient)
	local setup = dofile(spoon_path .. "/setup.lua")
	setup.setup_user_dir(spoon_path)

	-- Load configuration (user or default)
	local utils = dofile(spoon_path .. "/utils.lua")
	local config = utils.load_config(spoon_path)

	-- The "meh" modifier combo. Change this if you want a different chord.
	local meh = { "ctrl", "shift", "cmd" }

	-- Chooser that pick a currently open zed window and get the focus to it.
	hs.hotkey.bind(meh, "o", function()
		local cmd_zed_picker = dofile(spoon_path .. "/cmd_zed_picker.lua")
		cmd_zed_picker.show_zed_picker(config)
	end)

	-- Terminal positioning hotkeys (below / bottom) when enabled in config.
	if config.term then
		local cmd_term = dofile(spoon_path .. "/cmd_term.lua")
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
