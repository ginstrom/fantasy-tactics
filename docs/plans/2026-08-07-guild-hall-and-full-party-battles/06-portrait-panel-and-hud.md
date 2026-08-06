# Task 6: Portrait panel and HUD adjustments

## Objective

Add the left-side portrait panel (one square per fielded party member:
color swatch, health, selection ring, dimmed when defeated, clickable to
select) and adjust the HUD to match — drop the redundant aggregate
`PlayerHealth` label, and turn `EnemyHealth` into a per-living-enemy list
(design.md §3 "Left portrait panel", "HUD adjustments"). This is the task
that finally turns green the two `test_battlefield.gd` tests left red at
the end of Task 4.

## Files

- Create: `scripts/battle/portrait_panel.gd`
- Modify: `scenes/battle/battlefield.tscn`
- Modify: `scripts/battle/battlefield.gd`, `tests/unit/test_battlefield.gd`

## Steps

### Portrait panel component

1. Add `const BattleControllerScript :=
   preload("res://scripts/battle/battle_controller.gd")` and `const
   PortraitPanelScript := preload("res://scripts/battle/portrait_panel.gd")`
   to `test_battlefield.gd` (the first may already exist from Task 4).
2. Add failing tests to `test_battlefield.gd`:
   - `test_portrait_panel_shows_one_row_per_fielded_party_member`: a
     2-member party; `battlefield.portrait_panel.rows.get_child_count() ==
     2`; each row's `Health` label reads `"3/3"`.
   - `test_portrait_panel_shows_the_selection_ring_on_the_selected_member`:
     select the fielded Warrior via `battlefield.grid._select_unit(warrior)`;
     `Rows/Portrait0/SelectionRing` is `visible`.
   - `test_portrait_panel_dims_a_defeated_member`: reduce the Warrior's
     health to 0 and `battlefield.grid.units.erase(warrior)`, call
     `battlefield.portrait_panel.refresh()`; `Rows/Portrait0`'s `modulate`
     equals `PortraitPanelScript.DEFEATED_MODULATE`.
   - `test_clicking_a_portrait_selects_that_party_member`: a 2-member party;
     `battlefield.portrait_panel.get_node("Rows/Portrait1").emit_signal("pressed")`;
     `battlefield.grid.selected_unit.adventurer_id` equals the second
     member's id.
3. Run `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield
   -gexit`. Expected: fails, `portrait_panel` does not exist on `Battlefield`
   yet.
4. Implement `scripts/battle/portrait_panel.gd`:

   ```gdscript
   extends Control

   const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")

   const PORTRAIT_SIZE := 48
   const DEFEATED_MODULATE := Color(1, 1, 1, 0.35)
   const SELECTED_MODULATE := Color(1, 1, 1, 1)

   @onready var rows: VBoxContainer = $Rows

   var grid: Node2D


   func refresh() -> void:
       for child in rows.get_children():
           child.queue_free()
       var member_ids: Array = GameSession.get_selected_party().get("member_ids", [])
       for index in member_ids.size():
           rows.add_child(_build_row(index, member_ids[index]))


   func _build_row(index: int, adventurer_id: String) -> Button:
       var unit = _find_unit(adventurer_id)
       var row := Button.new()
       row.name = "Portrait%d" % index
       row.flat = true
       row.pressed.connect(func() -> void: grid.select_unit_by_adventurer_id(adventurer_id))
       row.modulate = SELECTED_MODULATE if unit != null else DEFEATED_MODULATE

       var hbox := HBoxContainer.new()
       row.add_child(hbox)

       var swatch := ColorRect.new()
       swatch.name = "Swatch"
       swatch.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
       swatch.color = BattleControllerScript.PLAYER_COLORS[index % BattleControllerScript.PLAYER_COLORS.size()]
       hbox.add_child(swatch)

       var health_label := Label.new()
       health_label.name = "Health"
       health_label.text = (
           "%d/%d" % [unit.health, unit.max_health] if unit != null
           else tr("battle.status.defeated") % GameSession.get_adventurer(adventurer_id).get("name", "")
       )
       hbox.add_child(health_label)

       var ring := ColorRect.new()
       ring.name = "SelectionRing"
       ring.custom_minimum_size = Vector2(4, PORTRAIT_SIZE)
       ring.color = Color.WHITE
       ring.visible = unit != null and grid.selected_unit == unit
       hbox.add_child(ring)

       return row


   func _find_unit(adventurer_id: String):
       for unit in grid.units:
           if unit.adventurer_id == adventurer_id:
               return unit
       return null
   ```

