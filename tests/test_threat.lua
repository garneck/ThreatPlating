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
	local delta, isLeader = Threat.CalculateDelta(120000, 100, 95000, true)
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
	local delta, isLeader = Threat.CalculateDelta(100000, 100, 90000, true)
	AssertNear(delta, 100, "equal-reference inference is not a duplicate contender")
	AssertEqual(isLeader, true, "equal-reference leader state")
end

do
	local delta, isLeader = Threat.CalculateDelta(116421, 255, nil, true)
	AssertNear(delta, 1164.21, "tanking 255 sentinel does not infer a phantom contender")
	AssertEqual(isLeader, true, "tanking 255 sentinel leader state")
	AssertEqual(Threat.FormatDelta(delta, isLeader), "+1.2k", "tanking 255 sentinel text")
end

do
	local delta, isLeader = Threat.CalculateDelta(116421, 255, nil, false)
	AssertNear(delta, 707.657, "non-tanking 255 remains a usable reference percentage")
	AssertEqual(isLeader, true, "non-tanking 255 leader state")
end

do
	local delta, isLeader = Threat.CalculateDelta(116421, 255, 30000, true)
	AssertNear(delta, 864.21, "exact runner-up survives tanking 255 sentinel")
	AssertEqual(isLeader, true, "exact runner-up below tanking 255 sentinel")
end

do
	local delta, isLeader = Threat.CalculateDelta(116421, 255, 120000, true)
	AssertNear(delta, -35.79, "exact leader survives tanking 255 sentinel")
	AssertEqual(isLeader, false, "exact leader above tanking 255 sentinel")
end

do
	-- A taunt or rip flips isTanking up to one threat push before the
	-- percentage pair refreshes. The stale sub-100 reading must join the
	-- self-reference branch instead of inferring a phantom contender at
	-- playerThreat / (stale% / 100), which read -10.5k here while the mob
	-- was already on the player.
	local delta, isLeader = Threat.CalculateDelta(350000, 25, 80000, true)
	AssertNear(delta, 2700, "stale sub-100 tanking percentage is self-reference")
	AssertEqual(isLeader, true, "stale sub-100 tanking leader state")
	AssertEqual(Threat.FormatDelta(delta, isLeader), "+2.7k", "stale sub-100 tanking text")
end

do
	-- The tanking sub-100 branch must stay continuous with the exactly-100
	-- self-reference case it now shares.
	local justBelow = Threat.FormatDelta(Threat.CalculateDelta(350000, 99.999999, 80000, true))
	local exact = Threat.FormatDelta(Threat.CalculateDelta(350000, 100, 80000, true))
	AssertEqual(justBelow, "+2.7k", "just below 100 while tanking")
	AssertEqual(exact, "+2.7k", "exactly 100 while tanking")
end

do
	-- Only the percentage inference is distrusted while tanking; an exact
	-- observable leader must still produce a real deficit.
	local delta, isLeader = Threat.CalculateDelta(350000, 25, 400000, true)
	AssertNear(delta, -500, "exact leader survives tanking sub-100 suppression")
	AssertEqual(isLeader, false, "exact leader above tanking sub-100 state")
end

do
	-- A non-tanking sub-100 reading remains a meaningful reference.
	local delta, isLeader = Threat.CalculateDelta(350000, 25, 80000, false)
	AssertNear(delta, -10500, "non-tanking sub-100 still infers the reference")
	AssertEqual(isLeader, false, "non-tanking sub-100 deficit state")
end

do
	local delta, isLeader = Threat.CalculateDelta(500000, 100, nil, false)
	AssertNear(delta, 0, "an exact non-tanking tie is a zero lead, not a full-threat lead")
	AssertEqual(isLeader, true, "non-tanking tie leader state")
	AssertEqual(Threat.FormatDelta(delta, isLeader), "+0", "non-tanking tie text")
end

do
	-- The exactly-100 branch must stay continuous with its neighbours.
	local below = Threat.FormatDelta(Threat.CalculateDelta(500000, 99.999999, nil, false))
	local exact = Threat.FormatDelta(Threat.CalculateDelta(500000, 100, nil, false))
	local above = Threat.FormatDelta(Threat.CalculateDelta(500000, 100.000001, nil, false))
	AssertEqual(below, "-1", "just below the reference")
	AssertEqual(exact, "+0", "exactly at the reference")
	AssertEqual(above, "+1", "just above the reference")
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

