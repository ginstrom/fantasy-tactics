extends Label

## Lightweight, pooled floating combat text (Technical Design §2,
## docs/plans/2026-08-18-core-loop-and-engagement/
## 07-visual-perspective-and-tactical-polish.md). A single instance is
## reused across many spawns via play() -- BattleController owns the actual
## pool (see _spawn_combat_text()/_acquire_floating_text() in
## battle_controller.gd); this script only knows how to animate itself once
## told what to show, and reports back via is_active/finished so the pool
## can tell a free instance from a busy one.

signal finished

const TYPE_DAMAGE := "damage"
const TYPE_CRITICAL := "critical"
const TYPE_HEAL := "heal"
const TYPE_MISS := "miss"
## Guard-absorbed hits ("BLOCKED"/"-6 (Guard)" per the Technical Design)
## have no backing game mechanic yet -- no Guard-block/absorb rule exists in
## battle_controller.gd today, so nothing currently spawns this type in real
## play. Supported here (color, animation) so the type is ready the moment
## such a mechanic exists, and so it stays independently testable now.
const TYPE_BLOCKED := "blocked"
## Stage 5 D2 tactical primitives (docs/plans/2026-08-23-stage-5-strategic-
## roster-expansion/03-tactical-depth-primitives.md): a successful Dodge or
## Parry is a distinct outcome from a plain Guard-driven miss (TYPE_MISS) --
## always its own text ("DODGED!"/"PARRIED!"), never colour-only feedback
## (Stage 4's accessibility carryover). See battle_controller.gd's
## try_attack_selected_unit()/_resolve_opportunity_attack().
const TYPE_DODGE := "dodge"
const TYPE_PARRY := "parry"

const COLORS := {
	TYPE_DAMAGE: Color(0.9, 0.2, 0.2),
	TYPE_CRITICAL: Color(1.0, 0.85, 0.2),
	TYPE_HEAL: Color(0.3, 0.9, 0.4),
	TYPE_MISS: Color(0.7, 0.7, 0.7),
	TYPE_BLOCKED: Color(0.35, 0.6, 0.95),
	TYPE_DODGE: Color(0.4, 0.85, 0.9),
	TYPE_PARRY: Color(0.95, 0.75, 0.35),
}
const RISE_DISTANCE := 40.0
const DURATION := 0.6
const CRIT_PUNCH_DURATION := 0.2
const DEFAULT_FONT_SIZE := 16
const CRIT_FONT_SIZE := 24
const CRIT_START_SCALE := Vector2(1.6, 1.6)

var is_active: bool = false
var _tween: Tween


## Starts (or restarts, if this instance was mid-animation) the rise-and-fade
## presentation for one combat event. pos is Grid-local pixel space (see
## battle_controller.gd's _floating_text_anchor()).
func play(pos: Vector2, text_value: String, type: String) -> void:
	is_active = true
	visible = true
	text = text_value
	position = pos
	pivot_offset = size / 2.0
	modulate = Color(COLORS.get(type, Color.WHITE), 1.0)
	scale = CRIT_START_SCALE if type == TYPE_CRITICAL else Vector2.ONE
	add_theme_font_size_override("font_size", CRIT_FONT_SIZE if type == TYPE_CRITICAL else DEFAULT_FONT_SIZE)

	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not is_inside_tree():
		_finish()
		return

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position:y", pos.y - RISE_DISTANCE, DURATION)
	_tween.tween_property(self, "modulate:a", 0.0, DURATION)
	if type == TYPE_CRITICAL:
		_tween.tween_property(self, "scale", Vector2.ONE, CRIT_PUNCH_DURATION).set_trans(Tween.TRANS_BACK)
	_tween.chain().tween_callback(_finish)


func _finish() -> void:
	is_active = false
	visible = false
	finished.emit()
