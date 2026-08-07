# Task 1: Battlefield HUD containers

## Objective

Replace `battlefield.tscn`'s flat, manually-offset `HUD` children with a
container hierarchy (`Margin` → `VBox` → `TopRow`/`BodyRow`), and switch
every script/test reference to those nodes from a hardcoded path to a
`%UniqueName` lookup so the restructure doesn't ripple into unrelated logic
changes.

## Files

- Modify: `scenes/battle/battlefield.tscn`
- Modify: `scripts/battle/battlefield.gd`
- Modify: `tests/unit/test_battlefield.gd`, `tests/unit/test_localization.gd`

## Current structure (for reference)

```
HUD (CanvasLayer)
├── Hint (Label)            offset-positioned, top-left
├── Status (Label)          offset-positioned, top-left
├── EnemyHealth (VBoxContainer)  offset-positioned, top-left
├── PortraitPanel (Control) offset-positioned, left side
│    └── Rows (VBoxContainer)    already anchors full-rect — leave as is
├── RoundLabel (Label)      offset-positioned, top-right
├── EndTurnButton (Button)  offset-positioned, top-right
└── LevelUp (instance)      centered via anchor preset — leave as is
```

## Target structure

```
HUD (CanvasLayer)
├── Margin (MarginContainer, layout_mode=1, full-rect anchors,
│           theme_override_constants/margin_* = 16)
│    └── VBox (VBoxContainer, layout_mode=2)
│         ├── TopRow (HBoxContainer, layout_mode=2)
│         │    ├── TopLeft (VBoxContainer, layout_mode=2,
│         │    │           size_flags_horizontal = 3 [EXPAND_FILL])
│         │    │    ├── Hint (Label) [unique_name_in_owner]
│         │    │    ├── Status (Label) [unique_name_in_owner]
│         │    │    └── EnemyHealth (VBoxContainer) [unique_name_in_owner]
│         │    └── TopRight (VBoxContainer, layout_mode=2,
│         │                 size_flags_horizontal = 8 [SHRINK_END])
│         │         ├── RoundLabel (Label) [unique_name_in_owner]
│         │         └── EndTurnButton (Button) [unique_name_in_owner]
│         └── BodyRow (HBoxContainer, layout_mode=2,
│                      size_flags_vertical = 3 [EXPAND_FILL])
│              └── PortraitPanel (Control, layout_mode=2,
│                                custom_minimum_size = Vector2(204, 0),
│                                size_flags_vertical = 3) [unique_name_in_owner]
│                   └── Rows (VBoxContainer)   — untouched, still anchors
│                       full-rect *within PortraitPanel*, which is correct:
│                       PortraitPanel owns its own internal layout (Rule 3)
└── LevelUp (instance, unchanged)
```

`MarginContainer`, `HBoxContainer`, and `VBoxContainer` all default to
`MOUSE_FILTER_PASS`, so an empty region of `BodyRow` (to the right of
`PortraitPanel`, where the board is) lets clicks fall through to
`Grid`'s `_unhandled_input` unless a Button/Label under it explicitly stops
them — none do. This matters because board tile clicks are handled via
`_unhandled_input` in `battle_controller.gd`, not through the `Control`
tree, so anything that swallows the event before it goes "unhandled" would
silently break tile clicks. Flag this explicitly for the manual `make play`
pass in Task 3 — headless GUT cannot simulate real mouse-click hit-testing
(confirmed earlier this session: even a synthetic click on the
definitely-working `EndTurnButton` failed to register via
`push_input`/`parse_input_event`), so this specific regression can only be
caught by a human clicking a tile.

## Steps

### 1. Spike: confirm `%UniqueName` resolution

1. Add a throwaway assertion to `test_battlefield.gd` (e.g. inside the
   existing `test_ready_spawns_one_unit_per_party_member_in_party_order`
   setup, or a new tiny test) that sets `unique_name_in_owner = true` on
   one existing node (say `HUD/Hint`) via the `.tscn` and asserts
   `battlefield.get_node("%Hint") == battlefield.get_node("HUD/Hint")`.
