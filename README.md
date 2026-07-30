# Threat Plating

Threat Plating is a focused World of Warcraft: The Burning Crusade Anniversary addon for the
new default enemy nameplates.

For every visible, attackable NPC with meaningful threat data, it shows:

- `+x` when you have the highest threat. `x` is your lead over the highest queryable contender.
- `-x` when you are behind. `x` is the gap to the threat lead.

Colors adapt to your detected role: tanks see a safe lead in green and a deficit in red, while
non-tanks see a safe deficit in green and taking the lead in red. Explicit group/raid tank
assignments take priority. Otherwise, the addon detects Protection paladin and warrior talent
builds, warrior Defensive Stance, and druid Bear or Dire Bear Form. Feral druids therefore switch
between tank colors in bear form and non-tank colors in cat or caster form.

Orange is a role-independent warning: your raw threat is already above the enemy's current target,
but you have not crossed the aggro pull threshold yet. That threshold depends on distance, not
class—110% in melee range and 130% outside melee range. Threat Plating uses the API's scaled
percentage, which normalizes the currently applicable threshold to 100%, so the warning responds
when you move between melee and ranged distance. The sign and number still describe the raw threat
lead or deficit.

The counter sits immediately to the right of the health bar in a high-contrast badge. Player and
player-controlled nameplates are excluded.

## Current status

This repository contains a working `0.5.1` addon targeting TBC Anniversary client
`2.5.6.68941` (`## Interface: 20506`).

Reliability is handled in two layers:

- Nameplate-specific threat events refresh only the affected visible plate, capped at 20 times per
  second.
- An independent 0.20-second poll catches missed or coalesced events and reconciles recycled
  nameplates even while threat events are firing continuously.

When you are below the lead, the addon uses the API's raw percentage to infer the leader even when
that actor does not have a party or raid token. When you are leading—or have zero threat—it queries
party/raid members, their pets, your pet, and the enemy's current target. Aggro ownership does not
override the raw-threat comparison during taunts or fixates. Contender scans retain only the
highest raw threat, avoiding per-plate list allocation.

## Install for development

1. Name the checkout folder `ThreatPlating`.
2. Put it in:
   `World of Warcraft\_anniversary_\Interface\AddOns\ThreatPlating`
3. Start or reload the game.
4. Ensure **Threat Plating** is enabled in the AddOns list.

For the client detected while this project was created, the full path would be:

`D:\World of Warcraft\_anniversary_\Interface\AddOns\ThreatPlating`

Commands:

- `/threatplating` — open the visual configurator.
- `/threatplating test` — show a sample `+12.3k` badge for eight seconds on eligible visible plates.
- `/threatplating test orange` — show the orange threshold-warning variant for eight seconds.
- `/threatplating status`
- `/threatplating on`
- `/threatplating off`
- `/threatplating reset`
- `/threatplating close`

The configurator is also available from **Options → AddOns → Threat Plating** and the AddOn
Compartment. It reflows from a stacked layout at narrow sizes to preview-and-controls columns at
wide sizes. The window, preview badge, and badge resize grip remain directly movable.

The live editor provides:

- A baseline mirrored from the current visible target plate—or another eligible visible plate—
  including its health-bar dimensions, texture/color/fill, labels, fonts, and label placement. The
  verified 128 × 20 modern nameplate remains the fallback when no suitable plate is visible.
- Tank/non-tank and safe/danger/warning preview scenarios, also shown on eligible real plates.
- Nine health-bar anchor presets, direct badge dragging, and exact X/Y entry.
- Independent minimum width, height, automatic width, horizontal padding, and 8–32 point text.
- Nameplate, UI, and combat-number Blizzard font presets plus optional text shadow.
- Background RGB/opacity and semantic, custom, or disabled borders.
- Default, Blue/Vermilion/Yellow, Cyan/Magenta/Yellow, and custom threat palettes.
- Reset Layout, Reset Appearance, Reset All, Revert, and Done actions.

Changes apply live and save account-wide. Ordinary closing keeps them. Revert restores the display
settings and enabled state captured when the current editor session opened without moving or
resizing the editor. Options → AddOns intentionally stays compact: it synchronizes the enabled
state, reports current role/status, and opens the full editor.

Close it with the title-bar X, the footer Done button, Escape, `/threatplating close`, or by running
`/threatplating` again.

While the configurator is open, eligible nameplates currently visible in the world show the same
sample counter. Layout changes therefore update both the mock nameplate and the actual frames
immediately.

## Important API limitation

WoW exposes threat for a specified source unit and enemy unit; it does not expose an enumerable
complete threat table. The result is exact for queryable group members and their pets. An unrelated
outside actor that is neither inferable from your raw percentage nor available as the enemy's
current target can be invisible to addons. This is an API boundary, not something polling faster
can solve.

The badge stays hidden when the API provides no meaningful threat data.

## Development

Run all local checks from PowerShell:

```powershell
.\tools\check.ps1
```

The checks require Lua 5.1, `luac`, and `luacheck`. They cover pure threat math plus a mocked
nameplate lifecycle smoke test.

See [AGENTS.md](AGENTS.md) for architecture and contribution invariants, and
[docs/TESTING.md](docs/TESTING.md) for the in-game test matrix.

## Source references

The implementation was checked against the extracted UI source for live build `2.5.6.68941`:

- [UnitDetailedThreatSituation API signature](https://github.com/Gethe/wow-ui-source/blob/d6a72ea3cb1942f84396b8cc34de9435fe5c7293/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- [Blizzard threat-color behavior](https://github.com/Gethe/wow-ui-source/blob/d6a72ea3cb1942f84396b8cc34de9435fe5c7293/Interface/AddOns/Blizzard_UnitFrame/Shared/CompactUnitFrame.lua)
- [Classic aggro-threshold measurements](https://github.com/magey/classic-warrior/wiki/Threat-Mechanics#aggro-thresholds)
- [Nameplate lifecycle events](https://github.com/Gethe/wow-ui-source/blob/d6a72ea3cb1942f84396b8cc34de9435fe5c7293/Interface/AddOns/Blizzard_APIDocumentationGenerated/NamePlateManagerDocumentation.lua)
- [TBC Anniversary default nameplate frame](https://github.com/Gethe/wow-ui-source/blob/d6a72ea3cb1942f84396b8cc34de9435fe5c7293/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlateUnitFrame.lua)
- [Frame movement and resize APIs](https://github.com/Gethe/wow-ui-source/blob/d6a72ea3cb1942f84396b8cc34de9435fe5c7293/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua)
- [AddOn Settings canvas integration](https://github.com/Gethe/wow-ui-source/blob/d6a72ea3cb1942f84396b8cc34de9435fe5c7293/Interface/AddOns/Blizzard_Settings_Shared/Blizzard_ImplementationReadme.lua)
- [Classic color-picker ownership API](https://github.com/Gethe/wow-ui-source/blob/d6a72ea3cb1942f84396b8cc34de9435fe5c7293/Interface/AddOns/Blizzard_FrameXML/Classic/ColorPickerFrame.lua)
