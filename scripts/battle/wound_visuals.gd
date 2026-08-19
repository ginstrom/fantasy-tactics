class_name WoundVisuals
extends RefCounted
## Shared wound-tier visual constants and classification (Technical Design §3,
## docs/plans/2026-08-18-core-loop-and-engagement/07-visual-perspective-and-
## tactical-polish.md): Healthy 100-51% HP, Wounded 50-21%, Critical 20-1%,
## Slain 0.
##
## Used by both portrait_panel.gd (left party-portrait column) and
## unit_info_panel.gd (right-hand hovered/selected detail panel) so a future
## tuning pass to these thresholds/colors/glyphs/pulse timing only ever needs
## to touch one place, following the same static-helper convention as
## scripts/tools/campaign_sim_metrics.gd/scripts/ui/table_column.gd (class_
## name + extends RefCounted, no instance state).

const TIER_HEALTHY := "healthy"
const TIER_WOUNDED := "wounded"
const TIER_CRITICAL := "critical"
const TIER_SLAIN := "slain"

const WOUNDED_HEALTH_FRACTION := 0.50
const CRITICAL_HEALTH_FRACTION := 0.20

const HEALTH_BAR_COLORS := {
	TIER_HEALTHY: Color(0.3, 0.8, 0.3),
	TIER_WOUNDED: Color(0.9, 0.65, 0.15),
	TIER_CRITICAL: Color(0.85, 0.15, 0.15),
}

## Placeholder glyph badges (this step has design latitude on exact
## iconography): a diamond stands in for a blood drop (Wounded), a double
## exclamation for severe trauma (Critical), and a skull for Slain.
const WOUND_BADGE_GLYPHS := {
	TIER_WOUNDED: "♦",
	TIER_CRITICAL: "‼",
	TIER_SLAIN: "☠",
}

const PULSE_MIN_ALPHA := 0.35
const PULSE_DURATION := 0.5


## Classifies a unit's visual wound tier from raw health/max_health. Shared
## so portrait_panel.gd's roster strip and unit_info_panel.gd's hover/
## selected bars can never silently desync on where a tier boundary falls.
static func tier(health: int, max_health: int) -> String:
	if health <= 0:
		return TIER_SLAIN
	if max_health <= 0:
		return TIER_CRITICAL
	var fraction: float = float(health) / float(max_health)
	if fraction <= CRITICAL_HEALTH_FRACTION:
		return TIER_CRITICAL
	if fraction <= WOUNDED_HEALTH_FRACTION:
		return TIER_WOUNDED
	return TIER_HEALTHY


## Starts (active=true) or stops (active=false) a looping alpha-pulse tween on
## a health bar fill, always killing whatever tween the node had before so
## repeated calls (e.g. update_panel() firing on every board_changed, or a
## panel refresh) never stack duplicate tweens on the same node. Returns the
## new Tween (or null when inactive/not yet in the SceneTree) so the caller
## can hold onto it and pass it back in as existing_tween next time.
static func apply_pulse(fill: ColorRect, active: bool, existing_tween: Tween) -> Tween:
	if existing_tween != null and is_instance_valid(existing_tween):
		existing_tween.kill()
	fill.modulate = Color(1, 1, 1, 1)
	if not active or not fill.is_inside_tree():
		return null
	var tween := fill.create_tween()
	tween.set_loops()
	tween.tween_property(fill, "modulate:a", PULSE_MIN_ALPHA, PULSE_DURATION)
	tween.tween_property(fill, "modulate:a", 1.0, PULSE_DURATION)
	return tween
