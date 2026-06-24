-- JC Spoon: quickly switch to a Zed editor window.
-- Press Ctrl+Shift+Cmd+o to open the Zed window chooser.

hs.application.enableSpotlightForNameSearches(true)

-- --- Spoon Definition

local obj = {}
obj.__index = obj

obj.name = "jc"
obj.version = "0.1"

-- --- /Spoon Definition

function obj:init()
	local spoon_path = hs.spoons.resourcePath("")

	-- Setup .user/ directory with default files
	-- note: might do it on key press to be more resilient
	local setup = dofile(spoon_path .. "/setup.lua")
	setup.setup_user_dir(spoon_path)

	-- Load configuration
	local utils = dofile(spoon_path .. "/utils.lua")
	local config = utils.load_config(spoon_path)
	local zed = dofile(spoon_path .. "/zed.lua")

	self.config = config
	self.zed = zed
	self.hotkeys = self.hotkeys or {}

	-- The "meh" modifier combo.
	local meh = { "ctrl", "shift", "cmd" }

	-- Chooser that picks a currently open Zed window and focuses it.
	self.hotkeys.zed_picker = hs.hotkey.bind(meh, "o", function()
		local cmd_zed_picker = dofile(spoon_path .. "/cmd_zed_picker.lua")
		cmd_zed_picker.show_zed_picker(config)
	end)

	-- Terminal positioning hotkeys and Zed focus watcher.
	if config.term then
		local cmd_term = dofile(spoon_path .. "/cmd_term.lua")

		self.hotkeys.term_below = hs.hotkey.bind(meh, "j", function()
			cmd_term.term_position({ mode = "below", auto_open = true })
		end)

		self.hotkeys.term_bottom = hs.hotkey.bind({ "ctrl", "shift", "cmd", "alt" }, "J", function()
			cmd_term.term_position({ mode = "bottom", auto_open = true })
		end)

		-- Keep the filter on self so it is not garbage-collected.
		self.zedFilter = hs.window.filter.new()

		self.zedFilter:subscribe(hs.window.filter.windowFocused, function(win, app_name)
			if app_name == "Zed" then
				local ws = zed.get_zed_workspace_for_win(config, win)
				if ws and ws.term and ws.term.win then
					ws.term.win:raise()
				end
			end
		end)
	end
end

return obj
