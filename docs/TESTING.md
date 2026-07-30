# In-game testing

## Fast smoke test

1. Run `.\tools\install.ps1` to replace `Interface\AddOns\ThreatPlating` with the current checkout.
2. Enable Lua errors with `/console scriptErrors 1`.
3. Reload with `/reload`.
4. Turn on enemy nameplates.
5. Run `/threatplating test` near several attackable NPCs.
6. Run `/threatplating test orange`.

Expected: every eligible visible NPC plate gets a `+12.3k` badge to the right of its health bar for
eight seconds. It is green in tank mode and red in non-tank mode. Friendly NPCs, players, and
player-controlled pets do not get a badge. The orange test uses orange text and border without
changing layout or eligibility.

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
8. Resize the badge from its lower-right grip, then change font size independently.
9. Exercise every slider by dragging and by keyboard entry, including invalid and boundary values.
10. Try automatic width, padding, all font presets, text shadow, background RGB/opacity, all border
   modes, all palettes, and custom semantic colors.
11. Open and cancel the color picker, then open another addon's picker before closing this editor.
12. Use Reset Layout, Reset Appearance, Reset All, and Revert. Move and resize the editor before
    Revert.
13. Close and reopen through the title X, footer Done, Escape, slash `close`, slash toggle,
    Options → AddOns, and AddOn Compartment.
14. Reload the UI.

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
- Badge resizing never changes font size, and font changes never change badge height.
- Custom colors retain the fixed safe, danger, and warning meanings.
- Canceling restores the pre-picker color. Closing Threat Plating does not close a newer picker
  session owned by another addon.
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
- As a detected tank, red `-x` while behind and green `+x` when leading.
- As a detected non-tank, green `-x` while behind and red `+x` when leading.
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
- Moving into melee range updates within roughly 0.25 seconds. If the move crosses the applicable
  pull threshold and aggro changes, orange clears.
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

Expected:

- Protection paladins and warriors use tank colors; other talent builds use non-tank colors unless
  a stronger current signal says otherwise.
- Defensive Stance and Bear or Dire Bear Form enable tank colors immediately.
- Cat and caster forms use non-tank colors unless the druid has an explicit tank assignment.
- An explicit tank, damage, or healer assignment overrides talent detection.
- The status command, configurator sample, and visible nameplates switch without a reload.

## Lifecycle and event stress

1. Keep several enemies in combat long enough to generate continuous threat events.
2. Rapidly move them into and out of nameplate range while tab-targeting.
3. During a taunt swap or fixate, compare the badge against the actors' raw threat values rather
   than current aggro ownership.
4. Disable the addon for at least ten seconds during combat, then enable it again.

Expected:

- Newly visible plates appear and removed plates clear within roughly 0.25 seconds even while
  threat events are continuous.
- Recycled plates never retain another unit's badge.
- Current aggro does not produce a green badge when another observed or inferred actor has higher
  raw threat.
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

## Raid stress test

Use at least 20 players and enable nameplates at maximum range:

1. Pull a large trash pack.
2. Observe update latency while rapidly tab-targeting.
3. Profile CPU with the same encounter both enabled and disabled.
4. Confirm there are no growing frame counts after repeated pulls.

Acceptance target: visible counters settle within roughly 0.25 seconds and the addon does not
produce noticeable frame-time spikes.

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