do
	local delta, isLeader = Threat.CalculateDelta(50000, 50, 80000)
	AssertNear(delta, -500, "inferred reference beats lower observable actor")
	AssertEqual(isLeader, false, "inferred-reference deficit state")
end

do
	local delta, isLeader = Threat.CalculateDelta(120000, 120, 110000)
	AssertNear(delta, 100, "observable runner-up beats lower inferred reference")
	AssertEqual(isLeader, true, "observable runner-up leader state")
end

do
	local delta, isLeader = Threat.CalculateDelta(100000, nil, 100000)
	AssertNear(delta, 0, "observable raw-threat tie")
	AssertEqual(isLeader, true, "raw-threat tie counts as highest")
end

do
	local delta, isLeader = Threat.CalculateDelta(101, nil, 100)
	AssertNear(delta, 0.01, "raw threat is scaled by one hundred")
	AssertEqual(isLeader, true, "single raw-unit lead state")
end

do
	local rawLeads = { 0.4, 0.5, 0.6 }
	for _, rawLead in ipairs(rawLeads) do
		local label = string.format("%.3f displayed observable lead", rawLead * 0.01)
		local delta, isLeader = Threat.CalculateDelta(100000, nil, 100000 + rawLead)
		AssertNear(delta, rawLead * -0.01, label .. " delta")
		AssertEqual(isLeader, false, label .. " state")
	end
end

do
	local delta, isLeader = Threat.CalculateDelta(100000.4, nil, 100000)
	AssertNear(delta, 0.004, "sub-cent observable player lead delta")
	AssertEqual(isLeader, true, "sub-cent observable player lead state")
end

do
	local playerThreat = 1000
	local inferredLeads = { 0.004, 0.005, 0.006 }
	for _, inferredLead in ipairs(inferredLeads) do
		local rawPercentage = playerThreat * 100 / (playerThreat + inferredLead)
		local label = string.format("%.3f displayed inferred lead", inferredLead)
		local delta, isLeader = Threat.CalculateDelta(100000, rawPercentage, nil)
		AssertNear(delta, -inferredLead, label .. " delta")
		AssertEqual(isLeader, false, label .. " state")
	end
end

do
	local playerThreat = 1000
	local inferredRunnerUp = playerThreat - 0.004
	local rawPercentage = playerThreat * 100 / inferredRunnerUp
	local delta, isLeader = Threat.CalculateDelta(100000, rawPercentage, nil)
	AssertNear(delta, 0.004, "sub-cent inferred runner-up delta")
	AssertEqual(isLeader, true, "sub-cent inferred runner-up state")
	AssertEqual(Threat.FormatDelta(delta, isLeader), "+1", "sub-cent lead text")
end

