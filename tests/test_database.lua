local Frame = {}
Frame.__index = Frame

function Frame:RegisterEvent(event)
	self.events[event] = true
end

function Frame:SetScript(scriptName, callback)
	self.scripts[scriptName] = callback
end

function Frame:UnregisterEvent(event)
	self.events[event] = nil
end

local frames = {}

function CreateFrame()
	local frame = setmetatable({
		events = {},
		scripts = {},
	}, Frame)
	frames[#frames + 1] = frame
	return frame
end

UIParent = {
	GetHeight = function()
		return 1080
	end,
	GetWidth = function()
		return 1920
	end,
}
SlashCmdList = {}

local function LoadInitWithDatabase(database)
	ThreatPlatingDB = database
	local addon = {}
	assert(loadfile("Init.lua"))("ThreatPlating", addon)
	return addon
end

local legacyBackgroundAddon = LoadInitWithDatabase({
	anchorPoint = "TOP",
	autoWidth = false,
	badgeHeight = 24,
	badgeWidth = 80,
	enabled = false,
	fontSize = 18,
	offsetX = 12,
	offsetY = -7,
	relativePoint = "BOTTOM",
	showBackground = true,
	windowHeight = 600,
	windowOffsetX = 33,
	windowOffsetY = -22,
	windowWidth = 700,
})
assert(legacyBackgroundAddon.db.schemaVersion == 2, "legacy databases should migrate")
assert(legacyBackgroundAddon.db.anchorPoint == "TOP", "migration should preserve placement")
assert(legacyBackgroundAddon.db.badgeWidth == 80, "migration should preserve badge size")
assert(legacyBackgroundAddon.db.fontSize == 18, "migration should preserve font size")
assert(
	legacyBackgroundAddon.db.autoWidth == false,
	"migration should preserve automatic width"
)
assert(legacyBackgroundAddon.db.enabled == false, "migration should preserve enabled state")
assert(
	legacyBackgroundAddon.db.windowWidth == 700,
	"migration should preserve window geometry"
)
assert(
	legacyBackgroundAddon.db.backgroundColor[4] == 0.90,
	"legacy backgrounds should retain opacity"
)
assert(
	legacyBackgroundAddon.db.borderMode == "semantic",
	"legacy backgrounds should use semantic borders"
)
assert(
	legacyBackgroundAddon.db.showBackground == nil,
	"legacy background fields should be removed"
)

local legacyTransparentAddon = LoadInitWithDatabase({
	showBackground = false,
})
assert(
	legacyTransparentAddon.db.backgroundColor[4] == 0,
	"disabled legacy backgrounds should migrate to transparent"
)
assert(
	legacyTransparentAddon.db.borderMode == "off",
	"disabled legacy backgrounds should migrate without a border"
)

local addon = LoadInitWithDatabase({
	badgeHeight = 14,
	badgeWidth = -100,
	backgroundColor = { 0.2, math.huge - math.huge, 2, -1 },
	borderColor = { math.huge, 0.4, 0.5, 2 },
	collapsedSections = {
		general = "invalid",
		position = true,
	},
	enabled = "invalid",
	fontPreset = "invalid",
	fontSize = 32,
	offsetX = math.huge - math.huge,
	offsetY = math.huge,
	palette = "hostile",
	safeColor = { -1, 0.5, math.huge },
	schemaVersion = 2,
	windowHeight = false,
	windowOffsetX = 99999,
	windowOffsetY = -99999,
})

assert(addon.version == "0.6.2", "runtime version should match the release")
assert(addon.db.enabled == true, "invalid saved booleans should use defaults")
assert(addon.db.offsetX == 6, "non-finite saved offsets should use defaults")
assert(addon.db.offsetY == 0, "infinite saved offsets should use defaults")
assert(addon.db.badgeWidth == 36, "finite saved dimensions should be clamped")
assert(addon.db.badgeHeight == 14, "badge and font size should validate independently")
assert(addon.db.windowHeight == 620, "invalid saved dimensions should use defaults")
assert(addon.db.backgroundColor[1] == 0.2, "valid color components should survive")
assert(addon.db.backgroundColor[2] == 0.025, "non-finite color components should reset")
assert(addon.db.backgroundColor[3] == 1, "color components should clamp high")
assert(addon.db.backgroundColor[4] == 0, "alpha components should clamp low")
assert(
	addon.db.borderColor[1] == 0.65,
	"non-finite custom border components should reset"
)
assert(addon.db.borderColor[4] == 1, "custom border alpha should clamp")
assert(addon.db.safeColor[1] == 0, "semantic colors should clamp independently")
assert(addon.db.safeColor[2] == 0.5, "valid semantic color components should survive")
assert(
	addon.db.safeColor[3] == 0.35,
	"non-finite semantic colors should reset independently"
)
assert(addon.db.fontPreset == "nameplate", "invalid font presets should reset")
assert(addon.db.palette == "default", "invalid palette identifiers should reset")
assert(
	addon.db.collapsedSections.general == false,
	"invalid collapsed states should reset"
)
assert(
	addon.db.collapsedSections.position == true,
	"valid collapsed states should survive"
)
assert(addon.db.windowOffsetX == 570, "off-screen horizontal geometry should recover")
assert(addon.db.windowOffsetY == -230, "off-screen vertical geometry should recover")

local databaseFrame
for _, frame in ipairs(frames) do
	if frame.events.ADDON_LOADED then
		databaseFrame = frame
	end
end
assert(databaseFrame, "database event frame should wait for ADDON_LOADED")

local runtimeDatabase = addon.db
local lateLoadedDatabase = addon.CopyValue(addon.db)
lateLoadedDatabase.schemaVersion = nil
lateLoadedDatabase.showBackground = true
lateLoadedDatabase.backgroundColor = nil
lateLoadedDatabase.borderMode = nil
lateLoadedDatabase.padding = 13
ThreatPlatingDB = lateLoadedDatabase
databaseFrame.scripts.OnEvent(databaseFrame, "ADDON_LOADED", "AnotherAddon")
assert(
	databaseFrame.events.ADDON_LOADED,
	"unrelated addon load events should not finalize saved variables"
)
databaseFrame.scripts.OnEvent(databaseFrame, "ADDON_LOADED", "ThreatPlating")
assert(addon.db == runtimeDatabase, "database adoption should preserve runtime table identity")
assert(
	ThreatPlatingDB == runtimeDatabase,
	"the saved global should point at the table mutated by the editor"
)
assert(addon.db.padding == 13, "late-loaded custom settings should be adopted")
assert(addon.db.schemaVersion == 2, "late-loaded legacy settings should migrate")
assert(
	addon.db.backgroundColor[4] == 0.90 and addon.db.borderMode == "semantic",
	"late-loaded legacy appearance should migrate"
)
addon.db.padding = 17
assert(
	ThreatPlatingDB.padding == 17,
	"editor mutations should update the table serialized by WoW"
)
assert(
	not databaseFrame.events.ADDON_LOADED,
	"database initialization should finish after the addon’s load event"
)

print("Database runtime: migration and persistence tests passed")
