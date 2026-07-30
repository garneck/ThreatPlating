local _, addon = ...

local db = addon.db
local Clamp = addon.Clamp
local Round = addon.Round
local configWindow
local previewPane
local previewCanvas
local previewBadge
local previewBadgeText
local previewHealthBar
local previewUnitName
local previewHealthText
local previewSourceText
local controlsPane
local scrollFrame
local scrollBar
local scrollChild
local statusText
local settingsEnabledCheck
local settingsStatusText
local sessionSnapshot
local applyingPreview = false
local refreshingControls = false
local pendingChangeKind
local pendingChangeElapsed = 0
local previewIsTank
local previewState = "safe"
local pickerOwner
local sections = {}
local controls = {}
local scenarioButtons = {}

local WIDE_THRESHOLD = 760
local APPLY_INTERVAL = 0.05
local BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Buttons\\WHITE8X8",
	edgeSize = 1,
}
local FONT_OBJECTS = {
	combat = "NumberFontNormal",
	nameplate = "SystemFont_NamePlate_Outlined",
	ui = "GameFontNormal",
}
local ANCHOR_PRESETS = {
	{
		label = "Top left",
		shortLabel = "TL",
		point = "BOTTOMRIGHT",
		relativePoint = "TOPLEFT",
		offsetX = -6,
		offsetY = 6,
	},
	{
		label = "Top",
		shortLabel = "T",
		point = "BOTTOM",
		relativePoint = "TOP",
		offsetX = 0,
		offsetY = 6,
	},
	{
		label = "Top right",
		shortLabel = "TR",
		point = "BOTTOMLEFT",
		relativePoint = "TOPRIGHT",
		offsetX = 6,
		offsetY = 6,
	},
	{
		label = "Left",
		shortLabel = "L",
		point = "RIGHT",
		relativePoint = "LEFT",
		offsetX = -6,
		offsetY = 0,
	},
	{
		label = "Center",
		shortLabel = "C",
		point = "CENTER",
		relativePoint = "CENTER",
		offsetX = 0,
		offsetY = 0,
	},
	{
		label = "Right",
		shortLabel = "R",
		point = "LEFT",
		relativePoint = "RIGHT",
		offsetX = 6,
		offsetY = 0,
	},
	{
		label = "Bottom left",
		shortLabel = "BL",
		point = "TOPRIGHT",
		relativePoint = "BOTTOMLEFT",
		offsetX = -6,
		offsetY = -6,
	},
	{
		label = "Bottom",
		shortLabel = "B",
		point = "TOP",
		relativePoint = "BOTTOM",
		offsetX = 0,
		offsetY = -6,
	},
	{
		label = "Bottom right",
		shortLabel = "BR",
		point = "TOPLEFT",
		relativePoint = "BOTTOMRIGHT",
		offsetX = 6,
		offsetY = -6,
	},
}

local function CreateText(parent, text, fontObject)
	local label = parent:CreateFontString(nil, "OVERLAY")
	label:SetFontObject(fontObject or "GameFontNormal")
	label:SetText(text)
	return label
end

local function ShowTooltip(frame, title, description)
	if not GameTooltip then
		return
	end

	GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
	GameTooltip:SetText(title, 1, 0.82, 0)
	if description and description ~= "" then
		GameTooltip:AddLine(description, 1, 1, 1, true)
	end
	GameTooltip:Show()
end

local function AddTooltip(frame, title, description)
	frame:SetScript("OnEnter", function(self)
		ShowTooltip(self, title, description)
	end)
	frame:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
end

local function CreateButton(parent, text, width, callback, tooltip)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 24)
	button:SetText(text)
	button:SetScript("OnClick", callback)
	if tooltip then
		AddTooltip(button, text, tooltip)
	end
	return button
end

local function SetButtonSelected(button, selected)
	if selected then
		if button.LockHighlight then
			button:LockHighlight()
		end
	else
		if button.UnlockHighlight then
			button:UnlockHighlight()
		end
	end
end

local function SetControlEnabled(control, enabled)
	control.disabled = not enabled
	if control.Enable and control.Disable then
		if enabled then
			control:Enable()
		else
			control:Disable()
		end
	end
	if control.label then
		if enabled then
			control.label:SetTextColor(1, 0.82, 0, 1)
		else
			control.label:SetTextColor(0.50, 0.50, 0.50, 1)
		end
	end
end

local function MergeChangeKind(current, requested)
	if not current then
		return requested
	end
	if current == requested then
		return current
	end
	return "all"
end

local function FlushPendingChange()
	if not pendingChangeKind then
		return
	end

	local changeKind = pendingChangeKind
	pendingChangeKind = nil
	pendingChangeElapsed = 0
	addon.ApplyDisplaySettings(changeKind)
end

local function RefreshControls()
	if refreshingControls then
		return
	end

	refreshingControls = true
	for _, control in ipairs(controls) do
		if control.refresh then
			control:refresh()
		end
	end
	refreshingControls = false
end

local function GetScenario()
	local isTank = previewIsTank
	if isTank == nil then
		isTank = addon.playerIsTank and true or false
	end

	local isLeader
	local isWarning = previewState == "warning"
	if previewState == "safe" then
		isLeader = isTank
	elseif previewState == "danger" then
		isLeader = not isTank
	else
		isLeader = true
	end

	return isTank, isLeader, isWarning
end

function addon.GetConfigPreviewScenario()
	return GetScenario()
end

local function UpdateStatus()
	if statusText then
		local role = addon.playerIsTank and "Tank" or "Non-tank"
		local scenarioRole = GetScenario() and "Tank" or "Non-tank"
		statusText:SetText(string.format(
			"Detected role: %s\nPreview: %s / %s",
			role,
			scenarioRole,
			previewState == "warning" and "Warning"
				or (previewState == "safe" and "Safe" or "Danger")
		))
	end

	if settingsStatusText then
		settingsStatusText:SetText(string.format(
			"Status: %s  •  Detected role: %s",
			addon.enabled and "Enabled" or "Disabled",
			addon.playerIsTank and "Tank" or "Non-tank"
		))
	end
	if settingsEnabledCheck then
		settingsEnabledCheck:SetChecked(addon.enabled)
	end
end

