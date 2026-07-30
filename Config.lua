local _, addon = ...

local db = addon.db
local configWindow
local previewBadge
local previewBadgeText
local previewCanvas
local previewHealthBar
local previewHealthFill
local statusText
local enabledCheck
local autoWidthCheck
local backgroundCheck
local fontSizeText
local applyingPreview = false

local BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Buttons\\WHITE8X8",
	edgeSize = 1,
}

local function Clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local function Round(value)
	if value >= 0 then
		return math.floor(value + 0.5)
	end
	return math.ceil(value - 0.5)
end

local function CreateText(parent, text, fontObject)
	local label = parent:CreateFontString(nil, "OVERLAY")
	label:SetFontObject(fontObject or "GameFontNormal")
	label:SetText(text)
	return label
end

local function CreateButton(parent, text, width, callback)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 24)
	button:SetText(text)
	button:SetScript("OnClick", callback)
	return button
end

local function CreateCheckButton(parent, text, callback)
	local checkButton = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	checkButton:SetSize(24, 24)

	local label = CreateText(checkButton, text, "GameFontHighlight")
	label:SetPoint("LEFT", checkButton, "RIGHT", 1, 1)
	checkButton.label = label
	checkButton:SetScript("OnClick", function(self)
		callback(self:GetChecked() == true)
	end)

	return checkButton
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

local function UpdateStatus()
	if not statusText then
		return
	end

	statusText:SetText(string.format(
		"Badge %d x %d  |  Font %d  |  Offset %+d, %+d  |  %s colors",
		db.badgeWidth,
		db.badgeHeight,
		db.fontSize,
		db.offsetX,
		db.offsetY,
		addon.playerIsTank and "Tank" or "Non-tank"
	))
end

local function ApplyPreviewVisuals()
	if not previewBadge then
		return
	end

	applyingPreview = true
	previewBadgeText:SetText("+12.3k")
	previewBadgeText:SetTextHeight(db.fontSize)

	local referenceWidth, referenceHeight = addon.GetReferenceHealthBarSize()
	referenceWidth = Clamp(referenceWidth, 60, 260)
	referenceHeight = Clamp(referenceHeight, 8, 60)
	previewHealthBar:SetSize(referenceWidth, referenceHeight)
	previewHealthFill:SetWidth(math.max(1, referenceWidth * 0.70 - 4))

	local width = db.badgeWidth
	if db.autoWidth then
		width = math.max(width, math.ceil(previewBadgeText:GetStringWidth()) + 14)
	end
	previewBadge:SetSize(width, db.badgeHeight)

	if db.showBackground then
		previewBadge:SetBackdropColor(0.025, 0.025, 0.025, 0.90)
	else
		previewBadge:SetBackdropColor(0, 0, 0, 0)
		previewBadge:SetBackdropBorderColor(0, 0, 0, 0)
	end
	addon:ApplyThreatColor(previewBadge, previewBadgeText, true, false)

	previewBadge:ClearAllPoints()
	previewBadge:SetPoint(
		db.anchorPoint,
		previewHealthBar,
		db.relativePoint,
		db.offsetX,
		db.offsetY
	)

	if enabledCheck then
		enabledCheck:SetChecked(db.enabled)
		autoWidthCheck:SetChecked(db.autoWidth)
		backgroundCheck:SetChecked(db.showBackground)
		fontSizeText:SetText(tostring(db.fontSize))
	end

	UpdateStatus()
	applyingPreview = false
end

local function CommitSettings()
	addon.ApplyDisplaySettings()
	ApplyPreviewVisuals()
end

addon.RefreshConfig = ApplyPreviewVisuals

local function UseAnchor(point, relativePoint, offsetX, offsetY)
	db.anchorPoint = point
	db.relativePoint = relativePoint
	db.offsetX = offsetX
	db.offsetY = offsetY
	CommitSettings()
end

