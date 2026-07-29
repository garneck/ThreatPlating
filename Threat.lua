local _, addon = ...

local Threat = {}
addon.Threat = Threat

local RAW_THREAT_SCALE = 0.01
local LEADER_PERCENT_EPSILON = 0.5
local THREAT_EPSILON = 0.005

local function NormalizeRawThreat(rawThreat)
	if type(rawThreat) ~= "number" or rawThreat <= 0 then
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
	if type(playerRawThreat) ~= "number" or playerRawThreat <= 0 then
		return true
	end

	if isTanking then
		return true
	end

	if type(rawPercentage) ~= "number" or rawPercentage <= 0 then
		return true
	end

	-- At (or above) the top of the table, the API percentage cannot tell us the
	-- runner-up. We scan queryable group units to calculate the positive lead.
	return rawPercentage >= (100 - LEADER_PERCENT_EPSILON)
end

function Threat.CalculateDelta(playerRawThreat, isTanking, rawPercentage, contenderRawThreats)
	local playerThreat = NormalizeRawThreat(playerRawThreat)
	local leader = playerThreat
	local runnerUp = 0

	for index = 1, #contenderRawThreats do
		local contenderThreat = NormalizeRawThreat(contenderRawThreats[index])
		leader, runnerUp = AddCandidate(leader, runnerUp, contenderThreat)
	end

	-- When the player is below the lead, rawPercentage lets us infer the
	-- current leader even if that actor has no group unit token.
	if not isTanking
		and playerThreat > 0
		and type(rawPercentage) == "number"
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

	if amount >= 1000000 then
		return (string.format("%.1fm", amount / 1000000):gsub("%.0m$", "m"))
	end

	if amount >= 1000 then
		return (string.format("%.1fk", amount / 1000):gsub("%.0k$", "k"))
	end

	return tostring(math.floor(amount + 0.5))
end

function Threat.FormatDelta(delta, isLeader)
	if type(delta) ~= "number" then
		return nil
	end

	local sign = isLeader and "+" or "-"
	return sign .. FormatMagnitude(delta)
end
