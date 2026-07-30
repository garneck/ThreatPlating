# Changelog

## 0.4.0 - 2026-07-30

- Show an orange warning when the player has surpassed the enemy's current target in raw threat but
  remains below the aggro pull threshold.
- Use the API's scaled threat percentage so the warning automatically respects the 110% melee and
  130% ranged-distance thresholds without class or range guessing.
- Keep the signed raw-threat lead or deficit unchanged while orange temporarily overrides the
  tank/non-tank role color.
- Add `/threatplating test orange` for visual validation.

## 0.3.0 - 2026-07-30

- Detect tank intent from explicit group assignments, Protection talents, warrior Defensive
  Stance, and druid Bear or Dire Bear Form.
- Keep threat signs unchanged while making colors role-aware: green marks the desired threat state
  and red marks the dangerous state for the detected role.
- Refresh role colors immediately after role, talent, roster, and shapeshift changes.
- Show the detected tank or non-tank color mode in the configurator and status command.

## 0.2.2 - 2026-07-29

- Keep the 0.20-second fallback scan independent from event refreshes so sustained threat events
  cannot starve nameplate reconciliation.
- Verify every overlay against the API's current unit-to-nameplate mapping and clean up missed
  removal events or recycled plates.
- Stop nameplate scans and threat queries while the addon is disabled.
- Preserve raw-threat semantics during taunts and fixates by using valid reference percentages even
  while the player has aggro.
- Reject non-finite saved settings and threat values, keep the restored badge tall enough for its
  font, and improve compact rounding at sub-unit, `1k`, and `1m` boundaries.
- Clarify both the fallback poll and minimum event-refresh interval in `/threatplating status`.
- Expand mocked lifecycle coverage for event cadence, pooled frames, missed removals, disabled mode,
  and invalid saved variables.

## 0.2.1 - 2026-07-29

- Prevent the draggable preview badge from overlapping configurator controls.
- Raise the title and footer close buttons above editor content.
- Add Escape and `/threatplating close` as independent recovery paths.

## 0.2.0 - 2026-07-29

- Add a movable and resizable visual configurator opened by `/threatplating`.
- Add a draggable and resizable badge preview anchored to a 2.5.6 nameplate health-bar mock.
- Apply layout changes live to currently visible real nameplates.
- Persist anchor, offsets, dimensions, font size, background, automatic width, enabled state, and
  configurator placement.
- Register an Options → AddOns category and AddOn Compartment action.
- Add anchor presets, reset behavior, and configurator testing guidance.

## 0.1.0 - 2026-07-29

- Add signed threat lead/deficit badges to visible enemy NPC nameplates.
- Add group, pet, current-target, and raw-percentage threat resolution.
- Add event-driven refresh with a 0.20-second polling fallback.
- Add a temporary visual test command.
- Add Lua 5.1 tests, lint configuration, and in-game validation guidance.
