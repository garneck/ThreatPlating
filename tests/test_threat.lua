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
	local delta, isLeader = Threat.CalculateDelta(120000, true, 100, { 95000, 40000 })
	AssertNear(delta, 250, "leader delta")
	AssertEqual(isLeader, true, "leader state")
	AssertEqual(Threat.FormatDelta(delta, isLeader), "+250", "leader text")
end

do
	local delta, isLeader = Threat.CalculateDelta(50000, false, 50, {})
	AssertNear(delta, -500, "inferred deficit")
	AssertEqual(isLeader, false, "deficit state")
	AssertEqual(Threat.FormatDelta(delta, isLeader), "-500", "deficit text")
end

do
	local delta, isLeader = Threat.CalculateDelta(nil, false, nil, { 90000 })
	AssertNear(delta, -900, "zero-threat deficit")
	AssertEqual(isLeader, false, "zero-threat state")
end

do
	local delta, isLeader = Threat.CalculateDelta(120000, false, 120, {})
	AssertNear(delta, 200, "taunt runner-up inference")
	AssertEqual(isLeader, true, "taunt leader state")
end

do
	local delta, isLeader = Threat.CalculateDelta(100000, false, 100, { 90000 })
	AssertNear(delta, 100, "equal-reference inference is not a duplicate contender")
	AssertEqual(isLeader, true, "equal-reference leader state")
end

do
	local delta, isLeader = Threat.CalculateDelta(nil, false, nil, {})
	AssertEqual(delta, nil, "no-data delta")
	AssertEqual(isLeader, false, "no-data state")
end

AssertEqual(Threat.ShouldScanContenders(100000, true, 100), true, "tank scan")
AssertEqual(Threat.ShouldScanContenders(100000, false, 99.5), true, "near-lead scan")
AssertEqual(Threat.ShouldScanContenders(50000, false, 50), false, "deficit inference")
AssertEqual(Threat.ShouldScanContenders(nil, false, nil), true, "zero-threat scan")

AssertEqual(Threat.FormatDelta(12300, true), "+12.3k", "thousands format")
AssertEqual(Threat.FormatDelta(-2000000, false), "-2m", "millions format")
AssertEqual(Threat.FormatDelta(0, true), "+0", "leader tie format")

print(string.format("Threat math: %d assertions passed", passed))
