# Step 4: Portrait HP Overlay

> REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this task-by-task.

**Branch:** `portrait-hp-overlay`
**Depends on:** nothing else in this plan — safe to do in any order
relative to Steps 2/3/5 (only depends on `main` as it stands today, or
after Step 1; it touches files none of the other steps touch).

**Goal:** Each portrait row's `"3/8"` HP text renders on top of the
colored swatch instead of beside it, closer to a real HP-bar-on-portrait
look. Same text format, same underlying data — purely a layout change.

**Files:**
- Modify: `scripts/battle/portrait_panel.gd`
- Modify: `tests/unit/test_battlefield.gd`

**Context you need:**
- `scripts/battle/portrait_panel.gd`'s `_build_row()` currently builds an
  `HBoxContainer` with three siblings: `Swatch` (48×48 `ColorRect`),
  `Health` (a `Label`, sized to its text), `SelectionRing` (4×48). This
  step nests `Swatch` and `Health` inside a new plain `Control` wrapper
  (`SwatchStack`) so `Health` can be absolutely positioned over `Swatch`
  instead of taking its own space in the `HBoxContainer` row. `Swatch` and
  `Health` remain **direct children of that wrapper** (not moved anywhere
  else), so every existing test that does
  `row.find_child("Swatch", true, false)` /
  `row.find_child("Health", true, false)` (recursive search) keeps
  finding them at their same relative depth-from-root — those tests do
  not need to change.
- `SelectionRing` stays exactly where it is, as a sibling of the new
  wrapper in the row's `HBoxContainer` — this step doesn't touch it.
- Every child added directly to a plain `Control` (not a `Container`)
  needs `mouse_filter = Control.MOUSE_FILTER_IGNORE` explicitly, or it
  defaults to `MOUSE_FILTER_STOP` and can swallow the row `Button`'s
  click — this file's existing comments call this out repeatedly for
  exactly this reason; keep following that pattern for the two new nodes.

## Step 4a: Move the HP label onto the swatch

- [ ] **Write the failing test**

Add to `tests/unit/test_battlefield.gd`, after
`test_portrait_row_decorative_children_do_not_intercept_clicks`:

```gdscript
func test_portrait_health_label_overlays_the_swatch_instead_of_sitting_beside_it() -> void:
	_setup_two_member_party()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var row: Control = battlefield.portrait_panel.get_node("Rows/Portrait0")
	var swatch: Control = row.find_child("Swatch", true, false)
	var health_label: Label = row.find_child("Health", true, false)

	assert_eq(
		health_label.get_parent(), swatch.get_parent(),
		"The HP label must live in the same stack as the swatch, not as its sibling in the row's HBoxContainer"
	)
	assert_ne(
		health_label.get_parent(), row.find_child("HBoxContainer", true, false),
		"The HP label must no longer be a direct child of the row's top-level HBoxContainer"
	)
	assert_eq(health_label.text, "10/10")
```

Note: the row's top-level `HBoxContainer` is created anonymously in
`_build_row()` (`var hbox := HBoxContainer.new()`, no explicit `.name`
assignment) — Godot auto-names it `"HBoxContainer"` since it's the first
node of that type added under `row`. Confirm this by running the test
below before writing implementation and reading the failure output if the
name assumption is wrong; if Godot assigned a different auto-name, use
that instead of guessing further.

- [ ] **Run to verify it fails**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gunit_test_name=overlays_the_swatch -gexit
```
Expected: FAIL — `health_label.get_parent() == swatch.get_parent()` is
already incidentally true today (both are direct children of the same
`HBoxContainer`), so the *first* assertion actually passes already; the
**second** assertion (`assert_ne` against the top-level `HBoxContainer`)
is the one that fails, since today `Health` *is* a direct child of it.
Confirm the failure is on that second assertion specifically before
proceeding.

- [ ] **Implement in `portrait_panel.gd`**

In `_build_row()`, replace the `swatch` and `health_label` construction
block — currently:

```gdscript
	var swatch := ColorRect.new()
	swatch.name = "Swatch"
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	swatch.color = BattleControllerScript.PLAYER_COLORS[index % BattleControllerScript.PLAYER_COLORS.size()]
	hbox.add_child(swatch)

	var health_label := Label.new()
	health_label.name = "Health"
	health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_label.text = (
		"%d/%d" % [unit.health, unit.max_health] if unit != null
		else tr("battle.status.defeated") % GameSession.get_adventurer(adventurer_id).get("name", "")
	)
	hbox.add_child(health_label)
