local Frame = {}
Frame.__index = Frame

function Frame:ClearAllPoints()
	self.points = {}
end

function Frame:CreateFontString()
	local fontString = setmetatable({
		points = {},
		text = "",
		shown = true,
	}, { __index = Frame })
	return fontString
end

function Frame:CreateTexture()
	local texture = setmetatable({
		points = {},
		shown = true,
	}, { __index = Frame })
	return texture
end

function Frame:EnableMouse()
end

function Frame:GetBottom()
	local _, centerY = self:GetCenter()
	return centerY - self:GetHeight() / 2
end

function Frame:GetCenter()
	return self.centerX or 0, self.centerY or 0
end

function Frame:GetChecked()
	return self.checked
end

function Frame:GetFrameLevel()
	return self.frameLevel or 1
end

function Frame:GetHeight()
	return self.height or 0
end

function Frame:GetLeft()
	local centerX = self:GetCenter()
	return centerX - self:GetWidth() / 2
end

function Frame:GetRight()
	local centerX = self:GetCenter()
	return centerX + self:GetWidth() / 2
end

function Frame:GetStringWidth()
	return #self.text * 7
end

function Frame:GetTop()
	local _, centerY = self:GetCenter()
	return centerY + self:GetHeight() / 2
end

function Frame:GetWidth()
	return self.width or 0
end

function Frame:Hide()
	local wasShown = self.shown
	self.shown = false
	if wasShown and self.scripts.OnHide then
		self.scripts.OnHide(self)
	end
	if wasShown and self.hooks.OnHide then
		self.hooks.OnHide(self)
	end
end

function Frame:HookScript(scriptName, callback)
	self.hooks[scriptName] = callback
end

function Frame:IsShown()
	return self.shown
end

function Frame:RegisterEvent(event)
	self.events[event] = true
end

function Frame:RegisterForDrag()
end

function Frame:SetAllPoints()
end

function Frame:SetBackdrop()
end

function Frame:SetBackdropBorderColor(...)
	self.borderColor = { ... }
end

function Frame:SetBackdropColor()
end

function Frame:SetChecked(checked)
	self.checked = checked
end

function Frame:SetClampedToScreen()
end

function Frame:SetClipsChildren()
end

function Frame:SetColorTexture()
end

function Frame:SetFont(path, size, flags)
	self.fontPath = path
	self.fontSize = size
	self.fontFlags = flags
	return true
end

function Frame:SetFontObject(fontObject)
	self.fontObject = fontObject
end

function Frame:SetFrameStrata()
end

function Frame:SetFrameLevel(level)
	self.frameLevel = level
end

function Frame:SetHeight(height)
	self.height = height
end

