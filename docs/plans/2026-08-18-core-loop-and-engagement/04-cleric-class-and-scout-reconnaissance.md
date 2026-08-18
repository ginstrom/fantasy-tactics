# Step 4: Third Root Class (Cleric) and Scout Strategic Reconnaissance

**Date:** 2026-08-18
**Status:** proposed
**Branch:** `feat/cleric-and-scout-recon`
**Part of:** [`docs/plans/2026-08-18-core-loop-and-engagement/index.md`](index.md)

---

## Summary

Complete the foundational three-class triad (Warrior, Scout, Cleric). Implement the **Cleric** root class with blunt melee proficiency, 3 MP per battle, and tactical **Heal** and **Bless** spells. Implement proximity-based Scout reconnaissance: encounters show location only until a deployed Scout is within three World Map squares, then reveal tier and exact enemy type/count. Finalize automatic class-owned attribute scaling on level-up and verify that legacy manual skill-point spending is fully eliminated.

---

## Technical Design

### 1. Cleric Root Class Definition (`scripts/autoload/game_session.gd`)
- Add `"cleric"` entry to `CLASS_DEFINITIONS`:
  ```gdscript
  "cleric": {
      "name_key": "class.cleric.name",
      "desc_key": "class.cleric.desc",
      "base_stats": {
          "max_health": 12,
          "vitality": 12,
          "melee": 50,
          "missile": 20,
          "guard": 15,
          "might": 2,
          "spellcasting": 60,
          "magic_resistance": 30,
          "resistance": 10,
          "move_range": 3,
      },
      "skills": {
          "melee": {"tier": "low", "min_gain": 1, "max_gain": 2},
          "guard": {"tier": "med", "min_gain": 2, "max_gain": 3},
          "spellcasting": {"tier": "hi", "min_gain": 4, "max_gain": 5},
          "max_health": {"tier": "med", "min_gain": 12, "max_gain": 12},
      },
      "proficiencies": {
          "weapon_categories": ["mace", "hammer", "staff"],
          "armor_categories": ["leather", "mail"],
      },
      "spells": ["heal", "bless"],
  }
  ```
- Starting gear for Cleric: `mace_iron` (1–6 blunt damage) and `leather_armor` (+10 Guard, 10% Resistance).

### 2. Tactical Combat Spells (`scripts/battle/battle_controller.gd` & `scripts/battle/unit.gd`)
- Hydrate `Unit.mp_max = 3` and `Unit.mp_remaining = 3` for Clerics only. MP is battle-local and never restores before battle resolution.
- **Spell: Heal (`"heal"`):**
  - Cost: 1 MP and the normal 3 AP action cost. Range: 1–3 tiles with the existing occupied-endpoint line-of-sight rule.
  - Target: one living ally, never an enemy.
  - Effect: restore an injectable `randi_range(2, 8)` HP, capped at the target's max HP.
- **Spell: Bless (`"bless"`):**
  - Cost: 1 MP and 3 AP. Range: 1–3 tiles with line of sight.
  - Target: one living ally, including self, not already blessed.
  - Effect: one battle-local status lasting until battle resolution: +10 percentage points to final hit chance (still respecting the global hit cap) and +10% to final post-resistance damage.
- Add Spell action buttons to the ActionBar in `scenes/battle/battlefield.tscn` when a Cleric unit is active.

### 3. Scout Strategic Reconnaissance (`scripts/autoload/game_session.gd` & `scripts/world/world_map.gd`)
- Add method `GameSession.get_party_scouting_intel(party_id: String, encounter_id: String) -> Dictionary`. Use the World Map's existing Manhattan `_grid_distance`, not a new diagonal metric:
  - If the deployed party contains at least one Scout and is within distance 3 of the encounter:
    - Return detailed intel:
      - `has_intel: true`
      - `enemy_types: Array[String]` (e.g. `["Goblin Skirmisher", "Goblin Archer"]`)
      - `enemy_count: int` (e.g. `3`)
      - `danger_tier: int` (1–5 stars)
  - Otherwise:
    - Return basic intel:
      - `has_intel: false`
      - `danger_tier: int` (1–5 stars)
      - `enemy_types: []`, `enemy_count: 0`
- In `world_map.gd`, encounter markers show location only outside the reveal condition; when it becomes true, update that marker/side panel with tier and type/count. Never reveal rewards or battlefield positions.

### 4. Automatic Class Attribute Growth & Level-Up Verification
- Ensure `GameSession.level_up_adventurer()` rolls gains strictly from class definition skill tiers.
- Ensure Level Up screen (`scenes/ui/level_up.tscn`) displays automatic gains clearly and only prompts for a Perk choice on levels divisible by 3.
- Remove all remaining traces of manual skill-point distribution.

