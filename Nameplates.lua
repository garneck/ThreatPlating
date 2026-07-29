local _, addon = ...

local POLL_INTERVAL = addon.updateInterval
local EVENT_REFRESH_DELAY = addon.eventRefreshDelay
local BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Buttons\\WHITE8X8",
	edgeSize = 1,
}

local activeNameplates = {}
local threatSources = {}
local EMPTY_THREATS = {}
local elapsedSincePoll = 0
local elapsedSinceRefresh = 0
local refreshRequested = true
local scanRevision = 0
local eventFrame = CreateFrame("Frame")

local function IsEligibleUnit(unit)
	return UnitExists(unit)
		and UnitCanAttack("player", unit)
		and not UnitIsPlayer(unit)
		and not UnitPlayerControlled(unit)
end

local function GetUnitFrame(nameplate)
	return nameplate and (nameplate.UnitFrame or nameplate.unitFrame)
end

local function GetHealthBarAnchor(nameplate)
	local unitFrame = GetUnitFrame(nameplate)
	if unitFrame then
		if unitFrame.HealthBarsContainer then
			return unitFrame.HealthBarsContainer
		end

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

local function ApplyOverlayStyle(overlay)
	if overlay.styleRevision == addon.styleRevision then
		return
	end

	local db = addon.db
	overlay.styleRevision = addon.styleRevision
	overlay:SetHeight(db.badgeHeight)
	overlay.text:SetTextHeight(db.fontSize)

	if db.showBackground then
		overlay:SetBackdropColor(0.025, 0.025, 0.025, 0.90)
	else
		overlay:SetBackdropColor(0, 0, 0, 0)
		overlay:SetBackdropBorderColor(0, 0, 0, 0)
	end
end

local function CreateOverlay(nameplate)
	local overlay = CreateFrame("Frame", nil, nameplate, "BackdropTemplate")
	overlay:SetSize(addon.db.badgeWidth, addon.db.badgeHeight)
	overlay:SetBackdrop(BACKDROP)
	overlay:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)
	overlay:EnableMouse(false)
	overlay:Hide()

	local text = overlay:CreateFontString(nil, "OVERLAY")
	text:SetFontObject("SystemFont_NamePlate_Outlined")
	text:SetTextHeight(addon.db.fontSize)
	text:SetPoint("CENTER", overlay, "CENTER", 0, 0)
	text:SetShadowColor(0, 0, 0, 1)
	text:SetShadowOffset(1, -1)
	overlay.text = text

	ApplyOverlayStyle(overlay)
	ApplyAnchor(overlay, nameplate)

	if not nameplate.ThreatPlatingHideHooked then
		nameplate:HookScript("OnHide", function(hiddenNameplate)
			local hiddenOverlay = hiddenNameplate.ThreatPlatingOverlay
			if hiddenOverlay then
				hiddenOverlay:Hide()
			end
		end)
		nameplate.ThreatPlatingHideHooked = true
	end

	nameplate.ThreatPlatingOverlay = overlay
	return overlay
end

local function DisplayValue(record, value, isLeader)
	local overlay = record.overlay
	local text = addon.Threat.FormatDelta(value, isLeader)
	if not text then
		overlay:Hide()
		return
	end

	ApplyAnchor(overlay, record.nameplate)
	ApplyOverlayStyle(overlay)
	overlay.text:SetText(text)
	if addon.db.autoWidth then
		overlay:SetWidth(math.max(addon.db.badgeWidth, math.ceil(overlay.text:GetStringWidth()) + 14))
	else
		overlay:SetWidth(addon.db.badgeWidth)
	end

	if isLeader then
		overlay.text:SetTextColor(0.35, 1, 0.35, 1)
		if addon.db.showBackground then
			overlay:SetBackdropBorderColor(0.20, 0.75, 0.20, 1)
		end
	else
		overlay.text:SetTextColor(1, 0.32, 0.26, 1)
		if addon.db.showBackground then
			overlay:SetBackdropBorderColor(0.85, 0.18, 0.14, 1)
		end
	end

	overlay:Show()
end

local function ReleaseNameplate(unit, record)
	if not record or activeNameplates[unit] ~= record then
		return
	end

	activeNameplates[unit] = nil
	if record.overlay.unit == unit then
		record.overlay.unit = nil
		record.overlay:Hide()
	end
end

local function QueryThreat(sourceUnit, enemyUnit)
	local ok, isTanking, status, _, rawPercentage, rawThreat =
		pcall(UnitDetailedThreatSituation, sourceUnit, enemyUnit)

	if not ok or type(status) ~= "number" or type(rawThreat) ~= "number" then
		return false, nil, nil
	end

	return isTanking == true, rawPercentage, rawThreat
end

