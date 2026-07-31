local _, addon = ...

local Config = addon.ConfigPrivate
local db = addon.db
local BACKDROP = addon.BACKDROP
local settingDefinitions = addon.settingDefinitions
local WIDE_THRESHOLD = Config.wideThreshold
local CreateText = Config.CreateText
local AddTooltip = Config.AddTooltip
local CreateButton = Config.CreateButton
local FlushPendingChange = Config.FlushPendingChange
local ApplyPreviewVisuals = Config.ApplyPreviewVisuals
local UpdateStatus = Config.UpdateStatus
local EndOwnedColorPicker = Config.EndOwnedColorPicker
local CommitDraggedPosition = Config.CommitDraggedPosition
local OpenColorPicker = Config.OpenColorPicker
local SetScenario = Config.SetScenario
local UseAnchorPreset = Config.UseAnchorPreset
local LayoutControls = Config.LayoutControls
local configWindow
local previewPane
local controlsPane
local scrollFrame
local scrollBar
local sessionSnapshot

local function SaveWindowPosition(window)
	local windowX, windowY = window:GetCenter()
	local parentX, parentY = UIParent:GetCenter()
	if windowX and windowY and parentX and parentY then
		db.windowOffsetX = addon.NormalizeSettingValue("windowOffsetX", windowX - parentX)
		db.windowOffsetY = addon.NormalizeSettingValue("windowOffsetY", windowY - parentY)
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
	end
end

local function CreateWindowTitle(window)
	local titleBar = CreateFrame("Frame", nil, window)
	titleBar:SetPoint("TOPLEFT", window, "TOPLEFT", 1, -1)
	titleBar:SetPoint("TOPRIGHT", window, "TOPRIGHT", -1, -1)
	titleBar:SetHeight(40)
	-- Above the preview badge, below the close button created at +100.
	titleBar:SetFrameLevel(window:GetFrameLevel() + 90)
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
end

local function CreateWindowFooter(window)
	-- Every footer control has to outrank the preview badge, which lives three levels
	-- deep inside the preview pane.
	local footerLevel = window:GetFrameLevel() + 100
	local footerBackground = window:CreateTexture(nil, "BACKGROUND")
	footerBackground:SetColorTexture(0.02, 0.03, 0.04, 0.98)
	footerBackground:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 1, 1)
	footerBackground:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -1, 1)
	footerBackground:SetHeight(50)

	local resetLayout = CreateButton(window, "Reset Layout", 88, function()
		addon:ResetLayoutSettings()
	end, "Restore position and size defaults immediately.")
	resetLayout:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 12, 13)
	resetLayout:SetFrameLevel(footerLevel)

	local resetAppearance = CreateButton(window, "Reset Appearance", 110, function()
		addon:ResetAppearanceSettings()
	end, "Restore typography, background, border, and color defaults immediately.")
	resetAppearance:SetPoint("LEFT", resetLayout, "RIGHT", 4, 0)
	resetAppearance:SetFrameLevel(footerLevel)

	local resetAll = CreateButton(window, "Reset All", 74, function()
		addon:ResetAllSettings()
	end, "Restore every display setting and enable the addon.")
	resetAll:SetPoint("LEFT", resetAppearance, "RIGHT", 4, 0)
	resetAll:SetFrameLevel(footerLevel)

	local done = CreateButton(window, "Done", 70, function()
		addon.CloseConfig()
	end, "Keep changes and close the editor.")
	done:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -12, 13)
	done:SetFrameLevel(footerLevel)

	local revert = CreateButton(
		window,
		"Revert",
		70,
		RestoreSession,
		"Restore the state captured when this editor session opened."
	)
	revert:SetPoint("RIGHT", done, "LEFT", -4, 0)
	revert:SetFrameLevel(footerLevel)
end

local function CreateWindowResizeGrip(window)
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
		db.windowWidth = addon.NormalizeSettingValue("windowWidth", window:GetWidth())
		db.windowHeight = addon.NormalizeSettingValue("windowHeight", window:GetHeight())
		SaveWindowPosition(window)
		ReflowWindow(window)
	end)
	AddTooltip(
		windowGrip,
		"Resize editor",
		string.format(
			"Resize between %d×%d and %d×%d.",
			settingDefinitions.windowWidth.minimum,
			settingDefinitions.windowHeight.minimum,
			settingDefinitions.windowWidth.maximum,
			settingDefinitions.windowHeight.maximum
		)
	)
