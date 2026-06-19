-- Spoon: jc.spoon/cmd_term.lua
-- Terminal positioning commands for Zed projects.

local obj = {}

local spoonPath = hs.spoons.resourcePath("")
local zed = dofile(spoonPath .. "/zed.lua")

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

	local ws = zed.get_current_zed()
	if not ws then
		return
	end

	if not ws.term or not ws.term.win then
		hs.alert("No terminal found")
		return
	end

	local term_win = ws.term.win
	local zed_frame = ws.window:frame()
	local term_frame = term_win:frame()
	if mode == "below" then
		local new_x = zed_frame.x + (zed_frame.w / 2) - (term_frame.w / 2)
		local new_y = zed_frame.y + zed_frame.h + 4
		term_win:setFrame(hs.geometry.rect(new_x, new_y, term_frame.w, term_frame.h))
	elseif mode == "bottom" then
		local margin = 4
		local new_x = zed_frame.x + (zed_frame.w / 2) - (term_frame.w / 2)
		local new_y = zed_frame.y + zed_frame.h - margin - term_frame.h
		term_win:setFrame(hs.geometry.rect(new_x, new_y, term_frame.w, term_frame.h))
	end

	term_win:focus()
end

return obj