local function AppendThreat(rawThreats, sourceUnit, enemyUnit)
	if not UnitExists(sourceUnit) or UnitIsUnit(sourceUnit, "player") then
		return
	end

	local _, _, rawThreat = QueryThreat(sourceUnit, enemyUnit)
	if rawThreat then
		rawThreats[#rawThreats + 1] = rawThreat
	end
end

local function CollectContenderThreats(enemyUnit)
	local rawThreats = {}
	local enemyTarget = enemyUnit .. "target"
	local targetAlreadyIncluded = false

	for index = 1, #threatSources do
		local sourceUnit = threatSources[index]
		if UnitExists(enemyTarget)
			and UnitExists(sourceUnit)
			and UnitIsUnit(sourceUnit, enemyTarget)
		then
			targetAlreadyIncluded = true
		end
		AppendThreat(rawThreats, sourceUnit, enemyUnit)
	end

	-- This covers an NPC or out-of-group actor currently tanking the enemy.
	if not targetAlreadyIncluded then
		AppendThreat(rawThreats, enemyTarget, enemyUnit)
	end

	return rawThreats
end

local function UpdateNameplate(unit, record)
	if not addon.enabled
		or record.overlay.unit ~= unit
		or not record.nameplate:IsShown()
		or C_NamePlate.GetNamePlateForUnit(unit) ~= record.nameplate
		or not IsEligibleUnit(unit)
	then
		record.overlay:Hide()
		return
	end

	if addon.configPreviewActive or addon.testModeUntil > GetTime() then
		DisplayValue(record, 12300, true)
		return
	end

	local isTanking, rawPercentage, playerRawThreat = QueryThreat("player", unit)
	local contenderRawThreats = EMPTY_THREATS

	if addon.Threat.ShouldScanContenders(playerRawThreat, isTanking, rawPercentage) then
		contenderRawThreats = CollectContenderThreats(unit)
	end

	local delta, isLeader = addon.Threat.CalculateDelta(
		playerRawThreat,
		rawPercentage,
		contenderRawThreats
	)

	if delta == nil then
		record.overlay:Hide()
		return
	end

	DisplayValue(record, delta, isLeader)
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
end

local function AddNameplate(unit)
	if not addon.enabled or not IsEligibleUnit(unit) then
		return
	end

	local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
	if not nameplate then
		return
	end

	local overlay = nameplate.ThreatPlatingOverlay or CreateOverlay(nameplate)
	local existingRecord = activeNameplates[unit]
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
		local previousUnit = overlay.unit
		local previousRecord = activeNameplates[previousUnit]
		if previousRecord and previousRecord.overlay == overlay then
			ReleaseNameplate(previousUnit, previousRecord)
		else
			overlay.unit = nil
			overlay:Hide()
		end
	end

	overlay.unit = unit
	overlay:Hide()

	local record = {
		nameplate = nameplate,
		overlay = overlay,
	}
	activeNameplates[unit] = record
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

	for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
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
		UpdateNameplate(unit, record)
	end
end

function addon.HideAllNameplates()
	for _, record in pairs(activeNameplates) do
		record.overlay:Hide()
	end
end

function addon.GetReferenceHealthBarSize()
	for unit, record in pairs(activeNameplates) do
		if record.overlay.unit == unit
			and record.nameplate:IsShown()
			and C_NamePlate.GetNamePlateForUnit(unit) == record.nameplate
		then
			local anchor = GetHealthBarAnchor(record.nameplate)
			local width = anchor and anchor:GetWidth()
			local height = anchor and anchor:GetHeight()
			if width and height and width > 0 and height > 0 then
				return width, height
			end
		end
	end

	return 128, 20
end

function addon.ApplyDisplaySettings()
	addon.layoutRevision = addon.layoutRevision + 1
	addon.styleRevision = addon.styleRevision + 1

	for _, record in pairs(activeNameplates) do
		ApplyOverlayStyle(record.overlay)
		ApplyAnchor(record.overlay, record.nameplate)
	end

	addon.UpdateAllNameplates()
end

eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
eventFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
eventFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")

eventFrame:SetScript("OnEvent", function(_, event, unit)
	if event == "NAME_PLATE_UNIT_ADDED" then
		AddNameplate(unit)
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		RemoveNameplate(unit)
	elseif event == "GROUP_ROSTER_UPDATE" then
		RebuildThreatSources()
	elseif event == "PLAYER_ENTERING_WORLD" then
		RebuildThreatSources()
		addon:ScanVisibleNameplates()
	else
		refreshRequested = true
	end
end)

eventFrame:SetScript("OnUpdate", function(_, elapsed)
	if not addon.enabled then
		elapsedSincePoll = 0
		elapsedSinceRefresh = 0
		refreshRequested = false
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
	addon.UpdateAllNameplates()
	refreshRequested = false
end)

RebuildThreatSources()
