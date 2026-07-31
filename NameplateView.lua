local _, addon = ...

local View = {}
local Threat = addon.Threat
local BACKDROP = addon.BACKDROP
local IsFiniteNumber = addon.IsFiniteNumber
local referenceVisual = {}

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
View.ReadReferenceVisual = PopulateReferenceVisual

addon.NameplateView = View
