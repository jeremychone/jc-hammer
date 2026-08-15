-- JC Spoon: quickly switch to a Zed editor window.
-- Press Ctrl+Shift+Cmd+o to open the Zed window chooser.

hs.application.enableSpotlightForNameSearches(true)

-- --- Spoon Definition

local obj = {}
obj.__index = obj

obj.name = "jc"
obj.version = "0.1"

-- --- /Spoon Definition

-- Keep focus coordination in one stateful callback so the short Zed activation
-- can select the correct project without leaking handoff state onto the Spoon.
-- The window-specific guard consumes the expected terminal restoration event,
-- while the main-window check avoids a redundant focus round trip and flicker.
local function create_zed_focus_handler(config, zed, term_position_state)
	local term_focus_handoff = nil
	local active_zed_window_id = nil

	return function(win, app_name)
		if app_name == "Zed" then
			active_zed_window_id = win:id()
			if not term_focus_handoff then
				local ws = zed.get_zed_workspace_for_win(config, win)
				if ws and ws.term and ws.term.win then
					ws.term.win:raise()
				end
			end
		elseif app_name == "Alacritty" then
			local term_window_id = win:id()
			if term_focus_handoff and term_focus_handoff.window_id == term_window_id then
				term_focus_handoff = nil
				return
			end

			if term_position_state.request then
				return
			end

			local ws = zed.get_zed_workspace_for_win(config, win)
			if ws and ws.win then
				-- Zed's main window can become temporarily unavailable while a
				-- newly launched terminal activates, so retain the last focused
				-- Zed window as the stable source for this handoff decision.
				if active_zed_window_id == ws.win:id() then
					return
				end

				local zed_app = ws.win:application()
				local zed_main_win = zed_app and zed_app:mainWindow()
				if zed_main_win and zed_main_win:id() == ws.win:id() then
					return
				end

				local handoff = { window_id = term_window_id }
				term_focus_handoff = handoff
				ws.win:focus()

				hs.timer.doAfter(0.05, function()
					if term_focus_handoff == handoff then
						local term_win = hs.window.get(term_window_id)
						if term_win then
							term_win:focus()
						end
					end
				end)

				hs.timer.doAfter(1, function()
					if term_focus_handoff == handoff then
						term_focus_handoff = nil
					end
				end)
			end
		end
	end
end

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

	self.hotkeys.zed_toggle_profile = hs.hotkey.bind(meh, "p", function()
		utils.util_cmd_exec("jc-zed-tasks", "toggle-profile")
	end)

	-- Terminal positioning hotkeys and Zed focus watcher.
	if config.term then
		local cmd_term = dofile(spoon_path .. "/cmd_term.lua")
		local term_position_state = { request = nil }

		local function position_term(options)
			local request = {}
			term_position_state.request = request

			hs.timer.doAfter(1, function()
				if term_position_state.request == request then
					term_position_state.request = nil
				end
			end)

			cmd_term.term_position(options)
		end

		self.hotkeys.term_below = hs.hotkey.bind(meh, "j", function()
			position_term({ mode = "below", auto_open = true })
		end)

		self.hotkeys.term_bottom = hs.hotkey.bind({ "ctrl", "shift", "cmd", "alt" }, "J", function()
			position_term({ mode = "bottom", auto_open = true })
		end)

		-- Keep the filter on self so it is not garbage-collected.
		self.zedFilter = hs.window.filter.new()
		self.zedFilter:subscribe(
			hs.window.filter.windowFocused,
			create_zed_focus_handler(config, zed, term_position_state)
		)
	end
end

return obj
