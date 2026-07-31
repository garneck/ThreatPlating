# In-game testing

## Fast smoke test

1. Deploy the checkout: `.\tools\link.ps1` for iteration, or `.\tools\install.ps1` for a copy. The
   two are mutually exclusive; the installer refuses to replace a link.
2. Enable Lua errors with `/console scriptErrors 1`.
3. Reload with `/reload`.
4. Turn on enemy nameplates.
5. Run `/threatplating test` near several attackable NPCs.
6. Run `/threatplating test orange`.
7. Run `/threatplating off`, then `/threatplating test`, then wait out the eight seconds.
8. Run `/threatplating stauts` and any other misspelling.

Expected: every eligible visible NPC plate gets a badge — the formatted sample for
`addon.sampleThreatDelta` — to the right of its health bar for eight seconds. It is green in tank
mode and red in non-tank mode. Friendly NPCs, players, and player-controlled pets do not get a
badge. The orange test uses orange text and border without changing layout or eligibility. A sample
requested while the addon is off says so, samples for eight seconds, and then returns to off; the
state survives `/reload`. A misspelled subcommand prints the command list and neither opens nor
closes the editor.

`.\tools\push.ps1` is the normal push command for this checkout. After a successful push, it calls
the installer with the pushed revision so the game never receives uncommitted files.

## Configurator

1. Run `/threatplating` with several enemy NPC plates visible.
2. Resize the window to 520 × 520, 1000 × 800, and several sizes around the wide/narrow breakpoint.
3. Repeat at the lowest supported UI scale and verify an old off-screen window position recovers.
4. Scroll every expanded controls section, then collapse and expand each section.
5. Target visible enemies using different current nameplate sizes, textures, colors, name
   placement, and health-text options. Switch targets while the editor remains open, then move all
   eligible plates out of range.
6. Select every Tank/Non-tank and Safe/Danger/Warning scenario combination.
7. Use all nine anchor presets. Drag the sample badge around the bar and enter exact X/Y values.
8. Resize the badge from its lower-right grip, then change font size independently. Also press and
   release the grip without moving the cursor several times in a row.
9. Exercise every slider by dragging and by keyboard entry, including invalid and boundary values.
   Type a partial value into an edit box, wait more than a second without pressing Enter, then
   finish typing. Repeat but click away instead of pressing Enter.
10. Try automatic width, padding, all font presets, text shadow, background RGB/opacity, all border
   modes, all palettes, and custom semantic colors.
11. Open and cancel the color picker, then open another addon's picker before closing this editor.
    Also open the picker and, while it is still open, press Reset Appearance, then cancel it.
12. Use Reset Layout, Reset Appearance, Reset All, and Revert. Move and resize the editor before
    Revert.
13. Drag the badge far outside the canvas, or set the vertical offset to about -230, then click the
    footer buttons underneath it. Press Escape mid-drag, then reopen the editor.
14. Close and reopen through the title X, footer Done, Escape, slash `close`, slash toggle,
    Options → AddOns, and AddOn Compartment.
15. Reload the UI.

Expected:

- All currently visible eligible plates show the selected signed sample and semantic color while
  the configurator is open.
- Wide layout places preview beside controls; narrow layout keeps preview above a scrollable
  controls pane. Reflow does not lose state or duplicate controls.
- The preview mirrors the current visible target plate and follows target/style changes without
  reparenting or modifying that Blizzard frame. It uses another eligible visible plate when the
  target has none, then the verified 128 × 20 fallback when no suitable plate exists.
- The status line identifies the detected role independently from the ephemeral preview role.
- Real plates update no more than 20 times per second during continuous edits and commit the final
  value immediately.
- Badge resizing never changes font size, and font changes never change badge height. A grip press
  with no cursor movement leaves the saved minimum width and height exactly where they were, no
  matter how many times it is repeated.
- A partially typed value survives the passive refresh; clicking away restores the saved value.
- Custom colors retain the fixed safe, danger, and warning meanings.
- Canceling restores the pre-picker color. Closing Threat Plating does not close a newer picker
  session owned by another addon. A reset while the picker is open ends the session, and a later
  cancel does not bring the discarded color back.
- A badge placed outside its canvas is invisible and does not intercept clicks; the footer buttons
  underneath it stay clickable. Escape mid-drag closes the editor cleanly and the preview resumes
  following the baseline when it is reopened.