local function CommitDraggedPosition()
	local badgeCenterX, badgeCenterY = previewBadge:GetCenter()
	local barCenterX, barCenterY = previewHealthBar:GetCenter()
	if not badgeCenterX or not barCenterX then
		ApplyPreviewVisuals()
		return
	end

	local deltaX = badgeCenterX - barCenterX
	local deltaY = badgeCenterY - barCenterY
	local insideHorizontally = math.abs(deltaX) < previewHealthBar:GetWidth() / 2
	local insideVertically = math.abs(deltaY) < previewHealthBar:GetHeight() / 2

	if insideHorizontally and insideVertically then
		db.anchorPoint = "CENTER"
		db.relativePoint = "CENTER"
	elseif math.abs(deltaX) >= math.abs(deltaY) then
		if deltaX >= 0 then
			db.anchorPoint = "LEFT"
			db.relativePoint = "RIGHT"
		else
			db.anchorPoint = "RIGHT"
			db.relativePoint = "LEFT"
		end
	elseif deltaY >= 0 then
		db.anchorPoint = "BOTTOM"
		db.relativePoint = "TOP"
	else
		db.anchorPoint = "TOP"
		db.relativePoint = "BOTTOM"
	end

	local badgeX, badgeY = GetPointCoordinates(previewBadge, db.anchorPoint)
	local barX, barY = GetPointCoordinates(previewHealthBar, db.relativePoint)
	if badgeX and barX then
		db.offsetX = Clamp(Round(badgeX - barX), -300, 300)
		db.offsetY = Clamp(Round(badgeY - barY), -300, 300)
	end

	CommitSettings()
end

local function StopPreviewResize()
	if not previewBadge or not previewBadge.resizing then
		return
	end

	previewBadge:StopMovingOrSizing()
	previewBadge.resizing = false
	db.badgeWidth = Clamp(Round(previewBadge:GetWidth()), 36, 160)
	db.badgeHeight = Clamp(Round(previewBadge:GetHeight()), 14, 64)
	db.fontSize = Clamp(db.badgeHeight - 4, 8, 32)
	CommitSettings()
end

