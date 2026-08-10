extends PanelContainer

## Non-blocking first-campaign guide banner (see docs/plans/2026-08-10-
## initial-campaign-and-automation/04-first-campaign-guidance.md). Instanced
## only on Encampment and World Map, it renders whatever
## GameSession.get_campaign_guide_state() currently says is due -- one short
## message, an optional textual target cue, and a Dismiss action -- and
## nothing else. It never routes or otherwise touches campaign state; the
## only session write it ever triggers is the explicit dismissal recorded
## by GameSession.record_campaign_guide_dismissal() when the player presses
## Dismiss.
##
## Every node in this scene keeps mouse_filter = MOUSE_FILTER_IGNORE except
## the Dismiss button itself, so the banner can never absorb a click meant
## for the screen underneath it -- see test_campaign_guide.gd and
## test_first_campaign_ui_flow.gd for the regression coverage.

@onready var message_label: Label = %MessageLabel
@onready var target_label: Label = %TargetLabel
@onready var dismiss_button: Button = %DismissButton

var _current_guide_id: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh()


## Re-reads the derived guide state and updates the banner in place. Safe to
## call as often as the owning screen likes (its own state-changing actions
## call this directly rather than waiting for a full scene reload) -- it
## never mutates GameSession itself.
func refresh() -> void:
	_current_guide_id = GameSession.get_campaign_guide_state()
	visible = _current_guide_id != ""
	if not visible:
		return

	message_label.text = tr("campaign_guide.%s.message" % _current_guide_id)

	var target_key := "campaign_guide.%s.target" % _current_guide_id
	var target_text := tr(target_key)
	# A target cue is optional per message -- an unresolved key (tr() just
	# echoes it back) means this guide id has none, so the line stays hidden
	# rather than showing a raw key to the player.
	target_label.visible = target_text != target_key
	target_label.text = target_text


func _on_dismiss_button_pressed() -> void:
	if _current_guide_id == "":
		return
	GameSession.record_campaign_guide_dismissal(_current_guide_id)
	refresh()