5. In `scenes/battle/battlefield.tscn`, add a `portrait_panel.gd`
   `ext_resource` and a new node under `HUD`, positioned on the left
   (mirroring the right-side HUD labels' offset style):

   ```
   [node name="PortraitPanel" type="Control" parent="HUD"]
   offset_left = 16.0
   offset_top = 170.0
   offset_right = 220.0
   offset_bottom = 520.0
   script = ExtResource("<next_id>_portrait_panel")

   [node name="Rows" type="VBoxContainer" parent="HUD/PortraitPanel"]
   layout_mode = 2
   ```
6. In `battlefield.gd`, add `@onready var portrait_panel: Control =
   $HUD/PortraitPanel` next to the other `@onready` HUD vars; in `_ready()`,
   set `portrait_panel.grid = grid` before the existing `_on_board_changed()`
   call; in `_on_board_changed()`, add `portrait_panel.refresh()` alongside
   the existing `_update_health_labels()` call.
7. Rerun the portrait tests from step 2 green.

### HUD adjustments

8. Replace `test_ready_shows_full_health_for_both_units` and
   `test_health_label_shows_defeated_after_a_unit_dies` in
   `test_battlefield.gd`:
   - `test_ready_lists_each_living_enemys_health`: the default (fallback)
     battlefield's `enemy_health` container has exactly 2 children (the
     fallback Goblin Camp's two goblins), each `Label.text` equal to
     `tr("battle.status.health") % [tr("battle.side.enemy"), 3, 3]`.
   - `test_enemy_health_list_drops_a_defeated_enemy`: defeat one goblin
     (`take_damage` to 0 then `grid.units.erase(goblin)`), call
     `battlefield._update_health_labels()`; `enemy_health.get_child_count()
     == 1`.
   - `test_player_health_label_no_longer_exists`: `not
     battlefield.has_node("HUD/PlayerHealth")`.
9. Run `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield
   -gexit`. Expected: these three fail (old label API still in place).
10. Implement:
    - In `battlefield.tscn`, delete the `PlayerHealth` node entirely; change
      `EnemyHealth`'s node `type` from `Label` to `VBoxContainer` and drop
      its `text` property (reposition `offset_top`/`offset_bottom` upward to
      fill the gap `PlayerHealth` left, purely cosmetic).
    - In `battlefield.gd`, delete `@onready var player_health: Label =
      $HUD/PlayerHealth` and change `@onready var enemy_health: Label` to
      `@onready var enemy_health: VBoxContainer`.
    - Replace `_update_health_labels()`, and delete the now-unused
      `_format_health()` and `_find_unit_by_side()` helpers it was the only
      caller of:

      ```gdscript
      func _update_health_labels() -> void:
          for child in enemy_health.get_children():
              child.queue_free()
          for unit in grid.units:
              if unit.side != BattleControllerScript.Side.ENEMY:
                  continue
              var label := Label.new()
              label.text = tr("battle.status.health") % [tr("battle.side.enemy"), unit.health, unit.max_health]
              enemy_health.add_child(label)
      ```
11. Rerun `test_battlefield` green, then the full suite (`make check`) —
    this should be the first fully green run since Task 3.
12. Commit:

    ```bash
    git add scripts/battle/portrait_panel.gd scenes/battle/battlefield.tscn \
      scripts/battle/battlefield.gd tests/unit/test_battlefield.gd
    git commit -m "feat: add the party portrait panel and a per-enemy health HUD"
    ```

## Milestone

The battlefield shows one portrait per fielded party member (health,
selection ring, dimmed when defeated, clickable), and the HUD lists every
living enemy's health individually instead of one aggregate player label
and one aggregate enemy label. Full suite green.
