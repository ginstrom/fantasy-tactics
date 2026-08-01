# Godot Skeleton Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Scaffold a lean Godot 4.7.1 / GDScript 2D starter (boot → menu → game) and publish it as a public MIT GitHub repo.

**Architecture:** Hand-authored `project.godot` with Boot as main scene, GameManager autoload for scene transitions, and placeholder asset folders. No gameplay systems.

**Tech Stack:** Godot 4.7.1, GDScript, Git, GitHub (`gh`), MIT license

**Design:** @docs/plans/2026-08-01-godot-skeleton-design.md

**Note:** Godot is not installed in this environment. Verify by file contents and `gh` success; open-in-editor smoke test is manual for the user.

---

### Task 1: Repo hygiene files

**Files:**
- Create: `.gitignore`
- Create: `LICENSE`
- Create: `README.md`
- Create: `icon.svg`

**Step 1: Write `.gitignore`**

```gitignore
# Godot 4+
.godot/
.import/
export.cfg
export_presets.cfg
*.translation

# Mono / C# (unused, but harmless)
.mono/
data_*/
mono_crash.*.json

# OS / editor
.DS_Store
Thumbs.db
*~
*.swp
.vscode/
.idea/
```

**Step 2: Write `LICENSE` (MIT, copyright year 2026, author from `gh` account name / git user)**

Use standard MIT text. Copyright holder: resolve via `gh api user --jq .login` or git `user.name` (do not invent a legal name).

**Step 3: Write `README.md`**

Include: project name, one-line description, required Godot **4.7.1**, how to open (`Godot → Import → project.godot`), folder map, MIT license note.

**Step 4: Write a simple `icon.svg`**

Minimal geometric SVG (e.g. dark shield/square with accent) so `project.godot` `config/icon` resolves. Keep it tiny and original.

**Step 5: Commit**

```bash
git add .gitignore LICENSE README.md icon.svg
git commit -m "$(cat <<'EOF'
chore: add repo hygiene and project icon

EOF
)"
```

---

### Task 2: Folder structure and asset placeholders

**Files:**
- Create: `assets/sprites/.gitkeep`
- Create: `assets/audio/.gitkeep`
- Create: `assets/fonts/.gitkeep`
- Create: `scripts/ui/.gitkeep`
- Create: `scripts/game/.gitkeep`

**Step 1: Create directories and `.gitkeep` files**

```bash
mkdir -p assets/sprites assets/audio assets/fonts scripts/ui scripts/game
touch assets/sprites/.gitkeep assets/audio/.gitkeep assets/fonts/.gitkeep \
  scripts/ui/.gitkeep scripts/game/.gitkeep
```

**Step 2: Commit**

```bash
git add assets scripts
git commit -m "$(cat <<'EOF'
chore: add assets and scripts folder placeholders

EOF
)"
```

---

### Task 3: GameManager autoload

**Files:**
- Create: `scripts/autoload/game_manager.gd`

**Step 1: Implement GameManager**

```gdscript
extends Node

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const GAME_SCENE := "res://scenes/game/game.tscn"


func go_to_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func go_to_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func quit_game() -> void:
	get_tree().quit()
```

**Step 2: Sanity-check file exists and parses as UTF-8 text**

```bash
test -f scripts/autoload/game_manager.gd && wc -l scripts/autoload/game_manager.gd
```

Expected: file present, non-zero lines.

**Step 3: Commit**

```bash
git add scripts/autoload/game_manager.gd
git commit -m "$(cat <<'EOF'
feat: add GameManager autoload for scene transitions

EOF
)"
```

---

### Task 4: Boot scene

**Files:**
- Create: `scripts/boot/boot.gd`
- Create: `scenes/boot/boot.tscn`

**Step 1: Write boot script**

```gdscript
extends Node


func _ready() -> void:
	GameManager.go_to_main_menu()
```

**Step 2: Write boot scene**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/boot/boot.gd" id="1_boot"]

[node name="Boot" type="Node"]
script = ExtResource("1_boot")
```

**Step 3: Commit**

```bash
git add scripts/boot/boot.gd scenes/boot/boot.tscn
git commit -m "$(cat <<'EOF'
feat: add boot scene that hands off to main menu

EOF
)"
```

---

### Task 5: Main menu scene

**Files:**
- Create: `scripts/ui/main_menu.gd`
- Create: `scenes/ui/main_menu.tscn`
- Delete if present: `scripts/ui/.gitkeep` (folder now has real files)

**Step 1: Write main menu script**

```gdscript
extends Control


func _on_new_game_pressed() -> void:
	GameManager.go_to_game()


func _on_quit_pressed() -> void:
	GameManager.quit_game()
