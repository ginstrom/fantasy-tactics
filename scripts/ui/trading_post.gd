extends Control

## Shows Shop status and its unlocked weapon catalogue. Selecting a
## row shows its detail and a Buy action gated on affordability, mirroring
## recruitment.gd's row-selection-drives-a-gated-purchase-button pattern.
## Also carries an Upgrade action gated on GameSession.can_upgrade_shop(),
## mirroring guild_hall.gd's "below the level cap" Upgrade button /
## MaxLevelLabel pattern — Shop's 3 tiers gate income (2/5/10 gold/turn) and
## the Tier-3 healing potion purchase (see stores.gd).

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")
const ItemDetailCardScene := preload("res://scenes/ui/item_detail_card.tscn")

@onready var income_label: Label = $Body/Center/VBox/IncomeLabel
@onready var upgrade_button: Button = $Body/Center/VBox/UpgradeButton
@onready var max_level_label: Label = $Body/Center/VBox/MaxLevelLabel
@onready var buy_table: TableView = $Body/Center/VBox/BuyTable
@onready var selected_item_label: Label = $Body/Center/VBox/SelectedItemLabel
@onready var buy_button: Button = $Body/Center/VBox/BuyButton
@onready var card_navigator: CardNavigator = $CardNavigator

const SHOP_MAX_LEVEL := 3

var selected_item_id: String = ""
var item_detail_card: ItemDetailCard


func _ready() -> void:
	buy_table.row_selected.connect(_on_row_selected)
	buy_table.row_activated.connect(_on_row_activated)
	buy_table.set_columns(_build_columns())

	item_detail_card = ItemDetailCardScene.instantiate()
	card_navigator.set_card_content(item_detail_card)
	card_navigator.set_title("shop.item_details")
	item_detail_card.configure(true, false, false)
	card_navigator.card_changed.connect(_on_card_changed)
	card_navigator.closed.connect(_on_card_navigator_closed)
	item_detail_card.buy_requested.connect(_on_card_buy_requested)

	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if card_navigator.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	income_label.text = tr("shop.status") % [GameSession.shop_level, GameSession.shop_gold, GameSession.shop_gold_cap()]
	buy_table.set_rows(_build_rows())
	_refresh_selection()

	var at_max_level: bool = GameSession.shop_level >= SHOP_MAX_LEVEL
	upgrade_button.visible = not at_max_level
	upgrade_button.disabled = not GameSession.can_upgrade_shop()
	var upgrade_cost := (
		GameSession.SHOP_LEVEL_3_UPGRADE_COST if GameSession.shop_level == 2 else GameSession.SHOP_UPGRADE_COST
	)
	upgrade_button.text = tr("shop.upgrade") % [GameSession.shop_level + 1, upgrade_cost]
	max_level_label.visible = at_max_level

	if card_navigator.visible:
		var cur_id: Variant = card_navigator.get_current_id()
		if cur_id == null or not GameSession.get_shop_catalogue_item_ids().has(str(cur_id)):
			card_navigator.close()
		else:
			_refresh_card(str(cur_id))


func _build_columns() -> Array[TableColumn]:
	var name_column := TableColumnDescriptor.new(&"name", tr("shop.column.name"))
	name_column.expand = true
	name_column.expand_ratio = 2
	var type_column := TableColumnDescriptor.new(&"type", tr("shop.column.type"))
	var price_column := TableColumnDescriptor.new(&"price", tr("shop.column.price"), TableColumnDescriptor.Type.INTEGER)
	return [name_column, type_column, price_column]


func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for item_id in GameSession.get_shop_catalogue_item_ids():
		rows.append(_row_for(item_id, GameSession.WEAPONS[item_id]))
	return rows


func _row_for(item_id: String, item: Dictionary) -> Dictionary:
	return {"id": item_id, "name": tr(item.name_key), "type": tr("shop.type.%s" % item.slot), "price": item.price}


func _refresh_selection() -> void:
	var item := GameSession.get_item_definition(selected_item_id)
	if item.is_empty():
		selected_item_id = ""
		selected_item_label.visible = false
		buy_button.visible = false
		return

	selected_item_label.visible = true
	selected_item_label.text = tr("shop.selected") % [tr(item.name_key), item.price]
	buy_button.visible = true
	buy_button.disabled = GameSession.gold < int(item.price) or not GameSession.get_shop_catalogue_item_ids().has(selected_item_id)


func _on_row_selected(row_id: Variant) -> void:
	selected_item_id = str(row_id)
	_refresh_selection()


func _on_row_activated(row_id: Variant) -> void:
	_open_card_navigator(str(row_id))


func _open_card_navigator(initial_id: String) -> void:
	var id_list := buy_table.get_displayed_row_ids()
	if id_list.is_empty():
		return
	var return_target: Control = buy_button if buy_button.visible else null
	card_navigator.open(id_list, initial_id, return_target)
	_refresh_card(str(card_navigator.get_current_id()))


func _on_card_changed(id: Variant) -> void:
	_refresh_card(str(id))


func _refresh_card(id: String) -> void:
	item_detail_card.set_item(id, {})


func _on_card_navigator_closed(last_id: Variant) -> void:
	if last_id != null and str(last_id) != "":
		selected_item_id = str(last_id)
		buy_table.select_row(selected_item_id)
		_refresh_selection()


func _on_card_buy_requested(item_id: String) -> void:
	if not GameSession.get_shop_catalogue_item_ids().has(item_id):
		refresh()
		return
	GameSession.buy_item(item_id)
	refresh()
	if card_navigator.visible:
		_refresh_card(item_id)


func _on_buy_button_pressed() -> void:
	GameSession.buy_item(selected_item_id)
	refresh()


func _on_upgrade_button_pressed() -> void:
	GameSession.upgrade_shop()
	refresh()


func _on_back_pressed() -> void:
	GameManager.go_to_trade()