local function ApplyPreviewVisuals()
	if not previewBadge then
		UpdateStatus()
		RefreshControls()
		return
	end

	applyingPreview = true
	local isTank, isLeader, isWarning = GetScenario()
	local sampleText = isLeader and "+12.3k" or "-12.3k"
	previewBadgeText:SetFontObject(FONT_OBJECTS[db.fontPreset] or FONT_OBJECTS.nameplate)
	previewBadgeText:SetTextHeight(db.fontSize)
	previewBadgeText:SetText(sampleText)
	if db.shadow then
		previewBadgeText:SetShadowColor(0, 0, 0, 1)
		previewBadgeText:SetShadowOffset(1, -1)
	else
		previewBadgeText:SetShadowColor(0, 0, 0, 0)
		previewBadgeText:SetShadowOffset(0, 0)
	end

	local visual = addon.GetReferenceNameplateVisual()
	local referenceWidth = visual and visual.width or 128
	local referenceHeight = visual and visual.height or 20
	referenceWidth = Clamp(referenceWidth, 60, 260)
	referenceHeight = Clamp(referenceHeight, 8, 60)
	previewHealthBar:SetSize(referenceWidth, referenceHeight)
	previewHealthBar:SetStatusBarTexture(
		visual and visual.texture or "Interface\\TargetingFrame\\UI-StatusBar"
	)
	previewHealthBar:SetStatusBarColor(
		visual and visual.red or 0.72,
		visual and visual.green or 0.12,
		visual and visual.blue or 0.10,
		visual and visual.alpha or 1
	)
	previewHealthBar:SetMinMaxValues(0, 1)
	previewHealthBar:SetValue(visual and visual.fill or 0.70)

	previewUnitName:ClearAllPoints()
	previewUnitName:SetText(visual and visual.nameText or "Enemy Nameplate")
	if visual and visual.nameFontPath then
		previewUnitName:SetFont(
			visual.nameFontPath,
			Clamp(visual.nameFontSize or 12, 6, 32),
			visual.nameFontFlags or ""
		)
	else
		previewUnitName:SetFontObject("SystemFont_NamePlate_Outlined")
	end
	if visual and visual.nameOffsetX and visual.nameOffsetY then
		previewUnitName:SetPoint(
			"CENTER",
			previewHealthBar,
			"CENTER",
			Clamp(visual.nameOffsetX, -260, 260),
			Clamp(visual.nameOffsetY, -80, 80)
		)
	else
		previewUnitName:SetPoint("BOTTOM", previewHealthBar, "TOP", 0, 3)
	end
	previewUnitName:SetTextColor(
		visual and visual.nameRed or 1,
		visual and visual.nameGreen or 0.82,
		visual and visual.nameBlue or 0.20,
		visual and visual.nameAlpha or 1
	)

	previewHealthText:ClearAllPoints()
	previewHealthText:SetText(visual and visual.healthText or "72%")
	if visual and visual.healthFontPath then
		previewHealthText:SetFont(
			visual.healthFontPath,
			Clamp(visual.healthFontSize or 12, 6, 32),
			visual.healthFontFlags or ""
		)
	else
		previewHealthText:SetFontObject("SystemFont_NamePlate_Outlined")
	end
	if visual and visual.healthOffsetX and visual.healthOffsetY then
		previewHealthText:SetPoint(
			"CENTER",
			previewHealthBar,
			"CENTER",
			Clamp(visual.healthOffsetX, -260, 260),
			Clamp(visual.healthOffsetY, -80, 80)
		)
	else
		previewHealthText:SetPoint("CENTER", previewHealthBar, "CENTER", 0, 0)
	end
	previewHealthText:SetTextColor(
		visual and visual.healthRed or 1,
		visual and visual.healthGreen or 1,
		visual and visual.healthBlue or 1,
		visual and visual.healthAlpha or 1
	)
	previewSourceText:SetText(
		visual and "Current visible nameplate baseline"
			or "Default 128 × 20 nameplate baseline"
	)

	local width = db.badgeWidth
	if db.autoWidth then
		width = math.max(
			width,
			math.ceil(previewBadgeText:GetStringWidth()) + db.padding * 2
		)
	end
	previewBadge:SetSize(width, db.badgeHeight)
	previewBadge:SetBackdropColor(
		db.backgroundColor[1],
		db.backgroundColor[2],
		db.backgroundColor[3],
		db.backgroundColor[4]
	)
	addon:ApplyThreatColor(previewBadge, previewBadgeText, isLeader, isWarning, isTank)

	previewBadge:ClearAllPoints()
	previewBadge:SetPoint(
		db.anchorPoint,
		previewHealthBar,
		db.relativePoint,
		db.offsetX,
		db.offsetY
	)

	for key, button in pairs(scenarioButtons) do
		local selected = key == (isTank and "tank" or "nonTank")
			or key == previewState
		SetButtonSelected(button, selected)
	end

	UpdateStatus()
	RefreshControls()
	applyingPreview = false
end

local function QueueDisplayChange(changeKind, immediate)
	ApplyPreviewVisuals()
	pendingChangeKind = MergeChangeKind(pendingChangeKind, changeKind)
	if immediate then
		FlushPendingChange()
	end
end

addon.RefreshConfig = ApplyPreviewVisuals

local function SetScenario(isTank, state)
	if isTank ~= nil then
		previewIsTank = isTank and true or false
	end
	if state then
		previewState = state
	end
	ApplyPreviewVisuals()
	if addon.configPreviewActive then
		addon.UpdateAllNameplates()
	end
end

local function GetPointCoordinates(frame, point)
	local centerX, centerY = frame:GetCenter()
	if not centerX or not centerY then
		return nil, nil
	end

	local x = centerX
	local y = centerY
	if point:find("LEFT", 1, true) then
		x = frame:GetLeft()
	elseif point:find("RIGHT", 1, true) then
		x = frame:GetRight()
	end
	if point:find("TOP", 1, true) then
		y = frame:GetTop()
	elseif point:find("BOTTOM", 1, true) then
		y = frame:GetBottom()
	end
	return x, y
end

local function UseAnchorPreset(index)
	local preset = ANCHOR_PRESETS[index]
	if not preset then
		return
	end

	db.anchorPoint = preset.point
	db.relativePoint = preset.relativePoint
	db.offsetX = preset.offsetX
	db.offsetY = preset.offsetY
	QueueDisplayChange("layout", true)
end

local function CommitDraggedPosition()
	if not previewBadge or not previewHealthBar then
		return
	end

	local nearestPreset
	local nearestOffsetX
	local nearestOffsetY
	local nearestDistance
	for _, preset in ipairs(ANCHOR_PRESETS) do
		local badgeX, badgeY = GetPointCoordinates(previewBadge, preset.point)
		local barX, barY = GetPointCoordinates(previewHealthBar, preset.relativePoint)
		if badgeX and barX then
			local offsetX = badgeX - barX
			local offsetY = badgeY - barY
			local distance = offsetX * offsetX + offsetY * offsetY
			if not nearestDistance or distance < nearestDistance then
				nearestPreset = preset
				nearestOffsetX = offsetX
				nearestOffsetY = offsetY
				nearestDistance = distance
			end
		end
	end

	if not nearestPreset then
		ApplyPreviewVisuals()
		return
	end

	db.anchorPoint = nearestPreset.point
	db.relativePoint = nearestPreset.relativePoint
	db.offsetX = Clamp(Round(nearestOffsetX), -300, 300)
	db.offsetY = Clamp(Round(nearestOffsetY), -300, 300)
	QueueDisplayChange("layout", true)