function Frame:SetPoint(...)
	self.points[#self.points + 1] = { ... }
end

function Frame:SetJustifyH()
end

function Frame:SetMovable()
end

function Frame:SetResizable()
end

function Frame:SetResizeBounds()
end

function Frame:SetScript(scriptName, callback)
	self.scripts[scriptName] = callback
end

function Frame:SetShadowColor()
end

function Frame:SetShadowOffset()
end

function Frame:SetSize(width, height)
	self.width = width
	self.height = height
end

function Frame:SetText(text)
	self.text = text
end

function Frame:SetTextColor(...)
	self.textColor = { ... }
end

function Frame:SetTextHeight(height)
	self.fontSize = height
end

function Frame:SetTexture(texture)
	self.texture = texture
end

function Frame:SetVertexColor()
end

function Frame:SetWidth(width)
	self.width = width
end

function Frame:Show()
	local wasShown = self.shown
	self.shown = true
	if not wasShown and self.scripts.OnShow then
		self.scripts.OnShow(self)
	end
end

function Frame:StartMoving()
end

function Frame:StartSizing()
end

function Frame:StopMovingOrSizing()
end

local frames = {}
local plates = {}
local units = {
	nameplate1 = true,
	pet = true,
	player = true,
}
local threat = {}
local now = 100
local nameplateScanCount = 0
local threatQueryCount = 0
local assignedRole = "NONE"
local isMainTank = false
local playerClass = "WARRIOR"
local activeFormSpellID
local talentPoints = { 0, 0, 41 }

function CreateFrame(_, _, parent)
	local frame = setmetatable({
		events = {},
		frameLevel = parent and parent:GetFrameLevel() + 1 or 1,
		hooks = {},
		parent = parent,
		points = {},
		scripts = {},
		shown = true,
	}, Frame)
	frames[#frames + 1] = frame
	return frame
end

C_NamePlate = {}

function C_NamePlate.GetNamePlateForUnit(unit)
	return plates[unit]
end

function C_NamePlate.GetNamePlates()
	nameplateScanCount = nameplateScanCount + 1
	local visible = {}
	for _, plate in pairs(plates) do
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
	return isMainTank
end

function GetShapeshiftForm()
	return activeFormSpellID and 1 or 0
end

function GetShapeshiftFormInfo()
	return nil, activeFormSpellID ~= nil, true, activeFormSpellID
end

function GetTalentTabInfo(index)
	return index, "Tree " .. index, nil, nil, talentPoints[index], "Tree" .. index
end

function GetTime()
	return now
end

function IsInGroup()
	return false
end

function IsInRaid()
	return false
end

function UnitCanAttack(_, unit)
	return unit == "nameplate1" or unit == "nameplate2"
end

function UnitClass()
	return playerClass, playerClass
end

function UnitDetailedThreatSituation(source, enemy)
	threatQueryCount = threatQueryCount + 1
	local result = threat[source .. ":" .. enemy]
	if not result then
		return nil
	end
	return unpack(result)
end

function UnitExists(unit)
	return units[unit] == true
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
	return assignedRole
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
	events = {},
	frameLevel = 0,
	height = 1080,
	hooks = {},
	points = {},
	scripts = {},
	shown = true,
	width = 1920,
}, Frame)

ThreatPlatingDB = {
	badgeHeight = 14,
	badgeWidth = -100,
	enabled = "invalid",
	fontSize = 32,
	offsetX = math.huge - math.huge,
	offsetY = math.huge,
	windowHeight = false,
}

local addon = {}
assert(loadfile("Init.lua"))("ThreatPlating", addon)
assert(loadfile("Threat.lua"))("ThreatPlating", addon)
assert(loadfile("Nameplates.lua"))("ThreatPlating", addon)
assert(loadfile("Config.lua"))("ThreatPlating", addon)

assert(addon.version == "0.4.0", "runtime version should match the release")
assert(addon.db.enabled == true, "invalid saved booleans should use defaults")
assert(addon.db.offsetX == 6, "non-finite saved offsets should use defaults")
assert(addon.db.offsetY == 0, "infinite saved offsets should use defaults")
assert(addon.db.badgeWidth == 36, "finite saved dimensions should be clamped")
assert(addon.db.badgeHeight == 36, "saved badge height should fit the font")
assert(addon.db.windowHeight == 570, "invalid saved dimensions should use defaults")

local function NewPlate(unit)
	local plate = CreateFrame("Frame")
	local healthBar = CreateFrame("Frame", nil, plate)
	plate.UnitFrame = {
		HealthBarsContainer = healthBar,
		unit = unit,
	}
	plate.namePlateUnitToken = unit
	plates[unit] = plate
	return plate
end

local eventFrame = frames[1]

local function Dispatch(event, unit)
	assert(eventFrame.events[event], "event is not registered: " .. event)
	eventFrame.scripts.OnEvent(eventFrame, event, unit)
end

local function Update(elapsed)
	now = now + elapsed
	eventFrame.scripts.OnUpdate(eventFrame, elapsed)
end

local function AssertColor(frame, red, green, blue, label)
	local color = frame.textColor
	assert(
		color and color[1] == red and color[2] == green and color[3] == blue,
		label
	)
end

local plate = NewPlate("nameplate1")
threat["player:nameplate1"] = { true, 3, 100, 100, 100000 }
threat["pet:nameplate1"] = { false, 1, 80, 80, 80000 }

Dispatch("NAME_PLATE_UNIT_ADDED", "nameplate1")
Update(0.20)

