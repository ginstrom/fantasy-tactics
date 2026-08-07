# Task 2: World Map HUD containers

## Objective

Apply the same container-based restructure from Task 1 to
`world_map.tscn`'s HUD: replace offset-positioned children with a
`Margin`/`VBox`/`TopRow` hierarchy, and fold the bottom hint bar's
`FeedbackPanel` + `Hint` pair into a single `PanelContainer` that lays out
its own label instead of two independently-offset nodes.

## Files

- Modify: `scenes/world/world_map.tscn`
- Modify: `scripts/world/world_map.gd`
- Modify: `tests/unit/test_world_map.gd`, `tests/unit/test_localization.gd`

## Current structure (for reference)

```
HUD (CanvasLayer)
├── FeedbackPanel (Panel)         offset-positioned, bottom bar background
├── Hint (Label)                  offset-positioned, bottom bar text
├── TurnLabel (Label)             offset-positioned, top-right
├── EndTurnButton (Button)        offset-positioned, top-right
└── InformationPanel (instance)   offset-positioned, top-right
```

(`CampNav` is not present here — it was removed from the World Map on
`fix/ui-selection-bugs`, per the earlier bugfix session; this task assumes
that's already merged, see the plan index's prerequisite note.)

## Target structure

```
HUD (CanvasLayer)
├── Margin (MarginContainer, layout_mode=1, full-rect anchors,
│           theme_override_constants/margin_* = 16)
│    └── VBox (VBoxContainer, layout_mode=2)
│         ├── TopRow (HBoxContainer, layout_mode=2)
│         │    └── TopRight (VBoxContainer, layout_mode=2,
│         │                 size_flags_horizontal = 8 [SHRINK_END])
│         │         ├── TurnLabel (Label) [unique_name_in_owner]
│         │         ├── EndTurnButton (Button) [unique_name_in_owner]
│         │         └── InformationPanel (instance) [unique_name_in_owner]
│         ├── Spacer (Control, layout_mode=2,
│         │          size_flags_vertical = 3 [EXPAND_FILL])  — pushes the
│         │          bottom bar down; the board itself is drawn separately
│         │          under `Board` (Node2D), not inside this HUD tree, so
│         │          this row has no other content
│         └── BottomPanel (PanelContainer, layout_mode=2)
│              [was `FeedbackPanel`, type changed from `Panel` to
│              `PanelContainer` so it lays out its child with theme
│              padding instead of a second manually-offset node]
│              └── Hint (Label, layout_mode=2, autowrap_mode=3)
│                  [unique_name_in_owner]
```

`TopRow` has only one child (`TopRight`) since, unlike the battlefield, the
World Map HUD has no top-left content — `TopRight`'s `SHRINK_END` size flag
still pushes it to the right edge of the full-width `TopRow`.

## Steps

### 1. Restructure the scene

1. Rewrite `world_map.tscn`'s `HUD` block to the target structure. Delete
   the standalone `FeedbackPanel` node; its role is taken over by
   `BottomPanel` (same node, renamed, retyped from `Panel` to
   `PanelContainer`, now parenting `Hint` directly instead of merely
   sitting behind it). Add `unique_name_in_owner = true` to `TurnLabel`,
   `EndTurnButton`, `InformationPanel`, `Hint`.
2. Tune `Margin`'s padding and `PanelContainer`'s theme padding against
   the pre-refactor `16_world_map.png` screenshot until the bottom hint bar
   and top-right stack occupy the same regions as before.

### 2. Update script and test references (red → green)

3. In `scripts/world/world_map.gd`, change:
   ```gdscript
   @onready var turn_label: Label = %TurnLabel
   @onready var end_turn_button: Button = %EndTurnButton
   @onready var information_panel: PanelContainer = %InformationPanel
   ```
   (Check whether `world_map.gd` also references `Hint` — if so, add
   `@onready var hint: Label = %Hint` in the same style as the other two.)
4. In `tests/unit/test_world_map.gd`, update all ten
   `get_node("HUD/InformationPanel")` / `get_node("HUD/EndTurnButton")` /
   `get_node("HUD/TurnLabel")` calls (lines ~504, 556, 564, 582, 599, 615,
   629, 808, 870 as of this writing) to `get_node("%InformationPanel")`,
   `get_node("%EndTurnButton")`, `get_node("%TurnLabel")` respectively.
   Leave `get_node_or_null("HUD/CampNav")` at line ~1054 untouched — it's
   asserting the node's absence, which holds regardless of this refactor.
5. In `tests/unit/test_localization.gd`, update the three world-map lookups
   (`get_node("HUD/Hint")`, `get_node("HUD/EndTurnButton")`,
   `get_node("HUD/TurnLabel")`) to their `%` equivalents.
6. Run `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_world_map
   -gexit` and `-gselect=test_localization`. Confirm the pre-step-3/4/5
   failure ("node not found") first, then apply the reference updates and
   confirm green.

### 3. Add structural regression tests

7. Add to `tests/unit/test_world_map.gd`:
   - `test_hud_top_right_stack_holds_turn_label_end_turn_and_information_panel`:
     all three share the same `get_parent()`.
   - `test_hud_bottom_panel_is_a_panel_container_not_a_manually_offset_panel`:
     `world_map.get_node("%Hint").get_parent() is PanelContainer`.
8. Run `-gselect=test_world_map -gexit`, confirm green.

### 4. Full suite and commit

9. Run `make check` (full suite). Fix any incidental breakage — in
   particular, re-check `test_first_campaign_ui_flow.gd` for any world-map
   HUD path that earlier sweeps might have missed (the CampNav removal
   sweep on `fix/ui-selection-bugs` only touched Encampment-family screens,
   not this HUD).
10. Commit:
    ```bash
    git add scenes/world/world_map.tscn scripts/world/world_map.gd \
      tests/unit/test_world_map.gd tests/unit/test_localization.gd
    git commit -m "refactor: rebuild the world map HUD from containers, not offsets"
    ```

## Milestone

`world_map.tscn`'s `HUD` is a real container tree with no manually-offset
children; the bottom hint bar is one `PanelContainer` instead of a
`Panel` + independently-offset `Label`; every HUD leaf node is reachable via
`%UniqueName`; `make check` is fully green; the regenerated
`16_world_map.png` (and `world_map_encounter_complete`,
`encampment_reward_deposited` if they touch this HUD) show the same regions
as before the refactor.
