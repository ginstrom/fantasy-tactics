# Step 5: Expedition Scouting Preview System

> **Branch:** `feat/scout-ranger-class` (or step-specific branch off `main`)

## Goal
Implement the World Map expedition scouting preview system. Having a **Scout** in the active deployed party unlocks detailed enemy composition previews for active encounters on the World Map.

---

## Technical Design

1. **Party Scouting Capabilities (`scripts/autoload/game_session.gd`)**:
   - `party_has_scout(party_id: String) -> bool`: Returns `true` if any adventurer in the specified party has `class == "scout"`.
   - `get_encounter_scouting_report(party_id: String, encounter_id: String) -> Dictionary`:
     - If `party_has_scout(party_id)` is `true`, returns detailed enemy breakdown: `{"is_scouted": true, "enemies": ["goblin", "goblin_archer"], "difficulty": tier}`.
     - Otherwise, returns `{"is_scouted": false, "difficulty": tier}` (star difficulty tier only).

2. **World Map UI Intel Display (`scripts/world/world_map.gd`)**:
   - When hovering over or selecting an encounter tile on the World Map:
     - Check `get_encounter_scouting_report()`.
     - If `is_scouted` is `true`, render detailed enemy icons/labels (e.g., "1x Goblin, 1x Goblin Archer") in the encounter info overlay.
     - If `is_scouted` is `false`, show standard star rating with a hint: *"Scout required for detailed intel"*.

---

## TDD Milestones

### Red Phase (Failing Tests First)
Create `tests/unit/test_world_map_scouting.gd`:
- `test_party_has_scout_returns_true_when_scout_in_party()`: Returns `true` for a party containing a Scout adventurer, `false` for a Warrior-only party.
- `test_scouting_report_reveals_enemy_composition_with_scout()`: `get_encounter_scouting_report()` includes full enemy list when Scout is deployed.
- `test_scouting_report_hides_enemy_composition_without_scout()`: Returns only star tier when no Scout is in party.
- `test_world_map_renders_scouted_intel_label()`: `world_map.gd` displays enemy breakdown when party has a Scout.

### Green Phase (Implementation)
1. Add `party_has_scout` and `get_encounter_scouting_report` to `scripts/autoload/game_session.gd`.
2. Update `scripts/world/world_map.gd` hover/selection info panel to render scouted intel.
3. Add localization strings for scouting report hints in `translations/en.tres`.

---

## Verification & Milestone

- **Automated Tests**: All tests in `test_world_map_scouting.gd` pass.
- **Verification Command**:
  ```bash
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_world_map_scouting.gd
  make check
  ```
- **Manual Verification**: Launch `make play`. Deploy a party without a Scout to the World Map and check encounter hover (shows stars only). Return to camp, recruit a Scout, add them to the party, deploy to World Map, and verify encounter hover now shows exact enemy names/composition.
- **Local Merge**: Commit changes, merge branch back to `main` after user signoff.
