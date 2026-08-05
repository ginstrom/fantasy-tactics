# Step 1: Expedition Catalog and Tougher Battle

**Milestone:** The map renders Goblin Camp and Orc Outpost as independently selectable, fixed-reward expeditions. Entering one selects the correct enemy configuration while retaining the existing tactical rules.

## Setup

```bash
git status --short
git diff -- docs/plans/2026-08-05-expedition-rewards-and-gold-design.md
git checkout main
git pull --ff-only
git checkout -b feat/expedition-catalog-and-tougher-battle
```

If the design document is locally modified, preserve it and do not stage it.

## Files

- Modify: `scripts/autoload/game_session.gd`, `scripts/world/world_map.gd`, `scripts/battle/battle_controller.gd`, `translations/en.tres`
- Modify: `tests/unit/test_game_session.gd`, `tests/unit/test_world_map.gd`, `tests/unit/test_battle_controller.gd`, `tests/unit/test_localization.gd`

## Red/green TDD

1. In `test_game_session.gd`, write failing tests for `GameSession.ORC_OUTPOST_ID`, a read-only expedition catalog/lookup, and these exact entries:

   ```gdscript
   goblin_camp: position Vector2i(4, 4), reward 10, enemy 3 HP / 1 damage / 0.3 hit
   orc_outpost: position Vector2i(4, 0), reward 25, enemy 5 HP / 2 damage / 0.5 hit
   ```

   Also assert `get_expedition("missing") == {}` and that a returned record can be mutated without mutating the catalog. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_game_session.gd -gexit
   ```

   Expected: FAIL because the catalog API does not exist.

2. In `game_session.gd`, retain `GOBLIN_CAMP_ID`, add `ORC_OUTPOST_ID`, `EXPEDITIONS`, and `get_expedition(encounter_id) -> Dictionary`. Each record must include `position`, `name_key`, `danger_key`, `reward`, and `enemy` (`name_key`, `max_health`, `attack_damage`, `hit_chance`). Return a deep duplicate. Do not introduce gold state yet. Re-run the focused test; expected: PASS.

3. In `test_world_map.gd`, add generic catalog-driven red tests: a party at each record’s position selects on first click and emits that record’s ID on second click; it can route away after selecting; completing Goblin Camp rejects only Goblin Camp while Orc Outpost remains activatable. Run the focused file; expected: FAIL because `world_map.gd` still hard-codes one encounter.

4. In `world_map.gd`, replace single `ENCOUNTER_ID`/`ENCOUNTER_POSITION` constants with catalog-derived helpers. Draw every expedition marker, coloring only its completed ID gray. Draw an ignored label near each marker with:

   ```gdscript
   tr("world_map.expedition.label") % [tr(record.name_key), tr(record.danger_key), record.reward]
   ```

   Activation must look up the current tile, reject completed entries, and emit its ID. Preserve settlement and route behavior, especially selection-before-activation. Re-run focused map tests; expected: PASS.

5. In `test_battle_controller.gd`, write a failing test that enters `ORC_OUTPOST_ID`, instantiates the controller, and verifies its enemy is 5 HP, 2 damage, and 0.5 chance; add the equivalent Goblin regression. Run the focused file; expected: FAIL because the enemy is hard-coded.

6. In `battle_controller.gd`, build the enemy from `GameSession.get_expedition(GameSession.selected_encounter).enemy`. Preserve the current Goblin as fallback for scene-isolated tests with no selected encounter. Retain grid, moves, attack rules, start position, and color; do not create a new unit type. Re-run focused tests; expected: PASS.

7. Add and test translations:

   ```text
   expedition.goblin_camp.name = Goblin Camp
   expedition.orc_outpost.name = Orc Outpost
   expedition.danger.low = Low danger
   expedition.danger.high = High danger
   battle.enemy.goblin = Goblin
   battle.enemy.orc = Orc
   world_map.expedition.label = %s — %s — %d gold
   ```

   Update `world_map.hint` only if needed to mention multiple marked expeditions while keeping the selection-first instruction.

## Verification

```bash
make check
godot --headless --path . --editor --quit
git diff --check
```

All commands must exit `0`; commit any generated `.uid` files.

## Manual verification and merge

Run `make play`, create and staff a party, and depart. Confirm both sites show name, danger, and reward. At each site, confirm first click selects and second enters; confirm Goblin versus Orc stats during battle. Gold is intentionally not shown or awarded until Step 2.

After user signoff:

```bash
git add scripts/autoload/game_session.gd scripts/world/world_map.gd scripts/battle/battle_controller.gd translations/en.tres tests/unit/test_game_session.gd tests/unit/test_world_map.gd tests/unit/test_battle_controller.gd tests/unit/test_localization.gd
git add scripts/**/*.uid
git commit -m "feat: add a tougher expedition"
git checkout main
git merge --ff-only feat/expedition-catalog-and-tougher-battle
git branch -d feat/expedition-catalog-and-tougher-battle
```

Do not push.
