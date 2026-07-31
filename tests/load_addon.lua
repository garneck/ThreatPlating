local function LoadAddon(addonName, addon, lastFile)
	for line in io.lines("ThreatPlating.toc") do
		local path = line:match("^%s*([^#].-%.lua)%s*$")
		if path then
			assert(loadfile(path))(addonName, addon)
			if path == lastFile then
				return
			end
		end
	end

	assert(not lastFile, "TOC does not declare requested final file: " .. tostring(lastFile))
end

return LoadAddon
