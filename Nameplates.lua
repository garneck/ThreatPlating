local _, addon = ...

local POLL_INTERVAL = addon.updateInterval
local EVENT_REFRESH_DELAY = addon.eventRefreshDelay
local MAX_PLATES_PER_FRAME = 5
local Threat = addon.Threat
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local GetNamePlates = C_NamePlate.GetNamePlates
local GetTime = GetTime
local UnitCanAttack = UnitCanAttack
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitPlayerControlled = UnitPlayerControlled
local BACKDROP = addon.BACKDROP

local activeNameplates = {}
local threatSources = {}
local urgentQueue = {}
local urgentGenerations = {}
local urgentHead = 1
local urgentTail = 0
local pollQueue = {}
local pollGenerations = {}
local pollHead = 1
local pollTail = 0
local elapsedSincePoll = 0
local elapsedSinceUrgentRefresh = 0
local urgentBatchReady = false
local urgentBatchTail = 0
local scanRevision = 0
local eventFrame = CreateFrame("Frame")
local referenceVisual = {}

local IsFiniteNumber = addon.IsFiniteNumber

local function QueueRecord(record, queueKind)
	local overlay = record and record.overlay
	if not overlay or overlay.unit == nil then
		return
	end

	if overlay.queuedKind == "urgent" then
		return
	end
	if overlay.queuedKind == queueKind then
		return
	end

	overlay.queueGeneration = (overlay.queueGeneration or 0) + 1
	overlay.queuedKind = queueKind
	if queueKind == "urgent" then
		urgentTail = urgentTail + 1
		urgentQueue[urgentTail] = record
		urgentGenerations[urgentTail] = overlay.queueGeneration
	else
		pollTail = pollTail + 1
		pollQueue[pollTail] = record
		pollGenerations[pollTail] = overlay.queueGeneration
	end
end

local function QueueAllNameplates(queueKind)
	for _, record in pairs(activeNameplates) do
		QueueRecord(record, queueKind)
	end
end

local function ClearScheduler()
	for index = urgentHead, urgentTail do
		urgentQueue[index] = nil
		urgentGenerations[index] = nil
	end
	for index = pollHead, pollTail do
		pollQueue[index] = nil
		pollGenerations[index] = nil
	end
	urgentHead = 1
	urgentTail = 0
	pollHead = 1
	pollTail = 0
	urgentBatchReady = false
	urgentBatchTail = 0

	for _, record in pairs(activeNameplates) do
		local overlay = record.overlay
		overlay.queueGeneration = (overlay.queueGeneration or 0) + 1
		overlay.queuedKind = nil
	end
end

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
	QueueAllNameplates("poll")

	if self.RefreshConfig then
		self.RefreshConfig()
	end
end

local function IsEligibleUnit(unit)
	return UnitExists(unit)
		and UnitCanAttack("player", unit)
		and not UnitIsPlayer(unit)
		and not UnitPlayerControlled(unit)
end

local function GetUnitFrame(nameplate)
	return nameplate and (nameplate.UnitFrame or nameplate.unitFrame)
end

-- NamePlateBaseMixin:SetUnit stores the token as `unitToken` and exposes GetUnit()
-- (pinned UI source d6a72ea3, Blizzard_NamePlates/Blizzard_NamePlateBase.lua). The
-- other two forms are compatibility fallbacks for replacement nameplate addons and
-- must never be the primary read.
local function GetNameplateUnitToken(nameplate)
	if not nameplate then
		return nil
	end

	local unit = nameplate.unitToken
	if not unit and type(nameplate.GetUnit) == "function" then
		local ok, resolved = pcall(nameplate.GetUnit, nameplate)
		if ok then
			unit = resolved
		end
	end
	if not unit then
		unit = nameplate.namePlateUnitToken
	end
	if not unit then
		local unitFrame = GetUnitFrame(nameplate)
		unit = unitFrame and unitFrame.unit
	end

	if type(unit) ~= "string" then
		return nil
	end
	return unit
end

local function GetLegacyHealthBar(unitFrame, nameplate)
	if unitFrame then
		if unitFrame.healthBar then
			return unitFrame.healthBar
		end
		if unitFrame.Health then
			return unitFrame.Health
		end
	end

	if nameplate and nameplate.unitFramePlater and nameplate.unitFramePlater.healthBar then
		return nameplate.unitFramePlater.healthBar
	end

	return nameplate
