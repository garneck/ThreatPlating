local _, addon = ...

local Threat = {}
addon.Threat = Threat

local RAW_THREAT_SCALE = 0.01
local TANK_RAW_PERCENTAGE_SENTINEL = 255
local BEAR_FORM_SPELL_ID = 5487
local DIRE_BEAR_FORM_SPELL_ID = 9634
local DEFENSIVE_STANCE_SPELL_ID = 71

-- Deliberately local rather than addon.IsFiniteNumber: Threat.lua must stay loadable
-- without Init.lua so the pure math remains runnable outside WoW.
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

function Threat.SelectHigherRawThreat(currentRawThreat, candidateRawThreat)
	local highestRawThreat
	if IsFiniteNumber(currentRawThreat) and currentRawThreat > 0 then
		highestRawThreat = currentRawThreat
	end

	if IsFiniteNumber(candidateRawThreat)
		and candidateRawThreat > 0
		and (not highestRawThreat or candidateRawThreat > highestRawThreat)
	then
		return candidateRawThreat
	end

	return highestRawThreat
end

function Threat.IsTankRole(
	classToken,
	dominantTalentTree,
	activeFormSpellID,
	assignedRole,
	isMainTank,
	isEffectivelyTank
)
	if isMainTank or assignedRole == "TANK" then
		return true
	end

	if assignedRole == "HEALER" or assignedRole == "DAMAGER" then
		return false
	end

	if classToken == "DRUID" then
		-- Feral is a shared tank/DPS tree in TBC, so the active form is the
		-- useful signal when no explicit group role is available.
		return activeFormSpellID == BEAR_FORM_SPELL_ID
			or activeFormSpellID == DIRE_BEAR_FORM_SPELL_ID
	end

	if classToken == "WARRIOR" then
		if activeFormSpellID == DEFENSIVE_STANCE_SPELL_ID then
			return true
		end
	end

	if type(isEffectivelyTank) == "boolean" then
		return isEffectivelyTank
	end

	return (classToken == "PALADIN" and dominantTalentTree == 2)
		or (classToken == "WARRIOR" and dominantTalentTree == 3)
end

function Threat.GetSafetyState(
	roleIsTank,
	isTanking,
	scaledPercentage,
	rawPercentage
)
	if type(isTanking) ~= "boolean" then
		return nil
	end

	local scaledMissing = scaledPercentage == nil
	local rawMissing = rawPercentage == nil
	if scaledMissing ~= rawMissing then
		return nil
	end
	if not scaledMissing then
		if not IsFiniteNumber(scaledPercentage)
			or scaledPercentage < 0
			or not IsFiniteNumber(rawPercentage)
			or rawPercentage < 0
		then
			return nil
		end
	end

	if not isTanking
		and rawPercentage ~= nil
		and rawPercentage > 100
		and scaledPercentage < 100
	then
		return "warning"
	end

	if roleIsTank then
		return isTanking and "safe" or "danger"
	end

	if isTanking then
		return "danger"
	end

	-- A completely empty percentage pair is the valid no-threat API result.
	if scaledPercentage == nil or scaledPercentage < 100 then
		return "safe"
	end

	return "danger"
end

function Threat.CalculateDelta(
	playerRawThreat,
	rawPercentage,
	highestContenderRawThreat,
	isTanking
)
	if playerRawThreat ~= nil
		and (not IsFiniteNumber(playerRawThreat) or playerRawThreat < 0)
	then
		return nil, false
	end
	if rawPercentage ~= nil
		and (not IsFiniteNumber(rawPercentage) or rawPercentage < 0)
	then
		return nil, false
	end
	if highestContenderRawThreat ~= nil
		and (not IsFiniteNumber(highestContenderRawThreat)
			or highestContenderRawThreat < 0)
	then
		return nil, false
	end

	local playerThreat = NormalizeRawThreat(playerRawThreat)
	local contenderThreat = NormalizeRawThreat(highestContenderRawThreat)

	-- rawPercentage lets us infer the reference actor even if that actor has
	-- no group unit token. isTanking describes aggro, not necessarily the
	-- highest raw threat during taunts and fixates.
	if playerThreat > 0
		and IsFiniteNumber(rawPercentage)
		and rawPercentage > 0
	then
		-- TBC Anniversary 2.5.6 can return exactly 255 for the actor that is
		-- tanking, even when that actor is the only unit on the threat table.
		-- It is therefore an unusable main-tank sentinel, not evidence of a
		-- reference actor at playerThreat / 2.55. Keep the exception scoped to
		-- a tanking source so a real non-tanking 255% reading can still infer
		-- the current tank during a fixate or other forced-target mechanic.
		--
		-- Exactly 100% likewise means the player is the API's own reference
		-- actor only while actually tanking. A non-tanking player at exactly
		-- 100% is tied with a distinct reference actor, so inference still
		-- produces a zero lead rather than the player's entire threat total.
		--
		-- Below 100% while tanking contradicts the verified reference
		-- semantics outright: the reference is the current tank, and the
		-- tanking player cannot hold less than 100% of their own threat. The
		-- client emits that pair for up to one threat push after a taunt or
		-- rip flips isTanking, and inferring from it manufactures a phantom
		-- contender at playerThreat / (stale% / 100) — a deficit that grows
		-- with the player's own fresh threat. A genuinely leading actor is
		-- still reported through the exact contender scan, which does not
		-- depend on this inference.
		local isSelfReference = isTanking == true
			and (rawPercentage <= 100
				or rawPercentage == TANK_RAW_PERCENTAGE_SENTINEL)
		if not isSelfReference then
			local inferredReferenceThreat = playerThreat * 100 / rawPercentage
			if not IsFiniteNumber(inferredReferenceThreat) then
				return nil, false
			end
			contenderThreat = math.max(contenderThreat, inferredReferenceThreat)
		end
	end

	local leader = math.max(playerThreat, contenderThreat)
	if leader <= 0 then
		return nil, false
	end

	if playerThreat >= leader then
		return playerThreat - contenderThreat, true
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
