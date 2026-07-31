local _, addon = ...

local Role = addon.Role
local View = addon.NameplateView
local GetNamePlates = C_NamePlate.GetNamePlates
local GetActiveFormSpellID = Role.GetActiveFormSpellID
local GetDominantTalentTree = Role.GetDominantTalentTree
local GetUnitFrame = View.GetUnitFrame
local GetNameplateUnitToken = View.GetUnitToken

local function DescribeValue(value)
	local valueType = type(value)
	if valueType == "string" then
		return string.format("%q", value)
	end
	if valueType == "number" or valueType == "boolean" or valueType == "nil" then
		return tostring(value)
	end
	return "<" .. valueType .. ">"
end

-- Receives pcall's results as varargs so the exact arity, including trailing nils, is
-- preserved. That arity is the whole point of the probe.
local function DescribeReturns(ok, ...)
	if not ok then
		return "error: " .. tostring((...))
	end

	local count = select("#", ...)
	if count == 0 then
		return "(returned nothing)"
	end

	local description = ""
	for index = 1, count do
		if index > 1 then
			description = description .. ", "
		end
		description = description .. index .. "=" .. DescribeValue((select(index, ...)))
	end
	return description
end

local function DescribeCall(fn, ...)
	if type(fn) ~= "function" then
		return "unavailable"
	end
	return DescribeReturns(pcall(fn, ...))
end

-- The mocks reproduce the slot layouts this file assumes, so by construction they can
-- never disagree with it. This reports the raw tuples next to the addon's reading of
-- them, which turns a client-patch regression from "raid colors look inverted" into a
-- single glance. See the positional-API list in AGENTS.md.
function addon.DescribeClientAPIs()
	local lines = {}

	local function Add(format, ...)
		lines[#lines + 1] = string.format(format, ...)
	end

	Add("%s %s", addon.name, addon.version)
	Add("GetBuildInfo(): %s", DescribeCall(GetBuildInfo))

	-- Every probe names the API it probed even when it cannot call it, so a missing line
	-- always means the probe itself changed rather than the client being quiet.
	if type(GetShapeshiftForm) ~= "function" or type(GetShapeshiftFormInfo) ~= "function" then
		Add("GetShapeshiftFormInfo: unavailable")
	else
		local formOK, formIndex = pcall(GetShapeshiftForm)
		if not formOK then
			Add("GetShapeshiftFormInfo: skipped, GetShapeshiftForm() errored")
		elseif type(formIndex) ~= "number" or formIndex <= 0 then
			Add(
				"GetShapeshiftFormInfo: skipped, GetShapeshiftForm() = %s",
				DescribeValue(formIndex)
			)
		else
			Add(
				"GetShapeshiftFormInfo(%d): %s",
				formIndex,
				DescribeCall(GetShapeshiftFormInfo, formIndex)
			)
		end
	end
	Add("  expected: 1=texture, 2=isActive, 3=isCastable, 4=spellID")
	Add("  addon reads activeFormSpellID = %s", DescribeValue(GetActiveFormSpellID()))

	if type(GetTalentTabInfo) ~= "function" then
		Add("GetTalentTabInfo: unavailable")
	else
		local tabCount = 3
		if type(GetNumTalentTabs) == "function" then
			local ok, count = pcall(GetNumTalentTabs)
			if ok and type(count) == "number" and count >= 1 then
				tabCount = count
			end
		end
		for index = 1, math.min(tabCount, 5) do
			Add("GetTalentTabInfo(%d): %s", index, DescribeCall(GetTalentTabInfo, index))
		end
		Add("  expected: 5=pointsSpent")
	end
	Add("  addon reads dominantTalentTree = %s", DescribeValue(GetDominantTalentTree()))

	local playerUtil = _G.PlayerUtil
	if type(playerUtil) ~= "table" or type(playerUtil.IsPlayerEffectivelyTank) ~= "function" then
		Add("PlayerUtil.IsPlayerEffectivelyTank: unavailable")
	else
		Add(
			"PlayerUtil.IsPlayerEffectivelyTank(): %s",
			DescribeCall(playerUtil.IsPlayerEffectivelyTank)
		)
	end
	Add("  addon detects role = %s", addon.playerIsTank and "tank" or "non-tank")

	local plates = GetNamePlates()
	local nameplate = plates and plates[1]
	if not nameplate then
		Add("nameplate token: no visible plates")
	else
		Add(
			"nameplate token: unitToken=%s GetUnit()=%s namePlateUnitToken=%s UnitFrame.unit=%s",
			DescribeValue(nameplate.unitToken),
			type(nameplate.GetUnit) == "function"
				and DescribeCall(nameplate.GetUnit, nameplate)
				or "unavailable",
			DescribeValue(nameplate.namePlateUnitToken),
			DescribeValue((GetUnitFrame(nameplate) or {}).unit)
		)
		Add("  addon resolves %s", DescribeValue(GetNameplateUnitToken(nameplate)))

		local unitFrame = GetUnitFrame(nameplate)
		Add(
			"  anchor fields: HealthBarsContainer=%s healthBar=%s Health=%s",
			DescribeValue(unitFrame ~= nil and unitFrame.HealthBarsContainer ~= nil),
			DescribeValue(unitFrame ~= nil and unitFrame.healthBar ~= nil),
			DescribeValue(unitFrame ~= nil and unitFrame.Health ~= nil)
		)
	end

	if UnitExists("target") then
		Add(
			"UnitDetailedThreatSituation(player, target): %s",
			DescribeCall(UnitDetailedThreatSituation, "player", "target")
		)
		Add("  expected: 1=isTanking, 2=status, 3=scaledPercentage, 4=rawPercentage, 5=rawThreat")
		Add("  rawThreat is divided by 100 for display")
		Add("  tanking rawPercentage=255 is excluded from reference inference")
	else
		Add("UnitDetailedThreatSituation: no target")
	end

	return lines
end