end

local function GetHealthBarAnchor(nameplate)
	local unitFrame = GetUnitFrame(nameplate)
	if unitFrame and unitFrame.HealthBarsContainer then
		return unitFrame.HealthBarsContainer
	end

	return GetLegacyHealthBar(unitFrame, nameplate)
end

local function GetVisualHealthBar(nameplate)
	local unitFrame = GetUnitFrame(nameplate)
	if unitFrame
		and unitFrame.HealthBarsContainer
		and unitFrame.HealthBarsContainer.healthBar
	then
		return unitFrame.HealthBarsContainer.healthBar
	end

	return GetLegacyHealthBar(unitFrame, nameplate)
end

local function ApplyAnchor(overlay, nameplate)
	local anchor = GetHealthBarAnchor(nameplate)
	local db = addon.db

	if not anchor
		or (overlay.anchor == anchor and overlay.layoutRevision == addon.layoutRevision)
	then
		return
	end

	overlay.anchor = anchor
	overlay.layoutRevision = addon.layoutRevision
	overlay:ClearAllPoints()
	overlay:SetPoint(db.anchorPoint, anchor, db.relativePoint, db.offsetX, db.offsetY)
	overlay:SetFrameLevel(math.max(nameplate:GetFrameLevel(), anchor:GetFrameLevel()) + 20)
end

local function ApplyOverlayLayout(overlay, nameplate)
	-- badgeHeight is a layout setting, so this gate follows layoutRevision only.
	if overlay.heightLayoutRevision ~= addon.layoutRevision then
		overlay.heightLayoutRevision = addon.layoutRevision
		overlay:SetHeight(addon.db.badgeHeight)
	end

	ApplyAnchor(overlay, nameplate)
end

local function ApplyBadgeWidthForRevision(overlay)
	addon:ApplyBadgeWidth(overlay, overlay.text)
	overlay.displayLayoutRevision = addon.layoutRevision
	overlay.displayStyleRevision = addon.styleRevision
end

local function ApplyOverlayStyle(overlay)
	if overlay.styleRevision == addon.styleRevision then
		return
	end

	overlay.styleRevision = addon.styleRevision
	addon:ApplyBadgeStyle(overlay, overlay.text)
end

local function OnNameplateHide(nameplate)
	local overlay = nameplate.ThreatPlatingOverlay
	if overlay then
		overlay:Hide()
	end
end

local function CreateOverlay(nameplate)
	local overlay = CreateFrame("Frame", nil, nameplate, "BackdropTemplate")
	overlay:SetSize(addon.db.badgeWidth, addon.db.badgeHeight)
	overlay:SetBackdrop(BACKDROP)
	overlay:EnableMouse(false)
	overlay:Hide()

	local text = overlay:CreateFontString(nil, "OVERLAY")
	text:SetPoint("CENTER", overlay, "CENTER", 0, 0)
	overlay.text = text

	ApplyOverlayStyle(overlay)
	ApplyOverlayLayout(overlay, nameplate)

	if not nameplate.ThreatPlatingHideHooked then
		nameplate:HookScript("OnHide", OnNameplateHide)
		nameplate.ThreatPlatingHideHooked = true
	end

	nameplate.ThreatPlatingOverlay = overlay
	overlay.queueGeneration = 0
	overlay.record = {
		nameplate = nameplate,
		overlay = overlay,
	}
	return overlay
end

