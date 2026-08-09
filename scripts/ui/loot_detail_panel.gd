class_name LootDetailPanel
extends PanelContainer

## The detail view LootTable opens for one row (via its View button or a
## double-click) — shows that item's description plus real, text-labeled
## [Sell]/[Equip] buttons. Exists because Godot's Tree control only
## supports icon buttons (TreeItem.add_button() takes a Texture2D, never
## a string) — a real PanelContainer holding real Button nodes is the
## only way to get actual readable button text.

signal sell_requested(item_id: String)
signal equip_requested(item_id: String)
signal closed

@onready var name_label: Label = $Content/NameLabel
@onready var detail_label: Label = $Content/DetailLabel
@onready var sell_button: Button = $Content/ButtonRow/SellButton
@onready var equip_button: Button = $Content/ButtonRow/EquipButton

var _item_id: String = ""


func _ready() -> void:
	visible = false


func show_for_row(row: Dictionary, show_sell: bool, show_equip: bool) -> void:
	_item_id = str(row.id)
	name_label.text = str(row.name)
	detail_label.text = tr("loot_detail_panel.detail") % [str(row.type), int(row.count), int(row.price)]
	sell_button.visible = show_sell and GameSession.has_trading_post
	equip_button.visible = show_equip and not _item_id.begins_with(GameSession.MANA_CRYSTAL_ID_PREFIX)
	visible = true


func _on_sell_button_pressed() -> void:
	visible = false
	sell_requested.emit(_item_id)


func _on_equip_button_pressed() -> void:
	visible = false
	equip_requested.emit(_item_id)


func _on_close_button_pressed() -> void:
	visible = false
	closed.emit()
