extends PanelContainer

const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")

const HEALTHY_THRESHOLD := 0.66
const WOUNDED_THRESHOLD := 0.33

## The visual wound-tier thresholds/colors/badge glyphs/pulse timing and the
## tier-classification function itself live in wound_visuals.gd, shared with
## portrait_panel.gd. Deliberately a second, distinct scale from
## HEALTHY_THRESHOLD/WOUNDED_THRESHOLD above (66%/33%), which back the
## pre-existing "battle.unit_info.wounded"/"badly_wounded" enemy-only text
## (_wound_tier_key()) and are left untouched -- this is the new health-bar-
## color/badge tier, not a second text system.
const HEALTH_BAR_WIDTH := 180.0
## An enemy's hovered health bar must never leak more precision than the
## existing text tier already withholds (_wound_tier_key() only ever says
## "Healthy"/"Wounded"/"Badly Wounded", never a number) -- so unlike the
## selected/player section (always exact, since HpLabel already prints exact
## numbers), a hovered enemy's bar fills to one of these fixed, tier-only
## widths rather than its true health fraction. See _update_health_visual().
const ENEMY_BAR_DISPLAY_FRACTIONS := {
	WoundVisuals.TIER_HEALTHY: 1.0,
	WoundVisuals.TIER_WOUNDED: 0.5,
	WoundVisuals.TIER_CRITICAL: 0.15,
}

## Cardinal Unit.facing -> its translation key (see translations/en.tres'
## battle.facing.* entries). Shown in both the hovered and selected sections
## (unlike class/HP/wound, which are side-conditional) -- Steps 2/3 of this
## plan (critical hits, flanking) make an enemy's facing just as tactically
## relevant as an ally's.
const FACING_KEYS := {
	Vector2i.RIGHT: "battle.facing.east",
	Vector2i.LEFT: "battle.facing.west",
	Vector2i.UP: "battle.facing.north",
	Vector2i.DOWN: "battle.facing.south",
}

@onready var empty_label: Label = $Content/EmptyLabel
@onready var hovered_section: VBoxContainer = $Content/HoveredSection
@onready var hovered_name_label: Label = $Content/HoveredSection/NameLabel
@onready var hovered_facing_label: Label = $Content/HoveredSection/FacingLabel
@onready var hovered_class_label: Label = $Content/HoveredSection/ClassLabel
@onready var hovered_hp_label: Label = $Content/HoveredSection/HpLabel
@onready var hovered_health_fill: ColorRect = $Content/HoveredSection/HealthBar/Fill
@onready var hovered_wound_badge: Label = $Content/HoveredSection/WoundBadge
@onready var hovered_wound_label: Label = $Content/HoveredSection/WoundLabel
@onready var selected_section: VBoxContainer = $Content/SelectedSection
@onready var selected_name_label: Label = $Content/SelectedSection/NameLabel
@onready var selected_facing_label: Label = $Content/SelectedSection/FacingLabel
@onready var selected_class_label: Label = $Content/SelectedSection/ClassLabel
@onready var selected_level_label: Label = $Content/SelectedSection/LevelLabel
@onready var selected_hp_label: Label = $Content/SelectedSection/HpLabel
@onready var selected_health_fill: ColorRect = $Content/SelectedSection/HealthBar/Fill
@onready var selected_wound_badge: Label = $Content/SelectedSection/WoundBadge
@onready var selected_ap_label: Label = $Content/SelectedSection/ApLabel
@onready var selected_weapon_label: Label = $Content/SelectedSection/WeaponLabel
@onready var selected_defense_label: Label = $Content/SelectedSection/DefenseLabel
@onready var selected_spellcasting_label: Label = $Content/SelectedSection/SpellcastingLabel
@onready var selected_wound_label: Label = $Content/SelectedSection/WoundLabel
@onready var selected_status_label: Label = $Content/SelectedSection/StatusLabel

## Independent pulse tweens for the hovered/selected bars (Critical tier) --
## kept as separate fields rather than one shared var since both sections
## can be visible and animating at once.
var _hovered_pulse_tween: Tween
var _selected_pulse_tween: Tween