local function DisplayValue(record, value, isLeader, safetyState)
	local overlay = record.overlay
	local text
	if overlay.cachedDisplayValue == value
		and overlay.cachedDisplayIsLeader == isLeader
	then
		text = overlay.cachedDisplayText
	else
		text = Threat.FormatDelta(value, isLeader)
		overlay.cachedDisplayValue = value
		overlay.cachedDisplayIsLeader = isLeader
		overlay.cachedDisplayText = text
	end

	if not text then
		overlay:Hide()
		return
	end

	local layoutChanged = overlay.displayLayoutRevision ~= addon.layoutRevision
	local styleChanged = overlay.displayStyleRevision ~= addon.styleRevision
	local textChanged = false
	ApplyOverlayLayout(overlay, record.nameplate)
	ApplyOverlayStyle(overlay)

	if overlay.displayText ~= text then
		overlay.displayText = text
		overlay.text:SetText(text)
		textChanged = true
	end

	-- New text can change the measured string width, so it re-runs the width pass
	-- without pretending the font or colors changed.
	if layoutChanged or styleChanged or textChanged then
		ApplyBadgeWidthForRevision(overlay)
	end

	if styleChanged
		or overlay.colorSafetyState ~= safetyState
	then
		addon:ApplyThreatColor(
			overlay,
			overlay.text,
			safetyState
		)
		overlay.colorSafetyState = safetyState
	end

	if not overlay:IsShown() then
		overlay:Show()
	end
end

local function ReleaseNameplate(unit, record)
	if not record or activeNameplates[unit] ~= record then
		return
	end

	activeNameplates[unit] = nil
	record.overlay.queueGeneration = (record.overlay.queueGeneration or 0) + 1
	record.overlay.queuedKind = nil
	if record.overlay.unit == unit then
		record.overlay.unit = nil
		record.overlay:Hide()
	end
end

local function ReleaseOverlayOwner(overlay)
	if not overlay then
		return
	end

	local unit = overlay.unit
	local record = unit and activeNameplates[unit]
	if record and record.overlay == overlay then
		ReleaseNameplate(unit, record)
	else
		overlay.unit = nil
		overlay:Hide()
	end
end

local function QueryThreat(sourceUnit, enemyUnit)
	local ok, isTanking, status, scaledPercentage, rawPercentage, rawThreat =
		pcall(UnitDetailedThreatSituation, sourceUnit, enemyUnit)

	if not ok then
		return false
	end

	if isTanking == nil
		and status == nil
		and scaledPercentage == nil
		and rawPercentage == nil
		and rawThreat == nil
	then
		return true, false, nil, nil, 0
	end

	if type(isTanking) ~= "boolean"
		or not IsFiniteNumber(status)
		or status < 0
		or status > 3
		or status ~= math.floor(status)
	then
		return false
	end

	if (scaledPercentage == nil) ~= (rawPercentage == nil) then
		return false
	end
	if scaledPercentage ~= nil
		and (not IsFiniteNumber(scaledPercentage)
			or scaledPercentage < 0
			or not IsFiniteNumber(rawPercentage)
			or rawPercentage < 0)
	then
		return false
	end

	if rawThreat ~= nil
		and (not IsFiniteNumber(rawThreat) or rawThreat < 0)
	then
		return false
	end

	return true,
		isTanking,
		scaledPercentage,
		rawPercentage,
		rawThreat or 0
end

local function CollectHighestContenderThreat(enemyUnit, enemyTarget)
	local highestRawThreat
	local targetExists = UnitExists(enemyTarget)
	local targetAlreadyIncluded = not targetExists

	for index = 1, #threatSources do
		local sourceUnit = threatSources[index]
		if UnitExists(sourceUnit) then
			if targetExists and UnitIsUnit(sourceUnit, enemyTarget) then
				targetAlreadyIncluded = true
			end

			if not UnitIsUnit(sourceUnit, "player") then
				local valid, _, _, _, rawThreat = QueryThreat(sourceUnit, enemyUnit)
				if not valid then
					return false
				end
				highestRawThreat = Threat.SelectHigherRawThreat(
					highestRawThreat,
					rawThreat
				)
			end
		end
	end

	-- This covers an NPC or out-of-group actor currently tanking the enemy.
	if not targetAlreadyIncluded then
		if not UnitIsUnit(enemyTarget, "player") then
			local valid, _, _, _, rawThreat = QueryThreat(enemyTarget, enemyUnit)
			if not valid then
				return false
			end
			highestRawThreat = Threat.SelectHigherRawThreat(
				highestRawThreat,
				rawThreat
			)
		end
	end

	return true, highestRawThreat
end

