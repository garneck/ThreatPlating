# Threat Plating

Threat Plating is a focused World of Warcraft: The Burning Crusade Anniversary addon for the
new default enemy nameplates.

For every visible, attackable NPC with meaningful threat data, it shows:

- `+x` when you have the highest threat. `x` is your lead over the highest queryable contender.
- `-x` when you are behind. `x` is the gap to the threat lead.

Color describes aggro safety independently from that sign. Detected tanks are green while actually
tanking and red after losing aggro, even during taunts or fixates where raw-threat order can differ
from the current target. Detected non-tanks are green below the distance-scaled pull threshold and
red while tanking or at/above that threshold. Explicit group/raid assignments take priority.
Otherwise, the addon uses druid form and warrior stance, Blizzard's effective-tank helper, and then
legacy Protection talent detection when available. Bear and cat behavior remains form-specific.

Orange is a role-independent warning: your raw threat is already above the enemy's current target,
but you have not crossed the aggro pull threshold yet. That threshold depends on distance, not
class—110% in melee range and 130% outside melee range. Threat Plating uses the API's scaled
percentage, which normalizes the currently applicable threshold to 100%, so the warning responds
when you move between melee and ranged distance. The sign and number still describe the raw threat
lead or deficit.

The counter sits immediately to the right of the health bar in a high-contrast badge. Player and
player-controlled nameplates are excluded.

## Current status

This repository contains a working `0.7.1` addon targeting TBC Anniversary client
`2.5.6.68941` (`## Interface: 20506`).

Reliability is handled in two layers:

- Nameplate-specific threat events enter a deduplicated urgent queue; urgent batches begin no more
  than 20 times per second and run ahead of ordinary queued work.
- Actor-token threat events resolve the actor's current hostile target, so ordinary damage updates
  do not wait for the full fallback poll.
- An independent 0.10-second poll reconciles missed events and recycled nameplates into a reusable
  poll queue even while threat events are firing continuously.
- At most five complete plates are queried per frame. In a full 25-player raid with 25 pets this is
  at most 255 threat calls per frame, including a possible out-of-group target for each plate.

Every due plate queries every existing party/raid member, group pet, the player's separate pet, and
a non-duplicate enemy target before selecting the highest observable contender. The API's raw
percentage is retained only as a reference for a higher actor that has no queryable unit token.
That reference is treated as the player only while the player is actually tanking; a non-tanking
player at exactly 100% is tied with a distinct actor and reads `+0`.
Aggro ownership does not override the signed raw-threat comparison during taunts or fixates.
Contender scans retain only the highest raw threat and allocate no per-plate list.
Raw-threat ordering is exact before formatting, so even a sub-unit lead keeps the correct sign
while the displayed magnitude remains compact.

## Install for development

Keep the checkout **outside** `Interface\AddOns`. Both options below take `-AddOnsPath`, or read
`THREATPLATING_ADDONS_PATH`, when more than one client is installed.

**Fast iteration — link the checkout:**

```powershell
.\tools\link.ps1            # junction: AddOns\ThreatPlating -> this checkout
.\tools\link.ps1 -Remove
```

`/reload` then picks up working-tree edits with no copy step. This is deliberately incompatible with
publishing: while the link is in place `tools\install.ps1` refuses to replace it, so `tools\push.ps1`
cannot finish either. A link deploys the working tree — uncommitted work included — so the "a push
only ever deploys the pushed commit" guarantee cannot hold at the same time. Run `-Remove` before
publishing.

**Release-like — copy a specific version in:**

```powershell
.\tools\install.ps1                  # the working tree
.\tools\install.ps1 -Revision HEAD   # exactly that commit
```

It stages the file set declared by the TOC (of the revision being installed), replaces
`World of Warcraft\_anniversary_\Interface\AddOns\ThreatPlating` atomically, and rolls back on
failure. It refuses to run when the destination is the checkout itself, when the destination is a
link, and when the path is not a TBC Anniversary `Interface\AddOns` directory.

Then start or reload the game and ensure **Threat Plating** is enabled in the AddOns list.

Commands:

- `/threatplating` — open the visual configurator. Running it again closes it.
- `/threatplating test` — show a sample `+12.3k` badge for eight seconds on eligible visible plates.
  If the addon is currently off, the sample enables it for those eight seconds only and the saved
  disabled state comes back on expiry.