- Reset actions apply immediately. Revert restores the session-open display and enabled state but
  preserves the editor's current size and position.
- Closing the configurator restores real threat values or hides plates without threat.
- Badge layout, appearance, collapsed sections, and configurator geometry survive `/reload`.
- Reset All restores a 44 × 18 badge, 14-point Nameplate font, seven-pixel horizontal padding,
  dark 90%-opaque background, semantic border, default colors, and a six-pixel right-side gap.
- Configuring never makes Blizzard nameplates draggable or mouse-interactive.
- The title X, footer Done button, Escape, `/threatplating close`, and slash toggle all close the
  window, even after dragging the preview badge against every canvas edge.

## Solo combat

Test without a pet and then with a pet:

1. Enter combat without attacking and let another queryable actor or pet establish threat.
2. Attack until behind the lead.
3. Overtake the lead.
4. Kill the target and repeat while rapidly switching targets.

Expected:

- No badge before meaningful threat exists.
- As a detected tank, green while actually tanking and red after losing aggro, independently of
  whether the raw-threat value is `+x` or `-x`.
- As a detected non-tank, green below the scaled pull threshold and red while tanking or at/above
  the threshold, independently of the sign.
- Orange while above the current target's raw threat but below the aggro pull threshold.
- No stale badge after a plate disappears or is recycled.
- Your pet is treated as a competing actor, not added to your threat.

## Aggro pull-threshold warning

Use a threat meter that exposes both raw and scaled percentages for comparison:

1. Let another player establish aggro and hold steady at 100% reference threat.
2. In melee range, increase your raw threat past 100% without reaching 110%.
3. Repeat from outside melee range, increasing raw threat past 100% without reaching 130%.
4. While between 110% and 130% at range, move into melee range.
5. Repeat during a taunt swap, then let the taunt expire.

Expected:

- The badge turns orange only while raw threat is above 100%, scaled threat is below 100%, and the
  enemy is not targeting the player.
- Both the 100–110% melee bracket and the 100–130% ranged bracket work; class does not determine
  which threshold applies.
- Moving into melee range updates within roughly 0.15 seconds under ordinary plate counts. If the
  move crosses the applicable pull threshold and aggro changes, orange clears.
- The displayed sign and magnitude continue to compare raw threat. Orange may therefore accompany
  either sign when another queryable contender is also above the current target.
- Taunts and fixates do not change raw-threat arithmetic; encounter targeting mechanics may delay
  or prevent the normal aggro transition.

## Role and specialization detection

1. On a warrior or paladin, swap between a Protection build and a non-tank build, then spend or
   remove a talent point to trigger a talent refresh.
2. On a non-Protection warrior, enter and leave Defensive Stance.
3. On a feral druid, switch among Bear or Dire Bear Form, Cat Form, and caster form.
4. In a group that supports role selection, change the assigned role between tank and damage or
   healer.
5. Run `/threatplating status` and keep the configurator open during each transition.
6. If the client exposes `PlayerUtil.IsPlayerEffectivelyTank()`, compare its result while legacy
   talent APIs are unavailable or restricted.

Expected:

- Protection paladins and warriors use tank colors; other talent builds use non-tank colors unless
  a stronger current signal says otherwise.
- Defensive Stance and Bear or Dire Bear Form enable tank colors immediately.
- Cat and caster forms use non-tank colors unless the druid has an explicit tank assignment.
- Blizzard's effective-tank helper classifies Protection builds when deprecated talent APIs are
  absent; an unavailable or throwing helper falls back without producing a Lua error.
- An explicit tank, damage, or healer assignment overrides talent detection.
- The status command, configurator sample, and visible nameplates switch without a reload.

## Lifecycle and event stress

1. Keep several enemies in combat long enough to generate continuous threat events.
2. Rapidly move them into and out of nameplate range while tab-targeting.
3. During a taunt swap or fixate, compare the badge against the actors' raw threat values rather
   than current aggro ownership.
4. Disable the addon for at least ten seconds during combat, then enable it again.
5. Repeatedly damage the current target and watch for smooth counter changes between fallback
   polls, including when the client reports the threat event against `player` rather than the mob.

Expected:

- Newly visible plates appear and removed plates clear within roughly 0.15 seconds under ordinary
  plate counts even while threat events are continuous. Dense packs remain bounded by the
  five-plate per-frame scheduler.
