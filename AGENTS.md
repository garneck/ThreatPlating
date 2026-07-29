# Threat Plating project guidance

## Product contract

Threat Plating augments Blizzard's default TBC Anniversary enemy NPC nameplates. Keep the addon
small, dependency-free, readable under pressure, and safe to enable in raids.

The counter semantics are fixed:

- Green `+x`: the player has the highest observed/inferred raw threat; `x` is the lead over the
  highest other queryable actor.
- Red `-x`: another actor leads; `x` is the player's deficit to that lead.
- The player's pet remains a separate threat actor. Do not merge pet threat into player threat.
- Hide the badge when no meaningful threat data exists.
- Never show on players or player-controlled units.

Do not describe the result as a guaranteed complete server threat table. The API is query-by-unit
and cannot enumerate unrelated actors.

## Supported client

- Product: World of Warcraft: The Burning Crusade Anniversary
- Verified build: `2.5.6.68941`
- TOC interface: `20506`
- Verified UI source commit: `d6a72ea3cb1942f84396b8cc34de9435fe5c7293`

When the client patches, check `.build.info`, update the extracted UI source, verify the three API
references in `README.md`, and only then change `## Interface`.

## Architecture

- `Init.lua`: addon identity and slash commands.
- `Threat.lua`: pure threat math, scan decision, and compact number formatting.
- `Nameplates.lua`: Blizzard API calls, roster cache, plate lifecycle, polling, and rendering.
- `Config.lua`: saved layout editor, draggable/resizable preview, Settings category, and AddOn
  Compartment integration.
- `tests/test_threat.lua`: Lua 5.1 tests for all pure logic.
- `tests/test_runtime.lua`: mocked nameplate lifecycle smoke test.

Keep calculations in `Threat.lua` so they remain runnable outside WoW. Keep all frame and unit-token
access in `Nameplates.lua`.

## Reliability invariants

1. Use `NAME_PLATE_UNIT_ADDED` and `NAME_PLATE_UNIT_REMOVED` as the primary lifecycle.
2. Retain the 0.20-second poll as a correctness fallback.
3. Refresh quickly after `UNIT_THREAT_LIST_UPDATE` and `UNIT_THREAT_SITUATION_UPDATE`, but cap
   event-driven refresh frequency.
4. Treat nameplates as pooled/recycled. Store the current unit on the addon overlay and verify it
   before rendering.
5. Keep event, threat, preview, and overlay frames unnamed. The named configurator window is the
   sole exception so it can participate in `UISpecialFrames` and close reliably with Escape. Do not
   replace scripts on Blizzard frames; `HookScript` is permitted only for cleanup.
6. Attach a child overlay. Never resize, reparent, recolor, or otherwise mutate the Blizzard
   health bar.
7. Anchor first to `UnitFrame.HealthBarsContainer` for the 2.5.6 modern plate, with compatibility
   fallbacks for `healthBar`, `Health`, and Plater.
8. Guard `UnitDetailedThreatSituation` with `pcall`, and hide rather than emit errors when values
   are unavailable or restricted.
9. Apply configurator changes through `addon.ApplyDisplaySettings()` so existing pooled overlays
   are re-anchored and restyled in place.

## Configuration invariants

- `/threatplating` with no subcommand opens the configurator.
- Keep five independent close paths working: title X, footer button, Escape, slash `close`, and
  slash toggle.
- The configurator and its preview badge remain movable and resizable.
- Badge drag completion must resolve back to a Blizzard anchor pair plus x/y offsets; do not save
  absolute screen coordinates for nameplate placement.
- Size the mock health bar from a currently visible anchor when available; use the verified
  128 × 20 modern nameplate dimensions as the fallback.
- While the configurator is visible, real eligible plates use the sample value so layout feedback
  is immediate.
- Persist settings in `ThreatPlatingDB` and validate every saved numeric value during startup.
- Configuring the addon must never make Blizzard nameplates mouse-interactive or movable.
- Clip the draggable preview to its canvas so it cannot cover or intercept window controls.

## Threat math

TBC Anniversary raw threat is divided by 100 before display. This matches the live client's
Classic threat behavior and must be reverified on client updates.

To avoid a group-size × plate-count scan on every tick:

- When the player is clearly below the lead, infer the reference lead from
  `playerThreat * 100 / rawPercentage`.
- Scan group contenders when the player is tanking, is at least 99.5% of the reference, has zero
  threat, or receives incomplete percentage data.
- During a scan, include party/raid members, group pets, the player's pet, and the enemy's current
  target.

Any optimization must preserve the zero-threat `-x` case and the leading `+x` runner-up case.

## Performance budget

- Do not create frames or persistent tables in the normal per-plate update path.
- A short-lived contender list is currently acceptable only on scan-required plates.
- Do not poll faster than 0.10 seconds without profiling a 40-player raid and 40 visible plates.
- Prefer inference when safely below the lead.

## Validation before handoff

Always run:

```powershell
.\tools\check.ps1
```

Then follow the relevant sections of `docs/TESTING.md`. A change to lifecycle, threat calculation,
formatting, anchoring, or configuration requires in-game validation; local Lua tests cannot fully
simulate Blizzard frame pooling, mouse-driven movement, or unit-token availability.

For user-facing behavior changes, update `README.md`, `CHANGELOG.md`, and the TOC version together.
