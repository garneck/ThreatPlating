local _, addon = ...

local POLL_INTERVAL = addon.updateInterval
local EVENT_REFRESH_DELAY = addon.eventRefreshDelay
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
local elapsedSincePoll = 0
local elapsedSinceRefresh = 0
local refreshRequested = true
local refreshAllRequested = true
local scanRevision = 0
local eventFrame = CreateFrame("Frame")
local referenceVisual = {}

local function IsFiniteNumber(value)
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

local function GetDominantTalentTree()
	if type(GetTalentTabInfo) ~= "function" then
		return nil
	end

	local talentTabCount = 3
	if type(GetNumTalentTabs) == "function" then
		talentTabCount = GetNumTalentTabs() or talentTabCount
	end

	local dominantTree
	local highestPoints = -1
	local tied = false

	for index = 1, talentTabCount do
		local _, _, _, _, pointsSpent = GetTalentTabInfo(index)
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

	local formIndex = GetShapeshiftForm()
	if not formIndex or formIndex <= 0 then
		return nil
	end

	local _, isActive, _, spellID = GetShapeshiftFormInfo(formIndex)
	if isActive then
		return spellID
	end

	return nil
end

local function DetectPlayerTankRole()
	local assignedRole = "NONE"
	if type(UnitGroupRolesAssigned) == "function" then
		assignedRole = UnitGroupRolesAssigned("player") or assignedRole
	end

	local isMainTank = false
	if type(GetPartyAssignment) == "function" then
		isMainTank = GetPartyAssignment("MAINTANK", "player", true) and true or false
	end

	local _, classToken = UnitClass("player")
	return Threat.IsTankRole(
		classToken,
		GetDominantTalentTree(),
		GetActiveFormSpellID(),
		assignedRole,
		isMainTank
	)
end

function addon:RefreshPlayerRole()
	local isTank = DetectPlayerTankRole()
	if self.playerIsTank == isTank then
		return
	end

	self.playerIsTank = isTank
	refreshRequested = true
	refreshAllRequested = true

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
	if overlay.layoutStyleRevision ~= addon.layoutRevision then
		overlay.layoutStyleRevision = addon.layoutRevision
		overlay:SetHeight(addon.db.badgeHeight)
	end

	ApplyAnchor(overlay, nameplate)
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
	overlay.record = {
		nameplate = nameplate,
		overlay = overlay,
	}
	return overlay
end

