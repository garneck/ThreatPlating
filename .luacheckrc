std = "lua51"
max_line_length = 120

-- Blizzard APIs the addon only ever reads. Declaring them read-only means an
-- accidental assignment to a client global is a lint error instead of a live taint
-- or a broken UI for everyone running the addon.
read_globals = {
	"C_NamePlate",
	"CreateFrame",
	"GameTooltip",
	"GetBuildInfo",
	"GetNumGroupMembers",
	"GetNumSubgroupMembers",
	"GetNumTalentTabs",
	"GetPartyAssignment",
	"GetShapeshiftForm",
	"GetShapeshiftFormInfo",
	"GetTalentTabInfo",
	"GetTime",
	"IsInGroup",
	"IsInRaid",
	"PlayerUtil",
	"Settings",
	"UIParent",
	"UnitCanAttack",
	"UnitClass",
	"UnitDetailedThreatSituation",
	"UnitExists",
	"UnitGroupRolesAssigned",
	"UnitIsPlayer",
	"UnitIsUnit",
	"UnitPlayerControlled",
	"wipe",
}

-- The only globals Threat Plating is allowed to write: its own saved variables and
-- entry points, plus Blizzard's shared color picker, whose callback fields the
-- configurator owns while its session is active.
globals = {
	"ColorPickerFrame",
	"SLASH_THREATPLATING1",
	"SlashCmdList",
	"ThreatPlatingDB",
	"ThreatPlating_OnAddonCompartmentClick",
	"UISpecialFrames",
}

-- The suites install the mocked client, so they define the whole surface.
files["tests/*.lua"] = {
	read_globals = {},
	globals = {
		"C_NamePlate",
		"ColorPickerFrame",
		"CreateFrame",
		"GameTooltip",
		"GetBuildInfo",
		"GetNumGroupMembers",
		"GetNumSubgroupMembers",
		"GetNumTalentTabs",
		"GetPartyAssignment",
		"GetShapeshiftForm",
		"GetShapeshiftFormInfo",
		"GetTalentTabInfo",
		"GetTime",
		"IsInGroup",
		"IsInRaid",
		"PlayerUtil",
		"SLASH_THREATPLATING1",
		"Settings",
		"SlashCmdList",
		"ThreatPlatingDB",
		"ThreatPlating_OnAddonCompartmentClick",
		"UIParent",
		"UISpecialFrames",
		"UnitCanAttack",
		"UnitClass",
		"UnitDetailedThreatSituation",
		"UnitExists",
		"UnitGroupRolesAssigned",
		"UnitIsPlayer",
		"UnitIsUnit",
		"UnitPlayerControlled",
		"wipe",
	},
}