2. Run it, confirm it passes, then remove the throwaway test (this is a
   one-line spec confirmation, not a permanent regression test — the real
   regression tests come in step 3).

### 2. Restructure the scene

3. Rewrite `battlefield.tscn`'s `HUD` block to the target structure above.
   Keep every leaf node's existing properties (`text`, `custom_minimum_size`
   on `PortraitPanel`'s children, etc.) — only their `parent=` path,
   `layout_mode`, and size-flag properties change; add
   `unique_name_in_owner = true` to `Hint`, `Status`, `EnemyHealth`,
   `RoundLabel`, `EndTurnButton`, `PortraitPanel`.
4. Tune `MarginContainer`'s margin and `VBoxContainer`/`HBoxContainer`
   separation theme constants against the pre-refactor screenshot
   (`17_battlefield.png`) until the visual regions line up — exact pixel
   values aren't prescribed here, matching "same regions, no overlap" is
   the bar.

### 3. Update script and test references (red → green)

5. In `scripts/battle/battlefield.gd`, change the six `@onready` HUD
   lookups from `$HUD/Name` to `%Name`:
   ```gdscript
   @onready var hint: Label = %Hint
   @onready var status: Label = %Status
   @onready var enemy_health: VBoxContainer = %EnemyHealth
   @onready var round_label: Label = %RoundLabel
   @onready var end_turn_button: Button = %EndTurnButton
   @onready var portrait_panel: Control = %PortraitPanel
   ```
   (`grid` and `level_up` are unaffected — `Grid` isn't under `HUD`, and
   `LevelUp` keeps its direct `$HUD/LevelUp` path.)
6. In `tests/unit/test_localization.gd`, update the four battlefield
   lookups (`get_node("HUD/EndTurnButton")`, `get_node("HUD/Status")`,
   `get_node("HUD/Hint")`, `get_node("HUD/RoundLabel")`) to
   `get_node("%EndTurnButton")`, `get_node("%Status")`,
   `get_node("%Hint")`, `get_node("%RoundLabel")`.
7. Run `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield
   -gexit` and `-gselect=test_localization`. Before step 5/6, these fail
   with "node not found" against the restructured scene — confirm that
   failure first, then apply steps 5/6 and confirm green.

### 4. Add structural regression tests

8. Add to `tests/unit/test_battlefield.gd` (near the existing portrait
   panel tests):
   - `test_hud_hint_and_status_share_the_top_left_stack`: `hint.get_parent()
     == status.get_parent()` and `enemy_health.get_parent() ==
     hint.get_parent()`.
   - `test_hud_round_label_and_end_turn_button_share_the_top_right_stack`:
     `round_label.get_parent() == end_turn_button.get_parent()`.
   - `test_portrait_panel_is_container_driven_not_offset_positioned`:
     `battlefield.portrait_panel.get_parent() is Container` (regression
     guard against reintroducing a manually-offset `Control` parent, i.e.
     re-breaking the guideline this task fixes).
9. Run `-gselect=test_battlefield -gexit`, confirm green.

### 5. Full suite and commit

10. Run `make check` (full suite). Fix any incidental breakage.
11. Commit:
    ```bash
    git add scenes/battle/battlefield.tscn scripts/battle/battlefield.gd \
      tests/unit/test_battlefield.gd tests/unit/test_localization.gd
    git commit -m "refactor: rebuild the battlefield HUD from containers, not offsets"
    ```

## Milestone

`battlefield.tscn`'s `HUD` is a real container tree (`Margin` → `VBox` →
`TopRow`/`BodyRow`) with no manually-offset children except the `LevelUp`
modal; every HUD leaf node is reachable via `%UniqueName` from both
`battlefield.gd` and the test suite; `make check` is fully green; the
regenerated `17_battlefield.png` (and any level-up screenshots) show the
same regions as before the refactor.
