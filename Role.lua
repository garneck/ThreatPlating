local _, addon = ...

local Role = {}
local Threat = addon.Threat
local IsFiniteNumber = addon.IsFiniteNumber
local onChanged

local function GetDominantTalentTree()
	if type(GetTalentTabInfo) ~= "function" then
		return nil
	end

	local talentTabCount = 3
	if type(GetNumTalentTabs) == "function" then
		local ok, count = pcall(GetNumTalentTabs)
		if not ok then
			return nil
		end
		if count ~= nil then
			if not IsFiniteNumber(count)
				or count < 1
				or count ~= math.floor(count)
			then
				return nil
			end
			talentTabCount = count
		end
	end

	local dominantTree
	local highestPoints = -1
	local tied = false

	-- Slot layout verified against pinned UI source d6a72ea3: the deprecation shim in
	-- Blizzard_DeprecatedSpecialization returns
	-- `specId, name, description, icon, pointsSpent, background, previewPointsSpent, isUnlocked`.
	for index = 1, talentTabCount do
		local ok, _, _, _, _, pointsSpent = pcall(GetTalentTabInfo, index)
		if not ok then
			return nil
		end
		if type(pointsSpent) == "number" then
			if pointsSpent > highestPoints then
				dominantTree = index
				highestPoints = pointsSpent
				tied = false
			elseif pointsSpent == highestPoints then
				tied = true
			end
		end
	end

	if tied or highestPoints <= 0 then
		return nil
	end

	return dominantTree
end

local function GetActiveFormSpellID()
	if type(GetShapeshiftForm) ~= "function"
		or type(GetShapeshiftFormInfo) ~= "function"
	then
		return nil
	end

	local ok, formIndex = pcall(GetShapeshiftForm)
	if not ok then
		return nil
	end
	if not IsFiniteNumber(formIndex)
		or formIndex <= 0
		or formIndex ~= math.floor(formIndex)
	then
		return nil
	end

	-- Slot layout verified against pinned UI source d6a72ea3:
	-- Blizzard_ActionBar/Shared/StanceBar.lua reads
	-- `texture, isActive, isCastable, spellID = GetShapeshiftFormInfo(i)`.
	local formOK, _, isActive, _, spellID = pcall(GetShapeshiftFormInfo, formIndex)
	if not formOK then
		return nil
	end

	-- Fail closed rather than hand a non-number to the spell-ID comparisons in
	-- Threat.IsTankRole, which would silently grade every bear/defensive-stance
	-- player as a non-tank.
	if isActive
		and IsFiniteNumber(spellID)
		and spellID > 0
		and spellID == math.floor(spellID)
	then
		return spellID
	end

	return nil
end

local function GetEffectiveTankSignal()
	local playerUtil = _G.PlayerUtil
	if type(playerUtil) ~= "table"
		or type(playerUtil.IsPlayerEffectivelyTank) ~= "function"
	then
		return nil
	end

	local ok, isTank = pcall(playerUtil.IsPlayerEffectivelyTank)
	if ok and type(isTank) == "boolean" then
		return isTank
	end

	return nil
end

local function DetectPlayerTankRole()
	local assignedRole = "NONE"
	if type(UnitGroupRolesAssigned) == "function" then
		local ok, role = pcall(UnitGroupRolesAssigned, "player")
		if ok then
			assignedRole = role or assignedRole
		end
	end

	local isMainTank = false
	if type(GetPartyAssignment) == "function" then
		local ok, assigned = pcall(GetPartyAssignment, "MAINTANK", "player", true)
		isMainTank = ok and assigned and true or false
	end

	local _, classToken = UnitClass("player")
	local activeFormSpellID = GetActiveFormSpellID()

	-- Threat.IsTankRole owns the whole precedence order (assignment, druid form,
	-- warrior stance, effective-tank helper, legacy talents). Do not re-implement
	-- any prefix of it here; RefreshPlayerRole runs on role/form/roster changes
	-- only, never per plate, so the extra guarded lookups are free.
	local effectiveTank = GetEffectiveTankSignal()
	return Threat.IsTankRole(
		classToken,
		effectiveTank == nil and GetDominantTalentTree() or nil,
		activeFormSpellID,
		assignedRole,
		isMainTank,
		effectiveTank
	)
end

function addon:RefreshPlayerRole()
	local isTank = DetectPlayerTankRole()
	if self.playerIsTank == isTank then
		return
	end

	self.playerIsTank = isTank
	if onChanged then
		onChanged()
	end

	if self.RefreshConfig then
		self.RefreshConfig()
	end
end

Role.GetDominantTalentTree = GetDominantTalentTree
Role.GetActiveFormSpellID = GetActiveFormSpellID

function Role.SetChangedCallback(callback)
	onChanged = callback
end

addon.Role = Role
