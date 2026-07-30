local addon = {}
local threatChunk = assert(loadfile("Threat.lua"))
threatChunk("ThreatPlating", addon)

local Threat = addon.Threat
local passed = 0

local function AssertEqual(actual, expected, label)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
	end
	passed = passed + 1
end

local function AssertNear(actual, expected, label)
	if actual == nil or math.abs(actual - expected) > 0.001 then
		error(string.format("%s: expected %.3f, got %s", label, expected, tostring(actual)), 2)
	end
	passed = passed + 1
end

do
	local delta, isLeader = Threat.CalculateDelta(120000, 100, { 95000, 40000 })
	AssertNear(delta, 250, "leader delta")
	AssertEqual(isLeader, true, "leader state")
	AssertEqual(Threat.FormatDelta(delta, isLeader), "+250", "leader text")
end

do
	local delta, isLeader = Threat.CalculateDelta(50000, 50, {})
	AssertNear(delta, -500, "inferred deficit")
	AssertEqual(isLeader, false, "deficit state")
	AssertEqual(Threat.FormatDelta(delta, isLeader), "-500", "deficit text")
end

do
	local delta, isLeader = Threat.CalculateDelta(nil, nil, { 90000 })
	AssertNear(delta, -900, "zero-threat deficit")
	AssertEqual(isLeader, false, "zero-threat state")
end

do
	local delta, isLeader = Threat.CalculateDelta(120000, 120, {})
	AssertNear(delta, 200, "taunt runner-up inference")
	AssertEqual(isLeader, true, "taunt leader state")
end

do
	local delta, isLeader = Threat.CalculateDelta(100000, 100, { 90000 })
	AssertNear(delta, 100, "equal-reference inference is not a duplicate contender")
	AssertEqual(isLeader, true, "equal-reference leader state")
end

do
	local delta, isLeader = Threat.CalculateDelta(nil, nil, {})
	AssertEqual(delta, nil, "no-data delta")
	AssertEqual(isLeader, false, "no-data state")
end

AssertEqual(Threat.ShouldScanContenders(100000, true, 100), true, "tank scan")
AssertEqual(Threat.ShouldScanContenders(100000, false, 99.5), true, "near-lead scan")
AssertEqual(Threat.ShouldScanContenders(50000, false, 50), false, "deficit inference")
AssertEqual(Threat.ShouldScanContenders(nil, false, nil), true, "zero-threat scan")
AssertEqual(Threat.ShouldScanContenders(0, false, 0), true, "explicit zero-threat scan")
AssertEqual(Threat.ShouldScanContenders(50000, false, nil), true, "incomplete percentage scan")
AssertEqual(
	Threat.ShouldScanContenders(50000, false, math.huge - math.huge),
	true,
	"non-finite percentage scan"
)

AssertEqual(Threat.IsTankRole("PALADIN", 2, nil, "NONE", false), true, "protection paladin")
AssertEqual(Threat.IsTankRole("PALADIN", 3, nil, "NONE", false), false, "retribution paladin")
AssertEqual(Threat.IsTankRole("WARRIOR", 3, nil, "NONE", false), true, "protection warrior")
AssertEqual(Threat.IsTankRole("WARRIOR", 1, 71, "NONE", false), true, "defensive stance")
AssertEqual(Threat.IsTankRole("DRUID", 2, 5487, "NONE", false), true, "bear form")
AssertEqual(Threat.IsTankRole("DRUID", 2, 9634, "NONE", false), true, "dire bear form")
AssertEqual(Threat.IsTankRole("DRUID", 2, 768, "NONE", false), false, "cat form")
AssertEqual(Threat.IsTankRole("MAGE", 1, nil, "TANK", false), true, "assigned tank")
AssertEqual(
	Threat.IsTankRole("WARRIOR", 3, 71, "DAMAGER", false),
	false,
	"assigned damage override"
)
AssertEqual(
	Threat.IsTankRole("PALADIN", 3, nil, "HEALER", true),
	true,
	"main tank assignment priority"
)
AssertEqual(Threat.IsDesiredState(true, true), true, "tank leader desired")
AssertEqual(Threat.IsDesiredState(true, false), false, "tank deficit dangerous")
AssertEqual(Threat.IsDesiredState(false, true), false, "non-tank leader dangerous")
AssertEqual(Threat.IsDesiredState(false, false), true, "non-tank deficit desired")

AssertEqual(Threat.FormatDelta(12300, true), "+12.3k", "thousands format")
AssertEqual(Threat.FormatDelta(-2000000, false), "-2m", "millions format")
AssertEqual(Threat.FormatDelta(0, true), "+0", "leader tie format")
AssertEqual(Threat.FormatDelta(-0.1, false), "-1", "sub-unit deficit format")
AssertEqual(Threat.FormatDelta(999.6, true), "+1k", "rounded thousands boundary")
AssertEqual(Threat.FormatDelta(999950, true), "+1m", "rounded millions boundary")
AssertEqual(Threat.FormatDelta(math.huge, true), nil, "non-finite delta")

do
	local delta, isLeader = Threat.CalculateDelta(math.huge, 100, {})
	AssertEqual(delta, nil, "non-finite raw threat delta")
	AssertEqual(isLeader, false, "non-finite raw threat state")
end

print(string.format("Threat math: %d assertions passed", passed))