end

local function StopPreviewResize()
	if not previewBadge or not previewBadge.resizing then
		return
	end

	previewBadge:StopMovingOrSizing()
	previewBadge.resizing = false
	db.badgeWidth = Clamp(Round(previewBadge:GetWidth()), 36, 160)
	db.badgeHeight = Clamp(Round(previewBadge:GetHeight()), 14, 64)
	QueueDisplayChange("layout", true)
end

local function EndOwnedColorPicker()
	if not pickerOwner or not ColorPickerFrame then
		pickerOwner = nil
		return
	end

	local owner = pickerOwner
	pickerOwner = nil
	local activeOwner = ColorPickerFrame.GetExtraInfo
		and ColorPickerFrame:GetExtraInfo()
		or ColorPickerFrame.extraInfo
	if activeOwner ~= owner then
		return
	end

	ColorPickerFrame.swatchFunc = nil
	ColorPickerFrame.opacityFunc = nil
	ColorPickerFrame.cancelFunc = nil
	ColorPickerFrame.hasOpacity = false
	ColorPickerFrame.extraInfo = nil
	if ColorPickerFrame:IsShown() then
		ColorPickerFrame:Hide()
	end
end

local function OpenColorPicker(key, hasAlpha)
	if not ColorPickerFrame then
		return
	end

	EndOwnedColorPicker()
	local color = db[key]
	local original = addon.CopyValue(color)
	local owner = {
		key = key,
		hasAlpha = hasAlpha,
		opening = true,
		original = original,
	}
	pickerOwner = owner

	local function ApplyColor()
		if pickerOwner ~= owner then
			return
		end
		if owner.opening then
			return
		end
		local red, green, blue = ColorPickerFrame:GetColorRGB()
		color[1] = Clamp(red, 0, 1)
		color[2] = Clamp(green, 0, 1)
		color[3] = Clamp(blue, 0, 1)
		if hasAlpha and ColorPickerFrame.GetColorAlpha then
			color[4] = Clamp(ColorPickerFrame:GetColorAlpha(), 0, 1)
		end
		QueueDisplayChange("style", not ColorPickerFrame:IsShown())
	end

	local function CancelColor()
		if pickerOwner ~= owner then
			return
		end
		db[key] = addon.CopyValue(original)
		color = db[key]
		pickerOwner = nil
		ColorPickerFrame.swatchFunc = nil
		ColorPickerFrame.opacityFunc = nil
		ColorPickerFrame.cancelFunc = nil
		ColorPickerFrame.extraInfo = nil
		QueueDisplayChange("style", true)
	end

	ColorPickerFrame:SetupColorPickerAndShow({
		b = color[3],
		cancelFunc = CancelColor,
		extraInfo = owner,
		g = color[2],
		hasOpacity = hasAlpha and true or false,
		opacity = hasAlpha and color[4] or 1,
		opacityFunc = ApplyColor,
		r = color[1],
		swatchFunc = ApplyColor,
	})
	owner.opening = false
end

local function CreatePreview(parent)
	local pane = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	pane:SetBackdrop(BACKDROP)
	pane:SetBackdropColor(0.025, 0.035, 0.050, 0.98)
	pane:SetBackdropBorderColor(0.18, 0.26, 0.34, 1)
	previewPane = pane

	local heading = CreateText(pane, "Live preview", "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", pane, "TOPLEFT", 12, -10)

	local tankButton = CreateButton(pane, "Tank", 66, function()
		SetScenario(true)
	end, "Preview the fixed tank color semantics.")
	tankButton:SetPoint("TOPLEFT", pane, "TOPLEFT", 12, -35)
	scenarioButtons.tank = tankButton

	local nonTankButton = CreateButton(pane, "Non-tank", 82, function()
		SetScenario(false)
	end, "Preview the fixed non-tank color semantics.")
	nonTankButton:SetPoint("LEFT", tankButton, "RIGHT", 4, 0)
	scenarioButtons.nonTank = nonTankButton

	local safeButton = CreateButton(pane, "Safe", 58, function()
		SetScenario(nil, "safe")
	end, "Show the role-appropriate safe threat state.")
	safeButton:SetPoint("TOPLEFT", pane, "TOPLEFT", 12, -62)
	scenarioButtons.safe = safeButton

	local dangerButton = CreateButton(pane, "Danger", 66, function()
		SetScenario(nil, "danger")
	end, "Show the role-appropriate dangerous threat state.")
	dangerButton:SetPoint("LEFT", safeButton, "RIGHT", 4, 0)
	scenarioButtons.danger = dangerButton

	local warningButton = CreateButton(pane, "Warning", 72, function()
		SetScenario(nil, "warning")
	end, "Show the orange pull-threshold warning.")
	warningButton:SetPoint("LEFT", dangerButton, "RIGHT", 4, 0)
	scenarioButtons.warning = warningButton

	local canvas = CreateFrame("Frame", nil, pane, "BackdropTemplate")
	canvas:SetPoint("TOPLEFT", pane, "TOPLEFT", 10, -94)
	canvas:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -10, 10)
	canvas:SetBackdrop(BACKDROP)
	canvas:SetBackdropColor(0.008, 0.012, 0.020, 1)
	canvas:SetBackdropBorderColor(0.12, 0.18, 0.25, 1)
	canvas:SetClipsChildren(true)
	previewCanvas = canvas

	local instructions = CreateText(
		canvas,
		"Drag to place • lower-right grip resizes",
		"GameFontHighlightSmall"
	)
	instructions:SetPoint("TOP", canvas, "TOP", 0, -9)
	instructions:SetTextColor(0.70, 0.78, 0.86, 1)

	local horizontalGuide = canvas:CreateTexture(nil, "BACKGROUND")
	horizontalGuide:SetColorTexture(0.20, 0.45, 0.60, 0.12)
	horizontalGuide:SetHeight(1)
	horizontalGuide:SetPoint("LEFT", canvas, "LEFT", 16, 0)
	horizontalGuide:SetPoint("RIGHT", canvas, "RIGHT", -16, 0)

	local verticalGuide = canvas:CreateTexture(nil, "BACKGROUND")
	verticalGuide:SetColorTexture(0.20, 0.45, 0.60, 0.12)
	verticalGuide:SetWidth(1)
	verticalGuide:SetPoint("TOP", canvas, "TOP", 0, -30)
	verticalGuide:SetPoint("BOTTOM", canvas, "BOTTOM", 0, 14)

	local healthBar = CreateFrame("StatusBar", nil, canvas, "BackdropTemplate")
	healthBar:SetSize(128, 20)
	healthBar:SetPoint("CENTER", canvas, "CENTER", 0, -2)
	healthBar:SetBackdrop(BACKDROP)
	healthBar:SetBackdropColor(0.08, 0.08, 0.08, 1)
	healthBar:SetBackdropBorderColor(0, 0, 0, 1)
	healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	healthBar:SetStatusBarColor(0.72, 0.12, 0.10, 1)
	healthBar:SetMinMaxValues(0, 1)
	healthBar:SetValue(0.70)
	previewHealthBar = healthBar

	local unitName = CreateText(healthBar, "Enemy Nameplate", "SystemFont_NamePlate_Outlined")
	unitName:SetPoint("BOTTOM", healthBar, "TOP", 0, 3)
	unitName:SetTextColor(1, 0.82, 0.20, 1)
	previewUnitName = unitName

	local healthText = CreateText(healthBar, "72%", "SystemFont_NamePlate_Outlined")
	healthText:SetPoint("CENTER", healthBar, "CENTER", 0, 0)
	healthText:SetTextColor(1, 1, 1, 1)
	previewHealthText = healthText

	local sourceText = CreateText(canvas, "", "GameFontDisableSmall")
	sourceText:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", 8, 6)
	previewSourceText = sourceText

	local badge = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
	badge:SetBackdrop(BACKDROP)
	badge:SetMovable(true)
	badge:SetResizable(true)
	badge:SetResizeBounds(36, 14, 160, 64)
	badge:EnableMouse(true)
	badge:RegisterForDrag("LeftButton")
	previewBadge = badge

	local badgeText = CreateText(badge, "+12.3k", "SystemFont_NamePlate_Outlined")
	badgeText:SetPoint("CENTER", badge, "CENTER", 0, 0)
	previewBadgeText = badgeText

	badge:SetScript("OnDragStart", function(self)
		self.dragging = true
		self:StartMoving()
	end)
	badge:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self.dragging = false
		CommitDraggedPosition()
	end)
	badge:SetScript("OnSizeChanged", function(_, width, height)
		if applyingPreview or not badge.resizing then
			return
		end
		db.badgeWidth = Clamp(Round(width), 36, 160)
		db.badgeHeight = Clamp(Round(height), 14, 64)
		QueueDisplayChange("layout", false)
	end)

	local badgeGrip = CreateFrame("Button", nil, badge)
	badgeGrip:SetSize(15, 15)
	badgeGrip:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", -1, 1)
	local badgeGripTexture = badgeGrip:CreateTexture(nil, "OVERLAY")
	badgeGripTexture:SetAllPoints(badgeGrip)
	badgeGripTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	badgeGripTexture:SetVertexColor(0.65, 1, 0.65, 0.9)
	badgeGrip:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then
			badge.resizing = true
			badge:StartSizing("BOTTOMRIGHT")
		end
	end)
	badgeGrip:SetScript("OnMouseUp", StopPreviewResize)
	badge:SetScript("OnMouseUp", StopPreviewResize)
	AddTooltip(
		badgeGrip,
		"Resize badge",
		"Changes minimum width and height only. Font size remains independent."
	)

	return pane
