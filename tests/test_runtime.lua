local Frame = {}
Frame.__index = Frame

function Frame:ClearAllPoints()
	self.points = {}
	self.clearAllPointsCount = (self.clearAllPointsCount or 0) + 1
end

function Frame:ClearFocus()
	self.hasFocus = false
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

function Frame:EnableMouseWheel()
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

function Frame:UnregisterEvent(event)
	self.events[event] = nil
end

function Frame:RegisterForDrag()
end

function Frame:LockHighlight()
	self.highlighted = true
end

function Frame:SetAllPoints(frame)
	self.allPoints = frame or self.parent
end

function Frame:SetBackdrop()
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

function Frame:SetClampedToScreen()
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

function Frame:SetFrameStrata()
end

function Frame:SetFrameLevel(level)
	self.frameLevel = level
end

function Frame:SetPoint(...)
	self.points[#self.points + 1] = { ... }
end

function Frame:SetJustifyH()
end

function Frame:SetAutoFocus()
end

function Frame:SetMaxLetters()
end

function Frame:SetMinMaxValues(minimum, maximum)
	self.minimum = minimum
	self.maximum = maximum
end

function Frame:SetMovable()
	self.movable = true
end

function Frame:SetNumeric()
end

function Frame:SetObeyStepOnDrag()
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

function Frame:SetShadowColor()
end

function Frame:SetShadowOffset()
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

function Frame:SetVertexColor()
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

function Frame:StartMoving()
end

function Frame:StartSizing()
end

function Frame:StopMovingOrSizing()
end

function Frame:UnlockHighlight()
	self.highlighted = false
end

local mock = assert(loadfile("tests/wow_mock.lua"))()(Frame)
local frames = mock.frames
local plates = mock.plates
local units = mock.units
local threat = mock.threat

ThreatPlatingDB = {}
local addon = {}
assert(loadfile("Init.lua"))("ThreatPlating", addon)
assert(loadfile("Threat.lua"))("ThreatPlating", addon)
assert(loadfile("Display.lua"))("ThreatPlating", addon)
assert(loadfile("Nameplates.lua"))("ThreatPlating", addon)
addon.testHarness = true
assert(loadfile("Config.lua"))("ThreatPlating", addon)

assert(addon.version == "0.6.1", "runtime version should match the release")

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
	plate.namePlateUnitToken = unit
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
Update(0.20)

assert(plate.ThreatPlatingOverlay.shown, "leader overlay should be shown")
assert(plate.ThreatPlatingOverlay.text.text == "+200", "leader overlay should show +200")
assert(addon.playerIsTank, "Protection talents should select tank colors")
AssertColor(plate.ThreatPlatingOverlay.text, 0.35, 1, 0.35, "tank leader should be green")

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

threat["player:nameplate1"] = { true, 3, 50, 50, 50000 }
Dispatch("UNIT_THREAT_SITUATION_UPDATE", "nameplate1")
Update(0.05)
assert(
	plate.ThreatPlatingOverlay.text.text == "-500",
	"tanking state must not override a higher inferred raw threat"
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
	mock.nameplateScanCount == scansBeforeContinuousEvents + 1,
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
recycledPlate.namePlateUnitToken = "nameplate2"
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
mock.targetPlateUnit = nil
Dispatch("NAME_PLATE_UNIT_REMOVED", "nameplate3")
plates.nameplate3 = nil
units.nameplate3 = nil
window.scripts.OnUpdate(window, 0.50)
assert(
	addon.ConfigTest.getPreviewUnitName():GetText() == disabledPlate.baselineName,
	"the preview should return to another current plate after target removal"
)

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

local fontBeforeResize = addon.db.fontSize
previewBadge.resizing = true
previewBadge:SetSize(88, 40)
previewBadge.scripts.OnMouseUp(previewBadge)
assert(addon.db.badgeWidth == 88, "badge dragging should resize width")
assert(addon.db.badgeHeight == 40, "badge dragging should resize height")
assert(addon.db.fontSize == fontBeforeResize, "badge resizing must not change font size")

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
addon:ResetAppearanceSettings()
assert(addon.db.fontSize == 14, "Reset Appearance should restore typography")
assert(addon.db.palette == "default", "Reset Appearance should restore the default palette")
assert(addon.db.offsetX == 77, "Reset Appearance should preserve layout")
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
assert(
	#resetApplyKinds == 1 and resetApplyKinds[1] == "all",
	"Reset All should perform one all-settings application"
)

resetApplyKinds = {}
addon.db.offsetX = 133
addon:SetEnabled(false)
addon.ConfigTest.restoreSession()
assert(addon.db.offsetX == 6, "Revert should restore the editor-open layout snapshot")
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

print("Nameplate runtime: smoke test passed")
