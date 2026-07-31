local _, addon = ...

local Role = addon.Role
local View = addon.NameplateView
local GetNameplateUnitToken = View.GetUnitToken
local ReadReferenceVisual = View.ReadReferenceVisual
local ApplyOverlayLayout = View.ApplyOverlayLayout
local ApplyBadgeWidthForRevision = View.ApplyBadgeWidthForRevision
local ApplyOverlayStyle = View.ApplyOverlayStyle
local CreateOverlay = View.CreateOverlay
local DisplayValue = View.DisplayValue

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


local function IsEligibleUnit(unit)
	return UnitExists(unit)
		and UnitCanAttack("player", unit)
		and not UnitIsPlayer(unit)
		and not UnitPlayerControlled(unit)
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


function addon.GetReferenceNameplateVisual()
	local targetPlate = GetNamePlateForUnit("target")
	if targetPlate then
		local overlay = targetPlate.ThreatPlatingOverlay
		if overlay
			and overlay.unit
			and GetNamePlateForUnit(overlay.unit) == targetPlate
		then
			local visual = ReadReferenceVisual(overlay.record)
			if visual then
				return visual
			end
		end
	end

	for unit, record in pairs(activeNameplates) do
		if record.overlay.unit == unit
			and record.nameplate:IsShown()
			and GetNamePlateForUnit(unit) == record.nameplate
		then
			local visual = ReadReferenceVisual(record)
			if visual then
				return visual
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

Role.SetChangedCallback(function()
	QueueAllNameplates("poll")
end)

RebuildThreatSources()
addon:RefreshPlayerRole()
