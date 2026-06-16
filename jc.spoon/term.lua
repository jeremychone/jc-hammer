-- Spoon: jc.spoon/term.lua
-- Alacritty terminal integration paired with Zed editor projects.

local obj = {}

-- Returns: {title, string, win}[]
function obj.list_zed_terms()
	local alacritty = hs.application.get("Alacritty")
	if not alacritty then
		return {}
	end
	local windows = alacritty:allWindows()
	local result = {}
	for _, win in ipairs(windows) do
		local title = win:title()
		-- Exclude windows without a title (e.g., transient / empty ones)
		if title and title:len() > 0 then
			-- Filter: title must contain "zed term"
			if title:find("zed term") then
				-- Extract path from title: "zed term - <path>"
				local path = title:match("zed term %- (.+)")
				table.insert(result, {
					title = title,
					path = path or "",
					win = win
				})
			end
		end
	end
	return result
end

return obj