## Drives both halves of the panel from a single call so a spent AP value (or
## a damage tick) on the still-selected unit updates immediately, even while
## the hovered unit itself hasn't changed -- see battlefield.gd's
## _on_board_changed()/_on_unit_focus_changed(), which both call this with
## grid.hovered_unit/grid.selected_unit rather than the older single
## get_focused_unit() result.
func update_panel(hovered_unit, selected_unit) -> void:
	# A unit hovering itself (hovered_unit == selected_unit) would otherwise
	# duplicate the same details in both halves of the panel -- only show the
	# HoveredSection for a genuinely different unit.
	var show_hovered: bool = hovered_unit != null and hovered_unit != selected_unit
	hovered_section.visible = show_hovered
	if show_hovered:
		_populate_hovered(hovered_unit)
	else:
		# Un-hovering (or hovering the already-selected unit) hides this
		# section without going through _populate_hovered()/
		# _update_health_visual() -- kill any looping Critical-tier pulse
		# tween so it doesn't keep animating a now-hidden fill node until
		# some later hover happens to touch this same shared node again.
		_hovered_pulse_tween = WoundVisuals.apply_pulse(hovered_health_fill, false, _hovered_pulse_tween)

	var show_selected: bool = selected_unit != null
	selected_section.visible = show_selected
	if show_selected:
		_populate_selected(selected_unit)
	else:
		# Same cleanup as the hovered branch above, for deselection.
		_selected_pulse_tween = WoundVisuals.apply_pulse(selected_health_fill, false, _selected_pulse_tween)

	empty_label.visible = not show_hovered and not show_selected


func clear() -> void:
	update_panel(null, null)


## Design Contract (index.md, "4. Dual Right-Hand Inspection Panel"): the
## hovered section shows "wound tier for enemies, HP/class for allies" -- so
## unlike _populate_selected() (which shows class for every player unit,
## selected or not), an ally's class only ever shows up here, never an
## enemy's wound-tier row gaining a class label.
func _populate_hovered(unit) -> void:
	hovered_name_label.text = unit.display_name
	hovered_facing_label.text = _facing_text(unit)

	var is_player: bool = unit.side == BattleControllerScript.Side.PLAYER
	hovered_class_label.visible = is_player
	hovered_hp_label.visible = is_player
	hovered_wound_label.visible = not is_player

	if is_player:
		var adventurer := GameSession.get_adventurer(unit.adventurer_id)
		hovered_class_label.text = tr("information.class") % adventurer.get("class", "")
		hovered_hp_label.text = tr("battle.unit_info.hp") % [unit.health, unit.max_health]
	else:
		hovered_wound_label.text = tr(_wound_tier_key(unit))
	# Health bar/wound badge show for every hovered unit, ally or enemy alike
	# -- unlike HpLabel/WoundLabel above, which are side-conditional -- but
	# an enemy's bar only ever fills to its coarse tier width (is_player
	# gates exact vs. discretized fraction; see ENEMY_BAR_DISPLAY_FRACTIONS).
	_hovered_pulse_tween = _update_health_visual(hovered_health_fill, hovered_wound_badge, unit, is_player, _hovered_pulse_tween)