local function CreatePreview(parent)
	local canvas = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	canvas:SetHeight(270)
	canvas:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, -100)
	canvas:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -22, -100)
	canvas:SetBackdrop(BACKDROP)
	canvas:SetBackdropColor(0.015, 0.02, 0.028, 0.96)
	canvas:SetBackdropBorderColor(0.18, 0.26, 0.34, 1)
	canvas:SetClipsChildren(true)
	previewCanvas = canvas

	local instructions = CreateText(
		canvas,
		"Drag the badge to position it. Drag its lower-right corner to resize.",
		"GameFontHighlightSmall"
	)
	instructions:SetPoint("TOP", canvas, "TOP", 0, -12)
	instructions:SetTextColor(0.70, 0.78, 0.86, 1)

	local horizontalGuide = canvas:CreateTexture(nil, "BACKGROUND")
	horizontalGuide:SetColorTexture(0.20, 0.45, 0.60, 0.12)
	horizontalGuide:SetHeight(1)
	horizontalGuide:SetPoint("LEFT", canvas, "LEFT", 20, 0)
	horizontalGuide:SetPoint("RIGHT", canvas, "RIGHT", -20, 0)

	local verticalGuide = canvas:CreateTexture(nil, "BACKGROUND")
	verticalGuide:SetColorTexture(0.20, 0.45, 0.60, 0.12)
	verticalGuide:SetWidth(1)
	verticalGuide:SetPoint("TOP", canvas, "TOP", 0, -40)
	verticalGuide:SetPoint("BOTTOM", canvas, "BOTTOM", 0, 44)

	local healthBar = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
	healthBar:SetSize(128, 20)
	healthBar:SetPoint("CENTER", canvas, "CENTER", 0, 16)
	healthBar:SetBackdrop(BACKDROP)
	healthBar:SetBackdropColor(0.08, 0.08, 0.08, 1)
	healthBar:SetBackdropBorderColor(0, 0, 0, 1)
	previewHealthBar = healthBar

	local fill = healthBar:CreateTexture(nil, "ARTWORK")
	fill:SetColorTexture(0.72, 0.12, 0.10, 1)
	fill:SetPoint("TOPLEFT", healthBar, "TOPLEFT", 2, -2)
	fill:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMLEFT", 2, 2)
	fill:SetWidth(88)
	previewHealthFill = fill

	local unitName = CreateText(healthBar, "Enemy Nameplate", "SystemFont_NamePlate_Outlined")
	unitName:SetPoint("BOTTOM", healthBar, "TOP", 0, 3)
	unitName:SetTextColor(1, 0.82, 0.20, 1)

	local healthText = CreateText(healthBar, "72%", "SystemFont_NamePlate_Outlined")
	healthText:SetPoint("CENTER", healthBar, "CENTER", 0, 0)
	healthText:SetTextColor(1, 1, 1, 1)

	local badge = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
	badge:SetBackdrop(BACKDROP)
	badge:SetBackdropColor(0, 0, 0, 0)
	badge:SetBackdropBorderColor(0.20, 0.75, 0.20, 1)
	badge:SetMovable(true)
	badge:SetResizable(true)
	badge:SetResizeBounds(36, 14, 160, 64)
	badge:EnableMouse(true)
	badge:RegisterForDrag("LeftButton")
	previewBadge = badge

	local badgeText = CreateText(badge, "+12.3k", "SystemFont_NamePlate_Outlined")
	badgeText:SetTextHeight(db.fontSize)
	badgeText:SetPoint("CENTER", badge, "CENTER", 0, 0)
	badgeText:SetTextColor(0.35, 1, 0.35, 1)
	badgeText:SetShadowColor(0, 0, 0, 1)
	badgeText:SetShadowOffset(1, -1)
	previewBadgeText = badgeText

	badge:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	badge:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		CommitDraggedPosition()
	end)
	badge:SetScript("OnSizeChanged", function(self, width, height)
		if applyingPreview or not self.resizing then
			return
		end

		db.badgeWidth = Clamp(Round(width), 36, 160)
		db.badgeHeight = Clamp(Round(height), 14, 64)
		db.fontSize = Clamp(db.badgeHeight - 4, 8, 32)
		previewBadgeText:SetTextHeight(db.fontSize)
		addon.ApplyDisplaySettings()
		UpdateStatus()
	end)

	local badgeGrip = CreateFrame("Button", nil, badge)
	badgeGrip:SetSize(13, 13)
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

	local rightButton = CreateButton(canvas, "Right", 68, function()
		UseAnchor("LEFT", "RIGHT", 6, 0)
	end)
	rightButton:SetPoint("BOTTOM", canvas, "BOTTOM", -148, 12)

	local leftButton = CreateButton(canvas, "Left", 68, function()
		UseAnchor("RIGHT", "LEFT", -6, 0)
	end)
	leftButton:SetPoint("LEFT", rightButton, "RIGHT", 6, 0)

	local aboveButton = CreateButton(canvas, "Above", 68, function()
		UseAnchor("BOTTOM", "TOP", 0, 6)
	end)
	aboveButton:SetPoint("LEFT", leftButton, "RIGHT", 6, 0)

	local belowButton = CreateButton(canvas, "Below", 68, function()
		UseAnchor("TOP", "BOTTOM", 0, -6)
	end)
	belowButton:SetPoint("LEFT", aboveButton, "RIGHT", 6, 0)

	local centerButton = CreateButton(canvas, "Center", 68, function()
		UseAnchor("CENTER", "CENTER", 0, 0)
	end)
	centerButton:SetPoint("LEFT", belowButton, "RIGHT", 6, 0)

	return canvas
end

local function SaveWindowPosition(window)
	local windowX, windowY = window:GetCenter()
	local parentX, parentY = UIParent:GetCenter()
	if windowX and parentX then
		db.windowOffsetX = Round(windowX - parentX)
		db.windowOffsetY = Round(windowY - parentY)
	end
