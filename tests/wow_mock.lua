return function(Frame)
	local mock = {
		activeFormSpellID = nil,
		assignedRole = "NONE",
		frames = {},
		isMainTank = false,
		nameplateScanCount = 0,
		now = 100,
		plates = {},
		playerClass = "WARRIOR",
		talentPoints = { 0, 0, 41 },
		targetPlateUnit = nil,
		threat = {},
		threatQueryCount = 0,
		units = {
			nameplate1 = true,
			pet = true,
			player = true,
		},
	}

	function CreateFrame(frameType, name, parent, template)
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
		}, Frame)
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
		for _, plate in pairs(mock.plates) do
			visible[#visible + 1] = plate
		end
		return visible
	end

	function GetNumGroupMembers()
		return 0
	end

	function GetNumSubgroupMembers()
		return 0
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
		return false
	end

	function IsInRaid()
		return false
	end

	function UnitCanAttack(_, unit)
		return unit == "nameplate1" or unit == "nameplate2" or unit == "nameplate3"
	end

	function UnitClass()
		return mock.playerClass, mock.playerClass
	end

	function UnitDetailedThreatSituation(source, enemy)
		mock.threatQueryCount = mock.threatQueryCount + 1
		local result = mock.threat[source .. ":" .. enemy]
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
		return unit == "nameplate2"
	end

	function UnitIsUnit(left, right)
		return left == right
	end

	function UnitPlayerControlled(unit)
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
