# Threat Plating project guidance

## Product contract

Threat Plating augments Blizzard's default TBC Anniversary enemy NPC nameplates. Keep the addon
small, dependency-free, readable under pressure, and safe to enable in raids.

The counter semantics are fixed:

- `+x`: the player has the highest observed/inferred raw threat; `x` is the lead over the highest
  other queryable actor.
- `-x`: another actor leads; `x` is the player's deficit to that lead.
- For a detected tank, green means the player is actually tanking and red means aggro has been
  lost; the sign remains an independent raw-threat comparison.
- For a detected non-tank, green means the player is below the scaled pull threshold and red means
  the player is tanking or has reached that threshold; the sign remains independent.
- Orange overrides the role color while the player has more raw threat than the enemy's current
  target but remains below the distance-scaled aggro pull threshold.
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

When the client patches, check `.build.info`, update the extracted UI source, verify every pinned
UI-source reference in `README.md` (`tools\check.ps1` enforces a floor and that all of them point at
the verified commit), and only then change `## Interface`.

Positional multi-return APIs are the highest-risk client dependency, because the mock cannot
disagree with the code. `/threatplating probe` prints the raw tuples next to the addon's reading of
them; run it first when anything looks wrong after a patch. Re-verify these slot layouts against the
pinned source on every client update:

- `GetShapeshiftFormInfo(index)` → `texture, isActive, isCastable, spellID`
- `GetTalentTabInfo(index)` → `specId, name, description, icon, pointsSpent, ...`
- The nameplate base frame stores its unit token in `unitToken` (`NamePlateBaseMixin:SetUnit`), not
  `namePlateUnitToken`, which is only a Blizzard parameter name.

## Architecture

- `Init.lua`: addon identity, the saved-setting schema, validation, migration, the
  snapshot/restore/reset API, and slash commands.
- `Threat.lua`: pure threat math, safety-state selection, and compact number formatting.
- `Display.lua`: shared palette, typography, backdrop, and badge rendering helpers.
- `Role.lua`: guarded Blizzard role, form, stance, and talent signals; delegates precedence to
  `Threat.IsTankRole`.
- `NameplateView.lua`: pooled overlay creation, nameplate token/health-bar compatibility, badge
  presentation, and configurator reference-visual capture.
- `Nameplates.lua`: eligible-unit tracking, threat-source roster, query validation, lifecycle,
  and bounded urgent/poll scheduling.
- `Diagnostics.lua`: positional-API and nameplate-shape reporting for `/threatplating probe`.
- `Config.lua`: configurator preview interactions and the private configurator interface.
- `ConfigControls.lua`: settings control construction, sections, and scroll layout.
- `ConfigWindow.lua`: editor window lifecycle, Settings category, and AddOn Compartment entry.
- `tests/test_threat.lua`: Lua 5.1 tests for all pure logic.
- `tests/test_database.lua`: isolated saved-variable migration and persistence coverage.
- `tests/wow_mock.lua`: fresh mocked WoW globals and mutable runtime state per fixture.
- `tests/test_runtime.lua`: mocked nameplate lifecycle smoke test.
- `tests/test_raid.lua`: deterministic 25-player, 25-pet, 40-nameplate correctness and scheduler
  budget suite.
- `tools/Common.ps1`: shared TOC manifest parsing and AddOns path resolution for the other scripts.
- `tools/link.ps1`: development junction from the client's `AddOns\ThreatPlating` to the checkout.

The mocks exist to reproduce the client, not the code. When a test and the pinned UI source
disagree about an API's shape, the mock is wrong. `tests/wow_mock.lua` therefore enforces the
client's template rules: `SetBackdrop` and friends error without `BackdropTemplate`, and an unknown
template name is rejected outright.

`ThreatPlating.toc` is the single source of truth for the shipped file set and its load order.
`check.ps1`, `install.ps1`, and the mocked-runtime loader derive their file lists or execution
order from it; do not add another copy. `install.ps1` reads the TOC of the revision it installs,
not the working tree.

The end of `tests/test_runtime.lua` runs a deterministic interaction fuzz pass. It exists because
refresh-during-typing, resize-during-refresh, reset-during-picker, and hide-during-drag were all
shipped bugs that per-mechanism tests structurally cannot find. When adding an editor mechanism, add
it as a fuzz action too, and mark it `needsVisibleEditor` if the client would only deliver it to a
visible frame.

Keep calculations in `Threat.lua` so they remain runnable outside WoW; it must contain no frame or
unit access, and its `IsFiniteNumber` stays a local copy so `tests/test_threat.lua` can load the
file without `Init.lua`. Keep unit-token compatibility and per-plate frame management in
`NameplateView.lua`; keep Blizzard nameplate lifecycle calls in `Nameplates.lua`. `Display.lua`
and the three `Config*.lua` modules may call frame APIs, but only on frames handed to them or
created by them.