assert(plate.ThreatPlatingOverlay.shown, "leader overlay should be shown")
assert(plate.ThreatPlatingOverlay.text.text == "+200", "leader overlay should show +200")
assert(addon.playerIsTank, "Protection talents should select tank colors")
AssertColor(plate.ThreatPlatingOverlay.text, 0.35, 1, 0.35, "tank leader should be green")

threat["player:nameplate1"] = { true, 3, 50, 50, 50000 }
Dispatch("UNIT_THREAT_SITUATION_UPDATE", "nameplate1")
Update(0.05)
assert(
	plate.ThreatPlatingOverlay.text.text == "-500",
	"tanking state must not override a higher inferred raw threat"
)
AssertColor(plate.ThreatPlatingOverlay.text, 1, 0.32, 0.26, "tank deficit should be red")

local scansBeforeThreatEvent = nameplateScanCount
threat["player:nameplate1"] = { false, 1, 50, 50, 50000 }
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate1")
Update(0.05)

assert(plate.ThreatPlatingOverlay.shown, "deficit overlay should remain shown")
assert(plate.ThreatPlatingOverlay.text.text == "-500", "deficit overlay should show -500")
assert(nameplateScanCount == scansBeforeThreatEvent, "event refresh should not perform a fallback scan")

talentPoints = { 41, 0, 0 }
Dispatch("PLAYER_TALENT_UPDATE")
Update(0.05)
assert(not addon.playerIsTank, "changing from Protection should select non-tank colors")
AssertColor(plate.ThreatPlatingOverlay.text, 0.35, 1, 0.35, "non-tank deficit should be green")

threat["player:nameplate1"] = { true, 3, 100, 100, 100000 }
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate1")
Update(0.05)
assert(plate.ThreatPlatingOverlay.text.text == "+200", "non-tank leader text should keep its sign")
AssertColor(plate.ThreatPlatingOverlay.text, 1, 0.32, 0.26, "non-tank leader should be red")

threat["player:nameplate1"] = { false, 1, 95.5, 105, 105000 }
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate1")
Update(0.05)
assert(plate.ThreatPlatingOverlay.text.text == "+50", "threshold warning should keep the raw lead")
AssertColor(
	plate.ThreatPlatingOverlay.text,
	1,
	0.62,
	0.12,
	"raw leader below the pull threshold should be orange"
)

threat["pet:nameplate1"] = { false, 1, 100, 110, 110000 }
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate1")
Update(0.05)
assert(plate.ThreatPlatingOverlay.text.text == "-50", "threshold warning should preserve a deficit")
AssertColor(
	plate.ThreatPlatingOverlay.text,
	1,
	0.62,
	0.12,
	"threshold warning should be orange when another contender leads"
)
threat["pet:nameplate1"] = { false, 1, 80, 80, 80000 }

assignedRole = "TANK"
Dispatch("PLAYER_ROLES_ASSIGNED")
Update(0.05)
assert(addon.playerIsTank, "assigned tank role should override talents")
AssertColor(
	plate.ThreatPlatingOverlay.text,
	1,
	0.62,
	0.12,
	"pull-threshold warning should override role colors"
)

threat["player:nameplate1"] = { true, 3, 100, 100, 100000 }
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate1")
Update(0.05)
AssertColor(plate.ThreatPlatingOverlay.text, 0.35, 1, 0.35, "assigned tank leader should be green")

assignedRole = "DAMAGER"
talentPoints = { 0, 0, 41 }
Dispatch("PLAYER_ROLES_ASSIGNED")
Update(0.05)
assert(not addon.playerIsTank, "assigned damage role should override Protection talents")

assignedRole = "NONE"
playerClass = "DRUID"
talentPoints = { 0, 41, 0 }
activeFormSpellID = 5487
Dispatch("UPDATE_SHAPESHIFT_FORM")
Update(0.05)
assert(addon.playerIsTank, "Bear Form should select tank colors")

activeFormSpellID = 768
Dispatch("UPDATE_SHAPESHIFT_FORM")
Update(0.05)
assert(not addon.playerIsTank, "Cat Form should select non-tank colors")

playerClass = "PALADIN"
activeFormSpellID = nil
talentPoints = { 0, 41, 0 }
Dispatch("ACTIVE_TALENT_GROUP_CHANGED")
Update(0.05)
assert(addon.playerIsTank, "an active Protection talent group should select tank colors")