```

with:

```gdscript
	var swatch_stack := Control.new()
	swatch_stack.name = "SwatchStack"
	swatch_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch_stack.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	hbox.add_child(swatch_stack)

	var swatch := ColorRect.new()
	swatch.name = "Swatch"
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	swatch.color = BattleControllerScript.PLAYER_COLORS[index % BattleControllerScript.PLAYER_COLORS.size()]
	swatch_stack.add_child(swatch)

	var health_backing := ColorRect.new()
	health_backing.name = "HealthBacking"
	health_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_backing.color = HEALTH_BACKING_COLOR
	health_backing.position = Vector2(0, PORTRAIT_SIZE - HEALTH_LABEL_HEIGHT)
	health_backing.size = Vector2(PORTRAIT_SIZE, HEALTH_LABEL_HEIGHT)
	swatch_stack.add_child(health_backing)

	var health_label := Label.new()
	health_label.name = "Health"
	health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.position = Vector2(0, PORTRAIT_SIZE - HEALTH_LABEL_HEIGHT)
	health_label.size = Vector2(PORTRAIT_SIZE, HEALTH_LABEL_HEIGHT)
	health_label.text = (
		"%d/%d" % [unit.health, unit.max_health] if unit != null
		else tr("battle.status.defeated") % GameSession.get_adventurer(adventurer_id).get("name", "")
	)
	swatch_stack.add_child(health_label)
```

Add the two new constants next to the existing ones at the top of the
file:

```gdscript
const HEALTH_LABEL_HEIGHT := 16
const HEALTH_BACKING_COLOR := Color(0, 0, 0, 0.55)
```

- [ ] **Run to verify it passes**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gexit
```
Expected: `N/N passed.` — including every pre-existing portrait test
(`test_portrait_panel_shows_one_row_per_fielded_party_member`,
`test_portrait_row_decorative_children_do_not_intercept_clicks`,
`test_portrait_row_click_target_spans_its_visible_content`,
`test_portrait_panel_shows_the_selection_ring_on_the_selected_member`,
`test_portrait_panel_dims_a_defeated_member`,
`test_clicking_a_portrait_selects_that_party_member`): all of them locate
`Swatch`/`Health`/`SelectionRing` via recursive `find_child()`, assert on
`row.size`/`row.modulate`/click behavior, or check text content — none
inspect the immediate parent of `Swatch`/`Health`, so nesting them one
level deeper under `SwatchStack` doesn't break any of them. `row.size.y`
in `test_portrait_row_click_target_spans_its_visible_content` is still
governed by `SwatchStack`'s `custom_minimum_size.y = PORTRAIT_SIZE` inside
the `HBoxContainer`, same as before.

- [ ] **Commit**

```bash
git add scripts/battle/portrait_panel.gd tests/unit/test_battlefield.gd
git commit -m "feat: overlay portrait HP text on the swatch instead of beside it"
```

## Manual verification

1. `make play`
2. Debug menu (**FN+F9**) → **Ruined Fortress** (three portraits, easy to
   compare side by side).
3. Confirm each portrait row shows its HP (e.g. `10/10`) rendered
   centered near the bottom of the colored swatch, with a dark
   semi-transparent backing behind the text for legibility, not as
   separate text to the right of the swatch.
4. Attack with a unit, take damage from the enemy turn, and confirm the
   overlaid number updates correctly as HP changes.
5. Let a party member reach 0 HP; confirm the defeated-state text/dimming
   still works (row `modulate` dims, text still shows via the same
   `Health` node, now overlaid).

## Full run and merge

```bash
make check
```
Expected: `N/N passed.` / `---- All tests passed! ----`, exit 0.

```bash
git checkout main
git merge portrait-hp-overlay
git branch -d portrait-hp-overlay
```
