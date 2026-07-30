local addonName, addon = ...

addon.name = addonName
addon.version = "0.5.1"
addon.updateInterval = 0.20
addon.eventRefreshDelay = 0.05
addon.testModeUntil = 0
addon.testPullThresholdWarning = false
addon.configPreviewActive = false
addon.layoutRevision = 1
addon.styleRevision = 1

local SCHEMA_VERSION = 2
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
local VALID_FONT_PRESETS = {
	combat = true,
	nameplate = true,
	ui = true,
}
local VALID_BORDER_MODES = {
	custom = true,
	off = true,
	semantic = true,
}
local VALID_PALETTES = {
	blue = true,
	custom = true,
	cyan = true,
	default = true,
}
local SECTION_KEYS = {
	"general",
	"position",
	"typography",
	"appearance",
	"colors",
}

addon.defaults = {
	schemaVersion = SCHEMA_VERSION,
	enabled = true,
	anchorPoint = "LEFT",
	relativePoint = "RIGHT",
	offsetX = 6,
	offsetY = 0,
	badgeWidth = 44,
	badgeHeight = 18,
	autoWidth = true,
	padding = 7,
	fontSize = 14,
	fontPreset = "nameplate",
	shadow = true,
	backgroundColor = { 0.025, 0.025, 0.025, 0.90 },
	borderMode = "semantic",
	borderColor = { 0.65, 0.65, 0.65, 1 },
	palette = "default",
	safeColor = { 0.35, 1, 0.35 },
	dangerColor = { 1, 0.32, 0.26 },
	warningColor = { 1, 0.62, 0.12 },
	collapsedSections = {
		general = false,
		position = false,
		typography = false,
		appearance = false,
		colors = false,
	},
	windowWidth = 780,
	windowHeight = 620,
	windowOffsetX = 0,
	windowOffsetY = 0,
}

addon.layoutSettingKeys = {
	"anchorPoint",
	"relativePoint",
	"offsetX",
	"offsetY",
	"badgeWidth",
	"badgeHeight",
	"autoWidth",
	"padding",
}

addon.appearanceSettingKeys = {
	"fontSize",
	"fontPreset",
	"shadow",
	"backgroundColor",
	"borderMode",
	"borderColor",
	"palette",
	"safeColor",
	"dangerColor",
	"warningColor",
}

local function Clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local function Round(value)
	if value >= 0 then
		return math.floor(value + 0.5)
	end
	return math.ceil(value - 0.5)
end

local function IsFiniteNumber(value)
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

