extends Control

## Lists everything banked in storage (GameSession.banked_gear +
## GameSession.mana_crystals) via the shared LootTable component (see
## loot_table.gd) — full [Sell]/[Equip] actions, unscoped (any roster
## adventurer can be assigned here, unlike the party-scoped Equip on the
## victory summary and World Map Party Details — see Steps 6/7).

@onready var loot_table: LootTable = $Body/Center/VBox/LootTable


func _ready() -> void:
	loot_table.configure(true, true, LootTable.ActionPresentation.DIRECT_ACTION_BAR)
	loot_table.equip_requested.connect(_on_equip_requested)
	loot_table.sold.connect(refresh)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	loot_table.set_rows(GameSession.build_loot_rows(
		GameSession.banked_gear, GameSession.mana_crystals, GameSession.banked_item_instance_ids
	))


func _on_equip_requested(item_id: String) -> void:
	GameManager.go_to_assign_equipment(item_id)


func _on_back_pressed() -> void:
	GameManager.go_to_trade()
