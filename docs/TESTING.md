# In-game testing

## Fast smoke test

1. Run `.\tools\install.ps1` to replace `Interface\AddOns\ThreatPlating` with the current checkout.
2. Enable Lua errors with `/console scriptErrors 1`.
3. Reload with `/reload`.
4. Turn on enemy nameplates.
5. Run `/threatplating test` near several attackable NPCs.

Expected: every eligible visible NPC plate gets a `+12.3k` badge to the right of its health bar for
eight seconds. It is green in tank mode and red in non-tank mode. Friendly NPCs, players, and
player-controlled pets do not get a badge.

`.\tools\push.ps1` is the normal push command for this checkout. After a successful push, it calls
the installer with the pushed revision so the game never receives uncommitted files.

## Configurator

1. Run `/threatplating` with several enemy NPC plates visible.
2. Confirm the window is draggable and resizable.
3. Drag the sample badge to every side of the mock health bar and into its center.
4. Resize the badge from its lower-right grip.
5. Toggle automatic width and the high-contrast background.
6. Change the font size, enabled state, and anchor preset buttons.
7. Close and reopen through the slash command, Options → AddOns, and AddOn Compartment.
8. Reload the UI.

Expected:

- All currently visible eligible plates show `+12.3k` while the configurator is open.
- The status line identifies tank or non-tank colors, and the sample is green for a tank or red for
  a non-tank.
- Real plates update after every completed drag and continuously during resize.
- Closing the configurator restores real threat values or hides plates without threat.
- Badge layout and configurator size/position survive `/reload`.
- Reset restores a 44 × 18 badge, 14-point font, and a 6-pixel gap to the health bar's right side.
- Configuring never makes Blizzard nameplates draggable or mouse-interactive.
- The title X, footer Close button, Escape, `/threatplating close`, and slash toggle all close the
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
- No stale badge after a plate disappears or is recycled.
- Your pet is treated as a competing actor, not added to your threat.

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
