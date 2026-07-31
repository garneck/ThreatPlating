local Frame = {}
Frame.__index = Frame

function Frame:ClearAllPoints()
	self.points = {}
end

function Frame:CreateFontString()
	local text = setmetatable({
		parent = self,
		points = {},
		shown = true,
		text = "",
	}, Frame)
	self.children[#self.children + 1] = text
	return text
end

function Frame:EnableMouse(enabled)
	self.mouseEnabled = enabled ~= false
end

function Frame:GetFrameLevel()
	return self.frameLevel or 1
end

function Frame:GetHeight()
	return self.height or 0
end

function Frame:GetStringWidth()
	return #self.text * 7
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

function Frame:SetBackdrop()
	self.backdropSet = true
end

function Frame:SetBackdropBorderColor(...)
	self.borderColor = { ... }
end

function Frame:SetBackdropColor(...)
	self.backgroundColor = { ... }
end

function Frame:SetFontObject(fontObject)
	self.fontObject = fontObject
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

function Frame:SetScript(scriptName, callback)
	self.scripts[scriptName] = callback
end

function Frame:SetShadowColor()
	self.shadowColorSet = true
end

function Frame:SetShadowOffset()
	self.shadowOffsetSet = true
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

function Frame:SetWidth(width)
	self.width = width
end

function Frame:Show()
	self.shown = true
end

function Frame:UnregisterEvent(event)
	self.events[event] = nil
end

local mock = assert(loadfile("tests/wow_mock.lua"))()(Frame)
mock:SetRaid(25)
mock.playerClass = "WARRIOR"
mock.talentPoints = { 0, 0, 41 }

local function NewPlate(unit)
	local plate = CreateFrame("Frame")
	local healthBarsContainer = CreateFrame("Frame", nil, plate)
	healthBarsContainer:SetSize(128, 20)
	plate.UnitFrame = {
		HealthBarsContainer = healthBarsContainer,
		unit = unit,
	}
	plate.namePlateUnitToken = unit
	mock.plates[unit] = plate
	return plate
end

local scenarios = {}
local restricted = {}
local malformed = {}

for index = 1, 40 do
	local unit = "nameplate" .. index
	local targetUnit = unit .. "target"
	mock.units[unit] = true
	mock.units[targetUnit] = true
	mock.attackable[unit] = true
	mock.playerUnits[unit] = false
	mock.controlledUnits[unit] = false
	mock.plateOrder[index] = unit
	mock.unitIdentity[targetUnit] = "raid-member-2"
	scenarios[unit] = {
		actors = {
			["raid-member-2"] = 80000,
		},
		player = { true, 3, 100, 100, 100000 },
	}
	NewPlate(unit)
end

scenarios.nameplate1 = {
	actors = {
		["raid-member-2"] = 100000,
		["raid-member-3"] = 120000,
	},
	player = { false, 1, 50, 50, 50000 },
}
scenarios.nameplate2 = {
	actors = {
		["raid-member-2"] = 100000,
		["raid-member-3"] = 120000,
	},
	player = { true, 3, 50, 50, 50000 },
}
scenarios.nameplate3 = {
	actors = {
		["raid-member-2"] = 100000,
	},
	player = { false, 1, 50, 50, 50000 },
}
scenarios.nameplate4.player = { true, 3, 100, 100, 100000 }
scenarios.nameplate5 = {
	actors = {
		["raid-member-2"] = 100000,
		["raid-member-3"] = 120000,
	},
	player = { false, 1, 95, 105, 105000 },
}
scenarios.nameplate6.player = { false, 1, 80, 80, 80000 }

mock.unitIdentity.nameplate40target = "outsider-40"
scenarios.nameplate40.actors = {
	["outsider-40"] = 110000,
}

mock.threatHandler = function(source, enemy)
	local restrictionKey = source .. ":" .. enemy
	if restricted[restrictionKey] then
		return "error"
	end
	if malformed[restrictionKey] then
		return { false, 1, 50 }
	end

	local scenario = scenarios[enemy]
	if not scenario then
		return nil
	end
	if source == "player" then
		return scenario.player
	end

	local identity = mock.unitIdentity[source] or source
	local rawThreat = scenario.actors[identity]
	if rawThreat == "nil" then
		return { false, 0, 0, 0, nil }
	end
	if rawThreat == nil then
		return nil
	end
	return { false, 1, 50, 50, rawThreat }
end

ThreatPlatingDB = {}
local addon = {
	testHarness = true,
}
assert(loadfile("Init.lua"))("ThreatPlating", addon)
assert(loadfile("Threat.lua"))("ThreatPlating", addon)
assert(loadfile("Display.lua"))("ThreatPlating", addon)
assert(loadfile("Nameplates.lua"))("ThreatPlating", addon)

local eventFrame
for _, frame in ipairs(mock.frames) do
	if frame.events.NAME_PLATE_UNIT_ADDED then
		eventFrame = frame
	end
end
assert(eventFrame, "nameplate event frame should exist")
assert(addon.NameplatesTest, "raid fixture should expose scheduler state")

local function Dispatch(event, unit)
	assert(eventFrame.events[event], "event is not registered: " .. event)
	eventFrame.scripts.OnEvent(eventFrame, event, unit)
end

local function Update(elapsed)
	mock.now = mock.now + elapsed
	mock:BeginFrame()
	eventFrame.scripts.OnUpdate(eventFrame, elapsed)
end

local function RunFrames(count, firstElapsed)
	for index = 1, count do
		Update(index == 1 and (firstElapsed or 0) or 0)
	end
end

local function DrainScheduler()
	RunFrames(8, 0)
	local urgentLength, pollLength = addon.NameplatesTest.getQueueLengths()
	assert(urgentLength == 0 and pollLength == 0, "scheduler queues should drain completely")
end

local function AssertColor(unit, red, green, blue, label)
	local color = mock.plates[unit].ThreatPlatingOverlay.text.textColor
	assert(
		color and color[1] == red and color[2] == green and color[3] == blue,
		label
	)
end

local function AssertText(unit, expected, label)
	local overlay = mock.plates[unit].ThreatPlatingOverlay
	assert(overlay.shown and overlay.text.text == expected, label)
end

local function CountQueriesByEnemy(firstLogIndex)
	local counts = {}
	for index = firstLogIndex, #mock.threatQueryLog do
		local enemy = mock.threatQueryLog[index].enemy
		counts[enemy] = (counts[enemy] or 0) + 1
	end
	return counts
end

local initialFrameCount = #mock.frames
for index = 1, 40 do
	Dispatch("NAME_PLATE_UNIT_ADDED", "nameplate" .. index)
end

local initialLogIndex = #mock.threatQueryLog + 1
RunFrames(8, 0.05)
assert(addon.NameplatesTest.getActiveCount() == 40, "all 40 raid plates should be active")
for index = 1, 40 do
	assert(
		mock.plates["nameplate" .. index].ThreatPlatingOverlay.shown,
		"all queued raid plates should complete within eight frames"
	)
end

local initialCounts = CountQueriesByEnemy(initialLogIndex)
for index = 1, 39 do
	assert(initialCounts["nameplate" .. index] == 50, "ordinary raid plates should make 50 queries")
end
assert(initialCounts.nameplate40 == 51, "an outsider target should add exactly one query")
for frame = 1, mock.currentFrame do
	assert(mock.threatQueriesByFrame[frame] <= 255, "no scheduler frame may exceed 255 queries")
end

AssertText(
	"nameplate1",
	"-700",
	"a third actor at 1200 must beat the inferred 1000 reference"
)
AssertText("nameplate2", "-700", "raw-threat deficit should keep its signed value while tanking")
AssertColor("nameplate2", 0.35, 1, 0.35, "tank with aggro should be green")
AssertColor("nameplate3", 1, 0.32, 0.26, "tank without aggro should be red")
AssertText("nameplate5", "-150", "warning state should not change the signed deficit")
AssertColor("nameplate5", 1, 0.62, 0.12, "warning bracket should be orange")

mock.assignedRole = "DAMAGER"
Dispatch("PLAYER_ROLES_ASSIGNED")
RunFrames(8, 0.039)
assert(not addon.playerIsTank, "explicit damage role should select non-tank semantics")
AssertColor("nameplate4", 1, 0.32, 0.26, "non-tank with aggro should be red")
AssertColor("nameplate6", 0.35, 1, 0.35, "non-tank below the pull threshold should be green")
AssertColor("nameplate5", 1, 0.62, 0.12, "warning should override non-tank colors")

Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate2")
Update(0.012)
DrainScheduler()

local rapidLogIndex = #mock.threatQueryLog + 1
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate1")
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate1")
Dispatch("UNIT_THREAT_SITUATION_UPDATE", "nameplate1")
Update(0.049)
assert(#mock.threatQueryLog == rapidLogIndex - 1, "rapid events should wait for the 0.05-second cap")
Update(0.001)
local rapidCounts = CountQueriesByEnemy(rapidLogIndex)
assert(rapidCounts.nameplate1 == 50, "rapid events should coalesce into one exact scan")
assert(rapidCounts.nameplate2 == nil, "a targeted event should not scan another plate")
Update(0)

local overlapLogIndex = #mock.threatQueryLog + 1
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate1")
RunFrames(8, 0.10)
local overlapCounts = CountQueriesByEnemy(overlapLogIndex)
for index = 1, 39 do
	assert(overlapCounts["nameplate" .. index] == 50, "event/poll overlap must scan each plate once")
end
assert(overlapCounts.nameplate40 == 51, "overlap cycle should retain the outsider query")
assert(
	mock.threatQueryLog[overlapLogIndex].enemy == "nameplate1",
	"urgent work should precede poll work"
)
DrainScheduler()

mock.targetPlateUnit = "nameplate1"
local actorEventLogIndex = #mock.threatQueryLog + 1
Dispatch("UNIT_THREAT_SITUATION_UPDATE", "player")
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate1")
Update(0.05)
local actorEventCounts = CountQueriesByEnemy(actorEventLogIndex)
assert(
	actorEventCounts.nameplate1 == 50,
	"a player threat event should urgently resolve the player's hostile target"
)
assert(
	#mock.threatQueryLog == actorEventLogIndex + 49,
	"an actor-token event should refresh only its resolved target"
)
Update(0)
mock.targetPlateUnit = nil

local activeBatchLogIndex = #mock.threatQueryLog + 1
for index = 1, 6 do
	Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate" .. index)
end
Update(0.05)
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate1")
Update(0)
local activeBatchCounts = CountQueriesByEnemy(activeBatchLogIndex)
for index = 1, 6 do
	assert(
		activeBatchCounts["nameplate" .. index] == 50,
		"the active urgent batch should scan each queued plate once"
	)
end
RunFrames(8, 0)
local pendingUrgentLength, pendingPollLength = addon.NameplatesTest.getQueueLengths()
assert(
	pendingUrgentLength == 1 and pendingPollLength == 0,
	"the independent fallback queue should drain without consuming the deferred urgent event"
)
local nextBatchLogIndex = #mock.threatQueryLog + 1
Update(0.049)
assert(
	#mock.threatQueryLog == nextBatchLogIndex - 1,
	"events arriving during a batch should wait for the next capped batch"
)
Update(0.001)
local nextBatchCounts = CountQueriesByEnemy(nextBatchLogIndex)
assert(nextBatchCounts.nameplate1 == 50, "the next urgent batch should process the deferred event")
Update(0)

scenarios.nameplate7 = {
	actors = { ["raid-member-2"] = 100000 },
	player = { false, 0, nil, nil, nil },
}
scenarios.nameplate8 = {
	actors = { ["raid-member-2"] = 95000 },
	player = { false, 1, 100, 100, 120000 },
}
scenarios.nameplate9 = {
	actors = { ["raid-pet-1"] = 120000 },
	player = { false, 1, 100, 100, 100000 },
}
scenarios.nameplate10 = {
	actors = {},
	player = { false, 0, nil, nil, nil },
}
for index = 7, 10 do
	Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate" .. index)
end
RunFrames(1, 0.05)
Update(0)
AssertText("nameplate7", "-1k", "valid nil player threat should preserve the zero-threat deficit")
AssertText("nameplate8", "+250", "leading players should compare against the exact runner-up")
AssertText("nameplate9", "-200", "the player's pet should remain a separate contender")
assert(not mock.plates.nameplate10.ThreatPlatingOverlay.shown, "no meaningful threat should hide the badge")

restricted["raid7:nameplate11"] = true
malformed["raid8:nameplate12"] = true
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate11")
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate12")
RunFrames(1, 0.05)
Update(0)
assert(not mock.plates.nameplate11.ThreatPlatingOverlay.shown, "restricted contender queries should hide")
assert(not mock.plates.nameplate12.ThreatPlatingOverlay.shown, "malformed contender queries should hide")
restricted["raid7:nameplate11"] = nil
malformed["raid8:nameplate12"] = nil
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate11")
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate12")
RunFrames(1, 0.05)
Update(0)
assert(mock.plates.nameplate11.ThreatPlatingOverlay.shown, "restricted plates should recover")
assert(mock.plates.nameplate12.ThreatPlatingOverlay.shown, "malformed plates should recover")

restricted["player:nameplate12"] = true
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate12")
RunFrames(1, 0.05)
Update(0)
assert(not mock.plates.nameplate12.ThreatPlatingOverlay.shown, "restricted player queries should hide")
restricted["player:nameplate12"] = nil
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate12")
RunFrames(1, 0.05)
Update(0)
assert(mock.plates.nameplate12.ThreatPlatingOverlay.shown, "player-query restrictions should recover")

scenarios.nameplate13.actors["raid-member-25"] = 150000
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate13")
RunFrames(1, 0.05)
Update(0)
AssertText("nameplate13", "-500", "an existing roster actor should participate")
mock.units.raid25 = false
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate13")
RunFrames(1, 0.05)
Update(0)
AssertText("nameplate13", "+200", "a missing roster actor should not leave stale threat")
mock.units.raid25 = true

scenarios.nameplate14.actors["raid-pet-25"] = 140000
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate14")
RunFrames(1, 0.05)
Update(0)
AssertText("nameplate14", "-400", "summoned raid pets should be separate contenders")
mock.units.raidpet25 = false
Dispatch("UNIT_THREAT_LIST_UPDATE", "nameplate14")
RunFrames(1, 0.05)
Update(0)
AssertText("nameplate14", "+200", "dismissed raid pets should stop contributing")
mock.units.raidpet25 = true

mock.groupSize = 24
Dispatch("GROUP_ROSTER_UPDATE")
local shortRosterLogIndex = #mock.threatQueryLog + 1
RunFrames(8, 0)
local shortRosterCounts = CountQueriesByEnemy(shortRosterLogIndex)
assert(shortRosterCounts.nameplate1 == 48, "a 24-player roster should query 48 observable actors")
assert(shortRosterCounts.nameplate40 == 49, "the outsider remains one query beyond the roster")
mock.groupSize = 25
Dispatch("GROUP_ROSTER_UPDATE")
RunFrames(8, 0)

local oldPlate = mock.plates.nameplate16
Dispatch("NAME_PLATE_UNIT_REMOVED", "nameplate16")
mock.plates.nameplate16 = nil
local recycledPlate = NewPlate("nameplate16")
Dispatch("NAME_PLATE_UNIT_ADDED", "nameplate16")
RunFrames(1, 0.05)
Update(0)
assert(oldPlate.ThreatPlatingOverlay.unit == nil, "recycled plates should release their old owner")
assert(recycledPlate.ThreatPlatingOverlay.shown, "recycled units should render on their new plate")

local stableFrameCount = #mock.frames
for _ = 1, 3 do
	local cycleLogIndex = #mock.threatQueryLog + 1
	RunFrames(8, 0.10)
	local cycleCounts = CountQueriesByEnemy(cycleLogIndex)
	for index = 1, 39 do
		assert(cycleCounts["nameplate" .. index] == 50, "repeated cycles must scan each ordinary plate once")
	end
	assert(cycleCounts.nameplate40 == 51, "repeated cycles must scan the outsider plate once")
	local urgentLength, pollLength = addon.NameplatesTest.getQueueLengths()
	assert(urgentLength == 0 and pollLength == 0, "repeated cycles must not grow scheduler state")
end
assert(#mock.frames == stableFrameCount, "repeated raid cycles must not create frames or overlays")
assert(#mock.frames > initialFrameCount, "the recycle test should create only its replacement frames")
assert(addon.NameplatesTest.getActiveCount() == 40, "recycling should preserve the active overlay count")
for frame = 1, mock.currentFrame do
	assert(mock.threatQueriesByFrame[frame] <= 255, "all raid scheduler frames must stay within budget")
end

print("Raid runtime: 25 players, 25 pets, and 40 nameplates passed")
