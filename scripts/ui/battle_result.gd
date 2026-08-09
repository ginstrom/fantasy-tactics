extends Control

## Reads GameManager.battle_result_summary (set by Battlefield._finish_
## victory() right before routing here — see that method) once, in
## _ready(), the same "transient payload set right before navigating"
## pattern route_context_id uses elsewhere in this codebase. Loot is part of
## that summary dict ("loot_gold" plus the itemized
## "loot_gear_counts"/"loot_mana_crystal_counts") -- reading
## GameSession.pending_reward/pending_mana_crystals/pending_gear directly
## would show every encounter a deployed party has cleared so far this
## deployment, not just this battle's own loot (see _finish_victory()'s
## before/after delta). The gear/mana-crystal table reuses LootTable, but
## purely as a read-only record: no [Sell] (loot only sells once banked
## at the Encampment) and no [Equip] either -- this is a frozen snapshot
## of what this battle dropped, taken once and never re-read, so letting
## the player mutate live state (GameSession.pending_gear) through it
## would silently desync the two. Equipping happens once the party is
## back on the World Map (Party Details, which reads pending_gear live).

@onready var kills_label: Label = $Center/VBox/KillsLabel
@onready var xp_label: Label = $Center/VBox/XpLabel
@onready var level_up_label: Label = $Center/VBox/LevelUpLabel
@onready var gold_label: Label = $Center/VBox/GoldLabel
@onready var loot_table: LootTable = $Center/VBox/LootTable
@onready var ok_button: Button = $Center/VBox/OkButton


func _ready() -> void:
	loot_table.configure(false, false)
	_refresh()


func _refresh() -> void:
	var summary: Dictionary = GameManager.battle_result_summary
	kills_label.text = _format_kills(summary.get("kills_by_type", {}))

	var total_xp: float = summary.get("total_xp", 0.0)
	var member_count: int = maxi(summary.get("party_member_count", 1), 1)
	var each_xp: float = total_xp / member_count
	xp_label.text = tr("battle_result.xp") % [int(round(total_xp)), int(round(each_xp))]

	var leveled_up_ids: Array = summary.get("leveled_up_ids", [])
	level_up_label.visible = not leveled_up_ids.is_empty()
	if level_up_label.visible:
		var names: Array = []
		for adventurer_id in leveled_up_ids:
			names.append(GameSession.get_adventurer(adventurer_id).get("name", ""))
		level_up_label.text = tr("battle_result.leveled_up") % ", ".join(names)

	gold_label.text = tr("battle_result.gold") % summary.get("loot_gold", 0)
	loot_table.set_rows(GameSession.build_loot_rows(
		summary.get("loot_gear_counts", {}), summary.get("loot_mana_crystal_counts", {})
	))


func _format_kills(kills_by_type: Dictionary) -> String:
	if kills_by_type.is_empty():
		return tr("battle_result.no_kills")
	var parts: Array = []
	for type_name in kills_by_type:
		parts.append("%s x%d" % [type_name, kills_by_type[type_name]])
	return tr("battle_result.kills") % ", ".join(parts)


func _on_ok_pressed() -> void:
	GameManager.battle_result_summary = {}
	GameManager.go_to_world_map()
