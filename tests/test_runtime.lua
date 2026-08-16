local Frame = {}
Frame.__index = Frame

function Frame:ClearAllPoints()
	self.points = {}
	self.clearAllPointsCount = (self.clearAllPointsCount or 0) + 1
end

function Frame:ClearFocus()
	local hadFocus = self.hasFocus
	self.hasFocus = false
	if hadFocus and self.scripts.OnEditFocusLost then
		self.scripts.OnEditFocusLost(self)
	end
end

function Frame:SetFocus()
	self.hasFocus = true
end

function Frame:HasFocus()
	return self.hasFocus == true
end

function Frame:CreateFontString()
	local fontString = setmetatable({
		parent = self,
		points = {},
		scripts = {},
		text = "",
		shown = true,
	}, { __index = Frame })
	self.children[#self.children + 1] = fontString
	return fontString
end

function Frame:CreateTexture()
	local texture = setmetatable({
		parent = self,
		points = {},
		scripts = {},
		shown = true,
	}, { __index = Frame })
	self.children[#self.children + 1] = texture
	return texture
end

function Frame:EnableMouse(enabled)
	self.mouseEnabled = enabled ~= false
end

function Frame.EnableMouseWheel()
end

function Frame:Disable()
	self.enabled = false
end

function Frame:Enable()
	self.enabled = true
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

function Frame:GetFont()
	return self.fontPath, self.fontSize, self.fontFlags
end

function Frame:GetHeight()
	return self.height or 0
end

function Frame:GetText()
	return self.text
end

function Frame:GetTextColor()
	local color = self.textColor or { 1, 1, 1, 1 }
	return color[1], color[2], color[3], color[4]
end

function Frame:GetStatusBarColor()
	local color = self.statusBarColor or { 1, 1, 1, 1 }
	return color[1], color[2], color[3], color[4]
end

function Frame:GetStatusBarTexture()
	return self.statusBarTexture
end

function Frame:GetMinMaxValues()
	return self.minimum or 0, self.maximum or 1
end

function Frame:GetValue()
	return self.value
end

function Frame:GetVerticalScroll()
	return self.verticalScroll or 0
end

function Frame:GetVerticalScrollRange()
	if not self.scrollChild then
		return 0
	end
	return math.max(0, self.scrollChild:GetHeight() - self:GetHeight())
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
	local hooks = wasShown and self.hooks.OnHide
	if hooks then
		for index = 1, #hooks do
			hooks[index](self)
		end
	end
end

-- HookScript appends; it never replaces. Storing a list is what lets a test detect a
-- duplicate hook installed on a recycled frame.
function Frame:HookScript(scriptName, callback)
	local hooks = self.hooks[scriptName]
	if not hooks then
		hooks = {}
		self.hooks[scriptName] = hooks
	end
	hooks[#hooks + 1] = callback
end

function Frame:IsShown()
	return self.shown
end

function Frame:RegisterEvent(event)
	self.events[event] = true
end

function Frame:UnregisterEvent(event)
	self.events[event] = nil
end

function Frame.RegisterForDrag()
end

function Frame:LockHighlight()
	self.highlighted = true
end

function Frame:SetAllPoints(frame)
	self.allPoints = frame or self.parent
end

function Frame.SetBackdrop()
end

function Frame:SetBackdropBorderColor(...)
	self.borderColor = { ... }
	self.setBackdropBorderColorCount = (self.setBackdropBorderColorCount or 0) + 1
end

function Frame:SetBackdropColor(...)
	self.backgroundColor = { ... }
end

function Frame:SetChecked(checked)
	self.checked = checked
end

function Frame.SetClampedToScreen()
end

function Frame:SetClipsChildren()
	self.clipsChildren = true
end

function Frame:SetColorTexture(...)
	self.colorTexture = { ... }
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

function Frame.SetFrameStrata()
end

function Frame:SetFrameLevel(level)
	self.frameLevel = level
end

function Frame:SetPoint(...)
	self.points[#self.points + 1] = { ... }
end

function Frame.SetJustifyH()
end

function Frame.SetAutoFocus()
end

function Frame.SetMaxLetters()
end

function Frame:SetMinMaxValues(minimum, maximum)
	self.minimum = minimum
	self.maximum = maximum
end

function Frame:SetMovable()
	self.movable = true
end

function Frame.SetNumeric()
end

function Frame.SetObeyStepOnDrag()
end

function Frame:SetOrientation(orientation)
	self.orientation = orientation
end

function Frame:SetResizable()
	self.resizable = true
end

function Frame:SetResizeBounds(...)
	self.resizeBounds = { ... }
end

function Frame:SetScript(scriptName, callback)
	self.scripts[scriptName] = callback
end

function Frame.SetShadowColor()
end

function Frame.SetShadowOffset()
end

function Frame:SetStatusBarColor(...)
	self.statusBarColor = { ... }
end

function Frame:SetStatusBarTexture(texture)
	self.statusBarTexture = setmetatable({
		children = {},
		points = {},
		scripts = {},
		shown = true,
		texture = texture,
	}, Frame)
end

function Frame:SetSize(width, height)
	local changed = self.width ~= width or self.height ~= height
	self.width = width
	self.height = height
	if changed and self.scripts.OnSizeChanged then
		self.scripts.OnSizeChanged(self, width, height)
	end
end

function Frame:SetText(text)
	self.text = text
	self.setTextCount = (self.setTextCount or 0) + 1
end

function Frame:SetTextColor(...)
	self.textColor = { ... }
	self.setTextColorCount = (self.setTextColorCount or 0) + 1
end

function Frame:SetTextHeight(height)
	self.fontSize = height
end

function Frame:SetThumbTexture(texture)
	self.thumbTexture = texture
end

function Frame:SetTexture(texture)
	self.texture = texture
end

function Frame:GetTexture()
	return self.texture
end

function Frame.SetVertexColor()
end

function Frame:SetWidth(width)
	local changed = self.width ~= width
	self.width = width
	self.setWidthCount = (self.setWidthCount or 0) + 1
	if changed and self.scripts.OnSizeChanged then
		self.scripts.OnSizeChanged(self, width, self:GetHeight())
	end
end

function Frame:SetHeight(height)
	local changed = self.height ~= height
	self.height = height
	if changed and self.scripts.OnSizeChanged then
		self.scripts.OnSizeChanged(self, self:GetWidth(), height)
	end
end

function Frame:SetScrollChild(child)
	self.scrollChild = child
end

function Frame:SetValue(value)
	self.value = value
	if self.scripts.OnValueChanged then
		self.scripts.OnValueChanged(self, value)
	end
end

function Frame:SetValueStep(step)
	self.valueStep = step
end

function Frame:SetVerticalScroll(value)
	self.verticalScroll = value
end

function Frame:Show()
	local wasShown = self.shown
	self.shown = true
	if not wasShown and self.scripts.OnShow then
		self.scripts.OnShow(self)
	end
end

function Frame.StartMoving()
end

function Frame.StartSizing()
end

function Frame.StopMovingOrSizing()
end

function Frame:UnlockHighlight()
	self.highlighted = false
end

local mock = assert(loadfile("tests/wow_mock.lua"))()(Frame)
local frames = mock.frames
local plates = mock.plates
local units = mock.units
local threat = mock.threat

-- Most runtime assertions exercise exact threat snapshots. Transition behavior has a
-- focused block below; keep it disabled elsewhere so unrelated expectations stay exact.
ThreatPlatingDB = {
	smoothTransitions = false,
}
local addon = {
	testHarness = true,
}
assert(loadfile("tests/load_addon.lua"))()("ThreatPlating", addon)

-- tools\check.ps1 owns cross-file version synchronization.
assert(
	type(addon.version) == "string" and addon.version:match("^%d+%.%d+%.%d+$"),
	"the runtime should expose a dotted release version"
)
assert(addon.updateInterval == 0.10, "fallback poll should run every 0.10 seconds")

local function NewPlate(unit)
	local plate = CreateFrame("Frame")
	local healthBarsContainer = CreateFrame("Frame", nil, plate)
	healthBarsContainer:SetSize(128, 20)
	local healthBar = CreateFrame("StatusBar", nil, healthBarsContainer)
	healthBar:SetSize(128, 20)
	healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	healthBar:SetStatusBarColor(0.61, 0.17, 0.13, 1)
	healthBar:SetMinMaxValues(0, 100)
	healthBar:SetValue(72)
	healthBarsContainer.healthBar = healthBar

	local unitName = healthBarsContainer:CreateFontString(nil, "OVERLAY")
	unitName:SetText(unit .. " baseline")
	unitName:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
	unitName:SetTextColor(1, 0.82, 0.20, 1)
	unitName.centerX = 0
	unitName.centerY = 18

	local healthText = healthBar:CreateFontString(nil, "OVERLAY")
	healthText:SetText("72%")
	healthText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
	healthText:SetTextColor(1, 1, 1, 1)
	healthText.centerX = 0
	healthText.centerY = 0
	healthBar.Text = healthText

	plate.UnitFrame = {
		HealthBarsContainer = healthBarsContainer,
		healthBar = healthBar,
		name = unitName,
		unit = unit,
	}
	plate.baselineName = unit .. " baseline"
	-- Matches NamePlateBaseMixin:SetUnit on the live client; the legacy
	-- namePlateUnitToken / UnitFrame.unit fallbacks are covered separately below.
	plate.unitToken = unit
	plates[unit] = plate
	return plate
end

local eventFrame
for _, frame in ipairs(frames) do
	if frame.events.NAME_PLATE_UNIT_ADDED then
		eventFrame = frame
	end
end
assert(eventFrame, "nameplate event frame should exist")

local function Dispatch(event, unit)
	assert(eventFrame.events[event], "event is not registered: " .. event)
	eventFrame.scripts.OnEvent(eventFrame, event, unit)
end

local function Update(elapsed)
	mock.now = mock.now + elapsed
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
Update(0.10)

assert(plate.ThreatPlatingOverlay.shown, "leader overlay should be shown")
assert(plate.ThreatPlatingOverlay.text.text == "+200", "leader overlay should show +200")
assert(addon.playerIsTank, "Protection talents should select tank colors")
AssertColor(plate.ThreatPlatingOverlay.text, 0.35, 1, 0.35, "tank leader should be green")

local scansBeforePollBoundary = mock.nameplateScanCount
Update(0.099)
assert(
	mock.nameplateScanCount == scansBeforePollBoundary,
	"fallback scan should not run before the 0.10-second boundary"
)
Update(0.002)
assert(
	mock.nameplateScanCount == scansBeforePollBoundary + 1,
	"fallback scan should run after crossing the 0.10-second boundary"
)

assert(
	#plate.hooks.OnHide == 1,
	"a plate should carry exactly one Threat Plating hide hook"
)
plate:Hide()
assert(
	not plate.ThreatPlatingOverlay.shown,
	"hiding a pooled plate must hide its badge"
)
plate:Show()
for _ = 1, 5 do
	Dispatch("NAME_PLATE_UNIT_ADDED", "nameplate1")
end
assert(
	#plate.hooks.OnHide == 1,
	"re-adding a pooled plate must not append a second hide hook"
)
Update(0.05)

-- NamePlateBaseMixin stores the token as unitToken; the other forms are fallbacks
-- for replacement nameplate addons.
plate.unitToken = nil
plate.namePlateUnitToken = "nameplate1"
addon:ScanVisibleNameplates()
assert(
	plate.ThreatPlatingOverlay.unit == "nameplate1",
	"a legacy namePlateUnitToken plate should still resolve"
)
plate.namePlateUnitToken = nil
addon:ScanVisibleNameplates()
assert(
	plate.ThreatPlatingOverlay.unit == "nameplate1",
	"a plate with only UnitFrame.unit should still resolve"
)
plate.unitToken = "nameplate1"
addon:ScanVisibleNameplates()
Update(0.05)

local initialSetTextCount = plate.ThreatPlatingOverlay.text.setTextCount
local initialSetTextColorCount = plate.ThreatPlatingOverlay.text.setTextColorCount
local initialSetWidthCount = plate.ThreatPlatingOverlay.setWidthCount
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate1")
Update(0.05)
assert(
	plate.ThreatPlatingOverlay.text.setTextCount == initialSetTextCount,
	"unchanged threat text should not be assigned again"
)
assert(
	plate.ThreatPlatingOverlay.text.setTextColorCount == initialSetTextColorCount,
	"unchanged threat color should not be assigned again"
)
assert(
	plate.ThreatPlatingOverlay.setWidthCount == initialSetWidthCount,
	"unchanged threat text should not be measured or resized again"
)

-- Live TBC Anniversary 2.5.6 reports rawPercentage=255 for a sole actor
-- that is tanking. The sentinel must not invent a playerThreat / 2.55
-- contender when no pet or other queryable actor exists.
units.pet = false
threat["player:nameplate1"] = { true, 3, 100, 255, 116421 }
addon.UpdateAllNameplates()
Update(0)
assert(
	plate.ThreatPlatingOverlay.text.text == "+1.2k",
	"tanking 255 sentinel should preserve the sole actor's full lead"
)
units.pet = true

-- A sub-100 percentage while tanking contradicts the reference semantics (the
-- tanking player cannot be below 100% of their own threat) and appears for up
-- to one threat push after a taunt or rip. It must not infer a phantom
-- contender at 1000 units; the exact pet reading at 800 units still supplies
-- a real observable deficit against the player's 500.
threat["player:nameplate1"] = { true, 3, 50, 50, 50000 }
Dispatch("UNIT_THREAT_SITUATION_UPDATE", "nameplate1")
Update(0.05)
assert(
	plate.ThreatPlatingOverlay.text.text == "-300",
	"tanking sub-100 percentage must yield the exact deficit, not an inferred one"
)
AssertColor(
	plate.ThreatPlatingOverlay.text,
	0.35,
	1,
	0.35,
	"tank with aggro should stay green despite a raw-threat deficit"
)

local scansBeforeThreatEvent = mock.nameplateScanCount
threat["player:nameplate1"] = { false, 1, 50, 50, 50000 }
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate1")
Update(0.05)

assert(plate.ThreatPlatingOverlay.shown, "deficit overlay should remain shown")
assert(plate.ThreatPlatingOverlay.text.text == "-500", "deficit overlay should show -500")
assert(
	mock.nameplateScanCount == scansBeforeThreatEvent,
	"event refresh should not perform a fallback scan"
)

mock.talentPoints = { 41, 0, 0 }
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

mock.assignedRole = "TANK"
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

mock.assignedRole = "DAMAGER"
mock.talentPoints = { 0, 0, 41 }
Dispatch("PLAYER_ROLES_ASSIGNED")
Update(0.05)
assert(not addon.playerIsTank, "assigned damage role should override Protection talents")

mock.assignedRole = "NONE"
mock.playerClass = "DRUID"
mock.talentPoints = { 0, 41, 0 }
mock.activeFormSpellID = 5487
Dispatch("UPDATE_SHAPESHIFT_FORM")
Update(0.05)
assert(addon.playerIsTank, "Bear Form should select tank colors")

mock.activeFormSpellID = 768
Dispatch("UPDATE_SHAPESHIFT_FORM")
Update(0.05)
assert(not addon.playerIsTank, "Cat Form should select non-tank colors")

mock.playerClass = "WARRIOR"
mock.activeFormSpellID = 71
mock.talentPoints = { 30, 5, 5 }
Dispatch("UPDATE_SHAPESHIFT_FORM")
Update(0.05)
assert(addon.playerIsTank, "Defensive Stance should select tank colors in the runtime path")

mock.activeFormSpellID = 2458
Dispatch("UPDATE_SHAPESHIFT_FORM")
Update(0.05)
assert(not addon.playerIsTank, "Berserker Stance should not select tank colors on Arms talents")

-- A non-numeric spell-ID slot must fail closed rather than reach the comparisons in
-- Threat.IsTankRole, which would silently grade every stance as non-tank.
mock.activeFormSpellID = 71
local realShapeshiftFormInfo = GetShapeshiftFormInfo
GetShapeshiftFormInfo = function()
	return nil, true, true, "not-a-spell-id"
end
Dispatch("UPDATE_SHAPESHIFT_FORM")
Update(0.05)
assert(
	not addon.playerIsTank,
	"a malformed shapeshift spell ID should fail closed without a Lua error"
)
GetShapeshiftFormInfo = realShapeshiftFormInfo
mock.activeFormSpellID = nil

mock.playerClass = "PALADIN"
mock.activeFormSpellID = nil
mock.talentPoints = { 0, 41, 0 }
Dispatch("ACTIVE_TALENT_GROUP_CHANGED")
Update(0.05)
assert(addon.playerIsTank, "an active Protection talent group should select tank colors")

local legacyTalentAPI = GetTalentTabInfo
GetTalentTabInfo = nil
PlayerUtil = {
	IsPlayerEffectivelyTank = function()
		return true
	end,
}
mock.talentPoints = { 41, 0, 0 }
Dispatch("PLAYER_TALENT_UPDATE")
Update(0.05)
assert(addon.playerIsTank, "Blizzard's effective-tank helper should work without legacy talents")

PlayerUtil.IsPlayerEffectivelyTank = function()
	return false
end
Dispatch("PLAYER_TALENT_UPDATE")
Update(0.05)
assert(not addon.playerIsTank, "an explicit false effective-tank result should be respected")

GetTalentTabInfo = legacyTalentAPI
PlayerUtil.IsPlayerEffectivelyTank = function()
	error("unavailable helper")
end
mock.talentPoints = { 0, 41, 0 }
Dispatch("PLAYER_TALENT_UPDATE")
Update(0.05)
assert(addon.playerIsTank, "a throwing effective-tank helper should fall back to legacy talents")
PlayerUtil = nil

mock.isMainTank = 1
mock.playerClass = "MAGE"
mock.talentPoints = { 41, 0, 0 }
Dispatch("GROUP_ROSTER_UPDATE")
Update(0.05)
assert(addon.playerIsTank, "a truthy Classic main-tank assignment should select tank colors")

mock.isMainTank = false
Dispatch("GROUP_ROSTER_UPDATE")
Update(0.05)
assert(not addon.playerIsTank, "clearing the main-tank assignment should restore detected colors")

mock.playerClass = "PALADIN"
mock.talentPoints = { 0, 41, 0 }
Dispatch("ACTIVE_TALENT_GROUP_CHANGED")
Update(0.05)
assert(addon.playerIsTank, "restored Protection talents should restore tank colors")

local scansBeforeContinuousEvents = mock.nameplateScanCount
for _ = 1, 4 do
	Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate1")
	Update(0.05)
end
assert(
	mock.nameplateScanCount == scansBeforeContinuousEvents + 2,
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

Update(0.10)
assert(replacementPlate.ThreatPlatingOverlay.shown, "the fallback scan should attach to a replacement plate")
assert(stalePlate.ThreatPlatingOverlay.unit == nil, "a replaced pooled plate should release its unit token")

plates.nameplate1 = nil
units.nameplate1 = nil
Update(0.10)
assert(not replacementPlate.ThreatPlatingOverlay.shown, "the fallback scan should prune a missing plate")
assert(replacementPlate.ThreatPlatingOverlay.unit == nil, "a pruned plate should release its unit token")

units.nameplate3 = true
local recycledPlate = NewPlate("nameplate3")
threat["player:nameplate3"] = { false, 1, 50, 50, 50000 }
Dispatch("NAME_PLATE_UNIT_ADDED", "nameplate3")
Update(0.05)
assert(recycledPlate.ThreatPlatingOverlay.shown, "eligible recycled plate setup should render")

threat["player:nameplate3"] = "error"
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate3")
Update(0.05)
assert(
	not recycledPlate.ThreatPlatingOverlay.shown,
	"restricted threat queries should hide without escaping the pcall guard"
)

threat["player:nameplate3"] = { false, 1, 50, 50, 50000 }
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate3")
Update(0.05)
assert(recycledPlate.ThreatPlatingOverlay.shown, "plate should recover after a restricted query")

plates.nameplate3 = nil
units.nameplate3 = nil
recycledPlate.unitToken = "nameplate2"
recycledPlate.UnitFrame.unit = "nameplate2"
plates.nameplate2 = recycledPlate
units.nameplate2 = true
Dispatch("NAME_PLATE_UNIT_ADDED", "nameplate2")
assert(
	not recycledPlate.ThreatPlatingOverlay.shown,
	"a pooled overlay must hide immediately when reassigned to a player-controlled unit"
)
assert(
	recycledPlate.ThreatPlatingOverlay.unit == nil,
	"an ineligible pooled plate must release its prior NPC token immediately"
)
plates.nameplate2 = nil
units.nameplate2 = nil

units.nameplate2 = true
local playerPlate = NewPlate("nameplate2")
Dispatch("NAME_PLATE_UNIT_ADDED", "nameplate2")
Update(0.10)
assert(playerPlate.ThreatPlatingOverlay == nil, "player-controlled plates should be ignored")

addon.db.offsetX = 99
addon:ResetAllSettings()
assert(addon.db.offsetX == 6, "reset should restore the default badge offset")

units.nameplate1 = true
local disabledPlate = NewPlate("nameplate1")
Dispatch("NAME_PLATE_UNIT_ADDED", "nameplate1")
Update(0.05)
assert(disabledPlate.ThreatPlatingOverlay.shown, "enabled addon should update a newly visible plate")

threat["player:nameplate1"] = { false, 1, 50, 50, 50000 }
units.nameplate3 = true
local unaffectedPlate = NewPlate("nameplate3")
threat["player:nameplate3"] = { false, 1, 40, 50, 40000 }
Dispatch("NAME_PLATE_UNIT_ADDED", "nameplate3")
Update(0.05)
assert(unaffectedPlate.ThreatPlatingOverlay.shown, "second eligible plate should render")

local queriesBeforeTargetedRefresh = mock.threatQueryCount
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate1")
Update(0.05)
assert(
	mock.threatQueryCount == queriesBeforeTargetedRefresh + 2,
	"a threat event should query only its affected visible plate"
)

Dispatch("NAME_PLATE_UNIT_REMOVED", "nameplate3")
plates.nameplate3 = nil
units.nameplate3 = nil

addon:SetEnabled(false)
assert(addon.db.enabled == false, "disabled state should be saved")
local scansWhileDisabled = mock.nameplateScanCount
local queriesWhileDisabled = mock.threatQueryCount
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate1")
Update(0.50)
assert(
	mock.nameplateScanCount == scansWhileDisabled,
	"disabled addon should not scan nameplates"
)
assert(
	mock.threatQueryCount == queriesWhileDisabled,
	"disabled addon should not query threat"
)

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

addon:SetEnabled(false)
SlashCmdList.THREATPLATING("test")
assert(addon.enabled == true, "the visual test should sample even while the addon is disabled")
assert(addon.db.enabled == false, "the visual test must not persist an enabled state")
mock.now = mock.now + 9
Update(0.05)
assert(addon.enabled == false, "the visual test should restore the disabled state on expiry")
assert(
	addon.testRestoreDisabled == false,
	"the restore flag should clear once the sample window closes"
)
assert(addon.db.enabled == false, "expiry must leave the saved disabled state untouched")

-- An explicit /threatplating on during the sample window must win over the pending
-- restore, or the addon would switch itself back off when the sample expires.
SlashCmdList.THREATPLATING("test")
assert(addon.testRestoreDisabled == true, "a sample while off should arm the restore")
SlashCmdList.THREATPLATING("on")
assert(addon.testRestoreDisabled == false, "an explicit enable should cancel the restore")
mock.now = mock.now + 9
Update(0.05)
assert(addon.enabled == true, "an explicit enable must survive sample expiry")
assert(addon.db.enabled == true, "an explicit enable should persist")
addon.testModeUntil = 0

local function AssertNear(actual, expected, label)
	assert(actual and math.abs(actual - expected) < 0.0001, label)
end

local function FindControl(labelText)
	for _, control in ipairs(addon.ConfigTest.getControls()) do
		if control.label and control.label.text == labelText then
			return control
		end
	end
	error("missing config control: " .. labelText)
end

local function FindFrame(predicate)
	for _, frame in ipairs(frames) do
		if predicate(frame) then
			return frame
		end
	end
end

local function FindChildText(frame, text)
	for _, child in ipairs(frame.children or {}) do
		if child.text == text then
			return true
		end
	end
	return false
end

local framesBeforeEditor = #frames
addon.ToggleConfig()
assert(addon.configPreviewActive, "opening the configurator should enable live preview")
assert(type(ThreatPlating_OnAddonCompartmentClick) == "function", "addon compartment should open config")
assert(UISpecialFrames[1] == "ThreatPlatingConfigWindow", "Escape-close frame should be registered")
local baselineHealthBar = addon.ConfigTest.getPreviewHealthBar()
assert(
	baselineHealthBar:GetStatusBarTexture():GetTexture()
		== "Interface\\TargetingFrame\\UI-StatusBar",
	"the preview should reuse the visible nameplate’s health texture"
)
local baselineRed, baselineGreen, baselineBlue = baselineHealthBar:GetStatusBarColor()
AssertNear(baselineRed, 0.61, "visible nameplate baseline red")
AssertNear(baselineGreen, 0.17, "visible nameplate baseline green")
AssertNear(baselineBlue, 0.13, "visible nameplate baseline blue")
assert(
	addon.ConfigTest.getPreviewUnitName():GetText() == disabledPlate.baselineName,
	"the preview should reuse the current visible plate name"
)
assert(
	addon.ConfigTest.getPreviewHealthText():GetText() == "72%",
	"the preview should reuse the current visible plate health text"
)
assert(
	addon.ConfigTest.getPreviewSourceText():GetText() == "Current visible nameplate baseline",
	"the preview should identify its live nameplate baseline"
)

local window = addon.ConfigTest.getWindow()
units.nameplate3 = true
local targetBaselinePlate = NewPlate("nameplate3")
targetBaselinePlate.UnitFrame.healthBar:SetStatusBarColor(0.20, 0.40, 0.60, 1)
targetBaselinePlate.UnitFrame.name:SetText("Current target baseline")
threat["player:nameplate3"] = { false, 1, 50, 50, 50000 }
Dispatch("NAME_PLATE_UNIT_ADDED", "nameplate3")
mock.targetPlateUnit = "nameplate3"
window.scripts.OnUpdate(window, 0.50)
assert(
	addon.ConfigTest.getPreviewUnitName():GetText() == "Current target baseline",
	"the preview should prefer and follow the current visible target plate"
)
baselineRed, baselineGreen, baselineBlue = baselineHealthBar:GetStatusBarColor()
AssertNear(baselineRed, 0.20, "target baseline red")
AssertNear(baselineGreen, 0.40, "target baseline green")
AssertNear(baselineBlue, 0.60, "target baseline blue")
-- referenceVisual is one reused table, so a plate with no readable name must not be
-- drawn with the previous plate's font, offset, and color.
local populatedVisual = addon.GetReferenceNameplateVisual()
assert(populatedVisual.nameFontPath ~= nil, "a named plate should populate the name font")
assert(populatedVisual.nameOffsetY ~= nil, "a named plate should populate the name offset")
targetBaselinePlate.UnitFrame.name:SetText("")
local clearedVisual = addon.GetReferenceNameplateVisual()
assert(
	clearedVisual.nameText == nil,
	"a plate with no readable name must not leak the previous name text"
)
assert(
	clearedVisual.nameFontPath == nil,
	"a plate with no readable name must not leak the previous font"
)
assert(
	clearedVisual.nameOffsetY == nil,
	"a plate with no readable name must not leak the previous offset"
)
targetBaselinePlate.UnitFrame.name:SetText("Current target baseline")

mock.targetPlateUnit = nil
Dispatch("NAME_PLATE_UNIT_REMOVED", "nameplate3")
plates.nameplate3 = nil
units.nameplate3 = nil
window.scripts.OnUpdate(window, 0.50)
assert(
	addon.ConfigTest.getPreviewUnitName():GetText() == disabledPlate.baselineName,
	"the preview should return to another current plate after target removal"
)

plates.nameplate1 = nil
units.nameplate1 = nil
window.scripts.OnUpdate(window, 0.50)
assert(
	addon.ConfigTest.getPreviewSourceText():GetText() == "Default 128 × 20 nameplate baseline",
	"the preview should identify the verified fallback when no visible plate is suitable"
)
assert(
	baselineHealthBar:GetWidth() == 128 and baselineHealthBar:GetHeight() == 20,
	"the preview fallback should use the verified modern nameplate dimensions"
)
plates.nameplate1 = disabledPlate
units.nameplate1 = true
window.scripts.OnUpdate(window, 0.50)

local framesAfterEditor = #frames
assert(window.layoutMode == "wide", "the default editor should use the wide layout")
window:SetSize(600, 600)
assert(window.layoutMode == "narrow", "narrow windows should stack preview above controls")
assert(#frames == framesAfterEditor, "responsive reflow should not recreate controls")
window:SetSize(520, 520)
local editorScroll = addon.ConfigTest.getScrollFrame()
local editorScrollBar = addon.ConfigTest.getScrollBar()
local scrollRange = editorScroll:GetVerticalScrollRange()
assert(scrollRange > 0, "minimum-size editors should scroll long controls")
editorScroll.scripts.OnScrollRangeChanged(editorScroll, 0, scrollRange)
assert(editorScrollBar:IsShown(), "the anonymous scrollbar should appear for overflowing controls")
editorScroll.scripts.OnMouseWheel(editorScroll, -1)
assert(editorScroll:GetVerticalScroll() == 48, "mouse wheel input should scroll the controls pane")
assert(
	addon.ConfigTest.getPreviewCanvas().clipsChildren,
	"the draggable preview should remain clipped to its canvas"
)
window:SetSize(900, 700)
assert(window.layoutMode == "wide", "wide windows should place preview beside controls")
assert(#frames == framesAfterEditor, "wide reflow should reuse every existing frame")
assert(framesAfterEditor > framesBeforeEditor, "opening the editor should create its controls once")

window.centerX = 1392.6
window.centerY = 452.6
addon.ConfigTest.saveWindowPosition()
assert(addon.db.windowOffsetX == 433, "window dragging should save a normalized X offset")
assert(addon.db.windowOffsetY == -87, "window dragging should save a normalized Y offset")
window.centerX = 9000
window.centerY = -9000
addon.ConfigTest.saveWindowPosition()
assert(addon.db.windowOffsetX == 4000, "window dragging should clamp the saved X offset")
assert(addon.db.windowOffsetY == -2400, "window dragging should clamp the saved Y offset")
window.centerX = 960
window.centerY = 540
addon.ConfigTest.saveWindowPosition()

local namedFrameCount = 0
for _, frame in ipairs(frames) do
	if frame.name then
		namedFrameCount = namedFrameCount + 1
		assert(
			frame.name == "ThreatPlatingConfigWindow",
			"the configurator window must be the only named addon frame"
		)
	end
end
assert(namedFrameCount == 1, "the configurator should create exactly one named frame")

local sections = addon.ConfigTest.getSections()
assert(#sections == 5, "all progressive-disclosure sections should exist")
local expectedControlLabels = {
	"Enable threat counters",
	"Smooth number transitions",
	"Anchor preset",
	"Horizontal offset",
	"Vertical offset",
	"Minimum width",
	"Height",
	"Expand width for long values",
	"Horizontal padding",
	"Font size",
	"Blizzard font preset",
	"Text shadow",
	"Background color",
	"Background opacity",
	"Border mode",
	"Custom border",
	"Palette",
	"Custom safe",
	"Custom danger",
	"Custom warning",
}
assert(
	#addon.ConfigTest.getControls() == #expectedControlLabels,
	"the control matrix should cover every display setting"
)
for _, label in ipairs(expectedControlLabels) do
	assert(FindControl(label), "the configurator should expose " .. label)
end
local smoothTransitionsControl = FindControl("Smooth number transitions")
assert(
	smoothTransitionsControl.check:GetChecked() == true,
	"the smoothing control should reflect the reset default state"
)
local styleRevisionBeforeBehaviorToggle = addon.styleRevision
local layoutRevisionBeforeBehaviorToggle = addon.layoutRevision
smoothTransitionsControl.check:SetChecked(false)
smoothTransitionsControl.check.scripts.OnClick(smoothTransitionsControl.check)
assert(addon.db.smoothTransitions == false, "the smoothing control should disable transitions")
smoothTransitionsControl.check:SetChecked(true)
smoothTransitionsControl.check.scripts.OnClick(smoothTransitionsControl.check)
assert(addon.db.smoothTransitions == true, "the smoothing control should enable transitions")
assert(
	addon.styleRevision == styleRevisionBeforeBehaviorToggle
		and addon.layoutRevision == layoutRevisionBeforeBehaviorToggle,
	"behavior-only changes should not trigger layout or style revisions"
)
local expandedHeight = sections[1].content:GetHeight()
sections[1].header.scripts.OnClick(sections[1].header)
assert(sections[1].content.shown == false, "section headers should collapse their content")
sections[1].header.scripts.OnClick(sections[1].header)
assert(sections[1].content.shown == true, "section headers should expand existing content")
assert(sections[1].content:GetHeight() == expandedHeight, "expansion should preserve existing rows")
assert(#frames == framesAfterEditor, "collapsing sections should not create frames")

for index, preset in ipairs(addon.ConfigTest.anchorPresets) do
	addon.ConfigTest.useAnchorPreset(index)
	assert(addon.db.anchorPoint == preset.point, "anchor preset should save the badge point")
	assert(
		addon.db.relativePoint == preset.relativePoint,
		"anchor preset should save the health-bar point"
	)
	assert(addon.db.offsetX == preset.offsetX, "anchor preset should save its exact X offset")
	assert(addon.db.offsetY == preset.offsetY, "anchor preset should save its exact Y offset")
end
for index, button in ipairs(sections[2].rows[1].anchorButtons) do
	button.scripts.OnClick(button)
	assert(
		addon.db.anchorPoint == addon.ConfigTest.anchorPresets[index].point,
		"each visible anchor button should retain its own preset"
	)
end
sections[5].rows[1].choiceButtons[2].scripts.OnClick(
	sections[5].rows[1].choiceButtons[2]
)
assert(addon.db.palette == "blue", "choice buttons should retain their own palette values")
sections[5].rows[1].choiceButtons[1].scripts.OnClick(
	sections[5].rows[1].choiceButtons[1]
)
assert(addon.db.palette == "default", "palette choices should switch independently")

local previewBadge = addon.ConfigTest.getPreviewBadge()
local previewHealthBar = addon.ConfigTest.getPreviewHealthBar()
local widthDefinition = addon.settingDefinitions.badgeWidth
local heightDefinition = addon.settingDefinitions.badgeHeight
local minimumWidth, maximumWidth = FindControl("Minimum width").slider:GetMinMaxValues()
assert(
	minimumWidth == widthDefinition.minimum and maximumWidth == widthDefinition.maximum,
	"the width control should derive its range from the settings definition"
)
assert(
	previewBadge.resizeBounds[1] == widthDefinition.minimum
		and previewBadge.resizeBounds[2] == heightDefinition.minimum
		and previewBadge.resizeBounds[3] == widthDefinition.maximum
		and previewBadge.resizeBounds[4] == heightDefinition.maximum,
	"preview resize bounds should derive from the settings definitions"
)
previewBadge.centerX = previewHealthBar:GetRight() + previewBadge:GetWidth() / 2 + 11
previewBadge.centerY = 3
previewHealthBar.centerX = 0
previewHealthBar.centerY = 0
addon.ConfigTest.commitDraggedPosition()
assert(addon.db.anchorPoint == "LEFT", "badge dragging should resolve to the nearest anchor")
assert(addon.db.relativePoint == "RIGHT", "dragging should resolve against the health-bar anchor")
assert(addon.db.offsetX == 11, "badge dragging should preserve the exact resolved X offset")
assert(addon.db.offsetY == 3, "badge dragging should preserve the exact resolved Y offset")

local horizontalOffset = FindControl("Horizontal offset")
horizontalOffset.edit:SetText("-27")
horizontalOffset.edit.scripts.OnEnterPressed(horizontalOffset.edit)
assert(addon.db.offsetX == -27, "numeric entry should save exact horizontal offsets")
local verticalOffset = FindControl("Vertical offset")
verticalOffset.edit:SetText("19")
verticalOffset.edit.scripts.OnEnterPressed(verticalOffset.edit)
assert(addon.db.offsetY == 19, "numeric entry should save exact vertical offsets")
verticalOffset.edit:SetText("not-a-number")
verticalOffset.edit.scripts.OnEnterPressed(verticalOffset.edit)
assert(addon.db.offsetY == 19, "invalid numeric entry should restore the saved value")

horizontalOffset.edit:SetFocus()
horizontalOffset.edit:SetText("-31")
addon.RefreshConfig()
assert(
	horizontalOffset.edit:GetText() == "-31",
	"the periodic refresh must not overwrite a focused edit box"
)
horizontalOffset.edit.scripts.OnEnterPressed(horizontalOffset.edit)
assert(addon.db.offsetX == -31, "keyboard entry must survive a refresh tick")
horizontalOffset.edit:SetFocus()
horizontalOffset.edit:SetText("abandoned")
horizontalOffset.edit:ClearFocus()
assert(
	horizontalOffset.edit:GetText() == "-31",
	"losing focus must restore an abandoned partial entry"
)

local fontBeforeResize = addon.db.fontSize
previewBadge.resizing = true
previewBadge:SetSize(88, 40)
previewBadge.scripts.OnMouseUp(previewBadge)
assert(addon.db.badgeWidth == 88, "badge dragging should resize width")
assert(addon.db.badgeHeight == 40, "badge dragging should resize height")
assert(addon.db.fontSize == fontBeforeResize, "badge resizing must not change font size")

addon:ResetLayoutSettings()
local widthBeforeGrip = addon.db.badgeWidth
local heightBeforeGrip = addon.db.badgeHeight
assert(
	previewBadge:GetWidth() > widthBeforeGrip,
	"the auto-width preview should be wider than the configured minimum"
)
previewBadge.resizing = true
previewBadge.scripts.OnMouseUp(previewBadge)
assert(
	addon.db.badgeWidth == widthBeforeGrip and addon.db.badgeHeight == heightBeforeGrip,
	"a grip press with no movement must not ratchet the saved minimum size"
)

-- The mock does not resolve anchors into coordinates, so drive both rects directly.
local previewCanvas = addon.ConfigTest.getPreviewCanvas()
previewCanvas.width = 360
previewCanvas.height = 300
previewCanvas.centerX = 0
previewCanvas.centerY = 0
previewBadge.centerX = 0
previewBadge.centerY = 0
addon.RefreshConfig()
assert(previewBadge.mouseEnabled == true, "a badge inside the canvas stays draggable")
previewBadge.centerY = -400
addon.RefreshConfig()
assert(
	previewBadge.mouseEnabled == false,
	"a badge dropped below the canvas must not intercept footer clicks"
)
previewBadge.centerY = 0
addon.RefreshConfig()
assert(previewBadge.mouseEnabled == true, "returning inside the canvas restores dragging")

previewBadge.scripts.OnDragStart(previewBadge)
assert(previewBadge.dragging, "drag start should mark the badge as dragging")
addon.CloseConfig()
assert(previewBadge.dragging == false, "hiding the window must clear an in-flight badge drag")
addon.OpenConfig()

addon.db.palette = "custom"
addon.db.safeColor = { 0.5, 0.5, 0.5 }
addon.ConfigTest.openColorPicker("safeColor", false)
addon:ResetAppearanceSettings()
assert(
	addon.ConfigTest.getPickerOwner() == nil,
	"a bulk reset must end an open color-picker session"
)
AssertNear(addon.db.safeColor[1], 0.35, "reset appearance should install the default safe color")
if ColorPickerFrame.cancelFunc then
	ColorPickerFrame.cancelFunc()
end
AssertNear(
	addon.db.safeColor[1],
	0.35,
	"a stale picker cancel must not resurrect a color the reset replaced"
)

local originalApplyDisplaySettings = addon.ApplyDisplaySettings
local applyCount = 0
addon.ApplyDisplaySettings = function(changeKind)
	applyCount = applyCount + 1
	return originalApplyDisplaySettings(changeKind)
end
addon.ConfigTest.flush()
applyCount = 0
local fontControl = FindControl("Font size")
local queriesBeforeStyling = mock.threatQueryCount
fontControl.slider.scripts.OnValueChanged(fontControl.slider, 15)
fontControl.slider.scripts.OnValueChanged(fontControl.slider, 16)
fontControl.slider.scripts.OnValueChanged(fontControl.slider, 17)
assert(addon.db.fontSize == 17, "continuous slider edits should update the preview immediately")
assert(previewBadge.children[1].fontSize == 17, "mock preview should restyle immediately")
assert(applyCount == 0, "rapid slider edits should wait for the 20 Hz restyle cap")
window.scripts.OnUpdate(window, 0.049)
assert(applyCount == 0, "queued edits should not flush before 0.05 seconds")
window.scripts.OnUpdate(window, 0.002)
assert(applyCount == 1, "queued edits should coalesce into one real-overlay restyle")
fontControl.slider.scripts.OnValueChanged(fontControl.slider, 18)
fontControl.slider.scripts.OnMouseUp(fontControl.slider)
assert(applyCount == 2, "interaction completion should commit the final value immediately")
assert(
	mock.threatQueryCount == queriesBeforeStyling,
	"styling interactions should not increase threat queries while previewing"
)
addon.ApplyDisplaySettings = originalApplyDisplaySettings

addon.db.palette = "blue"
local red, green, blue = addon:GetSemanticColor("safe")
AssertNear(red, 0, "blue palette safe red")
AssertNear(green, 0.447, "blue palette safe green")
AssertNear(blue, 0.698, "blue palette safe blue")
red, green, blue = addon:GetSemanticColor("danger")
AssertNear(red, 0.835, "danger should use the configured semantic color")
AssertNear(green, 0.369, "blue palette danger green")
AssertNear(blue, 0, "blue palette danger blue")

addon.db.palette = "cyan"
red, green, blue = addon:GetSemanticColor("warning")
AssertNear(red, 1, "warning palette red")
AssertNear(green, 0.80, "warning palette green")
AssertNear(blue, 0, "warning palette blue")

addon.db.palette = "custom"
addon.db.safeColor = { 0.11, 0.22, 0.33 }
addon.db.dangerColor = { 0.44, 0.55, 0.66 }
addon.db.warningColor = { 0.77, 0.88, 0.99 }
red, green, blue = addon:GetSemanticColor("safe")
AssertNear(red, 0.11, "custom safe red")
AssertNear(green, 0.22, "custom safe green")
AssertNear(blue, 0.33, "custom safe blue")

local colorBadge = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
local colorText = colorBadge:CreateFontString(nil, "OVERLAY")
addon.db.borderMode = "custom"
addon.db.borderColor = { 0.2, 0.3, 0.4, 0.5 }
addon:ApplyThreatColor(colorBadge, colorText, "safe")
AssertNear(colorBadge.borderColor[1], 0.2, "custom border red")
AssertNear(colorBadge.borderColor[4], 0.5, "custom border opacity")
addon.db.borderMode = "off"
addon:ApplyThreatColor(colorBadge, colorText, "safe")
AssertNear(colorBadge.borderColor[4], 0, "disabled borders should be transparent")
addon.db.borderMode = "semantic"
addon:ApplyThreatColor(colorBadge, colorText, "safe")
AssertNear(colorBadge.borderColor[1], 0.11, "semantic borders should follow text color")

local styledOverlay = disabledPlate.ThreatPlatingOverlay
local anchorChangesBeforeStyle = styledOverlay.clearAllPointsCount
local queriesBeforeDirectStyle = mock.threatQueryCount
addon.db.fontPreset = "combat"
addon.db.fontSize = 9
addon.db.backgroundColor = { 0.12, 0.23, 0.34, 0.45 }
addon.ApplyDisplaySettings("style")
assert(styledOverlay.text.fontObject == "NumberFontNormal", "font presets should use Blizzard objects")
assert(styledOverlay.text.fontSize == 9, "font size should style independently")
AssertNear(styledOverlay.backgroundColor[4], 0.45, "background opacity should apply")
assert(
	styledOverlay.clearAllPointsCount == anchorChangesBeforeStyle,
	"style-only changes should not re-anchor pooled overlays"
)
assert(
	mock.threatQueryCount == queriesBeforeDirectStyle,
	"direct restyling should not query threat"
)

addon.db.badgeHeight = 50
addon.db.badgeWidth = 44
addon.db.padding = 20
addon.db.autoWidth = true
addon.ApplyDisplaySettings("layout")
assert(styledOverlay:GetHeight() == 50, "badge height should apply independently")
assert(styledOverlay.text.fontSize == 9, "layout changes should not alter font size")
assert(styledOverlay:GetWidth() == 82, "automatic width should use configurable padding")
assert(disabledPlate:GetWidth() == 0, "styling must not resize Blizzard nameplates")
assert(disabledPlate.parent == nil, "styling must not reparent Blizzard nameplates")
assert(not disabledPlate.mouseEnabled, "configuring must not make Blizzard nameplates interactive")
assert(not disabledPlate.movable, "configuring must not make Blizzard nameplates movable")

local pickerOriginal = addon.CopyValue(addon.db.safeColor)
addon.ConfigTest.openColorPicker("safeColor", false)
assert(addon.ConfigTest.getPickerOwner(), "opening a color should record picker ownership")
assert(ColorPickerFrame:IsShown(), "the shared color picker should open")
ColorPickerFrame:SetColorRGB(0.91, 0.81, 0.71)
ColorPickerFrame.swatchFunc()
addon.ConfigTest.flush()
AssertNear(addon.db.safeColor[1], 0.91, "color picker changes should preview live")
ColorPickerFrame.cancelFunc()
AssertNear(addon.db.safeColor[1], pickerOriginal[1], "picker cancellation should restore red")
AssertNear(addon.db.safeColor[2], pickerOriginal[2], "picker cancellation should restore green")
AssertNear(addon.db.safeColor[3], pickerOriginal[3], "picker cancellation should restore blue")

local resetApplyKinds = {}
local applyBeforeResetTests = addon.ApplyDisplaySettings
addon.ApplyDisplaySettings = function(changeKind)
	resetApplyKinds[#resetApplyKinds + 1] = changeKind
	return applyBeforeResetTests(changeKind)
end

addon.db.offsetX = 120
addon.db.palette = "custom"
addon:ResetLayoutSettings()
assert(addon.db.offsetX == 6, "Reset Layout should restore placement")
assert(addon.db.palette == "custom", "Reset Layout should preserve appearance")
assert(
	#resetApplyKinds == 1 and resetApplyKinds[1] == "layout",
	"Reset Layout should perform one layout application"
)
resetApplyKinds = {}
addon.db.offsetX = 77
addon.db.smoothTransitions = false
addon:ResetAppearanceSettings()
assert(addon.db.fontSize == 14, "Reset Appearance should restore typography")
assert(addon.db.palette == "default", "Reset Appearance should restore the default palette")
assert(addon.db.offsetX == 77, "Reset Appearance should preserve layout")
assert(
	addon.db.smoothTransitions == false,
	"Reset Appearance should preserve general behavior settings"
)
assert(
	#resetApplyKinds == 1 and resetApplyKinds[1] == "style",
	"Reset Appearance should perform one style application"
)
resetApplyKinds = {}
addon:SetEnabled(false)
addon:ResetAllSettings()
assert(addon.enabled, "Reset All should restore enabled state")
assert(addon.db.offsetX == 6, "Reset All should restore layout")
assert(addon.db.fontSize == 14, "Reset All should restore appearance")
assert(addon.db.smoothTransitions, "Reset All should restore behavior settings")
assert(
	#resetApplyKinds == 1 and resetApplyKinds[1] == "all",
	"Reset All should perform one all-settings application"
)

resetApplyKinds = {}
addon.db.offsetX = 133
addon.db.safeColor[1] = 0.01
addon.db.smoothTransitions = false
addon:SetEnabled(false)
addon.ConfigTest.restoreSession()
assert(addon.db.offsetX == 6, "Revert should restore the editor-open layout snapshot")
assert(addon.db.safeColor[1] == 0.35, "Revert should restore an independent color snapshot")
assert(addon.db.smoothTransitions, "Revert should restore the editor-open behavior snapshot")
assert(addon.enabled, "Revert should restore the editor-open enabled state")
assert(window:GetWidth() == 900, "Revert should not resize the configurator")
assert(window:GetHeight() == 700, "Revert should not move configurator geometry")
assert(
	#resetApplyKinds == 1 and resetApplyKinds[1] == "all",
	"Revert should perform one all-settings application"
)
addon.ApplyDisplaySettings = applyBeforeResetTests

addon.ConfigTest.openColorPicker("backgroundColor", true)
local externalPickerOwner = {}
ColorPickerFrame:SetupColorPickerAndShow({
	b = 0.3,
	cancelFunc = function()
	end,
	extraInfo = externalPickerOwner,
	g = 0.2,
	hasOpacity = false,
	opacity = 1,
	opacityFunc = function()
	end,
	r = 0.1,
	swatchFunc = function()
	end,
})
addon.ConfigTest.endColorPicker()
assert(
	ColorPickerFrame:IsShown() and ColorPickerFrame:GetExtraInfo() == externalPickerOwner,
	"picker cleanup must not close another owner’s newer session"
)
ColorPickerFrame:Hide()
addon.ConfigTest.openColorPicker("backgroundColor", true)
local titleClose = FindFrame(function(frame)
	return frame.parent == window and frame.template == "UIPanelCloseButtonNoScripts"
end)
assert(titleClose, "title close button should exist")
addon.db.offsetX = 21
titleClose.scripts.OnClick(titleClose)
assert(not addon.configPreviewActive, "title X should clear preview mode")
assert(addon.db.offsetX == 21, "title X should keep live changes")
assert(not ColorPickerFrame:IsShown(), "closing should end Threat Plating's picker session")
assert(not addon.ConfigTest.getPickerOwner(), "closing should clear picker ownership")

local doneButton = FindFrame(function(frame)
	return frame.parent == window and frame.text == "Done"
end)
assert(doneButton, "footer Done button should exist")
local closeCases = {
	{
		label = "footer Done",
		offsetX = 22,
		close = function()
			doneButton.scripts.OnClick(doneButton)
		end,
	},
	{
		label = "Escape",
		offsetX = 23,
		close = function()
			window:Hide()
		end,
	},
	{
		label = "slash close",
		offsetX = 24,
		close = function()
			SlashCmdList.THREATPLATING("close")
		end,
	},
	{
		label = "slash toggle",
		offsetX = 25,
		close = function()
			SlashCmdList.THREATPLATING("")
		end,
	},
}

for _, closeCase in ipairs(closeCases) do
	addon.OpenConfig()
	addon.db.offsetX = closeCase.offsetX
	closeCase.close()
	assert(
		not addon.configPreviewActive,
		closeCase.label .. " should clear preview mode"
	)
	assert(
		addon.db.offsetX == closeCase.offsetX,
		closeCase.label .. " should keep live changes"
	)
end

SlashCmdList.THREATPLATING("")
assert(addon.configPreviewActive, "an empty slash command should open the configurator")
SlashCmdList.THREATPLATING("stauts")
assert(addon.configPreviewActive, "an unknown subcommand must not close the editor")
SlashCmdList.THREATPLATING("close")
assert(not addon.configPreviewActive, "slash close should close the editor")
SlashCmdList.THREATPLATING("stauts")
assert(not addon.configPreviewActive, "an unknown subcommand must not open the editor either")
SlashCmdList.THREATPLATING("   ON   ")
assert(addon.enabled, "the slash parser should tolerate padding and mixed case")
SlashCmdList.THREATPLATING("close")
ThreatPlating_OnAddonCompartmentClick()
assert(addon.configPreviewActive, "the AddOn Compartment should open the configurator")
ThreatPlating_OnAddonCompartmentClick()
assert(not addon.configPreviewActive, "the AddOn Compartment should toggle the configurator closed")

local settingsCheck = FindFrame(function(frame)
	return frame.frameType == "CheckButton"
		and frame.template == "UICheckButtonTemplate"
		and FindChildText(frame, "Enable threat counters")
end)
assert(settingsCheck, "Options should provide a synchronized enable control")
addon:SetEnabled(false)
assert(settingsCheck:GetChecked() == false, "Options enable state should synchronize when disabled")
addon:SetEnabled(true)
assert(settingsCheck:GetChecked() == true, "Options enable state should synchronize when enabled")

local settingsOpenButton = FindFrame(function(frame)
	return frame.text == "Open Editor"
end)
assert(settingsOpenButton, "Options should provide an editor button")
settingsOpenButton.scripts.OnClick(settingsOpenButton)
assert(addon.configPreviewActive, "the Options editor button should open the configurator")
addon.CloseConfig()

-- The mock must reproduce the client's template rules, or a forgotten template argument
-- ships as a live Lua error that every local suite happily passes over.
local plainFrame = CreateFrame("Frame")
local backdropOK = pcall(function()
	plainFrame:SetBackdrop({})
end)
assert(not backdropOK, "SetBackdrop without BackdropTemplate must error in the mock")
local backdropFrame = CreateFrame("Frame", nil, nil, "BackdropTemplate")
assert(
	pcall(function()
		backdropFrame:SetBackdrop({})
	end),
	"SetBackdrop with BackdropTemplate must work"
)
assert(
	not pcall(CreateFrame, "Frame", nil, nil, "BackdorpTemplate"),
	"a misspelled template must be rejected by the mock"
)
assert(
	pcall(CreateFrame, "Button", nil, nil, "BackdropTemplate, UIPanelButtonTemplate"),
	"a comma-separated template list must be accepted"
)

local probeLines = addon.DescribeClientAPIs()
assert(type(probeLines) == "table" and #probeLines > 0, "the client probe should return lines")
local probeText = table.concat(probeLines, "\n")
for _, expected in ipairs({
	"GetBuildInfo",
	"GetShapeshiftFormInfo",
	"GetTalentTabInfo",
	"IsPlayerEffectivelyTank",
	"nameplate token",
}) do
	assert(probeText:find(expected, 1, true), "the probe should report " .. expected)
end
assert(
	probeText:find("expected: 1=texture, 2=isActive, 3=isCastable, 4=spellID", 1, true),
	"the probe should state the shapeshift slot layout it assumes"
)
mock.activeFormSpellID = 5487
probeText = table.concat(addon.DescribeClientAPIs(), "\n")
assert(
	probeText:find("addon reads activeFormSpellID = 5487", 1, true),
	"the probe should report the addon's reading next to the raw tuple"
)
mock.activeFormSpellID = nil

local realShapeshiftInfo = GetShapeshiftFormInfo
GetShapeshiftFormInfo = function()
	error("restricted")
end
mock.activeFormSpellID = 5487
probeText = table.concat(addon.DescribeClientAPIs(), "\n")
assert(probeText:find("error:", 1, true), "the probe should survive and report a throwing API")
GetShapeshiftFormInfo = realShapeshiftInfo
mock.activeFormSpellID = nil

SlashCmdList.THREATPLATING("probe")

-- Interaction fuzz.
--
-- Four of the bugs this suite now covers were interleaving defects: refresh-during-
-- typing, resize-during-refresh, reset-during-picker, and hide-during-drag. Each
-- mechanism was already tested in isolation and none of the pairs were. This drives the
-- editor with a deterministic pseudo-random interleaving and asserts, after every single
-- step, that the database still holds only values startup validation would accept
-- unchanged -- i.e. that no interaction can persist a setting that comes back different
-- after a reload.
local fuzzState = 12345
local function NextRandom()
	-- Small constants so every product stays exactly representable in a double, which
	-- keeps the sequence identical on every Lua 5.1 build.
	fuzzState = (fuzzState * 75 + 74) % 65537
	return fuzzState
end

local function NextIndex(limit)
	return NextRandom() % limit + 1
end

local function NextNumber(minimum, maximum)
	return minimum + (maximum - minimum) * (NextRandom() % 1001) / 1000
end

local fuzzSliders = {}
local fuzzChecks = {}
for _, control in ipairs(addon.ConfigTest.getControls()) do
	if control.slider and control.edit then
		fuzzSliders[#fuzzSliders + 1] = control
	elseif control.check then
		fuzzChecks[#fuzzChecks + 1] = control
	end
end
assert(#fuzzSliders > 0 and #fuzzChecks > 0, "the fuzz pass needs sliders and checkboxes")

local fuzzColorKeys = {
	{ key = "backgroundColor", hasAlpha = true },
	{ key = "borderColor", hasAlpha = true },
	{ key = "safeColor", hasAlpha = false },
	{ key = "dangerColor", hasAlpha = false },
	{ key = "warningColor", hasAlpha = false },
}
local fuzzStates = { "safe", "danger", "warning" }

local function AssertPersistable(context)
	for key, definition in pairs(addon.settingDefinitions) do
		local value = addon.db[key]
		if definition.valueType == "boolean" then
			assert(type(value) == "boolean", context .. ": " .. key .. " must stay a boolean")
		elseif definition.valueType == "number" then
			assert(
				type(value) == "number" and value == addon.NormalizeSettingValue(key, value),
				context .. ": " .. key .. " = " .. tostring(value)
					.. " would be rewritten by startup validation"
			)
		elseif definition.valueType == "enum" then
			assert(
				definition.values[value],
				context .. ": " .. key .. " = " .. tostring(value) .. " is not a valid choice"
			)
		elseif definition.valueType == "color" then
			assert(type(value) == "table", context .. ": " .. key .. " must stay a table")
			for index = 1, definition.components do
				local component = value[index]
				assert(
					type(component) == "number"
						and component == component
						and component >= 0
						and component <= 1,
					context .. ": " .. key .. "[" .. index .. "] = " .. tostring(component)
				)
			end
		end
	end

	assert(type(addon.db.collapsedSections) == "table", context .. ": collapsedSections must stay a table")
	assert(
		previewBadge.dragging == nil or type(previewBadge.dragging) == "boolean",
		context .. ": dragging must stay a boolean"
	)
	assert(
		previewBadge.resizing == nil or type(previewBadge.resizing) == "boolean",
		context .. ": resizing must stay a boolean"
	)

	local owner = addon.ConfigTest.getPickerOwner()
	if owner ~= nil then
		assert(
			ColorPickerFrame:GetExtraInfo() == owner,
			context .. ": an owned picker session must still own ColorPickerFrame"
		)
	end

	-- A hidden editor runs no mouse scripts, so any interaction flag left set here can
	-- never be cleared again.
	if not window:IsShown() then
		assert(
			previewBadge.dragging ~= true,
			context .. ": a hidden editor must not hold an in-flight drag"
		)
		assert(
			previewBadge.resizing ~= true,
			context .. ": a hidden editor must not hold an in-flight resize"
		)
	end
end

local fuzzActions = {
	{
		label = "tick",
		run = function()
			window.scripts.OnUpdate(window, 0.1)
		end,
	},
	{
		label = "tick-past-refresh",
		run = function()
			window.scripts.OnUpdate(window, 0.6)
		end,
	},
	{
		label = "slider-drag",
		needsVisibleEditor = true,
		run = function()
			local control = fuzzSliders[NextIndex(#fuzzSliders)]
			local minimum, maximum = control.slider:GetMinMaxValues()
			control.slider.scripts.OnValueChanged(control.slider, NextNumber(minimum, maximum))
		end,
	},
	{
		label = "slider-release",
		needsVisibleEditor = true,
		run = function()
			local control = fuzzSliders[NextIndex(#fuzzSliders)]
			control.slider.scripts.OnMouseUp(control.slider)
		end,
	},
	{
		label = "edit-focus-type",
		needsVisibleEditor = true,
		run = function()
			local control = fuzzSliders[NextIndex(#fuzzSliders)]
			control.edit:SetFocus()
			if NextRandom() % 4 == 0 then
				control.edit:SetText("not-a-number")
			else
				local minimum, maximum = control.slider:GetMinMaxValues()
				control.edit:SetText(tostring(NextNumber(minimum - 20, maximum + 20)))
			end
		end,
	},
	{
		label = "edit-commit",
		needsVisibleEditor = true,
		run = function()
			local control = fuzzSliders[NextIndex(#fuzzSliders)]
			control.edit.scripts.OnEnterPressed(control.edit)
		end,
	},
	{
		label = "edit-abandon",
		needsVisibleEditor = true,
		run = function()
			local control = fuzzSliders[NextIndex(#fuzzSliders)]
			control.edit:ClearFocus()
		end,
	},
	{
		label = "check-toggle",
		needsVisibleEditor = true,
		run = function()
			local control = fuzzChecks[NextIndex(#fuzzChecks)]
			control.frame.scripts.OnClick(control.frame)
		end,
	},
	{
		label = "drag-start",
		needsVisibleEditor = true,
		run = function()
			previewBadge.scripts.OnDragStart(previewBadge)
		end,
	},
	{
		label = "drag-stop",
		needsVisibleEditor = true,
		run = function()
			previewBadge.centerX = NextNumber(-400, 400)
			previewBadge.centerY = NextNumber(-400, 400)
			previewBadge.scripts.OnDragStop(previewBadge)
		end,
	},
	{
		label = "grip-press",
		needsVisibleEditor = true,
		run = function()
			previewBadge.resizing = true
		end,
	},
	{
		label = "grip-size",
		needsVisibleEditor = true,
		run = function()
			previewBadge:SetSize(NextNumber(10, 220), NextNumber(4, 90))
		end,
	},
	{
		label = "grip-release",
		needsVisibleEditor = true,
		run = function()
			previewBadge.scripts.OnMouseUp(previewBadge)
		end,
	},
	{
		label = "picker-open",
		run = function()
			local choice = fuzzColorKeys[NextIndex(#fuzzColorKeys)]
			addon.ConfigTest.openColorPicker(choice.key, choice.hasAlpha)
		end,
	},
	{
		label = "picker-move",
		run = function()
			local pickedRed = NextNumber(0, 1)
			local pickedGreen = NextNumber(0, 1)
			local pickedBlue = NextNumber(0, 1)
			ColorPickerFrame:SetColorRGB(pickedRed, pickedGreen, pickedBlue)
			ColorPickerFrame.opacity = NextNumber(0, 1)
			if ColorPickerFrame.swatchFunc then
				ColorPickerFrame.swatchFunc()
			end

			-- The oracle for the whole reset-during-picker class: a live wheel edit must
			-- land in the table the database currently holds, not in one a reset or
			-- revert replaced underneath the session.
			local owner = addon.ConfigTest.getPickerOwner()
			if owner and ColorPickerFrame:IsShown() then
				local stored = addon.db[owner.key]
				assert(
					type(stored) == "table"
						and math.abs(stored[1] - pickedRed) < 0.0001
						and math.abs(stored[2] - pickedGreen) < 0.0001
						and math.abs(stored[3] - pickedBlue) < 0.0001,
					"a live picker edit must reach the current database table for " .. owner.key
				)
			end
		end,
	},
	{
		label = "picker-cancel",
		run = function()
			if ColorPickerFrame.cancelFunc then
				ColorPickerFrame.cancelFunc()
			end
		end,
	},
	{
		label = "picker-end",
		run = function()
			addon.ConfigTest.endColorPicker()
		end,
	},
	{
		label = "reset-layout",
		needsVisibleEditor = true,
		run = function()
			addon:ResetLayoutSettings()
		end,
	},
	{
		label = "reset-appearance",
		needsVisibleEditor = true,
		run = function()
			addon:ResetAppearanceSettings()
		end,
	},
	{
		label = "reset-all",
		run = function()
			addon:ResetAllSettings()
		end,
	},
	{
		label = "revert",
		needsVisibleEditor = true,
		run = function()
			addon.ConfigTest.restoreSession()
		end,
	},
	{
		label = "anchor-preset",
		needsVisibleEditor = true,
		run = function()
			addon.ConfigTest.useAnchorPreset(NextIndex(#addon.ConfigTest.anchorPresets))
		end,
	},
	{
		label = "scenario",
		needsVisibleEditor = true,
		run = function()
			addon.ConfigTest.setScenario(NextRandom() % 2 == 0, fuzzStates[NextIndex(#fuzzStates)])
		end,
	},
	{
		label = "reflow",
		needsVisibleEditor = true,
		run = function()
			addon.ConfigTest.reflow()
		end,
	},
	{
		label = "window-hide",
		run = function()
			window:Hide()
		end,
	},
	{
		label = "window-show",
		run = function()
			addon.OpenConfig()
		end,
	},
}

addon.OpenConfig()
AssertPersistable("fuzz start")
local fuzzCoverage = {}
for step = 1, 600 do
	local action = fuzzActions[NextIndex(#fuzzActions)]
	-- WoW delivers no mouse or keyboard scripts to a hidden frame, so firing a control's
	-- handler while the editor is closed would test a state the client cannot produce.
	if not (action.needsVisibleEditor and not window:IsShown()) then
		local context = string.format("fuzz step %d (%s)", step, action.label)
		local ok, err = pcall(action.run)
		assert(ok, context .. " errored: " .. tostring(err))
		AssertPersistable(context)
		fuzzCoverage[action.label] = (fuzzCoverage[action.label] or 0) + 1
	end
end

-- A fuzz pass that quietly stops exercising a mechanism is worse than none at all.
for _, action in ipairs(fuzzActions) do
	assert(
		(fuzzCoverage[action.label] or 0) > 0,
		"the fuzz pass never ran the " .. action.label .. " action"
	)
end

addon.CloseConfig()
addon:ResetAllSettings()
AssertPersistable("after fuzz reset")

-- Keep transition timing isolated at the end of the fixture so it cannot change the
-- scheduler phase assumed by threat-lifecycle assertions above.
threat["player:nameplate1"] = { true, 3, 100, 100, 100000 }
threat["pet:nameplate1"] = { false, 1, 80, 80, 80000 }
addon:ScanVisibleNameplates()
addon.UpdateAllNameplates()
Update(0.10)
assert(
	disabledPlate.ThreatPlatingOverlay.text.text == "+200",
	"the transition fixture should begin from a settled live value"
)

threat["player:nameplate1"] = { false, 1, 336.5, 437.5, 350000 }
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate1")
Update(0.05)
local firstTransitionText = disabledPlate.ThreatPlatingOverlay.text.text
assert(
	firstTransitionText ~= "+200" and firstTransitionText ~= "+2.7k",
	"same-sign live values should begin between the old and new counters"
)
AssertColor(
	disabledPlate.ThreatPlatingOverlay.text,
	1,
	0.32,
	0.26,
	"safety color changes should apply immediately while the number is moving"
)
local transitionQueryCount = mock.threatQueryCount
addon.NameplateView.AdvanceValueTransitions(0.04)
assert(
	mock.threatQueryCount == transitionQueryCount,
	"advancing a number transition must not query threat"
)
assert(
	disabledPlate.ThreatPlatingOverlay.text.text ~= firstTransitionText,
	"the shared transition clock should advance an active number"
)

disabledPlate:Hide()
addon.NameplateView.AdvanceValueTransitions(0.09)
assert(
	not disabledPlate.ThreatPlatingOverlay.shown,
	"hiding a plate should cancel its active number transition"
)
disabledPlate:Show()
addon.UpdateAllNameplates()
Update(0)
assert(
	disabledPlate.ThreatPlatingOverlay.text.text == "+2.7k",
	"a newly shown badge should snap to the exact formatted target"
)

threat["player:nameplate1"] = { false, 1, 62.5, 62.5, 50000 }
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate1")
Update(0.05)
assert(
	disabledPlate.ThreatPlatingOverlay.text.text == "-300",
	"leader-sign changes should render immediately instead of tweening through zero"
)

threat["player:nameplate1"] = { false, 1, 12.5, 12.5, 10000 }
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate1")
Update(0.05)
assert(
	disabledPlate.ThreatPlatingOverlay.text.text ~= "-700",
	"same-sign deficits should also use the number transition"
)
addon.db.smoothTransitions = false
addon.ApplyDisplaySettings("behavior")
assert(
	disabledPlate.ThreatPlatingOverlay.text.text == "-700",
	"turning smoothing off should settle an active transition immediately"
)
AssertPersistable("after transition tests")

-- A taunt or rip can flip isTanking one threat push before the percentage pair
-- refreshes. The stale sub-100 percentage must not manufacture a phantom deficit;
-- the badge should read the lead over the exact observable contender instead.
threat["player:nameplate1"] = { true, 3, 25, 25, 350000 }
Dispatch("UNIT_THREAT_SITUATION_UPDATE", "nameplate1")
Update(0.05)
assert(
	disabledPlate.ThreatPlatingOverlay.text.text == "+2.7k",
	"a stale sub-100 tanking percentage must not manufacture a phantom deficit"
)
AssertPersistable("after aggro-flip staleness test")

print("Nameplate runtime: smoke test passed")
