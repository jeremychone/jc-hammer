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

-- Find a terminal window by matching the project basename exactly.
-- Matches the basename extracted from the terminal's path (regardless of whether
-- the terminal title contains the full path or only the basename).
function obj.find_terminal_by_basename(basename)
	if not basename or basename == "" then return nil end
	local normalized_basename = basename:gsub("/+$", "")
	local terms = obj.list_zed_terms()
	for _, term in ipairs(terms) do
		local term_path = term.path
		if term_path and term_path ~= "" then
			local term_basename = term_path:gsub("/+$", ""):match("[^/]+$")
			if term_basename == normalized_basename then
				return term.win
			end
		end
	end
	return nil
end

return obj
