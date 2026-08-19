extends GutTest

## Floating Combat Text Spawner (Technical Design §2, docs/plans/2026-08-18-
## core-loop-and-engagement/07-visual-perspective-and-tactical-polish.md).

const FloatingTextScene := preload("res://scenes/battle/floating_text.tscn")
const FloatingTextScript := preload("res://scripts/battle/floating_text.gd")


func test_play_shows_red_text_for_damage() -> void:
	var node: Label = FloatingTextScene.instantiate()
	add_child_autofree(node)

	node.play(Vector2(100, 200), "-14", FloatingTextScript.TYPE_DAMAGE)

	assert_eq(node.text, "-14")
	assert_eq(node.position, Vector2(100, 200))
	assert_eq(node.modulate, FloatingTextScript.COLORS[FloatingTextScript.TYPE_DAMAGE])
	assert_true(node.visible)
	assert_true(node.is_active)


func test_play_shows_enlarged_golden_text_for_a_critical_hit() -> void:
	var node: Label = FloatingTextScene.instantiate()
	add_child_autofree(node)

	node.play(Vector2.ZERO, "CRIT! -28", FloatingTextScript.TYPE_CRITICAL)

	assert_eq(node.text, "CRIT! -28")
	assert_eq(node.modulate, FloatingTextScript.COLORS[FloatingTextScript.TYPE_CRITICAL])
	assert_eq(node.get_theme_font_size("font_size"), FloatingTextScript.CRIT_FONT_SIZE)


func test_play_shows_bright_green_text_for_healing() -> void:
	var node: Label = FloatingTextScene.instantiate()
	add_child_autofree(node)

	node.play(Vector2.ZERO, "+12 HP", FloatingTextScript.TYPE_HEAL)

	assert_eq(node.text, "+12 HP")
	assert_eq(node.modulate, FloatingTextScript.COLORS[FloatingTextScript.TYPE_HEAL])


func test_play_shows_gray_text_for_a_miss() -> void:
	var node: Label = FloatingTextScene.instantiate()
	add_child_autofree(node)

	node.play(Vector2.ZERO, "MISS", FloatingTextScript.TYPE_MISS)

	assert_eq(node.text, "MISS")
	assert_eq(node.modulate, FloatingTextScript.COLORS[FloatingTextScript.TYPE_MISS])


## No Guard-block/absorb mechanic exists in battle_controller.gd today (see
## floating_text.gd's own doc comment on TYPE_BLOCKED), so nothing in real
## play spawns this type yet -- but the component itself must already
## support it correctly, ready for the moment such a mechanic ships.
func test_play_shows_blue_shield_text_for_a_guard_absorbed_hit() -> void:
	var node: Label = FloatingTextScene.instantiate()
	add_child_autofree(node)

	node.play(Vector2.ZERO, "BLOCKED", FloatingTextScript.TYPE_BLOCKED)

	assert_eq(node.text, "BLOCKED")
	assert_eq(node.modulate, FloatingTextScript.COLORS[FloatingTextScript.TYPE_BLOCKED])


func test_play_a_non_critical_type_uses_the_default_font_size() -> void:
	var node: Label = FloatingTextScene.instantiate()
	add_child_autofree(node)

	node.play(Vector2.ZERO, "-3", FloatingTextScript.TYPE_DAMAGE)

	assert_eq(node.get_theme_font_size("font_size"), FloatingTextScript.DEFAULT_FONT_SIZE)


func test_animation_rises_above_its_starting_position_shortly_after_play() -> void:
	var node: Label = FloatingTextScene.instantiate()
	add_child_autofree(node)
	var start_y := 200.0

	node.play(Vector2(0, start_y), "-5", FloatingTextScript.TYPE_DAMAGE)
	await get_tree().create_timer(0.15).timeout

	assert_lt(node.position.y, start_y, "The text must rise (decreasing y) toward RISE_DISTANCE above its start")
	assert_true(node.is_active, "Still mid-animation partway through DURATION")


## Lifecycle: once the animation finishes, the instance frees itself for
## reuse by the pool (is_active/visible both flip back off, and the
## `finished` signal fires so a pool could react to it) rather than queuing
## its own removal -- BattleController's pool keeps reusing the same node.
func test_finish_marks_the_instance_inactive_and_hidden_and_emits_finished() -> void:
	var node: Label = FloatingTextScene.instantiate()
	add_child_autofree(node)
	node.play(Vector2.ZERO, "-1", FloatingTextScript.TYPE_DAMAGE)
	watch_signals(node)

	node._finish()

	assert_false(node.is_active, "A finished instance must be recyclable by the pool")
	assert_false(node.visible)
	assert_signal_emitted(node, "finished")


## Reusing a still-animating instance (the pool does this once every other
## slot is busy) must not leak a stale tween -- the new play() call replaces
## the old animation outright rather than fighting it for the node's
## position/modulate.
func test_play_again_on_a_still_animating_instance_restarts_cleanly() -> void:
	var node: Label = FloatingTextScene.instantiate()
	add_child_autofree(node)
	node.play(Vector2(0, 0), "-1", FloatingTextScript.TYPE_DAMAGE)

	node.play(Vector2(10, 30), "-2", FloatingTextScript.TYPE_DAMAGE)

	assert_eq(node.text, "-2")
	assert_eq(node.position, Vector2(10, 30))
	assert_true(node.is_active)
