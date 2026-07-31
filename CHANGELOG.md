# Changelog

## 0.6.2 - 2026-07-31

- Reduce the independent nameplate reconciliation fallback from 0.20 to 0.10 seconds so missed
  threat events and pooled-frame changes recover sooner during ordinary combat.
- Retain the five-plate per-frame scheduler cap, so the faster cadence increases update frequency
  without increasing the maximum amount of exact threat work performed in one frame.

## 0.6.1 - 2026-07-31

- Resolve threat events that identify the player or another threat actor back to that actor's
  current hostile target, instead of dropping them and waiting for the 0.20-second fallback poll.
- Keep direct hostile-unit events targeted, deduplicate actor/hostile aliases through the urgent
  queue, and retain the five-plate per-frame query budget.

## 0.6.0 - 2026-07-31

- Fix raid deficits by scanning every existing group member, group pet, player pet, and
  non-duplicate enemy target before using the API percentage to account for an unqueryable
  reference actor.
- Decouple color from the sign: tanks are green while actually tanking and red after losing aggro;
  non-tanks are green below the pull threshold and red while tanking or at/above it. Orange still
  overrides both roles inside the scaled pull-threshold warning bracket.
- Validate every required threat tuple, accept the API's valid nil-threat result as zero, and hide
  safely on restricted, malformed, or meaningless data.
- Resolve roles through main-tank and explicit assignments, form/stance rules, Blizzard's guarded
  effective-tank helper, and legacy talent trees in that order.
- Stagger exact work through reusable urgent and poll queues, deduplicate overlapping requests,
  verify pooled ownership when dequeuing, and cap processing at five complete plates per frame.
- Hide configurator samples immediately on close, then queue restoration of real threat values.
- Add a deterministic 25-player, 25-pet, 40-nameplate raid suite covering exact third-actor
  deficits, sign-independent safety colors, pets, aliases, roster changes, restrictions, recycling,
  event priority/coalescing, the 255-query frame budget, and stable scheduler/frame counts.

## 0.5.1 - 2026-07-30

- Preserve one database table identity through `ADDON_LOADED`, adopt the client's final
  SavedVariables table into it, and point `ThreatPlatingDB` back to the table held by the editor.
- Fix 0.5 settings reverting on `/reload` because the editor could mutate a startup table other
  than the global table serialized by WoW.
- Add runtime coverage for late SavedVariables replacement, legacy adoption, and subsequent editor
  mutations reaching the serialized global.

## 0.5.0 - 2026-07-30

- Replace the fixed configurator with a responsive Blizzard-native editor that reflows between
  side-by-side and stacked layouts from 520 × 520 through 1000 × 800.
- Derive the preview baseline from the current visible target nameplate when available, including
  its health texture/color/fill, dimensions, unit-name text, health text, fonts, colors, and text
  placement; follow target changes while the editor remains open.
- Add a pinned live preview, tank/non-tank and safe/danger/warning scenarios, nine health-bar anchor
  presets, exact numeric entry, independent badge and font sizing, and a scrollable controls pane.
- Add stock Blizzard font presets, text shadow, configurable padding, background RGB/opacity,
  semantic/custom/off borders, three built-in threat palettes, and fully custom semantic colors.
- Add versioned saved-variable migration and independent validation for every boolean, enum,
  numeric range, color component, collapsed section, and editor geometry field.
- Add Reset Layout, Reset Appearance, Reset All, Revert, and Done actions. Ordinary closing keeps
  live changes; Revert restores the display and enabled-state snapshot captured when the editor
  opened.
- Keep Options → AddOns lightweight with a synchronized enable control, detected-role summary, and
  Open Editor action.
- Coalesce continuous layout and style changes to 20 real-overlay restyles per second, commit final
  interaction values immediately, and avoid additional threat queries during styling.
- Track ownership of Blizzard's shared color picker and clean up only Threat Plating's active
  session.
- Preserve the 0.4.1 pooled-nameplate, targeted-refresh, restricted-query, and allocation
  reliability work.

## 0.4.1 - 2026-07-30

- Detach an existing NPC overlay immediately when Blizzard reassigns its pooled nameplate to a
  player or player-controlled unit, rather than waiting for the fallback reconciliation poll.
- Refresh only the affected visible plate after nameplate-specific threat events while retaining
  the independent 0.20-second correctness fallback.
- Eliminate per-scan contender-list allocation, reuse pooled overlay records and hide hooks, and
  skip unchanged text, width, and color assignments.
- Treat any truthy Classic main-tank assignment result as an explicit tank signal.
- Add adversarial runtime coverage for restricted threat queries, direct eligible-to-ineligible
  plate recycling, targeted refresh query counts, and unchanged render-state caching.

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
