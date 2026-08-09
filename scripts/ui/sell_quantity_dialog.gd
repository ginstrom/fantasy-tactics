class_name SellQuantityDialog
extends PanelContainer

## A Rimworld-style sell quantity picker: a directly-editable quantity
## field, -10/-1/+1/+10 step buttons, an ALL button, and Cancel/OK. Owns no
## GameSession state itself — show_for_item() is given everything it needs
## to render (max stock, unit price), and confirmed(item_id, quantity) is
## the caller's cue to actually call GameSession.sell_item().

signal confirmed(item_id: String, quantity: int)

@onready var item_label: Label = $Content/ItemLabel
@onready var quantity_input: LineEdit = $Content/QuantityRow/QuantityInput
@onready var total_label: Label = $Content/TotalLabel

var _item_id: String = ""
var _max_quantity: int = 1
var _unit_price: int = 0
var _quantity: int = 1


func _ready() -> void:
	visible = false


func show_for_item(item_id: String, item_name: String, max_quantity: int, unit_price: int) -> void:
	_item_id = item_id
	_max_quantity = max_quantity
	_unit_price = unit_price
	item_label.text = item_name
	_set_quantity(1)
	visible = true


func _set_quantity(value: int) -> void:
	_quantity = clampi(value, 1, maxi(_max_quantity, 1))
	quantity_input.text = str(_quantity)
	total_label.text = tr("sell_quantity_dialog.total") % (_quantity * _unit_price)


func _on_quantity_input_text_submitted(new_text: String) -> void:
	_set_quantity(int(new_text) if new_text.is_valid_int() else _quantity)


func _on_minus_ten_button_pressed() -> void:
	_set_quantity(_quantity - 10)


func _on_minus_one_button_pressed() -> void:
	_set_quantity(_quantity - 1)


func _on_plus_one_button_pressed() -> void:
	_set_quantity(_quantity + 1)


func _on_plus_ten_button_pressed() -> void:
	_set_quantity(_quantity + 10)


func _on_all_button_pressed() -> void:
	_set_quantity(_max_quantity)


func _on_cancel_button_pressed() -> void:
	visible = false


func _on_ok_button_pressed() -> void:
	visible = false
	confirmed.emit(_item_id, _quantity)
