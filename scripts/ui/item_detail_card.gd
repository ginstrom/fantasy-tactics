class_name ItemDetailCard
extends VBoxContainer

## Card body for item details (weapons, armor, potions, and mana crystals).
## Displays item name, type/category, stats, price/value, and quantity.
## Emits buy_requested, sell_requested, or equip_requested based on caller configuration.

signal buy_requested(item_id: String)
signal sell_requested(item_id: String)
signal equip_requested(item_id: String)

var item_id: String = ""
var row_data: Dictionary = {}
var show_buy: bool = false
var show_sell: bool = false
var show_equip: bool = false

@onready var name_label: Label = %NameLabel
@onready var type_label: Label = %TypeLabel
@onready var category_label: Label = %CategoryLabel
@onready var stats_label: Label = %StatsLabel
@onready var quantity_label: Label = %QuantityLabel
@onready var price_label: Label = %PriceLabel
@onready var description_label: Label = %DescriptionLabel
@onready var buy_button: Button = %BuyButton
@onready var sell_button: Button = %SellButton
@onready var equip_button: Button = %EquipButton
@onready var not_found_label: Label = %NotFoundLabel


func _ready() -> void:
	if is_instance_valid(buy_button):
		buy_button.pressed.connect(_on_buy_pressed)
	if is_instance_valid(sell_button):
		sell_button.pressed.connect(_on_sell_pressed)
	if is_instance_valid(equip_button):
		equip_button.pressed.connect(_on_equip_pressed)
	refresh()


func configure(new_show_buy: bool, new_show_sell: bool, new_show_equip: bool) -> void:
	show_buy = new_show_buy
	show_sell = new_show_sell
	show_equip = new_show_equip
	refresh()


func set_item(new_item_id: String, new_row_data: Dictionary = {}) -> void:
	item_id = new_item_id
	row_data = new_row_data
	refresh()


func refresh() -> void:
	if not is_inside_tree() or not is_instance_valid(name_label):
		return
	if item_id.is_empty():
		_show_not_found()
		return

	if item_id.begins_with(GameSession.MANA_CRYSTAL_ID_PREFIX):
		_show_mana_crystal()
		return

	var item := GameSession.get_item_definition(item_id)
	if item.is_empty():
		_show_not_found()
		return

	_show_gear_item(item)


func _show_mana_crystal() -> void:
	not_found_label.visible = false
	var tier := int(item_id.substr(GameSession.MANA_CRYSTAL_ID_PREFIX.length()))
	name_label.text = str(row_data.get("name", tr("stores.mana_crystal") % tier))
	type_label.text = tr("item_details.type") % tr("stores.type.mana_crystal")
	category_label.visible = false

	var sale_price := int(row_data.get("price", GameSession.get_item_sale_price(item_id)))
	stats_label.text = tr("item_details.crystal_stats") % [tier, sale_price]
	stats_label.visible = true

	var count := int(row_data.get("count", 1))
	quantity_label.text = tr("item_details.quantity") % count
	quantity_label.visible = count > 0

	price_label.text = tr("item_details.value") % sale_price
	price_label.visible = true
	description_label.visible = false

	buy_button.visible = false
	sell_button.visible = show_sell and GameSession.shop_level > 0
	sell_button.disabled = not GameSession.can_sell_item(item_id)
	equip_button.visible = false

	name_label.visible = true
	type_label.visible = true


func _show_gear_item(item: Dictionary) -> void:
	not_found_label.visible = false
	name_label.text = str(row_data.get("name", tr(item.name_key)))

	var slot: String = str(item.get("slot", ""))
	type_label.text = tr("item_details.type") % tr("stores.type.%s" % slot)
	type_label.visible = true

	if item.has("category"):
		category_label.text = tr("item_details.category") % str(item.category).capitalize()
		category_label.visible = true
	else:
		category_label.visible = false

	var slot_name := slot.to_lower()
	if slot_name == "weapon":
		var min_range: int = int(item.get("min_range", 1))
		var max_range: int = int(item.get("max_range", 1))
		var range_str := str(min_range) if min_range == max_range else "%d–%d" % [min_range, max_range]
		stats_label.text = tr("item_details.weapon_stats") % [int(item.damage_min), int(item.damage_max), range_str]
		stats_label.visible = true
	elif slot_name == "armor":
		stats_label.text = tr("item_details.armor_stats") % [int(item.defense), int(item.resistance)]
		stats_label.visible = true
	elif slot_name == "potion":
		stats_label.text = tr("item_details.potion_stats") % [int(item.healing_min), int(item.healing_max)]
		stats_label.visible = true
	else:
		stats_label.visible = false

	if show_buy:
		var price := int(item.get("price", 0))
		price_label.text = tr("item_details.price") % price
		price_label.visible = true
		quantity_label.visible = false
		buy_button.visible = true
		buy_button.text = tr("item_details.buy")
		buy_button.disabled = (
			GameSession.gold < price
			or not GameSession.get_shop_catalogue_item_ids().has(item_id)
		)
		sell_button.visible = false
		equip_button.visible = false
	else:
		var price := int(row_data.get("price", GameSession.get_item_sale_price(item_id)))
		price_label.text = tr("item_details.value") % price
		price_label.visible = true

		if row_data.has("count"):
			quantity_label.text = tr("item_details.quantity") % int(row_data.count)
			quantity_label.visible = true
		else:
			quantity_label.visible = false

		buy_button.visible = false
		sell_button.visible = show_sell and GameSession.shop_level > 0
		sell_button.text = tr("item_details.sell")
		sell_button.disabled = not GameSession.can_sell_item(item_id)

		equip_button.visible = show_equip and not item_id.begins_with(GameSession.MANA_CRYSTAL_ID_PREFIX)
		equip_button.text = tr("item_details.equip")
		equip_button.disabled = false

	description_label.visible = false
	name_label.visible = true


func _show_not_found() -> void:
	not_found_label.visible = true
	name_label.visible = false
	type_label.visible = false
	category_label.visible = false
	stats_label.visible = false
	quantity_label.visible = false
	price_label.visible = false
	description_label.visible = false
	buy_button.visible = false
	sell_button.visible = false
	equip_button.visible = false


func _on_buy_pressed() -> void:
	buy_requested.emit(item_id)


func _on_sell_pressed() -> void:
	sell_requested.emit(item_id)


func _on_equip_pressed() -> void:
	equip_requested.emit(item_id)