- `/threatplating test orange` — show the orange threshold-warning variant for eight seconds.
- `/threatplating status`
- `/threatplating probe` — print the raw return tuples of the client APIs whose slot layout this
  addon depends on, next to the addon's reading of each. Use it first when colors or counters look
  wrong after a client patch.
- `/threatplating on`
- `/threatplating off`
- `/threatplating reset`
- `/threatplating close`

Any other argument prints the command list rather than toggling the editor.

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
complete server threat table. The result is exact across successfully queryable group members,
their separate pets, the enemy target, and any higher reference inferable from the player's API
percentage. An unrelated outside actor that is neither inferable nor available through one of
those unit tokens can remain invisible to addons. This is an API boundary, not something polling
faster can solve.

The badge stays hidden when the API provides no meaningful threat data.

## Development

Run all local checks from PowerShell:

```powershell
.\tools\check.ps1
```

The checks require Lua 5.1 specifically, `luac`, and `luacheck`, and verify the toolchain version
rather than trusting it. They cover pure threat math, database migration/persistence, a mocked
nameplate/configurator lifecycle smoke test, a deterministic 600-step editor interaction fuzz pass,
and a deterministic 25-player, 25-pet, 40-nameplate raid scheduler suite. They lint every runtime and
test Lua file and keep the release, client build, interface, and pinned UI-source metadata
synchronized.

`ThreatPlating.toc` is the single source of truth for which Lua files ship and in what order.
The validation, mocked-runtime loader, and installer derive their file lists or execution order
from it. `check.ps1` fails if a Lua file in the repository root is missing from the TOC or if a
`tests/test_*.lua` suite is never run.

See [AGENTS.md](AGENTS.md) for architecture and contribution invariants, and
[docs/TESTING.md](docs/TESTING.md) for the in-game test matrix.

## Source references

The implementation was checked against the extracted UI source for live build `2.5.6.68941`:

- [UnitDetailedThreatSituation API signature](https://github.com/Gethe/wow-ui-source/blob/d6a72ea3cb1942f84396b8cc34de9435fe5c7293/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- [Blizzard threat-color behavior](https://github.com/Gethe/wow-ui-source/blob/d6a72ea3cb1942f84396b8cc34de9435fe5c7293/Interface/AddOns/Blizzard_UnitFrame/Shared/CompactUnitFrame.lua)
- [Classic aggro-threshold measurements](https://github.com/magey/classic-warrior/wiki/Threat-Mechanics#aggro-thresholds)
- [Nameplate lifecycle events](https://github.com/Gethe/wow-ui-source/blob/d6a72ea3cb1942f84396b8cc34de9435fe5c7293/Interface/AddOns/Blizzard_APIDocumentationGenerated/NamePlateManagerDocumentation.lua)
- [Nameplate unit-token field (`NamePlateBaseMixin:SetUnit` writes `unitToken`)](https://github.com/Gethe/wow-ui-source/blob/d6a72ea3cb1942f84396b8cc34de9435fe5c7293/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlateBase.lua)
- [`GetShapeshiftFormInfo` return slots (`texture, isActive, isCastable, spellID`)](https://github.com/Gethe/wow-ui-source/blob/d6a72ea3cb1942f84396b8cc34de9435fe5c7293/Interface/AddOns/Blizzard_ActionBar/Shared/StanceBar.lua)
- [`GetTalentTabInfo` deprecation shim (`pointsSpent` is the fifth return)](https://github.com/Gethe/wow-ui-source/blob/d6a72ea3cb1942f84396b8cc34de9435fe5c7293/Interface/AddOns/Blizzard_DeprecatedSpecialization/Deprecated_Specialization_TBC.lua)
- [TBC Anniversary default nameplate frame](https://github.com/Gethe/wow-ui-source/blob/d6a72ea3cb1942f84396b8cc34de9435fe5c7293/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlateUnitFrame.lua)
- [Frame movement and resize APIs](https://github.com/Gethe/wow-ui-source/blob/d6a72ea3cb1942f84396b8cc34de9435fe5c7293/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua)
- [AddOn Settings canvas integration](https://github.com/Gethe/wow-ui-source/blob/d6a72ea3cb1942f84396b8cc34de9435fe5c7293/Interface/AddOns/Blizzard_Settings_Shared/Blizzard_ImplementationReadme.lua)
- [Classic color-picker ownership API](https://github.com/Gethe/wow-ui-source/blob/d6a72ea3cb1942f84396b8cc34de9435fe5c7293/Interface/AddOns/Blizzard_FrameXML/Classic/ColorPickerFrame.lua)
