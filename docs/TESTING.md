# In-game testing

## Fast smoke test

1. Run `.\tools\install.ps1` to replace `Interface\AddOns\ThreatPlating` with the current checkout.
2. Enable Lua errors with `/console scriptErrors 1`.
3. Reload with `/reload`.
4. Turn on enemy nameplates.
5. Run `/threatplating test` near several attackable NPCs.

Expected: every eligible visible NPC plate gets a green `+12.3k` badge to the right of its health
bar for eight seconds. Friendly NPCs, players, and player-controlled pets do not get a badge.

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
- Red `-x` while behind.
- Green `+x` when leading.
- No stale badge after a plate disappears or is recycled.
- Your pet is treated as a competing actor, not added to your threat.

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
