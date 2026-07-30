local _, addon = ...

addon.BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Buttons\\WHITE8X8",
	edgeSize = 1,
}

addon.fontObjects = {
	combat = "NumberFontNormal",
	nameplate = "SystemFont_NamePlate_Outlined",
	ui = "GameFontNormal",
}

local PALETTES = {
	blue = {
		safe = { 0, 0.447, 0.698 },
		danger = { 0.835, 0.369, 0 },
		warning = { 0.941, 0.894, 0.259 },
	},
	cyan = {
		safe = { 0, 0.85, 0.85 },
		danger = { 1, 0.25, 0.75 },
		warning = { 1, 0.80, 0 },
	},
}

function addon:GetSemanticColor(isLeader, isPullThresholdWarning, isTank)
	if isTank == nil then
		isTank = self.playerIsTank
	end

	local semantic
	if isPullThresholdWarning then
		semantic = "warning"
	elseif self.Threat.IsDesiredState(isTank, isLeader) then
		semantic = "safe"
	else
		semantic = "danger"
	end

	local color
	if self.db.palette == "custom" then
		color = self.db[semantic .. "Color"]
	else
		local palette = PALETTES[self.db.palette]
		color = palette and palette[semantic] or self.defaults[semantic .. "Color"]
	end

	return color[1], color[2], color[3], semantic
end

function addon:ApplyBadgeStyle(badge, text)
	local db = self.db
	text:SetFontObject(self.fontObjects[db.fontPreset] or self.fontObjects.nameplate)
	text:SetTextHeight(db.fontSize)

	if db.shadow then
		text:SetShadowColor(0, 0, 0, 1)
		text:SetShadowOffset(1, -1)
	else
		text:SetShadowColor(0, 0, 0, 0)
		text:SetShadowOffset(0, 0)
	end

	badge:SetBackdropColor(
		db.backgroundColor[1],
		db.backgroundColor[2],
		db.backgroundColor[3],
		db.backgroundColor[4]
	)
end

function addon:GetBadgeWidth(text)
	if not self.db.autoWidth then
		return self.db.badgeWidth
	end

	return math.max(
		self.db.badgeWidth,
		math.ceil(text:GetStringWidth()) + self.db.padding * 2
	)
end

function addon:ApplyBadgeWidth(badge, text)
	badge:SetWidth(self:GetBadgeWidth(text))
end

function addon:ApplyThreatColor(
	badge,
	text,
	isLeader,
	isPullThresholdWarning,
	isTank
)
	local red, green, blue = self:GetSemanticColor(
		isLeader,
		isPullThresholdWarning,
		isTank
	)
	text:SetTextColor(red, green, blue, 1)

	if self.db.borderMode == "semantic" then
		badge:SetBackdropBorderColor(red, green, blue, 1)
	elseif self.db.borderMode == "custom" then
		local color = self.db.borderColor
		badge:SetBackdropBorderColor(color[1], color[2], color[3], color[4])
	else
		badge:SetBackdropBorderColor(0, 0, 0, 0)
	end
end
