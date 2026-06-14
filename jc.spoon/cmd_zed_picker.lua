local spoonPath = hs.spoons.resourcePath("")

local zed = dofile(spoonPath .. "/zed.lua")

local DEBUG = false

function show_zed_picker()
	-- === Load assets
	local image_open = hs.image.imageFromPath(spoonPath .. "/images/ico-opened.png")
	local image_closed = hs.image.imageFromPath(spoonPath .. "/images/ico-closed.png")

	-- === Get the zed info
	local open_ws = zed.list_open_zed()
	local recent_ws = zed.list_recent_zed_projects()
	local matched, remaining = zed.categorize_workspaces(open_ws, recent_ws)

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

	-- == Build the choices
	local choices = {}
	for _, ws in ipairs(matched) do
		table.insert(choices, {
			text = (ws.name or ws.display_name or ws.path),
			subText = ws.path,
			image = image_open,
			data = ws,
		})
	end
	for _, ws in ipairs(remaining) do
		table.insert(choices, {
			text = (ws.name or ws.display_name or ws.path),
			subText = ws.path,
			image = image_closed,
			data = ws,
		})
	end

	-- === Create and show chooser
	local chooser = hs.chooser.new(function(choice)
		if not choice then return end

		-- determine is_do_close (if the Alt/Option key is down)
		local mods = hs.eventtap.checkKeyboardModifiers() or {}
		local is_do_close = mods.alt;

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
			elseif win then
				win:focus()
			end
		end
	end)
	chooser:choices(choices)
	chooser:width(25)
	-- Position the chooser relative to the currently focused window (x+100, y+100)

	local win = hs.window.focusedWindow()
	-- If the focused window is Finder, let the chooser use its default position.
	if win and win:application():name() ~= "Finder" then
		local topLeft = nil
		topLeft = win:topLeft()
		topLeft = hs.geometry.point(topLeft.x + 100, topLeft.y + 100)
		chooser:show(topLeft)
		-- otherwise show default position (centered)
	else
		chooser:show()
	end
end

return {
	show_zed_picker = show_zed_picker
}
