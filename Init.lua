local addonName, addon = ...

addon.name = addonName
addon.version = "0.8.0"
addon.updateInterval = 0.10
addon.eventRefreshDelay = 0.05
addon.testModeUntil = 0
addon.testPullThresholdWarning = false
-- One raw-threat sample drives both /threatplating test and the configurator preview,
-- so the two can never disagree about what a formatted badge looks like.
addon.sampleThreatDelta = 12300
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
-- Ordered because the configurator renders them in this order; the accepted-value sets
-- are derived so the editor can never offer a value that validation rejects.
local FONT_PRESET_CHOICES = {
	{ label = "Nameplate", value = "nameplate" },
	{ label = "UI", value = "ui" },
	{ label = "Combat", value = "combat" },
}
local BORDER_MODE_CHOICES = {
	{ label = "Semantic", value = "semantic" },
	{ label = "Custom", value = "custom" },
	{ label = "Off", value = "off" },
}
local PALETTE_CHOICES = {
	{ label = "Default", value = "default" },
	{ label = "Blue / Verm.", value = "blue" },
	{ label = "Cyan / Mag.", value = "cyan" },
	{ label = "Custom", value = "custom" },
}

local function ChoiceValueSet(choices)
	local values = {}
	for _, choice in ipairs(choices) do
		values[choice.value] = true
	end
	return values
end

