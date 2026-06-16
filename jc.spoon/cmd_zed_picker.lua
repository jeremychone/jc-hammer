local spoonPath = hs.spoons.resourcePath("")

local zed = dofile(spoonPath .. "/zed.lua")
local term = dofile(spoonPath .. "/term.lua")

local DEBUG = false

local function apply_term_indicator(workspaces)
	local term_list = term.list_zed_terms()
	local term_paths = {}
	for _, t in ipairs(term_list) do
		if t.path and t.path ~= "" then
			term_paths[t.path:gsub("/+$", "")] = true
		end
	end
	for _, ws in ipairs(workspaces) do
		if ws.path then
			local normalized = ws.path:gsub("/+$", "")
			if term_paths[normalized] then
				ws.has_term = true
			end
		end
	end
end


local function refresh_chooser(chooser_inst, options, config)
	local new_open_ws = zed.list_open_zed()
	local new_recent_ws = zed.list_recent_zed_projects()
	local new_matched, new_remaining = zed.categorize_workspaces(new_open_ws, new_recent_ws)

	if config.term then
		apply_term_indicator(new_matched)
		apply_term_indicator(new_remaining)
	end

	local new_choices = {}
	for _, ws in ipairs(new_matched) do
		local text = (ws.name or ws.display_name or ws.path)
		if ws.has_term then text = text .. " (term)" end
		table.insert(new_choices, {
			text = text,
			subText = ws.path,
			image = options.image_open,
			data = ws,
		})
	end
	for _, ws in ipairs(new_remaining) do
		local text = (ws.name or ws.display_name or ws.path)
		if ws.has_term then text = text .. " (term)" end
		table.insert(new_choices, {
			text = text,
			subText = ws.path,
			image = options.image_closed,
			data = ws,
		})
	end
	chooser_inst:choices(new_choices)
	-- Reset the query to show all refreshed choices
	chooser_inst:query("")
end

local function re_focus(win)
	hs.timer.doAfter(0.1, function()
		win:focus()
	end)
end

local function show_zed_picker(config)
	-- === Load assets
	local image_open = hs.image.imageFromPath(spoonPath .. "/images/ico-opened.png")
	local image_closed = hs.image.imageFromPath(spoonPath .. "/images/ico-closed.png")

	-- === Debug: list zed terms
	if config.term then
		local dev_terms = term.list_zed_terms()
		print("--- Zed Terms ---")
		for i, t in ipairs(dev_terms) do
			print(i .. " title: " .. t.title .. "\npath: " .. t.path .. "\nid: " .. t.win:id() .. "\nwin:", t.win)
		end
	end

	-- === Get the zed info
	local open_ws = zed.list_open_zed()
	local recent_ws = zed.list_recent_zed_projects()
	local matched, remaining = zed.categorize_workspaces(open_ws, recent_ws)
	local current_win = hs.window.focusedWindow()

	-- === Debug
	if DEBUG then
		print("--- Zed Workspace Picker Debug ---")
		print("Open workspaces (raw):")
		for i, ws in ipairs(open_ws) do
			print(i, ws.path, ws.display_name, ws.active_file)
		end
		print("Recent DB entries (raw):")
		for i, ws in ipairs(recent_ws) do
			print(i, ws.path, ws.timestamp)
		end
		print("Matched open workspaces:")
		for i, ws in ipairs(matched) do
			print(i, ws.path, ws.is_open)
		end
		print("Remaining recent workspaces:")
		for i, ws in ipairs(remaining) do
			print(i, ws.path, ws.is_open)
		end
	end

	if config.term then
		apply_term_indicator(matched)
		apply_term_indicator(remaining)
	end

	-- == Build the choices
	local choices = {}
	for _, ws in ipairs(matched) do
		local text = (ws.name or ws.display_name or ws.path)
		if ws.has_term then text = text .. " (term)" end
		table.insert(choices, {
			text = text,
			subText = ws.path,
			image = image_open,
			data = ws,
		})
	end
	for _, ws in ipairs(remaining) do
		local text = (ws.name or ws.display_name or ws.path)
		if ws.has_term then text = text .. " (term)" end
		table.insert(choices, {
			text = text,
			subText = ws.path,
			image = image_closed,
			data = ws,
		})
	end

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
			if win then
				win:close()
			end
		else
			-- ELSE: otherwise, we are in open mode
			if not ws.is_open then
				hs.execute("open -a Zed '" .. ws.path .. "'")
				if is_do_sticky and current_win then
					re_focus(current_win)
				end
			elseif win then
				win:focus()
				if is_do_sticky and current_win then
					re_focus(current_win)
				end
			end
		end

		if is_do_sticky then
			-- Refresh the picker content while keeping it open.
			hs.timer.doAfter(0.1, function()
				refresh_chooser(chooser, { image_open = image_open, image_closed = image_closed }, config)
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
	-- If the focused window is Finder, let the chooser use its default position.
	if current_win and current_win:application():name() ~= "Finder" then
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