local function DisplayValue(record, value, isLeader, isPullThresholdWarning, isTank)
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
	ApplyOverlayLayout(overlay, record.nameplate)
	ApplyOverlayStyle(overlay)

	if overlay.displayText ~= text then
		overlay.displayText = text
		overlay.text:SetText(text)
		styleChanged = true
	end

	if layoutChanged or styleChanged then
		addon:ApplyBadgeWidth(overlay, overlay.text)
		overlay.displayLayoutRevision = addon.layoutRevision
		overlay.displayStyleRevision = addon.styleRevision
	end

	if styleChanged
		or overlay.colorIsLeader ~= isLeader
		or overlay.colorIsPullThresholdWarning ~= isPullThresholdWarning
		or overlay.colorIsTank ~= isTank
	then
		addon:ApplyThreatColor(
			overlay,
			overlay.text,
			isLeader,
			isPullThresholdWarning,
			isTank
		)
		overlay.colorIsLeader = isLeader
		overlay.colorIsPullThresholdWarning = isPullThresholdWarning
		overlay.colorIsTank = isTank
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
	record.refreshRequested = false
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

	if not ok or type(status) ~= "number" or type(rawThreat) ~= "number" then
		return false, nil, nil, nil
	end

	return isTanking == true, scaledPercentage, rawPercentage, rawThreat
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
				local _, _, _, rawThreat = QueryThreat(sourceUnit, enemyUnit)
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
			local _, _, _, rawThreat = QueryThreat(enemyTarget, enemyUnit)
			highestRawThreat = Threat.SelectHigherRawThreat(
				highestRawThreat,
				rawThreat
			)
		end
	end

	return highestRawThreat
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
		local isTank, isLeader, isWarning = addon:GetConfigPreviewScenario()
		DisplayValue(record, 12300, isLeader, isWarning, isTank)
		return
	end

	if addon.testModeUntil > GetTime() then
		DisplayValue(
			record,
			12300,
			true,
			addon.testPullThresholdWarning,
			addon.playerIsTank
		)
		return
	end

	local isTanking, scaledPercentage, rawPercentage, playerRawThreat =
		QueryThreat("player", unit)
	local highestContenderRawThreat

	if Threat.ShouldScanContenders(playerRawThreat, isTanking, rawPercentage) then
		highestContenderRawThreat = CollectHighestContenderThreat(unit, record.targetUnit)
	end

	local delta, isLeader = Threat.CalculateDelta(
		playerRawThreat,
		rawPercentage,
		highestContenderRawThreat
	)

	if delta == nil then
		record.overlay:Hide()
		return
	end

	local isPullThresholdWarning = Threat.IsPullThresholdWarning(
		isTanking,
		scaledPercentage,
		rawPercentage
	)
	DisplayValue(record, delta, isLeader, isPullThresholdWarning, addon.playerIsTank)
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

	refreshRequested = true
	refreshAllRequested = true
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
	record.refreshRequested = true
	refreshRequested = true
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
		local unit = nameplate.namePlateUnitToken
		local unitFrame = GetUnitFrame(nameplate)
		if not unit and unitFrame then
			unit = unitFrame.unit
		end

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

function addon.UpdateAllNameplates()
	for unit, record in pairs(activeNameplates) do
		record.refreshRequested = false
		UpdateNameplate(unit, record)
	end

	refreshRequested = false
	refreshAllRequested = false
end

local function UpdateRequestedNameplates()
	for unit, record in pairs(activeNameplates) do
		if record.refreshRequested then
			record.refreshRequested = false
			UpdateNameplate(unit, record)
		end
	end
end

function addon.HideAllNameplates()
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

	referenceVisual.nameText = nil
	referenceVisual.healthText = nil
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
			addon:ApplyBadgeWidth(overlay, overlay.text)
			overlay.displayLayoutRevision = addon.layoutRevision
			overlay.displayStyleRevision = addon.styleRevision
			addon:ApplyThreatColor(
				overlay,
				overlay.text,
				overlay.colorIsLeader,
				overlay.colorIsPullThresholdWarning,
				overlay.colorIsTank
			)
		end
	end
end

local function RequestNameplateRefresh(unit)
	if not addon.enabled then
		return
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
		return
	end

	record.refreshRequested = true
	refreshRequested = true
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
		RequestNameplateRefresh(unit)
	end
end)

eventFrame:SetScript("OnUpdate", function(_, elapsed)
	if not addon.enabled then
		elapsedSincePoll = 0
		elapsedSinceRefresh = 0
		refreshRequested = false
		refreshAllRequested = false
		return
	end

	elapsedSincePoll = elapsedSincePoll + elapsed
	elapsedSinceRefresh = elapsedSinceRefresh + elapsed

	local dueForPoll = elapsedSincePoll >= POLL_INTERVAL
	local dueForEventRefresh = refreshRequested and elapsedSinceRefresh >= EVENT_REFRESH_DELAY
	if not dueForPoll and not dueForEventRefresh then
		return
	end

	if dueForPoll then
		elapsedSincePoll = 0
		addon:ScanVisibleNameplates()
	end

	elapsedSinceRefresh = 0
	if dueForPoll or refreshAllRequested then
		addon.UpdateAllNameplates()
	else
		UpdateRequestedNameplates()
	end
	refreshRequested = false
	refreshAllRequested = false
end)

RebuildThreatSources()
addon:RefreshPlayerRole()
