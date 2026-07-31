return function(Frame)
	local mock = {
		activeFormSpellID = nil,
		attackable = {},
		assignedRole = "NONE",
		controlledUnits = {},
		currentFrame = 0,
		frames = {},
		groupMode = "solo",
		groupSize = 0,
		isMainTank = false,
		nameplateScanCount = 0,
		now = 100,
		plateOrder = {},
		plates = {},
		playerClass = "WARRIOR",
		playerUnits = {},
		subgroupSize = 0,
		talentPoints = { 0, 0, 41 },
		targetPlateUnit = nil,
		threat = {},
		threatQueryCount = 0,
		threatQueriesByFrame = {},
		threatQueryLog = {},
		unitIdentity = {},
		units = {
			nameplate1 = true,
			pet = true,
			player = true,
		},
	}

	function mock:BeginFrame()
		self.currentFrame = self.currentFrame + 1
		self.threatQueriesByFrame[self.currentFrame] = 0
	end

	function mock:SetRaid(size)
		self.groupMode = "raid"
		self.groupSize = size
		self.subgroupSize = 0
		for index = 1, size do
			local raidUnit = "raid" .. index
			local raidPet = "raidpet" .. index
			self.units[raidUnit] = true
			self.units[raidPet] = true
			self.unitIdentity[raidUnit] = "raid-member-" .. index
			self.unitIdentity[raidPet] = "raid-pet-" .. index
		end
		self.unitIdentity.player = self.unitIdentity.raid1
		self.unitIdentity.pet = self.unitIdentity.raidpet1
	end

	function mock:SetParty(size)
		self.groupMode = "party"
		self.groupSize = size + 1
		self.subgroupSize = size
		for index = 1, size do
			local partyUnit = "party" .. index
			local partyPet = "partypet" .. index
			self.units[partyUnit] = true
			self.units[partyPet] = true
			self.unitIdentity[partyUnit] = "party-member-" .. index
			self.unitIdentity[partyPet] = "party-pet-" .. index
		end
	end

	-- Templates the addon is allowed to ask for. A typo here is otherwise invisible: the
	-- shared metatable answers every method regardless of what was requested.
	local KNOWN_TEMPLATES = {
		BackdropTemplate = true,
		InputBoxTemplate = true,
		UICheckButtonTemplate = true,
		UIPanelButtonTemplate = true,
		UIPanelCloseButtonNoScripts = true,
		UISliderTemplate = true,
	}

	-- BackdropTemplateMixin stopped being part of the base Frame in this client
	-- generation, so calling these without the template is a live Lua error in game and
	-- must be one here too.
	local BACKDROP_METHODS = {
		"GetBackdrop",
		"SetBackdrop",
		"SetBackdropBorderColor",
		"SetBackdropColor",
	}

	function CreateFrame(frameType, name, parent, template)
		local templates = {}
		if template ~= nil then
			if type(template) ~= "string" then
				error("frame template must be a string, got " .. type(template), 2)
			end
			for entry in template:gmatch("[^,%s]+") do
				if not KNOWN_TEMPLATES[entry] then
					error("unknown frame template: " .. entry, 2)
				end
				templates[entry] = true
			end
		end

		local frame = setmetatable({
			children = {},
			enabled = true,
			events = {},
			frameLevel = parent and parent:GetFrameLevel() + 1 or 1,
			frameType = frameType,
			hooks = {},
			name = name,
			parent = parent,
			points = {},
			scripts = {},
			shown = true,
			template = template,
			templates = templates,
		}, Frame)

		if not templates.BackdropTemplate then
			for _, method in ipairs(BACKDROP_METHODS) do
				frame[method] = function()
					error(
						method .. " requires BackdropTemplate; "
							.. tostring(frameType) .. " was created with "
							.. (template and ("\"" .. template .. "\"") or "no template"),
						2
					)
				end
			end
		end

		mock.frames[#mock.frames + 1] = frame
		if parent and parent.children then
			parent.children[#parent.children + 1] = frame
		end
		return frame
	end

	C_NamePlate = {}

	function C_NamePlate.GetNamePlateForUnit(unit)
		if unit == "target" and mock.targetPlateUnit then
			return mock.plates[mock.targetPlateUnit]
		end
		return mock.plates[unit]
	end

	function C_NamePlate.GetNamePlates()
		mock.nameplateScanCount = mock.nameplateScanCount + 1
		local visible = {}
		if #mock.plateOrder > 0 then
			for _, unit in ipairs(mock.plateOrder) do
				local plate = mock.plates[unit]
				if plate then
					visible[#visible + 1] = plate
				end
			end
		else
			for _, plate in pairs(mock.plates) do
				visible[#visible + 1] = plate
			end
		end
		return visible
	end

	function GetBuildInfo()
		return "2.5.6", "68941", "Jul 31 2026", 20506
	end

	function GetNumGroupMembers()
		return mock.groupSize
	end

	function GetNumSubgroupMembers()
		return mock.subgroupSize
	end

	function GetNumTalentTabs()
		return 3
	end

	function GetPartyAssignment()
		return mock.isMainTank
	end

	function GetShapeshiftForm()
		return mock.activeFormSpellID and 1 or 0
	end

	function GetShapeshiftFormInfo()
		return nil,
			mock.activeFormSpellID ~= nil,
			true,
			mock.activeFormSpellID
	end

	function GetTalentTabInfo(index)
		return index,
			"Tree " .. index,
			nil,
			nil,
			mock.talentPoints[index],
			"Tree" .. index
	end

	function GetTime()
		return mock.now
	end

	function IsInGroup()
		return mock.groupMode == "party" or mock.groupMode == "raid"
	end

	function IsInRaid()
		return mock.groupMode == "raid"
	end

	function UnitCanAttack(_, unit)
		if mock.attackable[unit] ~= nil then
			return mock.attackable[unit]
		end
		return unit == "nameplate1" or unit == "nameplate2" or unit == "nameplate3"
	end

	function UnitClass()
		return mock.playerClass, mock.playerClass
	end

	function UnitDetailedThreatSituation(source, enemy)
		mock.threatQueryCount = mock.threatQueryCount + 1
		mock.threatQueriesByFrame[mock.currentFrame] =
			(mock.threatQueriesByFrame[mock.currentFrame] or 0) + 1
		mock.threatQueryLog[#mock.threatQueryLog + 1] = {
			enemy = enemy,
			frame = mock.currentFrame,
			source = source,
		}
		local result
		if mock.threatHandler then
			result = mock.threatHandler(source, enemy)
		else
			result = mock.threat[source .. ":" .. enemy]
		end
		if result == "error" then
			error("restricted threat query")
		end
		if not result then
			return nil
		end
		return unpack(result)
	end

	function UnitExists(unit)
		return mock.units[unit] == true
	end

	function UnitIsPlayer(unit)
		if mock.playerUnits[unit] ~= nil then
			return mock.playerUnits[unit]
		end
		return unit == "nameplate2"
	end

	function UnitIsUnit(left, right)
		return (mock.unitIdentity[left] or left) == (mock.unitIdentity[right] or right)
	end

	function UnitPlayerControlled(unit)
		if mock.controlledUnits[unit] ~= nil then
			return mock.controlledUnits[unit]
		end
		return unit == "nameplate2"
	end

	function UnitGroupRolesAssigned()
		return mock.assignedRole
	end

	function wipe(target)
		for key in pairs(target) do
			target[key] = nil
		end
	end

	SlashCmdList = {}
	UISpecialFrames = {}
	UIParent = setmetatable({
		centerX = 960,
		centerY = 540,
		children = {},
		events = {},
		frameLevel = 0,
		height = 1080,
		hooks = {},
		points = {},
		scripts = {},
		shown = true,
		width = 1920,
	}, Frame)

	GameTooltip = {
		AddLine = function()
		end,
		Hide = function()
		end,
		SetOwner = function()
		end,
		SetText = function()
		end,
		Show = function()
		end,
	}

	ColorPickerFrame = setmetatable({
		children = {},
		events = {},
		frameLevel = 10,
		hooks = {},
		points = {},
		scripts = {},
		shown = false,
	}, Frame)

	function ColorPickerFrame:GetColorRGB()
		return self.red or 1, self.green or 1, self.blue or 1
	end

	function ColorPickerFrame:GetColorAlpha()
		return self.opacity or 1
	end

	function ColorPickerFrame:GetExtraInfo()
		return self.extraInfo
	end

	function ColorPickerFrame:SetColorRGB(red, green, blue)
		self.red = red
		self.green = green
		self.blue = blue
	end

	function ColorPickerFrame:SetupColorPickerAndShow(info)
		self.swatchFunc = info.swatchFunc
		self.hasOpacity = info.hasOpacity
		self.opacityFunc = info.opacityFunc
		self.opacity = info.opacity
		self.cancelFunc = info.cancelFunc
		self.extraInfo = info.extraInfo
		self:SetColorRGB(info.r, info.g, info.b)
		self:Show()
		self.swatchFunc()
	end

	Settings = {}

	function Settings.RegisterCanvasLayoutCategory()
		return {}, {
			AddAnchorPoint = function()
			end,
		}
	end

	function Settings.RegisterAddOnCategory()
	end

	return mock
end
