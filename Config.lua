local _, addon = ...

local db = addon.db
local Clamp = addon.Clamp
local BACKDROP = addon.BACKDROP
local settingDefinitions = addon.settingDefinitions
local previewCanvas
local previewBadge
local previewBadgeText
local previewHealthBar
local previewUnitName
local previewHealthText
local previewSourceText
local statusText
local settingsEnabledCheck
local settingsStatusText
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
	if previewState == "safe" then
		isLeader = isTank
	elseif previewState == "danger" then
		isLeader = not isTank
	else
		isLeader = true
	end

	return isTank, isLeader, previewState
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

local function ApplyReferenceTextVisual(
	label,
	healthBar,
	visual,
	prefix,
	fallbackText,
	fallbackPoint,
	fallbackRelativePoint,
	fallbackOffsetX,
	fallbackOffsetY,
	defaultRed,
	defaultGreen,
	defaultBlue
)
	label:ClearAllPoints()
	label:SetText(visual and visual[prefix .. "Text"] or fallbackText)

	local fontPath = visual and visual[prefix .. "FontPath"]
	if fontPath then
		label:SetFont(
			fontPath,
			Clamp(visual[prefix .. "FontSize"] or 12, 6, 32),
			visual[prefix .. "FontFlags"] or ""
		)
	else
		label:SetFontObject("SystemFont_NamePlate_Outlined")
	end

	local offsetX = visual and visual[prefix .. "OffsetX"]
	local offsetY = visual and visual[prefix .. "OffsetY"]
	if offsetX and offsetY then
		label:SetPoint(
			"CENTER",
			healthBar,
			"CENTER",
			Clamp(offsetX, -260, 260),
			Clamp(offsetY, -80, 80)
		)
	else
		label:SetPoint(
			fallbackPoint,
			healthBar,
			fallbackRelativePoint,
			fallbackOffsetX,
			fallbackOffsetY
		)
	end

	label:SetTextColor(
		visual and visual[prefix .. "Red"] or defaultRed,
		visual and visual[prefix .. "Green"] or defaultGreen,
		visual and visual[prefix .. "Blue"] or defaultBlue,
		visual and visual[prefix .. "Alpha"] or 1
	)
end

-- SetClipsChildren only clips rendering; the badge keeps its hit box outside the canvas
-- and would swallow clicks meant for the footer buttons underneath. Test for overlap,
-- not containment: a badge clipped at an edge is still partly visible and must stay
-- draggable, while a badge with nothing on screen must never take a click.
local function UpdatePreviewBadgeHitBox()
	if not previewBadge or not previewCanvas then
		return
	end

	local badgeLeft, badgeRight = previewBadge:GetLeft(), previewBadge:GetRight()
	local badgeTop, badgeBottom = previewBadge:GetTop(), previewBadge:GetBottom()
	local canvasLeft, canvasRight = previewCanvas:GetLeft(), previewCanvas:GetRight()
	local canvasTop, canvasBottom = previewCanvas:GetTop(), previewCanvas:GetBottom()

	if not (badgeLeft and badgeRight and badgeTop and badgeBottom
		and canvasLeft and canvasRight and canvasTop and canvasBottom)
	then
		-- Unresolved geometry: leave the badge interactive rather than trap the user.
		previewBadge:EnableMouse(true)
		return
	end

	local visible = badgeRight > canvasLeft
		and badgeLeft < canvasRight
		and badgeTop > canvasBottom
		and badgeBottom < canvasTop

	previewBadge:EnableMouse(visible)
end

local function ApplyPreviewVisuals()
	if not previewBadge then
		UpdateStatus()
		RefreshControls()
		return
	end

	applyingPreview = true
	local isTank, isLeader, safetyState = GetScenario()
	local sampleText = addon.Threat.FormatDelta(addon.sampleThreatDelta, isLeader)
	previewBadgeText:SetText(sampleText)
	addon:ApplyBadgeStyle(previewBadge, previewBadgeText)

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

	ApplyReferenceTextVisual(
		previewUnitName,
		previewHealthBar,
		visual,
		"name",
		"Enemy Nameplate",
		"BOTTOM",
		"TOP",
		0,
		3,
		1,
		0.82,
		0.20
	)
	ApplyReferenceTextVisual(
		previewHealthText,
		previewHealthBar,
		visual,
		"health",
		"72%",
		"CENTER",
		"CENTER",
		0,
		0,
		1,
		1,
		1
	)
	previewSourceText:SetText(
		visual and "Current visible nameplate baseline"
			or "Default 128 × 20 nameplate baseline"
	)

	addon:ApplyThreatColor(previewBadge, previewBadgeText, safetyState)

	-- Never fight a live StartSizing: resizing the frame under the cursor would make
	-- the grip jump and feed the mock size back into the saved value.
	if not previewBadge.resizing then
		previewBadge:SetSize(addon:GetBadgeWidth(previewBadgeText), db.badgeHeight)
		previewBadge:ClearAllPoints()
		previewBadge:SetPoint(
			db.anchorPoint,
			previewHealthBar,
			db.relativePoint,
			db.offsetX,
			db.offsetY
		)
	end

	UpdatePreviewBadgeHitBox()

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
	db.offsetX = addon.NormalizeSettingValue("offsetX", nearestOffsetX)
	db.offsetY = addon.NormalizeSettingValue("offsetY", nearestOffsetY)
	QueueDisplayChange("layout", true)
