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
	local delta, isLeader = Threat.CalculateDelta(120000, 100, 95000)
	AssertNear(delta, 250, "leader delta")
	AssertEqual(isLeader, true, "leader state")
	AssertEqual(Threat.FormatDelta(delta, isLeader), "+250", "leader text")
end

do
	local delta, isLeader = Threat.CalculateDelta(50000, 50, nil)
	AssertNear(delta, -500, "inferred deficit")
	AssertEqual(isLeader, false, "deficit state")
	AssertEqual(Threat.FormatDelta(delta, isLeader), "-500", "deficit text")
end

do
	local delta, isLeader = Threat.CalculateDelta(nil, nil, 90000)
	AssertNear(delta, -900, "zero-threat deficit")
	AssertEqual(isLeader, false, "zero-threat state")
end

do
	local delta, isLeader = Threat.CalculateDelta(120000, 120, nil)
	AssertNear(delta, 200, "taunt runner-up inference")
	AssertEqual(isLeader, true, "taunt leader state")
end

do
	local delta, isLeader = Threat.CalculateDelta(100000, 100, 90000)
	AssertNear(delta, 100, "equal-reference inference is not a duplicate contender")
	AssertEqual(isLeader, true, "equal-reference leader state")
end

do
	local delta, isLeader = Threat.CalculateDelta(nil, nil, nil)
	AssertEqual(delta, nil, "no-data delta")
	AssertEqual(isLeader, false, "no-data state")
end

do
	local delta, isLeader = Threat.CalculateDelta(50000, 50, 120000)
	AssertNear(delta, -700, "observable third actor beats inferred reference")
	AssertEqual(isLeader, false, "third-actor deficit state")
end

AssertEqual(
	Threat.SelectHigherRawThreat(nil, 90000),
	90000,
	"first contender becomes highest"
)
AssertEqual(
	Threat.SelectHigherRawThreat(90000, 120000),
	120000,
	"higher contender replaces highest"
)
AssertEqual(
	Threat.SelectHigherRawThreat(120000, 90000),
	120000,
	"lower contender preserves highest"
)
AssertEqual(
	Threat.SelectHigherRawThreat(math.huge, 90000),
	90000,
	"invalid cached contender is discarded"
)
AssertEqual(
	Threat.SelectHigherRawThreat(90000, math.huge),
	90000,
	"invalid candidate is ignored"
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
AssertEqual(
	Threat.IsTankRole("PALADIN", nil, nil, "NONE", false, true),
	true,
	"effective-tank helper without talents"
)
AssertEqual(
	Threat.IsTankRole("PALADIN", 2, nil, "NONE", false, false),
	false,
	"effective-tank helper overrides legacy talents"
)
AssertEqual(
	Threat.IsTankRole("DRUID", 2, 768, "NONE", false, true),
	false,
	"cat form overrides effective-tank helper"
)

AssertEqual(Threat.GetSafetyState(true, true, 50, 50), "safe", "tank with aggro is safe")
AssertEqual(
	Threat.GetSafetyState(true, true, 125, 80),
	"safe",
	"tank taunt with raw deficit is safe"
)
AssertEqual(
	Threat.GetSafetyState(true, false, 50, 50),
	"danger",
	"tank without aggro is dangerous"
)
AssertEqual(
	Threat.GetSafetyState(false, false, 99.9, 99),
	"safe",
	"non-tank below pull threshold is safe"
)
AssertEqual(
	Threat.GetSafetyState(false, false, 100, 99),
	"danger",
	"non-tank at pull threshold is dangerous"
)
AssertEqual(
	Threat.GetSafetyState(false, true, 75, 75),
	"danger",
	"non-tank with aggro is dangerous"
)
AssertEqual(
	Threat.GetSafetyState(false, false, 95.5, 105),
	"warning",
	"melee pull-threshold warning"
)
AssertEqual(
	Threat.GetSafetyState(true, false, 92.3, 120),
	"warning",
	"ranged warning overrides tank role"
)
AssertEqual(
	Threat.GetSafetyState(false, false, 90, 100),
	"safe",
	"equal raw threat is below warning bracket"
)
AssertEqual(
	Threat.GetSafetyState(false, false, 100, 110),
	"danger",
	"pull threshold boundary is dangerous"
)
AssertEqual(
	Threat.GetSafetyState(false, false, nil, nil),
	"safe",
	"valid empty no-threat percentages are safe"
)
AssertEqual(
	Threat.GetSafetyState(true, false, nil, nil),
	"danger",
	"tank without aggro and no percentages is dangerous"
)
AssertEqual(
	Threat.GetSafetyState(false, false, nil, 105),
	nil,
	"incomplete percentages have no safety state"
)
AssertEqual(
	Threat.GetSafetyState(false, false, math.huge, 105),
	nil,
	"non-finite percentages have no safety state"
)
AssertEqual(
	Threat.GetSafetyState(false, false, -1, 0),
	nil,
	"negative percentages have no safety state"
)
AssertEqual(
	Threat.GetSafetyState(false, nil, 0, 0),
	nil,
	"malformed tanking state has no safety state"
)

AssertEqual(Threat.FormatDelta(12300, true), "+12.3k", "thousands format")
AssertEqual(Threat.FormatDelta(-2000000, false), "-2m", "millions format")
AssertEqual(Threat.FormatDelta(0, true), "+0", "leader tie format")
AssertEqual(Threat.FormatDelta(-0.1, false), "-1", "sub-unit deficit format")
AssertEqual(Threat.FormatDelta(999.6, true), "+1k", "rounded thousands boundary")
AssertEqual(Threat.FormatDelta(999950, true), "+1m", "rounded millions boundary")
AssertEqual(Threat.FormatDelta(math.huge, true), nil, "non-finite delta")

do
	local delta, isLeader = Threat.CalculateDelta(math.huge, 100, nil)
	AssertEqual(delta, nil, "non-finite raw threat delta")
	AssertEqual(isLeader, false, "non-finite raw threat state")
end

do
	local delta, isLeader = Threat.CalculateDelta(100000, 1e-320, nil)
	AssertEqual(delta, nil, "overflowing inference delta")
	AssertEqual(isLeader, false, "overflowing inference state")
end

print(string.format("Threat math: %d assertions passed", passed))
