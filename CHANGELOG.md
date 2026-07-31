# Changelog

## 0.7.1 - 2026-07-31

- Split role detection, nameplate presentation, threat scheduling/lifecycle, and client probes
  into focused runtime modules with explicit internal interfaces.
- Split the configurator's preview mechanics, controls, and window integration so each module
  owns one frame-lifecycle boundary without changing saved settings or user behavior.
- Load the mocked runtime from the TOC during tests, keeping shipped-file order in one manifest.

## 0.7.0 - 2026-07-31

- Report an exact tie with an unqueryable reference actor as `+0` instead of the player's entire
  threat total. The raw percentage is now only treated as self-referential while the player is
  actually tanking, removing a discontinuity where 99.999999%, 100%, and 100.000001% produced
  `-1`, `+5k`, and `+1`.
- Read the nameplate unit token from `unitToken`, the field Blizzard's `NamePlateBaseMixin:SetUnit`
  actually writes, before the legacy `namePlateUnitToken` and `UnitFrame.unit` fallbacks.
- Keep `/threatplating test` from permanently re-enabling a disabled addon: the sample now flips
  the runtime flag only and restores the saved disabled state when the eight seconds expire.
- Print usage for unknown subcommands instead of silently toggling the configurator, so a typo can
  no longer close the editor.
- Stop a resize-grip press with no movement from ratcheting the saved minimum badge width up by the
  current text width on every touch.
- Keep the periodic editor refresh from overwriting a slider's edit box while it has keyboard focus,
  and restore an abandoned partial entry when focus is lost.
- End an open color-picker session before Reset Layout, Reset Appearance, Reset All, and Revert
  replace the color tables, so a later cancel cannot resurrect a discarded color.
- Disable the preview badge's hit box while it sits outside its canvas, and raise every footer
  button above it, so a badge placed at an extreme offset cannot swallow their clicks.
- Clear an in-flight preview drag when the editor is hidden mid-drag, which previously froze the
  passive baseline refresh until the next completed drag.
- Clear every mirrored text key between baseline reads, so a plate with no readable name is no
  longer drawn with the previous plate's font, offset, and color.
- Fail closed when the shapeshift API returns a non-numeric spell ID rather than silently grading
  bear druids and defensive-stance warriors as non-tanks.
- Refuse to install over the checkout itself, which previously deleted the working tree and its
  history when the checkout lived at the documented `Interface\AddOns\ThreatPlating` path.
- Validate the TOC manifest and load order, pin the toolchain to Lua 5.1, declare read-only
  Blizzard APIs as read-only, and route tank-role precedence through a single implementation.
- Add `/threatplating probe`, which prints the raw return tuples of every client API whose slot
  layout the addon depends on next to the addon's reading of each, so a client patch that shifts a
  slot is diagnosable immediately instead of appearing as inverted raid colors.
- Add `tools\link.ps1` to deploy the checkout as a junction for fast iteration, and document that it
  cannot coexist with the publishing guarantee that only pushed commits reach the client.
- Make `ThreatPlating.toc` the single source of truth for the shipped file set: `check.ps1` and
  `install.ps1` both derive their lists from it, `install.ps1` reads the manifest belonging to the
  revision it installs, and validation now fails if a root Lua file is missing from the TOC or a
  test suite on disk is never run.
- Teach the test mock the client's frame-template rules, so a backdrop call without
  `BackdropTemplate` or a misspelled template name fails locally instead of in game.
- Add a deterministic 600-step editor interaction fuzz pass covering the interleavings that produced
  four of this release's bugs, asserting after every step that no interaction can persist a setting
  startup validation would rewrite and that live color-picker edits reach the current database.

## 0.6.3 - 2026-07-31

- Preserve exact raw-threat ordering below one displayed threat unit, so a real contender lead can
  no longer be hidden by the former comparison tolerance while compact formatting remains unchanged.
- Fail closed when legacy talent or shapeshift APIs return malformed numeric values, and extend the
  raid suite across early add events, queued recycling, sustained event pressure, party/pet source
  topology, restricted recovery, and scheduler-state bounds.
- Normalize saved configurator window offsets and expand automated coverage across all saved
  settings, display controls, preview fallbacks, session restores, and independent close paths.
- Lint every Lua test, enforce synchronized client/source metadata, validate clean `main` before
  publishing, and make local installation stage-verified and rollback-capable.

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