local scansBeforeContinuousEvents = nameplateScanCount
for _ = 1, 4 do
	Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate1")
	Update(0.05)
end
assert(
	nameplateScanCount == scansBeforeContinuousEvents + 1,
	"continuous threat events must not starve the fallback scan"
)

Dispatch("NAME_PLATE_UNIT_REMOVED", "nameplate1")
assert(not plate.ThreatPlatingOverlay.shown, "removed plate overlay should be hidden")
assert(plate.ThreatPlatingOverlay.unit == nil, "removed plate should release its unit token")
plates.nameplate1 = nil
units.nameplate1 = nil

units.nameplate1 = true
local stalePlate = NewPlate("nameplate1")
Dispatch("NAME_PLATE_UNIT_ADDED", "nameplate1")
Update(0.05)
assert(stalePlate.ThreatPlatingOverlay.shown, "newly added replacement candidate should update")

local replacementPlate = NewPlate("nameplate1")
Dispatch("UNIT_THREAT_SITUATION_UPDATE", "nameplate1")
Update(0.05)
assert(not stalePlate.ThreatPlatingOverlay.shown, "a stale pooled plate should hide before the next poll")

Update(0.20)
assert(replacementPlate.ThreatPlatingOverlay.shown, "the fallback scan should attach to a replacement plate")
assert(stalePlate.ThreatPlatingOverlay.unit == nil, "a replaced pooled plate should release its unit token")

plates.nameplate1 = nil
units.nameplate1 = nil
Update(0.20)
assert(not replacementPlate.ThreatPlatingOverlay.shown, "the fallback scan should prune a missing plate")
assert(replacementPlate.ThreatPlatingOverlay.unit == nil, "a pruned plate should release its unit token")

units.nameplate2 = true
local playerPlate = NewPlate("nameplate2")
Dispatch("NAME_PLATE_UNIT_ADDED", "nameplate2")
Update(0.20)
assert(playerPlate.ThreatPlatingOverlay == nil, "player-controlled plates should be ignored")

addon.db.offsetX = 99
addon:ResetBadgeSettings()
assert(addon.db.offsetX == 6, "reset should restore the default badge offset")

units.nameplate1 = true
local disabledPlate = NewPlate("nameplate1")
Dispatch("NAME_PLATE_UNIT_ADDED", "nameplate1")
Update(0.05)
assert(disabledPlate.ThreatPlatingOverlay.shown, "enabled addon should update a newly visible plate")

addon:SetEnabled(false)
assert(addon.db.enabled == false, "disabled state should be saved")
local scansWhileDisabled = nameplateScanCount
local queriesWhileDisabled = threatQueryCount
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate1")
Update(0.50)
assert(nameplateScanCount == scansWhileDisabled, "disabled addon should not scan nameplates")
assert(threatQueryCount == queriesWhileDisabled, "disabled addon should not query threat")

addon:SetEnabled(true)
assert(addon.db.enabled == true, "enabled state should be saved")

SlashCmdList.THREATPLATING("test orange")
assert(addon.testPullThresholdWarning, "orange visual test should select the threshold color")
AssertColor(
	disabledPlate.ThreatPlatingOverlay.text,
	1,
	0.62,
	0.12,
	"orange visual test should color visible samples"
)

SlashCmdList.THREATPLATING("test")
assert(not addon.testPullThresholdWarning, "normal visual test should clear the orange override")
AssertColor(
	disabledPlate.ThreatPlatingOverlay.text,
	0.35,
	1,
	0.35,
	"normal visual test should use detected role colors"
)

addon.ToggleConfig()
assert(addon.configPreviewActive, "opening the configurator should enable live preview")
assert(type(ThreatPlating_OnAddonCompartmentClick) == "function", "addon compartment should open config")
assert(UISpecialFrames[1] == "ThreatPlatingConfigWindow", "Escape-close frame should be registered")
addon.ToggleConfig()
assert(not addon.configPreviewActive, "closing the configurator should stop live preview")

print("Nameplate runtime: smoke test passed")