local function UpdateNameplate(unit, record)
	if not addon.enabled
		or record.overlay.unit ~= unit
		or not record.nameplate:IsShown()
		or GetNamePlateForUnit(unit) ~= record.nameplate
		or not IsEligibleUnit(unit)
	then
		record.overlay:Hide()
		return
	end

	if addon.configPreviewActive then
		local _, isLeader, safetyState = addon:GetConfigPreviewScenario()
		DisplayValue(record, addon.sampleThreatDelta, isLeader, safetyState)
		return
	end

	if addon.testModeUntil > GetTime() then
		DisplayValue(
			record,
			addon.sampleThreatDelta,
			true,
			addon.testPullThresholdWarning and "warning"
				or (addon.playerIsTank and "safe" or "danger")
		)
		return
	end

	local playerQueryValid,
		isTanking,
		scaledPercentage,
		rawPercentage,
		playerRawThreat =
		QueryThreat("player", unit)
	if not playerQueryValid then
		record.overlay:Hide()
		return
	end

	local safetyState = Threat.GetSafetyState(
		addon.playerIsTank,
		isTanking,
		scaledPercentage,
		rawPercentage
	)
	if not safetyState then
		record.overlay:Hide()
		return
	end

	local contenderQueryValid, highestContenderRawThreat =
		CollectHighestContenderThreat(unit, record.targetUnit)
	if not contenderQueryValid then
		record.overlay:Hide()
		return
	end

	local delta, isLeader = Threat.CalculateDelta(
		playerRawThreat,
		rawPercentage,
		highestContenderRawThreat,
		isTanking
	)

	if delta == nil then
		record.overlay:Hide()
		return
	end

	DisplayValue(record, delta, isLeader, safetyState)
end