func _populate_selected(unit) -> void:
	selected_name_label.text = unit.display_name
	selected_facing_label.text = _facing_text(unit)

	var is_player: bool = unit.side == BattleControllerScript.Side.PLAYER
	selected_class_label.visible = is_player
	selected_level_label.visible = is_player
	selected_wound_label.visible = not is_player

	if is_player:
		var adventurer := GameSession.get_adventurer(unit.adventurer_id)
		selected_class_label.text = tr("information.class") % adventurer.get("class", "")
		selected_level_label.text = tr("information.level") % adventurer.get("level", 0)
	else:
		selected_wound_label.text = tr(_wound_tier_key(unit))

	selected_hp_label.text = tr("battle.unit_info.hp") % [unit.health, unit.max_health]
	# The selected unit is always the player's own -- exact fraction, same as
	# the numeric HpLabel above, is never a spoiler here (see is_player
	# branch in _populate_hovered() for the enemy-side exception).
	_selected_pulse_tween = _update_health_visual(selected_health_fill, selected_wound_badge, unit, true, _selected_pulse_tween)
	selected_ap_label.text = tr("battle.unit_info.ap") % [unit.action_points_remaining, unit.max_action_points]
	selected_weapon_label.text = tr("battle.unit_info.weapon") % unit.attack_name
	# Guard (unit.guard -- hit-chance subtraction) and Resistance (unit.
	# resistance -- post-hit damage reduction) are two distinct shared
	# tactical attributes (docs/designs/class-system.md's "Shared tactical
	# attributes" section) -- shown together here, never as a single mislabeled
	# value (see this step's unit_details.gd fix for the bug this avoids
	# repeating). The selected unit is always the player's own (see this
	# file's own _populate_selected() doc comment), so this is never an
	# enemy-stat spoiler the way an exact HP number would be.
	selected_defense_label.text = tr("battle.unit_info.defense") % [unit.guard, unit.resistance]
	# Spellcasting only shows for a unit that actually has some (Cleric
	# today) -- a non-caster's unit.spellcasting is always 0, and showing
	# "Spellcasting: 0%" for every Warrior/Scout would expose a stat that
	# class doesn't own as though it were real (see unit_details.gd's own
	# identical rule for its Skills list, and this step's design note about
	# not exposing a missing spell value as a real stat). Magic Resistance is
	# omitted entirely here -- no class or monster has a nonzero source yet
	# (see GameSession.get_effective_magic_resistance()) -- rather than
	# always showing a dead 0%.
	selected_spellcasting_label.visible = unit.spellcasting > 0
	if unit.spellcasting > 0:
		selected_spellcasting_label.text = tr("battle.unit_info.spellcasting") % unit.spellcasting

	var status_names: Array[String] = []
	for status_id in unit.statuses:
		status_names.append(String(status_id).capitalize())
	selected_status_label.visible = not status_names.is_empty()
	if not status_names.is_empty():
		selected_status_label.text = ", ".join(status_names)


func _facing_text(unit) -> String:
	return tr("battle.unit_info.facing") % tr(FACING_KEYS.get(unit.facing, "battle.facing.east"))


func _wound_tier_key(unit) -> String:
	if unit.max_health <= 0:
		return "battle.unit_info.badly_wounded"
	var health_percent: float = float(unit.health) / float(unit.max_health)
	if health_percent > HEALTHY_THRESHOLD:
		return "battle.unit_info.healthy"
	if health_percent > WOUNDED_THRESHOLD:
		return "battle.unit_info.wounded"
	return "battle.unit_info.badly_wounded"


## Drives one bar+badge pair from a unit's current wound tier. exact_fraction
## selects between the true health fraction (selected/player, or a hovered
## ally) and the coarse, tier-only display width (a hovered enemy -- see
## ENEMY_BAR_DISPLAY_FRACTIONS's own doc comment). Manages this bar's pulse
## tween itself (Critical only, via WoundVisuals.apply_pulse()) and returns
## the current Tween (or null) so the caller can hold onto it for the next
## call to kill cleanly.
func _update_health_visual(fill: ColorRect, badge: Label, unit, exact_fraction: bool, existing_tween: Tween) -> Tween:
	var tier := WoundVisuals.tier(unit.health, unit.max_health)
	var fraction: float
	if unit.health <= 0:
		fraction = 0.0
	elif exact_fraction:
		fraction = clampf(float(unit.health) / float(maxi(1, unit.max_health)), 0.0, 1.0)
	else:
		fraction = float(ENEMY_BAR_DISPLAY_FRACTIONS.get(tier, 1.0))
	fill.size.x = HEALTH_BAR_WIDTH * fraction
	fill.color = WoundVisuals.HEALTH_BAR_COLORS.get(tier, WoundVisuals.HEALTH_BAR_COLORS[WoundVisuals.TIER_HEALTHY])
	badge.visible = tier != WoundVisuals.TIER_HEALTHY
	badge.text = WoundVisuals.WOUND_BADGE_GLYPHS.get(tier, "")
	return WoundVisuals.apply_pulse(fill, tier == WoundVisuals.TIER_CRITICAL, existing_tween)
