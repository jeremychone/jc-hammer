-- --- Initialize .user/ directory with default files if not present
local function setup_user_dir(spoon_path)
	local userDir = spoon_path .. "/.user"
	-- Create .user directory if it doesn't exist
	if hs.fs.attributes(userDir) == nil then
		hs.fs.mkdir(userDir)
	end

	-- Helper to copy file only if destination does not exist
	local function copyIfNotExists(src, dest)
		if hs.fs.attributes(dest) == nil then
			-- hs.fs.copy does not exist; use io to copy file contents
			local f_in = io.open(src, "rb")
			if f_in then
				local content = f_in:read("*a")
				f_in:close()
				local f_out = io.open(dest, "wb")
				if f_out then
					f_out:write(content)
					f_out:close()
				end
			end
		end
	end

	-- Copy config_default.lua to .user/config_user.lua
	local configDefaultPath = spoon_path .. "/config_default.lua"
	local configUserPath = userDir .. "/config_user.lua"
	copyIfNotExists(configDefaultPath, configUserPath)

	-- Copy templates/profiles.json to .user/profiles.json
	local profilesTemplatePath = spoon_path .. "/templates/profiles.json"
	local profilesUserPath = userDir .. "/profiles.json"
	copyIfNotExists(profilesTemplatePath, profilesUserPath)

	-- Copy templates/profile_current.json to .user/profile_current.json
	local currentProfileTemplatePath = spoon_path .. "/templates/profile_current.json"
	local currentProfileUserPath = userDir .. "/profile_current.json"
	copyIfNotExists(currentProfileTemplatePath, currentProfileUserPath)
end

return {
	setup_user_dir = setup_user_dir
}
