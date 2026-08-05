# Step 3: Reusable Information Panel

**Milestone:** Encampment and World Map each include the same right-side `InformationPanel`, whose sole current value is banked `GameSession.gold`.

## Setup

```bash
git checkout main
git pull --ff-only
git checkout -b feat/gold-information-panel
```

## Files

- Create: `scenes/ui/information_panel.tscn`, `scripts/ui/information_panel.gd`, `tests/unit/test_information_panel.gd`
- Modify: `scenes/ui/encampment.tscn`, `scenes/world/world_map.tscn`, `scripts/ui/encampment.gd`, `scripts/world/world_map.gd`, `translations/en.tres`
- Modify: `tests/unit/test_encampment.gd`, `tests/unit/test_world_map.gd`, `tests/unit/test_localization.gd`

## Red/green TDD

1. Create `test_information_panel.gd`. Instantiate `res://scenes/ui/information_panel.tscn`, set `GameSession.gold = 25`, call public `refresh()`, and assert:

   ```gdscript
   assert_eq(panel.get_node("Content/Title").text, "information.title")
   assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)
   ```

   Add scene integration tests in `test_encampment.gd` and `test_world_map.gd`: each scene contains its `InformationPanel` and the panel refreshes to the same current total.

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_information_panel.gd -gexit
   ```

   Expected: FAIL because the scene/script are absent.

2. Create `information_panel.tscn` as a generic `PanelContainer` with right-side-friendly minimum width and `Content` (`VBoxContainer`), `Title`, and `Gold` labels. Attach `information_panel.gd`:

   ```gdscript
   extends PanelContainer

   @onready var gold_label: Label = $Content/Gold

   func _ready() -> void:
       refresh()

   func refresh() -> void:
       gold_label.text = tr("information.gold") % GameSession.gold
   ```

   Use `information.title` as static title text. The component owns no resource state, is not named `GoldPanel`, and has no pending-reward row. Run focused test; expected: PASS.

3. Instance that exact packed scene as root child `InformationPanel` in `encampment.tscn`, anchored right with readable margins. Instance it at `HUD/InformationPanel` in `world_map.tscn`, right-aligned without overlapping End Turn. Add onready references; call its `refresh()` from Encampment’s existing `refresh()` and World Map’s initial UI update. Scene code only rereads state; it never changes gold.

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_encampment.gd -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_world_map.gd -gexit
   ```

   Expected: PASS.

4. Add and assert translations:

   ```text
   information.title = Information
   information.gold = Gold: %d
   ```

   Check that static scene copy remains translation keys, not player-facing literals.

## Verification

```bash
make check
godot --headless --path . --editor --quit
git diff --check
```

All commands must exit `0`; include generated sidecars.

## Manual verification and merge

Run `make play`. Open Encampment then World Map and confirm both show a right-aligned `Information` / `Gold: 0` panel. After a reward is deposited, confirm both show `Gold: 10` or `Gold: 25`; confirm map controls and battle UI are unobstructed.

After user signoff:

```bash
git add scenes/ui/information_panel.tscn scripts/ui/information_panel.gd scenes/ui/encampment.tscn scenes/world/world_map.tscn scripts/ui/encampment.gd scripts/world/world_map.gd translations/en.tres tests/unit/test_information_panel.gd tests/unit/test_encampment.gd tests/unit/test_world_map.gd tests/unit/test_localization.gd
git add scripts/ui/information_panel.gd.uid tests/unit/test_information_panel.gd.uid
git commit -m "feat: show gold in strategic information panel"
git checkout main
git merge --ff-only feat/gold-information-panel
git branch -d feat/gold-information-panel
```

Do not push.
