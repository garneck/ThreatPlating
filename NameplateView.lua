local _, addon = ...

local View = {}
local Threat = addon.Threat
local BACKDROP = addon.BACKDROP
local IsFiniteNumber = addon.IsFiniteNumber
local referenceVisual = {}
local activeValueTransitions = {}
local transitionUpdateElapsed = 0

local VALUE_TRANSITION_DURATION = 0.18
local VALUE_TRANSITION_INTERVAL = 1 / 30

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

local function StopValueTransition(overlay)
	local index = overlay.valueTransitionIndex
	if index then
		local lastIndex = #activeValueTransitions
		local lastOverlay = activeValueTransitions[lastIndex]
		activeValueTransitions[lastIndex] = nil
		if index ~= lastIndex then
			activeValueTransitions[index] = lastOverlay
			lastOverlay.valueTransitionIndex = index
		end
	end

	overlay.valueTransitionIndex = nil
	overlay.transitionFromValue = nil
	overlay.transitionTargetValue = nil
	overlay.transitionIsLeader = nil
	overlay.transitionElapsed = nil
end

local function OnOverlayHide(overlay)
	StopValueTransition(overlay)
	overlay.renderedFromLiveData = false
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
	overlay:SetScript("OnHide", OnOverlayHide)

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

local function SetRenderedValue(overlay, value, isLeader, text)
	text = text or Threat.FormatDelta(value, isLeader)
	if not text then
		return false
	end

	overlay.renderedValue = value
	overlay.renderedIsLeader = isLeader
	if overlay.renderedText ~= text then
		overlay.renderedText = text
		overlay.text:SetText(text)
		-- New text can change the measured string width. Intermediate values follow
		-- the same automatic-width rules as settled values.
		ApplyBadgeWidthForRevision(overlay)
	end
	return true
end

local function StartValueTransition(overlay, targetValue, isLeader)
	if not overlay.valueTransitionIndex then
		local index = #activeValueTransitions + 1
		activeValueTransitions[index] = overlay
		overlay.valueTransitionIndex = index
	end

	overlay.transitionFromValue = overlay.renderedValue
	overlay.transitionTargetValue = targetValue
	overlay.transitionIsLeader = isLeader
	overlay.transitionElapsed = 0
end

local function FinishValueTransition(overlay)
	local targetValue = overlay.transitionTargetValue
	local isLeader = overlay.transitionIsLeader
	local text
	if overlay.targetValue == targetValue
		and overlay.targetIsLeader == isLeader
	then
		text = overlay.targetText
	end

	StopValueTransition(overlay)
	if not SetRenderedValue(overlay, targetValue, isLeader, text) then
		overlay:Hide()
	end
end

local function FinishValueTransitions()
	while #activeValueTransitions > 0 do
		FinishValueTransition(activeValueTransitions[#activeValueTransitions])
	end
	transitionUpdateElapsed = 0
end

local function AdvanceValueTransitions(elapsed)
	if #activeValueTransitions == 0 then
		transitionUpdateElapsed = 0
		return
	end
	if not addon.db.smoothTransitions then
		FinishValueTransitions()
		return
	end
	if not IsFiniteNumber(elapsed) or elapsed <= 0 then
		return
	end

	transitionUpdateElapsed = transitionUpdateElapsed + elapsed
	if transitionUpdateElapsed < VALUE_TRANSITION_INTERVAL then
		return
	end

	local stepElapsed = transitionUpdateElapsed
	transitionUpdateElapsed = 0
	local index = 1
	while index <= #activeValueTransitions do
		local overlay = activeValueTransitions[index]
		if not overlay:IsShown() or overlay.unit == nil then
			StopValueTransition(overlay)
		else
			overlay.transitionElapsed = overlay.transitionElapsed + stepElapsed
			local progress = math.min(
				1,
				overlay.transitionElapsed / VALUE_TRANSITION_DURATION
			)
			if progress >= 1 then
				FinishValueTransition(overlay)
			else
				local remaining = 1 - progress
				local easedProgress = 1 - remaining * remaining * remaining
				local value = overlay.transitionFromValue
					+ (overlay.transitionTargetValue - overlay.transitionFromValue)
						* easedProgress
				SetRenderedValue(overlay, value, overlay.transitionIsLeader)
				index = index + 1
			end
		end
	end
end

local function DisplayValue(record, value, isLeader, safetyState, fromLiveData)
	local overlay = record.overlay
	local targetChanged = overlay.targetValue ~= value
		or overlay.targetIsLeader ~= isLeader
	local text
	if targetChanged then
		text = Threat.FormatDelta(value, isLeader)
		overlay.targetValue = value
		overlay.targetIsLeader = isLeader
		overlay.targetText = text
	else
		text = overlay.targetText
	end

	if not text then
		overlay:Hide()
		return
	end

	local styleChanged = overlay.displayStyleRevision ~= addon.styleRevision
	ApplyOverlayLayout(overlay, record.nameplate)
	ApplyOverlayStyle(overlay)

	local isLiveValue = fromLiveData == true
	local retainTransition = not targetChanged
		and overlay:IsShown()
		and isLiveValue
		and overlay.renderedFromLiveData
		and addon.db.smoothTransitions
	if not retainTransition then
		local canAnimate = isLiveValue
			and addon.db.smoothTransitions
			and overlay:IsShown()
			and overlay.renderedFromLiveData
			and IsFiniteNumber(overlay.renderedValue)
			and overlay.renderedIsLeader == isLeader
			and overlay.renderedValue ~= value
			and overlay.renderedText ~= text

		if canAnimate then
			StartValueTransition(overlay, value, isLeader)
		else
			StopValueTransition(overlay)
			if not SetRenderedValue(overlay, value, isLeader, text) then
				overlay:Hide()
				return
			end
		end
	end
	overlay.renderedFromLiveData = isLiveValue

	if overlay.displayLayoutRevision ~= addon.layoutRevision
		or overlay.displayStyleRevision ~= addon.styleRevision
	then
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

	return referenceVisual
end

View.GetUnitFrame = GetUnitFrame
View.GetUnitToken = GetNameplateUnitToken
View.GetVisualHealthBar = GetVisualHealthBar
View.ApplyOverlayLayout = ApplyOverlayLayout
View.ApplyBadgeWidthForRevision = ApplyBadgeWidthForRevision
View.ApplyOverlayStyle = ApplyOverlayStyle
View.CreateOverlay = CreateOverlay
View.DisplayValue = DisplayValue
View.AdvanceValueTransitions = AdvanceValueTransitions
View.FinishValueTransitions = FinishValueTransitions
View.ReadReferenceVisual = PopulateReferenceVisual

addon.NameplateView = View
