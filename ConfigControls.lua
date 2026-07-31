local _, addon = ...

local Config = addon.ConfigPrivate
local db = addon.db
local Clamp = addon.Clamp
local Round = addon.Round
local BACKDROP = addon.BACKDROP
local settingDefinitions = addon.settingDefinitions
local ANCHOR_PRESETS = Config.anchorPresets
local controls = Config.controls
local sections = Config.sections
local CreateText = Config.CreateText
local AddTooltip = Config.AddTooltip
local CreateButton = Config.CreateButton
local SetButtonSelected = Config.SetButtonSelected
local SetControlEnabled = Config.SetControlEnabled
local QueueDisplayChange = Config.QueueDisplayChange
local FlushPendingChange = Config.FlushPendingChange
local OpenColorPicker = Config.OpenColorPicker
local UseAnchorPreset = Config.UseAnchorPreset
local controlsPane
local scrollFrame
local scrollBar
local scrollChild

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
		if Config.RelayoutControls then
			Config.RelayoutControls()
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
	Config.SetStatusText(label)
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
		if Config.IsRefreshingControls() then
			return
		end
		value = NormalizeSliderValue(value, minimum, maximum, step)
		setter(value)
		edit:SetText(FormatValue(value))
		QueueDisplayChange(changeKind, false)
	end)
	slider:SetScript("OnMouseUp", function()
		if not Config.IsRefreshingControls() then
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
	edit:SetScript("OnEditFocusLost", RestoreEdit)

	local control = {
		edit = edit,
		frame = row,
		label = label,
		slider = slider,
	}
	function control:refresh()
		local value = getter()
		self.slider:SetValue(value)
		-- The window refreshes every 0.5s on a cadence the user cannot influence,
		-- so an in-progress keyboard entry must survive it.
		if not (self.edit.HasFocus and self.edit:HasFocus()) then
			self.edit:SetText(FormatValue(value))
		end
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

local function CreateSettingCheckRow(section, key, labelText, tooltip, changeKind)
	return CreateCheckRow(
		section,
		labelText,
		tooltip,
		function()
			return db[key]
		end,
		function(checked)
			db[key] = checked
			QueueDisplayChange(changeKind, true)
		end
	)
end

local function CreateSettingSliderRow(section, key, labelText, tooltip, changeKind)
	local definition = settingDefinitions[key]
	return CreateSliderRow(
		section,
		labelText,
		tooltip,
		definition.minimum,
		definition.maximum,
		definition.step,
		function()
			return db[key]
		end,
		function(value)
			db[key] = value
		end,
		changeKind
	)
end

local function CreateSettingChoiceRow(
	section,
	key,
	labelText,
	tooltip,
	changeKind,
	height
)
	return CreateChoiceRow(
		section,
		labelText,
		tooltip,
		settingDefinitions[key].choices,
		function()
			return db[key]
		end,
		function(value)
			db[key] = value
		end,
		changeKind,
		height
	)
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

local function CreateGeneralSection(parent)
	local section = CreateSection(parent, "general", "General")
	CreateCheckRow(
		section,
		"Enable threat counters",
		"Synchronizes the addon’s enabled state everywhere.",
		function()
			return addon.enabled
		end,
		function(checked)
			addon:SetEnabled(checked)
		end
	)
	CreateSettingCheckRow(
		section,
		"smoothTransitions",
		"Smooth number transitions",
		"Animate changes between live values. Sign changes still update immediately.",
		"behavior"
	)
	CreateInfoRow(section)
end

local function CreatePositionSection(parent)
	local section = CreateSection(parent, "position", "Position & Size")
	CreateAnchorGrid(section)
	CreateSettingSliderRow(
		section,
		"offsetX",
		"Horizontal offset",
		"Exact horizontal distance from the selected health-bar anchor.",
		"layout"
	)
	CreateSettingSliderRow(
		section,
		"offsetY",
		"Vertical offset",
		"Exact vertical distance from the selected health-bar anchor.",
		"layout"
	)
	CreateSettingSliderRow(
		section,
		"badgeWidth",
		"Minimum width",
		"The badge never becomes narrower than this value.",
		"layout"
	)
	CreateSettingSliderRow(
		section,
		"badgeHeight",
		"Height",
		"Badge height. This does not change the font size.",
		"layout"
	)
	CreateSettingCheckRow(
		section,
		"autoWidth",
		"Expand width for long values",
		"Allow formatted counters to grow beyond the minimum width.",
		"layout"
	)
	CreateSettingSliderRow(
		section,
		"padding",
		"Horizontal padding",
		"Space added to both sides of automatically sized text.",
		"layout"
	)
end

local function CreateTypographySection(parent)
	local section = CreateSection(parent, "typography", "Typography")
	CreateSettingSliderRow(
		section,
		"fontSize",
		"Font size",
		"Text size, independent of badge height.",
		"style"
	)
	CreateSettingChoiceRow(
		section,
		"fontPreset",
		"Blizzard font preset",
		"Use a stock Blizzard font object; no fonts are bundled.",
		"style"
	)
	CreateSettingCheckRow(
		section,
		"shadow",
		"Text shadow",
		"Draw the stock one-pixel text shadow.",
		"style"
	)
end

local function CreateAppearanceSection(parent)
	local section = CreateSection(parent, "appearance", "Appearance")
	CreateColorRow(
		section,
		"Background color",
		"Choose the badge background color.",
		"backgroundColor",
		true
	)
	CreateSliderRow(
		section,
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
	CreateSettingChoiceRow(
		section,
		"borderMode",
		"Border mode",
		"Semantic follows the threat color; custom uses one fixed color.",
		"style"
	)
	CreateColorRow(
		section,
		"Custom border",
		"Choose the fixed custom border color and opacity.",
		"borderColor",
		true,
		function()
			return db.borderMode == "custom"
		end
	)
end

local function CreateThreatColorsSection(parent)
	local section = CreateSection(parent, "colors", "Threat Colors")
	CreateSettingChoiceRow(
		section,
		"palette",
		"Palette",
		"Palette changes presentation only; safe, danger, and warning meanings stay fixed.",
		"style",
		86
	)
	CreateColorRow(
		section,
		"Custom safe",
		"Color for the role-appropriate safe state.",
		"safeColor",
		false,
		function()
			return db.palette == "custom"
		end
	)
	CreateColorRow(
		section,
		"Custom danger",
		"Color for the role-appropriate dangerous state.",
		"dangerColor",
		false,
		function()
			return db.palette == "custom"
		end
	)
	CreateColorRow(
		section,
		"Custom warning",
		"Role-independent pull-threshold warning color.",
		"warningColor",
		false,
		function()
			return db.palette == "custom"
		end
	)
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

	CreateGeneralSection(child)
	CreatePositionSection(child)
	CreateTypographySection(child)
	CreateAppearanceSection(child)
	CreateThreatColorsSection(child)

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


Config.CreateControls = CreateControls
Config.LayoutControls = LayoutControls

function Config.GetControlsFrames()
	return controlsPane, scrollFrame, scrollBar
end