local function AddThreatSource(unit)
	threatSources[#threatSources + 1] = unit
end

local function RebuildThreatSources()
	wipe(threatSources)

	if IsInRaid() then
		for index = 1, GetNumGroupMembers() do
			local raidUnit = "raid" .. index
			if not UnitIsUnit(raidUnit, "player") then
				AddThreatSource(raidUnit)
			end
			AddThreatSource("raidpet" .. index)
		end
	elseif IsInGroup() then
		for index = 1, GetNumSubgroupMembers() do
			AddThreatSource("party" .. index)
			AddThreatSource("partypet" .. index)
		end
		AddThreatSource("pet")
	else
		AddThreatSource("pet")
	end

	QueueAllNameplates("poll")
end

local function AddNameplate(unit)
	local existingRecord = activeNameplates[unit]
	local nameplate = GetNamePlateForUnit(unit)
	if not nameplate then
		ReleaseNameplate(unit, existingRecord)
		return
	end

	if not addon.enabled or not IsEligibleUnit(unit) then
		ReleaseNameplate(unit, existingRecord)
		ReleaseOverlayOwner(nameplate.ThreatPlatingOverlay)
		return
	end

	local overlay = nameplate.ThreatPlatingOverlay or CreateOverlay(nameplate)
	if existingRecord
		and existingRecord.nameplate == nameplate
		and overlay.unit == unit
	then
		return existingRecord
	end

	if existingRecord then
		ReleaseNameplate(unit, existingRecord)
	end

	if overlay.unit and overlay.unit ~= unit then
		ReleaseOverlayOwner(overlay)
	end

	overlay.unit = unit
	overlay:Hide()

	local record = overlay.record
	activeNameplates[unit] = record
	record.targetUnit = unit .. "target"
	QueueRecord(record, "urgent")
	return record
end

local function RemoveNameplate(unit)
	local record = activeNameplates[unit]
	ReleaseNameplate(unit, record)
end

function addon:ScanVisibleNameplates()
	if not self.enabled then
		return
	end

	scanRevision = scanRevision + 1

	for _, nameplate in ipairs(GetNamePlates()) do
		local unit = GetNameplateUnitToken(nameplate)

		if unit then
			local record = AddNameplate(unit)
			if record then
				record.scanRevision = scanRevision
			end
		end
	end

	for unit, record in pairs(activeNameplates) do
		if record.scanRevision ~= scanRevision then
			ReleaseNameplate(unit, record)
		end
	end
end

local function PopQueuedRecord(queueKind, maximumTail)
	local queue
	local generations
	local head
	local tail
	local physicalTail
	if queueKind == "urgent" then
		queue = urgentQueue
		generations = urgentGenerations
		head = urgentHead
		physicalTail = urgentTail
		tail = maximumTail and math.min(maximumTail, physicalTail) or physicalTail
	else
		queue = pollQueue
		generations = pollGenerations
		head = pollHead
		physicalTail = pollTail
		tail = physicalTail
	end

	local result
	while head <= tail do
		local record = queue[head]
		local generation = generations[head]
		queue[head] = nil
		generations[head] = nil
		head = head + 1

		local overlay = record and record.overlay
		if overlay
			and overlay.queueGeneration == generation
			and overlay.queuedKind == queueKind
			and overlay.unit ~= nil
		then
			overlay.queuedKind = nil
			result = record
			break
		end
	end

	if head > physicalTail then
		head = 1
		physicalTail = 0
	end
	if queueKind == "urgent" then
		urgentHead = head
		urgentTail = physicalTail
	else
		pollHead = head
		pollTail = physicalTail
	end

	return result
end

local function EndUrgentBatch()
	urgentBatchReady = false
	urgentBatchTail = 0
	elapsedSinceUrgentRefresh = 0
end

local function ProcessQueuedNameplates()
	local processed = 0
	if urgentBatchReady then
		while processed < MAX_PLATES_PER_FRAME do
			local record = PopQueuedRecord("urgent", urgentBatchTail)
			if not record then
				EndUrgentBatch()
				break
			end

			UpdateNameplate(record.overlay.unit, record)
			processed = processed + 1
		end
		if urgentBatchReady
			and (urgentTail == 0 or urgentHead > urgentBatchTail)
		then
			EndUrgentBatch()
		end
	end

	while processed < MAX_PLATES_PER_FRAME do
		local record = PopQueuedRecord("poll")
		if not record then
			break
		end

		UpdateNameplate(record.overlay.unit, record)
		processed = processed + 1
	end
end

function addon.UpdateAllNameplates()
	if addon.configPreviewActive or addon.testModeUntil > GetTime() then
		ClearScheduler()
		for unit, record in pairs(activeNameplates) do
			UpdateNameplate(unit, record)
		end
		return
	end

	QueueAllNameplates("poll")
end

function addon.HideAllNameplates()
	ClearScheduler()
	for _, record in pairs(activeNameplates) do
		record.overlay:Hide()
	end
end

local function FiniteOr(value, fallback)
	if IsFiniteNumber(value) then
		return value
	end
	return fallback
end

local TEXT_VISUAL_SUFFIXES = {
	"Text",
	"FontPath",
	"FontSize",
	"FontFlags",
	"Red",
	"Green",
	"Blue",
	"Alpha",
	"OffsetX",
	"OffsetY",
}

-- referenceVisual is a single reused table, so every key a prefix can write has to be
-- cleared before a new plate is read. Otherwise a plate with no readable name is drawn
-- with the previous plate's font, offset, and color.
local function ClearTextVisual(prefix)
	for index = 1, #TEXT_VISUAL_SUFFIXES do
		referenceVisual[prefix .. TEXT_VISUAL_SUFFIXES[index]] = nil
	end
end

local function ReadFontStringVisual(fontString, prefix, healthBar)
	if not fontString
		or not fontString.GetText
		or (fontString.IsShown and not fontString:IsShown())
	then
		return false
	end

	local text = fontString:GetText()
	if type(text) ~= "string" or text == "" then
		return false
	end

	referenceVisual[prefix .. "Text"] = text
	local fontPath, fontSize, fontFlags
	if fontString.GetFont then
		fontPath, fontSize, fontFlags = fontString:GetFont()
	end
	referenceVisual[prefix .. "FontPath"] = fontPath
	referenceVisual[prefix .. "FontSize"] = fontSize
	referenceVisual[prefix .. "FontFlags"] = fontFlags

	local red, green, blue, alpha = 1, 1, 1, 1
	if fontString.GetTextColor then
		red, green, blue, alpha = fontString:GetTextColor()
	end
	referenceVisual[prefix .. "Red"] = FiniteOr(red, 1)
	referenceVisual[prefix .. "Green"] = FiniteOr(green, 1)
	referenceVisual[prefix .. "Blue"] = FiniteOr(blue, 1)
	referenceVisual[prefix .. "Alpha"] = FiniteOr(alpha, 1)

	local textX, textY = fontString:GetCenter()
	local barX, barY = healthBar:GetCenter()
	if IsFiniteNumber(textX)
		and IsFiniteNumber(textY)
		and IsFiniteNumber(barX)
		and IsFiniteNumber(barY)
	then
		referenceVisual[prefix .. "OffsetX"] = textX - barX
		referenceVisual[prefix .. "OffsetY"] = textY - barY
	else
		referenceVisual[prefix .. "OffsetX"] = nil
		referenceVisual[prefix .. "OffsetY"] = nil
	end

	return true
end

local function ReadStatusBarVisual(healthBar)
	referenceVisual.texture = nil
	if healthBar.GetStatusBarTexture then
		local texture = healthBar:GetStatusBarTexture()
		if texture and texture.GetTexture then
			referenceVisual.texture = texture:GetTexture()
		end
	end

	local red, green, blue, alpha = 0.72, 0.12, 0.10, 1
	if healthBar.GetStatusBarColor then
		red, green, blue, alpha = healthBar:GetStatusBarColor()
	end
	referenceVisual.red = FiniteOr(red, 0.72)
	referenceVisual.green = FiniteOr(green, 0.12)
	referenceVisual.blue = FiniteOr(blue, 0.10)
	referenceVisual.alpha = FiniteOr(alpha, 1)

	referenceVisual.fill = 0.70
	if not healthBar.GetMinMaxValues or not healthBar.GetValue then
		return
	end

	local minimum, maximum = healthBar:GetMinMaxValues()
	local value = healthBar:GetValue()
	if IsFiniteNumber(minimum)
		and IsFiniteNumber(maximum)
		and IsFiniteNumber(value)
		and maximum > minimum
	then
		referenceVisual.fill = math.max(
			0,
			math.min(1, (value - minimum) / (maximum - minimum))
		)
	end
end

local function ReadHealthTextVisual(healthBar)
	if ReadFontStringVisual(healthBar.Text, "health", healthBar) then
		return
	end
	if ReadFontStringVisual(healthBar.LeftText, "health", healthBar) then
		return
	end
	ReadFontStringVisual(healthBar.RightText, "health", healthBar)
end

local function PopulateReferenceVisual(record)
	if not record
		or record.overlay.unit == nil
		or not record.nameplate:IsShown()
		or GetNamePlateForUnit(record.overlay.unit) ~= record.nameplate
	then
		return false
	end

	local unitFrame = GetUnitFrame(record.nameplate)
	local healthBar = GetVisualHealthBar(record.nameplate)
	local width = healthBar and healthBar:GetWidth()
	local height = healthBar and healthBar:GetHeight()
	if not IsFiniteNumber(width)
		or width <= 0
		or not IsFiniteNumber(height)
		or height <= 0
	then
		return false
	end

	referenceVisual.width = width
	referenceVisual.height = height
	ReadStatusBarVisual(healthBar)

	ClearTextVisual("name")
	ClearTextVisual("health")
	if unitFrame then
		ReadFontStringVisual(unitFrame.name, "name", healthBar)
	end
	ReadHealthTextVisual(healthBar)

	return true
end

function addon.GetReferenceNameplateVisual()
	local targetPlate = GetNamePlateForUnit("target")
	if targetPlate then
		local overlay = targetPlate.ThreatPlatingOverlay
		if overlay and PopulateReferenceVisual(overlay.record) then
			return referenceVisual
		end
	end

	for unit, record in pairs(activeNameplates) do
		if record.overlay.unit == unit
			and record.nameplate:IsShown()
			and GetNamePlateForUnit(unit) == record.nameplate
		then
			if PopulateReferenceVisual(record) then
				return referenceVisual
			end
		end
	end

	return nil
end

function addon.ApplyDisplaySettings(changeKind)
	changeKind = changeKind or "all"
	if changeKind ~= "layout" and changeKind ~= "style" then
		changeKind = "all"
	end

	if changeKind == "layout" or changeKind == "all" then
		addon.layoutRevision = addon.layoutRevision + 1
	end
	if changeKind == "style" or changeKind == "all" then
		addon.styleRevision = addon.styleRevision + 1
	end

	for _, record in pairs(activeNameplates) do
		local overlay = record.overlay
		ApplyOverlayLayout(overlay, record.nameplate)
		ApplyOverlayStyle(overlay)

		if overlay.displayText then
			ApplyBadgeWidthForRevision(overlay)
			addon:ApplyThreatColor(
				overlay,
				overlay.text,
				overlay.colorSafetyState
			)
		end
	end
end

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
	else
		Add("UnitDetailedThreatSituation: no target")
	end

	return lines
end

local function RequestNameplateRefresh(unit)
	if not addon.enabled then
		return false
	end

	local record = activeNameplates[unit]
	if not record and unit then
		local nameplate = GetNamePlateForUnit(unit)
		local overlay = nameplate and nameplate.ThreatPlatingOverlay
		local overlayUnit = overlay and overlay.unit
		local overlayRecord = overlayUnit and activeNameplates[overlayUnit]
		if overlayRecord and overlayRecord.nameplate == nameplate then
			record = overlayRecord
		end
	end

	if not record or record.overlay.unit == nil then
		return false
	end

	QueueRecord(record, "urgent")
	return true
end

local function RequestThreatEventRefresh(unit)
	if RequestNameplateRefresh(unit) or not unit then
		return
	end

	-- Threat events can identify the actor whose situation changed instead of
	-- the hostile unit. Resolve that actor's target so ordinary damage does not
	-- wait for the full fallback poll.
	if UnitIsUnit(unit, "player") then
		RequestNameplateRefresh("target")
	else
		RequestNameplateRefresh(unit .. "target")
	end
end

eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
eventFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
eventFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")

eventFrame:SetScript("OnEvent", function(_, event, unit)
	if event == "NAME_PLATE_UNIT_ADDED" then
		AddNameplate(unit)
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		RemoveNameplate(unit)
	elseif event == "GROUP_ROSTER_UPDATE" then
		RebuildThreatSources()
		addon:RefreshPlayerRole()
	elseif event == "PLAYER_ENTERING_WORLD" then
		RebuildThreatSources()
		addon:RefreshPlayerRole()
		addon:ScanVisibleNameplates()
	elseif event == "ACTIVE_TALENT_GROUP_CHANGED"
		or event == "PLAYER_ROLES_ASSIGNED"
		or event == "PLAYER_TALENT_UPDATE"
		or event == "UPDATE_SHAPESHIFT_FORM"
	then
		addon:RefreshPlayerRole()
	else
		RequestThreatEventRefresh(unit)
	end
end)

eventFrame:SetScript("OnUpdate", function(_, elapsed)
	if not addon.enabled then
		elapsedSincePoll = 0
		elapsedSinceUrgentRefresh = 0
		if urgentHead <= urgentTail or pollHead <= pollTail then
			ClearScheduler()
		end
		return
	end

	-- /threatplating test enables the runtime flag without touching db.enabled, so the
	-- explicit disabled state has to come back when the sample window closes.
	if addon.testRestoreDisabled and addon.testModeUntil <= GetTime() then
		addon.testRestoreDisabled = false
		addon.enabled = false
		addon.HideAllNameplates()
		return
	end

	elapsedSincePoll = elapsedSincePoll + elapsed
	elapsedSinceUrgentRefresh = elapsedSinceUrgentRefresh + elapsed

	local dueForPoll = elapsedSincePoll >= POLL_INTERVAL
	if dueForPoll then
		elapsedSincePoll = 0
		addon:ScanVisibleNameplates()
		QueueAllNameplates("poll")
	end

	if not urgentBatchReady
		and urgentHead <= urgentTail
		and elapsedSinceUrgentRefresh >= EVENT_REFRESH_DELAY
	then
		urgentBatchReady = true
		urgentBatchTail = urgentTail
	end

	ProcessQueuedNameplates()
end)

if addon.testHarness then
	addon.NameplatesTest = {
		getActiveCount = function()
			local count = 0
			for _ in pairs(activeNameplates) do
				count = count + 1
			end
			return count
		end,
		getQueueLengths = function()
			return math.max(0, urgentTail - urgentHead + 1),
				math.max(0, pollTail - pollHead + 1)
		end,
	}
end

RebuildThreatSources()
addon:RefreshPlayerRole()