end

local function AttachWindowScripts(window)
	function window.LayoutControls()
		LayoutControls(math.max(240, controlsPane:GetWidth() - 40))
	end
	Config.RelayoutControls = window.LayoutControls

	window:SetScript("OnSizeChanged", function(_, width, height)
		db.windowWidth = addon.NormalizeSettingValue("windowWidth", width)
		db.windowHeight = addon.NormalizeSettingValue("windowHeight", height)
		ReflowWindow(window)
	end)

	window:SetScript("OnShow", function()
		sessionSnapshot = addon:CaptureDisplaySettings()
		Config.ResetScenario(addon.playerIsTank)
		addon.configPreviewActive = true
		addon:ScanVisibleNameplates()
		ApplyPreviewVisuals()
		addon.UpdateAllNameplates()
	end)

	window:SetScript("OnHide", function(self)
		self:StopMovingOrSizing()
		Config.StopPreviewInteraction()
		FlushPendingChange()
		EndOwnedColorPicker()
		addon.configPreviewActive = false
		sessionSnapshot = nil
		addon.HideAllNameplates()
		addon.UpdateAllNameplates()
	end)

	window:SetScript("OnUpdate", function(self, elapsed)
		Config.AdvancePendingChange(elapsed)

		self.referenceRefreshElapsed = (self.referenceRefreshElapsed or 0) + elapsed
		if self.referenceRefreshElapsed < 0.5 then
			return
		end
		self.referenceRefreshElapsed = 0
		if Config.IsPreviewIdle() then
			ApplyPreviewVisuals()
		end
	end)
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
	window:SetResizeBounds(
		settingDefinitions.windowWidth.minimum,
		settingDefinitions.windowHeight.minimum,
		settingDefinitions.windowWidth.maximum,
		settingDefinitions.windowHeight.maximum
	)
	window:EnableMouse(true)
	window:Hide()
	UISpecialFrames[#UISpecialFrames + 1] = "ThreatPlatingConfigWindow"

	CreateWindowTitle(window)
	previewPane = Config.CreatePreview(window)
	controlsPane = Config.CreateControls(window)
	controlsPane, scrollFrame, scrollBar = Config.GetControlsFrames()
	CreateWindowFooter(window)
	CreateWindowResizeGrip(window)
	AttachWindowScripts(window)

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
	Config.SetSettingsEnabledCheck(enabled)

	local summary = CreateText(settingsFrame, "", "GameFontHighlightSmall")
	summary:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 4, -12)
	Config.SetSettingsStatusText(summary)

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
		anchorPresets = Config.anchorPresets,
		commitDraggedPosition = CommitDraggedPosition,
		endColorPicker = EndOwnedColorPicker,
		flush = FlushPendingChange,
		getControls = function()
			return Config.controls
		end,
		getPickerOwner = function()
			return Config.GetPickerOwner()
		end,
		getPreviewCanvas = function()
			return Config.GetPreviewCanvas()
		end,
		getPreviewBadge = function()
			return Config.GetPreviewBadge()
		end,
		getPreviewHealthBar = function()
			return Config.GetPreviewHealthBar()
		end,
		getPreviewHealthText = function()
			return Config.GetPreviewHealthText()
		end,
		getPreviewSourceText = function()
			return Config.GetPreviewSourceText()
		end,
		getPreviewUnitName = function()
			return Config.GetPreviewUnitName()
		end,
		getScrollBar = function()
			return scrollBar
		end,
		getScrollFrame = function()
			return scrollFrame
		end,
		getSections = function()
			return Config.sections
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
		saveWindowPosition = function()
			if configWindow then
				SaveWindowPosition(configWindow)
			end
		end,
		restoreSession = RestoreSession,
		setScenario = SetScenario,
		useAnchorPreset = UseAnchorPreset,
	}
end