- Recycled plates never retain another unit's badge.
- Signed values continue to follow the highest observed/inferred raw-threat actor while colors
  independently follow actual aggro safety during taunts and fixates.
- Ordinary current-target damage enters the urgent queue through either hostile-unit or actor-unit
  threat events instead of updating only at the 0.10-second fallback cadence.
- Disabling immediately hides every badge; enabling restores eligible plates without a reload.

## Five-player dungeon

Cover these cases on multiple simultaneous enemies:

- Tank leading every mob.
- DPS below the tank on every mob.
- DPS pulling one mob while remaining below on the others.
- Player at zero threat while another group member tanks.
- Taunt swap.
- Threat drop or wipe.
- Group member death and resurrection.
- Pet summon/dismiss during combat.

Watch the counters on non-targeted plates as well as the current target. They must continue updating
without mouseover or target changes.

## Karazhan-style raid matrix

Repeat the dungeon cases with multiple tanks and mixed melee/ranged damage dealers. Include a tank
holding aggro below the raw-threat leader during a taunt, a tank losing aggro while still leading
raw threat, a non-tank crossing and then dropping below the scaled pull threshold, pet threat, and
an encounter fixate. Verify the sign only follows raw-threat order while green/red follows the
detected role's aggro safety and orange follows the warning bracket.

## Raid stress test

Use a full 25-player raid and enable nameplates at maximum range:

1. Pull a large trash pack.
2. Keep 40 hostile nameplates visible while rapidly tab-targeting and generating threat events.
3. Cover tank and non-tank views, taunt swaps, fixates, threat drops, deaths/resurrections, roster
   changes, and player/group pet summons and dismissals.
4. Move between melee and ranged range around both the 110% and 130% pull thresholds.
5. Include enemies targeting raid actors and at least one actor outside the raid; compare every
   signed value to the queryable actors shown by a threat meter.
6. Repeat large pulls while watching Lua errors, addon CPU/frame time, update latency, and pooled
   frame/overlay counts.
7. Profile the same encounter enabled and disabled, then repeat enough cycles to expose growing
   scheduler or frame state.

Acceptance target: all 40 visible counters settle within roughly eight scheduler frames after a
full queued refresh, no single frame shows a noticeable threat-query spike, frame/overlay counts
remain stable, and no restricted query escapes as a Lua error.

## Raw-threat scale verification

On every supported-client update, capture live `UnitDetailedThreatSituation` tuples while a threat
meter shows the same actors. Verify that dividing `rawThreat` by 100 reproduces the displayed
threat and that a player at 500, the current target at 1000, and a third queryable actor at 1200
produces `-700`, not `-500`. Record both melee and ranged tuples around the pull thresholds before
changing the scale or TOC interface.

Also confirm `rawPercentage`'s denominator, since the exactly-100 branch depends on it: while
tanking it must read 100, and while another actor tanks it must equal the player's threat divided
by that actor's threat. A non-tanking player exactly level with the lead must read `+0`.

## Positional API slot verification

The mocks reproduce the slot layouts the code assumes, so they cannot detect a change. Start with:

```
/threatplating probe
```

It prints the raw return tuple of each dependency next to the addon's reading of it, so a shifted
slot shows up immediately instead of as inverted raid colors. Run it with a target selected, in a
shapeshift form or stance, and with enemy nameplates visible for full coverage. Then confirm against
the pinned UI source (and in game) that:

- `GetShapeshiftFormInfo(index)` returns `texture, isActive, isCastable, spellID`. A bear druid and
  a defensive-stance warrior must both detect as tanks with no group role assigned.
- `GetTalentTabInfo(index)` returns `pointsSpent` in the fifth slot. A Protection build with the
  effective-tank helper unavailable must still detect as a tank.
- The nameplate base frame exposes its unit token as `unitToken`. Badges must still appear when
  plates become visible without a `NAME_PLATE_UNIT_ADDED` event, which is the path that reads it.

## Default-nameplate variants

Repeat the smoke test with:

- Modern and classic nameplate styles.
- Name inside and above the health bar.
- Health values on and off.
- Cast bars and auras visible.
- UI scale and nameplate size changed.

The badge must remain next to the health bar and must not mutate Blizzard's plate layout.

## Compatibility

The addon has anchor fallbacks for popular replacement plates, but the supported product contract is
Blizzard's default TBC Anniversary nameplates. If validating Plater or another replacement, record
the exact addon version and treat failures as compatibility work rather than a default-nameplate
regression.
