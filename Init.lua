local addonName, addon = ...

addon.name = addonName
addon.version = "0.2.2"
addon.updateInterval = 0.20
addon.eventRefreshDelay = 0.05
addon.testModeUntil = 0
addon.configPreviewActive = false
addon.layoutRevision = 1
addon.styleRevision = 1

addon.defaults = {
	enabled = true,
	anchorPoint = "LEFT",
	relativePoint = "RIGHT",
	offsetX = 6,
	offsetY = 0,
	badgeWidth = 44,
	badgeHeight = 18,
	fontSize = 14,
	autoWidth = true,
	showBackground = true,
	windowWidth = 680,
	windowHeight = 570,
	windowOffsetX = 0,
	windowOffsetY = 0,
}

local VALID_POINTS = {
	BOTTOM = true,
	BOTTOMLEFT = true,
	BOTTOMRIGHT = true,
	CENTER = true,
	LEFT = true,
	RIGHT = true,
	TOP = true,
	TOPLEFT = true,
	TOPRIGHT = true,
}

local function Clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local function IsFiniteNumber(value)
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

local function CopyDefaults(target)
	for key, value in pairs(addon.defaults) do
		if type(target[key]) ~= type(value)
			or (type(value) == "number" and not IsFiniteNumber(target[key]))
		then
			target[key] = value
		end
	end
end

ThreatPlatingDB = type(ThreatPlatingDB) == "table" and ThreatPlatingDB or {}
CopyDefaults(ThreatPlatingDB)

ThreatPlatingDB.anchorPoint = VALID_POINTS[ThreatPlatingDB.anchorPoint]
	and ThreatPlatingDB.anchorPoint
	or addon.defaults.anchorPoint
ThreatPlatingDB.relativePoint = VALID_POINTS[ThreatPlatingDB.relativePoint]
	and ThreatPlatingDB.relativePoint
	or addon.defaults.relativePoint
ThreatPlatingDB.offsetX = Clamp(ThreatPlatingDB.offsetX, -300, 300)
ThreatPlatingDB.offsetY = Clamp(ThreatPlatingDB.offsetY, -300, 300)
ThreatPlatingDB.badgeWidth = Clamp(ThreatPlatingDB.badgeWidth, 36, 160)
ThreatPlatingDB.badgeHeight = Clamp(ThreatPlatingDB.badgeHeight, 14, 64)
ThreatPlatingDB.fontSize = Clamp(ThreatPlatingDB.fontSize, 8, 32)
ThreatPlatingDB.badgeHeight = math.max(ThreatPlatingDB.badgeHeight, ThreatPlatingDB.fontSize + 4)
ThreatPlatingDB.windowWidth = Clamp(ThreatPlatingDB.windowWidth, 620, 900)
ThreatPlatingDB.windowHeight = Clamp(ThreatPlatingDB.windowHeight, 540, 720)
ThreatPlatingDB.windowOffsetX = Clamp(ThreatPlatingDB.windowOffsetX, -2000, 2000)
ThreatPlatingDB.windowOffsetY = Clamp(ThreatPlatingDB.windowOffsetY, -1200, 1200)

addon.db = ThreatPlatingDB
addon.enabled = addon.db.enabled

local function Print(message)
	print("|cff65d96eThreat Plating:|r " .. message)
end

function addon:SetEnabled(enabled)
	self.enabled = enabled and true or false
	self.db.enabled = self.enabled

	if self.enabled then
		self:ScanVisibleNameplates()
		self.UpdateAllNameplates()
	else
		self.HideAllNameplates()
	end

	if self.RefreshConfig then
		self.RefreshConfig()
	end
end

function addon:ResetBadgeSettings()
	local keys = {
		"anchorPoint",
		"relativePoint",
		"offsetX",
		"offsetY",
		"badgeWidth",
		"badgeHeight",
		"fontSize",
		"autoWidth",
		"showBackground",
	}

	for _, key in ipairs(keys) do
		self.db[key] = self.defaults[key]
	end

	if self.ApplyDisplaySettings then
		self.ApplyDisplaySettings()
	end
	if self.RefreshConfig then
		self.RefreshConfig()
	end
end

SLASH_THREATPLATING1 = "/threatplating"
SlashCmdList.THREATPLATING = function(message)
	local command = string.lower((message or ""):match("^%s*(%S*)") or "")

	if command == "on" then
		addon:SetEnabled(true)
		Print("enabled.")
	elseif command == "off" then
		addon:SetEnabled(false)
		Print("disabled.")
	elseif command == "test" then
		addon:SetEnabled(true)
		addon.testModeUntil = GetTime() + 8
		addon:ScanVisibleNameplates()
		addon.UpdateAllNameplates()
		Print("showing sample counters on eligible visible nameplates for 8 seconds.")
	elseif command == "status" then
		local state = addon.enabled and "enabled" or "disabled"
		Print(string.format(
			"%s; %.2fs fallback poll; %.2fs minimum event refresh.",
			state,
			addon.updateInterval,
			addon.eventRefreshDelay
		))
	elseif command == "reset" then
		addon:ResetBadgeSettings()
		Print("badge layout reset.")
	elseif command == "close" then
		addon.CloseConfig()
	else
		addon.ToggleConfig()
	end
end