Tank-role precedence lives only in `Threat.IsTankRole`. `Role.lua` gathers the signals and
passes them in; it must not re-implement any prefix of that decision order.

## Reliability invariants

1. Use `NAME_PLATE_UNIT_ADDED` and `NAME_PLATE_UNIT_REMOVED` as the primary lifecycle.
2. Retain the 0.10-second poll as a correctness fallback.
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
10. Queue real threat refreshes, prioritize affected threat-event plates, and process at most five
    complete plates per frame.

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
- Clip the draggable preview to its canvas and disable its hit box while it is out of bounds, so it
  can neither cover nor intercept window controls. `SetClipsChildren` only clips rendering.
- Keep every window control above the preview badge, which sits three frame levels deep inside the
  preview pane.
- Never read committed geometry back out of the preview badge. Its width is the auto-width result,
  not the configured minimum; only genuine size changes may write `badgeWidth`/`badgeHeight`.
- Do not overwrite an edit box that currently has keyboard focus.
- End an owned color-picker session before any bulk replacement of the color tables.
- `/threatplating test` may flip the runtime enabled flag but must never write `db.enabled`.

## Threat math

TBC Anniversary raw threat is divided by 100 before display. This matches the live client's
Classic threat behavior and must be reverified on client updates.

Aggro changes targets above 110% raw threat in melee range and 130% outside melee range. Use the
API's `scaledPercentage` rather than duplicating range checks: it normalizes the applicable pull
threshold to 100%. The orange warning bracket requires `rawPercentage > 100`,
`scaledPercentage < 100`, and `isTanking == false`.

Every due plate scans all existing party/raid members, group pets, the player's separate pet, and a
non-duplicate enemy target before selecting the highest contender. The API percentage may still
infer a higher reference actor that has no queryable unit token, but it must never replace an exact
higher observable actor. Preserve the zero-threat `-x` case and the leading `+x` runner-up case.

When usable, `rawPercentage` is the player's threat as a percentage of the current tank's threat.
The verified 2.5.6 client can instead return exactly 255 for a sole actor that is tanking; treat
that exact value as an unusable self-reference sentinel only while `isTanking` is true. Exactly
100% likewise means the player *is* the reference actor only while `isTanking` is true. A
non-tanking player at exactly 100% is tied with a distinct actor and must read `+0`, not the
player's whole threat total. Suppressing the inference on the percentage alone reintroduces a
discontinuity where 99.999999%, 100%, and 100.000001% report `-1`, `+5k`, and `+1`.

Treat a completely nil threat tuple as valid zero threat. Hide the badge if the player query fails,
any required query is restricted or malformed, or the resulting table has no meaningful threat.

## Performance budget

- Do not create frames or persistent tables in the normal per-plate update path.
- Process at most five complete plate scans per frame. With 25 raid members and 25 raid pets, this
  is at most 255 threat calls per frame including one outsider target per plate.
- Do not poll faster than 0.10 seconds without profiling a 40-player raid and 40 visible plates.
- Reuse urgent and poll queues; do not allocate frames or persistent tables per refresh.

## Validation before handoff

Always run:

```powershell
.\tools\check.ps1
```

Then follow the relevant sections of `docs/TESTING.md`. A change to lifecycle, threat calculation,
formatting, anchoring, or configuration requires in-game validation; local Lua tests cannot fully
simulate Blizzard frame pooling, mouse-driven movement, or unit-token availability.

For user-facing behavior changes, update `README.md`, `CHANGELOG.md`, and the TOC version together.

## Local deployment after push

Use the project wrapper for every push from this checkout:

```powershell
.\tools\push.ps1
```

The wrapper pushes the current branch and, only after the remote branch matches the pushed commit,
replaces `ThreatPlating` in the local TBC Anniversary `Interface\AddOns` directory. It installs
the TOC and its declared runtime Lua files from the pushed commit, so uncommitted work is never
deployed by a push. If a push is performed without the wrapper, immediately run
`.\tools\install.ps1 -Revision
HEAD`.

The checkout must live outside `Interface\AddOns`. `install.ps1` refuses to install over itself,
but the guard exists because the install replaces the destination directory and then deletes the
copy it moved aside.

`tools\link.ps1` offers a junction instead of a copy for fast iteration. It cannot coexist with
publishing: `install.ps1` refuses to replace a link, so `push.ps1` cannot complete while one is in
place. Run `.\tools\link.ps1 -Remove` before publishing.

## Publishing

- Commit and push completed work directly to `main`.
- Do not create feature branches or pull requests.
- Use `.\tools\push.ps1` for the push so the exact `main` commit is installed into WoW afterward.