local function CopyValue(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, child in pairs(value) do
		copy[key] = CopyValue(child)
	end
	return copy
end

local function CopyDefault(target, key)
	target[key] = CopyValue(addon.defaults[key])
end

local function ValidateBoolean(target, key)
	if type(target[key]) ~= "boolean" then
		CopyDefault(target, key)
	end
end

local function ValidateNumber(target, key, minimum, maximum, integer)
	if not IsFiniteNumber(target[key]) then
		CopyDefault(target, key)
	end

	target[key] = Clamp(target[key], minimum, maximum)
	if integer then
		target[key] = Round(target[key])
	end
end

local function ValidateEnum(target, key, validValues)
	if not validValues[target[key]] then
		CopyDefault(target, key)
	end
end

local function ValidateColor(target, key, componentCount)
	local saved = type(target[key]) == "table" and target[key] or {}
	local fallback = addon.defaults[key]
	local color = {}

	for index = 1, componentCount do
		local component = saved[index]
		if not IsFiniteNumber(component) then
			component = fallback[index]
		end
		color[index] = Clamp(component, 0, 1)
	end

	target[key] = color
end

local function MigrateDatabase(target)
	if target.schemaVersion == SCHEMA_VERSION then
		return
	end

	-- 0.2 through 0.4 stored one background toggle. Preserve its visual result
	-- while moving to independently configurable background and border values.
	if target.showBackground == false then
		target.backgroundColor = CopyValue(addon.defaults.backgroundColor)
		target.backgroundColor[4] = 0
		target.borderMode = "off"
	elseif target.showBackground == true then
		target.backgroundColor = CopyValue(addon.defaults.backgroundColor)
		target.borderMode = "semantic"
	end

	target.showBackground = nil
	target.schemaVersion = SCHEMA_VERSION
end

local function GetViewportSize()
	if UIParent and UIParent.GetWidth and UIParent.GetHeight then
		local width = UIParent:GetWidth()
		local height = UIParent:GetHeight()
		if IsFiniteNumber(width) and width > 0 and IsFiniteNumber(height) and height > 0 then
			return width, height
		end
	end

	return 1920, 1080
end

local function ValidateDatabase(target)
	MigrateDatabase(target)

	ValidateBoolean(target, "enabled")
	ValidateEnum(target, "anchorPoint", VALID_POINTS)
	ValidateEnum(target, "relativePoint", VALID_POINTS)
	ValidateNumber(target, "offsetX", -300, 300, true)
	ValidateNumber(target, "offsetY", -300, 300, true)
	ValidateNumber(target, "badgeWidth", 36, 160, true)
	ValidateNumber(target, "badgeHeight", 14, 64, true)
	ValidateBoolean(target, "autoWidth")
	ValidateNumber(target, "padding", 0, 32, true)
	ValidateNumber(target, "fontSize", 8, 32, true)
	ValidateEnum(target, "fontPreset", VALID_FONT_PRESETS)
	ValidateBoolean(target, "shadow")
	ValidateColor(target, "backgroundColor", 4)
	ValidateEnum(target, "borderMode", VALID_BORDER_MODES)
	ValidateColor(target, "borderColor", 4)
	ValidateEnum(target, "palette", VALID_PALETTES)
	ValidateColor(target, "safeColor", 3)
	ValidateColor(target, "dangerColor", 3)
	ValidateColor(target, "warningColor", 3)

	if type(target.collapsedSections) ~= "table" then
		CopyDefault(target, "collapsedSections")
	else
		for _, section in ipairs(SECTION_KEYS) do
			if type(target.collapsedSections[section]) ~= "boolean" then
				target.collapsedSections[section] = addon.defaults.collapsedSections[section]
			end
		end
	end

	ValidateNumber(target, "windowWidth", 520, 1000, true)
	ValidateNumber(target, "windowHeight", 520, 800, true)
	ValidateNumber(target, "windowOffsetX", -4000, 4000, true)
	ValidateNumber(target, "windowOffsetY", -2400, 2400, true)

	local viewportWidth, viewportHeight = GetViewportSize()
	local maximumOffsetX = math.max(0, (viewportWidth - target.windowWidth) / 2)
	local maximumOffsetY = math.max(0, (viewportHeight - target.windowHeight) / 2)
	target.windowOffsetX = Round(Clamp(target.windowOffsetX, -maximumOffsetX, maximumOffsetX))
	target.windowOffsetY = Round(Clamp(target.windowOffsetY, -maximumOffsetY, maximumOffsetY))
	target.schemaVersion = SCHEMA_VERSION
end

local runtimeDB = type(ThreatPlatingDB) == "table" and ThreatPlatingDB or {}
ThreatPlatingDB = runtimeDB
ValidateDatabase(runtimeDB)

addon.db = runtimeDB
addon.enabled = addon.db.enabled
addon.Clamp = Clamp
addon.Round = Round
addon.CopyValue = CopyValue

local function AdoptLoadedDatabase()
	local loadedDB = ThreatPlatingDB
	if loadedDB ~= runtimeDB then
		for key in pairs(runtimeDB) do
			runtimeDB[key] = nil
		end

		if type(loadedDB) == "table" then
			for key, value in pairs(loadedDB) do
				runtimeDB[key] = CopyValue(value)
			end
		end
	end

	ValidateDatabase(runtimeDB)
	ThreatPlatingDB = runtimeDB
	addon.db = runtimeDB
	addon.enabled = runtimeDB.enabled

	if addon.RefreshConfig then
		addon.RefreshConfig()
	end
end

local databaseFrame = CreateFrame("Frame")
databaseFrame:RegisterEvent("ADDON_LOADED")
databaseFrame:SetScript("OnEvent", function(self, _, loadedAddonName)
	if loadedAddonName ~= addonName then
		return
	end

	self:UnregisterEvent("ADDON_LOADED")
	AdoptLoadedDatabase()
end)

local function CopyKeys(source, target, keys)
	for _, key in ipairs(keys) do
		target[key] = CopyValue(source[key])
	end
end

function addon:CaptureDisplaySettings()
	local snapshot = {
		enabled = self.db.enabled,
	}
	CopyKeys(self.db, snapshot, self.layoutSettingKeys)
	CopyKeys(self.db, snapshot, self.appearanceSettingKeys)
	return snapshot
end

function addon:RestoreDisplaySettings(snapshot)
	if type(snapshot) ~= "table" then
		return
	end

	CopyKeys(snapshot, self.db, self.layoutSettingKeys)
	CopyKeys(snapshot, self.db, self.appearanceSettingKeys)
	self:SetEnabled(snapshot.enabled)
	self.ApplyDisplaySettings("all")
end

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

function addon:ResetLayoutSettings()
	CopyKeys(self.defaults, self.db, self.layoutSettingKeys)
	if self.ApplyDisplaySettings then
		self.ApplyDisplaySettings("layout")
	end
	if self.RefreshConfig then
		self.RefreshConfig()
	end
end

function addon:ResetAppearanceSettings()
	CopyKeys(self.defaults, self.db, self.appearanceSettingKeys)
	if self.ApplyDisplaySettings then
		self.ApplyDisplaySettings("style")
	end
	if self.RefreshConfig then
		self.RefreshConfig()
	end
end

function addon:ResetAllSettings()
	CopyKeys(self.defaults, self.db, self.layoutSettingKeys)
	CopyKeys(self.defaults, self.db, self.appearanceSettingKeys)
	self:SetEnabled(self.defaults.enabled)
	if self.ApplyDisplaySettings then
		self.ApplyDisplaySettings("all")
	end
	if self.RefreshConfig then
		self.RefreshConfig()
	end
end

-- Keep the historical slash-command helper as a compatibility alias.
function addon:ResetBadgeSettings()
	self:ResetAllSettings()
end

SLASH_THREATPLATING1 = "/threatplating"
SlashCmdList.THREATPLATING = function(message)
	local command, argument = (message or ""):match("^%s*(%S*)%s*(%S*)")
	command = string.lower(command or "")
	argument = string.lower(argument or "")

	if command == "on" then
		addon:SetEnabled(true)
		Print("enabled.")
	elseif command == "off" then
		addon:SetEnabled(false)
		Print("disabled.")
	elseif command == "test" then
		addon:SetEnabled(true)
		addon.testModeUntil = GetTime() + 8
		addon.testPullThresholdWarning = argument == "orange"
		addon:ScanVisibleNameplates()
		addon.UpdateAllNameplates()
		if addon.testPullThresholdWarning then
			Print("showing orange threshold samples on eligible visible nameplates for 8 seconds.")
		else
			Print("showing sample counters on eligible visible nameplates for 8 seconds.")
		end
	elseif command == "status" then
		local state = addon.enabled and "enabled" or "disabled"
		local role = addon.playerIsTank and "tank" or "non-tank"
		Print(string.format(
			"%s; detected %s; %.2fs fallback poll; %.2fs minimum event refresh.",
			state,
			role,
			addon.updateInterval,
			addon.eventRefreshDelay
		))
	elseif command == "reset" then
		addon:ResetAllSettings()
		Print("layout and appearance reset.")
	elseif command == "close" then
		addon.CloseConfig()
	else
		addon.ToggleConfig()
	end
end