do
	local delta, isLeader = Threat.CalculateDelta(50000, 0, 90000)
	AssertNear(delta, -400, "zero percentage does not divide for inference")
	AssertEqual(isLeader, false, "zero-percentage observable deficit state")
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
AssertEqual(
	Threat.SelectHigherRawThreat(0, 0),
	nil,
	"zero-threat contenders are not meaningful"
)
AssertEqual(
	Threat.SelectHigherRawThreat(90000, 90000),
	90000,
	"equal contender preserves highest"
)
AssertEqual(
	Threat.SelectHigherRawThreat(90000, 90000.5),
	90000.5,
	"fractional higher contender is preserved exactly"
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
AssertEqual(
	Threat.IsTankRole("DRUID", 2, nil, "NONE", false, true),
	false,
	"caster form overrides effective-tank helper"
)
AssertEqual(
	Threat.IsTankRole("DRUID", 2, 768, "TANK", false, false),
	true,
	"assigned tank overrides cat form"
)
AssertEqual(
	Threat.IsTankRole("DRUID", 2, 5487, "HEALER", false, true),
	false,
	"assigned healer overrides bear form"
)
AssertEqual(
	Threat.IsTankRole("WARRIOR", 1, 71, "NONE", false, false),
	true,
	"defensive stance overrides negative effective-tank helper"
)
AssertEqual(
	Threat.IsTankRole("WARRIOR", 1, 2457, "NONE", false, true),
	true,
	"effective-tank helper covers non-defensive warrior"
)
AssertEqual(
	Threat.IsTankRole("WARRIOR", 3, 2457, "NONE", false, false),
	false,
	"negative effective-tank helper overrides Protection talents"
)
AssertEqual(
	Threat.IsTankRole("WARRIOR", 3, 2457, "NONE", false, nil),
	true,
	"Protection talents remain the warrior fallback"
)
AssertEqual(
	Threat.IsTankRole("PALADIN", 3, nil, "NONE", false, true),
	true,
	"effective-tank helper covers non-Protection paladin"
)
AssertEqual(
	Threat.IsTankRole("MAGE", nil, nil, "NONE", false, nil),
	false,
	"class without a tank signal is non-tank"
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
AssertEqual(
	Threat.GetSafetyState(false, true, 95, 105),
	"danger",
	"tanking suppresses non-tank warning"
)
AssertEqual(
	Threat.GetSafetyState(true, true, 95, 105),
	"safe",
	"tanking suppresses tank warning"
)
AssertEqual(
	Threat.GetSafetyState(true, false, 95, 100),
	"danger",
	"tank warning requires raw threat above target"
)
AssertEqual(
	Threat.GetSafetyState(false, false, 95, 100),
	"safe",
	"non-tank raw-threat equality remains safe below threshold"
)
AssertEqual(
	Threat.GetSafetyState(true, false, 100, 105),
	"danger",
	"tank warning requires scaled threat below threshold"
)
AssertEqual(
	Threat.GetSafetyState(false, false, 100, 105),
	"danger",
	"non-tank is dangerous at threshold despite raw lead"
)
AssertEqual(
	Threat.GetSafetyState(false, false, 105, nil),
	nil,
	"missing raw percentage has no safety state"
)
AssertEqual(
	Threat.GetSafetyState(false, false, 0, -1),
	nil,
	"negative raw percentage has no safety state"
)
AssertEqual(
	Threat.GetSafetyState(false, false, 0 / 0, 0),
	nil,
	"NaN scaled percentage has no safety state"
)
AssertEqual(
	Threat.GetSafetyState(false, false, 0, 0 / 0),
	nil,
	"NaN raw percentage has no safety state"
)

AssertEqual(Threat.FormatDelta(12300, true), "+12.3k", "thousands format")
AssertEqual(Threat.FormatDelta(-2000000, false), "-2m", "millions format")
AssertEqual(Threat.FormatDelta(0, true), "+0", "leader tie format")
AssertEqual(Threat.FormatDelta(-0.1, false), "-1", "sub-unit deficit format")
AssertEqual(Threat.FormatDelta(999.49, true), "+999", "below thousands boundary")
AssertEqual(Threat.FormatDelta(999.5, true), "+1k", "exact thousands rounding boundary")
AssertEqual(Threat.FormatDelta(999.6, true), "+1k", "rounded thousands boundary")
AssertEqual(Threat.FormatDelta(999949, true), "+999.9k", "below millions boundary")
AssertEqual(Threat.FormatDelta(999949.5, true), "+1m", "exact millions rounding boundary")
AssertEqual(Threat.FormatDelta(999950, true), "+1m", "rounded millions boundary")
AssertEqual(Threat.FormatDelta(1260000, true), "+1.3m", "fractional millions format")
AssertEqual(Threat.FormatDelta(math.huge, true), nil, "non-finite delta")
AssertEqual(Threat.FormatDelta(-math.huge, false), nil, "negative infinite delta")
AssertEqual(Threat.FormatDelta(0 / 0, true), nil, "NaN delta")

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

do
	local delta, isLeader = Threat.CalculateDelta(100000, -1, nil)
	AssertEqual(delta, nil, "negative raw percentage delta")
	AssertEqual(isLeader, false, "negative raw percentage state")
end

do
	local delta, isLeader = Threat.CalculateDelta(100000, 100, -1)
	AssertEqual(delta, nil, "negative contender delta")
	AssertEqual(isLeader, false, "negative contender state")
end

do
	local delta, isLeader = Threat.CalculateDelta(0 / 0, 100, nil)
	AssertEqual(delta, nil, "NaN raw threat delta")
	AssertEqual(isLeader, false, "NaN raw threat state")
end

print(string.format("Threat math: %d assertions passed", passed))
