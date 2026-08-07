# Follow up implementation for first campaign loop

## Encampment view and navigation

The main camp navigation menu should be in a left pane and be visible at all times:

[Encampment]
[Units]
[Buildings]
[Trade]
[Deploy Party]
[World Map]

When you first enter the encampment, you are on the "Encampent" screen which shows basic details about the encampment: population, number of parties/units in the encampment.

Clicking on Units, Buildings, Trade takes you to those specific screens, but the encampment menu is always visible on the left panel.

Minor point: On the Parties screen, the [Create Party] button should be under the parties table, not above it (consistency with party/Add Member button)

## World map movement path bug

There is a regression here. If there is already a path set for a unit, clicking the unit cancels the path and lets you set a new one. Instead, the old path should remain visible as we set the new path. If we right click, the new path setting is canceled and the old one remains. If we left click in the map, the new path is set and the old one disappears.

## XP accounting

After defeating enemies and clearing locations, we award fractional XP to each party member equally. The displayed XP value is truncated to the integer value. When displaying a unit details, show the XP and XP needed for the next level.

## Battle balancing

Three orcs are too tough for the level 1 warriors to handle. Let's rebalance the star system:

* One star: one goblin
* Two stars: two goblins or one orc (random)
* Three stars (not yet used): three goblins or two orcs (random)

This is not permanent because we are going to make units more powerful, but this is just so we can run the game loop a few times.

## Guild Hall / full-party battles cleanup

Deferred, non-blocking items from the final review of
`docs/plans/2026-08-07-guild-hall-and-full-party-battles/` (all merged to
`main`; none of these are regressions, just polish left on the table):

* `battle_controller.gd`'s `try_move_selected_unit` and `get_legal_moves`
  each build their own `is_blocked` closure and run their own BFS traversal
  over the same tiles — worth factoring into one shared helper.
* `portrait_panel.gd`'s `SELECTED_MODULATE` constant is a misnomer: it's
  applied to every living party member, not just the selected one. Rename
  to something like `LIVING_MODULATE`.
* `select_unit_by_adventurer_id` has no explicit `unit.side != Side.PLAYER`
  guard. Currently unreachable/harmless, but worth adding for safety.
* The enemy-health HUD band (`EnemyHealth`) may visually overlap the
  portrait panel for a 3-enemy Orc Outpost battle — only the 2-goblin
  Goblin Camp was manually verified with `make play`. Check with a 3-enemy
  battle.
* `test_guild_hall.gd` has a few tautological assertions (comparing label
  text against the same `tr()` expression that produced it), and the new
  `guild_hall.*` translation keys aren't covered by
  `test_localization.gd`'s literal-English-copy checks.
* `docs/dev/code-map.md` is stale: it doesn't mention `PortraitPanel`, the
  Buildings/Guild Hall scenes, Guild Hall state in `GameSession`'s "Owns"
  list, `get_tile_distances`, or the new WASD/number-key battle-flow
  description.
* In-game hint copy (`battle.hint.select_unit` etc.) never mentions the
  WASD/number-key controls — pure discoverability gap, not a spec
  violation.
* `test_first_campaign_ui_flow.gd`'s enemy-turn wait loop
  (`while battlefield._enemy_turn_in_progress: await get_tree().process_frame`)
  has no frame cap, unlike the sibling loop just below it — could hang
  instead of failing if a future regression gets `_enemy_turn_in_progress`
  stuck.
* `_stage_a_killing_blow()` in `test_battlefield.gd` places an enemy at a
  hardcoded offset that happens to equal `PLAYER_START_POSITIONS[1]` —
  latent collision risk if a helper ever fields a 2-member party.
* Cosmetic: `portrait_panel.gd`'s comment about `_player_adventurer_ids`
  being "capped by `PLAYER_START_POSITIONS.size()`" is inaccurate (it's
  actually uncapped; only the separate `units` array is capped).