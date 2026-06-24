-- Spoon: jc.spoon/cmd_term.lua
-- Terminal positioning commands for Zed projects.

local obj = {}

local spoonPath = hs.spoons.resourcePath("")
local zed = dofile(spoonPath .. "/zed.lua")
local term = dofile(spoonPath .. "/term.lua")
local profile = dofile(spoonPath .. "/profile.lua")

function obj.term_position(params)
	local mode
	if type(params) == "string" then
		mode = params
	elseif type(params) == "table" then
		mode = params.mode
	end

	if mode ~= "below" and mode ~= "bottom" then
		hs.alert("Invalid mode: " .. tostring(mode))
		return
	end

	local ws = zed.get_current_zed({ term = true })
	if not ws then
		return
	end

	local auto_open = (type(params) == "table" and params.auto_open) or false

	local is_new = false

	local term_win = ws.term and ws.term.win

	if not term_win then
		if auto_open and ws.path and ws.basename then
			local project_path = ws.path

			-- Resolve the full path from recent workspaces if the current path is not absolute
			if not project_path:match("^/") then
				local full = zed.resolve_project_path(ws.basename)
				if full then
					project_path = full
				end
			end

			local apps = hs.application.applicationsForBundleID("org.alacritty")
			local is_alacritty_proc_running = apps and apps[1] and true or false

			local alacritty_bin = nil
			-- Locate the Alacritty app via bundle ID; fall back to the default path.
			local app_path = hs.application.pathForBundleID("org.alacritty")
			if app_path then
				alacritty_bin = app_path .. "/Contents/MacOS/alacritty"
			else
				alacritty_bin = "/Applications/Alacritty.app/Contents/MacOS/alacritty"
			end

			local title = "zed term - " .. project_path
			local core_cmd = string.format(
				"--title %q --working-directory %q -e /opt/homebrew/bin/tmux new-session",
				title,
				project_path
			)

			local cmd
			if is_alacritty_proc_running then
				-- This will use the IPC way
				cmd = string.format(
					"%q msg create-window %s",
					alacritty_bin,
					core_cmd
				)
			else
				cmd = string.format(
					"nohup %q %s >/dev/null 2>&1 &",
					alacritty_bin,
					core_cmd
				)
			end

			local proc = hs.execute(cmd)

			term_win = term.find_terminal_by_basename(ws.basename)

			if term_win == nil then
				-- -- Wait for the window to appear
				local start_time = hs.timer.secondsSinceEpoch()
				while true do
					term_win = term.find_terminal_by_basename(ws.basename)
					if term_win then break end
					if hs.timer.secondsSinceEpoch() - start_time > 1 then
						hs.alert("Terminal did not open in time")
						return
					end
					hs.timer.usleep(100000)
				end
			end

			is_new = true
		else
			hs.alert("No terminal found")
			return
		end
	end

	if not term_win then
		return {}
	end

	-- term_win:focus()
	-- hs.eventtap.keyStrokes("tmux\n")

	-- Load profile dimensions, fall back to current size if unavailable
	local dims = profile.load_profile(spoonPath)
	local zed_frame = ws.win:frame()
	local term_frame = term_win:frame()
	local new_w = term_frame.w
	local new_h = term_frame.h
	if dims then
		new_w = dims.width
		new_h = dims.height
	end

	local duration = is_new and 0.1 or 0.2
	if mode == "below" then
		local new_x = zed_frame.x + (zed_frame.w / 2) - (new_w / 2)
		local new_y = zed_frame.y + zed_frame.h + 4
		term_win:setFrame(hs.geometry.rect(new_x, new_y, new_w, new_h), duration)
	elseif mode == "bottom" then
		local margin = 4
		local new_x = zed_frame.x + (zed_frame.w / 2) - (new_w / 2)
		local new_y = zed_frame.y + zed_frame.h - margin - new_h
		term_win:setFrame(hs.geometry.rect(new_x, new_y, new_w, new_h), duration)
	end

	term_win:focus()
end

return obj
