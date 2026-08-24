# Step 4 — Branching Perk Definitions

**Branch:** `refactor/branching-perks`

**Depends on:** Step 3 locally merged; G3 approved; G1 approved if Rogue is included.

**Milestone:** A real class presents a prerequisite-gated choice branch, resolves its typed effects through a bounded `PerkEffectResolver`, and eliminates hardcoded flat perk arrays without introducing bespoke controller flags.

## Files

- Create: `scripts/progression/perk_catalog.gd` and `scripts/battle/perk_effect_resolver.gd`.
- Modify: `scripts/autoload/game_session.gd`, `scripts/battle/unit.gd`, `scripts/battle/battle_controller.gd`, `scripts/tools/battle_scenarios/scenario_contract.gd`, `scripts/tools/battle_scenarios/battle_state_factory.gd`, `scripts/ui/level_up.gd`, `scripts/ui/unit_details.gd`, `scenes/ui/level_up.tscn`, `scenes/ui/unit_details.tscn`, and `translations/en.tres`.
- Modify: `scripts/save/campaign_snapshot.gd` for versioned perk tree normalization.
- Test: create `tests/unit/test_perk_catalog.gd`, `tests/unit/test_perk_effect_resolver.gd`; modify `test_game_session.gd`, `test_level_up.gd`, `test_unit_details.gd`, `test_battle_controller.gd`, `test_battle_state_factory.gd`, and `test_scenario_contract.gd`.

## Red/green tasks

1. **Write failing unit tests for `PerkCatalog` DAG logic:**
   - Test that a child perk cannot be chosen if its prerequisites are unfulfilled.
   - Test that choosing one branch node permanently excludes its mutually exclusive siblings.
   - Test rejection of circular prerequisites, invalid class IDs, duplicate rank assignments, and unrecognized effect descriptors.
   - Test deterministic serialization and deserialization of chosen perk graphs.
2. **Run `test_perk_catalog.gd` red:**
   - `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gselect=test_perk_catalog.gd -gexit`
3. **Implement `PerkCatalog` (`scripts/progression/perk_catalog.gd`):**
   - Define structured `PerkDefinition`:
     ```gdscript
     {
         "id": "warrior_juggernaut",
         "class_id": "warrior",
         "tier": 1,
         "prerequisite_ids": [] as Array[String],
         "mutually_exclusive_with": ["warrior_bulwark"] as Array[String],
         "rank_cap": 1,
         "name_key": "perk.warrior_juggernaut.name",
         "description_key": "perk.warrior_juggernaut.description",
         "effect_descriptor": {
             "type": "stat_modifier",
             "stat": "max_health",
             "percent_bonus": 15
         }
     }
     ```
   - Provide query functions:
     - `get_available_perks(adventurer: Dictionary) -> Array[Dictionary]` (evaluates prerequisites, tier, and exclusion sets)
     - `can_choose_perk(adventurer: Dictionary, perk_id: String) -> bool`
     - `apply_perk(adventurer: Dictionary, perk_id: String) -> Dictionary`
4. **Implement `PerkEffectResolver` (`scripts/battle/perk_effect_resolver.gd`):**
   - Provide pure rule evaluation for combat and strategic calculations:
     - `compute_stat_modifier(base_stat: int, perks: Array[String], stat_name: String) -> int`
     - `get_granted_actions(perks: Array[String]) -> Array[Dictionary]`
     - `resolve_action_modifier(base_action: Dictionary, perks: Array[String]) -> Dictionary`
   - Refactor `GameSession.compute_effective_max_health()`, `get_effective_defense()`, and `get_effective_move_range()` to call through `PerkEffectResolver`.
   - Remove ad-hoc perk boolean branches from `BattleController` and `Unit`.
5. **Update Progression UI Callers:**
   - `level_up.gd`: Fetch eligible perks from `PerkCatalog.get_available_perks()`. Render choice cards indicating prerequisite fulfillment and mutually exclusive branch commitments.
   - `unit_details.gd`: Render the class perk tree with clear visual state for locked, available, active, and excluded nodes.
6. **Migrate Existing Class Perks & Add First Branching Choice:**
   - Migrate shipped perks for Warrior, Scout, Cleric, Mage, and Specializations into `PerkCatalog`.
   - Add one approved branching decision node (e.g. offensive vs. defensive branch) to a core class.
7. **Update `CampaignSnapshot` Validation:**
   - Validate that saved perk lists satisfy prerequisite DAG integrity without containing mutually exclusive pairs.
8. **Run Focused Tests Green & Common Final Checks:**
   - `make campaign-sim`
   - `make check`
   - `godot --headless --path . --editor --quit`
   - `git diff --check`

## Manual check

In `make play`:
1. Level up an adventurer to a branch tier.
2. Open Level Up modal and confirm child nodes are locked until prerequisites are acquired.
3. Choose one branching perk; confirm its sibling node is visually marked excluded and disabled.
4. Verify in tactical combat that the chosen perk's effect applies accurately without debug output or errors.

## Commit and local merge

After review and user signoff, commit the perk catalog, effect resolver, UI updates, and tests as `refactor(progression): support branching perk definitions`, merge locally to `main`, and delete the branch.