local VALID_FONT_PRESETS = ChoiceValueSet(FONT_PRESET_CHOICES)
local VALID_BORDER_MODES = ChoiceValueSet(BORDER_MODE_CHOICES)
local VALID_PALETTES = ChoiceValueSet(PALETTE_CHOICES)
local SECTION_KEYS = {
	"general",
	"position",
	"typography",
	"appearance",
	"colors",
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

local SETTING_DEFINITIONS = {
	{
		key = "enabled",
		default = true,
		valueType = "boolean",
	},
	{
		key = "smoothTransitions",
		default = true,
		valueType = "boolean",
		group = "behavior",
	},
	{
		key = "anchorPoint",
		default = "LEFT",
		valueType = "enum",
		values = VALID_POINTS,
		group = "layout",
	},
	{
		key = "relativePoint",
		default = "RIGHT",
		valueType = "enum",
		values = VALID_POINTS,
		group = "layout",
	},
	{
		key = "offsetX",
		default = 6,
		valueType = "number",
		minimum = -300,
		maximum = 300,
		step = 1,
		integer = true,
		group = "layout",
	},
	{
		key = "offsetY",
		default = 0,
		valueType = "number",
		minimum = -300,
		maximum = 300,
		step = 1,
		integer = true,
		group = "layout",
	},
	{
		key = "badgeWidth",
		default = 44,
		valueType = "number",
		minimum = 36,
		maximum = 160,
		step = 1,
		integer = true,
		group = "layout",
	},
	{
		key = "badgeHeight",
		default = 18,
		valueType = "number",
		minimum = 14,
		maximum = 64,
		step = 1,
		integer = true,
		group = "layout",
	},
	{
		key = "autoWidth",
		default = true,
		valueType = "boolean",
		group = "layout",
	},
	{
		key = "padding",
		default = 7,
		valueType = "number",
		minimum = 0,
		maximum = 32,
		step = 1,
		integer = true,
		group = "layout",
	},
	{
		key = "fontSize",
		default = 14,
		valueType = "number",
		minimum = 8,
		maximum = 32,
		step = 1,
		integer = true,
		group = "appearance",
	},
	{
		key = "fontPreset",
		default = "nameplate",
		valueType = "enum",
		values = VALID_FONT_PRESETS,
		choices = FONT_PRESET_CHOICES,
		group = "appearance",
	},
	{
		key = "shadow",
		default = true,
		valueType = "boolean",
		group = "appearance",
	},
	{
		key = "backgroundColor",
		default = { 0.025, 0.025, 0.025, 0.90 },
		valueType = "color",
		components = 4,
		group = "appearance",
	},
	{
		key = "borderMode",
		default = "semantic",
		valueType = "enum",
		values = VALID_BORDER_MODES,
		choices = BORDER_MODE_CHOICES,
		group = "appearance",
	},
	{
		key = "borderColor",
		default = { 0.65, 0.65, 0.65, 1 },
		valueType = "color",
		components = 4,
		group = "appearance",
	},
	{
		key = "palette",
		default = "default",
		valueType = "enum",
		values = VALID_PALETTES,
		choices = PALETTE_CHOICES,
		group = "appearance",
	},
	{
		key = "safeColor",
		default = { 0.35, 1, 0.35 },
		valueType = "color",
		components = 3,
		group = "appearance",
	},
	{
		key = "dangerColor",
		default = { 1, 0.32, 0.26 },
		valueType = "color",
		components = 3,
		group = "appearance",
	},
	{
		key = "warningColor",
		default = { 1, 0.62, 0.12 },
		valueType = "color",
		components = 3,
		group = "appearance",
	},
	{
		key = "collapsedSections",
		default = {
			general = false,
			position = false,
			typography = false,
			appearance = false,
			colors = false,
		},
		valueType = "sections",
	},
	{
		key = "windowWidth",
		default = 780,
		valueType = "number",
		minimum = 520,
		maximum = 1000,
		step = 1,
		integer = true,
	},
	{
		key = "windowHeight",
		default = 620,
		valueType = "number",
		minimum = 520,
		maximum = 800,
		step = 1,
		integer = true,
	},
	{
		key = "windowOffsetX",
		default = 0,
		valueType = "number",
		minimum = -4000,
		maximum = 4000,
		step = 1,
		integer = true,
	},
	{
		key = "windowOffsetY",
		default = 0,
		valueType = "number",
		minimum = -2400,
		maximum = 2400,
		step = 1,
		integer = true,
	},
}

addon.defaults = {
	schemaVersion = SCHEMA_VERSION,
}
addon.settingDefinitions = {}
addon.layoutSettingKeys = {}
addon.appearanceSettingKeys = {}
addon.behaviorSettingKeys = {}

for _, definition in ipairs(SETTING_DEFINITIONS) do
	addon.settingDefinitions[definition.key] = definition
	addon.defaults[definition.key] = CopyValue(definition.default)
	if definition.group == "layout" then
		addon.layoutSettingKeys[#addon.layoutSettingKeys + 1] = definition.key
	elseif definition.group == "appearance" then
		addon.appearanceSettingKeys[#addon.appearanceSettingKeys + 1] = definition.key
	elseif definition.group == "behavior" then
		addon.behaviorSettingKeys[#addon.behaviorSettingKeys + 1] = definition.key
	end
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

	for _, definition in ipairs(SETTING_DEFINITIONS) do
		if definition.valueType == "boolean" then
			ValidateBoolean(target, definition.key)
		elseif definition.valueType == "number" then
			ValidateNumber(
				target,
				definition.key,
				definition.minimum,
				definition.maximum,
				definition.integer
			)
		elseif definition.valueType == "enum" then
			ValidateEnum(target, definition.key, definition.values)
		elseif definition.valueType == "color" then
			ValidateColor(target, definition.key, definition.components)
		end
	end

	if type(target.collapsedSections) ~= "table" then
		CopyDefault(target, "collapsedSections")
	else
		for _, section in ipairs(SECTION_KEYS) do
			if type(target.collapsedSections[section]) ~= "boolean" then
				target.collapsedSections[section] = addon.defaults.collapsedSections[section]
			end
		end
	end

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
addon.IsFiniteNumber = IsFiniteNumber
addon.NormalizeSettingValue = function(key, value)
	local definition = addon.settingDefinitions[key]
	if not definition or definition.valueType ~= "number" then
		return value
	end
	if not IsFiniteNumber(value) then
		value = definition.default
	end

	value = Clamp(value, definition.minimum, definition.maximum)
	if definition.integer then
		value = Round(value)
	end
	return value
end

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
	CopyKeys(self.db, snapshot, self.behaviorSettingKeys)
	return snapshot
end

local function Print(message)
	print("|cff65d96eThreat Plating:|r " .. message)
end

local function SetEnabledValue(self, enabled)
	self.enabled = enabled and true or false
	self.db.enabled = self.enabled
	-- An explicit on/off is the user's decision and outranks a pending test-mode
	-- restore, which would otherwise flip the addon back when the sample expires.
	self.testRestoreDisabled = false
end

local function RefreshEnabledDisplay(self)
	if self.enabled then
		self:ScanVisibleNameplates()
		self.UpdateAllNameplates()
	else
		self.HideAllNameplates()
	end
end

-- Config.lua is last in the TOC, so these hooks genuinely do not exist while Init.lua
-- and Nameplates.lua run their load-time bodies.
local function NotifyConfig(self)
	if self.RefreshConfig then
		self.RefreshConfig()
	end
end

-- Bulk replacements swap the color tables out from under an open picker session, so
-- the session has to end before the swap rather than resurrect a stale color later.
local function EndConfigColorPicker(self)
	if self.EndColorPicker then
		self.EndColorPicker()
	end
end

local function ApplySettingsChange(self, changeKind)
	if self.ApplyDisplaySettings then
		self.ApplyDisplaySettings(changeKind)
	end
	NotifyConfig(self)
end

function addon:RestoreDisplaySettings(snapshot)
	if type(snapshot) ~= "table" then
		return
	end

	EndConfigColorPicker(self)
	CopyKeys(snapshot, self.db, self.layoutSettingKeys)
	CopyKeys(snapshot, self.db, self.appearanceSettingKeys)
	CopyKeys(snapshot, self.db, self.behaviorSettingKeys)
	local enabledChanged = self.enabled ~= (snapshot.enabled and true or false)
	SetEnabledValue(self, snapshot.enabled)
	if self.ApplyDisplaySettings then
		self.ApplyDisplaySettings("all")
	end
	if enabledChanged then
		RefreshEnabledDisplay(self)
	end
	NotifyConfig(self)
end

function addon:SetEnabled(enabled)
	SetEnabledValue(self, enabled)
	RefreshEnabledDisplay(self)
	NotifyConfig(self)
end

local function ResetSettings(self, keys, changeKind)
	CopyKeys(self.defaults, self.db, keys)
	ApplySettingsChange(self, changeKind)
end

function addon:ResetLayoutSettings()
	-- Layout keys hold no color tables, so an open picker is left alone here.
	ResetSettings(self, self.layoutSettingKeys, "layout")
end

function addon:ResetAppearanceSettings()
	EndConfigColorPicker(self)
	ResetSettings(self, self.appearanceSettingKeys, "style")
end

function addon:ResetAllSettings()
	EndConfigColorPicker(self)
	CopyKeys(self.defaults, self.db, self.layoutSettingKeys)
	CopyKeys(self.defaults, self.db, self.appearanceSettingKeys)
	CopyKeys(self.defaults, self.db, self.behaviorSettingKeys)
	local enabledChanged = self.enabled ~= self.defaults.enabled
	SetEnabledValue(self, self.defaults.enabled)
	if self.ApplyDisplaySettings then
		self.ApplyDisplaySettings("all")
	end
	if enabledChanged then
		RefreshEnabledDisplay(self)
	end
	NotifyConfig(self)
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
		-- A diagnostic sample must not undo an explicit /threatplating off, so this
		-- flips the runtime flag only and leaves db.enabled alone. Nameplates.lua
		-- restores it when testModeUntil expires.
		if not addon.enabled then
			addon.enabled = true
			addon.testRestoreDisabled = true
		end
		addon.testModeUntil = GetTime() + 8
		addon.testPullThresholdWarning = argument == "orange"
		addon:ScanVisibleNameplates()
		addon.UpdateAllNameplates()
		local suffix = addon.testRestoreDisabled and " (enabled for the sample only)" or ""
		if addon.testPullThresholdWarning then
			Print("showing orange threshold samples on eligible visible nameplates for 8 seconds"
				.. suffix .. ".")
		else
			Print("showing sample counters on eligible visible nameplates for 8 seconds"
				.. suffix .. ".")
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
	elseif command == "probe" then
		local lines = addon.DescribeClientAPIs and addon.DescribeClientAPIs()
		if not lines then
			Print("client probe unavailable.")
		else
			Print("client probe:")
			for index = 1, #lines do
				print("  " .. lines[index])
			end
		end
	elseif command == "close" then
		addon.CloseConfig()
	elseif command == "" then
		addon.ToggleConfig()
	else
		Print("unknown command '" .. command
			.. "'. Use on, off, test [orange], status, probe, reset, close,"
			.. " or /threatplating on its own for the editor.")
	end
end
