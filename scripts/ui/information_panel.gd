extends PanelContainer

@onready var gold_label: Label = $Content/Gold


func _ready() -> void:
	refresh()


func refresh() -> void:
	gold_label.text = tr("information.gold") % GameSession.gold