end

local function CreateConfigWindow()
	local window = CreateFrame("Frame", "ThreatPlatingConfigWindow", UIParent, "BackdropTemplate")
	window:SetSize(db.windowWidth, db.windowHeight)
	window:SetPoint("CENTER", UIParent, "CENTER", db.windowOffsetX, db.windowOffsetY)
	window:SetBackdrop(BACKDROP)
	window:SetBackdropColor(0.035, 0.045, 0.060, 0.98)
	window:SetBackdropBorderColor(0.22, 0.65, 0.42, 1)
	window:SetFrameStrata("DIALOG")
	window:SetClampedToScreen(true)
	window:SetMovable(true)
	window:SetResizable(true)
	window:SetResizeBounds(620, 540, 900, 720)
	window:EnableMouse(true)
	window:Hide()
	UISpecialFrames[#UISpecialFrames + 1] = "ThreatPlatingConfigWindow"

	local titleBar = CreateFrame("Frame", nil, window)
	titleBar:SetPoint("TOPLEFT", window, "TOPLEFT", 1, -1)
	titleBar:SetPoint("TOPRIGHT", window, "TOPRIGHT", -1, -1)
	titleBar:SetHeight(36)
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
	titleBackground:SetColorTexture(0.06, 0.16, 0.12, 0.96)

	local title = CreateText(titleBar, "Threat Plating Configurator", "GameFontNormalLarge")
	title:SetPoint("LEFT", titleBar, "LEFT", 16, 0)
	title:SetTextColor(0.55, 1, 0.68, 1)

	local closeButton = CreateFrame("Button", nil, window, "UIPanelCloseButtonNoScripts")
	closeButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", -3, -3)
	closeButton:SetFrameLevel(window:GetFrameLevel() + 100)
	closeButton:SetScript("OnClick", function()
		addon.CloseConfig()
	end)

	local description = CreateText(
		window,
		"Changes apply immediately to the preview and every currently visible enemy NPC nameplate.",
		"GameFontHighlightSmall"
	)
	description:SetPoint("TOPLEFT", window, "TOPLEFT", 22, -48)
	description:SetPoint("RIGHT", window, "RIGHT", -22, 0)
	description:SetJustifyH("LEFT")
	description:SetTextColor(0.72, 0.78, 0.84, 1)

	enabledCheck = CreateCheckButton(window, "Enable threat counters", function(checked)
		addon:SetEnabled(checked)
	end)
	enabledCheck:SetPoint("TOPLEFT", window, "TOPLEFT", 18, -68)

	CreatePreview(window)

	autoWidthCheck = CreateCheckButton(window, "Expand width for long values", function(checked)
		db.autoWidth = checked
		CommitSettings()
	end)
	autoWidthCheck:SetPoint("TOPLEFT", previewCanvas, "BOTTOMLEFT", 0, -16)

	backgroundCheck = CreateCheckButton(window, "High-contrast background", function(checked)
		db.showBackground = checked
		CommitSettings()
	end)
	backgroundCheck:SetPoint("TOPLEFT", autoWidthCheck, "BOTTOMLEFT", 0, -8)

	local fontLabel = CreateText(window, "Font size", "GameFontHighlight")
	fontLabel:SetPoint("TOPLEFT", previewCanvas, "BOTTOM", 35, -21)

	local fontMinus = CreateButton(window, "-", 28, function()
		db.fontSize = Clamp(db.fontSize - 1, 8, 32)
		db.badgeHeight = math.max(db.badgeHeight, db.fontSize + 4)
		CommitSettings()
	end)
	fontMinus:SetPoint("LEFT", fontLabel, "RIGHT", 12, 0)

	fontSizeText = CreateText(window, tostring(db.fontSize), "GameFontNormalLarge")
	fontSizeText:SetPoint("LEFT", fontMinus, "RIGHT", 12, 0)

	local fontPlus = CreateButton(window, "+", 28, function()
		db.fontSize = Clamp(db.fontSize + 1, 8, 32)
		db.badgeHeight = math.max(db.badgeHeight, db.fontSize + 4)
		CommitSettings()
	end)
	fontPlus:SetPoint("LEFT", fontSizeText, "RIGHT", 12, 0)

	local resetButton = CreateButton(window, "Reset badge", 110, function()
		addon:ResetBadgeSettings()
		ApplyPreviewVisuals()
	end)
	resetButton:SetPoint("TOPRIGHT", previewCanvas, "BOTTOMRIGHT", 0, -17)

	statusText = CreateText(window, "", "GameFontHighlightSmall")
	statusText:SetPoint("TOPLEFT", backgroundCheck, "BOTTOMLEFT", 4, -14)
	statusText:SetTextColor(0.55, 0.78, 0.92, 1)

	local footer = CreateText(
		window,
		"Tip: keep this window open near enemies to see the sample badge on their real nameplates.",
		"GameFontDisableSmall"
	)
	footer:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 22, 18)
	footer:SetPoint("RIGHT", window, "RIGHT", -140, 0)
	footer:SetJustifyH("LEFT")

	local footerCloseButton = CreateButton(window, "Close", 82, function()
		addon.CloseConfig()
	end)
	footerCloseButton:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -32, 10)
	footerCloseButton:SetFrameLevel(window:GetFrameLevel() + 100)

	local windowGrip = CreateFrame("Button", nil, window)
	windowGrip:SetSize(20, 20)
	windowGrip:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -3, 3)
	local windowGripTexture = windowGrip:CreateTexture(nil, "OVERLAY")
	windowGripTexture:SetAllPoints(windowGrip)
	windowGripTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	windowGripTexture:SetVertexColor(0.55, 1, 0.68, 0.9)
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
	end)

	window:SetScript("OnSizeChanged", function(_, width, height)
		db.windowWidth = Clamp(Round(width), 620, 900)
		db.windowHeight = Clamp(Round(height), 540, 720)
	end)

	window:SetScript("OnShow", function()
		addon.configPreviewActive = true
		addon:ScanVisibleNameplates()
		addon.ApplyDisplaySettings()
		ApplyPreviewVisuals()
	end)

	window:SetScript("OnHide", function(self)
		self:StopMovingOrSizing()
		previewBadge:StopMovingOrSizing()
		previewBadge.resizing = false
		addon.configPreviewActive = false
		addon.UpdateAllNameplates()
	end)

	window:SetScript("OnUpdate", function(self, elapsed)
		self.referenceRefreshElapsed = (self.referenceRefreshElapsed or 0) + elapsed
		if self.referenceRefreshElapsed < 0.5 then
			return
		end

		self.referenceRefreshElapsed = 0
		local width, height = addon.GetReferenceHealthBarSize()
		if width ~= self.referenceWidth or height ~= self.referenceHeight then
			self.referenceWidth = width
			self.referenceHeight = height
			ApplyPreviewVisuals()
		end
	end)

	configWindow = window
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
		"Position, resize, and preview the threat badge with the standalone configurator.",
		"GameFontHighlight"
	)
	settingsDescription:SetPoint("TOPLEFT", settingsTitle, "BOTTOMLEFT", 0, -16)

	local openButton = CreateButton(settingsFrame, "Open configurator", 170, function()
		addon.OpenConfig()
	end)
	openButton:SetPoint("TOPLEFT", settingsDescription, "BOTTOMLEFT", 0, -20)

	local category, layout = Settings.RegisterCanvasLayoutCategory(settingsFrame, "Threat Plating")
	if layout and layout.AddAnchorPoint then
		layout:AddAnchorPoint("TOPLEFT", 20, -20)
		layout:AddAnchorPoint("BOTTOMRIGHT", -20, 20)
	end
	Settings.RegisterAddOnCategory(category)
end
