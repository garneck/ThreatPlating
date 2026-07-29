local _, addon = ...

local Threat = {}
addon.Threat = Threat

local RAW_THREAT_SCALE = 0.01
local LEADER_PERCENT_EPSILON = 0.5
local THREAT_EPSILON = 0.005

local function IsFiniteNumber(value)
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

local function NormalizeRawThreat(rawThreat)
	if not IsFiniteNumber(rawThreat) or rawThreat <= 0 then
		return 0
	end

	-- TBC Anniversary reports raw threat in hundredths of a displayed threat unit.
	return rawThreat * RAW_THREAT_SCALE
end

local function AddCandidate(leader, runnerUp, candidate)
	if candidate > leader + THREAT_EPSILON then
		return candidate, leader
	end

	if candidate > runnerUp then
		return leader, candidate
	end

	return leader, runnerUp
end

function Threat.ShouldScanContenders(playerRawThreat, isTanking, rawPercentage)
	if not IsFiniteNumber(playerRawThreat) or playerRawThreat <= 0 then
		return true
	end

	if isTanking then
		return true
	end

	if not IsFiniteNumber(rawPercentage) or rawPercentage <= 0 then
		return true
	end

	-- At (or above) the top of the table, the API percentage cannot tell us the
	-- runner-up. We scan queryable group units to calculate the positive lead.
	return rawPercentage >= (100 - LEADER_PERCENT_EPSILON)
end

function Threat.CalculateDelta(playerRawThreat, rawPercentage, contenderRawThreats)
	local playerThreat = NormalizeRawThreat(playerRawThreat)
	local leader = playerThreat
	local runnerUp = 0

	for index = 1, #contenderRawThreats do
		local contenderThreat = NormalizeRawThreat(contenderRawThreats[index])
		leader, runnerUp = AddCandidate(leader, runnerUp, contenderThreat)
	end

	-- rawPercentage lets us infer the reference actor even if that actor has
	-- no group unit token. isTanking describes aggro, not necessarily the
	-- highest raw threat during taunts and fixates.
	if playerThreat > 0
		and IsFiniteNumber(rawPercentage)
		and rawPercentage > 0
	then
		local inferredReferenceThreat = playerThreat * 100 / rawPercentage
		if math.abs(inferredReferenceThreat - playerThreat) > THREAT_EPSILON then
			leader, runnerUp = AddCandidate(leader, runnerUp, inferredReferenceThreat)
		end
	end

	if leader <= 0 then
		return nil, false
	end

	if playerThreat + THREAT_EPSILON >= leader then
		return math.max(0, playerThreat - runnerUp), true
	end

	return playerThreat - leader, false
end

local function FormatMagnitude(amount)
	amount = math.abs(amount)
	local roundedAmount = math.floor(amount + 0.5)
	if amount > 0 and roundedAmount == 0 then
		roundedAmount = 1
	end

	if roundedAmount >= 999950 then
		return (string.format("%.1fm", roundedAmount / 1000000):gsub("%.0m$", "m"))
	end

	if roundedAmount >= 1000 then
		return (string.format("%.1fk", roundedAmount / 1000):gsub("%.0k$", "k"))
	end

	return tostring(roundedAmount)
end

function Threat.FormatDelta(delta, isLeader)
	if not IsFiniteNumber(delta) then
		return nil
	end

	local sign = isLeader and "+" or "-"
	return sign .. FormatMagnitude(delta)
end