```

**Step 2: Write main menu scene**

Centered title + two buttons wired to the script signals:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/main_menu.gd" id="1_menu"]

[node name="MainMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_menu")

[node name="Center" type="CenterContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="VBox" type="VBoxContainer" parent="Center"]
layout_mode = 2
theme_override_constants/separation = 16

[node name="Title" type="Label" parent="Center/VBox"]
layout_mode = 2
text = "Fantasy Tactics"
horizontal_alignment = 1

[node name="NewGameButton" type="Button" parent="Center/VBox"]
layout_mode = 2
text = "New Game"

[node name="QuitButton" type="Button" parent="Center/VBox"]
layout_mode = 2
text = "Quit"

[connection signal="pressed" from="Center/VBox/NewGameButton" to="." method="_on_new_game_pressed"]
[connection signal="pressed" from="Center/VBox/QuitButton" to="." method="_on_quit_pressed"]
```

**Step 3: Remove `scripts/ui/.gitkeep` if it exists**

**Step 4: Commit**

```bash
git add scripts/ui scenes/ui
git add -u scripts/ui/.gitkeep
git commit -m "$(cat <<'EOF'
feat: add main menu with new game and quit

EOF
)"
```

---

### Task 6: Game scene stub

**Files:**
- Create: `scripts/game/game.gd`
- Create: `scenes/game/game.tscn`
- Delete if present: `scripts/game/.gitkeep`

**Step 1: Write game script**

```gdscript
extends Node2D


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameManager.go_to_main_menu()
		get_viewport().set_input_as_handled()
```

**Step 2: Write game scene**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/game/game.gd" id="1_game"]

[node name="Game" type="Node2D"]
script = ExtResource("1_game")

[node name="Battlefield" type="Node2D" parent="."]

[node name="HUD" type="CanvasLayer" parent="."]

[node name="Hint" type="Label" parent="HUD"]
offset_left = 16.0
offset_top = 16.0
offset_right = 480.0
offset_bottom = 48.0
text = "Game stub — Esc returns to menu"
```

**Step 3: Remove `scripts/game/.gitkeep` if it exists**

**Step 4: Commit**

```bash
git add scripts/game scenes/game
git add -u scripts/game/.gitkeep
git commit -m "$(cat <<'EOF'
feat: add empty game scene stub with HUD hint

EOF
)"
```

---

### Task 7: `project.godot`

**Files:**
- Create: `project.godot`

**Step 1: Write project config**

```
; Engine configuration file.
; It's best edited using the editor UI and not directly,
; but checking into version control is fine for a skeleton.
config_version=5

[application]

config/name="Fantasy Tactics"
config/description="2D turn-based tactics skeleton"
run/main_scene="res://scenes/boot/boot.tscn"
config/features=PackedStringArray("4.7", "Forward Plus")
config/icon="res://icon.svg"

[autoload]

GameManager="*res://scripts/autoload/game_manager.gd"

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]

textures/canvas_textures/default_texture_filter=0
renderer/rendering_method="forward_plus"
```

**Step 2: Verify required paths referenced by project exist**

```bash
test -f project.godot \
  && test -f scenes/boot/boot.tscn \
  && test -f scenes/ui/main_menu.tscn \
  && test -f scenes/game/game.tscn \
  && test -f scripts/autoload/game_manager.gd \
  && test -f icon.svg
```

Expected: all succeed (exit 0).

**Step 3: Commit**

```bash
git add project.godot
git commit -m "$(cat <<'EOF'
feat: add Godot 4.7 project config and main scene

EOF
)"
```

---

### Task 8: Publish to GitHub

**Files:**
- None (remote + GitHub only)

**Step 1: Confirm auth as ginstrom (keyring), not broken `GITHUB_TOKEN`**

```bash
GH_TOKEN= gh auth status
```

If `GITHUB_TOKEN` env is invalid, unset it for `gh` commands: `env -u GITHUB_TOKEN gh ...`

**Step 2: Create public repo and push**

```bash
env -u GITHUB_TOKEN gh repo create fantasy-tactics \
  --public \
  --source=. \
  --remote=origin \
  --push \
  --description "2D turn-based tactics game (Godot 4.7 / GDScript)"
```

Expected: repo URL printed; `git status` clean and tracking `origin/main`.

**Step 3: Verify remote**

```bash
env -u GITHUB_TOKEN gh repo view ginstrom/fantasy-tactics --json url,visibility,licenseInfo
```

Expected: public visibility; MIT if GitHub detected `LICENSE` (may show after detection).

**Step 4: No further commit required** unless `gh` rewrote something unexpected (it should not).

---

### Manual smoke test (user)

After clone/open on a machine with Godot 4.7.1:

1. Import `project.godot`
2. Run project → main menu appears
3. New Game → game stub + Esc returns to menu
4. Quit → exits