end

local function CreateSection(parent, key, title)
	local section = {
		key = key,
		rows = {},
	}
	local header = CreateFrame("Button", nil, parent, "BackdropTemplate")
	header:SetHeight(30)
	header:SetBackdrop(BACKDROP)
	header:SetBackdropColor(0.06, 0.09, 0.13, 1)
	header:SetBackdropBorderColor(0.16, 0.22, 0.30, 1)
	section.header = header

	local titleText = CreateText(header, title, "GameFontNormal")
	titleText:SetPoint("LEFT", header, "LEFT", 10, 0)
	section.title = titleText

	local collapseText = CreateText(header, "-", "GameFontNormalLarge")
	collapseText:SetPoint("RIGHT", header, "RIGHT", -10, 0)
	section.collapseText = collapseText

	local content = CreateFrame("Frame", nil, parent)
	section.content = content
	header:SetScript("OnClick", function()
		db.collapsedSections[key] = not db.collapsedSections[key]
		if configWindow and configWindow.LayoutControls then
			configWindow:LayoutControls()
		end
	end)
	AddTooltip(header, title, "Click to collapse or expand this section.")
	sections[#sections + 1] = section
	return section
end

local function CreateRow(section, height)
	local row = CreateFrame("Frame", nil, section.content)
	row:SetHeight(height or 44)
	row.requestedHeight = height or 44
	section.rows[#section.rows + 1] = row
	return row
end

local function CreateCheckRow(section, labelText, tooltip, getter, setter)
	local row = CreateRow(section, 36)
	local hitTarget = CreateFrame("Button", nil, row)
	hitTarget:SetAllPoints(row)
	local check = CreateFrame("CheckButton", nil, hitTarget, "UICheckButtonTemplate")
	check:SetSize(26, 26)
	check:SetPoint("LEFT", hitTarget, "LEFT", 4, 0)
	local label = CreateText(hitTarget, labelText, "GameFontHighlight")
	label:SetPoint("LEFT", check, "RIGHT", 3, 1)
	hitTarget.label = label
	check.label = label

	local function Toggle()
		if hitTarget.disabled then
			return
		end
		setter(not getter())
	end
	hitTarget:SetScript("OnClick", Toggle)
	check:SetScript("OnClick", function(self)
		if hitTarget.disabled then
			self:SetChecked(getter())
			return
		end
		setter(self:GetChecked() == true)
	end)
	AddTooltip(hitTarget, labelText, tooltip)
	AddTooltip(check, labelText, tooltip)

	local control = {
		frame = hitTarget,
		check = check,
		label = label,
	}
	function control:refresh()
		self.check:SetChecked(getter())
	end
	controls[#controls + 1] = control
	return control
end

local function CreateInfoRow(section)
	local row = CreateRow(section, 48)
	local label = CreateText(row, "", "GameFontHighlightSmall")
	label:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -6)
	label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	label:SetJustifyH("LEFT")
	statusText = label
	return row
end

local function NormalizeSliderValue(value, minimum, maximum, step)
	value = Clamp(value, minimum, maximum)
	if step >= 1 then
		value = Round(value / step) * step
	else
		value = math.floor(value / step + 0.5) * step
	end
	return Clamp(value, minimum, maximum)
end

local function CreateSliderRow(
	section,
	labelText,
	tooltip,
	minimum,
	maximum,
	step,
	getter,
	setter,
	changeKind
)
	local row = CreateRow(section, 58)
	local label = CreateText(row, labelText, "GameFontNormal")
	label:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
	row.label = label

	local range = CreateText(
		row,
		string.format("%g–%g", minimum, maximum),
		"GameFontDisableSmall"
	)
	range:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -6)

	local slider = CreateFrame("Slider", nil, row, "UISliderTemplate")
	row.slider = slider
	slider:SetHeight(16)
	slider:SetMinMaxValues(minimum, maximum)
	slider:SetValueStep(step)
	if slider.SetObeyStepOnDrag then
		slider:SetObeyStepOnDrag(true)
	end
	slider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 7)
	AddTooltip(slider, labelText, tooltip)

	local edit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
	edit:SetSize(58, 24)
	edit:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 2)
	edit:SetAutoFocus(false)
	edit:SetNumeric(false)
	edit:SetMaxLetters(8)
	edit:SetJustifyH("CENTER")
	AddTooltip(edit, labelText, tooltip .. " Press Enter to apply an exact value.")

	local function FormatValue(value)
		if step < 1 then
			return string.format("%.2f", value)
		end
		return tostring(Round(value))
	end

	slider:SetScript("OnValueChanged", function(_, value)
		if refreshingControls then
			return
		end
		value = NormalizeSliderValue(value, minimum, maximum, step)
		setter(value)
		edit:SetText(FormatValue(value))
		QueueDisplayChange(changeKind, false)
	end)
	slider:SetScript("OnMouseUp", function()
		if not refreshingControls then
			FlushPendingChange()
		end
	end)

	local function RestoreEdit()
		edit:SetText(FormatValue(getter()))
	end

	edit:SetScript("OnEnterPressed", function(self)
		local value = tonumber(self:GetText())
		if not value or value ~= value or value == math.huge or value == -math.huge then
			RestoreEdit()
			self:ClearFocus()
			return
		end
		value = NormalizeSliderValue(value, minimum, maximum, step)
		setter(value)
		self:SetText(FormatValue(value))
		slider:SetValue(value)
		self:ClearFocus()
		QueueDisplayChange(changeKind, true)
	end)
	edit:SetScript("OnEscapePressed", function(self)
		RestoreEdit()
		self:ClearFocus()
	end)

	local control = {
		edit = edit,
		frame = row,
		label = label,
		slider = slider,
	}
	function control:refresh()
		local value = getter()
		self.slider:SetValue(value)
		self.edit:SetText(FormatValue(value))
	end
	controls[#controls + 1] = control
	return control
end

local function CreateChoiceRow(
	section,
	labelText,
	tooltip,
	choices,
	getter,
	setter,
	changeKind,
	height
)
	local row = CreateRow(section, height or 58)
	local label = CreateText(row, labelText, "GameFontNormal")
	label:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
	row.label = label
	row.choiceButtons = {}
	row.choiceCount = #choices
	row.twoLines = height and height > 60

	for index, choice in ipairs(choices) do
		local choiceLabel = choice.label
		local choiceValue = choice.value
		local button = CreateButton(row, choiceLabel, 90, function()
			setter(choiceValue)
			QueueDisplayChange(changeKind, true)
		end, tooltip)
		row.choiceButtons[index] = button
	end

	local control = {
		buttons = row.choiceButtons,
		choices = choices,
		frame = row,
		label = label,
	}
	function control:refresh()
		local value = getter()
		for index, choice in ipairs(self.choices) do
			SetButtonSelected(self.buttons[index], value == choice.value)
		end
	end
	controls[#controls + 1] = control
	return control
end

local function CreateColorRow(section, labelText, tooltip, key, hasAlpha, enabledWhen)
	local row = CreateRow(section, 38)
	local label = CreateText(row, labelText, "GameFontHighlight")
	label:SetPoint("LEFT", row, "LEFT", 8, 0)

	local swatch = CreateFrame("Button", nil, row, "BackdropTemplate")
	swatch:SetSize(58, 24)
	swatch:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	swatch:SetBackdrop(BACKDROP)
	local swatchFill = swatch:CreateTexture(nil, "ARTWORK")
	swatchFill:SetPoint("TOPLEFT", swatch, "TOPLEFT", 3, -3)
	swatchFill:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -3, 3)
	swatch.fill = swatchFill
	swatch.label = label
	swatch:SetScript("OnClick", function()
		if not swatch.disabled then
			OpenColorPicker(key, hasAlpha)
		end
	end)
	AddTooltip(swatch, labelText, tooltip)

	local control = {
		frame = swatch,
		label = label,
	}
	function control:refresh()
		local color = db[key]
		self.frame.fill:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
		SetControlEnabled(self.frame, not enabledWhen or enabledWhen())
	end
	controls[#controls + 1] = control
	return control
end

local function CreateAnchorGrid(section)
	local row = CreateRow(section, 112)
	local label = CreateText(row, "Anchor preset", "GameFontNormal")
	label:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
	row.anchorButtons = {}

	for index, preset in ipairs(ANCHOR_PRESETS) do
		local presetIndex = index
		local button = CreateButton(row, preset.shortLabel, 44, function()
			UseAnchorPreset(presetIndex)
		end, preset.label .. " of the health bar.")
		row.anchorButtons[index] = button
	end

	local control = {
		buttons = row.anchorButtons,
		frame = row,
		label = label,
	}
	function control:refresh()
		for index, preset in ipairs(ANCHOR_PRESETS) do
			SetButtonSelected(
				self.buttons[index],
				db.anchorPoint == preset.point and db.relativePoint == preset.relativePoint
			)
		end
	end
	controls[#controls + 1] = control
	return control
end

local function CreateControls(parent)
	local pane = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	pane:SetBackdrop(BACKDROP)
	pane:SetBackdropColor(0.025, 0.035, 0.050, 0.98)
	pane:SetBackdropBorderColor(0.18, 0.26, 0.34, 1)
	controlsPane = pane

	local heading = CreateText(pane, "Badge settings", "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", pane, "TOPLEFT", 12, -10)

	local scroll = CreateFrame("ScrollFrame", nil, pane)
	scroll:SetPoint("TOPLEFT", pane, "TOPLEFT", 8, -36)
	scroll:EnableMouseWheel(true)
	scrollFrame = scroll

	local bar = CreateFrame("Slider", nil, pane, "BackdropTemplate")
	bar:SetOrientation("VERTICAL")
	bar:SetMinMaxValues(0, 0)
	bar:SetValueStep(24)
	bar:SetBackdrop(BACKDROP)
	bar:SetBackdropColor(0.02, 0.03, 0.04, 1)
	bar:SetBackdropBorderColor(0.18, 0.26, 0.34, 1)
	bar:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Vertical")
	bar:SetScript("OnValueChanged", function(_, value)
		scroll:SetVerticalScroll(value)
	end)
	scrollBar = bar

	scroll:SetScript("OnScrollRangeChanged", function(_, _, verticalRange)
		verticalRange = math.max(0, verticalRange or 0)
		bar:SetMinMaxValues(0, verticalRange)
		if verticalRange > 0 then
			bar:Show()
		else
			bar:Hide()
		end
		if scroll:GetVerticalScroll() > verticalRange then
			bar:SetValue(verticalRange)
		end
	end)
	scroll:SetScript("OnMouseWheel", function(_, delta)
		local maximum = scroll:GetVerticalScrollRange()
		local value = Clamp(scroll:GetVerticalScroll() - delta * 48, 0, maximum)
		bar:SetValue(value)
	end)

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(360, 1000)
	scroll:SetScrollChild(child)
	scrollChild = child

	local general = CreateSection(child, "general", "General")
	CreateCheckRow(
		general,
		"Enable threat counters",
		"Synchronizes the addon’s enabled state everywhere.",
		function()
			return addon.enabled
		end,
		function(checked)
			addon:SetEnabled(checked)
			ApplyPreviewVisuals()
		end
	)
	CreateInfoRow(general)

	local position = CreateSection(child, "position", "Position & Size")
	CreateAnchorGrid(position)
	CreateSliderRow(
		position,
		"Horizontal offset",
		"Exact horizontal distance from the selected health-bar anchor.",
		-300,
		300,
		1,
		function()
			return db.offsetX
		end,
		function(value)
			db.offsetX = value
		end,
		"layout"
	)
	CreateSliderRow(
		position,
		"Vertical offset",
		"Exact vertical distance from the selected health-bar anchor.",
		-300,
		300,
		1,
		function()
			return db.offsetY
		end,
		function(value)
			db.offsetY = value
		end,
		"layout"
	)
	CreateSliderRow(
		position,
		"Minimum width",
		"The badge never becomes narrower than this value.",
		36,
		160,
		1,
		function()
			return db.badgeWidth
		end,
		function(value)
			db.badgeWidth = value
		end,
		"layout"
	)
	CreateSliderRow(
		position,
		"Height",
		"Badge height. This does not change the font size.",
		14,
		64,
		1,
		function()
			return db.badgeHeight
		end,
		function(value)
			db.badgeHeight = value
		end,
		"layout"
	)
	CreateCheckRow(
		position,
		"Expand width for long values",
		"Allow formatted counters to grow beyond the minimum width.",
		function()
			return db.autoWidth
		end,
		function(checked)
			db.autoWidth = checked
			QueueDisplayChange("layout", true)
		end
	)
	CreateSliderRow(
		position,
		"Horizontal padding",
		"Space added to both sides of automatically sized text.",
		0,
		32,
		1,
		function()
			return db.padding
		end,
		function(value)
			db.padding = value
		end,
		"layout"
	)

	local typography = CreateSection(child, "typography", "Typography")
	CreateSliderRow(
		typography,
		"Font size",
		"Text size, independent of badge height.",
		8,
		32,
		1,
		function()
			return db.fontSize
		end,
		function(value)
			db.fontSize = value
		end,
		"style"
	)
	CreateChoiceRow(
		typography,
		"Blizzard font preset",
		"Use a stock Blizzard font object; no fonts are bundled.",
		{
			{ label = "Nameplate", value = "nameplate" },
			{ label = "UI", value = "ui" },
			{ label = "Combat", value = "combat" },
		},
		function()
			return db.fontPreset
		end,
		function(value)
			db.fontPreset = value
		end,
		"style"
	)
	CreateCheckRow(
		typography,
		"Text shadow",
		"Draw the stock one-pixel text shadow.",
		function()
			return db.shadow
		end,
		function(checked)
			db.shadow = checked
			QueueDisplayChange("style", true)
		end
	)

	local appearance = CreateSection(child, "appearance", "Appearance")
	CreateColorRow(
		appearance,
		"Background color",
		"Choose the badge background color.",
		"backgroundColor",
		true
	)
	CreateSliderRow(
		appearance,
		"Background opacity",
		"Set zero for a fully transparent background.",
		0,
		1,
		0.05,
		function()
			return db.backgroundColor[4]
		end,
		function(value)
			db.backgroundColor[4] = value
		end,
		"style"
	)
	CreateChoiceRow(
		appearance,
		"Border mode",
		"Semantic follows the threat color; custom uses one fixed color.",
		{
			{ label = "Semantic", value = "semantic" },
			{ label = "Custom", value = "custom" },
			{ label = "Off", value = "off" },
		},
		function()
			return db.borderMode
		end,
		function(value)
			db.borderMode = value
		end,
		"style"
	)
	CreateColorRow(
		appearance,
		"Custom border",
		"Choose the fixed custom border color and opacity.",
		"borderColor",
		true,
		function()
			return db.borderMode == "custom"
		end
	)

	local colors = CreateSection(child, "colors", "Threat Colors")
	CreateChoiceRow(
		colors,
		"Palette",
		"Palette changes presentation only; safe, danger, and warning meanings stay fixed.",
		{
			{ label = "Default", value = "default" },
			{ label = "Blue / Verm.", value = "blue" },
			{ label = "Cyan / Mag.", value = "cyan" },
			{ label = "Custom", value = "custom" },
		},
		function()
			return db.palette
		end,
		function(value)
			db.palette = value
		end,
		"style",
		86
	)
	CreateColorRow(
		colors,
		"Custom safe",
		"Color for the role-appropriate safe state.",
		"safeColor",
		false,
		function()
			return db.palette == "custom"
		end
	)
	CreateColorRow(
		colors,
		"Custom danger",
		"Color for the role-appropriate dangerous state.",
		"dangerColor",
		false,
		function()
			return db.palette == "custom"
		end
	)
	CreateColorRow(
		colors,
		"Custom warning",
		"Role-independent pull-threshold warning color.",
		"warningColor",
		false,
		function()
			return db.palette == "custom"
		end
	)

	return pane
end

local function LayoutChoiceRow(row, width)
	local count = row.choiceCount
	local columns = row.twoLines and 2 or count
	local available = width - 16 - (columns - 1) * 4
	local buttonWidth = math.floor(available / columns)
	for index, button in ipairs(row.choiceButtons) do
		button:ClearAllPoints()
		button:SetSize(buttonWidth, 24)
		local column = (index - 1) % columns
		local line = math.floor((index - 1) / columns)
		button:SetPoint("TOPLEFT", row, "TOPLEFT", 8 + column * (buttonWidth + 4), -25 - line * 27)
	end
end

local function LayoutAnchorGrid(row, width)
	local buttonWidth = math.floor((width - 24) / 3)
	for index, button in ipairs(row.anchorButtons) do
		button:ClearAllPoints()
		button:SetSize(buttonWidth, 24)
		local column = (index - 1) % 3
		local line = math.floor((index - 1) / 3)
		button:SetPoint(
			"TOPLEFT",
			row,
			"TOPLEFT",
			8 + column * (buttonWidth + 4),
			-25 - line * 27
		)
	end
end

local function LayoutControls(childWidth)
	if not scrollChild then
		return
	end

	childWidth = math.max(240, childWidth)
	scrollChild:SetWidth(childWidth)
	local y = 0
	for _, section in ipairs(sections) do
		section.header:ClearAllPoints()
		section.header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
		section.header:SetWidth(childWidth)
		y = y + 34

		local collapsed = db.collapsedSections[section.key]
		section.collapseText:SetText(collapsed and "+" or "-")
		if collapsed then
			section.content:Hide()
		else
			section.content:Show()
			section.content:ClearAllPoints()
			section.content:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
			section.content:SetWidth(childWidth)
			local rowY = 0
			for _, row in ipairs(section.rows) do
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", section.content, "TOPLEFT", 0, -rowY)
				row:SetWidth(childWidth)
				if row.slider then
					row.slider:SetWidth(math.max(100, childWidth - 92))
				end
				if row.choiceButtons then
					LayoutChoiceRow(row, childWidth)
				end
				if row.anchorButtons then
					LayoutAnchorGrid(row, childWidth)
				end
				rowY = rowY + row.requestedHeight
			end
			section.content:SetHeight(rowY)
			y = y + rowY + 4
		end
	end
	scrollChild:SetHeight(math.max(y, 1))
end

local function SaveWindowPosition(window)
	local windowX, windowY = window:GetCenter()
	local parentX, parentY = UIParent:GetCenter()
	if windowX and parentX then
		db.windowOffsetX = Round(windowX - parentX)
		db.windowOffsetY = Round(windowY - parentY)
	end
end

local function ReflowWindow(window)
	local width = window:GetWidth()
	local height = window:GetHeight()
	local bodyWidth = width - 24
	local bodyHeight = height - 112
	local wide = width >= WIDE_THRESHOLD

	previewPane:ClearAllPoints()
	controlsPane:ClearAllPoints()
	if wide then
		local previewWidth = math.min(390, math.floor(bodyWidth * 0.43))
		local controlsWidth = bodyWidth - previewWidth - 10
		previewPane:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -52)
		previewPane:SetSize(previewWidth, bodyHeight)
		controlsPane:SetPoint("TOPLEFT", previewPane, "TOPRIGHT", 10, 0)
		controlsPane:SetSize(controlsWidth, bodyHeight)
		window.layoutMode = "wide"
		LayoutControls(controlsWidth - 40)
	else
		local previewHeight = math.min(230, math.floor(bodyHeight * 0.47))
		local controlsHeight = bodyHeight - previewHeight - 10
		previewPane:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -52)
		previewPane:SetSize(bodyWidth, previewHeight)
		controlsPane:SetPoint("TOPLEFT", previewPane, "BOTTOMLEFT", 0, -10)
		controlsPane:SetSize(bodyWidth, controlsHeight)
		window.layoutMode = "narrow"
		LayoutControls(bodyWidth - 40)
	end

	scrollFrame:SetSize(
		math.max(1, controlsPane:GetWidth() - 42),
		math.max(1, controlsPane:GetHeight() - 44)
	)
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("TOPRIGHT", controlsPane, "TOPRIGHT", -8, -48)
	scrollBar:SetSize(16, math.max(24, controlsPane:GetHeight() - 62))
end

local function RestoreSession()
	if sessionSnapshot then
		addon:RestoreDisplaySettings(sessionSnapshot)
		ApplyPreviewVisuals()
	end
end

local function CreateConfigWindow()
	local window = CreateFrame("Frame", "ThreatPlatingConfigWindow", UIParent, "BackdropTemplate")
	window:SetSize(db.windowWidth, db.windowHeight)
	window:SetPoint("CENTER", UIParent, "CENTER", db.windowOffsetX, db.windowOffsetY)
	window:SetBackdrop(BACKDROP)
	window:SetBackdropColor(0.035, 0.045, 0.060, 0.99)
	window:SetBackdropBorderColor(0.22, 0.55, 0.38, 1)
	window:SetFrameStrata("DIALOG")
	window:SetClampedToScreen(true)
	window:SetMovable(true)
	window:SetResizable(true)
	window:SetResizeBounds(520, 520, 1000, 800)
	window:EnableMouse(true)
	window:Hide()
	UISpecialFrames[#UISpecialFrames + 1] = "ThreatPlatingConfigWindow"

	local titleBar = CreateFrame("Frame", nil, window)
	titleBar:SetPoint("TOPLEFT", window, "TOPLEFT", 1, -1)
	titleBar:SetPoint("TOPRIGHT", window, "TOPRIGHT", -1, -1)
	titleBar:SetHeight(40)
	titleBar:EnableMouse(true)
	titleBar:RegisterForDrag("LeftButton")
	titleBar:SetScript("OnDragStart", function()
		window:StartMoving()
	end)
	titleBar:SetScript("OnDragStop", function()
		window:StopMovingOrSizing()
		SaveWindowPosition(window)
	end)

	local titleBackground = titleBar:CreateTexture(nil, "BACKGROUND")
	titleBackground:SetAllPoints(titleBar)
	titleBackground:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	titleBackground:SetVertexColor(0.12, 0.45, 0.27, 0.95)

	local title = CreateText(titleBar, "Threat Plating", "GameFontNormalLarge")
	title:SetPoint("LEFT", titleBar, "LEFT", 16, 0)

	local subtitle = CreateText(
		titleBar,
		"Live nameplate editor",
		"GameFontHighlightSmall"
	)
	subtitle:SetPoint("LEFT", title, "RIGHT", 10, -1)

	local closeButton = CreateFrame("Button", nil, window, "UIPanelCloseButtonNoScripts")
	closeButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", -3, -3)
	closeButton:SetFrameLevel(window:GetFrameLevel() + 100)
	closeButton:SetScript("OnClick", function()
		addon.CloseConfig()
	end)
	AddTooltip(closeButton, "Close", "Keep changes and close the editor.")

	CreatePreview(window)
	CreateControls(window)

	local footerBackground = window:CreateTexture(nil, "BACKGROUND")
	footerBackground:SetColorTexture(0.02, 0.03, 0.04, 0.98)
	footerBackground:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 1, 1)
	footerBackground:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -1, 1)
	footerBackground:SetHeight(50)

	local resetLayout = CreateButton(window, "Reset Layout", 88, function()
		addon:ResetLayoutSettings()
		ApplyPreviewVisuals()
	end, "Restore position and size defaults immediately.")
	resetLayout:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 12, 13)

	local resetAppearance = CreateButton(window, "Reset Appearance", 110, function()
		addon:ResetAppearanceSettings()
		ApplyPreviewVisuals()
	end, "Restore typography, background, border, and color defaults immediately.")
	resetAppearance:SetPoint("LEFT", resetLayout, "RIGHT", 4, 0)

	local resetAll = CreateButton(window, "Reset All", 74, function()
		addon:ResetAllSettings()
		ApplyPreviewVisuals()
	end, "Restore every display setting and enable the addon.")
	resetAll:SetPoint("LEFT", resetAppearance, "RIGHT", 4, 0)

	local done = CreateButton(window, "Done", 70, function()
		addon.CloseConfig()
	end, "Keep changes and close the editor.")
	done:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -12, 13)
	done:SetFrameLevel(window:GetFrameLevel() + 100)

	local revert = CreateButton(
		window,
		"Revert",
		70,
		RestoreSession,
		"Restore the state captured when this editor session opened."
	)
	revert:SetPoint("RIGHT", done, "LEFT", -4, 0)

	local windowGrip = CreateFrame("Button", nil, window)
	windowGrip:SetSize(20, 20)
	windowGrip:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -1, 1)
	local windowGripTexture = windowGrip:CreateTexture(nil, "OVERLAY")
	windowGripTexture:SetAllPoints(windowGrip)
	windowGripTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	windowGrip:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then
			window:StartSizing("BOTTOMRIGHT")
		end
	end)
	windowGrip:SetScript("OnMouseUp", function()
		window:StopMovingOrSizing()
		db.windowWidth = Round(window:GetWidth())
		db.windowHeight = Round(window:GetHeight())
		SaveWindowPosition(window)
		ReflowWindow(window)
	end)
	AddTooltip(windowGrip, "Resize editor", "Resize between 520×520 and 1000×800.")

	function window.LayoutControls()
		LayoutControls(math.max(240, controlsPane:GetWidth() - 40))
	end

	window:SetScript("OnSizeChanged", function(_, width, height)
		db.windowWidth = Clamp(Round(width), 520, 1000)
		db.windowHeight = Clamp(Round(height), 520, 800)
		ReflowWindow(window)
	end)

	window:SetScript("OnShow", function()
		sessionSnapshot = addon:CaptureDisplaySettings()
		previewIsTank = addon.playerIsTank and true or false
		previewState = "safe"
		addon.configPreviewActive = true
		addon:ScanVisibleNameplates()
		ApplyPreviewVisuals()
		addon.UpdateAllNameplates()
	end)

	window:SetScript("OnHide", function(self)
		self:StopMovingOrSizing()
		if previewBadge then
			previewBadge:StopMovingOrSizing()
			previewBadge.resizing = false
		end
		FlushPendingChange()
		EndOwnedColorPicker()
		addon.configPreviewActive = false
		sessionSnapshot = nil
		addon.UpdateAllNameplates()
	end)

	window:SetScript("OnUpdate", function(self, elapsed)
		if pendingChangeKind then
			pendingChangeElapsed = pendingChangeElapsed + elapsed
			if pendingChangeElapsed >= APPLY_INTERVAL then
				FlushPendingChange()
			end
		end

		self.referenceRefreshElapsed = (self.referenceRefreshElapsed or 0) + elapsed
		if self.referenceRefreshElapsed < 0.5 then
			return
		end
		self.referenceRefreshElapsed = 0
		if not previewBadge.dragging and not previewBadge.resizing then
			ApplyPreviewVisuals()
		end
	end)

	configWindow = window
	ReflowWindow(window)
	ApplyPreviewVisuals()
	return window