end

local function StopPreviewResize()
	if not previewBadge or not previewBadge.resizing then
		return
	end

	previewBadge:StopMovingOrSizing()
	previewBadge.resizing = false

	-- Do not read the frame back here. Its width is the auto-width result, not the
	-- configured minimum, so a grip press with no movement would ratchet badgeWidth
	-- up by the current text width. OnSizeChanged already records genuine drags.
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

-- Init.lua's bulk settings paths call this before replacing the color tables.
addon.EndColorPicker = EndOwnedColorPicker

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

		-- Resolve the table on every callback: a reset or revert replaces db[key]
		-- outright, and writing through a captured reference would edit an orphan.
		local target = db[key]
		if type(target) ~= "table" then
			return
		end

		local red, green, blue = ColorPickerFrame:GetColorRGB()
		target[1] = Clamp(red, 0, 1)
		target[2] = Clamp(green, 0, 1)
		target[3] = Clamp(blue, 0, 1)
		if hasAlpha and ColorPickerFrame.GetColorAlpha then
			target[4] = Clamp(ColorPickerFrame:GetColorAlpha(), 0, 1)
		end
		QueueDisplayChange("style", not ColorPickerFrame:IsShown())
	end

	local function CancelColor()
		if pickerOwner ~= owner then
			return
		end
		db[key] = addon.CopyValue(original)
		pickerOwner = nil
		ColorPickerFrame.swatchFunc = nil
		ColorPickerFrame.opacityFunc = nil
		ColorPickerFrame.cancelFunc = nil
		ColorPickerFrame.hasOpacity = false
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
	badge:SetResizeBounds(
		settingDefinitions.badgeWidth.minimum,
		settingDefinitions.badgeHeight.minimum,
		settingDefinitions.badgeWidth.maximum,
		settingDefinitions.badgeHeight.maximum
	)
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
		db.badgeWidth = addon.NormalizeSettingValue("badgeWidth", width)
		db.badgeHeight = addon.NormalizeSettingValue("badgeHeight", height)
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


local Config = {
	anchorPresets = ANCHOR_PRESETS,
	controls = controls,
	sections = sections,
	wideThreshold = WIDE_THRESHOLD,
	CreateText = CreateText,
	AddTooltip = AddTooltip,
	CreateButton = CreateButton,
	SetButtonSelected = SetButtonSelected,
	SetControlEnabled = SetControlEnabled,
	FlushPendingChange = FlushPendingChange,
	ApplyPreviewVisuals = ApplyPreviewVisuals,
	UpdateStatus = UpdateStatus,
	QueueDisplayChange = QueueDisplayChange,
	SetScenario = SetScenario,
	UseAnchorPreset = UseAnchorPreset,
	CommitDraggedPosition = CommitDraggedPosition,
	EndOwnedColorPicker = EndOwnedColorPicker,
	OpenColorPicker = OpenColorPicker,
	CreatePreview = CreatePreview,
}

function Config.IsRefreshingControls()
	return refreshingControls
end

function Config.SetStatusText(label)
	statusText = label
end

function Config.SetSettingsEnabledCheck(check)
	settingsEnabledCheck = check
end

function Config.SetSettingsStatusText(label)
	settingsStatusText = label
end

function Config.ResetScenario(isTank)
	previewIsTank = isTank and true or false
	previewState = "safe"
end

function Config.AdvancePendingChange(elapsed)
	if not pendingChangeKind then
		return
	end

	pendingChangeElapsed = pendingChangeElapsed + elapsed
	if pendingChangeElapsed >= APPLY_INTERVAL then
		FlushPendingChange()
	end
end

function Config.StopPreviewInteraction()
	if not previewBadge then
		return
	end

	previewBadge:StopMovingOrSizing()
	previewBadge.resizing = false
	-- Hidden frames run no mouse scripts, so OnDragStop cannot clear this itself.
	previewBadge.dragging = false
end

function Config.IsPreviewIdle()
	return previewBadge
		and not previewBadge.dragging
		and not previewBadge.resizing
end

function Config.GetPreviewCanvas()
	return previewCanvas
end

function Config.GetPreviewBadge()
	return previewBadge
end

function Config.GetPreviewHealthBar()
	return previewHealthBar
end

function Config.GetPreviewHealthText()
	return previewHealthText
end

function Config.GetPreviewSourceText()
	return previewSourceText
end

function Config.GetPreviewUnitName()
	return previewUnitName
end

function Config.GetPickerOwner()
	return pickerOwner
end

addon.ConfigPrivate = Config