---

## Setup

```bash
git checkout main && git pull
git checkout -b feat/cleric-and-scout-recon
make check   # confirm clean baseline before changes
```

---

## TDD Task List (Red → Green)

Write failing unit tests first, verify failure, implement changes, and confirm `make check` passes.

1. **Cleric Class Definition & Progression ([`tests/unit/test_game_session.gd`](../../../tests/unit/test_game_session.gd)):**
   - Test `"cleric"` exists in `CLASS_DEFINITIONS` with correct base stats, skills, and proficiencies.
   - Test creating a Cleric initializes correct starting attributes and mace equipment.
   - Test leveling up a Cleric automatically increments health, melee, guard, and spellcasting according to defined tiers.

2. **Cleric Combat Spells in BattleController ([`tests/unit/test_battle_controller.gd`](../../../tests/unit/test_battle_controller.gd)):**
   - Test `try_cast_spell("heal", target_ally)` deducts 3 AP and 1 MP, then heals the injectable 2–8 result up to max HP.
   - Test casting heal on full-health ally is rejected or caps at max health.
   - Test casting heal on enemy is rejected.
   - Test `try_cast_spell("bless", target_ally)` deducts 1 MP and applies the battle-local hit/damage modifiers without bypassing the existing hit cap or resistance calculation.
   - Test spell range and line-of-sight constraints.

3. **Scout Strategic Reconnaissance ([`tests/unit/test_game_session.gd`](../../../tests/unit/test_game_session.gd) & [`tests/unit/test_world_map.gd`](../../../tests/unit/test_world_map.gd)):**
   - Test `get_party_scouting_intel()` returns detailed enemy composition and tier only when a Scout is within Manhattan distance 3.
   - Test it returns no tier/composition when no Scout is present or the Scout is four or more squares away.
   - Test World Map UI updates encounter preview panel with Scout intel when hovering/selecting an encounter site.

4. **UI ActionBar & Spells Integration ([`tests/unit/test_battlefield.gd`](../../../tests/unit/test_battlefield.gd)):**
   - Test ActionBar displays Heal and Bless buttons plus remaining MP when Cleric is selected.
   - Test ActionBar hides spell buttons when Warrior or Scout is selected.

5. **Localization Strings ([`tests/unit/test_localization.gd`](../../../tests/unit/test_localization.gd)):**
   - Test all new spell names, class descriptions, and scouting tooltip keys resolve properly in `translations/en.tres`.

---

## Verification

```bash
make check
```

Expected output: All unit tests pass with zero errors, zero orphans, and zero warnings.

---

## Manual Verification (User Sign-off)

1. Launch `make play`.
2. Construct the **Temple** in the Encampment and recruit a **Cleric**.
3. Form a party containing a **Warrior**, a **Scout**, and a **Cleric**.
4. **Test Scout Strategic Reconnaissance:**
   - Navigate to the **World Map**.
   - Click or hover over the Goblin Camp encounter tile.
   - Confirm the inspection tooltip displays exact enemy breakdown: monster types (e.g. Goblins, Kobolds), total count, and expected reward bands.
5. **Test Cleric Spells in Combat:**
   - Enter the encounter.
   - Move the Warrior forward and let them take damage from an enemy.
   - Select the Cleric on the next turn. Verify **Heal** and **Protection** buttons appear on the action bar.
   - Cast **Heal** on the wounded Warrior. Confirm HP increases and combat log records the heal.
   - Cast **Bless** on the Warrior. Confirm status indicators show the hit and damage bonus for the battle.
6. **Test Level Up:**
   - Complete the battle and earn XP to level up.
   - Confirm the Level Up screen shows automatic stat gains without manual point allocation prompts.

---

## Commit and Merge

```bash
git status --short
git add scripts/autoload/game_session.gd scripts/battle/unit.gd scripts/battle/battle_controller.gd scripts/battle/battlefield.gd scenes/battle/battlefield.tscn scripts/world/world_map.gd scenes/world/world_map.tscn translations/en.tres tests/unit/test_game_session.gd tests/unit/test_battle_controller.gd tests/unit/test_battlefield.gd tests/unit/test_world_map.gd tests/unit/test_localization.gd
git diff --cached --check
git commit -m "feat(classes): implement Cleric root class, tactical combat spells, and Scout strategic reconnaissance"

# After user sign-off:
git checkout main
git merge feat/cleric-and-scout-recon
git branch -d feat/cleric-and-scout-recon
```

---

## Milestone (Concretely Verifiable)

- Cleric class is playable with 3 MP and functioning Heal and Bless spells.
- Scout grants pre-battle strategic reconnaissance on the World Map.
- Automatic class-owned stat progression is 100% active and verified.
- `make check` passes 100% green.
