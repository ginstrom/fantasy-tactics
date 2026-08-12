# Step 2: Ranged Weapons Catalog & Scout Class Permissions

> **Branch:** `feat/scout-ranger-class` (or step-specific branch off `main`)

## Goal
Add bow weapons to the weapon catalog in [`GameSession`](file:///home/ryan/play/fantasy-tactics/scripts/autoload/game_session.gd), define the **Scout** class data schema, default equipment setup, and implement class-based equipment permissions.

---

## Technical Design

1. **Ranged Weapon Catalog (`scripts/autoload/game_session.gd`)**:
   Add bow entries to `WEAPONS`:
   ```gdscript
   "shortbow_iron": {
       "id": "shortbow_iron",
       "name": "tr:item.weapon.shortbow_iron",
       "damage_min": 1,
       "damage_max": 6,
       "min_range": 1,
       "max_range": 3,
       "category": "bow",
       "gold_value": 30
   },
   "hunting_bow_steel": {
       "id": "hunting_bow_steel",
       "name": "tr:item.weapon.hunting_bow_steel",
       "damage_min": 2,
       "damage_max": 7,
       "min_range": 1,
       "max_range": 4,
       "category": "bow",
       "gold_value": 75
   }
   ```

2. **Scout Class Definition**:
   Define `CLASS_DEFINITIONS` dictionary in `GameSession`:
   - `warrior`: `allowed_categories: ["sword", "dagger", "axe"]`, default stats.
   - `scout`: `allowed_categories: ["dagger", "bow"]`, default base stats (`max_health: 12`, `attack/accuracy: 65`, `defense/guard: 10`, `resistance: 10%`, `move_range: 3`).

3. **Adventurer Factory & Helper**:
   - `get_default_scout(id: String, name: String) -> Dictionary`: Creates a Scout adventurer equipped with `shortbow_iron` and `leather_armor`.
   - `can_adventurer_equip_item(adventurer_id: String, item_id: String) -> bool`: Checks if the adventurer's class permits the item category.

4. **Equipment Permission Enforcement**:
   - Update `GameSession.equip_item_from_bank()` and `activate_carried_item()` to validate `can_adventurer_equip_item()`, rejecting incompatible item swaps.

5. **Localization Keys (`translations/en.tres`)**:
   Add translation keys for `item.weapon.shortbow_iron`, `item.weapon.hunting_bow_steel`, `class.scout`, etc.

---

## TDD Milestones

### Red Phase (Failing Tests First)
Create `tests/unit/test_scout_class_and_permissions.gd`:
- `test_get_default_scout_returns_valid_adventurer_dict()`: Scout has `class: "scout"`, `weapon: "shortbow_iron"`, `armor: "leather_armor"`.
- `test_weapon_catalog_includes_bows_with_min_max_range()`: `shortbow_iron` has `min_range=1` and `max_range=3`.
- `test_scout_can_equip_bow_and_dagger_but_not_two_handed_sword()`: `can_adventurer_equip_item()` passes for bows and daggers, fails for heavy swords on a Scout.
- `test_warrior_cannot_equip_bow()`: `equip_item_from_bank()` rejects assigning `shortbow_iron` to a Warrior.
- `test_localization_keys_resolve()`: All new weapon and class localization keys resolve correctly in English.

### Green Phase (Implementation)
1. Add `shortbow_iron` and `hunting_bow_steel` to `GameSession.WEAPONS`.
2. Implement Scout class data schema and `get_default_scout()` in `scripts/autoload/game_session.gd`.
3. Add class permission checks in `equip_item_from_bank` and `activate_carried_item`.
4. Add localization entries in `translations/en.tres`.

---

## Verification & Milestone

- **Automated Tests**: All tests in `test_scout_class_and_permissions.gd` pass.
- **Verification Command**:
  ```bash
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_scout_class_and_permissions.gd
  make check
  ```
- **Local Merge**: Commit changes, merge branch back to `main` after user signoff.
