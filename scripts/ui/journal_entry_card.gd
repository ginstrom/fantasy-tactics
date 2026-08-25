class_name JournalEntryCard
extends VBoxContainer

## Card body for a Journal entry.
## Displays title, timestamp/turn/day/sequence, category, body text, and read state.
## Reads data freshly from GameSession on refresh.

var entry_id: String = ""

@onready var title_label: Label = %TitleLabel
@onready var meta_label: Label = %MetaLabel
@onready var status_label: Label = %StatusLabel
@onready var body_label: Label = %BodyLabel
@onready var not_found_label: Label = %NotFoundLabel


func _ready() -> void:
	refresh()


func set_entry_id(id: String) -> void:
	entry_id = id
	refresh()


func refresh() -> void:
	if not is_inside_tree() or not is_instance_valid(title_label):
		return
	var entry := GameSession.get_journal_entry(entry_id)
	if entry.is_empty():
		_show_not_found()
		return
	_show_entry(entry)


func _show_entry(entry: Dictionary) -> void:
	not_found_label.visible = false

	title_label.text = tr(entry.get("title_key", ""))

	var kind_text: String = tr("journal.section.%s" % entry.get("section", "log")) if entry.get("section", "") != "" else str(entry.get("kind", "")).capitalize()
	var seq: int = int(entry.get("sequence", 0))
	meta_label.text = tr("journal_card.meta") % [kind_text, seq]

	var is_read: bool = bool(entry.get("read", false))
	var status_text := tr("journal_card.status_read") if is_read else tr("journal_card.status_unread")
	status_label.text = tr("journal_card.status") % status_text

	var detail_dict: Dictionary = entry.get("detail", {})
	if detail_dict.is_empty():
		body_label.text = tr(entry.get("title_key", ""))
	else:
		var lines: Array[String] = []
		for key in detail_dict.keys():
			lines.append("%s: %s" % [str(key).capitalize().replace("_", " "), str(detail_dict[key])])
		body_label.text = "\n".join(lines)

	for label in [title_label, meta_label, status_label, body_label]:
		label.visible = true


func _show_not_found() -> void:
	not_found_label.visible = true
	for label in [title_label, meta_label, status_label, body_label]:
		label.visible = false