end

function addon.OpenConfig()
	local window = configWindow or CreateConfigWindow()
	window:Show()
end

function addon.CloseConfig()
	if configWindow then
		configWindow:Hide()
	end
end

function addon.ToggleConfig()
	local window = configWindow or CreateConfigWindow()
	if window:IsShown() then
		addon.CloseConfig()
	else
		window:Show()
	end
end

ThreatPlating_OnAddonCompartmentClick = function()
	addon.ToggleConfig()
end

if Settings and Settings.RegisterCanvasLayoutCategory then
	local settingsFrame = CreateFrame("Frame")
	local settingsTitle = CreateText(settingsFrame, "Threat Plating", "GameFontNormalHuge")
	settingsTitle:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 16, -16)

	local settingsDescription = CreateText(
		settingsFrame,
		"Threat counters stay lightweight here; use the standalone editor for visual layout.",
		"GameFontHighlight"
	)
	settingsDescription:SetPoint("TOPLEFT", settingsTitle, "BOTTOMLEFT", 0, -14)

	local enabled = CreateFrame("CheckButton", nil, settingsFrame, "UICheckButtonTemplate")
	enabled:SetSize(26, 26)
	enabled:SetPoint("TOPLEFT", settingsDescription, "BOTTOMLEFT", 0, -18)
	local enabledLabel = CreateText(enabled, "Enable threat counters", "GameFontHighlight")
	enabledLabel:SetPoint("LEFT", enabled, "RIGHT", 3, 1)
	enabled:SetScript("OnClick", function(self)
		addon:SetEnabled(self:GetChecked() == true)
	end)
	settingsEnabledCheck = enabled

	local summary = CreateText(settingsFrame, "", "GameFontHighlightSmall")
	summary:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 4, -12)
	settingsStatusText = summary

	local openButton = CreateButton(settingsFrame, "Open Editor", 150, function()
		addon.OpenConfig()
	end, "Open the movable, resizable live editor.")
	openButton:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", -4, -18)

	local category, layout = Settings.RegisterCanvasLayoutCategory(settingsFrame, "Threat Plating")
	if layout and layout.AddAnchorPoint then
		layout:AddAnchorPoint("TOPLEFT", 20, -20)
		layout:AddAnchorPoint("BOTTOMRIGHT", -20, 20)
	end
	Settings.RegisterAddOnCategory(category)
	UpdateStatus()
end

if addon.testHarness then
	addon.ConfigTest = {
		anchorPresets = ANCHOR_PRESETS,
		commitDraggedPosition = CommitDraggedPosition,
		endColorPicker = EndOwnedColorPicker,
		flush = FlushPendingChange,
		getControls = function()
			return controls
		end,
		getPickerOwner = function()
			return pickerOwner
		end,
		getPreviewCanvas = function()
			return previewCanvas
		end,
		getPreviewBadge = function()
			return previewBadge
		end,
		getPreviewHealthBar = function()
			return previewHealthBar
		end,
		getPreviewHealthText = function()
			return previewHealthText
		end,
		getPreviewSourceText = function()
			return previewSourceText
		end,
		getPreviewUnitName = function()
			return previewUnitName
		end,
		getScrollBar = function()
			return scrollBar
		end,
		getScrollFrame = function()
			return scrollFrame
		end,
		getSections = function()
			return sections
		end,
		getWindow = function()
			return configWindow
		end,
		openColorPicker = OpenColorPicker,
		reflow = function()
			if configWindow then
				ReflowWindow(configWindow)
			end
		end,
		restoreSession = RestoreSession,
		setScenario = SetScenario,
		useAnchorPreset = UseAnchorPreset,
	}
end
