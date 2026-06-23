local spoonPath = hs.spoons.resourcePath("")

local zed = dofile(spoonPath .. "/zed.lua")
local term = dofile(spoonPath .. "/term.lua")

local DEBUG = false

-- === Load assets
local IMAGE_OPENED = hs.image.imageFromPath(spoonPath .. "/images/ico-opened.png")
local IMAGE_CLOSED = hs.image.imageFromPath(spoonPath .. "/images/ico-closed.png")
local IMAGE_OPENED_TERM = hs.image.imageFromPath(spoonPath .. "/images/ico-opened-term.png")
local IMAGE_CLOSED_TERM = hs.image.imageFromPath(spoonPath .. "/images/ico-closed-term.png")


local function build_choices(...)
	local choices = {}
	for _, list in ipairs({ ... }) do
		for _, ws in ipairs(list) do
			local text = (ws.name or ws.display_name or ws.path)
			local image = ws.is_open and IMAGE_OPENED or IMAGE_CLOSED
			if ws.term then
				image = ws.is_open and IMAGE_OPENED_TERM or IMAGE_CLOSED_TERM
			end
			table.insert(choices, {
				text = text,
				subText = ws.path,
				image = image,
				data = ws,
			})
		end
	end
	return choices
end

local function apply_term(...)
	local term_list = term.list_zed_terms()
	local term_by_path = {}
	for _, t in ipairs(term_list) do
		if t.path and t.path ~= "" then
			term_by_path[t.path:gsub("/+$", "")] = t
		end
	end
	for _, workspaces in ipairs({ ... }) do
		for _, ws in ipairs(workspaces) do
			if ws.path then
				local normalized = ws.path:gsub("/+$", "")
				local term_info = term_by_path[normalized]
				if term_info then
					ws.term = term_info
				end
			end
		end
	end
end


local function refresh_chooser(chooser_inst, config)
	local new_open_ws = zed.list_open_zed()
	local new_recent_ws = zed.list_recent_zed_projects()
	local new_matched, new_remaining = zed.categorize_workspaces(new_open_ws, new_recent_ws)

	if config.term then
		apply_term(new_matched, new_remaining)
	end

	local new_choices = build_choices(new_matched, new_remaining)
	chooser_inst:choices(new_choices)
	-- Reset the query to show all refreshed choices
	chooser_inst:query("")
end

local function refocus(win)
	hs.timer.doAfter(0.1, function()
		win:focus()
	end)
end

local function wks_open(ws)
	hs.execute("open -a Zed '" .. ws.path .. "'")
end

local function wks_focus(ws)
	local win = ws.window_id and hs.window.get(ws.window_id)
	local win_term = ws.term and ws.term.win
	if win_term then
		ws.term.win:focus()
	end
	if win then
		win:focus()
	end
end

local function wks_close(ws)
	local win = ws.window_id and hs.window.get(ws.window_id)
	local win_term = ws.term and ws.term.win

	if win then
		win:close()
	end

	-- send the tmux jc close session command
	if win_term then
		local prev_focused_win = hs.window.focusedWindow()

		win_term:focus()
		hs.eventtap.keyStroke({ "ctrl" }, "k")
		hs.timer.usleep(10000)
		hs.eventtap.keyStroke({ "shift" }, "X")

		if prev_focused_win then
			prev_focused_win:focus()
		end
	end
end


local function show_zed_picker(config)
	-- === Debug: list zed terms
	if DEBUG and config.term then
		local dev_terms = term.list_zed_terms()
		print("--- DEBUG START Zed Terms ---")
		for i, t in ipairs(dev_terms) do
			print(i .. " title: " .. t.title .. "\npath: " .. t.path .. "\nid: " .. t.win:id() .. "\nwin:", t.win)
		end
		print("--- DEBUG END   Zed Terms ---")
	end

	-- === Get the zed info
	local open_ws = zed.list_open_zed()
	local recent_ws = zed.list_recent_zed_projects()
	local matched, remaining = zed.categorize_workspaces(open_ws, recent_ws)
	local current_win = hs.window.focusedWindow()

	-- === Debug
	if DEBUG then
		print("--- DEBUG START Zed Workspace Picker Debug ---")
		print("Open workspaces (raw):")
		for i, ws in ipairs(open_ws) do
			print("- " .. ws.path)
		end
		print("Recent DB entries (raw):")
		for i, ws in ipairs(recent_ws) do
			print("- " .. ws.path)
		end
		print("Matched open workspaces:")
		for i, ws in ipairs(matched) do
			print("- " .. ws.path)
		end
		print("Remaining recent workspaces:")
		for i, ws in ipairs(remaining) do
			print("- " .. ws.path)
		end
		print("--- DEBUG END   Zed Workspace Picker Debug ---")
	end

	if config.term then
		apply_term(matched, remaining)
	end

	-- == Build the choices
	local choices = build_choices(matched, remaining)

	-- === Helper to refresh the chooser content after a window close.

	-- === Create and show chooser
	local chooser
	local chooser_pos

	local function callback(choice)
		if not choice then return end

		-- determine is_do_close (if the Alt/Option key is down)
		local mods = hs.eventtap.checkKeyboardModifiers() or {}
		local is_do_close = mods.alt
		local is_do_sticky = mods.shift

		local ws = choice.data
		local win = nil
		if ws.is_open and ws.window_id then
			-- if open, then, we set focus
			win = hs.window.get(ws.window_id)
		end

		if is_do_close then
			-- IF: if is_do_close, then we close the open window
			wks_close(ws)
		else
			-- ELSE: otherwise, we are in open mode
			if not ws.is_open then
				wks_open(ws)
				if is_do_sticky and current_win then
					refocus(current_win)
				end
			elseif win then
				wks_focus(ws)
				if is_do_sticky and current_win then
					refocus(current_win)
				end
			end
		end

		if is_do_sticky then
			-- Refresh the picker content while keeping it open.
			hs.timer.doAfter(0.1, function()
				refresh_chooser(chooser, config)
				if chooser_pos then
					chooser:show(chooser_pos)
				else
					chooser:show()
				end
			end)
		end
	end -- callback

	chooser = hs.chooser.new(callback)
	chooser:choices(choices)
	chooser:width(25)

	-- === Compute Position the chooser relative to the currently focused window (x+100, y+100)
	-- If the focused window is Zed, position the chooser relative to it.
	if current_win and current_win:application():name():find("Zed", 1, true) then
		chooser_pos = current_win:topLeft()
		chooser_pos = hs.geometry.point(chooser_pos.x + 100, chooser_pos.y + 100)
		-- otherwise show default position (centered)
	end

	if chooser_pos then
		chooser:show(chooser_pos)
	else
		chooser:show()
	end
end

return {
	show_zed_picker = show_zed_picker
}
